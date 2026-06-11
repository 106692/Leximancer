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

    Write-Host "$(Get-Date) Relaunching uninstall as LocalSystem with PsExec."
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
$UninstallLog = "C:\ITD\Logs\" + $AppFullName + "_script_uninstall.log"
$MSIUninstallLog = "C:\ITD\Logs\" + $AppFullName + "_uninst_msi.log"

$ProductCode = "{62C04CF7-DAA4-309D-8CC0-D46DC24959B2}"
$InstallRoot = Join-Path -Path ${env:ProgramFiles} -ChildPath "Leximancer"
$InstallDir = Join-Path -Path ${env:ProgramFiles} -ChildPath "Leximancer\LexiDesktop5"
$Arguments = @("/x", "`"$ProductCode`"", "/quiet", "/norestart", "/L*v `"$MSIUninstallLog`"")

function Stop-LeximancerProcesses {
    param(
        [string]$Reason
    )

    Write-Host "$(Get-Date) Checking for running Leximancer processes before $Reason."

    $ProcessIds = @()
    $ProcessIds += Get-Process -Name "LexiDesktop5" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id
    $ProcessIds += Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExecutablePath -like "$InstallDir\*" -or
            $_.CommandLine -like "*LexiDesktop5*"
        } |
        Select-Object -ExpandProperty ProcessId

    foreach ($ProcessId in ($ProcessIds | Where-Object { $_ } | Sort-Object -Unique)) {
        try {
            $Process = Get-Process -Id $ProcessId -ErrorAction Stop
            Write-Host "$(Get-Date) Stopping process $($Process.ProcessName) (PID $ProcessId)."
            Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        } catch {
            Write-Host "$(Get-Date) Process PID $ProcessId is not running or could not be stopped. $($_.Exception.Message)"
        }
    }

    Start-Sleep -Seconds 2
}

function Remove-LeximancerDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (!(Test-Path -LiteralPath $Path)) {
        return $true
    }

    try {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Attributes = "Normal" }
    } catch {
        Write-Host "$(Get-Date) Could not reset attributes under $Path. $($_.Exception.Message)"
    }

    foreach ($Attempt in 1..3) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "$(Get-Date) Attempt $Attempt failed to remove $Path. $($_.Exception.Message)"
        }

        if (!(Test-Path -LiteralPath $Path)) {
            return $true
        }

        Start-Sleep -Seconds 2
    }

    return (!(Test-Path -LiteralPath $Path))
}

Start-Transcript -Path $UninstallLog -Append -NoClobber
Write-Host "$(Get-Date) * Starting uninstall of $AppFullName (MSI) *"
Write-Host "$(Get-Date) * Application Version: $AppDisplayVersion *"
Write-Host "$(Get-Date) * Product Code: $ProductCode *"

Stop-LeximancerProcesses -Reason "MSI uninstall"

$Uninstall = (Start-Process "msiexec.exe" -Wait -ArgumentList $Arguments -PassThru)
$SuccessExitCodes = @(0, 1605, 3010)
$ExitCode = $Uninstall.ExitCode

If ($SuccessExitCodes -notcontains $Uninstall.ExitCode) {
    Write-Host "$(Get-Date) $AppFullName uninstall failed. Exit Code: $($Uninstall.ExitCode)"
}
Else {
    if ($Uninstall.ExitCode -eq 1605) {
        Write-Host "$(Get-Date) $AppFullName is not installed. Treating MSI 1605 as success."
        $ExitCode = 0
    } elseif ($Uninstall.ExitCode -eq 3010) {
        Write-Host "$(Get-Date) $AppFullName uninstall succeeded and MSI requested reboot. Treating MSI 3010 as script success."
        $ExitCode = 0
    } else {
        Write-Host "$(Get-Date) $AppFullName uninstall succeeded. Exit Code: $($Uninstall.ExitCode)"
    }

    Stop-LeximancerProcesses -Reason "post-uninstall cleanup"

    if (Test-Path -Path $InstallDir) {
        if (Remove-LeximancerDirectory -Path $InstallDir) {
            Write-Host "$(Get-Date) Removed remaining install directory: $InstallDir"
        } else {
            Write-Host "$(Get-Date) Could not remove remaining install directory: $InstallDir"
        }
    }

    if (Test-Path -Path $InstallRoot) {
        $RemainingItems = @(Get-ChildItem -LiteralPath $InstallRoot -Force -ErrorAction SilentlyContinue)
        if ($RemainingItems.Count -eq 0) {
            if (Remove-LeximancerDirectory -Path $InstallRoot) {
                Write-Host "$(Get-Date) Removed empty install root: $InstallRoot"
            } else {
                Write-Host "$(Get-Date) Could not remove empty install root: $InstallRoot"
            }
        } else {
            Write-Host "$(Get-Date) Install root not removed because it still contains files or folders: $InstallRoot"
        }
    }

    $ProfileLicensePaths = @("C:\Users\Default\AppData\Local\com.leximancer.desktop\leximancer.lexlicense")
    $ProfileLicensePaths += Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Default", "Default User", "Public", "All Users") } |
        ForEach-Object { Join-Path -Path $_.FullName -ChildPath "AppData\Local\com.leximancer.desktop\leximancer.lexlicense" }

    foreach ($ProfileLicensePath in ($ProfileLicensePaths | Select-Object -Unique)) {
        if (Test-Path -Path $ProfileLicensePath) {
            Remove-Item -LiteralPath $ProfileLicensePath -Force -ErrorAction SilentlyContinue
            Write-Host "$(Get-Date) Removed user profile license file: $ProfileLicensePath"
        }
    }
}

Stop-Transcript
$Host.SetShouldExit($ExitCode)
EXIT $ExitCode
