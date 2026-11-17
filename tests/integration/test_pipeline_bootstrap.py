"""Checks that the pipeline can initialize a clean CI workspace."""

import unittest
from pathlib import Path


class PipelineBootstrapTests(unittest.TestCase):
    def test_report_directory_created_before_mktemp(self):
        script = Path(
            "scripts/security/security-pipeline.sh"
        ).read_text()

        mkdir = script.find("mkdir -p reports/pipeline")
        mktemp = script.find(
            "mktemp -d reports/pipeline/run-XXXXXXXX"
        )

        self.assertGreaterEqual(mkdir, 0)
        self.assertGreater(mktemp, mkdir)


if __name__ == "__main__":
    unittest.main()
