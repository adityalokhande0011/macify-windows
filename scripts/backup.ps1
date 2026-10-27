<#
.SYNOPSIS
    macify-windows: Pre-Flight System Restore Point and Registry Backup.
.DESCRIPTION
    Creates a Windows System Restore point and exports current user interface registry keys
    to $env:USERPROFILE\.macify_backup\latest\ before any modifications are executed.
#>

[CmdletBinding()]
param(
    [switch]$SkipRestorePoint
)

# Load common utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "common.ps1")

Write-MacHeader "STAGE 1: PRE-FLIGHT SYSTEM BACKUP"

# Ensure backup destination directories exist
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$archiveDir = Join-Path $env:USERPROFILE ".macify_backup\archive_$timestamp"
$latestDir  = $global:MacifyBackupDir

if (-not (Test-Path -Path $latestDir)) {
    New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
}
if (-not (Test-Path -Path $archiveDir)) {
    New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
}

# 1. System Restore Point
if (-not $SkipRestorePoint) {
    Write-MacStep "Creating Windows System Restore Point ('Pre-Macify-Windows-Backup')..."
    try {
        # Check if System Restore is enabled on OS drive
        $sysDrive = $env:SystemDrive
        $srStatus = Get-ComputerRestorePoint -ErrorAction SilentlyContinue

        # Attempt to create restore point
        Checkpoint-Computer -Description "Pre-Macify-Windows-Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-MacSuccess "System Restore point created successfully."
    } catch {
        Write-MacWarn "Could not create System Restore Point: $($_.Exception.Message)"
        Write-MacWarn "Note: System Restore may be disabled on this drive or rate-limited by Windows. Continuing with Registry backup..."
    }
} else {
    Write-MacLog "System Restore point creation skipped by parameter." "INFO"
}

# 2. Registry Keys to Export
$registryKeysToBackup = @(
    @{ Name = "ExplorerAdvanced"; Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" },
    @{ Name = "ThemesPersonalize"; Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" },
    @{ Name = "ControlPanelCursors"; Path = "HKCU\Control Panel\Cursors" },
    @{ Name = "SearchSettings"; Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" },
    @{ Name = "TaskbarStuckRects3"; Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" }
)

Write-MacStep "Exporting original Registry configurations..."

foreach ($item in $registryKeysToBackup) {
    $fileName = "$($item.Name).reg"
    $latestPath  = Join-Path $latestDir $fileName
    $archivePath = Join-Path $archiveDir $fileName

    try {
        # reg export command
        $exportCmd = "reg export `"$($item.Path)`" `"$latestPath`" /y"
        cmd.exe /c $exportCmd 2>&1 | Out-Null

        if (Test-Path -Path $latestPath) {
            Copy-Item -Path $latestPath -Destination $archivePath -Force
            Write-MacSuccess "Backed up $($item.Path) -> $fileName"
        } else {
            Write-MacWarn "Registry path $($item.Path) not found or empty."
        }
    } catch {
        Write-MacWarn "Failed to export $($item.Path): $($_.Exception.Message)"
    }
}

# 3. Capture Current Wallpaper and State Metadata
Write-MacStep "Capturing current desktop environment metadata..."

$currentWallpaper = ""
try {
    $currentWallpaper = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallPaper" -ErrorAction SilentlyContinue).WallPaper
} catch {}

$metaData = @{
    BackupDate       = (Get-Date).ToString("o")
    WindowsBuild     = [System.Environment]::OSVersion.Version.ToString()
    UserName         = $env:USERNAME
    MachineName      = $env:COMPUTERNAME
    OriginalWallpaper= $currentWallpaper
    KeysBackedUp     = $registryKeysToBackup.Name
}

$metaPathLatest  = Join-Path $latestDir "backup-metadata.json"
$metaPathArchive = Join-Path $archiveDir "backup-metadata.json"

$metaData | ConvertTo-Json -Depth 4 | Set-Content -Path $metaPathLatest -Encoding UTF8
Copy-Item -Path $metaPathLatest -Destination $metaPathArchive -Force

Write-MacSuccess "Registry and metadata backup saved to: $latestDir"
