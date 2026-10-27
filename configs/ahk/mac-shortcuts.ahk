#Requires AutoHotkey v2.0+
#SingleInstance Force

/*
================================================================================
  macify-windows: macOS Keyboard Ergonomics & Spotlight Daemon for Windows 11
  Maps Command-key ergonomics to the Alt / Win keys natively in AutoHotkey v2.
================================================================================
*/

; Optimize responsiveness
A_MaxHotkeysPerInterval := 200
KeyHistory(0)
ListLines(False)

; Configure System Tray
A_IconTip := "macify-windows Shortcut Daemon"

; ==============================================================================
; 1. SPOTLIGHT SEARCH (PowerToys Run)
; ==============================================================================
; Map Alt+Space & Win+Space to trigger Spotlight (PowerToys Run: Alt+Space)
!Space::
{
    ; Trigger PowerToys Run default hotkey
    Send("!{Space}")
}

#Space::
{
    ; Trigger PowerToys Run when user presses Win+Space
    Send("!{Space}")
}

; ==============================================================================
; 2. APPLICATION & WINDOW MANAGEMENT (Cmd+Q, Cmd+W, Cmd+M, Cmd+H)
; ==============================================================================
; Alt+Q -> Quit Application (Cmd+Q)
!q::
{
    try {
        activeWin := WinGetID("A")
        WinClose("ahk_id " . activeWin)
    }
}

; Alt+W -> Close Tab / Document (Cmd+W)
!w::
{
    Send("^w")
}

; Alt+M -> Minimize Active Window (Cmd+M)
!m::
{
    try {
        activeWin := WinGetID("A")
        WinMinimize("ahk_id " . activeWin)
    }
}

; Alt+H -> Hide Active Window (Cmd+H)
!h::
{
    try {
        activeWin := WinGetID("A")
        WinHide("ahk_id " . activeWin)
    }
}

; ==============================================================================
; 3. CLIPBOARD & TEXT EDITING SHORTCUTS (Cmd+C, V, X, Z, A, S, F)
; ==============================================================================
!c::Send("^c")
!v::Send("^v")
!x::Send("^x")
!z::Send("^z")
!+z::Send("^y")
!a::Send("^a")
!s::Send("^s")
!f::Send("^f")
!t::Send("^t")
!n::Send("^n")
!r::Send("^r")
!l::Send("^l")

; ==============================================================================
; 4. TEXT NAVIGATION SHORTCUTS (macOS line & document boundaries)
; ==============================================================================
; Alt+Left / Alt+Right -> Beginning / End of line
!Left::Send("{Home}")
!Right::Send("{End}")
!+Left::Send("+{Home}")
!+Right::Send("+{End}")

; Alt+Up / Alt+Down -> Beginning / End of document
!Up::Send("^{Home}")
!Down::Send("^{End}")
!+Up::Send("^+{Home}")
!+Down::Send("^+{End}")

; Alt+Backspace -> Delete word backward (Option+Delete on Mac)
!Backspace::Send("^{Backspace}")

; ==============================================================================
; 5. SCREENSHOT SHORTCUTS (macOS Cmd+Shift+3, Cmd+Shift+4)
; ==============================================================================
; Alt+Shift+3 -> Fullscreen Screenshot to Pictures/Screenshots
!+3::Send("#{PrintScreen}")

; Alt+Shift+4 -> Interactive Selection Snipping Tool
!+4::Send("#+s")
