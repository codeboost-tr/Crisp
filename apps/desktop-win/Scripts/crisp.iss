; crisp.iss — Inno Setup installer for Crisp (Windows), the counterpart of the macOS
; DMG (apps/desktop/make-dmg.sh). Packages the self-contained win-x64 bundle (the app
; + the engine + its vendored ffmpeg/whisper/python under engine/bin) into Crisp-Setup.exe.
;
; Build:  iscc /DSourceDir=<publish dir> /DAppVersion=<x.y> Scripts\crisp.iss
; Output: Crisp-Setup.exe next to this script. Unsigned by default — a release adds a
; SignTool pass with the code-signing cert (so SmartScreen doesn't warn). No AI
; attribution; credited to Syntax Lab Technology / Abdul Rafay.

#ifndef SourceDir
  #define SourceDir "..\publish"
#endif
#ifndef AppVersion
  #define AppVersion "0.0"
#endif

[Setup]
AppId={{C8A5E2D4-9B6F-4E1A-A3D7-5F8B1C2E3A40}}
AppName=Crisp
AppVersion={#AppVersion}
AppVerName=Crisp {#AppVersion}
AppPublisher=Syntax Lab Technology
AppPublisherURL=https://rafay99.com
DefaultDirName={autopf}\Crisp
DefaultGroupName=Crisp
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=Crisp-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\Crisp.exe
; The app writes its data to ~/.crisp (per-channel) — installing under Program Files
; never touches it, so an update/uninstall leaves the user's models + settings.

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\Crisp"; Filename: "{app}\Crisp.exe"
Name: "{commondesktop}\Crisp"; Filename: "{app}\Crisp.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Run]
Filename: "{app}\Crisp.exe"; Description: "Launch Crisp"; Flags: nowait postinstall skipifsilent
