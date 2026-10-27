<#
.SYNOPSIS
    macify-windows: Windows 11 Shell, Centered Dock & Top Menu Bar Configuration.
.DESCRIPTION
    Applies core Windows 11 desktop transformations:
    - Sets Dark / Light theme mode and acrylic transparency
    - Configures Centered Taskbar Dock & removes taskbar clutter (Search, Widgets, Copilot, TaskView)
    - Deploys TranslucentTB configuration for acrylic floating dock effect
    - Deploys Rainmeter macOS Top Menu Bar skin (MacTopBar.ini) and activates it
#>

[CmdletBinding()]
param(
    [ValidateSet("Dark", "Light")]
    [string]$Theme = "Dark",
    [switch]$EnableAutoHideTaskbar
)

# Load common utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "common.ps1")

Write-MacHeader "STAGE 4: WINDOWS 11 SHELL & FLOATING DOCK CONFIGURATION"

# ==============================================================================
# 1. System & App Theme (macOS Dark / Light)
# ==============================================================================
Write-MacStep "Applying Windows 11 Theme mode: macOS $Theme..."

$personalizeReg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$themeValue = if ($Theme -eq "Light") { 1 } else { 0 }

Set-MacRegistryValue -Path $personalizeReg -Name "AppsUseLightTheme" -Value $themeValue -PropertyType "DWord"
Set-MacRegistryValue -Path $personalizeReg -Name "SystemUsesLightTheme" -Value $themeValue -PropertyType "DWord"
Set-MacRegistryValue -Path $personalizeReg -Name "EnableTransparency" -Value 1 -PropertyType "DWord"

# Also set Accent Color palette in DWM if needed
$dwmReg = "HKCU:\Software\Microsoft\Windows\DWM"
Set-MacRegistryValue -Path $dwmReg -Name "ColorPrevalence" -Value 0 -PropertyType "DWord"

Write-MacSuccess "System theme set to macOS $Theme mode with acrylic transparency."

# ==============================================================================
# 2. Windows 11 Centered Floating Dock Styling
# ==============================================================================
Write-MacStep "Configuring Centered Floating Taskbar Dock..."

$explorerAdv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# TaskbarAl: 1 = Centered (macOS Dock style), 0 = Left-aligned
Set-MacRegistryValue -Path $explorerAdv -Name "TaskbarAl" -Value 1 -PropertyType "DWord"

# Remove Taskbar Clutter (Search, Task View, Widgets, Copilot)
Set-MacRegistryValue -Path $explorerAdv -Name "SearchboxTaskbarMode" -Value 0 -PropertyType "DWord"
Set-MacRegistryValue -Path $explorerAdv -Name "ShowTaskViewButton" -Value 0 -PropertyType "DWord"
Set-MacRegistryValue -Path $explorerAdv -Name "TaskbarDa" -Value 0 -PropertyType "DWord"         # Widgets / Dashboard
Set-MacRegistryValue -Path $explorerAdv -Name "ShowCopilotButton" -Value 0 -PropertyType "DWord" # Copilot

# Taskbar auto-hide (if enabled, leaves clean desktop for floating dock effect)
if ($EnableAutoHideTaskbar) {
    $stuckRects = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    try {
        $settings = (Get-ItemProperty -Path $stuckRects -Name "Settings" -ErrorAction Stop).Settings
        $settings[8] = 3 # 3 = Auto-hide enabled, 2 = Auto-hide disabled
        Set-ItemProperty -Path $stuckRects -Name "Settings" -Value $settings
        Write-MacSuccess "Taskbar auto-hide enabled."
    } catch {
        Write-MacWarn "Could not update StuckRects3 auto-hide setting: $($_.Exception.Message)"
    }
}

# ==============================================================================
# 3. TranslucentTB Configuration & Autostart
# ==============================================================================
Write-MacStep "Deploying TranslucentTB acrylic configuration..."

$ttbConfigDir = Join-Path $env:APPDATA "TranslucentTB"
$ttbSourceJson = Join-Path (Split-Path -Parent $scriptDir) "configs\translucenttb\settings.json"

if (-not (Test-Path -Path $ttbConfigDir)) {
    New-Item -ItemType Directory -Force -Path $ttbConfigDir | Out-Null
}

if (Test-Path -Path $ttbSourceJson) {
    Copy-Item -Path $ttbSourceJson -Destination (Join-Path $ttbConfigDir "settings.json") -Force
    Write-MacSuccess "TranslucentTB settings deployed to: $ttbConfigDir\settings.json"
}

# Ensure TranslucentTB launches at user login
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$ttbExe = "$env:LOCALAPPDATA\Programs\TranslucentTB\TranslucentTB.exe"
if (Test-Path -Path $ttbExe) {
    Set-MacRegistryValue -Path $runKey -Name "TranslucentTB" -Value "`"$ttbExe`"" -PropertyType "String"
    # Launch now if not running
    if (-not (Get-Process -Name "TranslucentTB" -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $ttbExe -ErrorAction SilentlyContinue
    }
} else {
    # Check Windows Store package installation
    $storeApp = Get-AppxPackage -Name "*TranslucentTB*" -ErrorAction SilentlyContinue
    if ($storeApp) {
        Write-MacSuccess "TranslucentTB (Store package) verified."
    }
}

# ==============================================================================
# 4. Rainmeter macOS Top Menu Bar (MacTopBar)
# ==============================================================================
Write-MacStep "Deploying Rainmeter macOS Top Menu Bar skin..."

$rainmeterSkinsDir = Join-Path $env:USERPROFILE "Documents\Rainmeter\Skins\Macify\MacTopBar"
$rainmeterIniDir   = Join-Path $env:APPDATA "Rainmeter"
$rainmeterIniPath  = Join-Path $rainmeterIniDir "Rainmeter.ini"
$topBarSourceIni   = Join-Path (Split-Path -Parent $scriptDir) "configs\rainmeter\MacTopBar\MacTopBar.ini"

if (-not (Test-Path -Path $rainmeterSkinsDir)) {
    New-Item -ItemType Directory -Force -Path $rainmeterSkinsDir | Out-Null
}

if (Test-Path -Path $topBarSourceIni) {
    Copy-Item -Path $topBarSourceIni -Destination (Join-Path $rainmeterSkinsDir "MacTopBar.ini") -Force
    Write-MacSuccess "MacTopBar skin deployed to: $rainmeterSkinsDir\MacTopBar.ini"
}

# Configure Rainmeter.ini to automatically load Macify\MacTopBar
if (-not (Test-Path -Path $rainmeterIniDir)) {
    New-Item -ItemType Directory -Force -Path $rainmeterIniDir | Out-Null
}

$rainmeterConfigBlock = @"

[Macify\MacTopBar]
Active=1
WindowX=0
WindowY=0
AlphaValue=255
FadeDuration=250
ClickThrough=0
KeepOnScreen=1
AutoSelectScreen=0
StayOnTop=2
LoadOrder=0
"@

if (Test-Path -Path $rainmeterIniPath) {
    $currentIni = Get-Content -Path $rainmeterIniPath -Raw -ErrorAction SilentlyContinue
    if ($currentIni -notmatch "\[Macify\\MacTopBar\]") {
        Add-Content -Path $rainmeterIniPath -Value $rainmeterConfigBlock -Encoding UTF8
    }
} else {
    $baseIni = @"
[Rainmeter]
Logging=0
SkinPath=$env:USERPROFILE\Documents\Rainmeter\Skins\
$rainmeterConfigBlock
"@
    Set-Content -Path $rainmeterIniPath -Value $baseIni -Encoding UTF8
}

# Ensure Rainmeter runs on startup
$rainmeterExe = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
if (-not (Test-Path -Path $rainmeterExe)) {
    $rainmeterExe = "$env:ProgramFiles(x86)\Rainmeter\Rainmeter.exe"
}

if (Test-Path -Path $rainmeterExe) {
    Set-MacRegistryValue -Path $runKey -Name "Rainmeter" -Value "`"$rainmeterExe`"" -PropertyType "String"
    
    # Reload skin if running, or launch Rainmeter
    if (Get-Process -Name "Rainmeter" -ErrorAction SilentlyContinue) {
        & $rainmeterExe "!RefreshApp"
        & $rainmeterExe "!ActivateConfig" "Macify\MacTopBar" "MacTopBar.ini"
    } else {
        Start-Process -FilePath $rainmeterExe -ErrorAction SilentlyContinue
    }
    Write-MacSuccess "Rainmeter macOS Top Menu Bar activated."
} else {
    Write-MacWarn "Rainmeter executable path not located yet; skin is primed for when Rainmeter launches."
}

Write-MacSuccess "Shell and Centered Dock configuration complete."
