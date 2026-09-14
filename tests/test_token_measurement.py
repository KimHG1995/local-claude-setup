import importlib.util
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "measure-skill-tokens.py"


def load_module():
	spec = importlib.util.spec_from_file_location("measure_skill_tokens", SCRIPT)
	module = importlib.util.module_from_spec(spec)
	assert spec.loader is not None
	sys.modules[spec.name] = module
	spec.loader.exec_module(module)
	return module


class ImportTests(unittest.TestCase):
	def test_import_does_not_require_tiktoken(self):
		with mock.patch.dict(sys.modules, {"tiktoken": None}):
			load_module()


class MeasurementTests(unittest.TestCase):
	def setUp(self):
		self.module = load_module()
		self.temp_dir = tempfile.TemporaryDirectory()
		self.root = Path(self.temp_dir.name)

	def tearDown(self):
		self.temp_dir.cleanup()

	def write(self, relative_path, text):
		path = self.root / relative_path
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(text, encoding="utf-8")
		return path

	def write_skill(self, name, body="choose route\n", reference="reference details here\n"):
		self.write(
			f".claude/skills/{name}/SKILL.md",
			f"---\nname: {name}\ndescription: demo\n---\n{body}",
		)
		if reference is not None:
			self.write(f".claude/skills/{name}/references/guide.md", reference)

	def test_discovers_both_project_instruction_locations_and_only_unscoped_rules(self):
		self.write("CLAUDE.md", "root instructions\n")
		self.write(".claude/CLAUDE.md", "local instructions\n")
		self.write(".claude/rules/plain.md", "plain global rule\n")
		self.write(
			".claude/rules/metadata.md",
			'---\ndescription: "mentions paths: but has no scope"\n---\nglobal rule\n',
		)
		self.write(
			".claude/rules/scoped.md",
			'---\npaths:\n  - "src/**/*.ts"\n---\nscoped rule\n',
		)

		found = self.module.discover_static_instruction_files(self.root)

		self.assertEqual(
			[
				Path("CLAUDE.md"),
				Path(".claude/CLAUDE.md"),
				Path(".claude/rules/metadata.md"),
				Path(".claude/rules/plain.md"),
			],
			[path.relative_to(self.root) for path in found],
		)

	def test_measurement_separates_static_metadata_router_and_reference_costs(self):
		self.write(".claude/CLAUDE.md", "project instructions\n")
		self.write(".claude/rules/global.md", "always rule\n")
		self.write_skill("sample")

		report = self.module.measure_repository(self.root, lambda text: len(text.split()))

		self.assertEqual(4, report.static_tokens)
		self.assertEqual(4, report.skill_metadata_tokens)
		self.assertEqual(1, len(report.skills))
		self.assertEqual("sample", report.skills[0].name)
		self.assertEqual(2, report.skills[0].router.tokens)
		self.assertEqual(3, report.skills[0].references[0].tokens)

	def test_router_budget_allows_350_proxy_tokens_and_rejects_351(self):
		self.write_skill("at-limit", body="x" * 350, reference=None)
		self.write_skill("over-limit", body="x" * 351, reference=None)

		report = self.module.measure_repository(self.root, len)

		self.assertEqual(("over-limit",), report.over_budget)

	def test_skill_without_frontmatter_is_rejected(self):
		path = self.write(".claude/skills/broken/SKILL.md", "choose route\n")

		with self.assertRaisesRegex(ValueError, "frontmatter"):
			self.module.split_frontmatter(path)

	def test_missing_tokenizer_returns_actionable_error(self):
		self.write_skill("sample", reference=None)

		def unavailable():
			raise self.module.TokenizerUnavailable("missing")

		stderr = io.StringIO()
		with redirect_stderr(stderr):
			status = self.module.main(["--root", str(self.root)], tokenizer_factory=unavailable)

		self.assertEqual(2, status)
		self.assertIn("tiktoken", stderr.getvalue())
		self.assertIn("--inventory", stderr.getvalue())

	def test_inventory_does_not_load_tokenizer(self):
		self.write(".claude/CLAUDE.md", "one line\nsecond line\n")
		self.write_skill("sample", reference=None)

		def must_not_run():
			raise AssertionError("inventory loaded the tokenizer")

		stdout = io.StringIO()
		with redirect_stdout(stdout):
			status = self.module.main(
				["--inventory", "--root", str(self.root)],
				tokenizer_factory=must_not_run,
			)

		self.assertEqual(0, status)
		self.assertIn("bytes", stdout.getvalue())
		self.assertIn("lines", stdout.getvalue())
		self.assertIn("350", stdout.getvalue())


if __name__ == "__main__":
	unittest.main()
