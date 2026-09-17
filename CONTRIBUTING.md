# Contributing

Thanks for helping improve the BF1942 installer. Bug reports, fixes and component updates are welcome.

## Reporting a problem

Open an issue and include:

- Your Windows version (Settings → System → About), and whether it is 32-bit or 64-bit.
- Your GPU. Also say whether DXVK or dgVoodoo2 was installed: the *Ready to Install* page shows it, and the value is stored in the registry.
- **For build problems:** `build\build.log`. It holds everything `build.ps1` printed, plus the full Inno Setup output.
- **For install problems:** the setup log at `%TEMP%\Setup Log YYYY-MM-DD #NNN.txt`.
- **For uninstall problems:** a log from `unins000.exe /LOG="%USERPROFILE%\Desktop\uninstall.log"`.

## Updating a bundled component

**Don't update DXVK.** It is locked to 2.7.1, the newest release that works with Battlefield 1942, and `build.ps1` rejects any other version.

1. Edit its entry in `components.json`: `version`, the download `url`, `fileName` and `sha256`.
2. Get the SHA-256 of the new file:
   ```powershell
   (Get-FileHash .\the-new-file.zip -Algorithm SHA256).Hash
   ```
3. Run `.\build.ps1 -Quick` to check the download and the script, then do a full build and test an install. Builds use Inno Setup 7, which `build.ps1` installs and updates with winget.
4. Update the version tables in `README.md` and `THIRD-PARTY-NOTICES.md`.

Only use **official** download locations, such as the project's GitHub releases or Microsoft's download servers. Never commit third-party binaries unless their license allows it. The DSOAL/OpenAL Soft files in `components/hrtf` are LGPL. The files in `extras/` have no official download and are included on purpose. `components/bobsiren/Battle_of_Britain.rfa` is included with the permission of its author, Nicole @ MoonGamers.

## Adding a new component

1. Add an entry to `components.json`, or to `extras` for files with no official download (and commit the file to `extras/`).
   Fill in `author` (and `version` where there is one) - `build.ps1` prints them as credits while it stages the component.
2. In `installer/BF1942-Installer.iss`, wrap every line that uses the component in `#if Has_<id>` … `#endif`. That covers `[Components]`, `[Files]`, `[Run]`, `[Registry]`, and the credits page in `InitializeWizard`.
3. If the component has its own uninstaller, remove it in `CurUninstallStepChanged`.

## Script conventions

- The `.iss` requires Inno Setup 7 and must compile without warnings. Don't use functions or directives that Inno Setup marks as obsolete or renamed, such as `RemoveBackslash` in ISPP (use `RemoveBackslashUnlessRoot`) or `LZMAUseSeparateProcess`.
- For paths in `[Code]`, use the built-in helpers (`PathCombine`, `PathSame`, `PathStartsWith`, `PathEndsWith`, `PathNormalizeSlashes`) instead of string handling.
- Use Inno Setup's handle types (`HWND`, `HDC`, ...) in `external` declarations of Windows API functions.
- The installer stays 32-bit (`SetupArchitecture` is not set), so it also runs on 32-bit Windows 10 and keeps writing the game's registry keys to the 32-bit view.
- The ratios in `size-seed.json` are measured on the MoonGamers build of this installer, not on a build of this template. If you do a full build of the template with the stock components, please update them from your `build\size-history.json` (`compressed / packed`) and say in the pull request which build they come from.

## Pull requests

- Keep each pull request focused on one change.
- Never commit game files, `config.json`, `build/` or `output/`.
- Test a full install **and** an uninstall on a clean Windows 10 or 11 PC or VM before submitting changes to the `[Code]` section.
