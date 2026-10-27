<#
.SYNOPSIS
    macify-windows: Complete Rollback, Registry Restoration & App Cleanup.
.DESCRIPTION
    Reverts all Windows 11 changes made by macify-windows:
    - Imports original pre-flight .reg registry backups
    - Restores Windows default Taskbar, Explorer and Cursor settings
    - Removes AutoHotkey startup scripts and registry Run entries
    - Terminates running helper daemons (TranslucentTB, Rainmeter, AutoHotkey)
    - Restores original Windows wallpaper and restarts explorer.exe cleanly
#>

[CmdletBinding()]
param(
    [switch]$PurgePackages,
    [switch]$Silent,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
macify-windows Uninstaller
Usage: .\uninstall.ps1 [OPTIONS]

Options:
  -PurgePackages      Optionally uninstalls packages installed via winget (QuickLook, TranslucentTB, etc.)
  -Silent             Runs silently without interactive confirmation prompts
  -Help               Displays this help dialog
"@
    exit 0
}

# Load common utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "scripts\common.ps1")

# Ensure Admin privileges
Assert-Admin -ScriptArgs $args

Clear-Host
Write-Host @"
================================================================================
   __  __            _  __         __        ___           _                     
  |  \/  | __ _  ___(_)/ _|_   _   \ \      / (_)_ __   __| | _____      _____   
  | |\/| |/ _` |/ __| | |_| | | |___\ \ /\ / /| | '_ \ / _` |/ _ \ \ /\ / / __|  
  | |  | | (_| | (__| |  _| |_| |_____\ V  V / | | | | | (_| | (_) \ V  V /\__ \  
  |_|  |_|\__,_|\___|_|_|  \__, |      \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/ |___/  
                           |___/                                                  
                     SYSTEM ROLLBACK & RESTORATION
================================================================================
"@ -ForegroundColor Yellow

if (-not $Silent) {
    Write-Host "This will restore your Windows 11 desktop, explorer, taskbar, and registry" -ForegroundColor White
    Write-Host "settings to their pre-installation state." -ForegroundColor White
    $confirm = Read-Host "Proceed with complete uninstallation? (Y/N) [Default: Y]"
    if ($confirm -and $confirm -notmatch "^[Yy]$") {
        Write-MacWarn "Uninstallation canceled by user."
        exit 0
    }
}

# ==============================================================================
# 1. Terminate Customization Daemons
# ==============================================================================
Write-MacStep "Terminating active macOS customization daemons..."

$daemons = @("TranslucentTB", "Rainmeter", "AutoHotkey64", "AutoHotkey32", "AutoHotkey")
foreach ($proc in $daemons) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-MacLog "Stopped process: $proc" "INFO"
}

# ==============================================================================
# 2. Remove Startup Hooks & Autostart Registry Entries
# ==============================================================================
Write-MacStep "Removing startup links and autostart registry entries..."

$startupAhk = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\mac-shortcuts.ahk"
if (Test-Path -Path $startupAhk) {
    Remove-Item -Path $startupAhk -Force -ErrorAction SilentlyContinue
    Write-MacSuccess "Removed Startup shortcut: mac-shortcuts.ahk"
}

$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$runEntries = @("TranslucentTB", "Rainmeter", "QuickLook")
foreach ($entry in $runEntries) {
    try {
        Remove-ItemProperty -Path $runKey -Name $entry -ErrorAction SilentlyContinue | Out-Null
        Write-MacLog "Removed Run entry: $entry" "INFO"
    } catch {}
}

# ==============================================================================
# 3. Restore Registry from Pre-Flight Backups
# ==============================================================================
Write-MacStep "Restoring original Registry keys from backup..."

$backupDir = $global:MacifyBackupDir
if (Test-Path -Path $backupDir) {
    $regFiles = Get-ChildItem -Path $backupDir -Filter "*.reg"
    if ($regFiles.Count -gt 0) {
        foreach ($file in $regFiles) {
            Write-MacLog "Importing backup: $($file.Name)..." "INFO"
            cmd.exe /c "reg import `"$($file.FullName)`"" 2>&1 | Out-Null
        }
        Write-MacSuccess "Registry keys restored from $backupDir."
    } else {
        Write-MacWarn "No .reg files located in $backupDir. Applying standard Windows defaults..."
    }
} else {
    Write-MacWarn "Backup directory not found. Reverting to standard Windows 11 defaults..."
}

# Explicitly ensure clean default values
$advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-MacRegistryValue -Path $advKey -Name "SearchboxTaskbarMode" -Value 1 -PropertyType "DWord" # Show search box/icon
Set-MacRegistryValue -Path $advKey -Name "ShowTaskViewButton" -Value 1 -PropertyType "DWord"   # Show Task View
Set-MacRegistryValue -Path $advKey -Name "TaskbarDa" -Value 1 -PropertyType "DWord"            # Show Widgets
Set-MacRegistryValue -Path $advKey -Name "ShowCopilotButton" -Value 1 -PropertyType "DWord"    # Show Copilot
Set-MacRegistryValue -Path $advKey -Name "UseCompactMode" -Value 0 -PropertyType "DWord"       # Standard spacing

# ==============================================================================
# 4. Restore Default Windows Cursors
# ==============================================================================
Write-MacStep "Restoring default Windows Cursors..."

$curKey = "HKCU:\Control Panel\Cursors"
Set-ItemProperty -Path $curKey -Name "(Default)" -Value "Windows Default" -Force
Set-ItemProperty -Path $curKey -Name "Scheme Source" -Value 0 -Type DWord -Force

$cursorRoles = @("Arrow", "Help", "AppStarting", "Wait", "Crosshair", "IBeam", "NWPen", "No", 
                 "SizeNS", "SizeWE", "SizeNWSE", "SizeNESW", "SizeAll", "UpArrow", "Hand", "Pin", "Person")
foreach ($role in $cursorRoles) {
    Set-ItemProperty -Path $curKey -Name $role -Value "" -Force
}

try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class CursorReset {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(int uAction, int uParam, IntPtr lpvParam, int fuWinIni);
    }
"@ -ErrorAction SilentlyContinue
    [CursorReset]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0x01 -bor 0x02) | Out-Null
    Write-MacSuccess "Default Windows cursors restored."
} catch {}

# ==============================================================================
# 5. Restore Original Wallpaper
# ==============================================================================
Write-MacStep "Restoring original desktop wallpaper..."

$metaFile = Join-Path $backupDir "backup-metadata.json"
$restoredWall = $false
if (Test-Path -Path $metaFile) {
    try {
        $meta = Get-Content -Path $metaFile -Raw | ConvertFrom-Json
        if ($meta.OriginalWallpaper -and (Test-Path -Path $meta.OriginalWallpaper)) {
            [Win32Native]::SystemParametersInfo(
                [Win32Native]::SPI_SETDESKWALLPAPER,
                0,
                $meta.OriginalWallpaper,
                [Win32Native]::SPIF_UPDATEINIFILE -bor [Win32Native]::SPIF_SENDCHANGE
            ) | Out-Null
            Write-MacSuccess "Restored wallpaper to: $($meta.OriginalWallpaper)"
            $restoredWall = $true
        }
    } catch {}
}

if (-not $restoredWall) {
    $defaultWinWall = Join-Path $env:windir "Web\Wallpaper\Windows\img0.jpg"
    if (Test-Path -Path $defaultWinWall) {
        [Win32Native]::SystemParametersInfo(
            [Win32Native]::SPI_SETDESKWALLPAPER,
            0,
            $defaultWinWall,
            [Win32Native]::SPIF_UPDATEINIFILE -bor [Win32Native]::SPIF_SENDCHANGE
        ) | Out-Null
        Write-MacSuccess "Restored standard Windows 11 Bloom wallpaper."
    }
}

# ==============================================================================
# 6. Optional: Purge Winget Packages
# ==============================================================================
if ($PurgePackages) {
    Write-MacStep "Purging open-source customization packages via winget..."
    $packagesToPurge = @(
        "CharlesMilette.TranslucentTB",
        "Rainmeter.Rainmeter",
        "AutoHotkey.AutoHotkey",
        "QL-Win.QuickLook"
    )

    foreach ($pkg in $packagesToPurge) {
        Write-MacLog "Uninstalling $pkg..." "INFO"
        Start-Process -FilePath "winget.exe" -ArgumentList @("uninstall", "--exact", "--id", $pkg, "--silent") -NoNewWindow -Wait -ErrorAction SilentlyContinue
    }
    Write-MacSuccess "Selected packages purged."
}

# ==============================================================================
# 7. Restart Explorer & Finalize
# ==============================================================================
Restart-MacExplorer
Update-WindowsEnvironment

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "   macify-windows: Rollback Complete!" -ForegroundColor Green
Write-Host "   Your Windows 11 system has been restored to its standard state." -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
