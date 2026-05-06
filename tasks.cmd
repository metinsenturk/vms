@echo off
REM Windows CMD wrapper for tasks.ps1
REM Allows calling .\tasks.cmd hub up from CMD prompt

if "%~1"=="" (
    echo Usage: %~n0 ^<target^> ^<action^> [args...]
    echo Example: %~n0 hub up
    echo For help: %~n0 help
    exit /b 1
)

REM Pass all arguments to PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tasks.ps1" %*