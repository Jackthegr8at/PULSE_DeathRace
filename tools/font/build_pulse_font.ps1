[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$SkipGodot
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$venvRoot = Join-Path $PSScriptRoot '.venv'
$venvPython = Join-Path $venvRoot 'Scripts\python.exe'
$requirements = Join-Path $PSScriptRoot 'requirements.txt'

if (-not (Test-Path -LiteralPath $venvPython)) {
    $systemPython = (Get-Command python -ErrorAction Stop).Source
    & $systemPython -m venv $venvRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create the local font-build Python environment.'
    }
}

if (-not $SkipInstall) {
    & $venvPython -m pip install --disable-pip-version-check --requirement $requirements
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to install the pinned font-build dependencies.'
    }
}

$commands = @(
    @((Join-Path $PSScriptRoot 'build_pulse_font.py'), '--repo-root', $repoRoot),
    @((Join-Path $PSScriptRoot 'validate_pulse_font.py'), '--repo-root', $repoRoot),
    @((Join-Path $PSScriptRoot 'render_pulse_specimen.py'), '--repo-root', $repoRoot)
)

foreach ($arguments in $commands) {
    $scriptPath = $arguments[0]
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Required font-build script is missing: $scriptPath"
    }
    & $venvPython @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Font-build command failed: $scriptPath"
    }
}

if (-not $SkipGodot) {
    $godot = 'D:\Godot_v4.7.1-stable_win64_console.exe'
    $proofScene = Join-Path $repoRoot 'scenes\ui\FontProof.tscn'
    if (-not (Test-Path -LiteralPath $godot)) {
        throw "Godot executable is missing: $godot"
    }
    if (-not (Test-Path -LiteralPath $proofScene)) {
        throw "Godot proof scene is missing: $proofScene"
    }
    & $godot --headless --path $repoRoot --quit-after 2 $proofScene
    if ($LASTEXITCODE -ne 0) {
        throw 'Godot font-proof validation failed.'
    }
}

Write-Host '[PulseFont] Build and validation completed successfully.' -ForegroundColor Green
