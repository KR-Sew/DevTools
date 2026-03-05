# -----------------------------------------
# Install Latest .NET SDK (Windows x64)
# Fully compatible with Windows Server 2016
# Includes Windows Event Log logging
# -----------------------------------------

$DownloadPage = "https://dotnet.microsoft.com/en-us/download"
$TempDir      = "$env:TEMP\dotnet-install"
$LogFile      = "$TempDir\install-log.txt"
$Installer    = "$TempDir\dotnet-sdk-installer.exe"

# Event Log settings
$EventSource  = "DotNetInstaller"
$EventLog     = "Application"

# Ensure TLS on WS2016
[Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls12 -bor
    [Net.SecurityProtocolType]::Tls11 -bor
    [Net.SecurityProtocolType]::Tls

# -----------------------------------------
# Ensure Event Log Source Exists
# -----------------------------------------
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    New-EventLog -LogName $EventLog -Source $EventSource
}

# -----------------------------------------
# Helpers
# -----------------------------------------
function LogFile { param($m)
    $timestamp = (Get-Date).ToString("u")
    "$timestamp  $m" | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

function LogEventInfo   { param($m) Write-EventLog -LogName $EventLog -Source $EventSource -EntryType Information -EventId 1000 -Message $m }
function LogEventWarn   { param($m) Write-EventLog -LogName $EventLog -Source $EventSource -EntryType Warning     -EventId 1001 -Message $m }
function LogEventError  { param($m) Write-EventLog -LogName $EventLog -Source $EventSource -EntryType Error       -EventId 1002 -Message $m }

# Ensure temp folder
if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir | Out-Null }

# -----------------------------------------
# STEP 1 — Get main download page
# -----------------------------------------
try {
    Write-Host "Fetching .NET download page..."
    $html = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing
}
catch {
    $msg = "Failed to load .NET download page: $_"
    Write-Error $msg
    LogFile $msg
    LogEventError $msg
    exit 1
}

# -----------------------------------------
# STEP 2 — Extract thank-you link
# -----------------------------------------
$pattern = "/en-us/download/dotnet/thank-you/.*sdk.*windows.*x64.*installer"

$thankYouLink = $html.Links |
    Where-Object { $_.href -match $pattern } |
    Select-Object -First 1

if (-not $thankYouLink) {
    $msg = "Could not locate .NET SDK thank-you download link."
    Write-Error $msg
    LogFile $msg
    LogEventError $msg
    exit 1
}

$thankYouURL = "https://dotnet.microsoft.com$($thankYouLink.href)"
Write-Host "Thank-you link: $thankYouURL"
LogFile "Thank-you URL: $thankYouURL"
LogEventInfo "Found .NET SDK thank-you URL."

# -----------------------------------------
# STEP 3 — Load thank-you page (HTML parsing)
# -----------------------------------------
try {
    Write-Host "Loading thank-you page..."
    $ty = Invoke-WebRequest -Uri $thankYouURL -UseBasicParsing
}
catch {
    $msg = "Failed to load thank-you page: $_"
    Write-Error $msg
    LogFile $msg
    LogEventError $msg
    exit 1
}

# -----------------------------------------
# STEP 4 — Extract final EXE download URL
# -----------------------------------------
$exeRegex = "https://(download\.visualstudio|builds\.dotnet)\.microsoft\.com/[^""]+\.exe"

$InstallerURL = ($ty.Content |
    Select-String -Pattern $exeRegex -AllMatches).Matches.Value |
    Select-Object -First 1

if (-not $InstallerURL) {
    $msg = "Failed to extract final SDK installer URL from thank-you page."
    Write-Error $msg
    LogFile $msg
    LogEventError $msg
    exit 1
}

Write-Host "Installer URL: $InstallerURL"
LogFile "Final installer URL: $InstallerURL"
LogEventInfo "Resolved .NET SDK installer URL."

# -----------------------------------------
# STEP 5 — Download installer
# -----------------------------------------
try {
    Write-Host "Downloading installer..."
    Invoke-WebRequest -Uri $InstallerURL -OutFile $Installer -UseBasicParsing
    LogFile "Downloaded installer."
    LogEventInfo "Successfully downloaded .NET SDK installer."
}
catch {
    $msg = "Download failed: $_"
    Write-Error $msg
    LogFile $msg
    LogEventError $msg
    exit 1
}

# -----------------------------------------
# STEP 6 — Run installer silently
# -----------------------------------------
try {
    Write-Host "Installing .NET SDK..."
    Start-Process -FilePath $Installer -ArgumentList "/quiet /norestart" -Wait
    $msg = ".NET SDK installation completed successfully."
    Write-Host $msg
    LogFile $msg
    LogEventInfo $msg
}
catch {
    $msg = "Installation failed: $_"
    Write-Error $msg
    LogFile $msg
    LogEventError $msg
    exit 1
}

# -----------------------------------------
# STEP 7 — Cleanup installer
# -----------------------------------------
Remove-Item -Path $Installer -Force

# -----------------------------------------
# STEP 8 — Display installed versions
# -----------------------------------------
Write-Host "`nInstalled SDKs:"
try { dotnet --list-sdks } catch {}

Write-Host "`nInstalled runtimes:"
try { dotnet --list-runtimes } catch {}

LogEventInfo ".NET SDK installation script finished successfully."
