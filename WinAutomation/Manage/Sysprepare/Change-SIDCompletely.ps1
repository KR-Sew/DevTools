#Requires -RunAsAdministrator

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
    }

    $prefix = switch ($Level) {
        "INFO"    { "🔹" }
        "WARN"    { "⚠" }
        "ERROR"   { "❌" }
        "SUCCESS" { "✅" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

Write-Log "Checking current PowerShell Execution Policy..." -Level INFO

# $currentPolicy = Get-ExecutionPolicy -Scope Process (it keeps here just for remark key -Scope. Process scope has the highest precedence among the locally configurable scopes. )
$effectivePolicy = Get-ExecutionPolicy

if ($effectivePolicy -in @("Restricted", "AllSigned")) {
    Write-Log "Current effective Execution Policy is: $effectivePolicy" -Level WARN
    Write-Log "This may prevent the script or additional PowerShell actions from running properly." -Level WARN

    $choice = Read-Host "Continue and set Execution Policy to Bypass only for this PowerShell session? [Y/N]"

    if ($choice -notmatch '^(Y|y|Yes|yes)$') {
        Write-Log "Script was stopped by user choice." -Level ERROR
        exit 1
    }

    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Log "Execution Policy was set to Bypass for current session only." -Level SUCCESS
}

Write-Log "Checking if Sysprep is available..." -Level INFO

$sysprepPath = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"

if (-not (Test-Path $sysprepPath)) {
    Write-Log "Sysprep is not found on this system!" -Level ERROR
    exit 1
}

Write-Log "The system will shut down after Sysprep completes!" -Level WARN

$confirm = Read-Host "Are you sure you want to run Sysprep with /generalize /oobe /shutdown? [Y/N]"

if ($confirm -notmatch '^(Y|y|Yes|yes)$') {
    Write-Log "Sysprep was cancelled by user." -Level ERROR
    exit 1
}

Write-Log "Running Sysprep to reset SID..." -Level INFO

try {
    $process = Start-Process `
        -FilePath $sysprepPath `
        -ArgumentList "/generalize /oobe /shutdown /quiet" `
        -Wait `
        -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Log "Sysprep completed successfully. The system will shut down now." -Level SUCCESS
    }
    else {
        Write-Log "Sysprep finished with exit code: $($process.ExitCode)" -Level ERROR
        exit $process.ExitCode
    }
}
catch {
    Write-Log "Failed to run Sysprep. Error: $($_.Exception.Message)" -Level ERROR
    exit 1
}