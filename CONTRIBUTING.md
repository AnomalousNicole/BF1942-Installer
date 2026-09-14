# Contributing

Thanks for helping improve the BF1942 installer. Bug reports, fixes and component updates are welcome.

## Reporting a problem

Open an issue and include:

- Your Windows version (Settings → System → About), and whether it is 32-bit or 64-bit.
- Your GPU. Also say whether DXVK or dgVoodoo2 was installed: the *Ready to Install* page shows it, and the value is stored in the registry.
- **For build problems:** the full `build.ps1` output.
- **For install problems:** the setup log at `%TEMP%\Setup Log YYYY-MM-DD #NNN.txt`.
- **For uninstall problems:** a log from `unins000.exe /LOG="%USERPROFILE%\Desktop\uninstall.log"`.

## Updating a bundled component

**Don't update DXVK.** It is locked to 2.7.1, the newest release that works with Battlefield 1942, and `build.ps1` rejects any other version.

1. Edit its entry in `components.json`: `version`, the download `url`, `fileName` and `sha256`.
2. Get the SHA-256 of the new file:
   ```powershell
   (Get-FileHash .\the-new-file.zip -Algorithm SHA256).Hash
   ```
3. Run `.\build.ps1 -Quick` to check the download and the script, then do a full build and test an install.
4. Update the version tables in `README.md` and `THIRD-PARTY-NOTICES.md`.

Only use **official** download locations, such as the project's GitHub releases or Microsoft's download servers. Never commit third-party binaries unless their license allows it. The DSOAL/OpenAL Soft files in `components/hrtf` are LGPL. `components/bobsiren/Battle_of_Britain.rfa` is included with the permission of its author, Nicole @ MoonGamers.

## Adding a new component

1. Add an entry to `components.json`, or to `extras` for files people must supply themselves.
2. In `installer/BF1942-Installer.iss`, wrap every line that uses the component in `#if Has_<id>` … `#endif`. That covers `[Components]`, `[Files]`, `[Run]`, `[Registry]`, and the credits page in `InitializeWizard`.
3. If the component has its own uninstaller, remove it in `CurUninstallStepChanged`.

## Pull requests

- Keep each pull request focused on one change.
- Never commit game files, `config.json`, `build/`, `output/` or anything in `extras/`.
- Test a full install **and** an uninstall on a clean Windows 10 or 11 PC or VM before submitting changes to the `[Code]` section.
