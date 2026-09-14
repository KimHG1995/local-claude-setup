"""Run the configured hooks against disposable repositories; never run project yarn."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]


class HookTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="claude hooks ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve() / "project space"
        self.root.mkdir()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.branch("feature/example")
        shutil.copytree(SOURCE / ".claude" / "hooks", self.root / ".claude" / "hooks")
        self.bin = Path(self.tmp.name) / "bin"
        self.bin.mkdir()
        # Isolate executables so missing jq/yarn tests are independent of host installs.
        for name in ("bash", "cat", "jq", "git", "dirname", "basename", "grep", "head", "tail"):
            executable = shutil.which(name)
            self.assertIsNotNone(executable, f"test prerequisite missing: {name}")
            (self.bin / name).symlink_to(executable)
        yarn = self.bin / "yarn"
        yarn.write_text('#!/bin/bash\nprintf "%s\\n" "$PWD" "$@" > "$YARN_LOG"\nprintf "%s\\n" "$YARN_OUTPUT"\nexit "$YARN_STATUS"\n')
        yarn.chmod(0o755)
        self.log = Path(self.tmp.name) / "yarn.log"
        self.env = dict(os.environ, PATH=str(self.bin), CLAUDE_PROJECT_DIR=str(self.root),
                        YARN_LOG=str(self.log), YARN_OUTPUT="Done", YARN_STATUS="0")
        self.settings = json.loads((SOURCE / ".claude" / "settings.local.json").read_text())

    def branch(self, name):
        subprocess.run(["git", "-C", str(self.root), "symbolic-ref", "HEAD", f"refs/heads/{name}"], check=True)

    def run_hook(self, script, path="src/item.ts", *, raw=None, cwd=None, configured=False):
        event = "PreToolUse" if script.startswith("pre-") else "PostToolUse"
        payload = {"hook_event_name": event, "cwd": str(cwd or self.root),
                   "tool_name": "Write", "tool_input": {"file_path": str(self.root / path)}}
        command = ["/bin/bash", str(self.root / ".claude" / "hooks" / script)]
        if configured:
            hooks = self.settings["hooks"][event]
            command_text = next(h["command"] for group in hooks for h in group["hooks"] if script in h["command"])
            command = ["/bin/bash", "-c", command_text]
        return subprocess.run(command, input=json.dumps(payload) if raw is None else raw,
                              text=True, capture_output=True, cwd=cwd or self.root, env=self.env)

    def context(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        try:
            output = json.loads(result.stdout)
        except json.JSONDecodeError:
            self.fail(f"Expected model-visible JSON, got {result.stdout!r}")
        self.assertEqual(output["hookSpecificOutput"]["hookEventName"], "PostToolUse")
        return output["hookSpecificOutput"]["additionalContext"]

    def test_protected_branches_block_new_nested_paths(self):
        for branch in ("main", "master"):
            with self.subTest(branch=branch):
                self.branch(branch)
                result = self.run_hook("pre-edit-branch-check.sh", "new/nested/item.ts")
                self.assertEqual(result.returncode, 2)
                self.assertIn(branch, result.stderr)
                self.assertEqual(result.stdout, "")

    def test_existing_file_on_main_is_blocked(self):
        self.branch("main")
        (self.root / "item.ts").write_text("export {};\n")
        result = self.run_hook("pre-edit-branch-check.sh", "item.ts")
        self.assertEqual(result.returncode, 2)
        self.assertIn("main", result.stderr)

    def test_unprotected_branch_and_non_git_directory_pass(self):
        for branch in ("feature/example", "hotfix/example", "develop"):
            self.branch(branch)
            result = self.run_hook("pre-edit-branch-check.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        result = self.run_hook("pre-edit-branch-check.sh", str(outside / "new.ts"), cwd=outside)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_settings_commands_work_from_subdirectory_with_spaces(self):
        subdir = self.root / "nested space"
        subdir.mkdir()
        for script, path in (("pre-edit-branch-check.sh", "item.ts"),
                             ("post-edit-typecheck.sh", "item.ts"),
                             ("post-edit-test.sh", "item.spec.ts")):
            with self.subTest(script=script):
                result = self.run_hook(script, path, cwd=subdir, configured=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                if script.startswith("post"):
                    self.context(result)

    def test_non_git_target_does_not_inherit_payload_repository(self):
        self.branch("main")
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        for script, name in (("pre-edit-branch-check.sh", "new/nested/item.ts"),
                             ("post-edit-typecheck.sh", "item.ts"),
                             ("post-edit-test.sh", "item.spec.ts")):
            with self.subTest(script=script):
                result = self.run_hook(script, str(outside / name))
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        self.assertFalse(self.log.exists())

    def test_typecheck_success_has_no_grep_zero_arithmetic_error(self):
        context = self.context(self.run_hook("post-edit-typecheck.sh", "item.ts"))
        self.assertIn("통과", context)
        self.assertEqual(self.log.read_text().splitlines(), [str(self.root), "typecheck"])

    def test_typecheck_exit_status_overrides_missing_ts_diagnostics(self):
        self.env.update(YARN_STATUS="1", YARN_OUTPUT='Usage Error: missing script "typecheck"')
        context = self.context(self.run_hook("post-edit-typecheck.sh", "item.ts"))
        self.assertIn("Usage Error", context)
        self.assertNotIn("통과", context)

    def test_typecheck_reports_ts_error_count(self):
        self.env.update(YARN_STATUS="2", YARN_OUTPUT="src/item.ts(1,1): error TS2322: wrong type\nsrc/item.ts(2,1): error TS2304: missing name")
        context = self.context(self.run_hook("post-edit-typecheck.sh", "item.ts"))
        self.assertIn("2건", context)
        self.assertIn("TS2322", context)

    def test_post_hooks_keep_command_not_found_diagnostics(self):
        (self.bin / "yarn").unlink()
        for script, path in (("post-edit-typecheck.sh", "item.ts"), ("post-edit-test.sh", "item.spec.ts")):
            with self.subTest(script=script):
                context = self.context(self.run_hook(script, path))
                self.assertIn("yarn", context)
                self.assertIn("127", context)
                self.assertNotIn("통과", context)

    def test_spec_test_quotes_path_and_runs_from_repo_root(self):
        context = self.context(self.run_hook("post-edit-test.sh", "new folder/item name.spec.ts"))
        self.assertIn("통과", context)
        self.assertEqual(self.log.read_text().splitlines(),
                         [str(self.root), "test", "new folder/item name.spec.ts", "--no-coverage"])

    def test_test_failure_keeps_unfiltered_diagnostics(self):
        self.env.update(YARN_STATUS="1", YARN_OUTPUT="script unavailable: test\nplease configure package scripts")
        context = self.context(self.run_hook("post-edit-test.sh", "item.spec.ts"))
        self.assertIn("script unavailable", context)
        self.assertNotIn("통과", context)

    def test_large_failure_output_remains_model_visible(self):
        diagnostics = Path(self.tmp.name) / "diagnostics.txt"
        content = "diagnostic line\n" * 150000 + "END_OF_DIAGNOSTICS"
        diagnostics.write_text(content)
        (self.bin / "yarn").write_text('#!/bin/bash\ncat "$YARN_DIAGNOSTICS_FILE"\nexit 1\n')
        self.env["YARN_DIAGNOSTICS_FILE"] = str(diagnostics)
        for script, path in (("post-edit-typecheck.sh", "item.ts"),
                             ("post-edit-test.sh", "item.spec.ts")):
            with self.subTest(script=script):
                context = self.context(self.run_hook(script, path))
                self.assertIn(content, context)
                self.assertNotIn("통과", context)

    def test_relative_path_uses_payload_cwd(self):
        subdir = self.root / "src"
        subdir.mkdir()
        payload = json.dumps({"cwd": str(subdir), "tool_input": {"file_path": "new dir/item.spec.ts"}})
        self.context(self.run_hook("post-edit-test.sh", raw=payload))
        self.assertEqual(self.log.read_text().splitlines()[2], "src/new dir/item.spec.ts")

    def test_triggers_remain_lightweight(self):
        for script, paths in (("post-edit-typecheck.sh", ["x.spec.ts", "x.d.ts", "x.js"]),
                              ("post-edit-test.sh", ["x.ts", "x.d.ts", "x.test.ts"])):
            for path in paths:
                result = self.run_hook(script, path)
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        self.assertFalse(self.log.exists())

    def test_malformed_input_is_visible_per_hook_event(self):
        for raw in ("{bad", '{"tool_input":{"file_path":42}}'):
            result = self.run_hook("pre-edit-branch-check.sh", raw=raw)
            self.assertEqual(result.returncode, 2)
            self.assertTrue(result.stderr)
            self.assertTrue(self.context(self.run_hook("post-edit-typecheck.sh", raw=raw)))
        self.assertFalse(self.log.exists())

    def test_missing_jq_is_visible_per_hook_event(self):
        (self.bin / "jq").unlink()
        for script, code in (("pre-edit-branch-check.sh", 2), ("post-edit-typecheck.sh", 1)):
            result = self.run_hook(script)
            self.assertEqual(result.returncode, code)
            self.assertIn("jq", result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
