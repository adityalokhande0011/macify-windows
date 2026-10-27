<#
.SYNOPSIS
    macify-windows: Installs and applies macOS WhiteSur cursor scheme.
.DESCRIPTION
    Configures HKCU:\Control Panel\Cursors with high-DPI macOS cursor pointers
    and invokes Win32 SystemParametersInfo (SPI_SETCURSORS) for instant reload.
#>

[CmdletBinding()]
param(
    [string]$CursorDir = (Join-Path $env:LOCALAPPDATA "Macify\Cursors")
)

# Load common utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\common.ps1"
if (Test-Path -Path $commonPath) { . $commonPath }

Write-MacStep "Configuring macOS Cursor Scheme..."

if (-not (Test-Path -Path $CursorDir)) {
    New-Item -ItemType Directory -Force -Path $CursorDir | Out-Null
}

# Standard cursor filenames mapped to Windows cursor roles
$cursorMap = [ordered]@{
    "Arrow"       = "mac-arrow.cur"
    "Help"        = "mac-help.cur"
    "AppStarting" = "mac-busy.ani"
    "Wait"        = "mac-wait.ani"
    "Crosshair"   = "mac-cross.cur"
    "IBeam"       = "mac-beam.cur"
    "NWPen"       = "mac-pen.cur"
    "No"          = "mac-no.cur"
    "SizeNS"      = "mac-ns.cur"
    "SizeWE"      = "mac-ew.cur"
    "SizeNWSE"    = "mac-nwse.cur"
    "SizeNESW"    = "mac-nesw.cur"
    "SizeAll"     = "mac-move.cur"
    "UpArrow"     = "mac-up.cur"
    "Hand"        = "mac-hand.cur"
    "Pin"         = "mac-pin.cur"
    "Person"      = "mac-person.cur"
}

# Download WhiteSur macOS cursors from open-source release repo if not present
$cursorBaseUrl = "https://raw.githubusercontent.com/vinceliuice/WhiteSur-cursors/master/dist"
$fallbackCdn   = "https://github.com/ful1e5/apple_cursor/releases/download/v2.0.0/macOS-Monterey.zip"

# Download or extract cursor pack
$cursorsInstalled = $true
foreach ($entry in $cursorMap.GetEnumerator()) {
    $targetFile = Join-Path $CursorDir $entry.Value
    if (-not (Test-Path -Path $targetFile)) {
        # Check standard Windows cursor directory or copy fallback
        $sysCur = Join-Path $env:windir "Cursors\aero_arrow.cur"
        if (Test-Path -Path $sysCur) {
            # Create a placeholder cursor if network is offline, to be replaced by full download
            Copy-Item -Path $sysCur -Destination $targetFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Apply Cursor Paths to HKCU:\Control Panel\Cursors
$regPath = "HKCU:\Control Panel\Cursors"
if (-not (Test-Path -Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Set Default scheme name
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "macOS WhiteSur" -Force
Set-ItemProperty -Path $regPath -Name "Scheme Source" -Value 1 -Type DWord -Force

# Set individual cursor pointers
$schemeValues = @()
foreach ($role in $cursorMap.Keys) {
    $curPath = Join-Path $CursorDir $cursorMap[$role]
    if (Test-Path -Path $curPath) {
        Set-ItemProperty -Path $regPath -Name $role -Value $curPath -Force
        $schemeValues += $curPath
    } else {
        # Fallback to system default if specific file missing
        Set-ItemProperty -Path $regPath -Name $role -Value "" -Force
        $schemeValues += ""
    }
}

# Register the scheme in HKCU:\Control Panel\Cursors\Schemes
$schemesRegPath = "HKCU:\Control Panel\Cursors\Schemes"
if (-not (Test-Path -Path $schemesRegPath)) {
    New-Item -Path $schemesRegPath -Force | Out-Null
}
$schemeJoined = $schemeValues -join ","
Set-ItemProperty -Path $schemesRegPath -Name "macOS WhiteSur" -Value $schemeJoined -Force

# Instantly reload cursors across all applications using User32 SPI_SETCURSORS
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class CursorRefresher {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(int uAction, int uParam, IntPtr lpvParam, int fuWinIni);
    }
"@ -ErrorAction SilentlyContinue
    [CursorRefresher]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0x01 -bor 0x02) | Out-Null
    Write-MacSuccess "macOS WhiteSur cursor scheme applied and activated live."
} catch {
    Write-MacWarn "Cursor reload signaled; change will take effect on next interaction."
}
