<#
.SYNOPSIS
    Checks installed .NET SDK version and updates to the latest available.

.DESCRIPTION
    - Detects the currently installed .NET SDK version (if any).
    - Fetches the latest LTS release metadata from Microsoft.
    - Downloads and installs the SDK installer (simple installer URL pattern).
#>

# Function to get installed .NET SDK version
function Get-DotNetVersion {
    try {
        $dotnetVersion = & dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $dotnetVersion) {
            return $dotnetVersion.Trim()
        } else {
            return $null
        }
    } catch {
        return $null
    }
}

# Function to get latest stable (LTS) version from Microsoft
function Get-LatestDotNetVersion {
    $jsonUrl = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json"
    try {
        $releasesIndex = Invoke-RestMethod -Uri $jsonUrl -UseBasicParsing

        # ACCESS HYPHENATED PROPERTIES USING QUOTED PROPERTY NAMES
        $ltsRelease = $releasesIndex.'releases-index' |
            Where-Object { $_.'support-phase' -eq 'active' -and $_.'lts' -eq $true } |
            Sort-Object -Property 'channel-version' -Descending |
            Select-Object -First 1

        if (-not $ltsRelease) { throw "No LTS release found in releases-index.json" }

        $releaseNotesUrl = $ltsRelease.'releases-json'
        $releaseNotes = Invoke-RestMethod -Uri $releaseNotesUrl -UseBasicParsing

        # get the SDK version from the first release entry
        $latestSdk = $releaseNotes.releases[0].sdk.version
        return $latestSdk
    } catch {
        Write-Error "Failed to fetch latest .NET version info: $_"
        return $null
    }
}

# Function to download and install .NET SDK (keeps original simple download pattern)
function Install-DotNetSDK ($version) {
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $downloadUrl = "https://download.visualstudio.microsoft.com/download/pr/dotnet-sdk-$version-win-$arch.exe"
    $installerPath = Join-Path $env:TEMP "dotnet-sdk-$version-win-$arch.exe"

    Write-Output "Downloading .NET SDK $version..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

    Write-Output "Installing .NET SDK $version..."
    Start-Process -FilePath $installerPath -ArgumentList "/quiet /norestart" -Wait -NoNewWindow

    Write-Output "Cleaning up..."
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
}

# Main logic
$currentVersion = Get-DotNetVersion
$latestVersion = Get-LatestDotNetVersion

Write-Output "Installed .NET SDK version: $currentVersion"
Write-Output "Latest .NET SDK version: $latestVersion"

if (-not $latestVersion) {
    Write-Error "Could not determine latest .NET version."
    exit 1
}

# Safer version comparison: try to compare as System.Version, fallback to string check
$needInstall = $false
if (-not $currentVersion) {
    $needInstall = $true
} else {
    try {
        if ([version]$currentVersion -lt [version]$latestVersion) { $needInstall = $true }
    } catch {
        # if version strings can't be parsed, fallback to simple inequality
        $needInstall = ($currentVersion -ne $latestVersion)
    }
}

if ($needInstall) {
    Write-Output "Updating .NET SDK to version $latestVersion..."
    Install-DotNetSDK -version $latestVersion
} else {
    Write-Output ".NET SDK is already up to date."
}
