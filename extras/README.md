# extras/

Optional components that are **not downloaded automatically**, because they have no official download link. They are included in this folder.

`build.ps1` adds every file it finds here to your installer. If you delete a file, that component is left out of the installer.

| Component | Put the file here | Tested SHA-256 |
|---|---|---|
| Punkbuster42 (Even Balance) | `extras\Punkbuster42\Punkbuster42.exe` | `09A51EBFED96717266CDAEA7A42B1E7315AE3A5C59ECF8357E46C7D480037123` |
| Battlefield 1942 Compatibility Profile ([PCGamingWiki](https://community.pcgamingwiki.com/files/file/1004-battlefield-1942-compatibility-profile/)) | `extras\CompatProfile\BF1942.sdb` | `086FFB75C54DFC4F7079EA25A6E1EFE09713550C294483D4889B69C34351DE65` |
| Higher resolution UI 0.1 | `extras\HiResUI\menu.rfa` | `F295BB588F11811F419FA532033B60191B2CC30C06D14F833CA88693B20378DA` |
| Font: BF1942 original (800×600 / 1024×768) | `extras\Fonts\Original\Font.rfa` | `D5BF9331E57F17A10235DE013B6F3A7C687C6706093D1E94B9487A3AAF629C17` |
| Font: 1x (1280×720 / 1366×768) | `extras\Fonts\1x\Font.rfa` | `80C9FCA93735E48D4D7905425385D7D106E17AD7716CD7BF5AD64A1DC40B7187` |
| Font: 2x (1920×1080) | `extras\Fonts\2x\Font.rfa` | `17EFFD7B59AF550F372FDD108DE8399E27EF202C8AB518679D5E89CF4BD06F4C` |
| Font: 3x (2560×1440) | `extras\Fonts\3x\Font.rfa` | `25B1F7359B131F6000C1A793496B1B55499C321E57405164BE60434658E78180` |
| Font: 3.5x (3440×1440 / 2560×1600) | `extras\Fonts\3.5x\Font.rfa` | `D098C9E5705E0E3935B91669C9FB38D8D5D17A2CC51C178F8BE9C9E22CA848DE` |
| Font: 4x (3840×2160) | `extras\Fonts\4x\Font.rfa` | `B20CE1EBC476CC55F03D2906B3CBE42508118A513580524D971A0EAA14E0E1E0` |

**If a file doesn't match the tested SHA-256,** the build shows a warning and still includes it.

**Fonts:** add any number of the font sizes. The installer always offers "Keep the game's own font", plus every font found here. **2x** is pre-selected when it is present.

To leave a component out even though its file is here, add its id to `"exclude"` in `config.json`. The ids are `punkbuster42`, `compat`, `hiresui`, `font_original`, `font_1x`, `font_2x`, `font_3x`, `font_35x` and `font_4x`.
