; ================================================================
; Invoice & POS Billing Software — Professional Installer
; Inno Setup 6  (https://jrsoftware.org/isinfo.php)
;
; What this installer does:
;   1. Installs Flutter desktop app  → Program Files\Invoice & POS Billing\
;   2. Installs backend server exe   → ...\server\
;   3. Registers backend as a hidden Windows Task (SYSTEM, runs on boot)
;   4. Starts the backend immediately (hidden, no console window)
;   5. Creates Desktop shortcut + Start Menu entry
;   6. Provides clean uninstaller (stops & removes background task)
; ================================================================

#define AppName       "Invoice & POS Billing"
#define AppVersion    "1.0.0"
#define AppPublisher  "Your Company"
#define AppURL        "https://yourcompany.com"
#define AppExeName    "invoice_pos.exe"
#define ServerExe     "invoice_pos_server.exe"
#define TaskName      "InvoicePOS\BackendServer"
#define FlutterSrc    "..\dist\windows"
#define BackendSrc    "..\backend\dist"

; ── [Setup] ──────────────────────────────────────────────────────
[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF0123456789}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} v{#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/support
AppUpdatesURL={#AppURL}/updates
VersionInfoVersion={#AppVersion}
VersionInfoDescription={#AppName} Setup
VersionInfoCompany={#AppPublisher}

; Install location
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

; Output
OutputDir=..\dist\installer
OutputBaseFilename=InvoicePOS_Setup_v{#AppVersion}
SetupIconFile=
WizardImageFile=compiler:WizModernImage.bmp
WizardSmallImageFile=compiler:WizModernSmallImage.bmp

; Compression
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; UI style
WizardStyle=modern
WizardResizable=no

; Permissions
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible

; Behavior
CloseApplications=yes
RestartApplications=no
AllowNoIcons=yes
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}

; ── [Languages] ──────────────────────────────────────────────────
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; ── [Tasks] ──────────────────────────────────────────────────────
[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"
Name: "autostart";   Description: "Start backend server automatically with Windows (recommended)"

; ── [Files] ──────────────────────────────────────────────────────
[Files]
; Flutter desktop app (all files — exe, dlls, and data folder)
Source: "{#FlutterSrc}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterSrc}\*.dll";          DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#FlutterSrc}\data\*";         DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Backend server
Source: "{#BackendSrc}\{#ServerExe}";      DestDir: "{app}\server"; Flags: ignoreversion
Source: "{#BackendSrc}\.env";              DestDir: "{app}\server"; Flags: ignoreversion

; ── [Icons] ──────────────────────────────────────────────────────
[Icons]
; Start Menu
Name: "{group}\{#AppName}";                         Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{group}\Uninstall {#AppName}";               Filename: "{uninstallexe}"

; Desktop shortcut
Name: "{autodesktop}\{#AppName}";                   Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
; Startup folder — auto-starts backend on login (no schtasks admin needed)
Name: "{userstartup}\InvoicePOS Backend";            Filename: "{app}\server\{#ServerExe}"; WorkingDir: "{app}\server"; Tasks: autostart

; ── [Run] — post-install ─────────────────────────────────────────
[Run]
; Start the backend right now (hidden)
Filename: "powershell.exe"; \
  Parameters: "-WindowStyle Hidden -Command ""Start-Process '{app}\server\{#ServerExe}' -WindowStyle Hidden"""; \
  Flags: runhidden waituntilterminated; \
  Tasks: autostart; \
  StatusMsg: "Starting backend server..."

; Launch the app (user-visible, optional)
Filename: "{app}\{#AppExeName}"; \
  Description: "Launch {#AppName} now"; \
  Flags: postinstall nowait skipifsilent

; ── [UninstallRun] — pre-uninstall ───────────────────────────────
[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/F /IM ""{#ServerExe}"""; Flags: runhidden; RunOnceId: "KillServer"

; ── [UninstallDelete] ────────────────────────────────────────────
[UninstallDelete]
Type: filesandordirs; Name: "{app}\server"
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{localappdata}\invoice_pos"

; ── [Code] — Pascal script ───────────────────────────────────────
[Code]

// Show a friendly welcome message in the wizard
function GetWelcomeText(Default: String): String;
begin
  Result := 'This will install ' + ExpandConstant('{#AppName}') + ' v' +
            ExpandConstant('{#AppVersion}') + ' on your computer.' + #13#10 + #13#10 +
            'The app includes:' + #13#10 +
            '  • Sales & POS billing' + #13#10 +
            '  • Inventory management' + #13#10 +
            '  • Customer & supplier records' + #13#10 +
            '  • Reports & analytics' + #13#10 +
            '  • Cloud database (always synced)' + #13#10 + #13#10 +
            'Click Next to continue.';
end;
