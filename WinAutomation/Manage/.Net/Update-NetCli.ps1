<#
.SYNOPSIS
    Check and update .NET SDK or Runtime using the official dotnet-install.ps1 script.

.DESCRIPTION
    - Detects installed .NET SDK versions.
    - Fetches the latest available LTS SDK or Runtime.
    - Installs it using Microsoft's dotnet-install.ps1.
#>

param (
    [ValidateSet("sdk", "runtime")]
    [string]$Type = "sdk",

    [ValidateSet("LTS", "Current")]
    [string]$Channel = "LTS",

    [string]$InstallDir = "$env:ProgramFiles\dotnet"
)

# Function to get installed SDK version
function Get-InstalledDotNet {
    try {
        if ($Type -eq "sdk") {
            $versions = & dotnet --list-sdks 2>$null
            return $versions
        } else {
            $versions = & dotnet --list-runtimes 2>$null | Select-String "Microsoft\.NETCore\.App"
            return $versions
        }
    } catch {
        return $null
    }
}

# Function to install/update .NET using official script
function Install-DotNet {
    Write-Output "Fetching dotnet-install.ps1..."
    $dotnetInstallScript = "$env:TEMP\dotnet-install.ps1"

    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript -UseBasicParsing

    if ($Type -eq "sdk") {
        Write-Output "Installing latest .NET SDK ($Channel) into $InstallDir"
        & powershell -ExecutionPolicy Bypass -File $dotnetInstallScript -Channel $Channel -InstallDir $InstallDir
    } else {
        Write-Output "Installing latest .NET Runtime ($Channel) into $InstallDir"
        & powershell -ExecutionPolicy Bypass -File $dotnetInstallScript -Channel $Channel -Runtime dotnet -InstallDir $InstallDir
    }
}

# Main logic
Write-Output "Checking installed .NET versions..."
$current = Get-InstalledDotNet
if ($current) {
    Write-Output "Installed $Type(s):"
    $current
} else {
    Write-Output "No .NET $Type detected."
}

Install-DotNet

Write-Output "Done. Installed versions now:"
Get-InstalledDotNet
