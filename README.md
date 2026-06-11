# Leximancer Installation Package

This package installs and uninstalls LexiDesktop5 5.50.4 for Windows.

## Package location

Source installer and license files are stored at:

- `\\mdcislressmb01.adsroot.uts.edu.au\apps\Desktop_Apps\Leximancer`

The package includes:

- `Install\LexiDesktop5-5.50.4.msi`
- `Install\*.lexlicense`
- `Install\Leximancer_Install.ps1`
- `Uninstall\Leximancer_Uninstall.ps1`
- PsExec helper scripts matching the LTspice package pattern

## What it does

- Runs install and uninstall under LocalSystem using the bundled `PsExec.exe` by default
- Installs LexiDesktop5 silently using `msiexec`
- Sets `INSTALLDIR` to `C:\Program Files\Leximancer\LexiDesktop5`
- Copies the provided `.lexlicense` file as `leximancer.lexlicense` into the locations LexiDesktop checks at launch:
  - `C:\Program Files\Leximancer\LexiDesktop5\app\config`
  - `C:\Program Files\Leximancer\LexiDesktop5\app`
  - `C:\Program Files\Leximancer\LexiDesktop5`
  - `C:\Users\Default\AppData\Local\com.leximancer.desktop`
  - Existing user profile folders under `C:\Users\*\AppData\Local\com.leximancer.desktop`
- Uninstalls LexiDesktop5 silently by MSI ProductCode
- Stops running `LexiDesktop5.exe` processes before and after uninstall so the tray process does not remain alive
- Removes `C:\Program Files\Leximancer\LexiDesktop5`, then removes `C:\Program Files\Leximancer` if it is empty
- Writes logs to `C:\ITD\Logs`

## Deployment exit codes

- Install treats `0` and `3010` as successful MSI outcomes. The script returns the MSI exit code so deployment tooling can detect reboot-required status.
- Uninstall treats `0`, `1605`, and `3010` as successful MSI outcomes. MSI `1605` means the product is not installed and MSI `3010` means success with reboot requested; both are returned as script exit `0` so PsExec/click-to-run uninstall does not show a false error.

## PsExec behavior

- Default install and uninstall script execution uses `PsExec.exe -accepteula -s -nobanner` to run the MSI payload as LocalSystem, not the signed-in user profile.
- Helper batch files use the same non-interactive PsExec flow and return the PsExec/MSI exit code.

## Silent install command

From the `Install` folder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Leximancer_Install.ps1
```

The script relaunches itself with bundled `PsExec.exe` as LocalSystem unless it is already running as LocalSystem.

The underlying MSI command is:

```powershell
msiexec.exe /i "LexiDesktop5-5.50.4.msi" /quiet /norestart ALLUSERS=1 INSTALLDIR="C:\Program Files\Leximancer\LexiDesktop5" /L*v "C:\ITD\Logs\Leximancer_5_50_4_msi.log"
```

## Silent uninstall command

From the `Uninstall` folder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Leximancer_Uninstall.ps1
```

The script relaunches itself with bundled `PsExec.exe` as LocalSystem unless it is already running as LocalSystem.

The underlying MSI command is:

```powershell
msiexec.exe /x "{62C04CF7-DAA4-309D-8CC0-D46DC24959B2}" /quiet /norestart /L*v "C:\ITD\Logs\Leximancer_5_50_4_uninst_msi.log"
```

## Product information

- Application: Leximancer / LexiDesktop5
- Version: 5.50.4
- Vendor: Leximancer Pty Ltd
- ProductCode: `{62C04CF7-DAA4-309D-8CC0-D46DC24959B2}`
- UpgradeCode: `{01973388-64DF-7964-804E-4485DDA7937E}`

## License injection notes

The MSI exposes `INSTALLDIR` but does not expose a public license-file property such as `LICENSEFILE`.

Because of that, this package does not use an MST for licensing. Instead, it installs the MSI silently and then copies the provided `.lexlicense` file as `leximancer.lexlicense` into the locations Leximancer logs show it probes during startup.

If Leximancer confirms a supported command-line property for license deployment later, update `Leximancer_Install.ps1` to pass that public property or replace the post-install copy with a vendor-supported MST.

## References

- Leximancer installation guide: https://www.leximancer.com/lexidesktop-installation-guide
