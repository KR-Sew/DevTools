# Check if the script is running as Administrator
$adminCheck = [System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $adminCheck.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host "🔹 Checking if Sysprep is available..."
$sysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe"

if (-not (Test-Path $sysprepPath)) {
    Write-Host "❌ Error: Sysprep is not found on this system!" -ForegroundColor Red
    exit 1
}

Write-Host "⚠ The system will reboot after Sysprep completes!" -ForegroundColor Yellow

# Run Sysprep with Generalize and OOBE to reset the SID
Write-Host "🔄 Running Sysprep to reset SID..."
Start-Process -FilePath $sysprepPath -ArgumentList "/generalize /oobe /shutdown /quiet" -Wait

Write-Host "✅ Sysprep completed successfully! The system will shut down now." -ForegroundColor Green
