@echo off
rem Installs or updates Rheizor. Put it inside World of Warcraft\<version>\Interface\AddOns
rem and double-click it. It always downloads the newest updater from the repo.
setlocal
set "ADDONS=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $f=Join-Path $env:TEMP 'rheizor-update.ps1'; try { Invoke-WebRequest -UseBasicParsing ('https://raw.githubusercontent.com/jaimesares/rheizor-ui-releases/main/tools/update.ps1?t=' + [DateTime]::UtcNow.Ticks) -OutFile $f } catch { Write-Host ('Could not download the updater: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }; & $f -AddOns $env:ADDONS"
echo.
pause
