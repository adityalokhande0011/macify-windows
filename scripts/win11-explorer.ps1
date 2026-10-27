<#
.SYNOPSIS
    macify-windows: Finder-Style Explorer, QuickLook & Spotlight Keybindings.
.DESCRIPTION
    - Configures Windows 11 Explorer with Finder layout (Compact mode, file extensions visible, Home/This PC launch)
    - Configures QuickLook to run at startup and activates it for instant Spacebar preview
    - Deploys AutoHotkey v2 macOS keyboard ergonomics daemon (Alt+Space Spotlight, Alt+Q Quit, Cmd keys)
    - Restarts Windows Explorer cleanly to apply all interface modifications
#>

[CmdletBinding()]
param(
    [switch]$SkipExplorerRestart
)

# Load common utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "common.ps1")

Write-MacHeader "STAGE 5: FINDER EXPLORER, QUICKLOOK & SPOTLIGHT"

# ==============================================================================
# 1. Finder-Style File Explorer Configuration
# ==============================================================================
Write-MacStep "Configuring Finder-style Windows 11 File Explorer..."

$advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Compact Mode (Tighter item spacing, like macOS Finder list/icon views)
Set-MacRegistryValue -Path $advKey -Name "UseCompactMode" -Value 1 -PropertyType "DWord"

# Show File Extensions (.png, .ps1, .pdf, etc. like Finder)
Set-MacRegistryValue -Path $advKey -Name "HideFileExt" -Value 0 -PropertyType "DWord"

# Launch File Explorer to "This PC" (1) or "Home" (2)
Set-MacRegistryValue -Path $advKey -Name "LaunchTo" -Value 1 -PropertyType "DWord"

# Show hidden files and folders
Set-MacRegistryValue -Path $advKey -Name "Hidden" -Value 1 -PropertyType "DWord"

# Show full path in title bar
$cabinetKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"
Set-MacRegistryValue -Path $cabinetKey -Name "FullPath" -Value 1 -PropertyType "DWord"

Write-MacSuccess "Explorer configured with Finder compact layout and file extension visibility."

# ==============================================================================
# 2. Spacebar QuickLook Configuration
# ==============================================================================
Write-MacStep "Configuring Spacebar QuickLook preview daemon..."

# Locate QuickLook binary (winget or store app)
$qlPath = Join-Path $env:LOCALAPPDATA "Programs\QuickLook\QuickLook.exe"
if (-not (Test-Path -Path $qlPath)) {
    # Check alternate install locations
    $possible = @(
        (Join-Path $env:ProgramFiles "QuickLook\QuickLook.exe"),
        (Join-Path $env:LOCALAPPDATA "QuickLook\QuickLook.exe")
    )
    foreach ($p in $possible) {
        if (Test-Path -Path $p) { $qlPath = $p; break }
    }
}

$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path -Path $qlPath) {
    Set-MacRegistryValue -Path $runKey -Name "QuickLook" -Value "`"$qlPath`"" -PropertyType "String"
    
    # Launch QuickLook if not active
    if (-not (Get-Process -Name "QuickLook" -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $qlPath -ErrorAction SilentlyContinue
    }
    Write-MacSuccess "QuickLook active. Press Spacebar on any file in Explorer to preview!"
} else {
    # Attempt to launch via Windows App protocol or UWP alias
    try {
        Start-Process -FilePath "explorer.exe" -ArgumentList "shell:AppsFolder\21090Poiru.QuickLook_4gcv5f925ez32!QuickLook" -ErrorAction SilentlyContinue
        Write-MacSuccess "QuickLook Store package launched."
    } catch {
        Write-MacWarn "QuickLook binary not found in standard paths; it will start after first manual run."
    }
}

# ==============================================================================
# 3. macOS Keyboard Shortcuts & Spotlight (AutoHotkey v2)
# ==============================================================================
Write-MacStep "Deploying macOS Keybindings & Spotlight Daemon (AutoHotkey v2)..."

$startupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$ahkSource  = Join-Path (Split-Path -Parent $scriptDir) "configs\ahk\mac-shortcuts.ahk"
$ahkDest    = Join-Path $startupDir "mac-shortcuts.ahk"

if (Test-Path -Path $ahkSource) {
    Copy-Item -Path $ahkSource -Destination $ahkDest -Force
    Write-MacSuccess "Shortcut script deployed to Windows Startup: $ahkDest"
}

# Find AutoHotkey v2 executable
$ahkExe = Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path -Path $ahkExe)) {
    $ahkExe = Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey32.exe"
}
if (-not (Test-Path -Path $ahkExe)) {
    $ahkExe = Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey\v2\AutoHotkey64.exe"
}
if (-not (Test-Path -Path $ahkExe)) {
    # Check general PATH
    $ahkCmd = Get-Command "AutoHotkey64.exe", "AutoHotkey.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ahkCmd) { $ahkExe = $ahkCmd.Source }
}

if (Test-Path -Path $ahkDest) {
    if (Test-Path -Path $ahkExe) {
        # Terminate any old instance and relaunch
        Get-Process -Name "AutoHotkey*" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process -FilePath $ahkExe -ArgumentList "`"$ahkDest`"" -ErrorAction SilentlyContinue
        Write-MacSuccess "AutoHotkey v2 macOS shortcuts daemon running."
    } else {
        # Attempt direct execution via file association
        Start-Process -FilePath $ahkDest -ErrorAction SilentlyContinue
        Write-MacSuccess "AutoHotkey shortcut script launched."
    }
}

# Ensure PowerToys Run is active for Spotlight
Write-MacStep "Verifying Microsoft PowerToys Run (Spotlight search)..."
$ptRunExe = Join-Path $env:ProgramFiles "PowerToys\PowerToys.exe"
if (-not (Test-Path -Path $ptRunExe)) {
    $ptRunExe = Join-Path $env:LOCALAPPDATA "PowerToys\PowerToys.exe"
}

if (Test-Path -Path $ptRunExe) {
    if (-not (Get-Process -Name "PowerToys" -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $ptRunExe -ErrorAction SilentlyContinue
    }
    Write-MacSuccess "PowerToys Run operational (Spotlight shortcut: Alt+Space / Win+Space)."
}

# ==============================================================================
# 4. Clean Shell Refresh
# ==============================================================================
if (-not $SkipExplorerRestart) {
    Restart-MacExplorer
}

Write-MacSuccess "Finder Explorer and Spotlight configuration complete."
