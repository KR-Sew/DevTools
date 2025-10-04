<#
.SYNOPSIS
  Checks for, downloads, and installs IIS ARR 3.0 and dependencies on Windows Server.

.DESCRIPTION
  This PowerShell script:
   • Detects if ARR 3.0 is installed.
   • Installs dependencies (URL Rewrite, Web Farm, External Cache) only if missing.
   • Downloads official Microsoft MSI packages.
   • Installs them silently.
   • Restarts IIS-related services using Restart-Service cmdlet.
   • Logs all actions.

.NOTES
  Run as Administrator.
  Tested on Windows Server 2022+ (should work on 2025).
#>

#region --- Configuration ---

$Urls = @{
    "x64" = "https://download.microsoft.com/download/3/4/1/3415F3F9-5698-44FE-A072-D4AF09728390/requestRouter_x64.msi"
    "x86" = "https://download.microsoft.com/download/4/4/9/449E2B5D-C9BF-49F0-8484-FF5D593C6035/requestRouter_x86.msi"
}

$Dependencies = @(
    @{ Name = "URL Rewrite Module 2"; Display = "*URL Rewrite*"; Url = "https://download.microsoft.com/download/4/5/A/45A6F824-1200-4796-BC9E-0D0E37A112A5/rewrite_amd64_en-US.msi" },
    @{ Name = "Web Farm Framework 1.1"; Display = "*Web Farm Framework*"; Url = "https://download.microsoft.com/download/5/7/0/57065640-4665-4980-a2f1-4d5940b577b0/webfarm_v1.1_amd64_en_us.msi" },
    @{ Name = "External Disk Cache 1.0"; Display = "*External Disk Cache*"; Url = "https://download.microsoft.com/download/C/A/5/CA5FAD87-1E93-454A-BB74-98310A9C523C/ExternalDiskCache_amd64.msi" }
)

$LogDir = Join-Path $env:TEMP "ARR_Install_Logs"
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}
$LogFile = Join-Path $LogDir "Install_ARR3_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

#endregion

#region --- Helper Functions ---

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Get-InstalledProduct {
    param([string]$Pattern)
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($k in $keys) {
        Get-ChildItem -Path $k -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -like $Pattern) { return $p }
        }
    }
    return $null
}

function Download-File {
    param([string]$Url, [string]$Dest)
    Write-Log "INFO" "Downloading: $Url"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -ErrorAction Stop
        Write-Log "INFO" "Downloaded successfully to: $Dest"
        return $true
    }
    catch {
        Write-Log "ERROR" "Download failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-MSI {
    param([string]$Path)
    $log = Join-Path $LogDir ("Install_" + (Split-Path $Path -Leaf) + ".log")
    $args = "/i `"$Path`" /qn /norestart /l*v `"$log`""
    Write-Log "INFO" "Running: msiexec $args"
    $proc = Start-Process -FilePath "$env:WINDIR\System32\msiexec.exe" -ArgumentList $args -Wait -PassThru
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-Log "INFO" "MSI installed successfully (exit code $($proc.ExitCode))"
        return $true
    } else {
        Write-Log "ERROR" "MSI install failed (exit code $($proc.ExitCode))"
        return $false
    }
}

function Restart-IISServices {
    $services = "WAS", "WMSVC", "W3SVC"
    foreach ($svc in $services) {
        try {
            Write-Log "INFO" "Restarting service: $svc"
            Restart-Service -Name $svc -Force -ErrorAction Stop
        }
        catch {
            Write-Log "WARN" "Service $svc could not be restarted or not present: $($_.Exception.Message)"
        }
    }
}

#endregion

#region --- Main Logic ---

Write-Log "INFO" "=== ARR 3.0 Installation Script Started ==="

# Detect existing ARR
$arrInstalled = Get-InstalledProduct -Pattern "*Application Request Routing*"
if ($arrInstalled) {
    Write-Log "INFO" "ARR already installed: $($arrInstalled.DisplayName) version $($arrInstalled.DisplayVersion)"
    if ($arrInstalled.DisplayVersion -match "^3\.0") {
        Write-Log "INFO" "ARR 3.0 already present. Exiting."
        exit 0
    }
}

# Detect and install dependencies
foreach ($dep in $Dependencies) {
    $exists = Get-InstalledProduct -Pattern $dep.Display
    if ($exists) {
        Write-Log "INFO" "$($dep.Name) already installed (version: $($exists.DisplayVersion))"
        continue
    }

    $dest = Join-Path $LogDir (Split-Path $dep.Url -Leaf)
    if (Download-File -Url $dep.Url -Dest $dest) {
        if (-not (Install-MSI -Path $dest)) {
            Write-Log "ERROR" "Dependency $($dep.Name) failed to install. Exiting."
            exit 1
        }
    } else {
        Write-Log "ERROR" "Failed to download dependency $($dep.Name). Exiting."
        exit 1
    }
}

# Download ARR 3.0
$arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$arrUrl = $Urls[$arch]
$arrFile = Join-Path $LogDir (Split-Path $arrUrl -Leaf)

if (-not (Download-File -Url $arrUrl -Dest $arrFile)) {
    Write-Log "ERROR" "Failed to download ARR 3.0 installer. Exiting."
    exit 1
}

# Restart IIS services before install (to release locks)
Restart-IISServices

# Install ARR
if (-not (Install-MSI -Path $arrFile)) {
    Write-Log "ERROR" "ARR 3.0 installation failed. Check log at $LogFile."
    exit 1
}

# Restart IIS again after install
Restart-IISServices

Write-Log "INFO" "=== ARR 3.0 installation completed successfully ==="
Write-Log "INFO" "Logs available at: $LogDir"

#endregion
