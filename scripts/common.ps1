<#
.SYNOPSIS
    macify-windows: Core helper functions, logging, admin elevation, and Win32 P/Invoke utilities.
.DESCRIPTION
    Provides shared functions across all installer and uninstaller scripts:
    - Administrator privilege check and self-elevation
    - Windows 11 Build 22000+ verification
    - High-fidelity ANSI console logging
    - Win32 User32 P/Invoke interop for instant UI updates (SystemParametersInfo, SendMessageTimeout)
    - Safe registry creation and process management
#>

# Ensure strict mode and stop on unhandled fatal errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Define global project constants
$global:MacifyName        = "macify-windows"
$global:MacifyVersion     = "1.0.0"
$global:MacifyBackupDir   = Join-Path $env:USERPROFILE ".macify_backup\latest"
$global:MacifyAppDataDir  = Join-Path $env:LOCALAPPDATA "Macify"
$global:MacifyLogDir      = Join-Path $global:MacifyAppDataDir "logs"
$global:MacifyLogFile     = Join-Path $global:MacifyLogDir "macify-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure Macify AppData directories exist
if (-not (Test-Path -Path $global:MacifyLogDir)) {
    New-Item -ItemType Directory -Force -Path $global:MacifyLogDir | Out-Null
}

# Win32 P/Invoke API definitions for dynamic Windows UI updates
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32Native {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(
        int uAction,
        int uParam,
        string lpvParam,
        int fuWinIni
    );

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        UIntPtr wParam,
        string lParam,
        uint fuFlags,
        uint uTimeout,
        out UIntPtr lpdwResult
    );

    public const int SPI_SETDESKWALLPAPER = 0x0014;
    public const int SPI_SETCURSORS       = 0x0057;
    public const int SPIF_UPDATEINIFILE   = 0x01;
    public const int SPIF_SENDCHANGE      = 0x02;

    public static readonly IntPtr HWND_BROADCAST = new IntPtr(0xffff);
    public const uint WM_SETTINGCHANGE = 0x001A;
    public const uint SMTO_ABORTIFHUNG = 0x0002;
}
"@ -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Writes structured, colorized messages to console and log file.
#>
function Write-MacLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "STEP")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logLine   = "[$timestamp] [$Level] $Message"

    # Append to permanent log file
    try {
        Add-Content -Path $global:MacifyLogFile -Value $logLine -ErrorAction SilentlyContinue
    } catch {}

    switch ($Level) {
        "INFO" {
            Write-Host "  [i] " -ForegroundColor Cyan -NoNewline
            Write-Host $Message -ForegroundColor Gray
        }
        "STEP" {
            Write-Host "`n==> " -ForegroundColor Magenta -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "SUCCESS" {
            Write-Host "  [+] " -ForegroundColor Green -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "WARN" {
            Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor Yellow
        }
        "ERROR" {
            Write-Host "  [-] " -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor Red
        }
    }
}

function Write-MacSuccess { param([string]$Message) Write-MacLog -Message $Message -Level "SUCCESS" }
function Write-MacWarn    { param([string]$Message) Write-MacLog -Message $Message -Level "WARN" }
function Write-MacError   { param([string]$Message) Write-MacLog -Message $Message -Level "ERROR" }
function Write-MacStep    { param([string]$Message) Write-MacLog -Message $Message -Level "STEP" }

function Write-MacHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor DarkCyan
}

<#
.SYNOPSIS
    Verifies current session has local Administrator elevation.
#>
function Test-IsAdmin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Self-elevates current script session to Administrator if not already elevated.
#>
function Assert-Admin {
    param([string[]]$ScriptArgs = @())

    if (-not (Test-IsAdmin)) {
        Write-MacWarn "Elevation required. Requesting Administrator privileges..."
        
        $myInvocationPath = $MyInvocation.PSCommandPath
        if (-not $myInvocationPath -and $script:MyInvocation.PSCommandPath) {
            $myInvocationPath = $script:MyInvocation.PSCommandPath
        }

        if (-not $myInvocationPath) {
            Write-MacError "Unable to determine caller script path for elevation. Please re-run PowerShell as Administrator."
            exit 1
        }

        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$myInvocationPath`"")
        if ($ScriptArgs -and $ScriptArgs.Count -gt 0) {
            $argList += $ScriptArgs
        }

        try {
            $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -PassThru
            $proc.WaitForExit()
            exit $proc.ExitCode
        } catch {
            Write-MacError "User declined elevation or elevation failed: $($_.Exception.Message)"
            exit 1
        }
    }
}

<#
.SYNOPSIS
    Checks whether the system is running Windows 11 (OS Build >= 22000).
#>
function Test-Windows11 {
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 22000) {
        Write-MacError "macify-windows requires Windows 11 (Build 22000 or newer)."
        Write-MacError "Detected Windows build: $build. Please upgrade to Windows 11 to use macify-windows."
        return $false
    }
    Write-MacSuccess "Windows 11 detected (Build $build)."
    return $true
}

<#
.SYNOPSIS
    Safely creates or updates a Windows Registry property, creating the key path if required.
#>
function Set-MacRegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        $Value,
        [ValidateSet("DWord", "String", "ExpandString", "Binary", "MultiString", "QWord")]
        [string]$PropertyType = "DWord"
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
}

<#
.SYNOPSIS
    Broadcasts WM_SETTINGCHANGE across all top-level windows to notify the shell of registry updates.
#>
function Update-WindowsEnvironment {
    try {
        [UIntPtr]$result = [UIntPtr]::Zero
        [Win32Native]::SendMessageTimeout(
            [Win32Native]::HWND_BROADCAST,
            [Win32Native]::WM_SETTINGCHANGE,
            [UIntPtr]::Zero,
            "Environment",
            [Win32Native]::SMTO_ABORTIFHUNG,
            2000,
            [ref]$result
        ) | Out-Null
    } catch {
        Write-MacWarn "Notification broadcast returned non-fatal error: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Restarts Windows File Explorer safely to apply Taskbar and Shell registry modifications.
#>
function Restart-MacExplorer {
    Write-MacStep "Refreshing Windows Shell (restarting explorer.exe)..."
    try {
        Get-Process -Name "explorer" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Milliseconds 1200
        if (-not (Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) {
            Start-Process "explorer.exe"
        }
        Write-MacSuccess "Windows Explorer restarted successfully."
    } catch {
        Write-MacWarn "Explorer restart triggered: $($_.Exception.Message)"
    }
}
