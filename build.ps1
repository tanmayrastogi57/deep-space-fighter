$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectRoot

python -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) {
    throw "Tests failed; package build stopped."
}

python -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('PyInstaller') else 1)"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing build-only PyInstaller dependency..."
    python -m pip install ".[build]"
}

python -m PyInstaller `
    --noconfirm `
    --clean `
    --windowed `
    --onedir `
    --name "ASCII Rocket" `
    run_game.py

Write-Host "Build complete: $projectRoot\dist\ASCII Rocket\ASCII Rocket.exe"
