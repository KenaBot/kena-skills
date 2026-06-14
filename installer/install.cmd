@echo off
REM install.cmd — entry point for double-click on Windows
REM Forwards all args to install.ps1

setlocal
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*
endlocal
