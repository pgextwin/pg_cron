[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PgRoot,

    [Parameter(Mandatory = $true)]
    [int]$PgPort,

    [Parameter(Mandatory = $true)]
    [int]$PostgreSqlMajor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$initdb = Join-Path $PgRoot "bin\initdb.exe"
$pgCtl = Join-Path $PgRoot "bin\pg_ctl.exe"
$pgIsReady = Join-Path $PgRoot "bin\pg_isready.exe"
$psql = Join-Path $PgRoot "bin\psql.exe"

$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$dataDir = Join-Path $tempRoot "pg_hint_plan-pg$PostgreSqlMajor-data"
$logFile = Join-Path $tempRoot "pg_hint_plan-pg$PostgreSqlMajor.log"
$setupSql = Join-Path $tempRoot "pg_hint_plan-setup.sql"

if (Test-Path $dataDir) {
    Remove-Item $dataDir -Recurse -Force
}

& $initdb -D $dataDir -U postgres -A trust --encoding=UTF8 --no-locale
if ($LASTEXITCODE -ne 0) {
    throw "initdb failed."
}

function Show-PostgresLog {
    if (Test-Path $logFile) {
        Write-Host "----- PostgreSQL log -----"
        Get-Content $logFile -Tail 250
        Write-Host "--------------------------"
    }
}

function Wait-Postgres {
    for ($i = 0; $i -lt 45; $i++) {
        & $pgIsReady -h 127.0.0.1 -p $PgPort -q
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Seconds 2
    }

    Show-PostgresLog
    throw "Temporary PostgreSQL cluster did not become ready."
}

try {
    $serverOptions = "-p $PgPort -c shared_preload_libraries=pg_hint_plan"

    & $pgCtl -D $dataDir -l $logFile -o $serverOptions start
    if ($LASTEXITCODE -ne 0) {
        Show-PostgresLog
        throw "Failed to start PostgreSQL with pg_hint_plan preloaded."
    }

    Wait-Postgres

    @'
CREATE EXTENSION pg_hint_plan;
DROP TABLE IF EXISTS public.pgextwin_hint_test;
CREATE TABLE public.pgextwin_hint_test (
    id integer PRIMARY KEY,
    payload text NOT NULL
);
INSERT INTO public.pgextwin_hint_test
SELECT g, repeat('x', 50)
FROM generate_series(1, 5000) AS g;
ANALYZE public.pgextwin_hint_test;
'@ | Set-Content -Path $setupSql -Encoding utf8

    & $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -v ON_ERROR_STOP=1 -f $setupSql
    if ($LASTEXITCODE -ne 0) {
        throw "CREATE EXTENSION or test setup failed."
    }

    $plan = (& $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -Atqc "EXPLAIN (COSTS OFF) SELECT /*+ SeqScan(pgextwin_hint_test) */ * FROM public.pgextwin_hint_test WHERE id = 42;") -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) {
        throw "Hinted EXPLAIN failed."
    }

    Write-Host "Hinted plan:"
    Write-Host $plan

    if ($plan -notmatch "Seq Scan on pgextwin_hint_test") {
        Show-PostgresLog
        throw "pg_hint_plan did not force the expected sequential scan."
    }

    & $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -v ON_ERROR_STOP=1 -c "DROP TABLE public.pgextwin_hint_test; DROP EXTENSION pg_hint_plan;"
    if ($LASTEXITCODE -ne 0) {
        throw "pg_hint_plan smoke-test cleanup failed."
    }
}
catch {
    Show-PostgresLog
    throw
}
finally {
    if (Test-Path (Join-Path $dataDir "postmaster.pid")) {
        & $pgCtl -D $dataDir -m fast stop
    }
}
