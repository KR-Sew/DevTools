# -----------------------------------------
# Install Latest .NET SDK (Windows x64)
# NEW Microsoft download pages compatible
# -----------------------------------------

$DownloadPage = "https://dotnet.microsoft.com/en-us/download"
$TempDir      = "$env:TEMP\dotnet-install"
$LogFile      = "$TempDir\install-log.txt"
$Installer    = "$TempDir\dotnet-sdk-installer.exe"

# TLS for WS2016
[Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls12 -bor
    [Net.SecurityProtocolType]::Tls11 -bor
    [Net.SecurityProtocolType]::Tls

# Ensure temp dir
if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir | Out-Null }

function Log($msg) {
    $timestamp = (Get-Date).ToString("u")
    "$timestamp  $msg" | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

# -----------------------------
# STEP 1 — Load download page
# -----------------------------

Write-Host "Fetching main .NET download page..."
try {
    $html = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing
}
catch {
    Write-Error "Failed to load .NET download page: $_"
    Log "ERROR: Could not load main page"
    exit 1
}

# -----------------------------
# STEP 2 — Extract thank-you link
# -----------------------------

$pattern = "/en-us/download/dotnet/thank-you/.*sdk.*windows.*x64.*installer"

$thankYouLink = $html.Links |
    Where-Object { $_.href -match $pattern } |
    Select-Object -First 1

if (-not $thankYouLink) {
    Write-Error "Could not locate thank-you link."
    Log "ERROR: Thank-you link not found"
    exit 1
}

$thankYouURL = "https://dotnet.microsoft.com$($thankYouLink.href)"
Write-Host "Thank-you link found: $thankYouURL"
Log "Thank-you link: $thankYouURL"

# -----------------------------
# STEP 3 — Load thank-you page (NO REDIRECT ANYMORE)
# -----------------------------

Write-Host "Loading thank-you page..."
try {
    $ty = Invoke-WebRequest -Uri $thankYouURL -UseBasicParsing
}
catch {
    Write-Error "Failed to load thank-you page: $_"
    Log "ERROR: Cannot load thank-you page"
    exit 1
}

# -----------------------------
# STEP 4 — Extract final EXE link
# -----------------------------
# Microsoft now embeds direct links in HTML, not via redirects.

$exeRegex = "https://(download\.visualstudio|builds\.dotnet)\.microsoft\.com/[^""]+\.exe"

$InstallerURL = ($ty.Content | Select-String -Pattern $exeRegex -AllMatches).Matches.Value |
    Select-Object -First 1

if (-not $InstallerURL) {
    Write-Error "Could not extract final installer URL from thank-you page."
    Log "ERROR: Installer URL missing"
    exit 1
}

Write-Host "Final installer URL: $InstallerURL"
Log "Installer URL: $InstallerURL"

# -----------------------------
# STEP 5 — Download installer
# -----------------------------

Write-Host "Downloading installer..."
try {
    Invoke-WebRequest -Uri $InstallerURL -OutFile $Installer -UseBasicParsing
    Log "Downloaded installer"
}
catch {
    Write-Error "Download failed: $_"
    Log "ERROR: download failed"
    exit 1
}

# -----------------------------
# STEP 6 — Install silently
# -----------------------------

Write-Host "Installing .NET..."
try {
    Start-Process -FilePath $Installer -ArgumentList "/quiet /norestart" -Wait
    Log "Installation SUCCESS"
    Write-Host "Installation completed."
}
catch {
    Write-Error "Installation failed: $_"
    Log "ERROR: installation failed"
    exit 1
}

# -----------------------------
# STEP 7 — Cleanup
# -----------------------------

Remove-Item -Path $Installer -Force

# -----------------------------
# STEP 8 — Confirm installation
# -----------------------------

Write-Host "`nInstalled SDKs:"
try { dotnet --list-sdks } catch {}

Write-Host "`nInstalled runtimes:"
try { dotnet --list-runtimes } catch {}
