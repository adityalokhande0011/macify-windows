<div align="center">

#  macify-windows

**Autonomously transform Windows 11 into an authentic macOS Sonoma & Sequoia experience.**  
*Native PowerShell automation, official Winget packages, safe Registry enhancements, and lightweight open-source utilities.*

[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20(Build%2022000%2B)-0078D4?logo=windows11&logoColor=white)](https://www.microsoft.com/software-download/windows11)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Dependencies](https://img.shields.io/badge/Dependencies-Winget%20Native-blueviolet)](https://github.com/microsoft/winget-cli)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/adityalokhande0011/macify-windows/pulls)

[Quick Install](#-one-line-quick-install) • [Features](#-features) • [Keyboard Shortcuts](#-macos-keyboard-ergonomics) • [CLI Options](#-command-line-options) • [Uninstallation](#-uninstallation--rollback) • [Repository Structure](#-repository-structure)

</div>

---

## ⚡ One-Line Quick Install

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/adityalokhande0011/macify-windows/main/install.ps1 | iex
```

Prefer local cloning?
```powershell
git clone https://github.com/adityalokhande0011/macify-windows.git
cd macify-windows
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

---

## 🌟 Features

| Module | Feature | macOS Experience |
|---|---|---|
| **Dock** | Centered Acrylic Taskbar | Minimalist floating dock with TranslucentTB acrylic blur, centered icons, and clutter removed (no search box, Copilot, or task view icons). |
| **Top Menu Bar** | Rainmeter MacTopBar | Sleek 28px frosted acrylic top bar featuring the Apple menu (Start/Power commands), Finder tabs, Wi-Fi, Volume control, Battery, and formatted Date/Time. |
| **Quick Look** | Spacebar Instant Preview | Press `Spacebar` in Windows Explorer on images, PDFs, Markdown, source code, archives, or videos to trigger an instant interactive preview. |
| **Spotlight** | PowerToys Run + AHK v2 | Press `Alt + Space` or `Win + Space` for instant system search, calculations, program launching, and unit conversion. |
| **Ergonomics** | macOS Keybindings | Familiar Command key shortcuts (`Alt + Q` to quit, `Alt + W` to close tabs, `Alt + C/V/X/Z` for editing, `Alt + Shift + 3/4` for screenshots). |
| **Aesthetics** | WhiteSur Cursors & 4K Wallpapers | High-DPI macOS cursor scheme activated instantly via Win32 APIs, paired with authentic 4K Sonoma & Sequoia wallpapers. |
| **Typography** | Inter & JetBrains Mono | Modern macOS-like subpixel typography with Inter and JetBrains Mono fonts registered directly into the Windows font registry. |
| **Safety First** | Automated System Restore Point | Creates a Windows System Restore point and exports complete `.reg` backups prior to modifying any configuration. |

---

## ⌨️ macOS Keyboard Ergonomics

`macify-windows` deploys a lightweight, native AutoHotkey v2 daemon into your Windows Startup folder that maps standard macOS shortcuts to your existing keyboard:

| macOS Shortcut | Windows Key Combo | Action |
|---|---|---|
| **Cmd + Space** | `Alt + Space` or `Win + Space` | Open Spotlight Search (PowerToys Run) |
| **Spacebar** | `Spacebar` (in Explorer) | QuickLook File Preview |
| **Cmd + Q** | `Alt + Q` | Quit / Close Active Application |
| **Cmd + W** | `Alt + W` | Close Current Tab or Window |
| **Cmd + M** | `Alt + M` | Minimize Active Window |
| **Cmd + H** | `Alt + H` | Hide Active Window |
| **Cmd + C / V / X** | `Alt + C` / `Alt + V` / `Alt + X` | Copy, Paste, Cut |
| **Cmd + Z / Shift+Z** | `Alt + Z` / `Alt + Shift + Z` | Undo / Redo |
| **Cmd + A / S / F** | `Alt + A` / `Alt + S` / `Alt + F` | Select All, Save, Find |
| **Cmd + Left / Right** | `Alt + Left` / `Alt + Right` | Move cursor to Beginning / End of Line |
| **Cmd + Up / Down** | `Alt + Up` / `Alt + Down` | Jump to Top / Bottom of Document |
| **Option + Delete** | `Alt + Backspace` | Delete entire previous word |
| **Cmd + Shift + 3** | `Alt + Shift + 3` | Fullscreen screenshot saved to Pictures |
| **Cmd + Shift + 4** | `Alt + Shift + 4` | Interactive region snip tool (Snipping Tool) |

---

## ⚙️ Command-Line Options

`install.ps1` supports both an interactive visual menu and non-interactive switches for automated deployments:

```powershell
# Interactive mode (Prompts for Dark/Light theme & wallpaper)
.\install.ps1

# Force macOS Dark Mode & Sequoia Dark 4K wallpaper
.\install.ps1 -Dark

# Force macOS Light Mode & Sequoia Light 4K wallpaper
.\install.ps1 -Light

# Fully silent deployment with sensible defaults
.\install.ps1 -Silent

# Skip pre-flight restore point (useful for test VMs)
.\install.ps1 -SkipBackup

# Rollback and uninstall
.\install.ps1 -Uninstall
```

---

## 🔄 Uninstallation & Rollback

`macify-windows` was designed with complete reversibility in mind. You can roll back every registry modification, restore default cursors, remove autostart entries, and return Windows 11 to its pristine state at any time:

```powershell
# Run uninstaller interactively
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

# Run silent rollback
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -Silent

# Rollback and optionally purge installed winget utility packages
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -PurgePackages
```

### What Rollback Does:
1. Re-imports registry backups exported from `$env:USERPROFILE\.macify_backup\latest\`.
2. Restores standard Windows 11 taskbar icons (Search box, Task View, Widgets, Copilot).
3. Resets cursor scheme to Windows Default using `SystemParametersInfo(SPI_SETCURSORS)`.
4. Removes AutoHotkey daemon from Windows Startup.
5. Re-applies the original Windows wallpaper.
6. Restarts `explorer.exe` smoothly.

---

## 📁 Repository Structure

```
macify-windows/
├── install.ps1                     # Master entry-point installer (CLI flags + interactive menu)
├── uninstall.ps1                   # Complete rollback, registry restoration & app cleanup script
├── scripts/
│   ├── common.ps1                  # Admin elevation check, logging, Win32 P/Invoke, OS build check
│   ├── backup.ps1                  # Creates Windows System Restore Point & exports Registry backups (.reg)
│   ├── dependencies.ps1            # Installs core tools silently via winget
│   ├── assets.ps1                  # Downloads & installs macOS Cursors, Fonts, Wallpapers, and Sounds
│   ├── win11-shell.ps1             # Configures Centered Floating Dock, Top Menu Bar, and Dark/Light theme
│   └── win11-explorer.ps1          # Configures Finder-like File Explorer, QuickLook (Spacebar), and Spotlight
├── configs/
│   ├── translucenttb/
│   │   └── settings.json           # Acrylic/clear floating taskbar configuration for Windows 11
│   ├── rainmeter/
│   │   └── MacTopBar/
│   │       └── MacTopBar.ini       # Complete Rainmeter macOS Top Menu Bar skin (Apple logo, File/Edit, Clock)
│   ├── ahk/
│   │   └── mac-shortcuts.ahk       # AutoHotkey v2 script for macOS keybindings & Spotlight hotkey
│   └── cursors/
│       └── install-cursors.ps1     # Applies WhiteSur/macOS cursor scheme to HKCU:\Control Panel\Cursors
├── LICENSE                         # MIT License
└── README.md                       # Documentation, shortcuts guide, and quick installer
```

---

## 🛡️ Requirements

- **Operating System:** Windows 11 64-bit (Build 22000 or higher, 21H2/22H2/23H2/24H2)
- **PowerShell:** PowerShell 5.1 (built into Windows 11) or PowerShell 7+
- **Privileges:** Administrator access (script automatically prompts for elevation)
- **Package Manager:** `winget` (included standard with Windows 11 App Installer)

---

## 🤝 Contributing

Contributions, bug reports, and enhancements are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/NewMacFeature`)
3. Commit your Changes (`git commit -m 'Add new macOS Sequoia styling'`)
4. Push to the Branch (`git push origin feature/NewMacFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
