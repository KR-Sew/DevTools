# Convert Windows Server Evaluation to Standard Edition
$edition = "ServerStandard"
$productKey = "TVRH6-WHNXV-R9WG3-9XRFY-MY832" # Replace with a valid key

Write-Host "Checking Current Edition..."
$currentEdition = (DISM /Online /Get-CurrentEdition | Select-String "Current Edition").Matches.Groups[0].Value.Trim()
Write-Host "Current Edition: $currentEdition"

Write-Host "Checking Available Target Editions..."
$targetEditions = (DISM /Online /Get-TargetEditions | Select-String "Target Edition" | ForEach-Object { $_.Line.Trim() })
Write-Host "Available Target Editions: $targetEditions"

if ($targetEditions -match $edition) {
    Write-Host "Upgrading to $edition..."
    DISM /Online /Set-Edition:$edition /ProductKey:$productKey /AcceptEula
    Write-Host "Upgrade completed. Rebooting now..."
    shutdown /r /t 10
} else {
    Write-Host "Error: Cannot upgrade to $edition. Check available editions."
}
