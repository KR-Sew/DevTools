#Requires -Version 5.1
<#
.SYNOPSIS
  Checks, installs or updates CPython using WinGet and repairs user command access.
.DESCRIPTION
  Default: Python 3.14, current user only. Existing other Python versions are kept.
  Creates .cmd command shims only for commands that are not working.
  No GitHub API calls, no global pip upgrades, no PowerShell profile changes.
.EXAMPLE
  .\Install-Update-Python.ps1
.EXAMPLE
  .\Install-Update-Python.ps1 -CheckOnly
.EXAMPLE
  .\Install-Update-Python.ps1 -Version 3.15 -SkipAliases
.NOTES
  Run under the account that will use Python. Do not use an elevated console
  running as a DIFFERENT administrator account for per-user installation.
  A py.cmd shim (if needed) is only a simple alias; it does not implement
  the full multi-version syntax of Python's official py launcher.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^3\.\d{1,2}$')]
    [string]$Version = '3.14',
    [switch]$CheckOnly,
    [switch]$SkipAliases
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PackageId = "Python.Python.$Version"
$ShimDirectory = Join-Path $env:LOCALAPPDATA 'Programs\PythonCommandAliases'
$script:ManagerAvailable = $false

function Write-Step([string]$Message) {
    Write-Host "`n== $Message ==" -ForegroundColor Cyan
}

function Get-AppCommandPath([string]$Name) {
    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $command) { return $command.Source }
    return $null
}

function Get-PythonVersion([string]$Executable) {
    if (-not $Executable -or -not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        return $null
    }
    # Avoid launching the Windows Store's placeholder aliases when there is
    # no Python Install Manager installed. Real manager aliases are tested.
    if ($Executable -match '(?i)[\\/]Microsoft[\\/]WindowsApps[\\/]' -and
        -not $script:ManagerAvailable) {
        return $null
    }
    try {
        $result = & $Executable -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $value = ($result | Select-Object -First 1).ToString().Trim()
            if ($value -match '^3\.\d+\.\d+$') { return $value }
        }
    } catch {
        # A broken interpreter is not a working installation.
    }
    return $null
}

function Get-RegistryPythonPaths([string]$Minor) {
    $keys = @(
        "Registry::HKEY_CURRENT_USER\Software\Python\PythonCore\$Minor\InstallPath",
        "Registry::HKEY_LOCAL_MACHINE\Software\Python\PythonCore\$Minor\InstallPath",
        "Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Python\PythonCore\$Minor\InstallPath"
    )
    foreach ($key in $keys) {
        try {
            $item = Get-Item -LiteralPath $key -ErrorAction Stop
            $fullExe = [string]$item.GetValue('ExecutablePath', '')
            if ($fullExe -and (Test-Path -LiteralPath $fullExe -PathType Leaf)) {
                Write-Output $fullExe
            }
            $directory = [string]$item.GetValue('', '')
            if ($directory) {
                $candidate = Join-Path $directory 'python.exe'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    Write-Output $candidate
                }
            }
        } catch {
            # Registry key absent or not readable; try the next location.
        }
    }
}

function Find-RequestedPython([string]$Minor) {
    $compact = $Minor.Replace('.', '')
    $candidates = @(
        @(Get-RegistryPythonPaths -Minor $Minor)
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python$compact\python.exe")
        (Join-Path $env:ProgramFiles "Python$compact\python.exe")
        (Get-AppCommandPath 'python.exe')
        (Get-AppCommandPath 'python3.exe')
    ) | ForEach-Object { $_ } | Where-Object { $_ } | Select-Object -Unique

    foreach ($candidate in $candidates) {
        $detected = Get-PythonVersion -Executable $candidate
        if ($detected -and $detected.StartsWith("$Minor.")) {
            return [pscustomobject]@{ Path = $candidate; Version = $detected }
        }
    }
    return $null
}

function Add-ToUserPathFirst([string]$Directory) {
    $Directory = [System.IO.Path]::GetFullPath($Directory).TrimEnd('\')
    $existing = [Environment]::GetEnvironmentVariable('Path', 'User')
    $remaining = @($existing -split ';' | Where-Object {
        $_ -and ($_.Trim().TrimEnd('\') -ine $Directory)
    })
    $newPath = (@($Directory) + $remaining) -join ';'
    if ($newPath -cne $existing) {
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Updated user PATH: $Directory"
    }
    $sessionRemaining = @($env:Path -split ';' | Where-Object {
        $_ -and ($_.Trim().TrimEnd('\') -ine $Directory)
    })
    $env:Path = (@($Directory) + $sessionRemaining) -join ';'
}

function Write-CommandShim([string]$CommandName, [string]$Target) {
    if (-not (Test-Path -LiteralPath $ShimDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $ShimDirectory -Force | Out-Null
    }
    $shimPath = Join-Path $ShimDirectory "$CommandName.cmd"
    # Escape % in paths because .cmd interprets it as environment expansion.
    $quotedTarget = $Target.Replace('%', '%%').Replace('"', '')
    $body = "@echo off`r`n`"$quotedTarget`" %*`r`n"
    [System.IO.File]::WriteAllText($shimPath, $body, [System.Text.Encoding]::Default)
    Write-Host "Created command shim: $CommandName -> $Target"
}

function Test-PythonCommand([string]$CommandName) {
    $path = Get-AppCommandPath $CommandName
    if (-not $path) { return $null }
    $foundVersion = Get-PythonVersion -Executable $path
    if (-not $foundVersion) { return $null }
    return [pscustomobject]@{ Path = $path; Version = $foundVersion }
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'This script is only for Windows.'
    }
    if ($env:VIRTUAL_ENV) {
        Write-Warning 'A Python virtual environment is active. Deactivate it before interpreting command/version results.'
    }

    $script:ManagerAvailable = [bool](Get-AppCommandPath 'pymanager.exe')
    if (-not $script:ManagerAvailable -and (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        $script:ManagerAvailable = [bool](Get-AppxPackage -Name 'PythonSoftwareFoundation.PythonManager' -ErrorAction SilentlyContinue)
    }

    Write-Step 'Current Python configuration'
    foreach ($name in @('python', 'python3', 'py')) {
        $current = Test-PythonCommand -CommandName $name
        if ($current) {
            Write-Host ("{0,-8} {1,-10} {2}" -f $name, $current.Version, $current.Path)
        } else {
            Write-Host ("{0,-8} {1}" -f $name, 'not working / not found') -ForegroundColor Yellow
        }
    }

    $target = Find-RequestedPython -Minor $Version
    if ($target) {
        Write-Host "Requested Python $Version found: $($target.Version) at $($target.Path)"
    } else {
        Write-Host "Requested Python $Version not detected." -ForegroundColor Yellow
    }

    $winget = Get-AppCommandPath 'winget.exe'
    if ($CheckOnly) {
        Write-Step 'Read-only check complete'
        if ($winget) { Write-Host "WinGet: $winget" }
        else { Write-Warning 'WinGet is not available.' }
        exit 0
    }
    if (-not $winget) {
        throw 'WinGet is missing. Install/update Windows App Installer from Microsoft, then rerun.'
    }

    Write-Step "Install or update $PackageId through WinGet"
    # Winget install without --no-upgrade also upgrades an already recognized
    # installation. It keeps other Python minor versions intact.
    $wingetArguments = @(
        'install', '--exact', '--id', $PackageId, '--source', 'winget',
        '--scope', 'user', '--silent', '--disable-interactivity',
        '--accept-package-agreements', '--accept-source-agreements'
    )
    & $winget @wingetArguments
    $installExitCode = $LASTEXITCODE
    if ($installExitCode -ne 0) {
        throw "WinGet failed with exit code $installExitCode. Check network access, source availability, and winget logs."
    }

    Write-Step 'Locate and verify requested interpreter'
    $target = Find-RequestedPython -Minor $Version
    if (-not $target) {
        throw "WinGet finished but Python $Version was not found. Open a new terminal and run this script with -CheckOnly."
    }
    Write-Host "Python $($target.Version): $($target.Path)" -ForegroundColor Green

    $python = Test-PythonCommand -CommandName 'python'
    if (-not $python) {
        Write-Step 'Repair user PATH for python'
        Add-ToUserPathFirst -Directory (Split-Path -Path $target.Path -Parent)
        $python = Test-PythonCommand -CommandName 'python'
        if (-not $python) {
            # Last resort for a broken/missing python command: a user shim.
            Write-CommandShim -CommandName 'python' -Target $target.Path
            Add-ToUserPathFirst -Directory $ShimDirectory
            $python = Test-PythonCommand -CommandName 'python'
        }
    }
    if (-not $python) {
        throw 'Python is installed, but the python command remains unavailable. Inspect Get-Command python -All and Windows App Execution Aliases.'
    }

    if (-not $SkipAliases) {
        Write-Step 'Check optional command aliases'
        foreach ($aliasName in @('python3', 'py')) {
            $aliasStatus = Test-PythonCommand -CommandName $aliasName
            if ($aliasStatus) {
                Write-Host "Keeping existing $aliasName command: $($aliasStatus.Path)"
            } else {
                Write-CommandShim -CommandName $aliasName -Target $python.Path
                Add-ToUserPathFirst -Directory $ShimDirectory
                if ($aliasName -eq 'py') {
                    Write-Warning 'py.cmd is a basic command alias, not the official multi-version py launcher.'
                }
            }
        }
    }

    Write-Step 'Final verification'
    foreach ($name in @('python', 'python3', 'py')) {
        $status = Test-PythonCommand -CommandName $name
        if ($status) {
            Write-Host ("{0,-8} {1,-10} {2}" -f $name, $status.Version, $status.Path) -ForegroundColor Green
        } else {
            Write-Warning "$name is still not working in the current session."
        }
    }
    & $target.Path -m pip --version
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'pip is unavailable for the requested Python version. Use: python -m ensurepip --upgrade'
    }
    if ($python.Version -notlike "$Version.*") {
        Write-Warning "The existing 'python' command uses $($python.Version), not requested $Version. Existing working commands were preserved."
        Write-Host "Requested interpreter is directly available at: $($target.Path)"
    }
    Write-Host "`nDone. New terminals will inherit the user PATH changes." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
