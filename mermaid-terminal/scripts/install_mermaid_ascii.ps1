# Installs mermaid-ascii from GitHub releases (Windows)

$ErrorActionPreference = "Stop"

# Check if already installed
$existingCommand = Get-Command mermaid-ascii -ErrorAction SilentlyContinue
if ($existingCommand) {
    Write-Host "mermaid-ascii is already installed"
    & mermaid-ascii --help | Select-Object -First 1
    exit 0
}

# Check if installed in local programs directory
$localBin = Join-Path $env:LOCALAPPDATA "Programs\mermaid-ascii"
$localExe = Join-Path $localBin "mermaid-ascii.exe"
if (Test-Path $localExe) {
    Write-Host "mermaid-ascii is already installed at $localExe"
    exit 0
}

Write-Host "Installing mermaid-ascii..."

# Detect architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "i386" }

# Create temp directory
$tempDir = Join-Path $env:TEMP "mermaid-ascii-install-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Push-Location $tempDir

try {
    # Get latest release info
    Write-Host "Fetching latest release..."
    $releaseUrl = "https://api.github.com/repos/AlexanderGrooff/mermaid-ascii/releases/latest"
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "PowerShell" }

    # Find Windows asset
    $assetPattern = "Windows_$arch"
    $asset = $release.assets | Where-Object { $_.name -like "*$assetPattern*" } | Select-Object -First 1

    if (-not $asset) {
        Write-Host "Could not find release for Windows_$arch"
        Write-Host "Available assets:"
        $release.assets | ForEach-Object { Write-Host "  - $($_.name)" }
        Write-Host ""
        Write-Host "You may need to build from source: https://github.com/AlexanderGrooff/mermaid-ascii"
        exit 1
    }

    $downloadUrl = $asset.browser_download_url
    Write-Host "Downloading from: $downloadUrl"

    $zipFile = "mermaid-ascii.zip"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing

    Write-Host "Extracting..."
    Expand-Archive -Path $zipFile -DestinationPath "." -Force

    # Install to local programs directory
    New-Item -ItemType Directory -Path $localBin -Force | Out-Null

    # Find the executable (might be in root or subdirectory)
    $exe = Get-ChildItem -Path "." -Filter "mermaid-ascii.exe" -Recurse | Select-Object -First 1
    if (-not $exe) {
        Write-Host "Could not find mermaid-ascii.exe in archive"
        exit 1
    }

    Copy-Item -Path $exe.FullName -Destination $localExe -Force

    Write-Host "Installed mermaid-ascii to $localExe"
    Write-Host ""
    Write-Host "To add to PATH permanently, run:"
    Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$localBin', 'User')"
    Write-Host ""
    Write-Host "Or add to current session:"
    Write-Host "  `$env:PATH += ';$localBin'"
}
finally {
    Pop-Location
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
