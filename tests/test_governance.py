import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class GovernanceTests(unittest.TestCase):
    def test_all_tagged_modules_enforce_the_baseline_tag_contract(self):
        tagged_modules = 0
        for variables_file in (ROOT / "modules").rglob("variables.tf"):
            content = variables_file.read_text(encoding="utf-8")
            if 'variable "tags"' not in content:
                continue
            tagged_modules += 1
            self.assertIn("validation {", content, str(variables_file))
            self.assertIn('lookup(var.tags, "environment", "")', content)
            self.assertIn('lookup(var.tags, "managed_by", "") == "terraform"', content)
        self.assertGreater(tagged_modules, 0)

    def test_composed_root_examples_supply_the_required_tags(self):
        composed_roots = 0
        for main_file in (ROOT / "environments").rglob("main.tf"):
            if not re.search(r'^\s*module\s+"', main_file.read_text(encoding="utf-8"), re.MULTILINE):
                continue
            example = main_file.parent / "terraform.tfvars.example"
            self.assertTrue(example.is_file(), str(example))
            content = example.read_text(encoding="utf-8")
            self.assertIn("environment =", content, str(example))
            self.assertIn('managed_by  = "terraform"', content, str(example))
            composed_roots += 1
        self.assertGreater(composed_roots, 0)


if __name__ == "__main__":
    unittest.main()
