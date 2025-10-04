<#
.SYNOPSIS
    Checks, downloads, and installs the latest version of IIS Application Request Routing (ARR).
.DESCRIPTION
    This script detects if ARR is installed, fetches the latest ARR installer from Microsoft,
    and installs it if a newer version is available. Works on Windows Server 2022 and 2025.
#>

# Requires elevation
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator."
    exit 1
}

# --- Variables ---
$ArrDownloadPage = "https://www.iis.net/downloads/microsoft/application-request-routing"
$TempPath = "$env:TEMP\ARR_Installer"
$ArrInstaller = "$TempPath\arr.msi"
$ArrProductName = "IIS Application Request Routing"

# --- Helper: Get Web Page Content ---
function Get-WebContent($url) {
    try {
        (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    } catch {
        Write-Error "Failed to get content from $url"
        exit 1
    }
}

# --- Function: Get ARR Package ---
function Get-ArrPackage {
    param([string]$DownloadDirectory)

    Write-Host "Fetching ARR download link from IIS.net..."
    $content = Get-WebContent $ArrDownloadPage

    # Try to find ARR 3.x download link (official MSI)
    if ($content -match 'https:\/\/download\.microsoft\.com\/[^"]+arr_3[^"]+\.msi') {
        $downloadLink = $matches[0]
    } else {
        Write-Error "Could not locate ARR MSI download link on IIS.net."
        exit 1
    }

    if (!(Test-Path $DownloadDirectory)) {
        New-Item -ItemType Directory -Path $DownloadDirectory | Out-Null
    }

    Write-Host "Downloading ARR package..."
    Invoke-WebRequest -Uri $downloadLink -OutFile $ArrInstaller -UseBasicParsing
    Write-Host "Downloaded to $ArrInstaller"
}

# --- Function: Install MSI ---
function Install-MSI {
    param([string]$argument)

    Write-Host "Installing ARR..."
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$argument`" /qn /norestart" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Installation failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# --- Function: Get ARR Installed Version ---
function Get-ArrInstalledVersion {
    $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $subkeys = Get-ChildItem $key | ForEach-Object {
        Get-ItemProperty $_.PSPath | Where-Object { $_.DisplayName -like "*Application Request Routing*" }
    }
    return $subkeys.DisplayVersion
}

# --- Function: Restart IIS Services ---
function Restart-IIS {
    Write-Host "Restarting IIS services..."
    Restart-Service W3SVC -Force -ErrorAction SilentlyContinue
    Restart-Service WAS -Force -ErrorAction SilentlyContinue
    Write-Host "IIS services restarted."
}

# --- MAIN LOGIC ---
Write-Host "`n=== IIS Application Request Routing Installer ===`n"

$currentVersion = Get-ArrInstalledVersion
if ($currentVersion) {
    Write-Host "Detected ARR version: $currentVersion"
} else {
    Write-Host "ARR is not currently installed."
}

Get-ArrPackage -DownloadDirectory $TempPath
Install-MSI -argument $ArrInstaller
Restart-IIS

Write-Host "`nARR installation completed successfully."
