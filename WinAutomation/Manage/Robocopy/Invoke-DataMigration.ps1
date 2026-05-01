param (
    [Parameter(Mandatory = $true)]
    [string]$SourceVolume,        # e.g. "R:\"

    [Parameter(Mandatory = $true)]
    [string]$SourceFolder,        # e.g. "Shares\Projects"

    [Parameter(Mandatory = $true)]
    [string]$DestinationFolder,   # e.g. "P:\Shares\Projects"

    [Parameter()]
    [switch]$UseShadowLink,

    [string]$LogPath = "C:\Logs",

    [int]$Threads = 16,

    [switch]$KeepShadow,

    [ValidateSet("Baseline","Sync","Final","Validate")]
    [string]$Mode = "Baseline"
)

# =========================
# Logging
# =========================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Level] $Message"
}

# =========================
# Ensure log directory
# =========================
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$LogFile = Join-Path $LogPath "robocopy_$Mode_$(Get-Date -Format yyyyMMdd_HHmm).log"

# =========================
# Create Shadow Copy
# =========================
function New-ShadowCopy {
    param([string]$Volume)

    Write-Log "Creating VSS snapshot for $Volume"

    $shadow = (Get-WmiObject -List Win32_ShadowCopy).Create($Volume, "ClientAccessible")

    if ($shadow.ReturnValue -ne 0) {
        throw "Failed to create shadow copy. ReturnValue=$($shadow.ReturnValue)"
    }

    $shadowObj = Get-WmiObject Win32_ShadowCopy |
        Where-Object { $_.ID -eq $shadow.ShadowID }

    Write-Log "Shadow copy created: $($shadowObj.DeviceObject)"

    return $shadowObj
}

# =========================
# Create ShadowLog(SymLink)
# =========================
function New-ShadowLink {
    param(
        [string]$ShadowDevice,
        [string]$LinkPath = "C:\ShadowCopy"
    )

    if (Test-Path $LinkPath) {
        Remove-Item $LinkPath -Force -Recurse
    }

    Write-Log "Creating shadow link: $LinkPath -> $ShadowDevice"

    cmd /c mklink /d $LinkPath "$ShadowDevice" | Out-Null

    if (!(Test-Path $LinkPath)) {
        throw "Failed to create shadow link"
    }

    return $LinkPath
}

function Remove-ShadowLink {
    param([string]$LinkPath)

    if (Test-Path $LinkPath) {
        Write-Log "Removing shadow link: $LinkPath"
        Remove-Item $LinkPath -Force -Recurse
    }
}

# =========================
# Remove Shadow Copy
# =========================
function Remove-ShadowCopy {
    param($ShadowObject)

    Write-Log "Deleting shadow copy: $($ShadowObject.ID)"

    $ShadowObject.Delete() | Out-Null
}

# =========================
# Run Robocopy
# =========================
function Invoke-RoboCopy {
    param (
        [string]$Source,
        [string]$Destination,
        [string]$Mode
    )

    Write-Log "Starting robocopy ($Mode)"
    Write-Log "Source      : $Source"
    Write-Log "Destination : $Destination"
    Write-Log "Log file    : $LogFile"

    $Options = @(
        "/COPYALL"
        "/R:2"
        "/W:2"
        "/MT:$Threads"
        "/TEE"
        "/LOG:$LogFile"
    )

    switch ($Mode) {
        "Baseline" { $CopyMode = "/E" }
        "Sync"     { $CopyMode = "/E" }
        "Final"    { $CopyMode = "/MIR" }
        "Validate" { $CopyMode = "/E /L /NJH /NJS" }
    }

    robocopy $Source $Destination $CopyMode $Options

    if ($LASTEXITCODE -le 3) {
        Write-Log "Robocopy completed successfully (code: $LASTEXITCODE)" "OK"
    }
    else {
        Write-Log "Robocopy finished with warnings/errors (code: $LASTEXITCODE)" "WARN"
    }
}

# =========================
# MAIN LOGIC
# =========================

switch ($Mode) {

    "Baseline" {

        $shadow = New-ShadowCopy -Volume $SourceVolume

        $ShadowSource = "$($shadow.DeviceObject)\$SourceFolder"

        Invoke-RoboCopy -Source $ShadowSource -Destination $DestinationFolder -Mode "Baseline"

        if (-not $KeepShadow) {
            Remove-ShadowCopy -ShadowObject $shadow
        }
        else {
            Write-Log "Shadow copy retained as requested"
        }
    }

    "Sync" {

        $Source = Join-Path $SourceVolume $SourceFolder

        Invoke-RoboCopy -Source $Source -Destination $DestinationFolder -Mode "Sync"
    }

    "Final" {

        Write-Log "FINAL SYNC - Ensure services/users are stopped!"

        $Source = Join-Path $SourceVolume $SourceFolder

        Invoke-RoboCopy -Source $Source -Destination $DestinationFolder -Mode "Final"
    }

    "Validate" {

        Write-Log "Running validation (no data will be copied)"

        $Source = Join-Path $SourceVolume $SourceFolder

        Invoke-RoboCopy -Source $Source -Destination $DestinationFolder -Mode "Validate"
    }
}