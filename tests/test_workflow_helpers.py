"""Workflow contracts using real Git repositories; only remote gh is stubbed."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENTITY = ROOT / '.claude/skills/entity-migration/scripts/check-entity-diff.sh'
CONVENTION = ROOT / '.claude/skills/commit-pr/scripts/derive-git-convention.sh'


class WorkflowHelpers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_CONFIG_NOSYSTEM='1')
        self.git('init', '-q')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Test')
        self.bin = self.repo / 'bin'
        self.bin.mkdir()
        self.env['PATH'] = str(self.bin) + os.pathsep + self.env['PATH']
        self.calls = self.repo / 'gh-calls'
        self.stub_gh('[]')

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.repo, env=self.env,
                              text=True, capture_output=True, check=True).stdout

    def write(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def history(self, count=5):
        for n in range(count):
            self.git('commit', '--allow-empty', '-qm', f'fix: repair case {n}')

    def run_helper(self, script, *args):
        return subprocess.run(['bash', str(script), *args], cwd=self.repo,
                              env=self.env, capture_output=True, text=True)

    def stub_gh(self, payload, status=0, stderr=''):
        # gh is the only external service boundary; record arguments to catch
        # accidental remote access, duplicate requests and missing body fields.
        self.env.update(GH_FIXTURE=payload, GH_STATUS=str(status), GH_ERR=stderr,
                        GH_CALLS=str(self.calls))
        gh = self.bin / 'gh'
        gh.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$GH_CALLS"\n'
                      'printf "%s" "$GH_FIXTURE"\nprintf "%s" "$GH_ERR" >&2\n'
                      'exit "$GH_STATUS"\n')
        gh.chmod(0o755)

    def test_untracked_entity_is_reported_without_staging(self):
        self.history(1)
        self.write('src/entities/New Entity.ts', '@Column()\nname: string;\n')
        before = self.git('status', '--porcelain=v1', '-uall')
        result = self.run_helper(ENTITY)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('New Entity.ts', result.stdout)
        self.assertIn('@Column()', result.stdout)
        self.assertEqual(before, self.git('status', '--porcelain=v1', '-uall'))

    def test_initial_repository_includes_staged_and_untracked_entities(self):
        self.write('src/entities/Staged.ts', '@Column()\nstaged: string;\n')
        self.git('add', 'src/entities/Staged.ts')
        self.write('src/entities/New.ts', '@Index()\nnewValue: string;\n')
        result = self.run_helper(ENTITY)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Staged.ts', result.stdout)
        self.assertIn('New.ts', result.stdout)
        self.assertNotIn('fatal:', result.stderr)

    def test_tracked_staged_and_unstaged_changes_are_combined(self):
        self.write('src/entities/Old.ts', '@Column()\n')
        self.git('add', 'src/entities/Old.ts')
        self.git('commit', '-qm', 'fix: baseline')
        self.write('src/entities/Old.ts', '@Column({ nullable: true })\n')
        self.git('add', 'src/entities/Old.ts')
        self.write('src/entities/Old.ts', '@Column({ nullable: true })\n@Index()\n')
        result = self.run_helper(ENTITY)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('nullable: true', result.stdout)
        self.assertIn('@Index()', result.stdout)

    def test_base_exposes_committed_entity_change(self):
        self.history(1)
        base = self.git('rev-parse', 'HEAD').strip()
        self.write('src/entities/Committed.ts', '@Column()\n')
        self.git('add', 'src/entities/Committed.ts')
        self.git('commit', '-qm', 'feat: entity')
        result = self.run_helper(ENTITY, '--base', base)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Committed.ts', result.stdout)

    def test_invalid_base_is_error_not_empty_diff(self):
        self.history(1)
        result = self.run_helper(ENTITY, '--base', 'missing-reference')
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('Entity 변경 없음', result.stdout)

    def test_corrupt_head_is_error_for_both_git_helpers(self):
        self.history(1)
        ref = self.git('symbolic-ref', 'HEAD').strip()
        self.write('.git/' + ref, '1' * 40 + '\n')
        for script in (ENTITY, CONVENTION):
            with self.subTest(script=script.name):
                result = self.run_helper(script)
                self.assertEqual(result.returncode, 1)
                self.assertNotIn('Entity 변경 없음', result.stdout)

    def test_empty_initial_repository_is_successful_but_scoped(self):
        result = self.run_helper(ENTITY)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('비교 범위', result.stdout)
        self.assertNotIn('마이그레이션 불필요', result.stdout)
        self.assertEqual(result.stderr, '')

    def test_commit_mode_never_queries_pr_history(self):
        self.history()
        self.stub_gh('', status=1)
        result = self.run_helper(CONVENTION, '--mode', 'commit', '5')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.calls.exists())
        self.assertIn('5/5', result.stdout)
        self.assertNotIn('제목에는 티켓 번호를 넣지 않음', result.stdout)

    def test_legacy_numeric_invocation_is_commit_only(self):
        self.history()
        result = self.run_helper(CONVENTION, '5')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.calls.exists())

    def test_pr_template_resolves_missing_history(self):
        self.write('.github/PULL_REQUEST_TEMPLATE.md', '## Purpose\n## Tests\n')
        result = self.run_helper(CONVENTION, '--mode', 'pr')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('## Purpose', result.stdout)
        self.assertFalse(self.calls.exists())

    def test_explicit_convention_resolves_initial_history(self):
        self.write('CONTRIBUTING.md', 'Use Korean titles. Include known ticket IDs.\n')
        result = self.run_helper(CONVENTION, '--mode', 'commit',
                                 '--convention', 'CONTRIBUTING.md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Use Korean titles', result.stdout)
        self.assertFalse(self.calls.exists())

    def test_explicit_pr_convention_precedes_template(self):
        self.write('rules.md', '## Required Context\n')
        self.write('.github/pull_request_template.md', '## Legacy Context\n')
        result = self.run_helper(CONVENTION, '--mode', 'pr', '--convention', 'rules.md')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('## Required Context', result.stdout)
        self.assertNotIn('## Legacy Context', result.stdout)
        self.assertFalse(self.calls.exists())

    def test_relative_convention_uses_invocation_directory(self):
        self.write('rules.md', 'ROOT: use English titles.\n')
        self.write('module space/rules.md', 'MODULE: use Korean titles.\n')
        for mode in ('commit', 'pr'):
            with self.subTest(mode=mode):
                result = subprocess.run(
                    ['bash', str(CONVENTION), '--mode', mode,
                     '--convention', 'rules.md'],
                    cwd=self.repo / 'module space', env=self.env,
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('MODULE: use Korean titles.', result.stdout)
                self.assertNotIn('ROOT: use English titles.', result.stdout)
                self.assertFalse(self.calls.exists())

    def test_pr_body_is_collected_in_one_successful_query(self):
        self.stub_gh(json.dumps([dict(number=12, title='A title',
                                      body='## Context\nDetails\n## Tests\nPassed')]),
                     stderr='A harmless CLI warning')
        result = self.run_helper(CONVENTION, '--mode', 'pr', '5')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('## Context', result.stdout)
        calls = self.calls.read_text().splitlines()
        self.assertEqual(len(calls), 1)
        self.assertIn('body', calls[0])

    def test_silent_gh_failure_is_operational_error(self):
        self.stub_gh('', status=1)
        result = self.run_helper(CONVENTION, '--mode', 'pr')
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('PR 0개', result.stdout)

    def test_empty_pr_history_is_insufficient_evidence(self):
        result = self.run_helper(CONVENTION, '--mode', 'pr')
        self.assertEqual(result.returncode, 2)
        self.assertIn('PR 0개', result.stdout)

    def test_title_only_pr_cannot_establish_body_structure(self):
        self.stub_gh(json.dumps([dict(number=1, title='Title only', body='')]))
        result = self.run_helper(CONVENTION, '--mode', 'pr')
        self.assertEqual(result.returncode, 2)

    def test_malformed_pr_response_is_operational_error(self):
        self.stub_gh('not-json')
        result = self.run_helper(CONVENTION, '--mode', 'pr')
        self.assertEqual(result.returncode, 1)

    def test_sample_size_must_be_positive_integer(self):
        for value in ('0', '-1', 'abc'):
            with self.subTest(value=value):
                result = self.run_helper(CONVENTION, '--mode', 'commit', value)
                self.assertEqual(result.returncode, 1)
                self.assertFalse(self.calls.exists())


if __name__ == '__main__':
    unittest.main()
