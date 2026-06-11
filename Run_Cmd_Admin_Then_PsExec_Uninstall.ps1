$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = $PWD.Path }

$psexecPath = Join-Path $scriptRoot "PsExec.exe"
if (-not (Test-Path -Path $psexecPath -PathType Leaf)) { $psexecPath = "PsExec.exe" }

$uninstallScript = Join-Path $scriptRoot "Leximancer_Uninstall.ps1"

$batchContent = @"
@echo off
cd /d `"$scriptRoot`"
echo Running Leximancer uninstall as LocalSystem with PsExec...
echo.
`"$psexecPath`" -accepteula -s -nobanner powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstallScript`" -RunAsSystemPayload
set EXITCODE=%ERRORLEVEL%
echo.
echo Leximancer uninstall finished with exit code %EXITCODE%.
pause
exit /b %EXITCODE%
"@

$batchPath = Join-Path $scriptRoot "PsExec_Sequence_Uninstall.bat"
$batchContent | Out-File -FilePath $batchPath -Encoding ASCII -Force

if ($isAdmin) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/k `"$batchPath`"" | Out-Null
} else {
    Start-Process -FilePath "cmd.exe" -Verb RunAs -ArgumentList "/k `"$batchPath`"" | Out-Null
}
