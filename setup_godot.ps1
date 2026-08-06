param(
    [string]$Version = "4.7.1"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolRoot = Join-Path $projectRoot ".tools\godot-$Version"
$releaseName = "$Version-stable"
$editorZip = Join-Path $toolRoot "godot.zip"
$templateArchive = Join-Path $toolRoot "templates.tpz"
$editorExe = Join-Path $toolRoot "Godot_v$releaseName`_win64.exe"
$templateRoot = Join-Path $toolRoot "editor_data\export_templates\$Version.stable"
$releaseTemplate = Join-Path $templateRoot "windows_release_x86_64.exe"
$releaseBaseUrl = "https://godot-releases.nbg1.your-objectstorage.com/$releaseName"

New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null

if (-not (Test-Path $editorExe)) {
    Write-Host "Downloading Godot $Version editor..."
    Start-BitsTransfer -DisplayName "Deep Space Fighter Godot Editor" -Source "$releaseBaseUrl/Godot_v$releaseName`_win64.exe.zip" -Destination $editorZip
    Expand-Archive -LiteralPath $editorZip -DestinationPath $toolRoot -Force
}

$selfContainedMarker = Join-Path $toolRoot "_sc_"
if (-not (Test-Path $selfContainedMarker)) {
    [System.IO.File]::WriteAllText($selfContainedMarker, "; Deep Space Fighter portable Godot toolchain.`n")
}

if (-not (Test-Path $releaseTemplate)) {
    Write-Host "Downloading Godot $Version export templates (large one-time download)..."
    Start-BitsTransfer -DisplayName "Deep Space Fighter Godot Templates" -Source "$releaseBaseUrl/Godot_v$releaseName`_export_templates.tpz" -Destination $templateArchive
    New-Item -ItemType Directory -Path $templateRoot -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($templateArchive)
    try {
        foreach ($entryName in @("templates/version.txt", "templates/windows_debug_x86_64.exe", "templates/windows_release_x86_64.exe")) {
            $entry = $archive.GetEntry($entryName)
            if (-not $entry) {
                throw "Export template archive is missing $entryName"
            }
            $destination = Join-Path $templateRoot ([System.IO.Path]::GetFileName($entryName))
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
        }
    } finally {
        $archive.Dispose()
    }
}

if (Test-Path $editorZip) {
    [System.IO.File]::Delete($editorZip)
}
if (Test-Path $templateArchive) {
    [System.IO.File]::Delete($templateArchive)
}

& $editorExe --version
Write-Host "Godot is ready at: $editorExe"

