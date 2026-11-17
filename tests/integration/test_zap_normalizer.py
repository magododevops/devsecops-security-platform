#!/usr/bin/env python3
"""Tests for ZAP finding normalization."""

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path("scripts/security/normalize-zap.py")

spec = importlib.util.spec_from_file_location(
    "normalize_zap", SCRIPT
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TestZAPNormalizer(unittest.TestCase):
    def test_information_does_not_become_unknown(self):
        report = {
            "site": [{
                "@name": "http://go-api:8080",
                "alerts": [{
                    "pluginid": "10111",
                    "riskcode": "0",
                }],
            }],
        }

        result = module.normalize(report)
        self.assertEqual(result["findings"], [])

    def test_high_risk_is_preserved(self):
        report = {
            "site": [{
                "@name": "http://go-api:8080",
                "alerts": [{
                    "pluginid": "40012",
                    "riskcode": "3",
                }],
            }],
        }

        result = module.normalize(report)
        self.assertEqual(result["findings"], [{
            "id": "ZAP-40012",
            "severity": "HIGH",
        }])

    def test_missing_site_fails_closed(self):
        with self.assertRaises(ValueError):
            module.normalize({"site": []})


if __name__ == "__main__":
    unittest.main()
