@echo off
cd /d "C:\Users\106692\Documents\Codex\2026-06-11\leximancer-package\outputs\Leximancer\Install"
echo Running Leximancer install as LocalSystem with PsExec...
echo.
"C:\Users\106692\Documents\Codex\2026-06-11\leximancer-package\outputs\Leximancer\Install\PsExec.exe" -accepteula -s -nobanner powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\106692\Documents\Codex\2026-06-11\leximancer-package\outputs\Leximancer\Install\Leximancer_Install.ps1" -RunAsSystemPayload
set EXITCODE=%ERRORLEVEL%
echo.
echo Leximancer install finished with exit code %EXITCODE%.
pause
exit /b %EXITCODE%
