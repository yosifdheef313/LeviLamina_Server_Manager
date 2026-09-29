Unicode true
ManifestDPIAware true

####
## Please note: Template replacements don't work in this file. They are provided with default defines like
## mentioned underneath.
## If the keyword is not defined, "wails_tools.nsh" will populate them with the values from ProjectInfo.
## If they are defined here, "wails_tools.nsh" will not touch them. This allows to use this project.nsi manually
## from outside of Wails for debugging and development of the installer.
##
## For development first make a wails nsis build to populate the "wails_tools.nsh":
## > wails build --target windows/amd64 --nsis
## Then you can call makensis on this file with specifying the path to your binary:
## For a AMD64 only installer:
## > makensis -DARG_WAILS_AMD64_BINARY=..\..\bin\app.exe
####
!define INFO_PROJECTNAME    "LeviLaminaServerManager"
!define INFO_COMPANYNAME    "yosifdheef313"
!define INFO_PRODUCTNAME    "LeviLamina Server Manager"
!define INFO_PRODUCTVERSION "1.1.1"
!define INFO_COPYRIGHT      "Copyright 2026 yosifdheef313"
!define PRODUCT_EXECUTABLE  "LeviLaminaServerManager.exe"
!define UNINST_KEY_NAME     "LeviLaminaServerManager"
!define REQUEST_EXECUTION_LEVEL "admin"

!define WIN_W  675
!define WIN_H  475

!include "wails_tools.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "WinMessages.nsh"

VIProductVersion "${INFO_PRODUCTVERSION}.0"
VIFileVersion    "${INFO_PRODUCTVERSION}.0"
VIAddVersionKey "CompanyName"     "${INFO_COMPANYNAME}"
VIAddVersionKey "FileDescription" "${INFO_PRODUCTNAME} Installer"
VIAddVersionKey "ProductVersion"  "${INFO_PRODUCTVERSION}"
VIAddVersionKey "FileVersion"     "${INFO_PRODUCTVERSION}"
VIAddVersionKey "LegalCopyright"  "${INFO_COPYRIGHT}"
VIAddVersionKey "ProductName"     "${INFO_PRODUCTNAME}"

Icon "..\icon.ico"
UninstallIcon "..\icon.ico"
Name "${INFO_PRODUCTNAME}"
BrandingText " "
OutFile "..\..\bin\${INFO_PROJECTNAME}-${ARCH}-installer.exe"
InstallDir "$PROGRAMFILES64\LeviLaminaServerManager"
ShowInstDetails nevershow
ShowUninstDetails nevershow
AutoCloseWindow false

# ─── Variables ────────────────────────────────────────────────────────────────

Var page.Dialog
Var page.BgBmp
Var page.BgRef
Var page.InstallBtn
Var page.InstallRef
Var page.CloseBtn
Var page.CloseRef
Var page.MinBtn
Var page.MinRef
Var page.LicenseCheck
Var page.CustomLink

Var opt.Dialog
Var opt.BgBmp
Var opt.BgRef
Var opt.ChkDesktop
Var opt.ChkStartMenu
Var opt.ChkStartup
Var opt.NextBtn
Var opt.NextRef
Var opt.CloseBtn
Var opt.CloseRef
Var opt.MinBtn
Var opt.MinRef

Var page.DirField
Var page.BrowseBtn
Var page.BrowseRef
Var dir.NextBtn
Var dir.NextRef

Var page.FinishBtn
Var page.FinishRef
Var page.LaunchCheck

Var inst.Dialog
Var inst.BgBmp
Var inst.BgRef
Var inst.ProgressBar
Var inst.Status
Var inst.NextBtn
Var inst.NextRef
Var inst.CloseBtn
Var inst.CloseRef
Var inst.MinBtn
Var inst.MinRef
Var inst.Step

Var doCustomInstall
Var licenseAccepted
Var launchAfterInstall
Var optDesktop
Var optStartMenu
Var optStartup

# Hover state trackers
Var hov.install
Var hov.close
Var hov.min
Var hov.optNext
Var hov.optClose
Var hov.optMin
Var hov.dirBrowse
Var hov.dirNext
Var hov.dirClose
Var hov.dirMin
Var hov.instNext
Var hov.instClose
Var hov.instMin
Var hov.finBtn
Var hov.finClose
Var hov.finMin

# Uninstaller
Var un.Dialog
Var un.CheckboxServers
Var un.CheckboxData
Var un.RemoveServers
Var un.RemoveData
Var un.CloseBtn
Var un.CloseRef
Var un.MinBtn
Var un.MinRef
Var un.UninstBtn
Var un.UninstRef
Var un.FinBtn
Var un.FinRef

Var un.InstDialog
Var un.InstProgressBar
Var un.InstStatus
Var un.InstStep
Var un.InstNextBtn
Var un.InstNextRef
Var un.InstCloseBtn
Var un.InstCloseRef
Var un.InstMinBtn
Var un.InstMinRef
Var hov.unInstNext
Var hov.unInstClose
Var hov.unInstMin
Var hov.unUninst
Var hov.unClose
Var hov.unMin
Var hov.unFinish
Var hov.unFinClose

# GDI font handles (created once, reused)
Var fnt.TitleBar    ; Segoe UI SemiBold 10pt
Var fnt.Title       ; Segoe UI Bold 18pt
Var fnt.Subtitle    ; Segoe UI 9pt
Var fnt.OptionHead  ; Segoe UI Bold 14pt
Var fnt.Link        ; Segoe UI 9pt

# ─── Pages ────────────────────────────────────────────────────────────────────

Page custom  pg.Welcome        pg.WelcomeLeave
Page custom  pg.Options        pg.OptionsLeave
Page custom  pg.Directory      pg.DirectoryLeave
Page custom  pg.Installing     pg.InstallingLeave
Page instfiles "" ""           pg.InstFilesShow
Page custom  pg.Finish         pg.FinishLeave

UninstPage custom  un.CleanOptionsPage  un.CleanOptionsPageLeave
UninstPage custom  un.UninstallingPage  un.UninstallingPageLeave
UninstPage instfiles "" "" un.InstFilesShow
UninstPage custom  un.FinishPage

# ─── Window helpers ───────────────────────────────────────────────────────────

!macro MakeCustomWindow
    System::Call 'user32::SetWindowLong(i $HWNDPARENT, i -16, i 0x90000000)'
    System::Call 'user32::SetWindowLong(i $HWNDPARENT, i -20, i 0x00000000)'
    System::Call 'user32::GetSystemMetrics(i 0) i.r1'
    System::Call 'user32::GetSystemMetrics(i 1) i.r2'
    IntOp $3 $1 - ${WIN_W}
    IntOp $3 $3 / 2
    IntOp $4 $2 - ${WIN_H}
    IntOp $4 $4 / 2
    System::Call 'user32::SetWindowPos(i $HWNDPARENT, i 0, i $3, i $4, i ${WIN_W}, i ${WIN_H}, i 0x0024)'
    ShowWindow $HWNDPARENT 0
    ShowWindow $HWNDPARENT 5
    System::Call 'dwmapi::DwmSetWindowAttribute(i $HWNDPARENT, i 33, *i 2, i 4)'
    System::Call 'dwmapi::DwmSetWindowAttribute(i $HWNDPARENT, i 20, *i 0, i 4)'
!macroend

!macro SetupPageCustom DIALOG_HWND
    System::Call 'user32::SetWindowLong(i $HWNDPARENT, i -16, i 0x90000000)'
    System::Call 'user32::SetWindowLong(i $HWNDPARENT, i -20, i 0x00000000)'
    System::Call 'user32::GetSystemMetrics(i 0) i.r1'
    System::Call 'user32::GetSystemMetrics(i 1) i.r2'
    IntOp $3 $1 - ${WIN_W}
    IntOp $3 $3 / 2
    IntOp $4 $2 - ${WIN_H}
    IntOp $4 $4 / 2
    System::Call 'user32::SetWindowPos(i $HWNDPARENT, i 0, i $3, i $4, i ${WIN_W}, i ${WIN_H}, i 0x0024)'
    System::Call 'user32::MoveWindow(i ${DIALOG_HWND}, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 1)'
    System::Call 'dwmapi::DwmSetWindowAttribute(i $HWNDPARENT, i 33, *i 2, i 4)'
    System::Call 'dwmapi::DwmSetWindowAttribute(i $HWNDPARENT, i 20, *i 0, i 4)'
    System::Call 'user32::FindWindowEx(i $HWNDPARENT, i 0, i 0, i 0) i.r1'
    ${While} $1 != 0
        ${If} $1 != ${DIALOG_HWND}
            System::Call 'user32::ShowWindow(i $1, i 0)'
            System::Call 'user32::SetWindowPos(i $1, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'
        ${EndIf}
        System::Call 'user32::FindWindowEx(i $HWNDPARENT, i $1, i 0, i 0) i.r1'
    ${EndWhile}
    SetCtlColors ${DIALOG_HWND} "0F172A" "FFFFFF"
!macroend

!macro AdvancePage
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 1
    EnableWindow $0 1
    SendMessage $HWNDPARENT ${WM_COMMAND} 1 0
!macroend

!macro BackPage
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 1
    EnableWindow $0 1
    SendMessage $HWNDPARENT ${WM_COMMAND} 3 0
!macroend

# Create a GDI font. Result goes into $R0.
# CreateFont(h, w, esc, orient, weight, italic, underline, strike, charset, outprec, clipprec, quality, pitchfamily, face)
!macro CreateFont HEIGHT WEIGHT FACE RESULT
    System::Call 'gdi32::CreateFont(i ${HEIGHT}, i 0, i 0, i 0, i ${WEIGHT}, i 0, i 0, i 0, i 0, i 0, i 0, i 5, i 0, t "${FACE}") i.s'
    Pop ${RESULT}
!macroend

# Apply a GDI font handle to a control HWND
!macro SetFont HWND FONT_HANDLE
    SendMessage ${HWND} 0x0030 ${FONT_HANDLE} 1
!macroend

# ─── .onInit ──────────────────────────────────────────────────────────────────

Function .onInit
    !insertmacro wails.checkArchitecture
    StrCpy $doCustomInstall "0"
    StrCpy $licenseAccepted "1"
    StrCpy $launchAfterInstall "1"
    StrCpy $optDesktop   "1"
    StrCpy $optStartMenu "1"
    StrCpy $optStartup   "0"

    nsExec::Exec 'cmd.exe /c taskkill /F /IM LeviLaminaServerManager.exe /T 2>nul'
    nsExec::Exec 'cmd.exe /c taskkill /F /IM levilamina-server-manager.exe /T 2>nul'

    InitPluginsDir
    File "/oname=$PLUGINSDIR\ui_bg.bmp"          "ui_bg.bmp"
    File "/oname=$PLUGINSDIR\ui_bg_options.bmp"  "ui_bg_options.bmp"
    File "/oname=$PLUGINSDIR\ui_bg_dir.bmp"      "ui_bg_dir.bmp"
    File "/oname=$PLUGINSDIR\ui_bg_install.bmp"  "ui_bg_install.bmp"
    File "/oname=$PLUGINSDIR\ui_bg_finish.bmp"   "ui_bg_finish.bmp"
    File "/oname=$PLUGINSDIR\ui_bg_uninst.bmp"   "ui_bg_uninst.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_install.bmp"   "ui_btn_install.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_install_h.bmp" "ui_btn_install_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_install_p.bmp" "ui_btn_install_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_next.bmp"   "ui_btn_next.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_next_h.bmp" "ui_btn_next_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_next_p.bmp" "ui_btn_next_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_finish.bmp"   "ui_btn_finish.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_finish_h.bmp" "ui_btn_finish_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_finish_p.bmp" "ui_btn_finish_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_browse.bmp"   "ui_btn_browse.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_browse_h.bmp" "ui_btn_browse_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_launch.bmp"   "ui_btn_launch.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_uninstall.bmp" "ui_btn_uninstall.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_close.bmp"   "ui_btn_close.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_close_h.bmp" "ui_btn_close_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_close_p.bmp" "ui_btn_close_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_min.bmp"   "ui_btn_min.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_min_h.bmp" "ui_btn_min_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_min_p.bmp" "ui_btn_min_p.bmp"
    File "/oname=$PLUGINSDIR\ui_logo.bmp" "ui_logo.bmp"

    # Create shared GDI fonts
    !insertmacro CreateFont -13 600 "Segoe UI" $fnt.TitleBar
    !insertmacro CreateFont -20 700 "Segoe UI" $fnt.Title
    !insertmacro CreateFont -12 400 "Segoe UI" $fnt.Subtitle
    !insertmacro CreateFont -15 700 "Segoe UI" $fnt.OptionHead
    !insertmacro CreateFont -12 400 "Segoe UI" $fnt.Link
FunctionEnd

Function .onGUIInit
    !insertmacro MakeCustomWindow
FunctionEnd

# ─── Shared handlers ──────────────────────────────────────────────────────────

Function pg.OnDragWindow
    System::Call 'user32::ReleaseCapture()'
    SendMessage $HWNDPARENT 0x00A1 2 0
FunctionEnd

Function pg.OnClose
    MessageBox MB_YESNO|MB_ICONQUESTION "Cancel the installation?" IDNO pg.OnClose_No
    ShowWindow $HWNDPARENT 0
    SendMessage $HWNDPARENT 0x0010 0 0 ; WM_CLOSE
    Quit
    System::Call 'kernel32::ExitProcess(i 0)'
    pg.OnClose_No:
FunctionEnd

Function pg.OnMinimize
    ShowWindow $HWNDPARENT 2
FunctionEnd

# ─── PAGE 1: Welcome ──────────────────────────────────────────────────────────

Function pg.WelcomeTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # InstallBtn
    ${If} $3 == $page.InstallBtn
        ${If} $hov.install != "1"
            StrCpy $hov.install "1"
            ${NSD_FreeImage} $page.InstallRef
            ${NSD_SetImage} $page.InstallBtn "$PLUGINSDIR\ui_btn_install_h.bmp" $page.InstallRef
        ${EndIf}
    ${Else}
        ${If} $hov.install != "0"
            StrCpy $hov.install "0"
            ${NSD_FreeImage} $page.InstallRef
            ${NSD_SetImage} $page.InstallBtn "$PLUGINSDIR\ui_btn_install.bmp" $page.InstallRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $page.CloseBtn
        ${If} $hov.close != "1"
            StrCpy $hov.close "1"
            ${NSD_FreeImage} $page.CloseRef
            ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $page.CloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.close != "0"
            StrCpy $hov.close "0"
            ${NSD_FreeImage} $page.CloseRef
            ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $page.CloseRef
        ${EndIf}
    ${EndIf}

    # MinBtn
    ${If} $3 == $page.MinBtn
        ${If} $hov.min != "1"
            StrCpy $hov.min "1"
            ${NSD_FreeImage} $page.MinRef
            ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min_h.bmp" $page.MinRef
        ${EndIf}
    ${Else}
        ${If} $hov.min != "0"
            StrCpy $hov.min "0"
            ${NSD_FreeImage} $page.MinRef
            ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $page.MinRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function pg.Welcome
    !insertmacro MakeCustomWindow
    nsDialogs::Create 1018
    Pop $page.Dialog
    ${If} $page.Dialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $page.Dialog

    # Background (entire Welcome page design with logo, glow, titles, dot grid)
    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $page.BgBmp
    ${NSD_SetImage} $page.BgBmp "$PLUGINSDIR\ui_bg.bmp" $page.BgRef
    System::Call 'user32::SetWindowPos(i $page.BgBmp, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $page.BgBmp pg.OnDragWindow

    # ── Quick Install button (270x40, centered: x=202, y=312) ──
    ${NSD_CreateBitmap} 202 312 270 40 ""
    Pop $page.InstallBtn
    ${NSD_SetImage} $page.InstallBtn "$PLUGINSDIR\ui_btn_install.bmp" $page.InstallRef
    System::Call 'user32::SetWindowPos(i $page.InstallBtn, i 0, i 202, i 312, i 270, i 40, i 0x14)'
    ${NSD_OnClick} $page.InstallBtn pg.OnQuickInstall

    # ── License checkbox (x=35, y=428, w=260, h=24) ──
    ${NSD_CreateCheckBox} 35 428 260 24 " I agree to the License Agreement"
    Pop $page.LicenseCheck
    SetCtlColors $page.LicenseCheck "334155" "F8FAFC"
    !insertmacro SetFont $page.LicenseCheck $fnt.Subtitle
    ${NSD_Check} $page.LicenseCheck
    System::Call 'user32::SetWindowPos(i $page.LicenseCheck, i 0, i 35, i 428, i 260, i 24, i 0x14)'

    # ── Custom Install link (x=505, y=428, w=140, h=24) ──
    ${NSD_CreateLabel} 505 428 140 24 "Custom Install  >"
    Pop $page.CustomLink
    SetCtlColors $page.CustomLink "059669" "F8FAFC"
    !insertmacro SetFont $page.CustomLink $fnt.Subtitle
    System::Call 'user32::SetWindowPos(i $page.CustomLink, i 0, i 505, i 428, i 140, i 24, i 0x14)'
    ${NSD_OnClick} $page.CustomLink pg.OnCustomInstall

    # ── Close button (32x32, top right: x=635, y=8) ──
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $page.CloseBtn
    ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $page.CloseRef
    System::Call 'user32::SetWindowPos(i $page.CloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $page.CloseBtn pg.OnClose

    # ── Minimize button (32x32, x=597, y=8) ──
    ${NSD_CreateBitmap} 597 8 32 32 ""
    Pop $page.MinBtn
    ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $page.MinRef
    System::Call 'user32::SetWindowPos(i $page.MinBtn, i 0, i 597, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $page.MinBtn pg.OnMinimize

    # Bring interactive controls to top
    System::Call 'user32::BringWindowToTop(i $page.CloseBtn)'
    System::Call 'user32::BringWindowToTop(i $page.MinBtn)'
    System::Call 'user32::BringWindowToTop(i $page.InstallBtn)'
    System::Call 'user32::BringWindowToTop(i $page.LicenseCheck)'
    System::Call 'user32::BringWindowToTop(i $page.CustomLink)'

    SendMessage $HWNDPARENT 0x0127 0x00010001 0

    # Hand cursor on interactive controls
    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $page.InstallBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $page.CloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $page.MinBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $page.CustomLink, i -12, i $5)'

    StrCpy $hov.install "0"
    StrCpy $hov.close "0"
    StrCpy $hov.min "0"

    ${NSD_CreateTimer} pg.WelcomeTimer 40

    nsDialogs::Show
    ${NSD_KillTimer} pg.WelcomeTimer
    ${NSD_FreeImage} $page.BgRef
    ${NSD_FreeImage} $page.InstallRef
    ${NSD_FreeImage} $page.CloseRef
    ${NSD_FreeImage} $page.MinRef
FunctionEnd

Function pg.OnQuickInstall
    ${NSD_GetState} $page.LicenseCheck $licenseAccepted
    ${If} $licenseAccepted != ${BST_CHECKED}
        MessageBox MB_OK|MB_ICONINFORMATION "Please read and accept the License Agreement to continue."
        Return
    ${EndIf}
    ${NSD_KillTimer} pg.WelcomeTimer
    ${NSD_FreeImage} $page.InstallRef
    ${NSD_SetImage} $page.InstallBtn "$PLUGINSDIR\ui_btn_install_p.bmp" $page.InstallRef
    Sleep 120
    StrCpy $doCustomInstall "0"
    !insertmacro AdvancePage
FunctionEnd

Function pg.OnCustomInstall
    ${NSD_GetState} $page.LicenseCheck $licenseAccepted
    ${If} $licenseAccepted != ${BST_CHECKED}
        MessageBox MB_OK|MB_ICONINFORMATION "Please read and accept the License Agreement to continue."
        Return
    ${EndIf}
    ${NSD_KillTimer} pg.WelcomeTimer
    StrCpy $doCustomInstall "1"
    !insertmacro AdvancePage
FunctionEnd

Function pg.WelcomeLeave
    ${NSD_KillTimer} pg.WelcomeTimer
FunctionEnd

# ─── PAGE 2: Installation Options ─────────────────────────────────────────────

Function pg.OptionsTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # NextBtn
    ${If} $3 == $opt.NextBtn
        ${If} $hov.optNext != "1"
            StrCpy $hov.optNext "1"
            ${NSD_FreeImage} $opt.NextRef
            ${NSD_SetImage} $opt.NextBtn "$PLUGINSDIR\ui_btn_next_h.bmp" $opt.NextRef
        ${EndIf}
    ${Else}
        ${If} $hov.optNext != "0"
            StrCpy $hov.optNext "0"
            ${NSD_FreeImage} $opt.NextRef
            ${NSD_SetImage} $opt.NextBtn "$PLUGINSDIR\ui_btn_next.bmp" $opt.NextRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $opt.CloseBtn
        ${If} $hov.optClose != "1"
            StrCpy $hov.optClose "1"
            ${NSD_FreeImage} $opt.CloseRef
            ${NSD_SetImage} $opt.CloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $opt.CloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.optClose != "0"
            StrCpy $hov.optClose "0"
            ${NSD_FreeImage} $opt.CloseRef
            ${NSD_SetImage} $opt.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $opt.CloseRef
        ${EndIf}
    ${EndIf}

    # MinBtn
    ${If} $3 == $opt.MinBtn
        ${If} $hov.optMin != "1"
            StrCpy $hov.optMin "1"
            ${NSD_FreeImage} $opt.MinRef
            ${NSD_SetImage} $opt.MinBtn "$PLUGINSDIR\ui_btn_min_h.bmp" $opt.MinRef
        ${EndIf}
    ${Else}
        ${If} $hov.optMin != "0"
            StrCpy $hov.optMin "0"
            ${NSD_FreeImage} $opt.MinRef
            ${NSD_SetImage} $opt.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $opt.MinRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function pg.Options
    ${If} $doCustomInstall == "0"
        Abort
    ${EndIf}

    !insertmacro MakeCustomWindow
    nsDialogs::Create 1018
    Pop $opt.Dialog
    ${If} $opt.Dialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $opt.Dialog

    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $opt.BgBmp
    ${NSD_SetImage} $opt.BgBmp "$PLUGINSDIR\ui_bg_options.bmp" $opt.BgRef
    System::Call 'user32::SetWindowPos(i $opt.BgBmp, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $opt.BgBmp pg.OnDragWindow

    # Desktop shortcut checkbox (inside card x=60, y=136)
    ${NSD_CreateCheckBox} 90 170 480 26 "  Create Desktop Shortcut"
    Pop $opt.ChkDesktop
    SetCtlColors $opt.ChkDesktop "1E293B" "F8FAFC"
    !insertmacro SetFont $opt.ChkDesktop $fnt.Subtitle
    ${If} $optDesktop == "1"
        ${NSD_Check} $opt.ChkDesktop
    ${EndIf}
    System::Call 'user32::SetWindowPos(i $opt.ChkDesktop, i 0, i 90, i 170, i 480, i 26, i 0x14)'

    # Start Menu checkbox
    ${NSD_CreateCheckBox} 90 225 480 26 "  Add to Start Menu"
    Pop $opt.ChkStartMenu
    SetCtlColors $opt.ChkStartMenu "1E293B" "F8FAFC"
    !insertmacro SetFont $opt.ChkStartMenu $fnt.Subtitle
    ${If} $optStartMenu == "1"
        ${NSD_Check} $opt.ChkStartMenu
    ${EndIf}
    System::Call 'user32::SetWindowPos(i $opt.ChkStartMenu, i 0, i 90, i 225, i 480, i 26, i 0x14)'

    # Launch on startup checkbox
    ${NSD_CreateCheckBox} 90 280 480 26 "  Launch on Windows startup"
    Pop $opt.ChkStartup
    SetCtlColors $opt.ChkStartup "1E293B" "F8FAFC"
    !insertmacro SetFont $opt.ChkStartup $fnt.Subtitle
    ${If} $optStartup == "1"
        ${NSD_Check} $opt.ChkStartup
    ${EndIf}
    System::Call 'user32::SetWindowPos(i $opt.ChkStartup, i 0, i 90, i 280, i 480, i 26, i 0x14)'

    # Back link
    ${NSD_CreateLabel} 45 422 70 24 "< Back"
    Pop $3
    SetCtlColors $3 "64748B" "F8FAFC"
    !insertmacro SetFont $3 $fnt.Subtitle
    System::Call 'user32::SetWindowPos(i $3, i 0, i 45, i 422, i 70, i 24, i 0x14)'
    ${NSD_OnClick} $3 pg.Options.Back

    # Next button (160x44 at 475, 412)
    ${NSD_CreateBitmap} 475 412 160 44 ""
    Pop $opt.NextBtn
    ${NSD_SetImage} $opt.NextBtn "$PLUGINSDIR\ui_btn_next.bmp" $opt.NextRef
    System::Call 'user32::SetWindowPos(i $opt.NextBtn, i 0, i 475, i 412, i 160, i 44, i 0x14)'
    ${NSD_OnClick} $opt.NextBtn pg.Options.Next

    # Close button (32x32 at 635, 8)
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $opt.CloseBtn
    ${NSD_SetImage} $opt.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $opt.CloseRef
    System::Call 'user32::SetWindowPos(i $opt.CloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $opt.CloseBtn pg.OnClose

    # Minimize button (32x32 at 597, 8)
    ${NSD_CreateBitmap} 597 8 32 32 ""
    Pop $opt.MinBtn
    ${NSD_SetImage} $opt.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $opt.MinRef
    System::Call 'user32::SetWindowPos(i $opt.MinBtn, i 0, i 597, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $opt.MinBtn pg.OnMinimize

    System::Call 'user32::BringWindowToTop(i $opt.CloseBtn)'
    System::Call 'user32::BringWindowToTop(i $opt.MinBtn)'
    System::Call 'user32::BringWindowToTop(i $opt.ChkDesktop)'
    System::Call 'user32::BringWindowToTop(i $opt.ChkStartMenu)'
    System::Call 'user32::BringWindowToTop(i $opt.ChkStartup)'
    System::Call 'user32::BringWindowToTop(i $opt.NextBtn)'
    System::Call 'user32::BringWindowToTop(i $3)'

    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $opt.NextBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $3, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $opt.CloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $opt.MinBtn, i -12, i $5)'

    StrCpy $hov.optNext "0"
    StrCpy $hov.optClose "0"
    StrCpy $hov.optMin "0"

    ${NSD_CreateTimer} pg.OptionsTimer 40

    nsDialogs::Show
    ${NSD_KillTimer} pg.OptionsTimer
    ${NSD_FreeImage} $opt.BgRef
    ${NSD_FreeImage} $opt.NextRef
    ${NSD_FreeImage} $opt.CloseRef
    ${NSD_FreeImage} $opt.MinRef
FunctionEnd

Function pg.Options.Next
    ${NSD_KillTimer} pg.OptionsTimer
    ${NSD_GetState} $opt.ChkDesktop   $optDesktop
    ${NSD_GetState} $opt.ChkStartMenu $optStartMenu
    ${NSD_GetState} $opt.ChkStartup   $optStartup
    ${NSD_FreeImage} $opt.NextRef
    ${NSD_SetImage} $opt.NextBtn "$PLUGINSDIR\ui_btn_next_p.bmp" $opt.NextRef
    Sleep 120
    !insertmacro AdvancePage
FunctionEnd

Function pg.Options.Back
    ${NSD_KillTimer} pg.OptionsTimer
    !insertmacro BackPage
FunctionEnd

Function pg.OptionsLeave
    ${NSD_KillTimer} pg.OptionsTimer
    ${NSD_GetState} $opt.ChkDesktop   $optDesktop
    ${NSD_GetState} $opt.ChkStartMenu $optStartMenu
    ${NSD_GetState} $opt.ChkStartup   $optStartup
FunctionEnd

# ─── PAGE 3: Custom Directory ─────────────────────────────────────────────────

Function pg.DirectoryTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # BrowseBtn
    ${If} $3 == $page.BrowseBtn
        ${If} $hov.dirBrowse != "1"
            StrCpy $hov.dirBrowse "1"
            ${NSD_FreeImage} $page.BrowseRef
            ${NSD_SetImage} $page.BrowseBtn "$PLUGINSDIR\ui_btn_browse_h.bmp" $page.BrowseRef
        ${EndIf}
    ${Else}
        ${If} $hov.dirBrowse != "0"
            StrCpy $hov.dirBrowse "0"
            ${NSD_FreeImage} $page.BrowseRef
            ${NSD_SetImage} $page.BrowseBtn "$PLUGINSDIR\ui_btn_browse.bmp" $page.BrowseRef
        ${EndIf}
    ${EndIf}

    # NextBtn
    ${If} $3 == $dir.NextBtn
        ${If} $hov.dirNext != "1"
            StrCpy $hov.dirNext "1"
            ${NSD_FreeImage} $dir.NextRef
            ${NSD_SetImage} $dir.NextBtn "$PLUGINSDIR\ui_btn_next_h.bmp" $dir.NextRef
        ${EndIf}
    ${Else}
        ${If} $hov.dirNext != "0"
            StrCpy $hov.dirNext "0"
            ${NSD_FreeImage} $dir.NextRef
            ${NSD_SetImage} $dir.NextBtn "$PLUGINSDIR\ui_btn_next.bmp" $dir.NextRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $page.CloseBtn
        ${If} $hov.dirClose != "1"
            StrCpy $hov.dirClose "1"
            ${NSD_FreeImage} $page.CloseRef
            ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $page.CloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.dirClose != "0"
            StrCpy $hov.dirClose "0"
            ${NSD_FreeImage} $page.CloseRef
            ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $page.CloseRef
        ${EndIf}
    ${EndIf}

    # MinBtn
    ${If} $3 == $page.MinBtn
        ${If} $hov.dirMin != "1"
            StrCpy $hov.dirMin "1"
            ${NSD_FreeImage} $page.MinRef
            ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min_h.bmp" $page.MinRef
        ${EndIf}
    ${Else}
        ${If} $hov.dirMin != "0"
            StrCpy $hov.dirMin "0"
            ${NSD_FreeImage} $page.MinRef
            ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $page.MinRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function pg.Directory
    ${If} $doCustomInstall == "0"
        Abort
    ${EndIf}

    !insertmacro MakeCustomWindow
    nsDialogs::Create 1018
    Pop $page.Dialog
    ${If} $page.Dialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $page.Dialog

    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $page.BgBmp
    ${NSD_SetImage} $page.BgBmp "$PLUGINSDIR\ui_bg_dir.bmp" $page.BgRef
    System::Call 'user32::SetWindowPos(i $page.BgBmp, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $page.BgBmp pg.OnDragWindow

    ${NSD_CreateText} 85 190 375 32 "$INSTDIR"
    Pop $page.DirField
    SetCtlColors $page.DirField "0F172A" "FFFFFF"
    System::Call 'user32::SetWindowPos(i $page.DirField, i 0, i 85, i 190, i 375, i 32, i 0x14)'

    ${NSD_CreateBitmap} 475 190 110 32 ""
    Pop $page.BrowseBtn
    ${NSD_SetImage} $page.BrowseBtn "$PLUGINSDIR\ui_btn_browse.bmp" $page.BrowseRef
    System::Call 'user32::SetWindowPos(i $page.BrowseBtn, i 0, i 475, i 190, i 110, i 32, i 0x14)'
    ${NSD_OnClick} $page.BrowseBtn pg.OnBrowse

    # Next button (160x44 at 475, 412)
    ${NSD_CreateBitmap} 475 412 160 44 ""
    Pop $dir.NextBtn
    ${NSD_SetImage} $dir.NextBtn "$PLUGINSDIR\ui_btn_next.bmp" $dir.NextRef
    System::Call 'user32::SetWindowPos(i $dir.NextBtn, i 0, i 475, i 412, i 160, i 44, i 0x14)'
    ${NSD_OnClick} $dir.NextBtn pg.OnDirInstall

    # Back link
    ${NSD_CreateLabel} 45 422 70 24 "< Back"
    Pop $1
    SetCtlColors $1 "64748B" "F8FAFC"
    !insertmacro SetFont $1 $fnt.Subtitle
    System::Call 'user32::SetWindowPos(i $1, i 0, i 45, i 422, i 70, i 24, i 0x14)'
    ${NSD_OnClick} $1 pg.OnDirBack

    # Close button (32x32 at 635, 8)
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $page.CloseBtn
    ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $page.CloseRef
    System::Call 'user32::SetWindowPos(i $page.CloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $page.CloseBtn pg.OnClose

    # Minimize button (32x32 at 597, 8)
    ${NSD_CreateBitmap} 597 8 32 32 ""
    Pop $page.MinBtn
    ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $page.MinRef
    System::Call 'user32::SetWindowPos(i $page.MinBtn, i 0, i 597, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $page.MinBtn pg.OnMinimize

    System::Call 'user32::BringWindowToTop(i $page.CloseBtn)'
    System::Call 'user32::BringWindowToTop(i $page.MinBtn)'
    System::Call 'user32::BringWindowToTop(i $page.DirField)'
    System::Call 'user32::BringWindowToTop(i $page.BrowseBtn)'
    System::Call 'user32::BringWindowToTop(i $dir.NextBtn)'
    System::Call 'user32::BringWindowToTop(i $1)'

    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $page.BrowseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $dir.NextBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $1, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $page.CloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $page.MinBtn, i -12, i $5)'

    StrCpy $hov.dirBrowse "0"
    StrCpy $hov.dirNext "0"
    StrCpy $hov.dirClose "0"
    StrCpy $hov.dirMin "0"

    ${NSD_CreateTimer} pg.DirectoryTimer 40

    nsDialogs::Show
    ${NSD_KillTimer} pg.DirectoryTimer
    ${NSD_FreeImage} $page.BgRef
    ${NSD_FreeImage} $page.BrowseRef
    ${NSD_FreeImage} $dir.NextRef
    ${NSD_FreeImage} $page.CloseRef
    ${NSD_FreeImage} $page.MinRef
FunctionEnd

Function pg.OnBrowse
    ${NSD_GetText} $page.DirField $0
    nsDialogs::SelectFolderDialog "Select Installation Folder" "$0"
    Pop $0
    ${If} $0 != error
        ${NSD_SetText} $page.DirField "$0"
    ${EndIf}
FunctionEnd

Function pg.OnDirInstall
    ${NSD_GetText} $page.DirField $INSTDIR
    StrCmp $INSTDIR "" 0 +3
        MessageBox MB_OK|MB_ICONINFORMATION "Please select an installation folder."
        Return
    ${NSD_KillTimer} pg.DirectoryTimer
    ${NSD_FreeImage} $dir.NextRef
    ${NSD_SetImage} $dir.NextBtn "$PLUGINSDIR\ui_btn_next_p.bmp" $dir.NextRef
    Sleep 120
    !insertmacro AdvancePage
FunctionEnd

Function pg.OnDirBack
    ${NSD_KillTimer} pg.DirectoryTimer
    StrCpy $doCustomInstall "0"
    !insertmacro BackPage
FunctionEnd

Function pg.DirectoryLeave
    ${NSD_KillTimer} pg.DirectoryTimer
    ${NSD_GetText} $page.DirField $INSTDIR
FunctionEnd

# ─── PAGE 4: Installing ──────────────────────────────────────────────────────

Function pg.InstallingProgressTimer
    IntOp $inst.Step $inst.Step + 2
    ${If} $inst.Step > 100
        StrCpy $inst.Step 100
    ${EndIf}

    SendMessage $inst.ProgressBar 0x0402 $inst.Step 0 ; PBM_SETPOS

    ${If} $inst.Step < 15
        ${NSD_SetText} $inst.Status "Initializing setup environment... ($inst.Step%)"
    ${ElseIf} $inst.Step < 35
        ${NSD_SetText} $inst.Status "Extracting LeviLamina Bedrock server core engine... ($inst.Step%)"
    ${ElseIf} $inst.Step < 60
        ${NSD_SetText} $inst.Status "Configuring Server Manager GUI & Web Console... ($inst.Step%)"
    ${ElseIf} $inst.Step < 85
        ${NSD_SetText} $inst.Status "Setting up Mod & Plugin Manager with automated updates... ($inst.Step%)"
    ${ElseIf} $inst.Step < 100
        ${NSD_SetText} $inst.Status "Registering system components and shortcuts... ($inst.Step%)"
    ${Else}
        ${NSD_KillTimer} pg.InstallingProgressTimer
        ${NSD_SetText} $inst.Status "Completed! Click Next to continue."
        ShowWindow $inst.NextBtn 1
        EnableWindow $inst.NextBtn 1
        System::Call 'user32::BringWindowToTop(i $inst.NextBtn)'
    ${EndIf}
FunctionEnd

Function pg.InstallingHoverTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # NextBtn
    ${If} $3 == $inst.NextBtn
        ${If} $hov.instNext != "1"
            StrCpy $hov.instNext "1"
            ${NSD_FreeImage} $inst.NextRef
            ${NSD_SetImage} $inst.NextBtn "$PLUGINSDIR\ui_btn_next_h.bmp" $inst.NextRef
        ${EndIf}
    ${Else}
        ${If} $hov.instNext != "0"
            StrCpy $hov.instNext "0"
            ${NSD_FreeImage} $inst.NextRef
            ${NSD_SetImage} $inst.NextBtn "$PLUGINSDIR\ui_btn_next.bmp" $inst.NextRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $inst.CloseBtn
        ${If} $hov.instClose != "1"
            StrCpy $hov.instClose "1"
            ${NSD_FreeImage} $inst.CloseRef
            ${NSD_SetImage} $inst.CloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $inst.CloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.instClose != "0"
            StrCpy $hov.instClose "0"
            ${NSD_FreeImage} $inst.CloseRef
            ${NSD_SetImage} $inst.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $inst.CloseRef
        ${EndIf}
    ${EndIf}

    # MinBtn
    ${If} $3 == $inst.MinBtn
        ${If} $hov.instMin != "1"
            StrCpy $hov.instMin "1"
            ${NSD_FreeImage} $inst.MinRef
            ${NSD_SetImage} $inst.MinBtn "$PLUGINSDIR\ui_btn_min_h.bmp" $inst.MinRef
        ${EndIf}
    ${Else}
        ${If} $hov.instMin != "0"
            StrCpy $hov.instMin "0"
            ${NSD_FreeImage} $inst.MinRef
            ${NSD_SetImage} $inst.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $inst.MinRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function pg.Installing
    !insertmacro MakeCustomWindow
    nsDialogs::Create 1018
    Pop $inst.Dialog
    ${If} $inst.Dialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $inst.Dialog

    # Background bitmap (675x475)
    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $inst.BgBmp
    ${NSD_SetImage} $inst.BgBmp "$PLUGINSDIR\ui_bg_install.bmp" $inst.BgRef
    System::Call 'user32::SetWindowPos(i $inst.BgBmp, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $inst.BgBmp pg.OnDragWindow

    # Progress bar (75, 234, 525, 16)
    System::Call 'user32::CreateWindowEx(i 0, t "msctls_progress32", t "", i 0x50000000, i 75, i 234, i 525, i 16, i $inst.Dialog, i 0, i 0, i 0) i.r0'
    StrCpy $inst.ProgressBar $0
    SendMessage $inst.ProgressBar 0x0401 0 0x00640000 ; PBM_SETRANGE 0..100
    SendMessage $inst.ProgressBar 0x0402 0 0          ; PBM_SETPOS 0
    SendMessage $inst.ProgressBar 0x0409 0 0x0081B910 ; PBM_SETBARCOLOR = emerald #10B981
    SendMessage $inst.ProgressBar 0x2001 0 0x00F0E8E2 ; CCM_SETBKCOLOR = #E2E8F0
    System::Call 'user32::BringWindowToTop(i $inst.ProgressBar)'

    # Status Label (75, 258, 525, 20)
    ${NSD_CreateLabel} 75 258 525 20 "Initializing setup environment..."
    Pop $inst.Status
    SetCtlColors $inst.Status "059669" "FFFFFF"
    !insertmacro SetFont $inst.Status $fnt.Subtitle
    System::Call 'user32::BringWindowToTop(i $inst.Status)'

    # Next button (160x44 at 475, 412) - initially HIDDEN
    ${NSD_CreateBitmap} 475 412 160 44 ""
    Pop $inst.NextBtn
    ${NSD_SetImage} $inst.NextBtn "$PLUGINSDIR\ui_btn_next.bmp" $inst.NextRef
    System::Call 'user32::SetWindowPos(i $inst.NextBtn, i 0, i 475, i 412, i 160, i 44, i 0x14)'
    ShowWindow $inst.NextBtn 0
    EnableWindow $inst.NextBtn 0
    ${NSD_OnClick} $inst.NextBtn pg.OnInstallingNext

    # Close (X) button at 635, 8
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $inst.CloseBtn
    ${NSD_SetImage} $inst.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $inst.CloseRef
    System::Call 'user32::SetWindowPos(i $inst.CloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $inst.CloseBtn pg.OnClose

    # Min (-) button at 597, 8
    ${NSD_CreateBitmap} 597 8 32 32 ""
    Pop $inst.MinBtn
    ${NSD_SetImage} $inst.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $inst.MinRef
    System::Call 'user32::SetWindowPos(i $inst.MinBtn, i 0, i 597, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $inst.MinBtn pg.OnMinimize

    System::Call 'user32::BringWindowToTop(i $inst.CloseBtn)'
    System::Call 'user32::BringWindowToTop(i $inst.MinBtn)'

    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $inst.NextBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $inst.CloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $inst.MinBtn, i -12, i $5)'

    StrCpy $inst.Step 0
    StrCpy $hov.instNext "0"
    StrCpy $hov.instClose "0"
    StrCpy $hov.instMin "0"

    ${NSD_CreateTimer} pg.InstallingProgressTimer 50
    ${NSD_CreateTimer} pg.InstallingHoverTimer 40

    nsDialogs::Show

    ${NSD_KillTimer} pg.InstallingProgressTimer
    ${NSD_KillTimer} pg.InstallingHoverTimer
    ${NSD_FreeImage} $inst.BgRef
    ${NSD_FreeImage} $inst.NextRef
    ${NSD_FreeImage} $inst.CloseRef
    ${NSD_FreeImage} $inst.MinRef
FunctionEnd

Function pg.OnInstallingNext
    ${NSD_KillTimer} pg.InstallingProgressTimer
    ${NSD_KillTimer} pg.InstallingHoverTimer
    ${NSD_FreeImage} $inst.NextRef
    ${NSD_SetImage} $inst.NextBtn "$PLUGINSDIR\ui_btn_next_p.bmp" $inst.NextRef
    Sleep 120
    !insertmacro AdvancePage
FunctionEnd

Function pg.InstallingLeave
    ${NSD_KillTimer} pg.InstallingProgressTimer
    ${NSD_KillTimer} pg.InstallingHoverTimer
FunctionEnd

# ─── PAGE 5: Silent Extraction (instfiles) ────────────────────────────────────

Function pg.InstFilesShow
    ShowWindow $HWNDPARENT 0
FunctionEnd

# ─── PAGE 6: Finish ──────────────────────────────────────────────────────────

Function pg.FinishTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # FinishBtn
    ${If} $3 == $page.FinishBtn
        System::Call 'user32::GetAsyncKeyState(i 1) i.r4'
        IntOp $4 $4 & 0x8000
        ${If} $4 != 0
            Call pg.OnFinish
            Return
        ${EndIf}
        ${If} $hov.finBtn != "1"
            StrCpy $hov.finBtn "1"
            ${NSD_FreeImage} $page.FinishRef
            ${NSD_SetImage} $page.FinishBtn "$PLUGINSDIR\ui_btn_finish_h.bmp" $page.FinishRef
        ${EndIf}
    ${Else}
        ${If} $hov.finBtn != "0"
            StrCpy $hov.finBtn "0"
            ${NSD_FreeImage} $page.FinishRef
            ${NSD_SetImage} $page.FinishBtn "$PLUGINSDIR\ui_btn_finish.bmp" $page.FinishRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $page.CloseBtn
        ${If} $hov.finClose != "1"
            StrCpy $hov.finClose "1"
            ${NSD_FreeImage} $page.CloseRef
            ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $page.CloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.finClose != "0"
            StrCpy $hov.finClose "0"
            ${NSD_FreeImage} $page.CloseRef
            ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $page.CloseRef
        ${EndIf}
    ${EndIf}

    # MinBtn
    ${If} $3 == $page.MinBtn
        ${If} $hov.finMin != "1"
            StrCpy $hov.finMin "1"
            ${NSD_FreeImage} $page.MinRef
            ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min_h.bmp" $page.MinRef
        ${EndIf}
    ${Else}
        ${If} $hov.finMin != "0"
            StrCpy $hov.finMin "0"
            ${NSD_FreeImage} $page.MinRef
            ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $page.MinRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function pg.Finish
    !insertmacro MakeCustomWindow
    nsDialogs::Create 1018
    Pop $page.Dialog
    ${If} $page.Dialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $page.Dialog

    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $page.BgBmp
    ${NSD_SetImage} $page.BgBmp "$PLUGINSDIR\ui_bg_finish.bmp" $page.BgRef
    System::Call 'user32::SetWindowPos(i $page.BgBmp, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $page.BgBmp pg.OnDragWindow

    # Launch Checkbox centered at (197, 305, 280, 24)
    ${NSD_CreateCheckBox} 197 305 280 24 " Run LeviLamina Server Manager"
    Pop $page.LaunchCheck
    SetCtlColors $page.LaunchCheck "1E293B" "FFFFFF"
    !insertmacro SetFont $page.LaunchCheck $fnt.Subtitle
    ${NSD_Check} $page.LaunchCheck
    System::Call 'user32::SetWindowPos(i $page.LaunchCheck, i 0, i 197, i 305, i 280, i 24, i 0x14)'

    # Finish Button centered at (257, 355, 160, 44)
    ${NSD_CreateBitmap} 257 355 160 44 ""
    Pop $page.FinishBtn
    ${NSD_SetImage} $page.FinishBtn "$PLUGINSDIR\ui_btn_finish.bmp" $page.FinishRef
    System::Call 'user32::SetWindowPos(i $page.FinishBtn, i 0, i 257, i 355, i 160, i 44, i 0x14)'
    ${NSD_OnClick} $page.FinishBtn pg.OnFinish

    # Close (X) button at (635, 8, 32, 32)
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $page.CloseBtn
    ${NSD_SetImage} $page.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $page.CloseRef
    System::Call 'user32::SetWindowPos(i $page.CloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $page.CloseBtn pg.OnFinishClose

    # Minimize button at (597, 8, 32, 32)
    ${NSD_CreateBitmap} 597 8 32 32 ""
    Pop $page.MinBtn
    ${NSD_SetImage} $page.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $page.MinRef
    System::Call 'user32::SetWindowPos(i $page.MinBtn, i 0, i 597, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $page.MinBtn pg.OnMinimize

    System::Call 'user32::BringWindowToTop(i $page.CloseBtn)'
    System::Call 'user32::BringWindowToTop(i $page.MinBtn)'
    System::Call 'user32::BringWindowToTop(i $page.LaunchCheck)'
    System::Call 'user32::BringWindowToTop(i $page.FinishBtn)'

    SendMessage $HWNDPARENT 0x0127 0x00010001 0

    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $page.FinishBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $page.CloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $page.MinBtn, i -12, i $5)'

    StrCpy $hov.finBtn "0"
    StrCpy $hov.finClose "0"
    StrCpy $hov.finMin "0"

    ${NSD_CreateTimer} pg.FinishTimer 40

    nsDialogs::Show
    ${NSD_KillTimer} pg.FinishTimer
    ${NSD_FreeImage} $page.BgRef
    ${NSD_FreeImage} $page.FinishRef
    ${NSD_FreeImage} $page.CloseRef
    ${NSD_FreeImage} $page.MinRef
FunctionEnd

Function pg.OnFinish
    ${NSD_KillTimer} pg.FinishTimer
    ${NSD_FreeImage} $page.FinishRef
    ${NSD_SetImage} $page.FinishBtn "$PLUGINSDIR\ui_btn_finish_p.bmp" $page.FinishRef
    Sleep 60
    ${NSD_GetState} $page.LaunchCheck $launchAfterInstall
    ${If} $launchAfterInstall == ${BST_CHECKED}
        IfFileExists "$INSTDIR\${PRODUCT_EXECUTABLE}" 0 +2
            ExecShell "open" "$INSTDIR\${PRODUCT_EXECUTABLE}"
    ${EndIf}
    ShowWindow $HWNDPARENT 0
    SendMessage $HWNDPARENT 0x0010 0 0 ; WM_CLOSE
    Quit
    System::Call 'kernel32::ExitProcess(i 0)'
FunctionEnd

Function pg.OnFinishClose
    ${NSD_KillTimer} pg.FinishTimer
    ShowWindow $HWNDPARENT 0
    SendMessage $HWNDPARENT 0x0010 0 0 ; WM_CLOSE
    Quit
    System::Call 'kernel32::ExitProcess(i 0)'
FunctionEnd

Function pg.FinishLeave
    ${NSD_KillTimer} pg.FinishTimer
FunctionEnd

# ─── Install Section ──────────────────────────────────────────────────────────

Section
    SetAutoClose true

    !insertmacro wails.setShellContext
    !insertmacro wails.webview2runtime

    SetOutPath $INSTDIR
    !insertmacro wails.files
    File "/oname=appicon.ico" "..\icon.ico"

    ${If} $optDesktop == ${BST_CHECKED}
        CreateShortCut "$DESKTOP\${INFO_PRODUCTNAME}.lnk" "$INSTDIR\${PRODUCT_EXECUTABLE}" "" "$INSTDIR\appicon.ico" 0
    ${EndIf}
    ${If} $optStartMenu == ${BST_CHECKED}
        CreateShortcut "$SMPROGRAMS\${INFO_PRODUCTNAME}.lnk" "$INSTDIR\${PRODUCT_EXECUTABLE}" "" "$INSTDIR\appicon.ico" 0
    ${EndIf}
    ${If} $optStartup == ${BST_CHECKED}
        WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${INFO_PRODUCTNAME}" "$INSTDIR\${PRODUCT_EXECUTABLE}"
    ${EndIf}

    !insertmacro wails.associateFiles
    !insertmacro wails.associateCustomProtocols
    !insertmacro wails.writeUninstaller
    WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\appicon.ico"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\appicon.ico"
SectionEnd

# ─── Uninstaller ─────────────────────────────────────────────────────────────

Function un.onInit
    # Kill any running server or manager processes immediately on uninstaller startup
    nsExec::Exec 'cmd.exe /c taskkill /F /T /IM bedrock_server_mod.exe /IM bedrock_server.exe /IM LeviLaminaServerManager.exe /IM levilamina-server-manager.exe 2>nul'

    StrCpy $un.RemoveServers ${BST_CHECKED}
    StrCpy $un.RemoveData    ${BST_CHECKED}
    InitPluginsDir
    File "/oname=$PLUGINSDIR\ui_bg_uninst.bmp"        "ui_bg_uninst.bmp"
    File "/oname=$PLUGINSDIR\ui_bg_uninst_prog.bmp"   "ui_bg_uninst_prog.bmp"
    File "/oname=$PLUGINSDIR\ui_bg_uninst_finish.bmp" "ui_bg_uninst_finish.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_close.bmp"        "ui_btn_close.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_close_h.bmp"      "ui_btn_close_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_close_p.bmp"      "ui_btn_close_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_min.bmp"          "ui_btn_min.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_min_h.bmp"        "ui_btn_min_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_min_p.bmp"        "ui_btn_min_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_uninstall.bmp"    "ui_btn_uninstall.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_uninstall_h.bmp"  "ui_btn_uninstall_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_uninstall_p.bmp"  "ui_btn_uninstall_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_next.bmp"         "ui_btn_next.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_next_h.bmp"       "ui_btn_next_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_next_p.bmp"       "ui_btn_next_p.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_finish.bmp"       "ui_btn_finish.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_finish_h.bmp"     "ui_btn_finish_h.bmp"
    File "/oname=$PLUGINSDIR\ui_btn_finish_p.bmp"     "ui_btn_finish_p.bmp"
    !insertmacro CreateFont -13 600 "Segoe UI" $fnt.TitleBar
    !insertmacro CreateFont -20 700 "Segoe UI" $fnt.Title
    !insertmacro CreateFont -12 400 "Segoe UI" $fnt.Subtitle
    !insertmacro CreateFont -15 700 "Segoe UI" $fnt.OptionHead
FunctionEnd

Function un.onGUIInit
    !insertmacro MakeCustomWindow
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 0
    EnableWindow $0 0
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'
FunctionEnd

Function un.OnDragWindow
    System::Call 'user32::ReleaseCapture()'
    SendMessage $HWNDPARENT 0x00A1 2 0
FunctionEnd

Function un.OnMinimize
    ShowWindow $HWNDPARENT 2
FunctionEnd

Function un.CleanOptionsTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # UninstBtn
    ${If} $3 == $un.UninstBtn
        ${If} $hov.unUninst != "1"
            StrCpy $hov.unUninst "1"
            ${NSD_FreeImage} $un.UninstRef
            ${NSD_SetImage} $un.UninstBtn "$PLUGINSDIR\ui_btn_uninstall_h.bmp" $un.UninstRef
        ${EndIf}
    ${Else}
        ${If} $hov.unUninst != "0"
            StrCpy $hov.unUninst "0"
            ${NSD_FreeImage} $un.UninstRef
            ${NSD_SetImage} $un.UninstBtn "$PLUGINSDIR\ui_btn_uninstall.bmp" $un.UninstRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $un.CloseBtn
        ${If} $hov.unClose != "1"
            StrCpy $hov.unClose "1"
            ${NSD_FreeImage} $un.CloseRef
            ${NSD_SetImage} $un.CloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $un.CloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.unClose != "0"
            StrCpy $hov.unClose "0"
            ${NSD_FreeImage} $un.CloseRef
            ${NSD_SetImage} $un.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $un.CloseRef
        ${EndIf}
    ${EndIf}

    # MinBtn
    ${If} $3 == $un.MinBtn
        ${If} $hov.unMin != "1"
            StrCpy $hov.unMin "1"
            ${NSD_FreeImage} $un.MinRef
            ${NSD_SetImage} $un.MinBtn "$PLUGINSDIR\ui_btn_min_h.bmp" $un.MinRef
        ${EndIf}
    ${Else}
        ${If} $hov.unMin != "0"
            StrCpy $hov.unMin "0"
            ${NSD_FreeImage} $un.MinRef
            ${NSD_SetImage} $un.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $un.MinRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function un.CleanOptionsPage
    nsDialogs::Create 1018
    Pop $un.Dialog
    ${If} $un.Dialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $un.Dialog

    # Explicitly ensure NO default NSIS buttons (especially Cancel #2) are visible
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 0
    EnableWindow $0 0
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'

    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $0
    ${NSD_SetImage} $0 "$PLUGINSDIR\ui_bg_uninst.bmp" $1
    System::Call 'user32::SetWindowPos(i $0, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $0 un.OnDragWindow

    ${NSD_CreateCheckBox} 85 165 500 26 "  Delete all Minecraft servers, worlds, and add-ons (C:\MinecraftServers)"
    Pop $un.CheckboxServers
    SetCtlColors $un.CheckboxServers "1E293B" "F8FAFC"
    !insertmacro SetFont $un.CheckboxServers $fnt.Subtitle
    ${If} $un.RemoveServers == ${BST_CHECKED}
        ${NSD_Check} $un.CheckboxServers
    ${EndIf}
    System::Call 'user32::SetWindowPos(i $un.CheckboxServers, i 0, i 85, i 165, i 500, i 26, i 0x14)'

    ${NSD_CreateCheckBox} 85 215 500 26 "  Delete all app settings, sign-in info, and cache (%APPDATA%, .llsm)"
    Pop $un.CheckboxData
    SetCtlColors $un.CheckboxData "1E293B" "F8FAFC"
    !insertmacro SetFont $un.CheckboxData $fnt.Subtitle
    ${If} $un.RemoveData == ${BST_CHECKED}
        ${NSD_Check} $un.CheckboxData
    ${EndIf}
    System::Call 'user32::SetWindowPos(i $un.CheckboxData, i 0, i 85, i 215, i 500, i 26, i 0x14)'

    # Uninstall button (200x44 at 237, 345)
    ${NSD_CreateBitmap} 237 345 200 44 ""
    Pop $un.UninstBtn
    ${NSD_SetImage} $un.UninstBtn "$PLUGINSDIR\ui_btn_uninstall.bmp" $un.UninstRef
    System::Call 'user32::SetWindowPos(i $un.UninstBtn, i 0, i 237, i 345, i 200, i 44, i 0x14)'
    ${NSD_OnClick} $un.UninstBtn un.DoUninstall

    # Close button (32x32 at 635, 8)
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $un.CloseBtn
    ${NSD_SetImage} $un.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $un.CloseRef
    System::Call 'user32::SetWindowPos(i $un.CloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $un.CloseBtn un.CancelUninstall

    # Minimize button (32x32 at 597, 8)
    ${NSD_CreateBitmap} 597 8 32 32 ""
    Pop $un.MinBtn
    ${NSD_SetImage} $un.MinBtn "$PLUGINSDIR\ui_btn_min.bmp" $un.MinRef
    System::Call 'user32::SetWindowPos(i $un.MinBtn, i 0, i 597, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $un.MinBtn un.OnMinimize

    System::Call 'user32::BringWindowToTop(i $un.CloseBtn)'
    System::Call 'user32::BringWindowToTop(i $un.MinBtn)'
    System::Call 'user32::BringWindowToTop(i $un.UninstBtn)'
    System::Call 'user32::BringWindowToTop(i $un.CheckboxServers)'
    System::Call 'user32::BringWindowToTop(i $un.CheckboxData)'

    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $un.UninstBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $un.CloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $un.MinBtn, i -12, i $5)'

    StrCpy $hov.unUninst "0"
    StrCpy $hov.unClose "0"
    StrCpy $hov.unMin "0"
    ${NSD_CreateTimer} un.CleanOptionsTimer 40

    nsDialogs::Show
    ${NSD_KillTimer} un.CleanOptionsTimer
    ${NSD_FreeImage} $un.UninstRef
    ${NSD_FreeImage} $un.CloseRef
    ${NSD_FreeImage} $un.MinRef
FunctionEnd

Function un.DoUninstall
    ${NSD_KillTimer} un.CleanOptionsTimer
    ${NSD_FreeImage} $un.UninstRef
    ${NSD_SetImage} $un.UninstBtn "$PLUGINSDIR\ui_btn_uninstall_p.bmp" $un.UninstRef
    Sleep 120
    ${NSD_GetState} $un.CheckboxServers $un.RemoveServers
    ${NSD_GetState} $un.CheckboxData    $un.RemoveData
    !insertmacro AdvancePage
FunctionEnd

Function un.CancelUninstall
    MessageBox MB_YESNO|MB_ICONQUESTION "Cancel the uninstallation?" IDNO un.Cancel_No
    SendMessage $HWNDPARENT 0x0010 0 0 ; WM_CLOSE
    Quit
    un.Cancel_No:
FunctionEnd

Function un.CleanOptionsPageLeave
    ${NSD_KillTimer} un.CleanOptionsTimer
FunctionEnd

# ─── Uninstallation Progress Page ──────────────────────────────────────────

Function un.UninstallingProgressTimer
    IntOp $un.InstStep $un.InstStep + 3
    ${If} $un.InstStep > 100
        StrCpy $un.InstStep 100
    ${EndIf}

    SendMessage $un.InstProgressBar 0x0402 $un.InstStep 0 ; PBM_SETPOS

    ${If} $un.InstStep < 20
        ${NSD_SetText} $un.InstStatus "Shutting down active Minecraft Bedrock servers and services... ($un.InstStep%)"
    ${ElseIf} $un.InstStep < 45
        ${NSD_SetText} $un.InstStatus "Closing background processes and listeners... ($un.InstStep%)"
    ${ElseIf} $un.InstStep < 70
        ${NSD_SetText} $un.InstStatus "Removing LeviLamina Server Manager program files... ($un.InstStep%)"
    ${ElseIf} $un.InstStep < 90
        ${NSD_SetText} $un.InstStatus "Cleaning up server data and user settings... ($un.InstStep%)"
    ${ElseIf} $un.InstStep < 100
        ${NSD_SetText} $un.InstStatus "Unregistering system shortcuts and registry entries... ($un.InstStep%)"
    ${Else}
        ${NSD_KillTimer} un.UninstallingProgressTimer
        ${NSD_SetText} $un.InstStatus "Completed! Click Next to continue."
        ShowWindow $un.InstNextBtn 1
        EnableWindow $un.InstNextBtn 1
        System::Call 'user32::BringWindowToTop(i $un.InstNextBtn)'
    ${EndIf}
FunctionEnd

Function un.UninstallingHoverTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # NextBtn
    ${If} $3 == $un.InstNextBtn
        ${If} $hov.unInstNext != "1"
            StrCpy $hov.unInstNext "1"
            ${NSD_FreeImage} $un.InstNextRef
            ${NSD_SetImage} $un.InstNextBtn "$PLUGINSDIR\ui_btn_next_h.bmp" $un.InstNextRef
        ${EndIf}
    ${Else}
        ${If} $hov.unInstNext != "0"
            StrCpy $hov.unInstNext "0"
            ${NSD_FreeImage} $un.InstNextRef
            ${NSD_SetImage} $un.InstNextBtn "$PLUGINSDIR\ui_btn_next.bmp" $un.InstNextRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $un.InstCloseBtn
        ${If} $hov.unInstClose != "1"
            StrCpy $hov.unInstClose "1"
            ${NSD_FreeImage} $un.InstCloseRef
            ${NSD_SetImage} $un.InstCloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $un.InstCloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.unInstClose != "0"
            StrCpy $hov.unInstClose "0"
            ${NSD_FreeImage} $un.InstCloseRef
            ${NSD_SetImage} $un.InstCloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $un.InstCloseRef
        ${EndIf}
    ${EndIf}

    # MinBtn
    ${If} $3 == $un.InstMinBtn
        ${If} $hov.unInstMin != "1"
            StrCpy $hov.unInstMin "1"
            ${NSD_FreeImage} $un.InstMinRef
            ${NSD_SetImage} $un.InstMinBtn "$PLUGINSDIR\ui_btn_min_h.bmp" $un.InstMinRef
        ${EndIf}
    ${Else}
        ${If} $hov.unInstMin != "0"
            StrCpy $hov.unInstMin "0"
            ${NSD_FreeImage} $un.InstMinRef
            ${NSD_SetImage} $un.InstMinBtn "$PLUGINSDIR\ui_btn_min.bmp" $un.InstMinRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function un.UninstallingPage
    !insertmacro MakeCustomWindow
    nsDialogs::Create 1018
    Pop $un.InstDialog
    ${If} $un.InstDialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $un.InstDialog

    # Explicitly ensure NO default NSIS buttons are visible
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 0
    EnableWindow $0 0
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'

    # Background bitmap (675x475)
    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $0
    ${NSD_SetImage} $0 "$PLUGINSDIR\ui_bg_uninst_prog.bmp" $1
    System::Call 'user32::SetWindowPos(i $0, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $0 un.OnDragWindow

    # Progress bar (75, 234, 525, 16)
    System::Call 'user32::CreateWindowEx(i 0, t "msctls_progress32", t "", i 0x50000000, i 75, i 234, i 525, i 16, i $un.InstDialog, i 0, i 0, i 0) i.r0'
    StrCpy $un.InstProgressBar $0
    SendMessage $un.InstProgressBar 0x0401 0 0x00640000 ; PBM_SETRANGE 0..100
    SendMessage $un.InstProgressBar 0x0409 0 0x0081B910 ; PBM_SETBARCOLOR = emerald
    SendMessage $un.InstProgressBar 0x2001 0 0x00F0E8E2 ; CCM_SETBKCOLOR = #E2E8F0
    System::Call 'user32::SetWindowPos(i $un.InstProgressBar, i 0, i 75, i 234, i 525, i 16, i 0x14)'
    System::Call 'user32::BringWindowToTop(i $un.InstProgressBar)'

    # Status label
    ${NSD_CreateLabel} 80 258 515 22 "Shutting down servers and preparing uninstallation..."
    Pop $un.InstStatus
    SetCtlColors $un.InstStatus "059669" "FFFFFF"
    !insertmacro SetFont $un.InstStatus $fnt.Subtitle
    System::Call 'user32::SetWindowPos(i $un.InstStatus, i 0, i 80, i 258, i 515, i 22, i 0x14)'
    System::Call 'user32::BringWindowToTop(i $un.InstStatus)'

    # Next button (160x44 at 475, 412) - initially hidden
    ${NSD_CreateBitmap} 475 412 160 44 ""
    Pop $un.InstNextBtn
    ${NSD_SetImage} $un.InstNextBtn "$PLUGINSDIR\ui_btn_next.bmp" $un.InstNextRef
    System::Call 'user32::SetWindowPos(i $un.InstNextBtn, i 0, i 475, i 412, i 160, i 44, i 0x14)'
    ${NSD_OnClick} $un.InstNextBtn un.OnUninstallNext
    ShowWindow $un.InstNextBtn 0
    EnableWindow $un.InstNextBtn 0

    # Close button (32x32 at 635, 8)
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $un.InstCloseBtn
    ${NSD_SetImage} $un.InstCloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $un.InstCloseRef
    System::Call 'user32::SetWindowPos(i $un.InstCloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $un.InstCloseBtn un.CancelUninstall

    # Minimize button (32x32 at 597, 8)
    ${NSD_CreateBitmap} 597 8 32 32 ""
    Pop $un.InstMinBtn
    ${NSD_SetImage} $un.InstMinBtn "$PLUGINSDIR\ui_btn_min.bmp" $un.InstMinRef
    System::Call 'user32::SetWindowPos(i $un.InstMinBtn, i 0, i 597, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $un.InstMinBtn un.OnMinimize

    System::Call 'user32::BringWindowToTop(i $un.InstCloseBtn)'
    System::Call 'user32::BringWindowToTop(i $un.InstMinBtn)'

    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $un.InstNextBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $un.InstCloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $un.InstMinBtn, i -12, i $5)'

    StrCpy $un.InstStep 0
    ${NSD_CreateTimer} un.UninstallingProgressTimer 45
    ${NSD_CreateTimer} un.UninstallingHoverTimer 40

    nsDialogs::Show
    ${NSD_KillTimer} un.UninstallingProgressTimer
    ${NSD_KillTimer} un.UninstallingHoverTimer
    ${NSD_FreeImage} $un.InstNextRef
    ${NSD_FreeImage} $un.InstCloseRef
    ${NSD_FreeImage} $un.InstMinRef
FunctionEnd

Function un.OnUninstallNext
    ${NSD_KillTimer} un.UninstallingProgressTimer
    ${NSD_KillTimer} un.UninstallingHoverTimer
    ${NSD_FreeImage} $un.InstNextRef
    ${NSD_SetImage} $un.InstNextBtn "$PLUGINSDIR\ui_btn_next_p.bmp" $un.InstNextRef
    Sleep 120
    !insertmacro AdvancePage
FunctionEnd

Function un.UninstallingPageLeave
FunctionEnd

Function un.InstFilesShow
    ShowWindow $HWNDPARENT 0
FunctionEnd

Function un.FinishTimer
    System::Alloc 8
    Pop $0
    System::Call "user32::GetCursorPos(i r0)"
    System::Call "*$0(i .r1, i .r2)"
    System::Free $0
    System::Call "user32::WindowFromPoint(i r1, i r2) i .r3"

    # FinBtn
    ${If} $3 == $un.FinBtn
        ${If} $hov.unFinish != "1"
            StrCpy $hov.unFinish "1"
            ${NSD_FreeImage} $un.FinRef
            ${NSD_SetImage} $un.FinBtn "$PLUGINSDIR\ui_btn_finish_h.bmp" $un.FinRef
        ${EndIf}
    ${Else}
        ${If} $hov.unFinish != "0"
            StrCpy $hov.unFinish "0"
            ${NSD_FreeImage} $un.FinRef
            ${NSD_SetImage} $un.FinBtn "$PLUGINSDIR\ui_btn_finish.bmp" $un.FinRef
        ${EndIf}
    ${EndIf}

    # CloseBtn
    ${If} $3 == $un.CloseBtn
        ${If} $hov.unFinClose != "1"
            StrCpy $hov.unFinClose "1"
            ${NSD_FreeImage} $un.CloseRef
            ${NSD_SetImage} $un.CloseBtn "$PLUGINSDIR\ui_btn_close_h.bmp" $un.CloseRef
        ${EndIf}
    ${Else}
        ${If} $hov.unFinClose != "0"
            StrCpy $hov.unFinClose "0"
            ${NSD_FreeImage} $un.CloseRef
            ${NSD_SetImage} $un.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $un.CloseRef
        ${EndIf}
    ${EndIf}
FunctionEnd

Function un.FinishPage
    nsDialogs::Create 1018
    Pop $un.Dialog
    ${If} $un.Dialog == error
        Abort
    ${EndIf}
    !insertmacro SetupPageCustom $un.Dialog

    # Explicitly ensure NO default NSIS buttons are visible
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 0
    EnableWindow $0 0
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 0
    EnableWindow $0 0
    System::Call 'user32::SetWindowPos(i $0, i 0, i -2000, i -2000, i 0, i 0, i 0x14)'

    ${NSD_CreateBitmap} 0 0 ${WIN_W} ${WIN_H} ""
    Pop $0
    ${NSD_SetImage} $0 "$PLUGINSDIR\ui_bg_uninst_finish.bmp" $1
    System::Call 'user32::SetWindowPos(i $0, i 0, i 0, i 0, i ${WIN_W}, i ${WIN_H}, i 0x14)'
    ${NSD_OnClick} $0 un.OnDragWindow

    # Close button (32x32 at 635, 8)
    ${NSD_CreateBitmap} 635 8 32 32 ""
    Pop $un.CloseBtn
    ${NSD_SetImage} $un.CloseBtn "$PLUGINSDIR\ui_btn_close.bmp" $un.CloseRef
    System::Call 'user32::SetWindowPos(i $un.CloseBtn, i 0, i 635, i 8, i 32, i 32, i 0x14)'
    ${NSD_OnClick} $un.CloseBtn un.OnFinishClose

    # Finish button (160x44 at 257, 355)
    ${NSD_CreateBitmap} 257 355 160 44 ""
    Pop $un.FinBtn
    ${NSD_SetImage} $un.FinBtn "$PLUGINSDIR\ui_btn_finish.bmp" $un.FinRef
    System::Call 'user32::SetWindowPos(i $un.FinBtn, i 0, i 257, i 355, i 160, i 44, i 0x14)'
    ${NSD_OnClick} $un.FinBtn un.OnFinishClose

    System::Call 'user32::BringWindowToTop(i $un.CloseBtn)'
    System::Call 'user32::BringWindowToTop(i $un.FinBtn)'

    System::Call 'user32::LoadCursor(i 0, i 32649) i.r5'
    System::Call 'user32::SetClassLong(i $un.CloseBtn, i -12, i $5)'
    System::Call 'user32::SetClassLong(i $un.FinBtn, i -12, i $5)'

    StrCpy $hov.unFinish "0"
    StrCpy $hov.unFinClose "0"
    ${NSD_CreateTimer} un.FinishTimer 40

    nsDialogs::Show
    ${NSD_KillTimer} un.FinishTimer
    ${NSD_FreeImage} $un.CloseRef
    ${NSD_FreeImage} $un.FinRef
FunctionEnd

Function un.OnFinishClose
    ${NSD_KillTimer} un.FinishTimer
    ${NSD_FreeImage} $un.FinRef
    ${NSD_SetImage} $un.FinBtn "$PLUGINSDIR\ui_btn_finish_p.bmp" $un.FinRef
    Sleep 120
    ShowWindow $HWNDPARENT 0
    SendMessage $HWNDPARENT 0x0010 0 0 ; WM_CLOSE
    Quit
    System::Call 'kernel32::ExitProcess(i 0)'
FunctionEnd

# ─── Uninstall Section ────────────────────────────────────────────────────────

Section "uninstall"
    SetAutoClose true
    SetOutPath "$TEMP"
    !insertmacro wails.setShellContext

    nsExec::Exec 'cmd.exe /c taskkill /F /T /IM bedrock_server_mod.exe /IM bedrock_server.exe /IM LeviLaminaServerManager.exe /IM levilamina-server-manager.exe 2>nul'

    ${If} $un.RemoveServers == ${BST_CHECKED}
        RMDir /r /REBOOTOK "C:\MinecraftServers"
        RMDir /r /REBOOTOK "$PROFILE\MinecraftServers"
    ${EndIf}

    ${If} $un.RemoveData == ${BST_CHECKED}
        RMDir /r /REBOOTOK "$PROFILE\.llsm"
        RMDir /r /REBOOTOK "$APPDATA\LeviLaminaServerManager"
        RMDir /r /REBOOTOK "$LOCALAPPDATA\LeviLaminaServerManager"
        RMDir /r /REBOOTOK "$LOCALAPPDATA\${PRODUCT_EXECUTABLE}.WebView2"
        DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${INFO_PRODUCTNAME}"
    ${EndIf}

    SetShellVarContext all
    Delete "$SMPROGRAMS\${INFO_PRODUCTNAME}.lnk"
    Delete "$DESKTOP\${INFO_PRODUCTNAME}.lnk"
    SetShellVarContext current
    Delete "$SMPROGRAMS\${INFO_PRODUCTNAME}.lnk"
    Delete "$DESKTOP\${INFO_PRODUCTNAME}.lnk"

    !insertmacro wails.unassociateFiles
    !insertmacro wails.unassociateCustomProtocols

    SetOutPath "$TEMP"
    Delete "$INSTDIR\appicon.ico"
    !insertmacro wails.deleteUninstaller

    RMDir /r /REBOOTOK "$INSTDIR\${PRODUCT_EXECUTABLE}.WebView2"
    RMDir /r /REBOOTOK "$INSTDIR"
SectionEnd
