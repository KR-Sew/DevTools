# Ensure TLS 1.2 for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "🔹 Installing PowerShell 7..."
$pwshInstaller = "https://aka.ms/install-powershell.ps1"
Invoke-Expression "& { $(Invoke-RestMethod -Uri $pwshInstaller) } -UseMSI -Quiet"

# Wait for installation
Start-Sleep -Seconds 10

# Add PowerShell to PATH (optional)
$env:Path += ";C:\Program Files\PowerShell\7"

Write-Host "✅ PowerShell 7 Installed!"

Write-Host "🔹 Installing .NET Runtime..."
$dotnetInstaller = "https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-latest-windows-x64-installer"
$dotnetPath = "C:\Setup\dotnet-installer.exe"
Invoke-WebRequest -Uri $dotnetInstaller -OutFile $dotnetPath

Start-Process -FilePath $dotnetPath -ArgumentList "/quiet /norestart" -Wait
Write-Host "✅ .NET Runtime Installed!"

# Cleanup
Remove-Item -Path $dotnetPath -Force
