# Install OpenSSH (Client + Server) on Windows Server 2016 / Hyper-V Server 2016
# Andrew's version

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "`n === Installing OpenSSH for Windows Server 2016 === `n"

# --- CONFIG ---
$gitApi = "https://api.github.com/repos/PowerShell/Win32-OpenSSH/releases/latest"
$temp = "$env:TEMP\OpenSSH"
$installDir = "C:\Program Files\OpenSSH"

if (-not (Test-Path $temp)) { New-Item -ItemType Directory -Path $temp | Out-Null }

# --- Get latest release tag from GitHub ---
Write-Host "Fetching latest OpenSSH release info..."
$release = Invoke-RestMethod -Uri $gitApi -UseBasicParsing

$asset = $release.assets | Where-Object { $_.name -match "OpenSSH-Win64.*.zip" } | Select-Object -First 1
if (-not $asset) { throw "Failed to find OpenSSH zip in GitHub API response." }

$zipFile = Join-Path $temp $asset.name
Write-Host "Downloading $($asset.name)..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipFile -UseBasicParsing

# --- Extract ZIP ---
Write-Host "Extracting..."
Expand-Archive -LiteralPath $zipFile -DestinationPath $temp -Force

# Create install directory
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Copy files
Write-Host "Copying files to $installDir ..."
Copy-Item -Path "$temp\OpenSSH-Win64\*" -Destination $installDir -Recurse -Force

# --- Install SSHD + SSH-Agent services ---
Write-Host "Installing SSH services..."
Set-Location $installDir
powershell.exe -ExecutionPolicy Bypass -File ".\install-sshd.ps1"

# --- Firewall rules ---
Write-Host "Configuring firewall..."
netsh advfirewall firewall add rule name="OpenSSH-Server-In-TCP" dir=in action=allow protocol=TCP localport=22

# --- Fix permissions ---
Write-Host "Adjusting NTFS permissions..."
& "$installDir\FixHostFilePermissions.ps1"
& "$installDir\FixUserFilePermissions.ps1"

# --- Start services ---
Write-Host "Starting sshd + ssh-agent..."
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent

Write-Host "`n OPENSSH INSTALLATION COMPLETE ✔"
Write-Host "Try connecting using: ssh <username>@<server-ip>"
