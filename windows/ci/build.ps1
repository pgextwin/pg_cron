[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PgRoot,

    [Parameter(Mandatory = $true)]
    [string]$UpstreamDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
$vswhere = Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe was not found: $vswhere"
}

$vsRoot = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1).Trim()
if ([string]::IsNullOrWhiteSpace($vsRoot)) {
    throw "Visual Studio with the C++ x64 toolchain was not found."
}

$vsDevCmd = Join-Path $vsRoot "Common7\Tools\VsDevCmd.bat"
if (-not (Test-Path $vsDevCmd)) {
    throw "VsDevCmd.bat was not found: $vsDevCmd"
}

$pgConfig = Join-Path $PgRoot "bin\pg_config.exe"
$pgVersionText = (& $pgConfig --version).Trim()
if ($LASTEXITCODE -ne 0 -or $pgVersionText -notmatch 'PostgreSQL\s+(\d+)\.(\d+)') {
    throw "Could not determine PostgreSQL major/minor from pg_config: '$pgVersionText'"
}

$pgMajor = [int]$Matches[1]
$pgMinorPart = [int]$Matches[2]

if ($pgMajor -notin @(14, 15)) {
    throw "This probe build hook is intentionally limited to PostgreSQL 14 and 15."
}

$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }

$coreTag = "REL_{0}_{1}" -f $pgMajor, $pgMinorPart
$queryJumbleC = Join-Path $UpstreamDir "pgextwin_queryjumble.c"
$queryJumbleUrl = "https://raw.githubusercontent.com/postgres/postgres/$coreTag/src/backend/utils/misc/queryjumble.c"
Write-Host "Fetching matching PostgreSQL queryjumble source: $queryJumbleUrl"
Invoke-WebRequest -Uri $queryJumbleUrl -OutFile $queryJumbleC

if (-not (Test-Path $queryJumbleC)) {
    throw "Matching PostgreSQL queryjumble.c was not downloaded."
}

$sourceText = Get-Content (Join-Path $UpstreamDir "pg_hint_plan.c") -Raw
$exports = @("_PG_init")
if ($sourceText -match "\b_PG_fini\s*\(") {
    $exports += "_PG_fini"
}

$defPath = Join-Path $UpstreamDir "pg_hint_plan.pgextwin.def"
(@("LIBRARY pg_hint_plan", "EXPORTS") + @($exports | Sort-Object -Unique | ForEach-Object { "    $_" })) |
    Set-Content -Path $defPath -Encoding ascii

$cmdFile = Join-Path $tempRoot "pg_hint_plan-build.cmd"

@"
@echo off
call "$vsDevCmd" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%
cd /d "$UpstreamDir"
cl /nologo /DWIN32_NO_STATUS /Dstrcasecmp=_stricmp /DBUILDING_MODULE /DWIN32 /D_WINDOWS /DWIN32_STACK_RLIMIT=4194304 /D_CRT_SECURE_NO_DEPRECATE /D_CRT_NONSTDC_NO_DEPRECATE /I"$PgRoot\include\server\port\win32_msvc" /I"$PgRoot\include\server\port\win32" /I"$PgRoot\include\server" /I"$PgRoot\include" /I"$UpstreamDir" /c pg_hint_plan.c /Fopg_hint_plan.obj
if errorlevel 1 exit /b %errorlevel%
cl /nologo /DWIN32_NO_STATUS /DBUILDING_DLL /DWIN32 /D_WINDOWS /DWIN32_STACK_RLIMIT=4194304 /D_CRT_SECURE_NO_DEPRECATE /D_CRT_NONSTDC_NO_DEPRECATE /I"$PgRoot\include\server\port\win32_msvc" /I"$PgRoot\include\server\port\win32" /I"$PgRoot\include\server" /I"$PgRoot\include" /c pgextwin_queryjumble.c /Foqueryjumble.obj
if errorlevel 1 exit /b %errorlevel%
cl /nologo pg_hint_plan.obj queryjumble.obj "$PgRoot\lib\postgres.lib" "$PgRoot\lib\libintl.lib" ws2_32.lib /link /DLL /DEF:pg_hint_plan.pgextwin.def /OUT:pg_hint_plan.dll
"@ | Set-Content -Path $cmdFile -Encoding ascii

& cmd.exe /d /c $cmdFile
if ($LASTEXITCODE -ne 0) {
    throw "pg_hint_plan PostgreSQL $pgMajor MSVC build failed with exit code $LASTEXITCODE."
}

$dll = Join-Path $UpstreamDir "pg_hint_plan.dll"
if (-not (Test-Path $dll)) {
    throw "Expected pg_hint_plan.dll was not produced: $dll"
}
