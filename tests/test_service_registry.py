import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "templates" / "service-registry.py"
SPEC = importlib.util.spec_from_file_location("service_registry", REGISTRY)
service_registry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(service_registry)


def run_registry(*arguments):
    return subprocess.run(
        [sys.executable, str(REGISTRY), *arguments],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


class ServiceRegistryTests(unittest.TestCase):
    def test_registry_is_valid(self):
        result = run_registry("validate")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_registry_rejects_dependencies_that_conflict_with_deployment_order(self):
        catalog = json.loads(
            (ROOT / "service-registry" / "services.json").read_text(
                encoding="utf-8"
            )
        )
        catalog["layer_dependencies"]["compute"] = ["operations"]
        errors = service_registry.validate_registry(catalog)
        self.assertTrue(any("must precede layer 'compute'" in error for error in errors))

    def test_resolves_provider_specific_modules_to_shared_layer(self):
        for provider in ("azure", "aws"):
            with self.subTest(provider=provider):
                result = run_registry("resolve", "network", provider, "dev")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "network")

    def test_service_resolution_includes_declared_prerequisite_layers(self):
        result = run_registry("resolve", "compute", "aws", "dev")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["network", "compute"])

    def test_rejects_services_without_environment_roots(self):
        result = run_registry("resolve", "application-storage", "aws", "prod")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not registered for prod", result.stderr)

    def test_deployment_order_includes_dev_compatibility_layer_only_in_dev(self):
        dev_layers = run_registry("layers", "dev")
        prod_layers = run_registry("layers", "prod")
        self.assertEqual(dev_layers.returncode, 0, dev_layers.stderr)
        self.assertEqual(prod_layers.returncode, 0, prod_layers.stderr)
        self.assertTrue(dev_layers.stdout.strip().endswith("application"))
        self.assertNotIn("application", prod_layers.stdout.splitlines())


if __name__ == "__main__":
    unittest.main()
