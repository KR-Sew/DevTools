# PowerShell script to install IIS and ARR on Windows Server 2022
# Run as Administrator

# Step 1: Install IIS Web Server role
Write-Host "Installing IIS Web Server role..."
Install-WindowsFeature -Name Web-Server -IncludeAllSubFeatures -IncludeManagementTools
Write-Host "IIS installation completed."

# Step 2: Stop required services
Write-Host "Stopping WAS and WMSVC services..."
Stop-Service -Name WAS -Force -ErrorAction SilentlyContinue
Stop-Service -Name WMSVC -Force -ErrorAction SilentlyContinue

# Step 3: Create temporary directory for downloads
$tempDir = "$env:TEMP\ARR_Install"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force
}

# Step 4: Download and install dependencies in order

# URL Rewrite Module
Write-Host "Downloading and installing URL Rewrite Module..."
$urlRewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
$urlRewritePath = Join-Path $tempDir "rewrite_amd64_en-US.msi"
Invoke-WebRequest -Uri $urlRewriteUrl -OutFile $urlRewritePath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$urlRewritePath`" /qn /norestart" -Wait -NoNewWindow
Write-Host "URL Rewrite Module installed."

# Web Farm Framework
Write-Host "Downloading and installing Web Farm Framework..."
$webfarmUrl = "https://download.microsoft.com/download/3/4/1/3415F3F9-5698-44FE-A072-D4AF09728390/webfarm_amd64_en-US.msi"
$webfarmPath = Join-Path $tempDir "webfarm_amd64_en-US.msi"
Invoke-WebRequest -Uri $webfarmUrl -OutFile $webfarmPath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$webfarmPath`" /qn /norestart" -Wait -NoNewWindow
Write-Host "Web Farm Framework installed."

# External Disk Cache
Write-Host "Downloading and installing External Disk Cache..."
$cacheUrl = "https://download.microsoft.com/download/3/4/1/3415F3F9-5698-44FE-A072-D4AF09728390/ExternalDiskCache_amd64_en-US.msi"
$cachePath = Join-Path $tempDir "ExternalDiskCache_amd64_en-US.msi"
Invoke-WebRequest -Uri $cacheUrl -OutFile $cachePath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$cachePath`" /qn /norestart" -Wait -NoNewWindow
Write-Host "External Disk Cache installed."

# Application Request Routing (ARR)
Write-Host "Downloading and installing Application Request Routing..."
$arrUrl = "https://download.microsoft.com/download/A/A/E/AAE77C2B-ED2D-4EE1-9AF7-D29E89EA623D/requestRouter_amd64_en-US.msi"
$arrPath = Join-Path $tempDir "requestRouter_amd64_en-US.msi"
Invoke-WebRequest -Uri $arrUrl -OutFile $arrPath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$arrPath`" /qn /norestart" -Wait -NoNewWindow
Write-Host "Application Request Routing installed."

# Step 5: Start services
Write-Host "Starting WAS and WMSVC services..."
Start-Service -Name WMSVC -ErrorAction SilentlyContinue
Start-Service -Name WAS -ErrorAction SilentlyContinue

# Optional: Set DefaultAppPool idle timeout to 0
Write-Host "Configuring DefaultAppPool idle timeout..."
& "$env:SystemRoot\System32\inetsrv\appcmd.exe" set apppool "DefaultAppPool" /processModel.idleTimeout:"00:00:00"

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Installation completed successfully. Please restart the server if necessary."