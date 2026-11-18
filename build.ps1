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

function Invoke-FlightTest([string]$scene, [int]$frames = 1800) {
    $result = & $godotCommand --headless --path $projectRoot --fixed-fps 60 --quit-after $frames $scene 2>&1 | Out-String
    $result | Write-Host
    if ($LASTEXITCODE -ne 0 -or $result -match "SCRIPT ERROR|(?m)^ERROR:" -or $result -notmatch "(?m)^PASS:") {
        throw "Godot test failed or did not finish: $scene"
    }
}

Invoke-FlightTest "res://tests_godot/test_runner.tscn"
Invoke-FlightTest "res://tests_godot/smoke_test.tscn"
Invoke-FlightTest "res://tests_godot/menu_flow.tscn"
Invoke-FlightTest "res://tests_godot/flight_art_test.tscn" 7800

$outputDirectory = Join-Path $projectRoot "dist\Deep Space Fighter"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$outputExe = Join-Path $outputDirectory "Deep Space Fighter.exe"

& $godotCommand --headless --path $projectRoot --export-release "Windows Desktop" $outputExe
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputExe)) {
    throw "Godot Windows export failed. Run .\setup_godot.ps1 to install export templates."
}

Write-Host "Built: $outputExe"
