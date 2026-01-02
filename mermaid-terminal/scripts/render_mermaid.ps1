# Renders a Mermaid diagram as ASCII art in the terminal (Windows)
# Usage: render_mermaid.ps1 <mermaid_file> [options]
#        Get-Content diagram.mermaid | render_mermaid.ps1 - [options]

param(
    [Parameter(Position=0)]
    [string]$InputFile,

    [Parameter()]
    [int]$x = -1,

    [Parameter()]
    [int]$y = -1,

    [Parameter()]
    [int]$p = 1,

    [Parameter()]
    [switch]$ascii
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find mermaid-ascii binary
function Find-MermaidAscii {
    $cmd = Get-Command mermaid-ascii -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $localExe = Join-Path $env:LOCALAPPDATA "Programs\mermaid-ascii\mermaid-ascii.exe"
    if (Test-Path $localExe) {
        return $localExe
    }

    return $null
}

# Auto-install if not found
$MermaidBin = Find-MermaidAscii
if (-not $MermaidBin) {
    Write-Host "mermaid-ascii not found. Installing..." -ForegroundColor Yellow
    $installScript = Join-Path $ScriptDir "install_mermaid_ascii.ps1"
    & $installScript
    $MermaidBin = Find-MermaidAscii
    if (-not $MermaidBin) {
        Write-Error "Installation failed. Please install manually."
        exit 1
    }
}

# Get terminal width
function Get-TerminalWidth {
    try {
        return $Host.UI.RawUI.WindowSize.Width
    }
    catch {
        return 120
    }
}

$TermWidth = Get-TerminalWidth

# Fix mermaid-ascii bug that duplicates output
function Remove-DuplicateOutput {
    param([string]$Output)

    $lines = $Output -split "`n"
    $count = $lines.Count
    $half = [math]::Floor($count / 2)

    if ($half -gt 0 -and ($half * 2) -eq $count) {
        $firstHalf = ($lines[0..($half-1)] -join "`n")
        $secondHalf = ($lines[$half..($count-1)] -join "`n")

        $firstHash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.MD5]::Create().ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes($firstHalf)
            )
        )
        $secondHash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.MD5]::Create().ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes($secondHalf)
            )
        )

        if ($firstHash -eq $secondHash) {
            return $firstHalf
        }
    }

    return $Output
}

# Calculate optimal spacing based on diagram complexity
function Get-OptimalSpacing {
    param([string]$FilePath)

    $content = Get-Content -Path $FilePath -Raw

    # Count nodes
    $nodeMatches = [regex]::Matches($content, '\[[^\]]+\]|\([^\)]+\)|\{[^\}]+\}')
    $nodeCount = $nodeMatches.Count

    # Find longest label
    $maxLabelLen = 10
    foreach ($match in $nodeMatches) {
        $label = $match.Value -replace '[\[\]\(\)\{\}]', ''
        if ($label.Length -gt $maxLabelLen) {
            $maxLabelLen = $label.Length
        }
    }

    # Check if horizontal flow
    $isHorizontal = $content -match 'graph\s+(LR|RL)'

    # Estimate width
    if ($isHorizontal) {
        $estimatedWidth = $nodeCount * ($maxLabelLen + 20)
    }
    else {
        $estimatedWidth = [math]::Floor($nodeCount * ($maxLabelLen + 10) / 2)
    }

    # Calculate spacing based on available room
    $availableRatio = [math]::Floor($TermWidth * 100 / ($estimatedWidth + 1))

    if ($availableRatio -ge 150) {
        return @{ X = 6; Y = 4 }
    }
    elseif ($availableRatio -ge 100) {
        return @{ X = 4; Y = 3 }
    }
    elseif ($availableRatio -ge 70) {
        return @{ X = 2; Y = 2 }
    }
    else {
        return @{ X = 1; Y = 1 }
    }
}

# Handle stdin input
$TempFile = $null
$ActualInput = $InputFile

if ($InputFile -eq "-") {
    $TempFile = [System.IO.Path]::GetTempFileName()
    $TempFile = [System.IO.Path]::ChangeExtension($TempFile, ".mermaid")
    $input | Out-File -FilePath $TempFile -Encoding UTF8
    $ActualInput = $TempFile
}

if (-not $ActualInput -or (-not (Test-Path $ActualInput) -and $ActualInput -ne "-")) {
    Write-Host "Usage: render_mermaid.ps1 <file.mermaid> [options]"
    Write-Host "       Get-Content diagram.mermaid | render_mermaid.ps1 - [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -x <int>   Horizontal spacing (default: auto-calculated)"
    Write-Host "  -y <int>   Vertical spacing (default: auto-calculated)"
    Write-Host "  -p <int>   Border padding (default: 1)"
    Write-Host "  -ascii     Use pure ASCII (no Unicode)"
    Write-Host ""
    Write-Host "Spacing is automatically adjusted based on terminal width ($TermWidth cols)"
    exit 1
}

# Calculate spacing unless manually specified
$ManualSpacing = ($x -ge 0) -or ($y -ge 0)
$xSpacing = $x
$ySpacing = $y

if (-not $ManualSpacing) {
    $spacing = Get-OptimalSpacing -FilePath $ActualInput
    $xSpacing = $spacing.X
    $ySpacing = $spacing.Y
}

# Build arguments
$args = @("-f", $ActualInput, "-p", $p)
if ($xSpacing -ge 0) { $args += @("-x", $xSpacing) }
if ($ySpacing -ge 0) { $args += @("-y", $ySpacing) }
if ($ascii) { $args += "--ascii" }

# Render the diagram
try {
    $output = & $MermaidBin @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Render failed. Try simplifying the diagram."
        if ($TempFile) { Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue }
        exit 1
    }

    $output = Remove-DuplicateOutput -Output ($output -join "`n")

    # Check output width
    $maxWidth = ($output -split "`n" | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

    if ($maxWidth -gt $TermWidth -and -not $ManualSpacing) {
        # Try once more with minimum spacing
        $retryArgs = @("-f", $ActualInput, "-x", 1, "-y", 1, "-p", 0)
        if ($ascii) { $retryArgs += "--ascii" }

        $output = & $MermaidBin @retryArgs 2>&1
        $output = Remove-DuplicateOutput -Output ($output -join "`n")
        $maxWidth = ($output -split "`n" | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

        if ($maxWidth -gt $TermWidth) {
            Write-Output $output
            Write-Host ""
            Write-Host "Note: Diagram is $maxWidth cols wide (terminal: $TermWidth). Scroll horizontally to see full diagram." -ForegroundColor Yellow
        }
        else {
            Write-Output $output
        }
    }
    else {
        Write-Output $output
    }
}
finally {
    if ($TempFile) {
        Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
    }
}
