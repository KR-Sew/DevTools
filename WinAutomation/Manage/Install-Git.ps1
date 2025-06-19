<#
.SYNOPSIS
    Downloads and installs the latest Git for Windows
.DESCRIPTION
    This script checks GitHub for the latest Git for Windows release,
    downloads the installer, and performs a silent installation.
.NOTES
    File Name      : Install-LatestGit.ps1
    Prerequisite   : PowerShell 5.1 or later
#>

[CmdletBinding()]
param (
    [switch]$SkipExecutionPolicyChange
)

if (-not $SkipExecutionPolicyChange) {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to set execution policy. Proceeding anyway. $_"
    }
}

function Get-LatestGitVersion {
    try {
        $apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        $version = $response.tag_name -replace '^v', ''
        $asset = $response.assets | Where-Object {
            $_.name -match '^Git-\d+\.\d+\.\d+-64-bit\.exe$'
        } | Select-Object -First 1

        if (-not $asset) {
            throw "No matching 64-bit installer found."
        }

        return @{
            Version      = $version
            DownloadUrl  = $asset.browser_download_url
            FileName     = $asset.name
        }
    }
    catch {
        Write-Error "Error fetching latest Git release: $_"
        exit 1
    }
}

Write-Host "Checking for latest Git for Windows version..." -ForegroundColor Cyan
$latestGit = Get-LatestGitVersion
Write-Host "Latest version found: $($latestGit.Version)" -ForegroundColor Green

$installerPath = Join-Path $env:TEMP $latestGit.FileName

try {
    Write-Host "Downloading Git $($latestGit.Version) installer..."
    Invoke-WebRequest -Uri $latestGit.DownloadUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "Download completed: $installerPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download Git installer: $_"
    exit 1
}

# Define installer arguments
$installArgs = @(
    "/VERYSILENT",
    "/SUPPRESSMSGBOXES",
    "/NORESTART",
    "/NOCANCEL",
    "/SP-",
    "/LOG",
    "/COMPONENTS=icons,ext\reg\shellhere,assoc,assoc_sh",
    "/D=C:\Program Files\Git"
)

try {
    Write-Host "Installing Git $($latestGit.Version)..."
    Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -NoNewWindow
    Write-Host "Git installation completed." -ForegroundColor Green
}
catch {
    Write-Error "Git installation failed: $_"
    exit 1
}

# Add Git to system PATH if needed
try {
    $gitCmdPath = "C:\Program Files\Git\cmd"
    $envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

    if ($envPath -notlike "*$gitCmdPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$envPath;$gitCmdPath", "Machine")
        Write-Host "Added Git to system PATH." -ForegroundColor Green
    }
}
catch {
    Write-Warning "Failed to update system PATH: $_"
}

# Clean up installer
try {
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    Write-Host "Cleaned up installer." -ForegroundColor DarkGray
}
catch {
    Write-Warning "Could not remove installer: $_"
}

# Verify installation
try {
    $env:Path += ";$gitCmdPath"  # Ensure current session can see Git
    $gitVersion = git --version 2>$null

    if ($gitVersion) {
        Write-Host "Git installed successfully: $gitVersion" -ForegroundColor Green
        Write-Host "You may need to restart your terminal or system to finalize PATH updates." -ForegroundColor Yellow
    }
    else {
        Write-Warning "Git installation could not be verified."
    }
}
catch {
    Write-Warning "Error during verification: $_"
}
