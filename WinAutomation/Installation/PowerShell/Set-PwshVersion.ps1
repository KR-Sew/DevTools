# Check if PowerShell 7 is installed
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    Write-Host "PowerShell 7 is not installed. Please install it first: https://aka.ms/powershell"
    exit 1
}

# Get current user profile path
$profilePath = [System.Environment]::GetFolderPath("UserProfile")

# Update Windows Terminal profile (if exists)
$terminalSettings = "$profilePath\AppData\Local\Microsoft\Windows Terminal\settings.json"
if (Test-Path $terminalSettings) {
    (Get-Content $terminalSettings) -replace '"commandline": ".*powershell.exe"' , "`"commandline`": `"$pwshPath`"" | Set-Content $terminalSettings
    Write-Host "Updated Windows Terminal to use PowerShell 7"
}

# Set pwsh as the default shell for Command Prompt
$registryPath = "HKCU:\Software\Microsoft\Command Processor"

# Ensure the registry path exists before modifying it
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

Set-ItemProperty -Path $registryPath -Name "AutoRun" -Value "`"$pwshPath`" -NoExit"
Write-Host "Set PowerShell 7 as default shell for cmd.exe"

# Update system PATH (if needed)
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if ($pwshPath -notin $envPath -split ";") {
    [System.Environment]::SetEnvironmentVariable("Path", "$pwshPath;${envPath}", [System.EnvironmentVariableTarget]::User)
    Write-Host "Updated PATH to include PowerShell 7"
}

Write-Host "PowerShell 7 is now the default shell!"
