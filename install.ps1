<#
.SYNOPSIS
    macify-windows: Master Entry-Point Installer.
.DESCRIPTION
    Autonomously transforms Windows 11 into an authentic macOS Sonoma/Sequoia desktop experience:
    - Pre-flight backup & System Restore point creation
    - Silently installs core dependencies (TranslucentTB, QuickLook, PowerToys, Rainmeter, MacType, AHK)
    - Deploys WhiteSur Cursors, 4K macOS Wallpapers, Inter/JetBrains fonts, and subtle alert sounds
    - Configures Centered Floating Dock, Dark/Light mode, and MacTopBar (macOS menu bar)
    - Configures Finder-style Explorer, Spacebar preview, and Spotlight hotkey daemon (Alt+Space)
.PARAMETER Dark
    Applies macOS Dark Mode theme and dark wallpaper.
.PARAMETER Light
    Applies macOS Light Mode theme and light wallpaper.
.PARAMETER Uninstall
    Triggers complete uninstallation and rollback to standard Windows defaults.
.PARAMETER Silent
    Runs without interactive prompts using sensible defaults (macOS Dark mode, Sequoia 4K).
.PARAMETER SkipBackup
    Skips the pre-flight System Restore Point and registry backup.
.PARAMETER Help
    Displays command line usage and parameter documentation.
#>

[CmdletBinding()]
param(
    [switch]$Dark,
    [switch]$Light,
    [switch]$Uninstall,
    [switch]$Silent,
    [switch]$SkipBackup,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
macify-windows: Unified macOS Sonoma & Sequoia Interface for Windows 11
Version 1.0.0

USAGE:
  powershell -ExecutionPolicy Bypass -File .\install.ps1 [OPTIONS]

OPTIONS:
  -Dark         Apply macOS Dark theme & Sequoia Dark wallpaper
  -Light        Apply macOS Light theme & Sequoia Light wallpaper
  -Silent       Run completely automated installation without prompts
  -SkipBackup   Skip pre-flight system restore point & registry backup
  -Uninstall    Rollback all changes and restore original Windows environment
  -Help         Show this help information

ONE-LINE INSTALL (Run in Administrator PowerShell):
  irm https://raw.githubusercontent.com/adityalokhande0011/macify-windows/main/install.ps1 | iex
"@
    exit 0
}

# Load common utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "scripts\common.ps1")

# Handle uninstallation forward
if ($Uninstall) {
    $uninstallScript = Join-Path $scriptDir "uninstall.ps1"
    & $uninstallScript
    exit 0
}

# 1. Administrator Elevation Check & Self-Elevation
Assert-Admin -ScriptArgs $args

# 2. Windows 11 Compatibility Check
Clear-Host
if (-not (Test-Windows11)) {
    exit 1
}

# 3. Interactive Banner
Write-Host @"
================================================================================
   __  __            _  __         __        ___           _                     
  |  \/  | __ _  ___(_)/ _|_   _   \ \      / (_)_ __   __| | _____      _____   
  | |\/| |/ _` |/ __| | |_| | | |___\ \ /\ / /| | '_ \ / _` |/ _ \ \ /\ / / __|  
  | |  | | (_| | (__| |  _| |_| |_____\ V  V / | | | | | (_| | (_) \ V  V /\__ \  
  |_|  |_|\__,_|\___|_|_|  \__, |      \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/ |___/  
                           |___/                                                  
          Unified macOS Sonoma & Sequoia Interface for Windows 11
================================================================================
"@ -ForegroundColor Cyan

# 4. Resolve Configuration Options
$chosenTheme     = "Dark"
$chosenWallpaper = "Sequoia-Dark"
$autoHideDock    = $false

if ($Light) {
    $chosenTheme     = "Light"
    $chosenWallpaper = "Sequoia-Light"
} elseif ($Dark) {
    $chosenTheme     = "Dark"
    $chosenWallpaper = "Sequoia-Dark"
} elseif (-not $Silent) {
    Write-Host "Select your desired macOS configuration:`n" -ForegroundColor White

    Write-Host " [1] macOS Sequoia Dark Mode (Recommended)" -ForegroundColor Cyan
    Write-Host " [2] macOS Sequoia Light Mode" -ForegroundColor White
    Write-Host " [3] macOS Sonoma Dark Mode" -ForegroundColor White
    Write-Host " [4] macOS Sonoma Light Mode" -ForegroundColor White
    Write-Host ""
    
    $selection = Read-Host " Enter choice [1-4] (Default: 1)"
    switch ($selection) {
        "2" {
            $chosenTheme     = "Light"
            $chosenWallpaper = "Sequoia-Light"
        }
        "3" {
            $chosenTheme     = "Dark"
            $chosenWallpaper = "Sonoma-Dark"
        }
        "4" {
            $chosenTheme     = "Light"
            $chosenWallpaper = "Sonoma-Light"
        }
        default {
            $chosenTheme     = "Dark"
            $chosenWallpaper = "Sequoia-Dark"
        }
    }

    $dockPrompt = Read-Host "`n Would you like to enable Taskbar Auto-Hide for a pure floating dock experience? (y/N) [Default: N]"
    if ($dockPrompt -match "^[Yy]$") {
        $autoHideDock = $true
    }
}

Write-MacLog "Theme Mode: macOS $chosenTheme" "INFO"
Write-MacLog "Wallpaper:  macOS $chosenWallpaper (4K)" "INFO"
Write-MacLog "Dock Mode:  Centered Acrylic Dock $(if ($autoHideDock) {'(Auto-Hide Enabled)'} else {''})" "INFO"
Start-Sleep -Seconds 1

# ==============================================================================
# EXECUTION PIPELINE
# ==============================================================================

# STAGE 1: Backup & Restore Point
if (-not $SkipBackup) {
    $backupScript = Join-Path $scriptDir "scripts\backup.ps1"
    & $backupScript
} else {
    Write-MacWarn "Skipping pre-flight backup per -SkipBackup flag."
}

# STAGE 2: Open-Source Dependencies
$depsScript = Join-Path $scriptDir "scripts\dependencies.ps1"
& $depsScript

# STAGE 3: macOS Visual & Audio Assets
$assetsScript = Join-Path $scriptDir "scripts\assets.ps1"
& $assetsScript -WallpaperChoice $chosenWallpaper

# STAGE 4: Windows 11 Shell & Floating Dock
$shellScript = Join-Path $scriptDir "scripts\win11-shell.ps1"
if ($autoHideDock) {
    & $shellScript -Theme $chosenTheme -EnableAutoHideTaskbar
} else {
    & $shellScript -Theme $chosenTheme
}

# STAGE 5: Finder Explorer, QuickLook & Spotlight Keybindings
$explorerScript = Join-Path $scriptDir "scripts\win11-explorer.ps1"
& $explorerScript

# Final Environment Refresh
Update-WindowsEnvironment

# ==============================================================================
# COMPLETION SUMMARY & SHORTCUTS GUIDE
# ==============================================================================
Clear-Host
Write-Host @"
================================================================================
   ✨  MACIFY-WINDOWS INSTALLATION COMPLETE!  ✨
================================================================================

 Your Windows 11 desktop is now transformed into macOS $chosenTheme ($chosenWallpaper)!

 KEYBOARD SHORTCUTS CHEAT SHEET:
 +---------------------------+-----------------------------------------------+
 | macOS Shortcut            | Windows 11 Equivalent Action                  |
 +---------------------------+-----------------------------------------------+
 | Alt + Space / Win + Space | macOS Spotlight Search (PowerToys Run)       |
 | Spacebar (in Explorer)    | QuickLook File Preview (Images, PDFs, Media)  |
 | Alt + Q                   | Close Active Window (like Cmd + Q)            |
 | Alt + W                   | Close Active Tab (like Cmd + W)               |
 | Alt + M                   | Minimize Active Window (like Cmd + M)         |
 | Alt + H                   | Hide Active Window (like Cmd + H)             |
 | Alt + C / V / X / Z       | macOS Command Clipboard Ergonomics            |
 | Alt + Shift + 3           | Fullscreen Screenshot                         |
 | Alt + Shift + 4           | Interactive Region Snip Tool                  |
 +---------------------------+-----------------------------------------------+

 ACTIVE macOS MODULES:
  [✔] TranslucentTB: Acrylic floating centered dock
  [✔] Rainmeter MacTopBar: Top macOS status bar with Apple menu & stats
  [✔] WhiteSur Cursors: High-DPI macOS cursor scheme
  [✔] QuickLook: Spacebar instant previews
  [✔] PowerToys Run & AHK: Spotlight search daemon
  [✔] Finder Explorer: Compact spacing, extensions visible

 Need to revert? Run:
   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

 Logs and backups are saved at:
   Backup:  $global:MacifyBackupDir
   Logs:    $global:MacifyLogDir

================================================================================
"@ -ForegroundColor Green
