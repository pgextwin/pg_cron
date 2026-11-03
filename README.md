# pg_cron — Windows x64

[日本語](README_ja.md) | English

pgextwin publishes **unofficial Windows x64 binaries** of [pg_cron](https://github.com/citusdata/pg_cron). schedules SQL jobs inside PostgreSQL.

## Download

Choose your PostgreSQL major version from the [latest published Release](https://github.com/pgextwin/pg_cron/releases/latest), or [view earlier Releases](https://github.com/pgextwin/pg_cron/releases). PostgreSQL **14–18** packages are listed in the [pgextwin catalog](https://pgextwin.github.io/website/en/). PostgreSQL 14 community support ends November 12, 2026; existing downloads may remain available.

## Installation

1. Back up your environment and check the [upstream documentation](https://github.com/citusdata/pg_cron).
2. Stop PostgreSQL before replacing files. Extract the ZIP matching your PostgreSQL major version, then copy the packaged lib/ and share/extension/ files into the corresponding PostgreSQL directories.
3. Add pg_cron to shared_preload_libraries, set cron.database_name for the database where the extension is installed, and restart PostgreSQL. The upstream documentation explains job authentication, background workers, and security.
4. Start PostgreSQL with the required settings and run CREATE EXTENSION pg_cron; in the appropriate database.

Use the Release's SHA256SUMS.txt to verify downloaded files. Refer to the Release for SPDX SBOMs, vulnerability reports and any signed attestations. Test the extension before production use.

## License

The extension's behavior and limitations are documented by [upstream pg_cron](https://github.com/citusdata/pg_cron). This is an independent, unofficial Windows package. Consult the included license notices.
