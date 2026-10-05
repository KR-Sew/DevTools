<#
.SYNOPSIS
    Downloads and installs the latest version of 7-Zip (EXE or MSI).
.DESCRIPTION
    - Detects latest version from 7-zip.org
    - Falls back to GitHub API if parsing fails
    - Detects CPU architecture (x64 / arm64)
    - Supports EXE or MSI installers
#>

param(
    [ValidateSet("exe","msi")]
    [string]$InstallerType = "exe",

    [string]$Version # Optional manual override, e.g. -Version 2408
)

Write-Host "=== 7-Zip Auto Installer ===" -ForegroundColor Green

function Get-Latest7ZipVersion {
    param([switch]$Verbose)

    Write-Host "Detecting latest 7-Zip version..." -ForegroundColor Yellow

    # -------------------------------
    # Method 1 — Scrape 7-zip.org
    # -------------------------------
    try {
        $page = Invoke-WebRequest "https://www.7-zip.org/download.html" -UseBasicParsing

        # Match versions like 7z2409-x64.exe
        $regex = '7z(\d{4})-(?:x64|arm64)\.exe'
        $matching = [regex]::Matches($page.Content, $regex)

        if ($matching.Count -gt 0) {
            $versions = $matching | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Descending
            $latest = $versions[0]
            Write-Host "Latest version detected from website: $latest" -ForegroundColor Green
            return $latest
        }
        Write-Host "Website parsing failed — no version found." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Failed to parse 7-zip.org: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # -------------------------------
    # Method 2 — GitHub (official)
    # -------------------------------
    try {
        Write-Host "Querying GitHub API as fallback..." -ForegroundColor Yellow
        $api = Invoke-RestMethod "https://api.github.com/repos/ip7z/7zip/releases/latest"
        $tag = $api.tag_name -replace '[^\d]', ''  # convert "23.01" → "2301"

        if ($tag -match '^\d{4}$') {
            Write-Host "Latest version detected from GitHub: $tag" -ForegroundColor Green
            return $tag
        }
    }
    catch {
        Write-Host "GitHub API fallback failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # -------------------------------
    # Method 3 — Fallback (YYMM pattern)
    # -------------------------------
    $fallback = (Get-Date).ToString("yyMM")
    Write-Host "Using fallback version: $fallback" -ForegroundColor Yellow
    return $fallback
}

# Manual override
$latestVersion = $Version
if (-not $latestVersion) {
    $latestVersion = Get-Latest7ZipVersion
}

# Architecture detection
$arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
if ($env:PROCESSOR_ARCHITECTURE -match "ARM") { $arch = "arm64" }

Write-Host "Detected architecture: $arch" -ForegroundColor Cyan

# Build URL
$base = "https://www.7-zip.org/a"
$installerFile = if ($InstallerType -eq "exe") {
    "7z$latestVersion-$arch.exe"
} else {
    "7z$latestVersion-$arch.msi"
}

$downloadUrl = "$base/$installerFile"
$downloadPath = "$env:TEMP\$installerFile"

Write-Host "Downloading: $downloadUrl" -ForegroundColor Yellow

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
    Write-Host "Downloaded successfully." -ForegroundColor Green
}
catch {
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Install
Write-Host "Installing 7-Zip..." -ForegroundColor Yellow
if ($InstallerType -eq "exe") {
    $arguments = "/S"
} else {
    $arguments = "/qn /norestart"
}

$process = Start-Process $downloadPath -ArgumentList $arguments -Wait -PassThru
Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor Cyan

if ($process.ExitCode -eq 0) {
    Write-Host "7-Zip installed successfully!" -ForegroundColor Green
} else {
    Write-Host "Installer finished with errors." -ForegroundColor Red
}

# Cleanup
Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
Write-Host "Temporary files cleaned." -ForegroundColor Green

Write-Host "=== Completed ===" -ForegroundColor Green
