@echo off
REM Windows CMD wrapper for tasks.ps1
REM Allows calling .\tasks.cmd up hub from CMD prompt

if "%~1"=="" (
    echo Usage: %~n0 ^<command^> [vm] [args...]
    echo Example: %~n0 up hub
    echo For help: %~n0 help
    exit /b 1
)

REM Pass all arguments to PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tasks.ps1" %*