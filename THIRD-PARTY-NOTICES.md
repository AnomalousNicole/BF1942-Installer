# Third-party notices

This repository contains **no unmodified game files** The third-party binaries it includes are the LGPL audio libraries and the optional extras listed below. The one modified game file, the Battle of Britain map without the air raid siren, is also listed below. `build.ps1` downloads every other component from its official source when you build, and checks its SHA-256.

> [!IMPORTANT]
> **If you distribute an installer you built,** you are redistributing everything inside it. Check each project's terms first. Several projects publish no license file, so their authors keep all rights. Ask them before sharing their work widely.

## Downloaded at build time

| Component | Version | Author | License | Source |
|---|---|---|---|---|
| BF42++ | v2.0 | Casqade | No license file published | https://github.com/Casqade/bf42plusplus |
| DXVK | v2.7.1 | Philip Rebohle and contributors | zlib | https://github.com/doitsujin/dxvk |
| dgVoodoo2 | v2.87.4 | Dege | Freeware; see the readme in the release | https://github.com/dege-diosg/dgVoodoo2 |
| Borderless1942 | 1.3.0 | LANCommander | No license file published | https://github.com/LANCommander/Borderless1942 |
| DataField42 | v2.1.0 | Ahrkylien | MIT | https://github.com/Ahrkylien/BF1942-DataField42 |
| Battlefield Rich Presence | v1.6.0 | Gametools Network | MIT | https://github.com/community-network/Battlefield-rich-presence |
| DirectX End-User Runtime | June 2010 | Microsoft | Microsoft redistributable terms | https://www.microsoft.com/download/details.aspx?id=8109 |
| Visual C++ Redistributable (x86) | latest | Microsoft | Microsoft redistributable terms | https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist |
| .NET 8 Desktop Runtime (x64) | 8.0.31 | Microsoft | MIT (.NET) / Microsoft terms | https://dotnet.microsoft.com/download/dotnet/8.0 |

## Included in this repository

| Component | Files | Author | License | Source code |
|---|---|---|---|---|
| DSOAL (based on Wine DirectSound; version resource 5.3.1.904) | `components/hrtf/dsound_next.dll` | Chris Robinson (kcat), Wine project | LGPL-2.1 (`components/hrtf/DSOAL-LICENSE.txt`) | https://github.com/kcat/dsoal |
| OpenAL Soft 1.23.1 | `components/hrtf/dsoal-aldrv.dll` | Chris Robinson (kcat) and contributors | LGPL-2.0-or-later (`components/hrtf/OpenAL-Soft-COPYING.txt`) | https://github.com/kcat/openal-soft/tree/1.23.1 |

| Battle of Britain - disable siren | `components/bobsiren/Battle_of_Britain.rfa` | Nicole @ MoonGamers | Modified Battlefield 1942 map; the original map is © Electronic Arts / DICE | |

The audio libraries are unmodified builds. The installer also copies their license texts to `Licenses\` in the game folder. `alsoft.ini` is a configuration file written for this project.

## Optional extras (`extras/`)

These are included in the repository, because they have no official download. See [extras/README.md](extras/README.md).

| Component | Author |
|---|---|
| Punkbuster42 (community-built installer) | BF1942 community; the PunkBuster software it installs is by Even Balance, Inc. (proprietary) |
| Battlefield 1942 Compatibility Profile | PCGamingWiki community: https://community.pcgamingwiki.com/files/file/1004-battlefield-1942-compatibility-profile/ |
| Font RFAs, Higher resolution UI 0.1 | BF1942 community |

## Build tools

| Tool | License |
|---|---|
| [Inno Setup](https://jrsoftware.org/isinfo.php) (Jordan Russell, Martijn Laan) | Inno Setup License. Built installers contain the Inno Setup runtime. https://jrsoftware.org/files/is/license.txt |

## Game

Battlefield 1942, The Road to Rome and Secret Weapons of WWII are © Electronic Arts / DICE. No game files are included. Builders must use their own copy of the game.

This project is a community effort. It is not affiliated with or endorsed by Electronic Arts, DICE, Even Balance or any of the projects above.
