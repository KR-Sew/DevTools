# Check if OpenSSH Server is already installed
$sshServerFeature = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }

if ($sshServerFeature.State -eq 'Installed') {
    Write-Host "OpenSSH Server is already installed."
} else {
    # Install OpenSSH Server
    Write-Host "Installing OpenSSH Server..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

    # Check if the installation was successful
    $sshServerFeature = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
    if ($sshServerFeature.State -eq 'Installed') {
        Write-Host "OpenSSH Server installed successfully."
    } else {
        Write-Host "Failed to install OpenSSH Server."
        exit
    }
}

# Start the OpenSSH Server service
Write-Host "Starting OpenSSH Server service..."
Start-Service sshd

# Set the OpenSSH Server service to start automatically
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the service status
$serviceStatus = Get-Service -Name sshd
if ($serviceStatus.Status -eq 'Running') {
    Write-Host "OpenSSH Server service is running."
} else {
    Write-Host "OpenSSH Server service is not running."
}
