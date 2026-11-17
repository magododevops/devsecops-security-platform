"""Unit tests for security evidence image identity."""

import importlib.util
import unittest
from pathlib import Path

path = Path("scripts/security/audit-evidence.py")
spec = importlib.util.spec_from_file_location("audit_evidence", path)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

VALID_ID = "sha256:" + ("a" * 64)


class ImageIdentityTests(unittest.TestCase):
    def test_matching_ids(self):
        audit.verify_identity(VALID_ID, VALID_ID)

    def test_different_ids(self):
        with self.assertRaises(ValueError):
            audit.verify_identity(VALID_ID, "sha256:" + ("b" * 64))

    def test_missing_trivy_id(self):
        with self.assertRaises(ValueError):
            audit.verify_identity(None, VALID_ID)

    def test_invalid_image_id(self):
        with self.assertRaises(ValueError):
            audit.verify_identity("latest", VALID_ID)


if __name__ == "__main__":
    unittest.main()
