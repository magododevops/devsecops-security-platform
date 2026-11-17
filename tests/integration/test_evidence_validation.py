"""Unit tests for fail-closed evidence validation."""

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path("scripts/security/validate-evidence.py")
spec = importlib.util.spec_from_file_location(
    "validate_evidence", SCRIPT
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TestEvidenceValidation(unittest.TestCase):
    def setUp(self):
        self.trivy = {
            "SchemaVersion": 2,
            "ArtifactName": "devsecops-go-api:lab",
            "Results": [
                {
                    "Target": "server",
                    "Class": "lang-pkgs",
                    "Vulnerabilities": [],
                }
            ],
        }

        self.zap = {
            "site": [
                {
                    "@name": "http://go-api:8080",
                    "alerts": [],
                }
            ],
        }

    def test_valid_reports(self):
        module.validate_trivy(self.trivy)
        module.validate_zap(self.zap)

    def test_trivy_missing_results(self):
        self.trivy["Results"] = []
        with self.assertRaises(ValueError):
            module.validate_trivy(self.trivy)

    def test_trivy_wrong_image(self):
        self.trivy["ArtifactName"] = "other-image:latest"
        with self.assertRaises(ValueError):
            module.validate_trivy(self.trivy)

    def test_trivy_invalid_schema(self):
        self.trivy["SchemaVersion"] = 999
        with self.assertRaises(ValueError):
            module.validate_trivy(self.trivy)

    def test_zap_missing_sites(self):
        self.zap["site"] = []
        with self.assertRaises(ValueError):
            module.validate_zap(self.zap)

    def test_zap_wrong_target(self):
        self.zap["site"][0]["@name"] = "http://other-app:8080"
        with self.assertRaises(ValueError):
            module.validate_zap(self.zap)

    def test_zap_missing_alerts(self):
        del self.zap["site"][0]["alerts"]
        with self.assertRaises(ValueError):
            module.validate_zap(self.zap)

    def test_zap_invalid_risk(self):
        self.zap["site"][0]["alerts"] = [
            {"pluginid": "10037", "riskcode": "INVALID"}
        ]
        with self.assertRaises(ValueError):
            module.validate_zap(self.zap)


if __name__ == "__main__":
    unittest.main()
