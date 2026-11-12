@echo off
rem Runs Build-TinkwaniosStatic.ps1 even when PowerShell script execution is disabled.
rem -ExecutionPolicy Bypass applies to this one PowerShell process only.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-TinkwaniosStatic.ps1" %*
exit /b %ERRORLEVEL%
