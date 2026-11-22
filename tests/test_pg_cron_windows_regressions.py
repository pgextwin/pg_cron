#!/usr/bin/env python3
"""pg_cron-specific Windows regression tests kept with the extension.

The shared required-windows summary cases live in pgextwin/build
(tests/test-required-windows-summary.py) and run once in build's validate
CI. These cases cover this extension's own hooks and workflows and keep
running in this repo's Windows required summary job.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PgCronWindowsRegressionTests(unittest.TestCase):
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

if __name__ == "__main__":
    unittest.main()
