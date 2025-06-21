<#
.SYNOPSIS
    Creates a dual-mode (UEFI + BIOS) bootable ISO from Windows Server 2025 ISO,
    containing only one Server Core edition, selected interactively.
#>

param (
    [Parameter(Mandatory)]
    [string]$SourceISO,

    [Parameter(Mandatory)]
    [string]$OutputISO
)

$WorkingDir = "$env:TEMP\WS2025_CoreISO"
$OscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

# Cleanup old working directory
if (Test-Path $WorkingDir) { Remove-Item $WorkingDir -Recurse -Force }
New-Item -Path $WorkingDir -ItemType Directory | Out-Null

# Mount the ISO
Write-Host "[+] Mounting source ISO..." -ForegroundColor Cyan
$mount = Mount-DiskImage -ImagePath $SourceISO -PassThru
Start-Sleep -Seconds 2
$ISODrive = ($mount | Get-Volume).DriveLetter + ":"

# Copy ISO contents
Write-Host "[+] Copying ISO contents..." -ForegroundColor Cyan
robocopy "$ISODrive\" "$WorkingDir" /E > $null

# Display image indexes
$OriginalWIM = Join-Path "$ISODrive\sources" "install.wim"
Write-Host "`n[+] Getting available editions from install.wim..." -ForegroundColor Cyan
$images = dism /Get-ImageInfo /ImageFile:"$OriginalWIM"

# Parse output and show selection
$parsed = @()
foreach ($line in $images) {
    if ($line -match "^Index\s+:\s+(\d+)") {
        $index = $matches[1]
    }
    if ($line -match "^Name\s+:\s+(.+)$") {
        $name = $matches[1]
        $parsed += [PSCustomObject]@{ Index = $index; Name = $name }
    }
}

$parsed | Format-Table -AutoSize

do {
    $selection = Read-Host "`nEnter the Index number of the Server Core edition to include"
} until ($parsed.Index -contains $selection)

# Export selected edition
$DestWIM = Join-Path "$WorkingDir\sources" "install.wim"
Write-Host "[+] Exporting index $selection..." -ForegroundColor Green
dism /Export-Image /SourceImageFile:"$OriginalWIM" /SourceIndex:$selection /DestinationImageFile:"$DestWIM" /Compress:max /CheckIntegrity

# Unmount ISO
Write-Host "[+] Unmounting ISO..." -ForegroundColor DarkCyan
Dismount-DiskImage -ImagePath $SourceISO

# Build dual-mode ISO
$BootEFI  = "$WorkingDir\efi\microsoft\boot\efisys.bin"
$BootBIOS = "$WorkingDir\boot\etfsboot.com"

Write-Host "[+] Creating final bootable ISO..." -ForegroundColor Green
& "$OscdimgPath" `
    -m -o -u2 -udfver102 `
    -bootdata:2#p0,e,b"$BootBIOS"#pEF,e,b"$BootEFI" `
    -lWS2025_CORE `
    "$WorkingDir" "$OutputISO"

Write-Host "`n✅ Bootable ISO created at: $OutputISO" -ForegroundColor Green
