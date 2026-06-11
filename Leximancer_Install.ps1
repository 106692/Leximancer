param(
    [switch]$RunAsSystemPayload
)

$ScriptPath = $PSScriptRoot
if (-not $ScriptPath) { $ScriptPath = $PWD.Path }

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
if ((-not $RunAsSystemPayload) -and (-not $CurrentIdentity.IsSystem)) {
    $PsExec = Join-Path -Path $ScriptPath -ChildPath "PsExec.exe"
    if (!(Test-Path -Path $PsExec -PathType Leaf)) {
        Write-Host "$(Get-Date) PsExec.exe not found: $PsExec"
        $Host.SetShouldExit(5)
        EXIT 5
    }

    Write-Host "$(Get-Date) Relaunching install as LocalSystem with PsExec."
    $PsExecArguments = "-accepteula -s -nobanner powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -RunAsSystemPayload"
    $PsExecRun = Start-Process -FilePath $PsExec -ArgumentList $PsExecArguments -Wait -PassThru
    $Host.SetShouldExit($PsExecRun.ExitCode)
    EXIT $PsExecRun.ExitCode
}

If (!(Test-Path -Path "C:\ITD\Logs")) {
    New-Item -Path "C:\ITD\Logs" -ItemType Directory -Force | Out-Null
}

$AppName = "Leximancer"
$AppVersion = "5_50_4"
$AppDisplayVersion = "5.50.4"
$AppFullName = $AppName + "_" + $AppVersion
$InstallLog = "C:\ITD\Logs\" + $AppFullName + "_script_install.log"
$MSIInstallLog = "C:\ITD\Logs\" + $AppFullName + "_msi.log"

$MSI = Join-Path -Path $ScriptPath -ChildPath "LexiDesktop5-5.50.4.msi"
$LicenseFile = Get-ChildItem -Path $ScriptPath -Filter "*.lexlicense" -File | Select-Object -First 1
$ProductCode = "{62C04CF7-DAA4-309D-8CC0-D46DC24959B2}"
$InstallDir = Join-Path -Path ${env:ProgramFiles} -ChildPath "Leximancer\LexiDesktop5"
$LicenseTargetDirs = @(
    (Join-Path -Path $InstallDir -ChildPath "app\config"),
    (Join-Path -Path $InstallDir -ChildPath "app"),
    $InstallDir
)

$Arguments = @(
    "/i"
    "`"$MSI`""
    "/quiet"
    "/norestart"
    "ALLUSERS=1"
    "INSTALLDIR=`"$InstallDir`""
    "/L*v `"$MSIInstallLog`""
)

Start-Transcript -Path $InstallLog -Append -NoClobber
Write-Host "$(Get-Date) * Starting install of $AppFullName (MSI) *"
Write-Host "$(Get-Date) * Application Version: $AppDisplayVersion *"
Write-Host "$(Get-Date) * Product Code: $ProductCode *"
Write-Host "$(Get-Date) * Install directory: $InstallDir *"

if (!(Test-Path -Path $MSI -PathType Leaf)) {
    Write-Host "$(Get-Date) MSI not found: $MSI"
    Stop-Transcript
    $Host.SetShouldExit(2)
    EXIT 2
}

$Install = (Start-Process "msiexec.exe" -Wait -ArgumentList $Arguments -PassThru)
$SuccessExitCodes = @(0, 3010)

If ($SuccessExitCodes -notcontains $Install.ExitCode) {
    Write-Host "$(Get-Date) $AppFullName install failed. Exit Code: $($Install.ExitCode)"
}
Else {
    Write-Host "$(Get-Date) $AppFullName install succeeded. Exit Code: $($Install.ExitCode)"

    if ($LicenseFile) {
        foreach ($LicenseTargetDir in $LicenseTargetDirs) {
            New-Item -Path $LicenseTargetDir -ItemType Directory -Force | Out-Null
            $TargetLicense = Join-Path -Path $LicenseTargetDir -ChildPath "leximancer.lexlicense"
            Copy-Item -LiteralPath $LicenseFile.FullName -Destination $TargetLicense -Force
            Write-Host "$(Get-Date) License file copied to: $TargetLicense"
        }

        $ProfileRoots = @()
        $DefaultProfileLocal = "C:\Users\Default\AppData\Local\com.leximancer.desktop"
        $ProfileRoots += $DefaultProfileLocal
        $ProfileRoots += Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @("Default", "Default User", "Public", "All Users") } |
            ForEach-Object { Join-Path -Path $_.FullName -ChildPath "AppData\Local\com.leximancer.desktop" }

        foreach ($ProfileRoot in ($ProfileRoots | Select-Object -Unique)) {
            New-Item -Path $ProfileRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            if (Test-Path -Path $ProfileRoot) {
                $TargetLicense = Join-Path -Path $ProfileRoot -ChildPath "leximancer.lexlicense"
                Copy-Item -LiteralPath $LicenseFile.FullName -Destination $TargetLicense -Force -ErrorAction SilentlyContinue
                if (Test-Path -Path $TargetLicense) {
                    Write-Host "$(Get-Date) User profile license file copied to: $TargetLicense"
                } else {
                    Write-Host "$(Get-Date) Could not copy user profile license file to: $TargetLicense"
                }
            }
        }
    } else {
        Write-Host "$(Get-Date) No .lexlicense file found next to installer. License injection skipped."
    }
}

Stop-Transcript
$Host.SetShouldExit($Install.ExitCode)
EXIT $Install.ExitCode
