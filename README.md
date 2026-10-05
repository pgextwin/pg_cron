# pg_cron Windows binaries

[日本語](README_ja.md) | **English**

This repository provides **unofficial Windows x64 binaries** of [pg_cron](https://github.com/citusdata/pg_cron).

pg_cron itself is developed and maintained upstream by the pg_cron/Citus Data community. For pg_cron behavior, SQL APIs, configuration parameters, limitations, and security semantics, the **upstream pg_cron documentation is authoritative**.

## Upstream

- Repository: https://github.com/citusdata/pg_cron
- Source used by this repository: **v1.6.8**
- Upstream commit pinned by the tag: **5cedfa472ccc83567aa23ec645925ed8489a7797**
- License: PostgreSQL-style permissive license, identical to upstream
- Native Windows support: added upstream in pg_cron **v1.6.8**

The CI/CD pipeline checks out the pinned upstream tag. This repository does not vendor a forked copy of pg_cron's C sources.

## Documentation

- [Japanese README / 日本語README](README_ja.md)
- [Windows x64 binary guide / Windows x64 バイナリ利用ガイド（日本語）](docs/windows_ja.md)
- [Official pg_cron README](https://github.com/citusdata/pg_cron/blob/v1.6.8/README.md)
- [Official pg_cron changelog](https://github.com/citusdata/pg_cron/blob/v1.6.8/CHANGELOG.md)

Use this repository for Windows package placement and pgextwin-specific build information. Use upstream documentation for pg_cron product behavior and configuration.

## Supported PostgreSQL versions

Windows binaries are built only for PostgreSQL major versions that are still under PostgreSQL community maintenance on the build date.

As of 2026-10-06:

| PostgreSQL | Tested minor | Community EOL |
|---|---:|---:|
| 14 | 14.24 | 2026-11-12 |
| 15 | 15.19 | 2027-11-11 |
| 16 | 16.15 | 2028-11-09 |
| 17 | 17.11 | 2029-11-08 |
| 18 | 18.6 | 2030-11-14 |

PostgreSQL lifecycle metadata is maintained centrally in **pgextwin/build**. This repository declares pg_cron's allowed range in [config/extension.json](config/extension.json). PostgreSQL 14 is currently included, but the shared workflow automatically excludes entries after their configured community EOL date.

Only **Windows x64** packages are published.

## Download

Download the ZIP matching your PostgreSQL major version from this repository's **Releases** page.

Asset names follow this pattern:

~~~text
pg_cron-v1.6.8-pg18-windows-x64.zip
~~~

Each ZIP contains:

~~~text
lib/
  pg_cron.dll
share/
  extension/
    pg_cron.control
    pg_cron--1.0.sql
    pg_cron--*--*.sql
LICENSE
UPSTREAM-README.md
UPSTREAM-CHANGELOG.md
PACKAGE-INFO.txt
~~~

## Installation

1. Stop PostgreSQL before replacing extension binaries.
2. Extract the ZIP for the same PostgreSQL major version as your installation.
3. Copy **lib/pg_cron.dll** to PostgreSQL's **lib** directory.
4. Copy the files under **share/extension/** to PostgreSQL's **share/extension** directory.
5. Add pg_cron to `shared_preload_libraries` in `postgresql.conf`.
6. Optionally configure `cron.database_name`, `cron.timezone`, `cron.use_background_workers`, and other upstream settings.
7. Restart PostgreSQL.
8. In the database configured by `cron.database_name`, run:

~~~sql
CREATE EXTENSION pg_cron;
~~~

pg_cron may only be installed in one database in a PostgreSQL cluster. Jobs for other databases can be scheduled with upstream's `cron.schedule_in_database()`.

By default pg_cron opens local libpq connections for jobs, so the relevant `pg_hba.conf` and password/`.pgpass` configuration must permit those connections. Alternatively, pg_cron can execute jobs through PostgreSQL background workers by setting:

~~~conf
cron.use_background_workers = on
~~~

When background workers are used, ensure `max_worker_processes` is large enough for the required concurrency.

See [docs/windows_ja.md](docs/windows_ja.md) and the official pg_cron README for complete setup details.

## PostgreSQL 14/15 Windows compatibility

pg_cron v1.6.8 added official native Windows support. PostgreSQL 16 and newer automatically export SQL-callable extension functions through `PG_FUNCTION_INFO_V1()` on Windows, while PostgreSQL 14/15 do not.

For PostgreSQL 14/15 only, the pgextwin build hook therefore:

1. discovers SQL functions declared with `PG_FUNCTION_INFO_V1(...)`,
2. generates a temporary DLL export definition file,
3. exports `_PG_init` and the SQL-callable functions,
4. creates a temporary copy of upstream `Makefile.win` that adds the linker `/DEF` option.

The upstream C source is not modified or vendored. PostgreSQL 16–18 use upstream `Makefile.win` unchanged.

The compatibility path was validated through actual `CREATE EXTENSION pg_cron` and scheduled-job execution on PostgreSQL 14 and 15.

## CI/CD

[.github/workflows/windows.yml](.github/workflows/windows.yml) delegates common CI/CD mechanics to the reusable workflow in **pgextwin/build**.

For each eligible PostgreSQL major version, CI:

1. resolves the maintained PostgreSQL matrix,
2. checks out pg_cron v1.6.8,
3. verifies this repository's LICENSE against upstream,
4. installs the matching Windows PostgreSQL distribution,
5. invokes the hooks under **windows/ci/**,
6. builds pg_cron with MSVC/nmake,
7. starts PostgreSQL with `shared_preload_libraries=pg_cron`,
8. runs `CREATE EXTENSION pg_cron`,
9. schedules a one-second job and verifies that it actually executes,
10. packages and uploads one Windows x64 ZIP per PostgreSQL major.

Pull requests and pushes to **main** run validation only.

To publish a GitHub Release, create a branch from the desired **main** commit named:

~~~text
release/<release-tag>
~~~

For the first pgextwin release:

~~~text
release/v1.6.8-windows.1
~~~

After every supported PostgreSQL build and functional test succeeds, the shared workflow publishes all ZIPs plus `SHA256SUMS.txt`. The Release body is English first and Japanese second.

## Updating pg_cron

When upstream publishes a new release:

1. update `upstream.ref` and `upstream.version` in [config/extension.json](config/extension.json),
2. review whether upstream Windows build behavior changed,
3. specifically re-check whether the PostgreSQL 14/15 compatibility export path is still required,
4. update the documentation,
5. run the complete maintained PostgreSQL matrix,
6. publish a new Windows Release only after all functional tests pass.

## License

This repository uses the same license text as upstream pg_cron. See [LICENSE](LICENSE).

Release packages copy **LICENSE** directly from the pinned upstream source checkout.

These binaries are unofficial pgextwin builds and are not official binary releases from the upstream pg_cron project.
