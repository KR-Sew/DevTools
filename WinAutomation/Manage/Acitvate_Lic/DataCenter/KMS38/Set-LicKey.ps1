# script.ps1
# Make sure we run in the script's own folder
Set-Location -Path $PSScriptRoot

# Read the target license kay from .txt
$getLicKey = Get-Content -Path ".\key.txt" -Raw

Write-Host "the next key will bi add: ${getLicKey}" -ForegroundColor Cyan

# Add new license key
$addKey = slmgr.vbs /ipk $getLicKey

Write-Host "Key registration result: ${addKey}" -ForegroundColor Cyan
Write-Host "Copy KMS38 to prepare resistration process .." -ForegroundColor DarkCyan
Copy-Item -Path .\KeyXML\KMS38.xml -Destination .\ -PassThru

# Run registration with config.xml as parameter
Write-Host "Starting activation license with config.xml..." -ForegroundColor DarkCyan
Start-Process ".\ClipUp.exe" -ArgumentList "-v -o -altto .\" -Wait
