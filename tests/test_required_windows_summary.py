#!/usr/bin/env python3
"""Test the exact stable aggregate check used by Windows CI, without Release."""
import importlib.util
from pathlib import Path
import os
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "summary", ROOT / "scripts" / "required_windows_summary.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WindowsSummaryTests(unittest.TestCase):
    def test_success_only(self):
        self.assertTrue(module.verified_matrix_result("success"))
        for value in ("failure", "cancelled", "skipped", "", "Success",
                      "success ", True, 1, None):
            with self.subTest(value=value):
                self.assertFalse(module.verified_matrix_result(value))

    def test_real_exit_status_allow_and_deny(self):
        path = ROOT / "scripts" / "required_windows_summary.py"
        for value, expected in (("success", 0), ("failure", 2),
                                ("cancelled", 2), ("skipped", 2), ("", 2)):
            env = dict(os.environ, WINDOWS_MATRIX_RESULT=value)
            res = subprocess.run([sys.executable, str(path)], env=env,
                                 capture_output=True, text=True)
            with self.subTest(result=value):
                self.assertEqual(res.returncode, expected)

    def test_pg_cron_smoke_uses_os_allocated_loopback_port_without_skipping_sql(self):
        # Windows hosted runners sometimes block the fixed matrix port 55432.
        # A successful ephemeral loopback bind ensures the same port is then
        # passed to PostgreSQL, readiness checks and the genuine cron SQL test.
        script = (ROOT / "windows" / "ci" / "smoke-test.ps1").read_text()
        for expected in (
            "[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)",
            "$portProbe.Start()", "$portProbe.Stop()",
            "$PgPort = ([System.Net.IPEndPoint]$portProbe.LocalEndpoint).Port",
            'if ($PgPort -lt 1024 -or $PgPort -gt 65535)',
            "-p $PgPort", "& $pgCtl", "& $pgIsReady", "& $psql",
            "CREATE EXTENSION pg_cron;", "SELECT cron.schedule(",
            "pg_cron scheduled job did not execute",
        ):
            with self.subTest(marker=expected):
                self.assertIn(expected, script)
        self.assertGreaterEqual(script.count("-p $PgPort"), 4)
        self.assertNotIn("cron.use_background_workers=off", script)

    def test_workflow_depends_on_complete_reusable_matrix_not_pg14_name(self):
        contents = (ROOT / ".github" / "workflows" / "windows.yml").read_text()
        self.assertIn("  windows_required:", contents)
        summary = contents.split("  windows_required:", 1)[1].split(
            "\n  candidate_report:", 1)[0]
        self.assertIn("name: Windows required summary", summary)
        self.assertIn("needs: windows", summary)
        self.assertIn("always()", summary)
        self.assertIn("needs.windows.result", summary)
        self.assertIn("scripts/required_windows_summary.py", summary)
        self.assertNotIn("PostgreSQL 14", summary)
        self.assertNotIn("workflow_dispatch:", summary)


if __name__ == "__main__":
    unittest.main()
