$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$localConsole = Join-Path $projectRoot ".tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$godotCommand = $null

if (Test-Path $localConsole) {
    $godotCommand = $localConsole
} else {
    $installedCommand = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installedCommand) {
        $godotCommand = $installedCommand.Source
    }
}

if (-not $godotCommand) {
    throw "Godot 4 was not found. Run .\setup_godot.ps1 first."
}

$parseOutput = & $godotCommand --headless --path $projectRoot --editor --quit 2>&1 | Out-String
$parseOutput | Write-Host
if ($parseOutput -match "SCRIPT ERROR|Failed to load script") {
    throw "Godot script validation failed."
}

& $godotCommand --headless --path $projectRoot res://tests_godot/test_runner.tscn
if ($LASTEXITCODE -ne 0) {
    throw "Deterministic tests failed."
}

& $godotCommand --headless --path $projectRoot res://tests_godot/smoke_test.tscn
if ($LASTEXITCODE -ne 0) {
    throw "3D scene smoke test failed."
}

$outputDirectory = Join-Path $projectRoot "dist\Deep Space Fighter"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$outputExe = Join-Path $outputDirectory "Deep Space Fighter.exe"

& $godotCommand --headless --path $projectRoot --export-release "Windows Desktop" $outputExe
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputExe)) {
    throw "Godot Windows export failed. Run .\setup_godot.ps1 to install export templates."
}

Write-Host "Built: $outputExe"
