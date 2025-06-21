<#
.SYNOPSIS
    Create a bootable dual-mode (UEFI + BIOS) Windows Server 2025 ISO with only one Server Core edition.
.DESCRIPTION
    Mounts an original ISO, exports one Server Core edition, replaces the install.wim,
    and creates a new ISO that boots in both BIOS and UEFI environments.
#>

param (
    [Parameter(Mandatory)]
    [string]$SourceISO,

    [Parameter(Mandatory)]
    [int]$EditionIndex,

    [Parameter(Mandatory)]
    [string]$OutputISO
)

# Configurable Paths
$WorkingDir = "$env:TEMP\WS2025_CoreISO"
$OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

# Step 1: Cleanup and Prepare Working Directory
if (Test-Path $WorkingDir) { Remove-Item $WorkingDir -Recurse -Force }
New-Item -Path $WorkingDir -ItemType Directory | Out-Null

# Step 2: Mount Original ISO
Write-Host "[+] Mounting ISO..." -ForegroundColor Cyan
$Mount = Mount-DiskImage -ImagePath $SourceISO -PassThru
Start-Sleep -Seconds 2
$ISOdrive = ($Mount | Get-Volume).DriveLetter + ":"

# Step 3: Copy all ISO contents to working folder
Write-Host "[+] Copying ISO contents..." -ForegroundColor Cyan
robocopy "$ISOdrive\" "$WorkingDir" /E > $null

# Step 4: Export Server Core edition to replace install.wim
$OriginalWIM = Join-Path -Path "$ISOdrive\sources" -ChildPath "install.wim"
$CustomWIM   = Join-Path -Path "$WorkingDir\sources" -ChildPath "install.wim"

Write-Host "[+] Exporting Server Core edition index $EditionIndex..." -ForegroundColor DarkCyan
dism /Export-Image /SourceImageFile:"$OriginalWIM" /SourceIndex:$EditionIndex /DestinationImageFile:"$CustomWIM" /Compress:Max /CheckIntegrity

# Step 5: Unmount ISO
Write-Host "[+] Unmounting ISO..." -ForegroundColor DarkCyan
Dismount-DiskImage -ImagePath $SourceISO

# Step 6: Build Dual-Mode Bootable ISO (UEFI + BIOS)
$BootEFI = "$WorkingDir\efi\microsoft\boot\efisys.bin"
$BootBIOS = "$WorkingDir\boot\etfsboot.com"

Write-Host "[+] Creating bootable ISO (UEFI + BIOS)..." -ForegroundColor Green
& "$OscdimgPath" `
    -m -o -u2 -udfver102 `
    -bootdata:2#p0,e,b"$BootBIOS"#pEF,e,b"$BootEFI" `
    -lWS2025_CORE `
    "$WorkingDir" "$OutputISO"

Write-Host "`n✅ ISO created at: $OutputISO" -ForegroundColor Green
