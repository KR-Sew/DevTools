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

# Add this before mounting
$OutputDir = Split-Path $OutputISO
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# Mount the ISO
Write-Host "[+] Mounting source ISO..."
$mount = Mount-DiskImage -ImagePath $SourceISO -PassThru
Start-Sleep -Seconds 2
$ISODrive = ($mount | Get-Volume).DriveLetter + ":"

# Copy ISO contents
Write-Host "[+] Copying ISO contents (excluding install.wim)..." -ForegroundColor Cyan
robocopy "$ISODrive\" "$WorkingDir" /E /XF "install.wim" > $null


# Display image indexes
$OriginalWIM = Join-Path "$ISODrive\sources" "install.wim"
# Get edition info
Write-Host "`n[+] Getting available editions from install.wim..." -ForegroundColor DarkCyan

$images = & dism /Get-WimInfo /WimFile:"$OriginalWIM" 2>&1
$parsed = @()

$index = $null
$name = $null

foreach ($line in $images) {
    if ($line -match "^\s*(Index|Индекс)\s*:\s*(\d+)") {
        $index = $matches[2]
    }
    elseif ($line -match "^\s*(Name|Имя)\s*:\s*(.+)$") {
        $name = $matches[2]
        if ($index) {
            $parsed += [PSCustomObject]@{ Index = $index; Name = $name }
            $index = $null
        }
    }
}

if ($parsed.Count -eq 0) {
    Write-Error "❌ No editions found. Make sure install.wim exists and is valid."
    exit 1
}

Write-Host "`nAvailable editions:"
$parsed | Format-Table -AutoSize

do {
    $selection = Read-Host "`nEnter the Index number of the Server Core edition to include"
} until ($parsed.Index -contains $selection)

# Export selected edition
$DestWIM = Join-Path "$WorkingDir\sources" "install.wim"
Write-Host "[+] Exporting index $selection to $DestWIM..." -ForegroundColor Cyan
dism /Export-Image /SourceImageFile:"$OriginalWIM" /SourceIndex:$selection /DestinationImageFile:"$DestWIM" /Compress:max /CheckIntegrity

# Unmount ISO
Write-Host "[+] Unmounting ISO..." -ForegroundColor Cyan
Dismount-DiskImage -ImagePath $SourceISO

# Build dual-mode ISO
$BootEFI  = "$WorkingDir\efi\microsoft\boot\efisys.bin"
$BootBIOS = "$WorkingDir\boot\etfsboot.com"

# Replace the ISO build section with:
Write-Host "[+] Creating final bootable ISO..." -ForegroundColor Green
$oscdimgArgs = @(
    "-m", "-o", "-u2", "-udfver102",
    "-bootdata:2#p0,e,b$BootBIOS#pEF,e,b$BootEFI",
    "-lWS2025_CORE",
    "$WorkingDir", "$OutputISO"
)
$null = & "$OscdimgPath" @oscdimgArgs

if (Test-Path $OutputISO) {
    Write-Host "`n✅ Bootable ISO created at: $OutputISO" -ForegroundColor Green
} else {
    Write-Error "❌ Failed to create ISO at: $OutputISO"
}