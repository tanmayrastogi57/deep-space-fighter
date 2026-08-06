$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$localEditor = Join-Path $projectRoot ".tools\godot-4.7.1\Godot_v4.7.1-stable_win64.exe"
$godotCommand = $null

if (Test-Path $localEditor) {
    $godotCommand = $localEditor
} else {
    $installedCommand = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installedCommand) {
        $godotCommand = $installedCommand.Source
    }
}

if (-not $godotCommand) {
    throw "Godot 4 was not found. Run .\setup_godot.ps1 first."
}

& $godotCommand --path $projectRoot

