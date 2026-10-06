; Battlefield 1942 & Expansions Installer
; https://github.com/AnomalousNicole/BF1942-Installer
;
; Do not compile this file directly - run build.ps1 from the repository root.
; build.ps1 downloads the components, compiles VulkanCheck.exe and writes build\generated.iss
; (your settings from config.json + component versions from components.json), included below.

#if Ver < EncodeVer(7, 0, 0)
  #error Inno Setup 7 or newer is required.
#endif
#define Root ExtractFileDir(RemoveBackslashUnlessRoot(SourcePath))
#if !FileExists(Root + "\build\generated.iss")
  #error build\generated.iss was not found - run build.ps1 from the repository root instead of compiling this script directly.
#endif
#include "..\build\generated.iss"

#define VCVer GetVersionNumbersString(Deps + "\vcredist\VC_redist.x86.exe")
#define DotNetVer Ver_dotnet8
#define StateKeyParent ExtractFileDir(StateKey)
#define HasFontPack (Has_font_original || Has_font_1x || Has_font_2x || Has_font_3x || Has_font_35x || Has_font_4x)
#if !HasFontPack
  #error No font in extras\Fonts - the game's own Font.rfa is not shipped, so at least one font is required
#endif
; Pre-selected font: 2x when present, otherwise the closest available size
#if Has_font_2x
  #define DefaultFont "x2"
  #define DefaultFontDir "2x"
#elif Has_font_1x
  #define DefaultFont "x1"
  #define DefaultFontDir "1x"
#elif Has_font_3x
  #define DefaultFont "x3"
  #define DefaultFontDir "3x"
#elif Has_font_35x
  #define DefaultFont "x35"
  #define DefaultFontDir "3.5x"
#elif Has_font_4x
  #define DefaultFont "x4"
  #define DefaultFontDir "4x"
#else
  #define DefaultFont "original"
  #define DefaultFontDir "Original"
#endif

; ---- Welcome page list of included community tools ----
#define WelcomeTools "%n  • BF42++ " + Ver_bf42pp + " by Casqade%n  • DXVK " + Ver_dxvk + " by Philip Rebohle (doitsujin)%n  • dgVoodoo2 " + Ver_dgvoodoo2 + " by Dege (dege-diosg)%n  • DSOAL + OpenAL Soft by Chris Robinson (kcat)"
#if Has_borderless1942
  #define WelcomeTools WelcomeTools + "%n  • Borderless1942 " + Ver_borderless1942 + " by Turnerj, LANCommander and Nicole"
#endif
#if Has_datafield42
  #define WelcomeTools WelcomeTools + "%n  • DataField42 " + Ver_datafield42 + " by Ahrkylien"
#endif
#if Has_bobsiren
  #define WelcomeTools WelcomeTools + "%n  • Battle of Britain - disable siren by Nicole @ MoonGamers"
#endif
#if Has_richpresence
  #define WelcomeTools WelcomeTools + "%n  • Battlefield Rich Presence " + Ver_richpresence + " by Gametools Network"
#endif
#if CreatedBy != ""
  #define CreatedLine "%n%nInstaller created by " + CreatedBy + "."
#else
  #define CreatedLine ""
#endif

#pragma message "BF42++ " + Ver_bf42pp + " | DXVK " + Ver_dxvk + " | dgVoodoo2 " + Ver_dgvoodoo2 + " | VC++ " + VCVer

[Setup]
AppId={{{#AppIdGuid}}
AppName={#AppName}
AppVersion=1.61
AppVerName={#AppName}
AppPublisher={#AppPublisher}
AppComments=Battlefield 1942, The Road to Rome and Secret Weapons of WWII with community fixes
DefaultDirName={#DefaultDir}
DisableDirPage=no
DisableWelcomePage=no
DisableProgramGroupPage=yes
DisableReadyPage=no
PrivilegesRequired=admin
; Windows 10 version 1809 (build 17763) or later: the oldest Windows that BF1942 Options (WinUI) runs on
MinVersion=10.0.17763
WizardStyle=modern
#if GameIcon != ""
SetupIconFile={#GameIcon}
#endif
#if WizardImages != ""
; Left panel of the Welcome/Finish pages - branding\WizardImage*.bmp
WizardImageFile={#WizardImages}
#endif
UninstallDisplayIcon={app}\BF1942.exe
UninstallDisplayName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBase}
; A single Setup.exe can hold up to 4,200,000,000 bytes. build.ps1 defines SPAN when the build does not fit,
; which keeps Setup.exe small and puts the data in <OutputBase>-1.bin, -2.bin, ... next to it
Compression={#Compression}
SolidCompression=yes
; build.ps1 picks the thread count for this PC. With -Smallest it compresses one stream with a 1 GB
; dictionary instead (about 5% smaller, much slower); 1 GB is the most a 32-bit Setup supports.
LZMANumBlockThreads={#LzmaThreads}
#if LzmaDict > 0
LZMADictionarySize={#LzmaDict}
#endif
#ifdef SPAN
DiskSpanning=yes
; Just under 2 GB per slice, so every file stays easy to upload and copy ("max" would mean unlimited)
DiskSliceSize=2100000000
#else
DiskSpanning=no
#endif
SetupLogging=yes
VersionInfoDescription={#InstallerTitle}
VersionInfoCompany={#AppPublisher}

[Messages]
SetupWindowTitle={#InstallerTitle}
UninstallAppTitle={#InstallerTitle}
UninstallAppFullTitle={#InstallerTitle}
WelcomeLabel1=Welcome to the {#InstallerTitle}
WelcomeLabel2=This wizard installs Battlefield 1942 with The Road to Rome and Secret Weapons of WWII, pre-configured to run on modern Windows.%n%nIncluded community tools/fixes:{#WelcomeTools}{#CreatedLine}

[Types]
Name: "recommended"; Description: "Recommended installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "game"; Description: "Battlefield 1942 + The Road to Rome + Secret Weapons of WWII"; Types: recommended custom; Flags: fixed
Name: "required"; Description: "Required fixes (always installed)"; Types: recommended custom; Flags: fixed
Name: "required\bf42pp"; Description: "BF42++ {#Ver_bf42pp} (Casqade)"; Types: recommended custom; Flags: fixed
Name: "required\renderer"; Description: "DXVK {#Ver_dxvk} (auto-detected) or dgVoodoo2 {#Ver_dgvoodoo2} fallback"; Types: recommended custom; Flags: fixed
Name: "required\hrtf"; Description: "HRTF - DSOAL + OpenAL Soft (3D audio)"; Types: recommended custom; Flags: fixed
Name: "required\directx"; Description: "DirectX End-User Runtime (June 2010) (only if missing)"; Types: recommended custom; Flags: fixed
Name: "required\vcredist"; Description: "Visual C++ Redistributable x86 {#VCVer} (only if missing)"; Types: recommended custom; Flags: fixed
Name: "required\directplay"; Description: "Enable Windows DirectPlay feature (only if not enabled)"; Types: recommended custom; Flags: fixed
#if Has_bobsiren
Name: "bobsiren"; Description: "Battle of Britain - disable the air raid siren (Nicole @ MoonGamers)"; Types: custom
#endif
; Borderless1942 and Battlefield Rich Presence are 64-bit only - hidden on 32-bit Windows
#if Has_borderless1942
Name: "borderless"; Description: "Borderless1942 {#Ver_borderless1942} (Turnerj, LANCommander, Nicole) - borderless window launcher"; Types: custom; Check: IsWin64
#endif
#if Has_datafield42
Name: "datafield"; Description: "DataField42 {#Ver_datafield42} (Ahrkylien) - automatic map/mod downloader"; Types: custom; Check: IsWin64
#endif
#if Has_richpresence
Name: "richpresence"; Description: "Battlefield Rich Presence {#Ver_richpresence} (Gametools Network) - show your BF1942 game in Discord"; Types: custom; Check: IsWin64
#endif
#if Has_punkbuster42
Name: "punkbuster"; Description: "Punkbuster42 - community installer for PunkBuster anti-cheat (online play)"; Types: custom
#endif
#if Has_compat
Name: "compat"; Description: "Battlefield 1942 Compatibility Profile (only if you get crashes)"; Types: custom
#endif
#if Has_hiresui
Name: "hiresui"; Description: "Higher resolution UI - 0.1 (sharper menus and HUD)"; Types: custom
#endif
#if HasFontPack
Name: "font"; Description: "Font"; Types: recommended custom; Flags: fixed
  #if Has_font_original
Name: "font\original"; Description: "BF1942 Original Font - for 800x600 / 1024x768"; {#DefaultFont == "original" ? "Types: recommended; " : ""}Flags: exclusive
  #endif
  #if Has_font_1x
Name: "font\x1"; Description: "Font size: 1x - for 1280x720 / 1366x768"; {#DefaultFont == "x1" ? "Types: recommended; " : ""}Flags: exclusive
  #endif
  #if Has_font_2x
Name: "font\x2"; Description: "Font size: 2x (most common) - for 1920x1080"; Types: recommended; Flags: exclusive
  #endif
  #if Has_font_3x
Name: "font\x3"; Description: "Font size: 3x - for 2560x1440"; {#DefaultFont == "x3" ? "Types: recommended; " : ""}Flags: exclusive
  #endif
  #if Has_font_35x
Name: "font\x35"; Description: "Font size: 3.5x - for 3440x1440 / 2560x1600"; {#DefaultFont == "x35" ? "Types: recommended; " : ""}Flags: exclusive
  #endif
  #if Has_font_4x
Name: "font\x4"; Description: "Font size: 4x - for 3840x2160 (4K)"; {#DefaultFont == "x4" ? "Types: recommended; " : ""}Flags: exclusive
  #endif
#endif

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut to BF1942.exe"; GroupDescription: "Shortcuts:"
#if ServerAddress != ""
Name: "servericon"; Description: "Create a ""{#ServerName}"" desktop shortcut (joins {#ServerAddress})"; GroupDescription: "Shortcuts:"
#endif
#if Has_borderless1942
Name: "borderlessicon"; Description: "Create a desktop shortcut for Borderless1942 (uses your primary monitor resolution)"; GroupDescription: "Shortcuts:"; Components: borderless
#endif
; Ticked by default; untick it for no desktop shortcut (the Start menu one is always there)
Name: "optionsicon"; Description: "Create a desktop shortcut to Battlefield 1942 Options, the app that turns the fixes and extras on or off after install"; GroupDescription: "Shortcuts:"
Name: "skipintro"; Description: "Skip the intro videos (adds +restart 1 to the shortcut)"; GroupDescription: "Game options:"

[Files]
; Helper used to decide between DXVK and dgVoodoo2 (Setup runs it from {tmp}; BF1942 Options' copy is installed below)
Source: "{#BuildDir}\VulkanCheck.exe"; Flags: dontcopy

; Base game (the Tools folder is not shipped - DirectX/DirectPlay are handled by the installer)
#ifndef QUICK
; The game folder's own Font.rfa is never shipped - Font.rfa always comes from the Font component
Source: "{#GameDir}\*"; Excludes: "\Mods\bf1942\Archives\Font.rfa,\Tools,\Mods\bf1942\Settings"; DestDir: "{app}"; Components: game; Flags: ignoreversion recursesubdirs createallsubdirs
; The player's settings (profile and player name, controls, video, sound, server settings) only go in when missing,
; so running Setup again keeps them. Setup sets the screen resolution and windowed mode in them afterwards.
Source: "{#GameDir}\Mods\bf1942\Settings\*"; DestDir: "{app}\Mods\bf1942\Settings"; Components: game; Flags: onlyifdoesntexist recursesubdirs createallsubdirs
#endif
; /COMPONENTS without a font: the default font, unless the game folder has a font already (see NoFontSelected)
Source: "{#Extras}\Fonts\{#DefaultFontDir}\Font.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Check: NoFontSelected; Flags: onlyifdoesntexist

; Troubleshooting guide (and any other page in docs\manual), next to the game manual. build.ps1 prints them to PDF in build\manual
Source: "{#ManualDir}\*.pdf"; DestDir: "{app}\manual"; Flags: ignoreversion

; BF1942 Options (a WinUI app, installer\BF1942Options) turns the fixes and extras on and off after install.
; build.ps1 publishes it self-contained to build\options; it runs from {app}\Options\App. It switches between the
; copies kept in {app}\Options: every fix it can turn on, and the original game files that the extras replace.
; Files that are also installed elsewhere are stored once in the setup file.
Source: "{#OptionsDir}\*"; DestDir: "{app}\Options\App"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildDir}\VulkanCheck.exe"; DestDir: "{app}\Options"; Flags: ignoreversion
Source: "{#Deps}\bf42pp\*"; DestDir: "{app}\Options\BF42++"; Flags: ignoreversion
Source: "{#Deps}\hrtf\*"; Excludes: "*.txt"; DestDir: "{app}\Options\DSOAL"; Flags: ignoreversion
Source: "{#Deps}\dxvk\*"; DestDir: "{app}\Options\DXVK"; Flags: ignoreversion
Source: "{#Deps}\dgvoodoo2\*"; DestDir: "{app}\Options\dgVoodoo2"; Flags: ignoreversion
#if Has_borderless1942
Source: "{#Deps}\borderless1942\Borderless1942.exe"; DestDir: "{app}\Options\Borderless1942"; Check: IsWin64; Flags: ignoreversion
#endif
#if Has_compat
Source: "{#Extras}\CompatProfile\BF1942.sdb"; DestDir: "{app}\Options\Compatibility Profile"; Flags: ignoreversion
#endif
#ifndef QUICK
  #if Has_hiresui
Source: "{#Extras}\HiResUI\menu.rfa"; DestDir: "{app}\Options\Higher resolution UI"; Flags: ignoreversion
Source: "{#GameDir}\Mods\bf1942\Archives\menu.rfa"; DestDir: "{app}\Options\Originals"; Flags: ignoreversion
  #endif
  #if Has_bobsiren
Source: "{#Deps}\bobsiren\Battle_of_Britain.rfa"; DestDir: "{app}\Options\Battle of Britain disable siren"; Flags: ignoreversion
Source: "{#GameDir}\Mods\bf1942\Archives\bf1942\levels\Battle_of_Britain.rfa"; DestDir: "{app}\Options\Originals"; Flags: ignoreversion
  #endif
#endif
#if Has_font_original
Source: "{#Extras}\Fonts\Original\Font.rfa"; DestDir: "{app}\Options\Fonts\Original"; Flags: ignoreversion
#endif
#if Has_font_1x
Source: "{#Extras}\Fonts\1x\Font.rfa"; DestDir: "{app}\Options\Fonts\1x"; Flags: ignoreversion
#endif
#if Has_font_2x
Source: "{#Extras}\Fonts\2x\Font.rfa"; DestDir: "{app}\Options\Fonts\2x"; Flags: ignoreversion
#endif
#if Has_font_3x
Source: "{#Extras}\Fonts\3x\Font.rfa"; DestDir: "{app}\Options\Fonts\3x"; Flags: ignoreversion
#endif
#if Has_font_35x
Source: "{#Extras}\Fonts\3.5x\Font.rfa"; DestDir: "{app}\Options\Fonts\3.5x"; Flags: ignoreversion
#endif
#if Has_font_4x
Source: "{#Extras}\Fonts\4x\Font.rfa"; DestDir: "{app}\Options\Fonts\4x"; Flags: ignoreversion
#endif

; Required fixes (next to BF1942.exe)
Source: "{#Deps}\bf42pp\*"; Excludes: "bf42++.ini"; DestDir: "{app}"; Components: required\bf42pp; Flags: ignoreversion
Source: "{#Deps}\hrtf\*"; Excludes: "*.txt,alsoft.ini"; DestDir: "{app}"; Components: required\hrtf; Flags: ignoreversion
; Their settings files only when missing, so the player's own settings stay (BF1942 Options does the same)
Source: "{#Deps}\bf42pp\bf42++.ini"; DestDir: "{app}"; Components: required\bf42pp; Flags: onlyifdoesntexist
Source: "{#Deps}\hrtf\alsoft.ini"; DestDir: "{app}"; Components: required\hrtf; Flags: onlyifdoesntexist
Source: "{#Deps}\hrtf\*.txt"; DestDir: "{app}\Licenses"; Components: required\hrtf; Flags: ignoreversion
Source: "{#Deps}\dxvk\*"; Excludes: "dxvk.conf"; DestDir: "{app}"; Components: required\renderer; Check: UseDXVK; Flags: ignoreversion
; The renderer's config file only when missing, so the player's own settings in it stay
Source: "{#Deps}\dxvk\dxvk.conf"; DestDir: "{app}"; Components: required\renderer; Check: UseDXVK; Flags: onlyifdoesntexist
Source: "{#Deps}\dgvoodoo2\*"; Excludes: "dgVoodoo.conf"; DestDir: "{app}"; Components: required\renderer; Check: not UseDXVK; Flags: ignoreversion
Source: "{#Deps}\dgvoodoo2\dgVoodoo.conf"; DestDir: "{app}"; Components: required\renderer; Check: not UseDXVK; Flags: onlyifdoesntexist

; Redistributables (temporary only)
Source: "{#Deps}\directx\*"; DestDir: "{tmp}\dxredist"; Components: required\directx; Check: DirectXNeeded; Flags: deleteafterinstall
Source: "{#Deps}\vcredist\VC_redist.x86.exe"; DestDir: "{tmp}"; Components: required\vcredist; Check: VCRedistNeeded; Flags: deleteafterinstall

; Optional
#if Has_bobsiren
; Replaces the base game's Battle of Britain map with a copy that has the air raid siren removed
Source: "{#Deps}\bobsiren\Battle_of_Britain.rfa"; DestDir: "{app}\Mods\bf1942\Archives\bf1942\levels"; Components: bobsiren; Flags: ignoreversion
#endif
#if Has_borderless1942
Source: "{#Deps}\borderless1942\Borderless1942.exe"; DestDir: "{app}"; Components: borderless; Flags: ignoreversion
#endif
#if Has_datafield42
Source: "{#Deps}\datafield42\{#File_datafield42}"; DestDir: "{tmp}"; Components: datafield; Flags: deleteafterinstall
#endif
#if Has_richpresence
Source: "{#Deps}\richpresence\{#File_richpresence}"; DestDir: "{tmp}"; Components: richpresence; Flags: deleteafterinstall
; .NET 8 Desktop Runtime (x64), needed by Battlefield Rich Presence - only extracted if missing
Source: "{#Deps}\dotnet8\{#File_dotnet8}"; DestDir: "{tmp}"; Components: richpresence; Check: DotNetDesktop8Needed; Flags: deleteafterinstall
#endif
#if Has_punkbuster42
Source: "{#Extras}\Punkbuster42\Punkbuster42.exe"; DestDir: "{tmp}\pb42"; Components: punkbuster; Flags: deleteafterinstall
#endif
#if Has_compat
; PCGamingWiki shim database (EmulateHeap, NoGhost, Win98VersionLie) - registered with sdbinst in [Run]
Source: "{#Extras}\CompatProfile\BF1942.sdb"; DestDir: "{app}"; Components: compat; Flags: ignoreversion
#endif
#if Has_hiresui
Source: "{#Extras}\HiResUI\menu.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Components: hiresui; Flags: ignoreversion
#endif
#if Has_font_original
Source: "{#Extras}\Fonts\Original\Font.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Components: font\original; Flags: ignoreversion
#endif
#if Has_font_1x
Source: "{#Extras}\Fonts\1x\Font.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Components: font\x1; Flags: ignoreversion
#endif
#if Has_font_2x
Source: "{#Extras}\Fonts\2x\Font.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Components: font\x2; Flags: ignoreversion
#endif
#if Has_font_3x
Source: "{#Extras}\Fonts\3x\Font.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Components: font\x3; Flags: ignoreversion
#endif
#if Has_font_35x
Source: "{#Extras}\Fonts\3.5x\Font.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Components: font\x35; Flags: ignoreversion
#endif
#if Has_font_4x
Source: "{#Extras}\Fonts\4x\Font.rfa"; DestDir: "{app}\Mods\bf1942\Archives"; Components: font\x4; Flags: ignoreversion
#endif

[Registry]
; EA registration (32-bit view = HKLM\SOFTWARE\WOW6432Node on 64-bit Windows)
Root: HKLM32; Subkey: "SOFTWARE\Electronic Arts"; Flags: uninsdeletekeyifempty
Root: HKLM32; Subkey: "SOFTWARE\Electronic Arts\EA GAMES"; Flags: uninsdeletekeyifempty
Root: HKLM32; Subkey: "SOFTWARE\Electronic Arts\EA GAMES\Battlefield 1942"; ValueType: string; ValueName: "GAMEDIR"; ValueData: "{app}"; Flags: uninsdeletevalue uninsdeletekeyifempty
#if GenerateSerial
; Random serial - only written (and removed on uninstall) when no valid 22-character serial already exists
Root: HKLM32; Subkey: "SOFTWARE\Electronic Arts\EA GAMES\Battlefield 1942\ergc"; ValueType: string; ValueName: ""; ValueData: "{code:GetSerial}"; Flags: uninsdeletekey; Check: IsNewSerial
#endif
; Installer state (used by the uninstaller)
#if Lowercase(StateKeyParent) != "software"
Root: HKLM32; Subkey: "{#StateKeyParent}"; Flags: uninsdeletekeyifempty
#endif
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "Renderer"; ValueData: "{code:GetRendererName}"; Flags: uninsdeletekey
; Whether uninstalling deletes the whole folder (FolderIsGameFolder), kept for when Setup runs again over it
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "WholeFolder"; ValueData: "{code:WholeFolderValue}"; Flags: uninsdeletekey
; Read by BF1942 Options: the versions it shows, and whether its shortcuts skip the intro
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "VerBF42PP"; ValueData: "{#Ver_bf42pp}"; Flags: uninsdeletekey
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "VerDXVK"; ValueData: "{#Ver_dxvk}"; Flags: uninsdeletekey
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "VerDgVoodoo2"; ValueData: "{#Ver_dgvoodoo2}"; Flags: uninsdeletekey
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "SkipIntro"; ValueData: "1"; Tasks: skipintro; Flags: uninsdeletekey
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "SkipIntro"; ValueData: "0"; Tasks: not skipintro; Flags: uninsdeletekey
#if Has_datafield42
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "DataField42"; ValueData: "1"; Components: datafield; Flags: uninsdeletekey
#endif
#if Has_richpresence
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "RichPresence"; ValueData: "1"; Components: richpresence; Check: RichPresenceIsNew; Flags: uninsdeletekey
#endif
#if Has_punkbuster42
; PunkBuster Services are shared with other PB games - the uninstaller only removes them when no other PB game is found
Root: HKLM32; Subkey: "{#StateKey}"; ValueType: string; ValueName: "PunkBuster"; ValueData: "1"; Components: punkbuster; Flags: uninsdeletekey
; Punkbuster42 fills in its install folder from this key (not the Electronic Arts one), and only if the folder exists.
; [Registry] is written before [Run], so the PunkBuster setup opens with the game folder already filled in
Root: HKLM32; Subkey: "SOFTWARE\EA GAMES"; Components: punkbuster; Flags: uninsdeletekeyifempty
Root: HKLM32; Subkey: "SOFTWARE\EA GAMES\Battlefield 1942"; ValueType: string; ValueName: "GAMEDIR"; ValueData: "{app}"; Components: punkbuster; Flags: uninsdeletevalue uninsdeletekeyifempty
#endif

[Icons]
Name: "{autodesktop}\Battlefield 1942"; Filename: "{app}\BF1942.exe"; Parameters: "+restart 1"; WorkingDir: "{app}"; Tasks: desktopicon and skipintro
Name: "{autodesktop}\Battlefield 1942"; Filename: "{app}\BF1942.exe"; WorkingDir: "{app}"; Tasks: desktopicon and not skipintro
#if Has_borderless1942
Name: "{autodesktop}\Battlefield 1942 (Borderless)"; Filename: "{app}\Borderless1942.exe"; Parameters: "{code:GetBorderlessParams}"; WorkingDir: "{app}"; IconFilename: "{app}\BF1942.exe"; Tasks: borderlessicon
#endif
Name: "{autoprograms}\Battlefield 1942 Options"; Filename: "{app}\Options\App\BF1942 Options.exe"; WorkingDir: "{app}"; Comment: "Turn the Battlefield 1942 fixes and extras on or off"
; Its name says what the app is for, as players see it on the desktop
Name: "{autodesktop}\Battlefield 1942 Options - turn fixes and extras on or off"; Filename: "{app}\Options\App\BF1942 Options.exe"; WorkingDir: "{app}"; Comment: "Turn the Battlefield 1942 fixes and extras on or off"; Tasks: optionsicon
#if ServerAddress != ""
; Always skips the intro and joins the configured server
Name: "{autodesktop}\{#ServerName}"; Filename: "{app}\BF1942.exe"; Parameters: "+restart 1 +joinServer {#ServerAddress}"; WorkingDir: "{app}"; Tasks: servericon
#endif

[Run]
Filename: "{sys}\dism.exe"; Parameters: "/online /enable-feature /featurename:DirectPlay /all /norestart /quiet"; StatusMsg: "Enabling Windows DirectPlay (this can take a minute)..."; Components: required\directplay; Check: IsWin64 and DirectPlayNeeded; Flags: runhidden waituntilterminated 64bit
Filename: "{sys}\dism.exe"; Parameters: "/online /enable-feature /featurename:DirectPlay /all /norestart /quiet"; StatusMsg: "Enabling Windows DirectPlay (this can take a minute)..."; Components: required\directplay; Check: (not IsWin64) and DirectPlayNeeded; Flags: runhidden waituntilterminated
Filename: "{tmp}\dxredist\DXSETUP.exe"; Parameters: "/silent"; StatusMsg: "Installing DirectX End-User Runtime (June 2010)..."; Components: required\directx; Check: DirectXNeeded; Flags: waituntilterminated
Filename: "{tmp}\VC_redist.x86.exe"; Parameters: "{code:GetVCRedistParams}"; StatusMsg: "Installing Visual C++ Redistributable (x86)..."; Components: required\vcredist; Check: VCRedistNeeded; AfterInstall: VCRedistAfterInstall; Flags: waituntilterminated
#if Has_compat
Filename: "{sys}\sdbinst.exe"; Parameters: "-q ""{app}\BF1942.sdb"""; StatusMsg: "Installing the Battlefield 1942 compatibility profile..."; Components: compat; Check: IsWin64; Flags: runhidden waituntilterminated 64bit
Filename: "{sys}\sdbinst.exe"; Parameters: "-q ""{app}\BF1942.sdb"""; StatusMsg: "Installing the Battlefield 1942 compatibility profile..."; Components: compat; Check: not IsWin64; Flags: runhidden waituntilterminated
#endif
; DataField42 is already installed in this folder (installing over an earlier install): BF1942.exe was just replaced,
; so only DataField42's patch to it, which makes the game start DataField42 for a missing map, is applied again.
; Also when this build leaves DataField42 out, as the player may have installed it there
Filename: "{app}\DataField42.exe"; Parameters: "install"; WorkingDir: "{app}"; StatusMsg: "Setting up DataField42 again..."; Check: DataField42PatchNeeded; Flags: waituntilterminated
#if Has_datafield42
Filename: "{tmp}\{#File_datafield42}"; Parameters: "/SILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=""{app}"""; StatusMsg: "Installing DataField42..."; Components: datafield; Check: DataField42SetupNeeded; AfterInstall: CloseDataField42; Flags: waituntilterminated
#endif
#if Has_richpresence
Filename: "{tmp}\{#File_dotnet8}"; Parameters: "{code:GetDotNetParams}"; StatusMsg: "Installing .NET 8 Desktop Runtime (needed by Battlefield Rich Presence)..."; Components: richpresence; Check: DotNetDesktop8Needed; AfterInstall: DotNetAfterInstall; Flags: waituntilterminated
Filename: "{sys}\msiexec.exe"; Parameters: "/i ""{tmp}\{#File_richpresence}"" /qn /norestart"; StatusMsg: "Installing Battlefield Rich Presence..."; Components: richpresence; Flags: waituntilterminated
#endif
#if Has_punkbuster42
Filename: "{tmp}\pb42\Punkbuster42.exe"; WorkingDir: "{app}"; StatusMsg: "Installing PunkBuster - please follow the PunkBuster installer (game folder: {app})..."; Components: punkbuster; Flags: waituntilterminated
; Punkbuster42 exits while its "PunkBuster Services" window (pbsvc.exe) is still open - wait for the user to finish it
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Start-Sleep -Seconds 2; Get-Process pbsvc -ErrorAction SilentlyContinue | Wait-Process"""; StatusMsg: "Finish the PunkBuster Services window (click Install/Repair, then close it) to continue..."; Components: punkbuster; Flags: runhidden waituntilterminated
#endif
Filename: "{app}\BF1942.exe"; Parameters: "{code:GetLaunchParams}"; WorkingDir: "{app}"; Description: "Launch Battlefield 1942"; Flags: postinstall nowait skipifsilent unchecked runasoriginaluser

[UninstallRun]
; Each command compares paths with the game folder as plain text ($d): -like would read [ and ] in a folder name
; as wildcards, and PSApp doubles an apostrophe in it for the quotes
; Close BF1942 Options if it is still open, so its folder can be deleted
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""$d = '{code:PSApp}\'; Get-Process 'BF1942 Options' -ErrorAction SilentlyContinue | Where-Object {{ $_.Path -and $_.Path.StartsWith($d, [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force"""; RunOnceId: "CloseOptionsApp"; Flags: runhidden waituntilterminated
#if Has_punkbuster42
; Close any PunkBuster setup window still running from the game folder so its pbsvc.exe can be deleted
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""$d = '{code:PSApp}\'; Get-Process pbsvc -ErrorAction SilentlyContinue | Where-Object {{ $_.Path -and $_.Path.StartsWith($d, [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force"""; RunOnceId: "ClosePunkBusterSetup"; Components: punkbuster; Flags: runhidden waituntilterminated
#endif
; Remove Windows Firewall rules that Windows created for programs in the game folder (bf1942.exe, dedicated server, pbsvc.exe...)
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""$d = '{code:PSApp}\'; Get-NetFirewallApplicationFilter | Where-Object {{ $_.Program -and $_.Program.StartsWith($d, [StringComparison]::OrdinalIgnoreCase) } | Get-NetFirewallRule | Remove-NetFirewallRule"""; RunOnceId: "RemoveFirewallRules64"; Check: IsWin64; Flags: runhidden waituntilterminated 64bit
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""$d = '{code:PSApp}\'; Get-NetFirewallApplicationFilter | Where-Object {{ $_.Program -and $_.Program.StartsWith($d, [StringComparison]::OrdinalIgnoreCase) } | Get-NetFirewallRule | Remove-NetFirewallRule"""; RunOnceId: "RemoveFirewallRules32"; Check: not IsWin64; Flags: runhidden waituntilterminated

[InstallDelete]
; Installing over an earlier install: the files of the graphics fix that is not being installed go first, so
; DXVK's d3d9.dll and dxvk.conf don't stay next to dgVoodoo2, or dgVoodoo.conf next to DXVK (d3d8.dll is replaced)
Type: files; Name: "{app}\d3d9.dll"; Check: not UseDXVK
Type: files; Name: "{app}\dxvk.conf"; Check: not UseDXVK
Type: files; Name: "{app}\dgVoodoo.conf"; Check: UseDXVK

[UninstallDelete]
; Remove everything in the install folder, including files the game/tools created after install - unless the folder
; held something else than a game before Setup ran (see FolderIsGameFolder): then only what Setup installed goes
Type: filesandordirs; Name: "{app}"; Check: FolderIsGameFolder
; BF1942 Options creates this shortcut when Borderless1942 is turned on after install
Type: files; Name: "{autodesktop}\Battlefield 1942 (Borderless).lnk"

[Code]
const
  SerialChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  UninstallKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall';
  StateKey = '{#StateKey}';
  ErgcKey = 'SOFTWARE\Electronic Arts\EA GAMES\Battlefield 1942\ergc';
  PBGameKey = 'Punkbuster for Battlefield 1942';
  PBServicesKey = 'PunkBusterSvc';
  DataField42Key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DataField42_is1';   { its AppId is DataField42 }

var
  Serial: String;
  SerialIsNew: Boolean;
  RendererDetected, DxvkSupported: Boolean;
  RendererInfo: String;
  VCChecked, VCNeeded, VCRepair: Boolean;
  DPChecked, DPNeeded: Boolean;
  DXChecked, DXNeeded: Boolean;
  DNChecked, DNNeeded, DNRepair: Boolean;

function GetSystemMetrics(nIndex: Integer): Integer;
  external 'GetSystemMetrics@user32.dll stdcall';
function GetTickCount: DWORD;
  external 'GetTickCount@kernel32.dll stdcall';
function GetDC(hWnd: HWND): HDC;
  external 'GetDC@user32.dll stdcall';
function ReleaseDC(hWnd: HWND; hDC: HDC): Integer;
  external 'ReleaseDC@user32.dll stdcall';
function GetDeviceCaps(hDC: HDC; nIndex: Integer): Integer;
  external 'GetDeviceCaps@gdi32.dll stdcall';

const
  VREFRESH = 116;        { refresh rate of the primary monitor }
  DESKTOPVERTRES = 117;  { real (unscaled) height of the primary monitor }
  DESKTOPHORZRES = 118;  { real (unscaled) width of the primary monitor }

{ Primary monitor resolution in real pixels (not affected by Windows display scaling) and refresh rate }
procedure GetPrimaryDisplay(var Width, Height, Refresh: Integer);
var
  DC: HDC;
begin
  DC := GetDC(0);
  Width := GetDeviceCaps(DC, DESKTOPHORZRES);
  Height := GetDeviceCaps(DC, DESKTOPVERTRES);
  Refresh := GetDeviceCaps(DC, VREFRESH);
  ReleaseDC(0, DC);
  if (Width <= 0) or (Height <= 0) then begin
    Width := GetSystemMetrics(0);
    Height := GetSystemMetrics(1);
  end;
  { 0 or 1 means "hardware default" - fall back to 60 Hz }
  if Refresh <= 1 then Refresh := 60;
end;

{ ---------- Serial ---------- }

function GenerateSerial: String;
var
  I, Mix: Integer;
begin
  Result := '';
  Mix := GetTickCount mod 36;
  for I := 1 to 22 do
    Result := Result + SerialChars[((Random(36) + Mix * I) mod 36) + 1];
end;

function IsValidSerial(const S: String): Boolean;
var
  I: Integer;
begin
  Result := Length(S) = 22;
  if Result then
    for I := 1 to 22 do
      if Pos(Uppercase(S[I]), SerialChars) = 0 then begin
        Result := False;
        Exit;
      end;
end;

{ Reuse a valid serial that is already registered, otherwise generate one }
procedure InitSerial;
var
  Existing: String;
begin
  if RegQueryStringValue(HKLM32, ErgcKey, '', Existing) and IsValidSerial(Trim(Existing)) then begin
    Serial := Trim(Existing);
    SerialIsNew := False;
    Log('Existing serial found in registry - keeping it.');
  end else begin
    Serial := GenerateSerial;
    SerialIsNew := True;
    Log('No valid serial found in registry - generated a new one.');
  end;
end;

function IsNewSerial: Boolean;
begin
  Result := SerialIsNew;
end;

function GetSerial(Param: String): String;
begin
  Result := Serial;
end;

{ ---------- DXVK / dgVoodoo2 detection ---------- }

function SameFileContent(const A, B: String): Boolean;
begin
  Result := FileExists(A) and FileExists(B) and (GetSHA256OfFile(A) = GetSHA256OfFile(B));
end;

{ The game folder runs dgVoodoo2 now (picked in BF1942 Options, or by an earlier Setup) }
function DgVoodooInstalled: Boolean;
begin
  Result := SameFileContent(ExpandConstant('{app}\d3d8.dll'), ExpandConstant('{app}\Options\dgVoodoo2\D3D8.dll'));
end;

var
  RendererFor: String;                 { the folder the renderer was picked for }
  VulkanChecked, VulkanDxvk: Boolean;  { the graphics card check, which runs (and may ask) only once }
  VulkanInfo: String;

{ Once per folder: going back and picking another folder, which may or may not run dgVoodoo2, decides again }
procedure DetectRenderer;
var
  Forced: String;
  Output: TExecOutput;
  Code, I: Integer;
  CheckFailed: Boolean;
begin
  if RendererDetected and PathSame(RendererFor, WizardDirValue) then Exit;
  RendererDetected := True;
  RendererFor := WizardDirValue;
  DxvkSupported := False;
  RendererInfo := '';

  { Optional override: Setup.exe /RENDERER=dxvk  or  /RENDERER=dgvoodoo }
  Forced := Lowercase(ExpandConstant('{param:RENDERER|auto}'));
  if Forced = 'dxvk' then begin
    DxvkSupported := True;
    RendererInfo := 'Forced by /RENDERER=dxvk';
  end else if Forced = 'dgvoodoo' then
    RendererInfo := 'Forced by /RENDERER=dgvoodoo'
  else if DgVoodooInstalled then
    { Installing over a game that runs dgVoodoo2 keeps it: someone picked it in BF1942 Options, or an earlier Setup
      did, and switching to DXVK by itself could bring a black screen back. Over DXVK the check runs again, so a
      card that can't run it (such as an AMD RX 400/500) still gets dgVoodoo2. }
    RendererInfo := 'dgVoodoo2 kept: the game folder already runs it (BF1942 Options switches it)' + #13#10
  else if VulkanChecked then begin
    DxvkSupported := VulkanDxvk;
    RendererInfo := VulkanInfo;
  end else begin
    { Only exit code 1 means the GPU can't run DXVK. If the check itself fails (often an
      antivirus blocking VulkanCheck.exe) the answer is unknown, so the user picks instead }
    CheckFailed := True;
    try
      ExtractTemporaryFile('VulkanCheck.exe');
      if ExecAndCaptureOutput(ExpandConstant('{tmp}\VulkanCheck.exe'), '', '', SW_HIDE,
                              ewWaitUntilTerminated, Code, Output) then begin
        DxvkSupported := (Code = 0);
        CheckFailed := (Code <> 0) and (Code <> 1);
        for I := 0 to GetArrayLength(Output.StdOut) - 1 do
          if Trim(Output.StdOut[I]) <> '' then
            RendererInfo := RendererInfo + Trim(Output.StdOut[I]) + #13#10;
      end else
        RendererInfo := 'Vulkan check could not run: ' + SysErrorMessage(Code);
    except
      RendererInfo := 'Vulkan check failed: ' + GetExceptionMessage;
    end;

    if CheckFailed then begin
      { Most PCs today run DXVK, so it is the default (also for silent installs) }
      DxvkSupported := SuppressibleMsgBox('Setup could not check whether this PC''s graphics card can run DXVK:' + #13#10 +
        Trim(RendererInfo) + #13#10#13#10 +
        'This is usually caused by antivirus software blocking Setup''s files. If it also blocks other files, ' +
        'add an exclusion for this setup file and the game folder, then run Setup again.' + #13#10#13#10 +
        'Install DXVK (recommended for most graphics cards from 2016 or later)?' + #13#10 +
        'Choose No to install dgVoodoo2 instead.', mbConfirmation, MB_YESNO, IDYES) = IDYES;
      if DxvkSupported then
        RendererInfo := RendererInfo + 'DXVK chosen because the Vulkan check failed' + #13#10
      else
        RendererInfo := RendererInfo + 'dgVoodoo2 chosen because the Vulkan check failed' + #13#10;
    end;
    VulkanChecked := True;
    VulkanDxvk := DxvkSupported;
    VulkanInfo := RendererInfo;
  end;
  Log('Renderer detection: DXVK supported = ' + IntToStr(Ord(DxvkSupported)) + #13#10 + RendererInfo);
end;

function UseDXVK: Boolean;
begin
  DetectRenderer;
  Result := DxvkSupported;
end;

function GetRendererName(Param: String): String;
begin
  if UseDXVK then Result := 'DXVK {#Ver_dxvk}' else Result := 'dgVoodoo2 {#Ver_dgvoodoo2}';
end;

{ ---------- Visual C++ ---------- }

{ The registry entry can outlive the DLLs (a "cleaner" tool, a broken uninstall or a failed
  update), so the 32-bit runtime files must also be present before the install is skipped }
function VCRuntimeFilesPresent: Boolean;
begin
  Result := FileExists(ExpandConstant('{syswow64}\msvcp140.dll')) and
            FileExists(ExpandConstant('{syswow64}\vcruntime140.dll'));
end;

function VCRedistNeeded: Boolean;
var
  Installed, Major, Minor, Bld: Cardinal;
  Required: Int64;
begin
  if not VCChecked then begin
    VCChecked := True;
    VCNeeded := True;
    VCRepair := False;
    if RegQueryDWordValue(HKLM32, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86', 'Installed', Installed) and (Installed = 1) and
       RegQueryDWordValue(HKLM32, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86', 'Major', Major) and
       RegQueryDWordValue(HKLM32, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86', 'Minor', Minor) and
       RegQueryDWordValue(HKLM32, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86', 'Bld', Bld) and
       StrToVersion('{#VCVer}', Required) then begin
      VCNeeded := ComparePackedVersion(PackVersionComponents(Major, Minor, Bld, 0), Required) < 0;
      { Registered as current but the DLLs are gone: /install would be a no-op, so repair instead }
      if (not VCNeeded) and (not VCRuntimeFilesPresent) then begin
        VCNeeded := True;
        VCRepair := True;
      end;
    end;
    Log('Visual C++ x86 runtime install needed: ' + IntToStr(Ord(VCNeeded)) + ', repair: ' + IntToStr(Ord(VCRepair)));
  end;
  Result := VCNeeded;
end;

function GetVCRedistParams(Param: String): String;
begin
  if VCRepair then Result := '/repair /quiet /norestart' else Result := '/install /quiet /norestart';
end;

procedure VCRedistAfterInstall;
begin
  if not VCRuntimeFilesPresent then begin
    Log('Visual C++ x86 runtime files are still missing after running the redistributable');
    SuppressibleMsgBox('The Visual C++ Redistributable (x86) could not restore its files (msvcp140.dll and vcruntime140.dll), so Battlefield 1942 will not start yet.' + #13#10#13#10 +
      'To fix this, open Settings > Apps > Installed apps, find "Microsoft Visual C++ Redistributable (x86)", choose Modify and then Repair. ' +
      'You can also reinstall it from https://aka.ms/vs/17/release/vc_redist.x86.exe', mbError, MB_OK, IDOK);
  end;
end;

{ ---------- DirectPlay ---------- }

{ Win32_OptionalFeature.InstallState: 1 = Enabled, 2 = Disabled, 3 = Absent }
function DirectPlayNeeded: Boolean;
var
  Locator, Service, Items: Variant;
begin
  if not DPChecked then begin
    DPChecked := True;
    DPNeeded := True;
    try
      Locator := CreateOleObject('WbemScripting.SWbemLocator');
      Service := Locator.ConnectServer('.', 'root\CIMV2');
      Items := Service.ExecQuery('SELECT InstallState FROM Win32_OptionalFeature WHERE Name = ''DirectPlay''');
      if Items.Count > 0 then
        DPNeeded := (Items.ItemIndex(0).InstallState <> 1);
    except
      Log('DirectPlay state query failed, will run DISM: ' + GetExceptionMessage);
    end;
    Log('DirectPlay enable needed: ' + IntToStr(Ord(DPNeeded)));
  end;
  Result := DPNeeded;
end;

{ ---------- DirectX (June 2010) ---------- }

{ The June 2010 runtime is present when its newest 32-bit DLLs are in SysWOW64 (System32 on 32-bit Windows) }
function DirectXNeeded: Boolean;
var
  Files: TArrayOfString;
  I: Integer;
begin
  if not DXChecked then begin
    DXChecked := True;
    DXNeeded := False;
    Files := ['d3dx9_43.dll', 'd3dx10_43.dll', 'd3dx11_43.dll', 'D3DCompiler_43.dll',
              'd3dcsx_43.dll', 'xinput1_3.dll', 'XAudio2_7.dll', 'X3DAudio1_7.dll', 'XAPOFX1_5.dll'];
    for I := 0 to GetArrayLength(Files) - 1 do
      if not FileExists(ExpandConstant('{syswow64}\') + Files[I]) then begin
        Log('DirectX June 2010 file missing: ' + Files[I]);
        DXNeeded := True;
      end;
    Log('DirectX June 2010 install needed: ' + IntToStr(Ord(DXNeeded)));
  end;
  Result := DXNeeded;
end;

{ ---------- .NET 8 Desktop Runtime (x64) ---------- }

{ An uninstall or a "cleaner" tool can leave empty version folders behind, so a version only
  counts when its files are there: the .NET host (hostfxr.dll) plus both shared frameworks }
function DotNetHostPresent: Boolean;
var
  FR: TFindRec;
  Dir: String;
begin
  Result := False;
  Dir := ExpandConstant('{commonpf64}\dotnet\host\fxr\');
  if FindFirst(Dir + '*', FR) then
    try
      repeat
        if (FR.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0) and (FR.Name <> '.') and (FR.Name <> '..') and
           FileExists(Dir + FR.Name + '\hostfxr.dll') then
          Result := True;
      until Result or (not FindNext(FR));
    finally
      FindClose(FR);
    end;
end;

function DotNetDesktopVersionComplete(const Ver: String): Boolean;
var
  Shared: String;
begin
  Shared := ExpandConstant('{commonpf64}\dotnet\shared\');
  Result := FileExists(Shared + 'Microsoft.WindowsDesktop.App\' + Ver + '\Microsoft.WindowsDesktop.App.deps.json') and
            FileExists(Shared + 'Microsoft.NETCore.App\' + Ver + '\Microsoft.NETCore.App.deps.json');
  if not Result then
    Log('.NET Desktop Runtime ' + Ver + ' folder is incomplete');
end;

{ x64 only - call on 64-bit Windows }
function DotNetDesktop8Present: Boolean;
var
  FR: TFindRec;
begin
  Result := False;
  if DotNetHostPresent and FindFirst(ExpandConstant('{commonpf64}\dotnet\shared\Microsoft.WindowsDesktop.App\8.0.*'), FR) then
    try
      repeat
        if (FR.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0) and DotNetDesktopVersionComplete(FR.Name) then
          Result := True;
      until Result or (not FindNext(FR));
    finally
      FindClose(FR);
    end;
end;

function DotNetDesktop8Needed: Boolean;
begin
  if not DNChecked then begin
    DNChecked := True;
    DNNeeded := False;
    DNRepair := False;
    if IsWin64 then begin
      DNNeeded := not DotNetDesktop8Present;
      { The bundled version is registered but its files are gone: /install would be a no-op, so repair instead }
      if DNNeeded then
        DNRepair := RegValueExists(HKLM32, 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App', '{#DotNetVer}') or
                    RegValueExists(HKLM64, 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App', '{#DotNetVer}');
    end;
    Log('.NET 8 Desktop Runtime install needed: ' + IntToStr(Ord(DNNeeded)) + ', repair: ' + IntToStr(Ord(DNRepair)));
  end;
  Result := DNNeeded;
end;

function GetDotNetParams(Param: String): String;
begin
  if DNRepair then Result := '/repair /quiet /norestart' else Result := '/install /quiet /norestart';
end;

procedure DotNetAfterInstall;
begin
  if not DotNetDesktop8Present then begin
    Log('.NET 8 Desktop Runtime is still incomplete after running its installer');
    SuppressibleMsgBox('The .NET 8 Desktop Runtime (x64) could not be installed correctly, so Battlefield Rich Presence may not start.' + #13#10#13#10 +
      'To fix this, open Settings > Apps > Installed apps, find "Microsoft Windows Desktop Runtime - 8.0 (x64)", choose Modify and then Repair. ' +
      'You can also reinstall it from https://dotnet.microsoft.com/download/dotnet/8.0', mbError, MB_OK, IDOK);
  end;
end;

{ ---------- Misc helpers ---------- }

function GetLaunchParams(Param: String): String;
begin
  if WizardIsTaskSelected('skipintro') then Result := '+restart 1' else Result := '';
end;

{ Borderless1942 shortcut: primary monitor resolution, plus +restart 1 when "Skip intro" is ticked }
function GetBorderlessParams(Param: String): String;
var
  W, H, R: Integer;
begin
  GetPrimaryDisplay(W, H, R);
  Result := Format('-width %d -height %d', [W, H]);
  if WizardIsTaskSelected('skipintro') then
    Result := Result + ' +restart 1';
end;

{ Replace every line starting with Prefix by NewLine }
procedure SetConLine(const FileName, Prefix, NewLine: String);
var
  Lines: TArrayOfString;
  I: Integer;
begin
  if not LoadStringsFromFile(FileName, Lines) then Exit;
  for I := 0 to GetArrayLength(Lines) - 1 do
    if Pos(Lowercase(Prefix), Lowercase(Trim(Lines[I]))) = 1 then
      Lines[I] := NewLine;
  SaveStringsToFile(FileName, Lines, False);
end;

{ Sets game.setGameDisplayMode in every Video*.con under Dir (recursively) }
procedure SetDisplayModeInDir(const Dir, Mode: String);
var
  FR: TFindRec;
begin
  if FindFirst(Dir + '\*', FR) then
    try
      repeat
        if (FR.Name <> '.') and (FR.Name <> '..') then begin
          if FR.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then
            SetDisplayModeInDir(Dir + '\' + FR.Name, Mode)
          else if (CompareText(Copy(FR.Name, 1, 5), 'Video') = 0) and
                  (CompareText(ExtractFileExt(FR.Name), '.con') = 0) then begin
            SetConLine(Dir + '\' + FR.Name, 'game.setGameDisplayMode', Mode);
          end;
        end;
      until not FindNext(FR);
    finally
      FindClose(FR);
    end;
end;

{ Always: game resolution/refresh = primary monitor, 32-bit colour }
procedure ConfigureDisplayMode;
var
  W, H, R: Integer;
  Mode: String;
begin
  GetPrimaryDisplay(W, H, R);
  Mode := Format('game.setGameDisplayMode %d %d 32 %d', [W, H, R]);
  SetDisplayModeInDir(ExpandConstant('{app}\Mods'), Mode);
  Log('Display mode set in Video*.con files: ' + Mode);
end;

{ Only with Borderless1942: the game must run windowed }
procedure ConfigureBorderless;
begin
  SetConLine(ExpandConstant('{app}\Mods\bf1942\Settings\VideoDefault.con'),
             'renderer.setFullScreen', 'renderer.setFullScreen 0');
  Log('Borderless1942: renderer.setFullScreen 0');
end;

{ Without Borderless1942 the game runs fullscreen. Setup keeps the game's settings files when it installs over an
  earlier install, so a windowed VideoDefault.con from before is set back here }
procedure ConfigureFullscreen;
begin
  SetConLine(ExpandConstant('{app}\Mods\bf1942\Settings\VideoDefault.con'),
             'renderer.setFullScreen', 'renderer.setFullScreen 1');
end;

{ Finds an installed program in Apps & features whose name contains NamePart.
  KeyName = its uninstall key (the ProductCode for MSI installs), Cmd = its UninstallString }
function FindUninstallEntry(const NamePart: String; var KeyName, Cmd: String): Boolean;
var
  Roots: array of Integer;
  Names: TArrayOfString;
  R, I: Integer;
  DisplayName, Uninst: String;
begin
  Result := False;
  if IsWin64 then Roots := [HKLM64, HKLM32, HKCU] else Roots := [HKLM32, HKCU];
  for R := 0 to GetArrayLength(Roots) - 1 do
    if RegGetSubkeyNames(Roots[R], UninstallKey, Names) then
      for I := 0 to GetArrayLength(Names) - 1 do
        if RegQueryStringValue(Roots[R], UninstallKey + '\' + Names[I], 'DisplayName', DisplayName) and
           (Pos(Lowercase(NamePart), Lowercase(DisplayName)) > 0) and
           RegQueryStringValue(Roots[R], UninstallKey + '\' + Names[I], 'UninstallString', Uninst) then begin
          KeyName := Names[I];
          Cmd := RemoveQuotes(Uninst);
          Result := True;
          Exit;
        end;
end;

{ ---------- DataField42 ---------- }

{ DataField42 is installed for one game folder per PC. Run again, its installer stops with a message box that
  /SUPPRESSMSGBOXES doesn't hide, which would hold up a silent install, so Setup checks first }

{ The game folder DataField42 is installed in, or '' when it isn't installed }
function DataField42Dir: String;
var
  Dir: String;
begin
  Result := '';
  if RegQueryStringValue(HKLM32, DataField42Key, 'Inno Setup: App Path', Dir) or
     RegQueryStringValue(HKCU, DataField42Key, 'Inno Setup: App Path', Dir) then
    Result := RemoveBackslashUnlessRoot(Dir);
end;

{ DataField42 is installed in this game folder, by an earlier install or by the player }
function DataField42Here: Boolean;
begin
  Result := PathSame(DataField42Dir, ExpandConstant('{app}'));
end;

function DataField42SetupNeeded: Boolean;
begin
  Result := DataField42Dir = '';
  if not Result then
    Log('DataField42 is already installed for ' + DataField42Dir + ' - its installer is skipped');
end;

{ Installing over a game folder with DataField42: BF1942.exe was just replaced, so DataField42's patch to it, which
  makes the game start DataField42 when a map or mod is missing, is applied again (what its installer does) }
function DataField42PatchNeeded: Boolean;
begin
  { DataField42 is a 64-bit program }
  Result := IsWin64 and DataField42Here and FileExists(ExpandConstant('{app}\DataField42.exe'));
end;

function FindDataField42Uninstaller(var Cmd: String): Boolean;
begin
  Result := RegQueryStringValue(HKLM32, DataField42Key, 'UninstallString', Cmd) or
            RegQueryStringValue(HKCU, DataField42Key, 'UninstallString', Cmd);
  Cmd := RemoveQuotes(Cmd);
end;

{ Whether DataField42 runs from this game folder; with Close, it is ended as well }
function DataField42Running(Close: Boolean): Boolean;
var
  Locator, Service, Items, Value: Variant;
  Path: String;
  I, Pid, Code: Integer;
begin
  Result := False;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('.', 'root\CIMV2');
    Items := Service.ExecQuery('SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name = ''DataField42.exe''');
    for I := 0 to Items.Count - 1 do begin
      Value := Items.ItemIndex(I).ExecutablePath;
      if not VarIsNull(Value) then begin
        Path := Value;
        if PathSame(Path, ExpandConstant('{app}\DataField42.exe')) then begin
          Result := True;
          if Close then begin
            Pid := Items.ItemIndex(I).ProcessId;
            Log('Closing DataField42 (process ' + IntToStr(Pid) + ')');
            Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /PID ' + IntToStr(Pid), '', SW_HIDE, ewWaitUntilTerminated, Code);
          end;
        end;
      end;
    end;
  except
    Log('Could not look for DataField42: ' + GetExceptionMessage);
  end;
end;

{ DataField42's installer starts DataField42 when it finishes, also when silent, and as administrator, as it runs
  from this setup - a game joined from it would run as administrator too. The game starts DataField42 by itself
  when a map or mod is missing, so it is closed. Also before DataField42 is uninstalled, so its files can go }
procedure CloseDataField42;
var
  Tries: Integer;
begin
  if not DataField42Running(True) then Exit;
  { taskkill returns before the process is gone }
  Tries := 0;
  while DataField42Running(False) and (Tries < 20) do begin
    Sleep(250);
    Tries := Tries + 1;
  end;
end;

{ ---------- Installing over an earlier install ---------- }

{ The game folder for a single-quoted PowerShell string ([UninstallRun]): an apostrophe in its name is doubled,
  also a typographic one, which PowerShell reads as a quote too }
function PSApp(Param: String): String;
begin
  Result := ExpandConstant('{app}');
  StringChangeEx(Result, '''', '''''', True);
  StringChangeEx(Result, #$2018, #$2018#$2018, True);
  StringChangeEx(Result, #$2019, #$2019#$2019, True);
  StringChangeEx(Result, #$201A, #$201A#$201A, True);
  StringChangeEx(Result, #$201B, #$201B#$201B, True);
end;

{ /COMPONENTS on the command line deselects every font it doesn't list, and the game's own Font.rfa is never
  copied, so the game would have no font at all: the default font is installed then, if there is none }
function NoFontSelected: Boolean;
begin
  Result := True;
#if Has_font_original
  if WizardIsComponentSelected('font\original') then Result := False;
#endif
#if Has_font_1x
  if WizardIsComponentSelected('font\x1') then Result := False;
#endif
#if Has_font_2x
  if WizardIsComponentSelected('font\x2') then Result := False;
#endif
#if Has_font_3x
  if WizardIsComponentSelected('font\x3') then Result := False;
#endif
#if Has_font_35x
  if WizardIsComponentSelected('font\x35') then Result := False;
#endif
#if Has_font_4x
  if WizardIsComponentSelected('font\x4') then Result := False;
#endif
  if Result then Log('No font selected - installing the {#DefaultFontDir} font if the game folder has none');
end;

{ Already installed in another folder: Setup has one entry in Apps, which the new folder takes over, and the old
  folder stays behind with its own copy of the game }
function ConfirmSecondInstall: Boolean;
var
  Prev: String;
begin
  Result := True;
  Prev := RemoveBackslashUnlessRoot(WizardForm.PrevAppDir);
  if (Prev = '') or PathSame(Prev, WizardDirValue) or not DirExists(Prev) then Exit;
  Log('Already installed in ' + Prev + ' - now installing to ' + WizardDirValue);
  if not WizardSilent then
    Result := MsgBox('Battlefield 1942 is already installed in:' + #13#10 + Prev + #13#10#13#10 +
      'Installing to another folder adds a second copy of the game. The first copy stays, but it can no longer ' +
      'be uninstalled from Settings > Apps.' + #13#10#13#10 +
      'To move the game, click No, uninstall it, and run Setup again. Install a second copy anyway?',
      mbConfirmation, MB_YESNO) = IDYES;
end;

{ Installing over a game folder: the font, the extras and the skip-intro choice start as they are in the folder now,
  so running Setup again doesn't undo what was changed in BF1942 Options since (the renderer: DetectRenderer).
  /COMPONENTS and /TASKS on the command line still decide. The required fixes, BF42++ and 3D audio, are always put
  back: they are what Setup is run again for. }
var
  SelectedFor: String;   { the folder the component list was last set up for }

procedure SelectFromGameFolder;
var
  Lib, Archives, Value: String;
  Found: Boolean;
begin
  { Once per folder, so going back to the folder page doesn't undo changes made on the components page }
  if PathSame(SelectedFor, WizardDirValue) then Exit;
  SelectedFor := WizardDirValue;
  Lib := AddBackslash(WizardDirValue) + 'Options\';
  Archives := AddBackslash(WizardDirValue) + 'Mods\bf1942\Archives\';
  if not DirExists(Lib) then Exit;
  if ExpandConstant('{param:COMPONENTS|}') = '' then begin
    Found := False;
#if Has_font_original
    if not Found and SameFileContent(Archives + 'Font.rfa', Lib + 'Fonts\Original\Font.rfa') then begin
      WizardSelectComponents('font\original');
      Found := True;
    end;
#endif
#if Has_font_1x
    if not Found and SameFileContent(Archives + 'Font.rfa', Lib + 'Fonts\1x\Font.rfa') then begin
      WizardSelectComponents('font\x1');
      Found := True;
    end;
#endif
#if Has_font_2x
    if not Found and SameFileContent(Archives + 'Font.rfa', Lib + 'Fonts\2x\Font.rfa') then begin
      WizardSelectComponents('font\x2');
      Found := True;
    end;
#endif
#if Has_font_3x
    if not Found and SameFileContent(Archives + 'Font.rfa', Lib + 'Fonts\3x\Font.rfa') then begin
      WizardSelectComponents('font\x3');
      Found := True;
    end;
#endif
#if Has_font_35x
    if not Found and SameFileContent(Archives + 'Font.rfa', Lib + 'Fonts\3.5x\Font.rfa') then begin
      WizardSelectComponents('font\x35');
      Found := True;
    end;
#endif
#if Has_font_4x
    if not Found and SameFileContent(Archives + 'Font.rfa', Lib + 'Fonts\4x\Font.rfa') then begin
      WizardSelectComponents('font\x4');
      Found := True;
    end;
#endif
#if Has_hiresui
    if FileExists(Lib + 'Higher resolution UI\menu.rfa') then begin
      if SameFileContent(Archives + 'menu.rfa', Lib + 'Higher resolution UI\menu.rfa') then
        WizardSelectComponents('hiresui')
      else
        WizardSelectComponents('!hiresui');
    end;
#endif
#if Has_bobsiren
    if FileExists(Lib + 'Battle of Britain disable siren\Battle_of_Britain.rfa') then begin
      if SameFileContent(Archives + 'bf1942\levels\Battle_of_Britain.rfa', Lib + 'Battle of Britain disable siren\Battle_of_Britain.rfa') then
        WizardSelectComponents('bobsiren')
      else
        WizardSelectComponents('!bobsiren');
    end;
#endif
    { Without these, Setup would install them again from the components picked last time }
#if Has_borderless1942
    if IsWin64 then begin
      if FileExists(AddBackslash(WizardDirValue) + 'Borderless1942.exe') then
        WizardSelectComponents('borderless')
      else
        WizardSelectComponents('!borderless');
    end;
#endif
#if Has_compat
    if FileExists(AddBackslash(WizardDirValue) + 'BF1942.sdb') then
      WizardSelectComponents('compat')
    else
      WizardSelectComponents('!compat');
#endif
    Log('Components as the game folder has them: ' + WizardSelectedComponents(False));
  end;
  if (ExpandConstant('{param:TASKS|}') = '') and (ExpandConstant('{param:MERGETASKS|}') = '') and
     RegQueryStringValue(HKLM32, StateKey, 'SkipIntro', Value) then begin
    if Value = '1' then WizardSelectTasks('skipintro') else WizardSelectTasks('!skipintro');
    Log('Skip intro as the game folder has it: ' + Value);
  end;
end;

{ ---------- Wizard ---------- }

var
  RichPresenceBefore: Boolean;

function InitializeSetup: Boolean;
var
  KeyName, Cmd: String;
begin
  InitSerial;
  { Battlefield Rich Presence that was there before this setup ran is the player's (it serves other Battlefield
    games too), so the uninstaller leaves it }
  RichPresenceBefore := FindUninstallEntry('battlefield rich presence', KeyName, Cmd);
  Result := True;
end;

function RichPresenceIsNew: Boolean;
begin
  Result := not RichPresenceBefore;
end;

{ One line of the RTF credits text }
function L(const S: String): String;
begin
  Result := S + '\par' + #13#10;
end;

{ Bold section header }
function H(const S: String): String;
begin
  Result := L('\b ' + S + '\b0');
end;

{ ---------- Install folder ---------- }

{ Optionally (appendEAGamesFolder) always install to <chosen folder>\EA Games\Battlefield 1942,
  e.g. C:\Temp -> C:\Temp\EA Games\Battlefield 1942 }
function EndsWithDir(const Path, Tail: String): Boolean;
begin
  Result := PathEndsWith(Path, '\' + Tail, True);
end;

{ True for a last folder named "Battlefield 1942" or starting with it, such as "Battlefield 1942-Test" }
function IsGameFolderName(const Name: String): Boolean;
begin
  Result := CompareText(Copy(Name, 1, Length('Battlefield 1942')), 'Battlefield 1942') = 0;
end;

function NormalizeInstallDir(Dir: String): String;
begin
  Dir := RemoveBackslashUnlessRoot(Trim(Dir));
  if IsGameFolderName(ExtractFileName(Dir)) and EndsWithDir(ExtractFileDir(Dir), 'EA Games') then
    Result := Dir
  else if IsGameFolderName(ExtractFileName(Dir)) then
    Result := PathCombine(ExtractFileDir(Dir), 'EA Games\' + ExtractFileName(Dir))
  else if EndsWithDir(Dir, 'EA Games') then
    Result := PathCombine(Dir, 'Battlefield 1942')
  else
    Result := PathCombine(Dir, 'EA Games\Battlefield 1942');
end;

var
  InstallDirHint: TNewStaticText;

{ Shows the folder the game will really end up in, so the rule is visible while typing }
procedure UpdateInstallDirHint;
var
  Current: String;
begin
  if InstallDirHint = nil then Exit;
  Current := Trim(WizardForm.DirEdit.Text);
  if Current = '' then
    InstallDirHint.Caption := ''
  else
    InstallDirHint.Caption := 'Will install to:  ' + NormalizeInstallDir(Current);
end;

procedure DirEditChange(Sender: TObject);
begin
  UpdateInstallDirHint;
end;

{ Applies the folder rule to the folder box on the Select Destination Location page }
procedure ApplyInstallDirRule;
var
  Current, Fixed: String;
begin
  Current := Trim(WizardForm.DirEdit.Text);
  if Current = '' then Exit;
  Fixed := NormalizeInstallDir(Current);
  if WizardForm.DirEdit.Text <> Fixed then begin
    Log('Install folder adjusted: ' + WizardForm.DirEdit.Text + ' -> ' + Fixed);
    WizardForm.DirEdit.Text := Fixed;
  end;
  UpdateInstallDirHint;
end;

{ Browse... : the picked folder is the parent, so C:\Temp shows as C:\Temp\EA Games\Battlefield 1942 right away }
procedure DirBrowseButtonClick(Sender: TObject);
var
  Dir: String;
begin
  { Start in the deepest folder of the current path that exists }
  Dir := RemoveBackslashUnlessRoot(Trim(WizardForm.DirEdit.Text));
  while (Dir <> '') and not DirExists(Dir) and not PathSame(Dir, ExtractFileDir(Dir)) do
    Dir := ExtractFileDir(Dir);
  if BrowseForFolder(SetupMessage(msgBrowseDialogTitle), Dir, True) then begin
    WizardForm.DirEdit.Text := Dir;
    ApplyInstallDirRule;
  end;
end;

{ A typed folder gets the rule as soon as the user leaves the box }
procedure DirEditExit(Sender: TObject);
begin
  ApplyInstallDirRule;
end;

procedure HookInstallDirPage;
begin
#if AppendEAGames
  WizardForm.DirBrowseButton.OnClick := @DirBrowseButtonClick;
  WizardForm.DirEdit.OnExit := @DirEditExit;
  WizardForm.DirEdit.OnChange := @DirEditChange;
  InstallDirHint := TNewStaticText.Create(WizardForm);
  InstallDirHint.Parent := WizardForm.DirEdit.Parent;
  InstallDirHint.Left := WizardForm.DirEdit.Left;
  InstallDirHint.Top := WizardForm.DirEdit.Top + WizardForm.DirEdit.Height + ScaleY(8);
  InstallDirHint.Width := WizardForm.DirBrowseButton.Left + WizardForm.DirBrowseButton.Width - WizardForm.DirEdit.Left;
  InstallDirHint.AutoSize := False;
  InstallDirHint.WordWrap := True;
  InstallDirHint.Height := WizardForm.DiskSpaceLabel.Height * 3;
  InstallDirHint.ShowAccelChar := False;
  UpdateInstallDirHint;
#endif
end;


procedure InitializeWizard;
var
  Page: TOutputMsgMemoWizardPage;
  S: String;
begin
  WizardForm.Caption := '{#InstallerTitle}';
  HookInstallDirPage;
  Page := CreateOutputMsgMemoPage(wpWelcome,
    'Readme & Credits',
    'Please read the following information before continuing.',
    'This installer bundles the work of these developers - all credit goes to them:',
    '');
  { RTF so the section headers can be bold. Layout: header, items separated by a blank line,
    one blank line between sections. }
  S := '{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Segoe UI;}}\f0\fs18' + #13#10 +
    H(Uppercase('{#InstallerTitle}'));
#if CreatedBy != ""
  S := S + H('Created by {#CreatedBy}');
#endif
  S := S + L('') +
    L('Battlefield 1942, The Road to Rome and Secret Weapons of WWII') +
    L('  (c) DICE / Electronic Arts.') +
    L('') +
    H('REQUIRED FIXES (always installed)') +
    L('  BF42++ {#Ver_bf42pp} - developed by Casqade') +
    L('    {#Url_bf42pp}') +
    L('') +
    L('  DXVK {#Ver_dxvk} - developed by Philip Rebohle (doitsujin)') +
    L('    {#Url_dxvk}') +
    L('') +
    L('  dgVoodoo2 {#Ver_dgvoodoo2} - developed by Dege (dege-diosg)') +
    L('    {#Url_dgvoodoo2}') +
    L('    The installer detects whether your graphics card supports DXVK {#Ver_dxvk}') +
    L('    (Vulkan 1.3 driver). If it does DXVK is installed, otherwise dgVoodoo2.') +
    L('    A game folder that already runs dgVoodoo2 keeps it.') +
    L('') +
    L('  HRTF 3D audio - DSOAL + OpenAL Soft, developed by Chris Robinson (kcat)') +
    L('    https://github.com/kcat/dsoal') +
    L('    https://github.com/kcat/openal-soft') +
    L('') +
    L('  DirectX End-User Runtime (June 2010) and Visual C++ Redistributable - Microsoft') +
    L('') +
    L('  Windows DirectPlay is enabled, as BF1942 needs it on modern Windows.') +
    L('') +
    H('OPTIONAL (choose Custom installation on the Select Components page)');
#if Has_bobsiren
  S := S + L('  Battle of Britain - disable siren - created by Nicole @ MoonGamers') +
    L('    The Battle of Britain map without the air raid siren.') + L('');
#endif
#if Has_borderless1942
  S := S + L('  Borderless1942 {#Ver_borderless1942} - originally by Turnerj, forked by LANCommander, then by Nicole') +
    L('    {#Url_borderless1942}') + L('');
#endif
#if Has_datafield42
  S := S + L('  DataField42 {#Ver_datafield42} - developed by Ahrkylien') +
    L('    {#Url_datafield42}') + L('');
#endif
#if Has_richpresence
  S := S + L('  Battlefield Rich Presence {#Ver_richpresence} - developed by Gametools Network') +
    L('    {#Url_richpresence}') +
    L('    Shows the Battlefield game and server you are playing in your Discord status.') + L('');
#endif
#if Has_punkbuster42
  S := S + L('  Punkbuster42 - PunkBuster installer (BF1942 community; PunkBuster by Even Balance)') + L('');
#endif
#if Has_compat
  S := S + L('  Battlefield 1942 Compatibility Profile - PCGamingWiki community') +
    L('    https://community.pcgamingwiki.com/files/file/1004-battlefield-1942-compatibility-profile/') +
    L('    Windows fixes EmulateHeap, NoGhost and Win98VersionLie. Only tick this if the game crashes.') + L('');
#endif
#if Has_hiresui
  S := S + L('  Higher resolution UI 0.1 - higher resolution menu/interface textures (menu.rfa)') + L('');
#endif
#if HasFontPack
  S := S + L('  Font - pick the original or a larger in-game font') + L('');
#endif
  S := S + H('NOTES');
#if GenerateSerial
  S := S + L('  - A random serial is generated and registered automatically') +
    L('    (an existing valid serial in the registry is kept).') + L('');
#endif
#if ServerAddress != ""
  S := S + L('  - The "{#ServerName}" shortcut joins {#ServerAddress}.') + L('');
#endif
  S := S + L('  - Use the "Skip intro" option to add +restart 1 to the desktop shortcut.') +
    L('') +
    L('  - Uninstall from Windows Settings > Apps > Installed apps.') +
    L('') +
    '  - Built with BF1942-Installer: https://github.com/AnomalousNicole/BF1942-Installer}';
  Page.RichEditViewer.RTFText := S;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpSelectDir then begin
#if AppendEAGames
    ApplyInstallDirRule;
#endif
    Result := ConfirmSecondInstall;
    if Result then SelectFromGameFolder;
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  Info: String;
begin
  DetectRenderer;
  Result := MemoDirInfo + NewLine + NewLine + MemoTypeInfo + NewLine + NewLine +
            MemoComponentsInfo + NewLine + NewLine;
  if MemoTasksInfo <> '' then
    Result := Result + MemoTasksInfo + NewLine + NewLine;
  Result := Result + 'Graphics renderer:' + NewLine + Space + GetRendererName('') + NewLine;
  Info := RendererInfo;
  StringChangeEx(Info, #13#10, NewLine + Space, True);
  if Trim(Info) <> '' then
    Result := Result + Space + Trim(Info) + NewLine;

  Result := Result + NewLine + 'Windows prerequisites:' + NewLine;
  if DirectPlayNeeded then
    Result := Result + Space + 'DirectPlay: will be enabled' + NewLine
  else
    Result := Result + Space + 'DirectPlay: already enabled - skipped' + NewLine;
  if DirectXNeeded then
    Result := Result + Space + 'DirectX (June 2010): will be installed' + NewLine
  else
    Result := Result + Space + 'DirectX (June 2010): already installed - skipped' + NewLine;
  if VCRedistNeeded and VCRepair then
    Result := Result + Space + 'Visual C++ Redistributable (x86): registered but its files are missing - will be repaired' + NewLine
  else if VCRedistNeeded then
    Result := Result + Space + 'Visual C++ Redistributable (x86): will be installed' + NewLine
  else
    Result := Result + Space + 'Visual C++ Redistributable (x86): already installed - skipped' + NewLine;
#if Has_richpresence
  if WizardIsComponentSelected('richpresence') then begin
    if DotNetDesktop8Needed and DNRepair then
      Result := Result + Space + '.NET 8 Desktop Runtime (x64): registered but its files are missing - will be repaired' + NewLine
    else if DotNetDesktop8Needed then
      Result := Result + Space + '.NET 8 Desktop Runtime (x64): will be installed' + NewLine
    else
      Result := Result + Space + '.NET 8 Desktop Runtime (x64): already installed - skipped' + NewLine;
  end;
#endif
  { DataField42 is installed for one game folder per PC }
  Info := DataField42Dir;
  if DataField42PatchNeeded then
    Result := Result + NewLine + 'DataField42:' + NewLine +
              Space + 'already installed in this folder - kept, and set up again for BF1942.exe' + NewLine
#if Has_datafield42
  else if WizardIsComponentSelected('datafield') and (Info <> '') then
    Result := Result + NewLine + 'DataField42:' + NewLine +
              Space + 'already installed for ' + Info + ' - not added here, as it can only be installed once.' + NewLine +
              Space + 'To use it with this folder, remove it in Settings > Apps first.' + NewLine
#endif
  ;
end;

var
  FolderChecked, FolderIsGame: Boolean;

{ Whether uninstalling may delete the whole install folder: it was new or empty, or it already held the game
  (an earlier install). A folder with other things in it, and no game, keeps them. Decided before any file is
  copied (ssInstall), as [UninstallDelete] is set up during the install. Running Setup again over its own install
  keeps what the first install decided (WholeFolder in the state key): BF1942.exe is in the folder by then. }
function FolderIsGameFolder: Boolean;
var
  Dir, Value: String;
  Rec: TFindRec;
begin
  if not FolderChecked then begin
    FolderChecked := True;
    Dir := ExpandConstant('{app}');
    FolderIsGame := True;
    if PathSame(RemoveBackslashUnlessRoot(WizardForm.PrevAppDir), Dir) and
       RegQueryStringValue(HKLM32, StateKey, 'WholeFolder', Value) then
      FolderIsGame := Value = '1'
    else if DirExists(Dir) and not FileExists(AddBackslash(Dir) + 'BF1942.exe') then
      if FindFirst(AddBackslash(Dir) + '*', Rec) then
        try
          repeat
            if (Rec.Name <> '.') and (Rec.Name <> '..') then FolderIsGame := False;
          until (not FolderIsGame) or not FindNext(Rec);
        finally
          FindClose(Rec);
        end;
    if not FolderIsGame then
      Log('The install folder has other files and no game: uninstalling removes only what Setup installed');
  end;
  Result := FolderIsGame;
end;

function WholeFolderValue(Param: String): String;
begin
  if FolderIsGameFolder then Result := '1' else Result := '0';
end;

{ Running Setup again with Borderless1942 or the Compatibility Profile unticked turns them off, as BF1942 Options
  does: they are in the game folder by now, and nothing else would remove them }
procedure RemoveUnselectedExtras;
var
  Path, Cmd: String;
  Code: Integer;
  Shell, Lnk: Variant;
begin
#if Has_borderless1942
  Path := ExpandConstant('{app}\Borderless1942.exe');
  if IsWin64 and FileExists(Path) and not WizardIsComponentSelected('borderless') then begin
    Log('Borderless1942 is unticked - removing it');
    DeleteFile(Path);
    { Its desktop shortcut too, when it is this folder's }
    Path := ExpandConstant('{autodesktop}\Battlefield 1942 (Borderless).lnk');
    if FileExists(Path) then
      try
        Shell := CreateOleObject('WScript.Shell');
        Lnk := Shell.CreateShortcut(Path);
        if Pos(Lowercase(AddBackslash(ExpandConstant('{app}'))), Lowercase(Lnk.TargetPath)) = 1 then DeleteFile(Path);
      except
        Log('Could not read ' + Path + ': ' + GetExceptionMessage);
      end;
  end;
#endif
#if Has_compat
  Path := ExpandConstant('{app}\BF1942.sdb');
  if FileExists(Path) and not WizardIsComponentSelected('compat') then begin
    Log('The Compatibility Profile is unticked - removing it');
    if IsWin64 then Cmd := ExpandConstant('{sysnative}\sdbinst.exe') else Cmd := ExpandConstant('{sys}\sdbinst.exe');
    Exec(Cmd, '-q -u "' + Path + '"', '', SW_HIDE, ewWaitUntilTerminated, Code);
    DeleteFile(Path);
  end;
#endif
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then begin
    FolderIsGameFolder;
    RemoveUnselectedExtras;
  end;
  if CurStep = ssPostInstall then begin
    ConfigureDisplayMode;
    { Also when Borderless1942.exe is already there (turned on in BF1942 Options, or by an earlier install):
      installing over it puts the game's own VideoDefault.con back, which would make the game fullscreen again }
#if Has_borderless1942
    if WizardIsComponentSelected('borderless') or FileExists(ExpandConstant('{app}\Borderless1942.exe')) then
#else
    if FileExists(ExpandConstant('{app}\Borderless1942.exe')) then
#endif
      ConfigureBorderless
    else
      ConfigureFullscreen;
  end;
end;

{ ---------- Uninstall ---------- }

procedure InitializeUninstallProgressForm;
begin
  UninstallProgressForm.Caption := '{#InstallerTitle}';
end;

{ "Punkbuster for Battlefield 1942": its Uninstal.exe lives in the game folder (deleted with it),
  so remove its Apps & features entry and Start menu folder directly }
procedure RemovePunkBusterGameEntry;
var
  Uninst: String;
begin
  if RegQueryStringValue(HKLM32, UninstallKey + '\' + PBGameKey, 'UninstallString', Uninst) and
     PathStartsWith(RemoveQuotes(Uninst), AddBackslash(ExpandConstant('{app}')), True) then begin
    Log('Removing ' + PBGameKey);
    RegDeleteKeyIncludingSubkeys(HKLM32, UninstallKey + '\' + PBGameKey);
    DelTree(ExpandConstant('{commonprograms}\' + PBGameKey), True, True, True);
  end;
end;

{ ---- Is another PunkBuster game installed? (a game folder other than this one with pb\pbcl.dll) ---- }

function IsOtherPBGameDir(Dir: String): Boolean;
begin
  Dir := RemoveBackslashUnlessRoot(PathNormalizeSlashes(RemoveQuotes(Trim(Dir))));
  Result := (Dir <> '') and not PathSame(Dir, ExpandConstant('{app}')) and
            FileExists(PathCombine(Dir, 'pb\pbcl.dll'));
  if Result then Log('Other PunkBuster game found: ' + Dir);
end;

{ Checks every direct subfolder of Parent (e.g. C:\EA Games\*, steamapps\common\*) }
function PBGameInSubfolders(const Parent: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if (Parent = '') or not DirExists(Parent) then Exit;
  if FindFirst(AddBackslash(Parent) + '*', FindRec) then
    try
      repeat
        if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
           (FindRec.Name <> '.') and (FindRec.Name <> '..') then
          Result := IsOtherPBGameDir(AddBackslash(Parent) + FindRec.Name);
      until Result or not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
end;

{ Folder of the exe in an UninstallString such as "C:\Game\uninst.exe" /x or C:\Game\Uninstal.exe -y }
function UninstallExeDir(Cmd: String): String;
var
  P: Integer;
begin
  Cmd := Trim(Cmd);
  if Copy(Cmd, 1, 1) = '"' then begin
    Delete(Cmd, 1, 1);
    P := Pos('"', Cmd);
    if P > 0 then Cmd := Copy(Cmd, 1, P - 1);
  end else begin
    P := Pos('.exe', Lowercase(Cmd));
    if P > 0 then Cmd := Copy(Cmd, 1, P + 3);
  end;
  Result := ExtractFileDir(Cmd);
end;

function PBGameInUninstallEntries: Boolean;
var
  Roots: array of Integer;
  Names: TArrayOfString;
  R, I: Integer;
  Key, Value: String;
begin
  Result := False;
  if IsWin64 then Roots := [HKLM64, HKLM32, HKCU] else Roots := [HKLM32, HKCU];
  for R := 0 to GetArrayLength(Roots) - 1 do
    if RegGetSubkeyNames(Roots[R], UninstallKey, Names) then
      for I := 0 to GetArrayLength(Names) - 1 do begin
        Key := UninstallKey + '\' + Names[I];
        { Another game's "Punkbuster for <game>" entry (ours was already removed) }
        if (CompareText(Names[I], PBServicesKey) <> 0) and
           RegQueryStringValue(Roots[R], Key, 'DisplayName', Value) and
           (Pos('punkbuster', Lowercase(Value)) > 0) then begin
          Log('Other PunkBuster entry found: ' + Value);
          Result := True;
        end;
        if not Result and RegQueryStringValue(Roots[R], Key, 'InstallLocation', Value) then
          Result := IsOtherPBGameDir(Value);
        if not Result and RegQueryStringValue(Roots[R], Key, 'UninstallString', Value) then
          Result := IsOtherPBGameDir(UninstallExeDir(Value));
        if Result then Exit;
      end;
end;

{ EA games register their folder as GAMEDIR / Install Dir under SOFTWARE\Electronic Arts[\EA GAMES] }
function PBGameInEAKeys(const Parent: String): Boolean;
var
  Names: TArrayOfString;
  I: Integer;
  Value: String;
begin
  Result := False;
  if RegGetSubkeyNames(HKLM32, Parent, Names) then
    for I := 0 to GetArrayLength(Names) - 1 do begin
      if RegQueryStringValue(HKLM32, Parent + '\' + Names[I], 'GAMEDIR', Value) then
        Result := IsOtherPBGameDir(Value);
      if not Result and RegQueryStringValue(HKLM32, Parent + '\' + Names[I], 'Install Dir', Value) then
        Result := IsOtherPBGameDir(Value);
      if Result then Exit;
    end;
end;

{ Every Steam library's steamapps\common folder (from libraryfolders.vdf) }
function PBGameInSteam: Boolean;
var
  SteamDir, LibPath: String;
  Vdf: AnsiString;
  S: String;
  P: Integer;
begin
  Result := False;
  if not RegQueryStringValue(HKCU, 'Software\Valve\Steam', 'SteamPath', SteamDir) then
    SteamDir := ExpandConstant('{commonpf32}\Steam');
  SteamDir := PathNormalizeSlashes(SteamDir);
  Result := PBGameInSubfolders(SteamDir + '\steamapps\common');
  if Result or not LoadStringFromFile(SteamDir + '\steamapps\libraryfolders.vdf', Vdf) then Exit;
  S := String(Vdf);
  P := Pos('"path"', S);
  while not Result and (P > 0) do begin
    S := Copy(S, P + 6, MaxInt);
    P := Pos('"', S);                         { opening quote of the value }
    if P = 0 then Break;
    S := Copy(S, P + 1, MaxInt);
    P := Pos('"', S);                         { closing quote }
    if P = 0 then Break;
    LibPath := Copy(S, 1, P - 1);
    LibPath := PathNormalizeSlashes(LibPath);   { libraryfolders.vdf escapes each backslash as \\ }
    Result := PBGameInSubfolders(LibPath + '\steamapps\common');
    P := Pos('"path"', S);
  end;
end;

function OtherPunkBusterGameFound: Boolean;
begin
  Result := PBGameInUninstallEntries or
            PBGameInEAKeys('SOFTWARE\Electronic Arts\EA GAMES') or
            PBGameInEAKeys('SOFTWARE\Electronic Arts') or
            PBGameInSubfolders(ExtractFileDir(ExpandConstant('{app}'))) or
            PBGameInSubfolders(ExpandConstant('{sd}\EA Games')) or
            PBGameInSubfolders(ExpandConstant('{commonpf32}\EA Games')) or
            PBGameInSubfolders(ExpandConstant('{commonpf32}\Electronic Arts')) or
            (IsWin64 and PBGameInSubfolders(ExpandConstant('{commonpf64}\EA Games'))) or
            PBGameInSteam;
end;

{ "PunkBuster Services" (PnkBstrA/PnkBstrB) - stop and delete the services, their files and entry }
procedure RemovePunkBusterServices;
var
  Sc: String;
  Code, Tries: Integer;
  Files: TArrayOfString;
  I: Integer;
  Remaining: Boolean;
begin
  Log('Removing PunkBuster Services');
  Sc := ExpandConstant('{sys}\sc.exe');
  Exec(Sc, 'stop PnkBstrA', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Exec(Sc, 'stop PnkBstrB', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Exec(Sc, 'delete PnkBstrA', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Exec(Sc, 'delete PnkBstrB', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Files := [ExpandConstant('{syswow64}\PnkBstrA.exe'), ExpandConstant('{syswow64}\PnkBstrB.exe'),
            ExpandConstant('{syswow64}\PnkBstrK.sys'), ExpandConstant('{syswow64}\pbsvc.exe')];
  { The services take a moment to stop and release their exe files }
  Tries := 0;
  repeat
    Remaining := False;
    for I := 0 to GetArrayLength(Files) - 1 do
      if FileExists(Files[I]) and not DeleteFile(Files[I]) then
        Remaining := True;
    if Remaining then Sleep(500);
    Tries := Tries + 1;
  until (not Remaining) or (Tries >= 20);
  RegDeleteKeyIncludingSubkeys(HKLM32, UninstallKey + '\' + PBServicesKey);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Flag, Cmd, KeyName: String;
  Code, Tries: Integer;
begin
  if CurUninstallStep <> usUninstall then Exit;
  { A CD key that BF1942 Options generated after install goes too, like one Setup generated ([Registry] above) }
  if RegQueryStringValue(HKLM32, StateKey, 'SerialCreated', Flag) and (Flag = '1') then begin
    Log('Removing the CD key that BF1942 Options generated');
    RegDeleteKeyIncludingSubkeys(HKLM32, ErgcKey);
  end;
  { The Compatibility Profile is registered while BF1942.sdb is in the game folder - by Setup or by BF1942 Options,
    so this checks the file rather than the component. Unregister it before the folder is deleted }
  if FileExists(ExpandConstant('{app}\BF1942.sdb')) then begin
    if IsWin64 then Cmd := ExpandConstant('{sysnative}\sdbinst.exe') else Cmd := ExpandConstant('{sys}\sdbinst.exe');
    Log('Removing the compatibility profile');
    Exec(Cmd, '-q -u "' + ExpandConstant('{app}\BF1942.sdb') + '"', '', SW_HIDE, ewWaitUntilTerminated, Code);
  end;
  { DataField42 has its own uninstaller. It runs when DataField42 is installed in this game folder - also when the
    player installed it there, as the folder is deleted anyway - so its entry in Apps and its shortcuts go too.
    DataField42 installed for another game folder stays. It is closed first, so its uninstaller can delete it }
  if DataField42Here and FindDataField42Uninstaller(Cmd) and FileExists(Cmd) then begin
    CloseDataField42;
    Log('Uninstalling DataField42: ' + Cmd);
    Exec(Cmd, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, Code);
    { Inno Setup uninstallers relaunch themselves from %TEMP%; wait until it is really gone }
    Tries := 0;
    while FindDataField42Uninstaller(Cmd) and (Tries < 120) do begin
      Sleep(500);
      Tries := Tries + 1;
    end;
  end;
  { Battlefield Rich Presence is an MSI - remove it by its ProductCode (the uninstall key name) }
  if RegQueryStringValue(HKLM32, StateKey, 'RichPresence', Flag) and (Flag = '1') and
     FindUninstallEntry('battlefield rich presence', KeyName, Cmd) and (Copy(KeyName, 1, 1) = '{') then begin
    Log('Uninstalling Battlefield Rich Presence: ' + KeyName);
    Exec(ExpandConstant('{sys}\msiexec.exe'), '/x ' + KeyName + ' /qn /norestart', '', SW_HIDE, ewWaitUntilTerminated, Code);
  end;
  { PunkBuster (Punkbuster42): always drop BF1942's own entry; the shared services only if no other game uses them }
  if RegQueryStringValue(HKLM32, StateKey, 'PunkBuster', Flag) and (Flag = '1') then begin
    RemovePunkBusterGameEntry;
    if OtherPunkBusterGameFound then
      Log('Keeping PunkBuster Services - another PunkBuster game is installed')
    else
      RemovePunkBusterServices;
  end;
end;
