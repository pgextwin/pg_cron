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

$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$flexRoot = Join-Path $tempRoot "winflexbison-2.5.24"
$flexZip = Join-Path $tempRoot "win_flex_bison-2.5.24.zip"
$flexExe = Join-Path $flexRoot "win_flex.exe"

if (-not (Test-Path $flexExe)) {
    Invoke-WebRequest -Uri "https://github.com/lexxmark/winflexbison/releases/download/v2.5.24/win_flex_bison-2.5.24.zip" -OutFile $flexZip

    $expectedHash = "39C6086CE211D5415500ACC5ED2D8939861CA1696AEE48909C7F6DAF5122B505"
    $actualHash = (Get-FileHash $flexZip -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw "WinFlexBison SHA256 mismatch. Expected $expectedHash, got $actualHash."
    }

    if (Test-Path $flexRoot) {
        Remove-Item $flexRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $flexRoot | Out-Null
    Expand-Archive -Path $flexZip -DestinationPath $flexRoot -Force
}

if (-not (Test-Path $flexExe)) {
    throw "win_flex.exe was not found after extraction: $flexExe"
}

$queryScanC = Join-Path $UpstreamDir "query_scan.c"
& $flexExe "--outfile=$queryScanC" (Join-Path $UpstreamDir "query_scan.l")
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $queryScanC)) {
    throw "Failed to generate query_scan.c with WinFlexBison."
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
cl /nologo /DWIN32_NO_STATUS /Dstrcasecmp=_stricmp /DBUILDING_MODULE /DWIN32 /D_WINDOWS /DWIN32_STACK_RLIMIT=4194304 /D_CRT_SECURE_NO_DEPRECATE /D_CRT_NONSTDC_NO_DEPRECATE /I"$PgRoot\include\server\port\win32_msvc" /I"$PgRoot\include\server\port\win32" /I"$PgRoot\include\server" /I"$PgRoot\include" /I"$UpstreamDir" /c query_scan.c /Foquery_scan.obj
if errorlevel 1 exit /b %errorlevel%
cl /nologo pg_hint_plan.obj query_scan.obj "$PgRoot\lib\postgres.lib" "$PgRoot\lib\libintl.lib" ws2_32.lib /link /DLL /DEF:pg_hint_plan.pgextwin.def /OUT:pg_hint_plan.dll
"@ | Set-Content -Path $cmdFile -Encoding ascii

& cmd.exe /d /c $cmdFile
if ($LASTEXITCODE -ne 0) {
    throw "pg_hint_plan MSVC build failed with exit code $LASTEXITCODE."
}

$dll = Join-Path $UpstreamDir "pg_hint_plan.dll"
if (-not (Test-Path $dll)) {
    throw "Expected pg_hint_plan.dll was not produced: $dll"
}
