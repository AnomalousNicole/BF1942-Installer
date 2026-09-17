# BF1942-Installer

Build your own Windows installer for **Battlefield 1942**, **The Road to Rome** and **Secret Weapons of WWII**. It bundles the best community fixes and sets the game up to run on Windows 10 and 11.

You bring the game files. One command downloads every fix from its official source, checks it, and produces a `Setup.exe` you can hand to players. It is a single file unless the build is too big for one; see [Installers larger than 2 GB](#installers-larger-than-2-gb).

```powershell
git clone https://github.com/AnomalousNicole/BF1942-Installer.git
cd BF1942-Installer
.\build.ps1 -GameDir "C:\EA Games\Battlefield 1942"
```

> [!IMPORTANT]
> This repository does **not** contain the game. You need your own installed copy of Battlefield 1942 with both expansions, patched to 1.61.

---

## Contents

- [What the installer does](#what-the-installer-does)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Components](#components)
- [Optional extras](#optional-extras)
- [Branding](#branding)
- [build.ps1 options](#buildps1-options)
- [Installers larger than 2 GB](#installers-larger-than-2-gb)
- [Antivirus and build.ps1](#antivirus-and-buildps1)
- [Distributing your installer](#distributing-your-installer)
- [Updating components](#updating-components)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)
- [Credits](#credits)
- [License](#license)

---

## What the installer does

For the people who run your `Setup.exe`:

**Graphics fix, chosen automatically**
- DXVK is installed when the graphics card supports it: Vulkan 1.3 with robustness2.
- Otherwise dgVoodoo2 is installed, pre-configured with 4x MSAA and 16x anisotropic filtering.

**Windows parts, only if they're missing**
- DirectPlay
- DirectX June 2010
- Visual C++ x86
- .NET 8, only when Rich Presence is chosen
- Visual C++ and .NET 8 are repaired if they're registered but their files are missing

**Game setup**
- **Serial:** a valid existing serial is kept. Otherwise a random 22-character one is generated. This can be turned off.
- **Display:** the game is set to the primary monitor's resolution and refresh rate (`game.setGameDisplayMode W H 32 Hz`).
- **Audio:** HRTF 3D audio through DSOAL + OpenAL Soft, and the BF42++ client improvements.

**Shortcuts**
- A desktop shortcut, with an option to skip the intro.
- An optional "join my server" shortcut.
- A Borderless1942 shortcut at the monitor's native resolution.

**Clean uninstall.** The uninstaller removes:
- Every file and registry entry the installer created.
- Its DataField42 and Rich Presence installs.
- The PunkBuster pieces for this game. The shared PunkBuster Services are removed only if no other PunkBuster game is installed.
- The Windows Firewall rules for the game folder.

---

## Requirements

| To build | |
|---|---|
| Windows 10 or 11 | PowerShell 5.1 (built in) or PowerShell 7 |
| [Inno Setup 6.4+](https://jrsoftware.org/isinfo.php) | `winget install JRSoftware.InnoSetup`, or run `.\build.ps1 -InstallInnoSetup` |
| Battlefield 1942 game folder | With `Mods\xpack1` (The Road to Rome) and `Mods\xpack2` (Secret Weapons of WWII) |
| ~6 GB free disk space | Downloads, staging and output |
| ~8 GB RAM | For the default `lzma2/ultra64` compression. Use `lzma2/max` on smaller machines |
| Internet connection | Components are downloaded on the first build and cached |

| To install (your players) |
|---|
| Windows 10 or 11, 32-bit or 64-bit. Borderless1942 and Rich Presence are 64-bit only and are hidden on 32-bit Windows |
| Administrator rights |
| ~4 GB free disk space |

---

## Quick start

1. **Install Inno Setup 6.4 or newer:**
   ```powershell
   winget install JRSoftware.InnoSetup
   ```
2. **Clone the repository:**
   ```powershell
   git clone https://github.com/AnomalousNicole/BF1942-Installer.git
   cd BF1942-Installer
   ```
3. **Point it at your game.** Either copy the game folder to `game\` inside the repository, or pass `-GameDir` in step 5.
4. *(Optional)* Add artwork to [`branding\`](branding/README.md). The optional extras in [`extras\`](extras/README.md) are already included.
5. **Build:**
   ```powershell
   .\build.ps1 -GameDir "C:\EA Games\Battlefield 1942"
   ```
   The first run creates `config.json` with a unique AppId for your installer. Edit it if you want your own title, server shortcut and so on, then run the build again.
6. **Get your installer** from `output\BF1942_Expansions_Setup.exe`. The build prints its size and SHA-256. If the build is too big for one file, `output\` also contains `.bin` files; see [Installers larger than 2 GB](#installers-larger-than-2-gb).

> [!TIP]
> If PowerShell refuses to run the script, allow it for this session:
> `Set-ExecutionPolicy -Scope Process Bypass`

---

## Configuration

`config.json` is created from [`config.example.json`](config.example.json) on the first build. It is git-ignored, so your settings stay local.

| Setting | Default | Description |
|---|---|---|
| `appId` | *(generated)* | Unique GUID for your installer. **Keep it the same across versions** so updates replace older installs. Never copy someone else's. |
| `gameDir` | `game` | Game folder. Relative paths are relative to the repository. `-GameDir` overrides it. |
| `appName` | `Battlefield 1942 & Expansions` | Name shown in Installed apps. |
| `installerTitle` | `BF1942 & Expansions Installer` | Window title and welcome heading. |
| `createdBy` | *(empty)* | Adds "Installer created by …" to the welcome and credits pages. |
| `appPublisher` | `BF1942 Community` | Publisher shown in Installed apps. |
| `outputBaseFilename` | `BF1942_Expansions_Setup` | File name of the built `.exe` (and of the `.bin` files of a split build). |
| `defaultInstallDir` | `{sd}\EA Games\Battlefield 1942` | Default install folder. `{sd}` is the system drive. |
| `appendEAGamesFolder` | `true` | Always install into `<chosen folder>\EA Games\Battlefield 1942`. |
| `serverShortcutName` | *(empty)* | Name of the "join server" desktop shortcut. |
| `serverAddress` | *(empty)* | `ip:port` to join, for example `203.0.113.10:14567`. Leave empty for no server shortcut. |
| `generateSerial` | `true` | Register a random serial when none is present. |
| `registryStateKey` | `SOFTWARE\BF1942 Installer` | Registry key (32-bit HKLM) where the installer records what it installed. |
| `compression` | `lzma2/ultra64` | Inno Setup compression. `lzma2/max` needs less RAM but produces a bigger file. |
| `exclude` | `[]` | Component ids to leave out, for example `["datafield42", "richpresence"]`. |

**Example**, a community installer with a server shortcut:

```json
{
  "appId": "5C1D3E7A-0B7B-4E43-9F3A-2D9E6B1F4C21",
  "gameDir": "D:\\Games\\Battlefield 1942",
  "installerTitle": "BF1942 Installer: Created by MyClan",
  "createdBy": "MyClan",
  "appPublisher": "MyClan",
  "outputBaseFilename": "BF1942_MyClan_Setup",
  "serverShortcutName": "Battlefield 1942 - MyClan",
  "serverAddress": "203.0.113.10:14567",
  "exclude": ["datafield42"]
}
```

---

## Components

The versions are pinned in [`components.json`](components.json). Each download is checked against its SHA-256.

### Required

| Component | Version | Author | Obtained from |
|---|---|---|---|
| [BF42++](https://github.com/Casqade/bf42plusplus) | v2.0 | Casqade | GitHub release |
| [DXVK](https://github.com/doitsujin/dxvk) | v2.7.1 (locked) | Philip Rebohle (doitsujin) | GitHub release |
| [dgVoodoo2](https://github.com/dege-diosg/dgVoodoo2) | v2.87.4 | Dege | GitHub release |
| HRTF: [DSOAL](https://github.com/kcat/dsoal) + [OpenAL Soft](https://github.com/kcat/openal-soft) | OpenAL Soft 1.23.1 | Chris Robinson (kcat) | Included in `components/hrtf` (LGPL) |
| DirectX End-User Runtime | June 2010 | Microsoft | download.microsoft.com |
| Visual C++ Redistributable (x86) | latest | Microsoft | aka.ms, with the Microsoft signature verified |

### Optional (leave out with `exclude`)

| Id | Component | Version | Author |
|---|---|---|---|
| `bobsiren` | Battle of Britain - disable siren: the Battle of Britain map without the air raid siren. Included in `components/bobsiren` | | Nicole @ MoonGamers |
| `borderless1942` | [Borderless1942](https://github.com/LANCommander/Borderless1942) | 1.3.0 | LANCommander |
| `datafield42` | [DataField42](https://github.com/Ahrkylien/BF1942-DataField42) | v2.1.0 | Ahrkylien |
| `richpresence` | [Battlefield Rich Presence](https://github.com/community-network/Battlefield-rich-presence) | v1.6.0 | Gametools Network |
| `dotnet8` | .NET 8 Desktop Runtime (x64), needed by Rich Presence | 8.0.31 | Microsoft |

### Tracked configuration

These are files written for this project. Edit them to change the defaults.

| File | Purpose |
|---|---|
| `components/bf42pp/bf42++.ini` | BF42++ settings |
| `components/dxvk/dxvk.conf` | DXVK settings |
| `components/dgvoodoo2/dgVoodoo.conf` | dgVoodoo2 settings: `stretched_ar`, 4x MSAA, 16x anisotropic filtering, 1024 MB VRAM, no watermark |
| `components/hrtf/alsoft.ini` | OpenAL Soft HRTF settings: 48 kHz, headphones, built-in HRTF |

---

## Optional extras

Some community files have no official download, so they are included in `extras\` and added to your installer. Delete a file, or `exclude` its id in `config.json`, to leave it out. See [extras/README.md](extras/README.md) for the exact paths and tested SHA-256 values.

- **Punkbuster42** (community-built installer for PunkBuster)
- **Battlefield 1942 Compatibility Profile** ([PCGamingWiki](https://community.pcgamingwiki.com/files/file/1004-battlefield-1942-compatibility-profile/))
- **Higher resolution UI 0.1**
- **Font RFAs:** original, 1x, 2x, 3x, 3.5x and 4x

---

## Branding

Put `WizardImage100.bmp` (164×314) in `branding\` to replace the default Welcome/Finish page image. Higher-DPI sizes are optional. See [branding/README.md](branding/README.md).

---

## build.ps1 options

| Option | Description |
|---|---|
| `-GameDir <path>` | Game folder (overrides `gameDir`) |
| `-Config <path>` | Use a different config file, for example one per community |
| `-Quick` | Compile without the game files. A fast check of the script and components. **Don't distribute the result.** |
| `-DownloadOnly` | Download and stage the components, then stop |
| `-Force` | Download everything again instead of using `build\cache` |
| `-Span` | Always split the installer into `Setup.exe` + `.bin` files (done automatically when a single file would be over 2 GB; see [Installers larger than 2 GB](#installers-larger-than-2-gb)) |
| `-InstallInnoSetup` | Install Inno Setup with winget if it is missing |

**What gets created** (all git-ignored):

| Path | Contents |
|---|---|
| `build\cache\` | Downloads (reused between builds) |
| `build\deps\` | Staged components |
| `build\generated.iss` | Settings passed to Inno Setup |
| `build\size-history.json` | Sizes of the last build, used to predict whether the next one fits in a single `Setup.exe` |
| `build\VulkanCheck.exe` | Helper compiled from `installer\VulkanCheck.cs` |
| `output\` | Your installer (`Setup.exe`, plus `.bin` files for a split build) |

---

## Installers larger than 2 GB

A single-file `Setup.exe` must stay under 2 GB. A full build with every extra is about 1.97 GB, which fits.

**What `build.ps1` does:**

1. Before compiling, it decides whether to build a single `Setup.exe` or a split installer:
   - If the files to pack are smaller than the limit, it builds a single `Setup.exe`.
   - Otherwise it predicts the compressed size from the previous build with the same compression setting (saved in `build\size-history.json`). If the prediction is clearly over the limit (by more than 2%), it builds the split installer straight away, so the installer is only compiled once.
   - If there is no previous build to predict from, or the prediction is close to the limit, it tries a single `Setup.exe` first.
2. If a single `Setup.exe` was tried and Inno Setup reports that the file is too large, or the finished `Setup.exe` is bigger than 2 GB minus a 64 MB safety margin (2,080,374,784 bytes), the build prints a warning and compiles again as a **split installer**.
3. A split installer is a small `Setup.exe` plus data files named after it, each just under 2 GB:

   ```
   output\
   ├── BF1942_Expansions_Setup.exe      # about 2 MB
   ├── BF1942_Expansions_Setup-1.bin
   └── BF1942_Expansions_Setup-2.bin    # only if needed
   ```
4. The build summary lists every file with its size and SHA-256, and the total size.

Before each compile, the build deletes the `Setup.exe` and `.bin` files of the previous build, so an old `.bin` file is never mixed up with a new `Setup.exe`.

**Good to know:**

- **Build time:** the installer is compiled twice only when a single `Setup.exe` was tried and did not fit, which mostly happens on the first build or when your files grow. Use `-Span` to always build the split installer straight away.
- **Sharing:** give players **all** the files and tell them to keep them in the same folder. Setup reads the `.bin` files from the folder `Setup.exe` is in; if one is missing, it asks the player where to find it. A ZIP of all the files is the easiest way to keep them together.
- **Checksums:** publish the SHA-256 of every file, not only of `Setup.exe`.
- **Keeping a single file:** leave out large extras, or `exclude` optional components in `config.json`, until the build fits again.

---

## Antivirus and build.ps1

Some antivirus products flag `build.ps1` as malware, move it to quarantine, or lock it while you edit it. Bitdefender, for example, has reported it as `Heur.BZC.PZQ.Boxter.*`. This is a **false positive**. `Heur` means a *heuristic* detection: the file does not match any known malware, but it does some of the things malicious PowerShell scripts often do.

**Why the script looks suspicious.** To build the installer, `build.ps1` has to:

| What the script does | Why an antivirus scanner is suspicious of it |
|---|---|
| Downloads files with `Net.WebClient` and turns on TLS 1.2 | "Download and run" scripts use the same calls |
| Writes `.exe` files to disk and runs the DirectX redistributable silently (`/Q`) | Malware droppers save and silently start payloads |
| Compiles `installer\VulkanCheck.cs` with the `csc.exe` that ships with Windows | Attackers use built-in Windows tools to avoid detection |
| Reads uninstall keys in the registry, can run `winget install` | Looks like system reconnaissance and software installation |
| Deletes temporary files with `-Force` and hides the download progress bar | Looks like an attempt to hide activity |

Each of these is harmless on its own, but together they can push the script over a heuristic threshold. Scanners check a file most closely when it is new or has just changed, so a detection often appears right after cloning, pulling an update, or editing the script. Any change to the file can switch the detection on or off.

**What the script does not do.** It only downloads from the official sources listed in `components.json`, checks every download against its pinned SHA-256 (or a valid Microsoft signature for the unpinned VC++ redistributable), and writes only inside the repository (`build\`, `output\`). The one exception is `-InstallInnoSetup`, which installs Inno Setup with winget. It is plain text, so you can read all of it before you run it.

**If your antivirus flags it:**

1. Check that your copy is unchanged: `git status` should not list `build.ps1`. If you downloaded a ZIP instead of cloning, compare the file with the one on GitHub.
2. Add an exclusion for the repository folder in your antivirus, for example `C:\repos\BF1942-Installer`.
3. Restore the file with `git checkout -- build.ps1`. This is safer than restoring it from quarantine, because the quarantined copy may contain changes you made yourself.
4. Optional: report the false positive to your antivirus vendor (for Bitdefender: https://www.bitdefender.com/submit/), so other users are not affected.

Only exclude a copy you got from this repository. If `git status` shows changes you did not make, delete the folder and clone it again.

The installer you build is a separate file: an unsigned `Setup.exe` can also trigger SmartScreen or an antivirus warning on players' PCs. See [Distributing your installer](#distributing-your-installer).

---

## Distributing your installer

- **Size:** the installer is normally a single `.exe` under **2 GB** (a full build with every extra is about 1.97 GB). A bigger build is split into `Setup.exe` + `.bin` files, which must be shared together. See [Installers larger than 2 GB](#installers-larger-than-2-gb).
- **SmartScreen:** unsigned installers show *"Windows protected your PC"*. Players click **More info → Run anyway**. Code signing removes this.
- **Antivirus:** some antivirus products are suspicious of new, unsigned installers, especially large ones that bundle tools such as PunkBuster, DXVK or dgVoodoo2. Publishing the SHA-256 and signing the installer both help. If a player's antivirus blocks it, submit the file to that vendor as a false positive.
- **Checksum:** publish the SHA-256 that `build.ps1` prints (one per file for a split installer), so players can verify their download.
- **Licenses:** you are redistributing the bundled components, so read [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) first.

---

## Updating components

> [!WARNING]
> **DXVK is locked to 2.7.1**, the newest release that works with Battlefield 1942. `build.ps1` stops if `components.json` points to any other DXVK version.

1. Edit the component's `version`, `url`, `fileName` and `sha256` in `components.json`.
2. Run `.\build.ps1 -Quick` to check it, then do a full build and test an install and uninstall.

See [CONTRIBUTING.md](CONTRIBUTING.md) for adding new components.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Inno Setup 6 was not found` | `winget install JRSoftware.InnoSetup`, or `.\build.ps1 -InstallInnoSetup` |
| `BF1942.exe was not found` | Pass `-GameDir`, set `gameDir` in `config.json`, or copy the game to `game\` |
| `SHA-256 mismatch` | The file on the download server changed. Check the project's release page before updating `components.json`. |
| Antivirus warning about the dgVoodoo2 zip | Some antivirus products flag tools inside the dgVoodoo2 release (a false positive). The build handles that archive in memory and never saves it (`"cache": false`); only `D3D8.dll` is used. |
| Antivirus quarantines or locks `build.ps1` (for example Bitdefender `Heur.BZC.PZQ.Boxter.*`) | A false positive caused by what the script has to do. See [Antivirus and build.ps1](#antivirus-and-buildps1). |
| "Access denied" on a file in `build\` | Antivirus is scanning a new file. Run the build again; the script already retries for 30 seconds. |
| Out of memory while compiling | Set `"compression": "lzma2/max"` in `config.json` |
| Installer over 2 GB | `build.ps1` splits it into `Setup.exe` + `.bin` files automatically. See [Installers larger than 2 GB](#installers-larger-than-2-gb) |
| Players get the wrong renderer | They can run `Setup.exe /RENDERER=dxvk` or `/RENDERER=dgvoodoo` |
| Install problems | The setup log is at `%TEMP%\Setup Log YYYY-MM-DD #NNN.txt` |

---

## How it works

The full technical write-up is in [docs/TECHNICAL.md](docs/TECHNICAL.md). It covers:

- How DXVK or dgVoodoo2 is chosen
- The order things are installed in
- Every uninstall step, including how PunkBuster games are detected
- The registry layout

**Repository layout:**

```
BF1942-Installer/
├── build.ps1                 # The build: download → stage → compile
├── config.example.json       # Template for your config.json
├── components.json           # Pinned component versions, URLs and SHA-256
├── installer/
│   ├── BF1942-Installer.iss  # Inno Setup script
│   └── VulkanCheck.cs        # DXVK capability check (compiled by build.ps1)
├── components/               # Config files (+ LGPL audio libraries) copied into the install
├── extras/                   # Optional files with no official download
├── branding/                 # Your optional artwork (git-ignored)
└── docs/TECHNICAL.md
```

---

## Credits

This installer bundles the work of these developers, and all credit goes to them:

- **BF42++**: [Casqade](https://github.com/Casqade/bf42plusplus)
- **DXVK**: [Philip Rebohle (doitsujin)](https://github.com/doitsujin/dxvk)
- **dgVoodoo2**: [Dege](https://github.com/dege-diosg/dgVoodoo2)
- **DSOAL / OpenAL Soft**: [Chris Robinson (kcat)](https://github.com/kcat)
- **Borderless1942**: [LANCommander](https://github.com/LANCommander/Borderless1942)
- **DataField42**: [Ahrkylien](https://github.com/Ahrkylien/BF1942-DataField42)
- **Battlefield Rich Presence**: [Gametools Network](https://github.com/community-network/Battlefield-rich-presence)
- **Punkbuster42**: the BF1942 community (PunkBuster itself: Even Balance, Inc.)
- **Compatibility Profile**: the PCGamingWiki community
- **Font RFAs and Higher resolution UI**: the BF1942 community
- **Battle of Britain - disable siren**: Nicole @ MoonGamers
- **[Inno Setup](https://jrsoftware.org/isinfo.php)**: Jordan Russell and Martijn Laan

The installer was created by **Nicole @ MoonGamers**.

---

## License

The scripts and configuration in this repository are released under the [MIT License](LICENSE).

- **Bundled components** keep their own licenses. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
- **Battlefield 1942** is © Electronic Arts / DICE. No game files are included.
- This is a community project. It is not affiliated with EA, DICE, Even Balance or any of the projects above.
