# Convert Windows Server Evaluation to Standard Edition
$edition = "ServerStandard"
$productKey = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" # Replace with a valid key

Write-Host "Checking Current Edition..."
$currentEdition = (DISM /Online /Get-CurrentEdition | Select-String "Current Edition").ToString()
Write-Host "Current Edition: $currentEdition"

Write-Host "Checking Available Target Editions..."
$targetEditions = (DISM /Online /Get-TargetEditions | Select-String "Target Edition").ToString()
Write-Host "Available Target Editions: $targetEditions"

if ($targetEditions -match $edition) {
    Write-Host "Upgrading to $edition..."
    DISM /Online /Set-Edition:$edition /ProductKey:$productKey /AcceptEula
    Write-Host "Upgrade completed. Rebooting now..."
    shutdown /r /t 10
} else {
    Write-Host "Error: Cannot upgrade to $edition. Check available editions."
}

# Enable RDP
Write-Host "Enabling Remote Desktop..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

# Allow RDP through Windows Firewall
Write-Host "Configuring Firewall for RDP..."
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Enable Network Level Authentication (Optional, Recommended)
Write-Host "Setting Network Level Authentication..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1

# Create an admin user for RDP
$adminUser = "RDPAdmin"
$adminPassword = "SecurePass123!" # Change to a strong password
Write-Host "Creating admin user '$adminUser'..."
New-LocalUser -Name $adminUser -Password (ConvertTo-SecureString $adminPassword -AsPlainText -Force) -FullName "RDP Admin" -Description "Admin for RDP access"
Add-LocalGroupMember -Group "Administrators" -Member $adminUser

Write-Host "RDP and user setup complete. Rebooting in 10 seconds..."
shutdown /r /t 10