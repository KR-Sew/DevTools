# Define variables
$dotnetDownloadPage = "https://dotnet.microsoft.com/en-us/download"
$tempDir = "$env:TEMP\dotnet-install"
$logFile = "$tempDir\install-log.txt"
$dotnetInstaller = "$tempDir\dotnet-sdk-installer.exe"

# Create temp directory
if (!(Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory | Out-Null
}

# Get latest SDK "thank-you" page URL
Write-Host "Fetching latest .NET SDK download link..."
try {
    $html = Invoke-WebRequest -Uri $dotnetDownloadPage -UseBasicParsing
    $thankYouLink = ($html.Links | Where-Object {
        $_.href -match "/en-us/download/dotnet/thank-you/.*sdk.*-windows-x64-installer$"
    } | Select-Object -First 1).href

    if (-not $thankYouLink) {
        throw "Unable to find SDK thank-you page link."
    }

    $thankYouUrl = "https://dotnet.microsoft.com$thankYouLink"

    # Follow the thank-you redirect to get the actual installer URL
    Write-Host "Following redirect to get the actual SDK installer..."
    $thankYouResponse = Invoke-WebRequest -Uri $thankYouUrl -UseBasicParsing
    $realDownloadUrl = ($thankYouResponse.Links | Where-Object {
        $_.href -match "https://(download\.visualstudio|builds\.dotnet)\.microsoft\.com/.*\.exe$"
    } | Select-Object -First 1).href

    if (-not $realDownloadUrl) {
        throw "Unable to extract final SDK installer URL."
    }

    # Log the resolved version and URL
    Add-Content -Path $logFile -Value "Timestamp: $(Get-Date)"
    Add-Content -Path $logFile -Value "Installer URL: $realDownloadUrl"

} catch {
    Write-Error "Failed to retrieve the .NET SDK download link: $_"
    exit 1
}

# Download the installer
Write-Host "Downloading .NET SDK installer from $realDownloadUrl..."
try {
    Invoke-WebRequest -Uri $realDownloadUrl -OutFile $dotnetInstaller
} catch {
    Write-Error "Failed to download .NET SDK: $_"
    exit 1
}

# Install silently
Write-Host "Installing .NET SDK silently..."
try {
    Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet" -Wait -NoNewWindow
    Write-Host ".NET SDK installation completed."
    Add-Content -Path $logFile -Value "Installation status: SUCCESS"
} catch {
    Write-Error "Installation failed: $_"
    Add-Content -Path $logFile -Value "Installation status: FAILED"
    exit 1
}

# Cleanup
Remove-Item -Path $dotnetInstaller -Force
Remove-Item -Path $tempDir -Recurse -Force

# Confirm installation
Write-Host "Checking installed .NET SDK version:"
& "$env:ProgramFiles\dotnet\dotnet.exe" --list-sdks
