<#
.SYNOPSIS
    macify-windows: Automated Winget Dependency Installer.
.DESCRIPTION
    Verifies Windows Package Manager (winget) availability and silently installs
    core open-source packages required for the macOS transformation:
    - QuickLook (Spacebar file preview)
    - PowerToys (Spotlight search via PowerToys Run)
    - TranslucentTB (Acrylic dock/taskbar styling)
    - Rainmeter (macOS Top Menu/Status Bar)
    - MacType (macOS font smoothing engine)
    - AutoHotkey v2 (macOS shortcuts & keybindings)
#>

[CmdletBinding()]
param(
    [switch]$ForceReinstall
)

# Load common utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "common.ps1")

Write-MacHeader "STAGE 2: CORE OPEN-SOURCE DEPENDENCY INSTALLATION"

# 1. Verify winget availability
function Test-WingetAvailable {
    try {
        $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($wingetCmd) { return $true }

        # Check App Execution Aliases
        $localAlias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
        if (Test-Path -Path $localAlias) { return $true }
    } catch {}
    return $false
}

if (-not (Test-WingetAvailable)) {
    Write-MacError "Windows Package Manager (winget) is not installed or not in PATH."
    Write-MacWarn "Please update Windows App Installer from the Microsoft Store or install winget from:"
    Write-MacWarn "https://github.com/microsoft/winget-cli/releases"
    throw "winget is required to install open-source utilities."
}

Write-MacSuccess "Windows Package Manager (winget) is operational."

# 2. Package manifest
$macifyPackages = @(
    @{
        Id          = "QL-Win.QuickLook"
        Name        = "QuickLook"
        Description = "macOS Finder Spacebar preview engine"
    },
    @{
        Id          = "Microsoft.PowerToys"
        Name        = "Microsoft PowerToys"
        Description = "PowerToys Run for macOS Spotlight search"
    },
    @{
        Id          = "CharlesMilette.TranslucentTB"
        Name        = "TranslucentTB"
        Description = "Acrylic and transparent floating taskbar styling"
    },
    @{
        Id          = "Rainmeter.Rainmeter"
        Name        = "Rainmeter"
        Description = "macOS Top Menu Bar and System Tray skin framework"
    },
    @{
        Id          = "Snowie2000.MacType"
        Name        = "MacType"
        Description = "macOS subpixel font rasterization and font smoothing"
    },
    @{
        Id          = "AutoHotkey.AutoHotkey"
        Name        = "AutoHotkey v2"
        Description = "macOS keyboard shortcuts, Cmd keybindings and hotkeys"
    }
)

# 3. Check and install packages
Write-MacStep "Verifying and installing core packages..."

foreach ($pkg in $macifyPackages) {
    Write-MacLog "Checking status for [$($pkg.Name)] ($($pkg.Id))..." "INFO"

    $isInstalled = $false
    if (-not $ForceReinstall) {
        # Check if already installed
        $checkResult = & winget list --exact --id $pkg.Id 2>&1 | Out-String
        if ($checkResult -match [regex]::Escape($pkg.Id)) {
            $isInstalled = $true
        }
    }

    if ($isInstalled) {
        Write-MacSuccess "[$($pkg.Name)] is already installed and up to date."
    } else {
        Write-MacLog "Installing [$($pkg.Name)] - $($pkg.Description)..." "INFO"
        
        $installArgs = @(
            "install",
            "--exact",
            "--id", $pkg.Id,
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--disable-interactivity"
        )

        try {
            $process = Start-Process -FilePath "winget.exe" -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
            
            # Winget exit codes: 0 = Success, -1978335189 (0x8A15002B) = Already installed/No applicable update
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
                Write-MacSuccess "[$($pkg.Name)] successfully installed."
            } else {
                Write-MacWarn "[$($pkg.Name)] finished with exit code $($process.ExitCode). Verifying presence..."
            }
        } catch {
            Write-MacWarn "Error installing $($pkg.Name): $($_.Exception.Message)"
        }
    }
}

Write-MacSuccess "All core dependencies verified."
