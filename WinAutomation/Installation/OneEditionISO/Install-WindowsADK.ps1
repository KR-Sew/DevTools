<#
.SYNOPSIS
    Downloads and installs the Windows ADK and WinPE Add-on for Windows 11 / Server 2025
.DESCRIPTION
    This script downloads the latest ADK and installs only the Deployment Tools and WinPE
#>

$adkUrl     = "https://go.microsoft.com/fwlink/?linkid=2243390" # ADK 11 / Server 2025
$winpeUrl   = "https://go.microsoft.com/fwlink/?linkid=2243391" # WinPE Add-on

$tempDir    = "$env:TEMP\ADK_Setup"
$adkFile    = "$tempDir\adksetup.exe"
$winpeFile  = "$tempDir\adkwinpesetup.exe"

# Create temp directory
if (!(Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory | Out-Null }

Write-Host "[+] Downloading ADK installer..."
Invoke-WebRequest -Uri $adkUrl -OutFile $adkFile

Write-Host "[+] Installing ADK Deployment Tools..."
Start-Process -Wait -FilePath $adkFile -ArgumentList "/quiet /norestart /features OptionId.DeploymentTools"

Write-Host "[+] Downloading WinPE Add-on..."
Invoke-WebRequest -Uri $winpeUrl -OutFile $winpeFile

Write-Host "[+] Installing WinPE Add-on..."
Start-Process -Wait -FilePath $winpeFile -ArgumentList "/quiet /norestart /features OptionId.WindowsPreinstallationEnvironment"

Write-Host "`n✅ ADK and WinPE installed successfully."
