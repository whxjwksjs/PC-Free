@echo off
REM Windows X-Lite 26H1 first-boot setup v2 (dockurr copies ./oem to C:\OEM,
REM then runs install.bat as the last step of automatic installation).
REM v2 changes (2026-10-25, for future installs): Brave is the primary browser
REM (winget Brave.Brave), Edge stays as fallback; FDM fallback installer runs
REM truly silent (Inno switches, verified); extension force-install keys are
REM written for BOTH Brave (Chrome Web Store IDs) and Edge; and the marker is
REM verification-gated: setup-done.txt only when browser + FDM + extension
REM keys all check out, otherwise setup-failed.txt names what is missing.
REM Style note: single-line IFs only, no parenthesised blocks, because batch
REM breaks blocks that contain parentheses in their commands.
REM Best-effort throughout: never fail the install. Log: C:\OEM\setup-log.txt
echo [%DATE% %TIME%] setup start > C:\OEM\setup-log.txt

REM Hibernation off (no-op on X-Lite, harmless)
powercfg /h off >> C:\OEM\setup-log.txt 2>&1

REM No auto-reboot on Windows Update while a user is logged on
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >> C:\OEM\setup-log.txt 2>&1

REM --- winget repair (best-effort) ---
echo [%DATE% %TIME%] winget repair >> C:\OEM\setup-log.txt
powershell -NoProfile -Command "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" >> C:\OEM\setup-log.txt 2>&1
set WINGET_OK=0
where winget >nul 2>&1
if not errorlevel 1 set WINGET_OK=1
if %WINGET_OK%==0 echo [%DATE% %TIME%] winget missing, fetching DesktopAppInstaller >> C:\OEM\setup-log.txt
if %WINGET_OK%==0 powershell -NoProfile -Command "$rel = Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest; $asset = $rel.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1; Invoke-WebRequest $asset.browser_download_url -OutFile $env:TEMP\DesktopAppInstaller.msixbundle; Add-AppxPackage $env:TEMP\DesktopAppInstaller.msixbundle" >> C:\OEM\setup-log.txt 2>&1
where winget >nul 2>&1
if not errorlevel 1 set WINGET_OK=1
if %WINGET_OK%==1 winget --version >> C:\OEM\setup-log.txt 2>&1
if %WINGET_OK%==0 echo [%DATE% %TIME%] winget still missing, using fallbacks below >> C:\OEM\setup-log.txt

REM --- Browser: Brave first, Edge as fallback ---
if %WINGET_OK%==1 echo [%DATE% %TIME%] winget installing Brave >> C:\OEM\setup-log.txt
if %WINGET_OK%==1 winget install --id Brave.Brave -e --silent --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
set BRAVE_OK=0
if exist "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe" set BRAVE_OK=1
if exist "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe" set BRAVE_OK=1
if %BRAVE_OK%==0 echo [%DATE% %TIME%] Brave not present, trying Edge >> C:\OEM\setup-log.txt
REM Edge only if Brave is missing: included installer first, then winget.
set EDGESETUP=
if %BRAVE_OK%==0 for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-ChildItem -Path $env:USERPROFILE\Desktop,$env:PUBLIC\Desktop -Filter *Edge*.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName"') do set EDGESETUP=%%I
if defined EDGESETUP echo [%DATE% %TIME%] installing included Edge installer: %EDGESETUP% >> C:\OEM\setup-log.txt
if defined EDGESETUP "%EDGESETUP%" /silent /install >> C:\OEM\setup-log.txt 2>&1
if %BRAVE_OK%==0 if %WINGET_OK%==1 echo [%DATE% %TIME%] winget installing Edge >> C:\OEM\setup-log.txt
if %BRAVE_OK%==0 if %WINGET_OK%==1 winget install --id Microsoft.Edge --silent --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
REM Final browser check (explicit paths, not PATH lookup).
set BROWSER_OK=0
if exist "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe" set BROWSER_OK=1
if exist "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe" set BROWSER_OK=1
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set BROWSER_OK=1
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set BROWSER_OK=1
set EDGE_OK=0
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set EDGE_OK=1
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set EDGE_OK=1
if %BROWSER_OK%==0 echo [%DATE% %TIME%] NO BROWSER installed, winget path failed >> C:\OEM\setup-log.txt
if %BROWSER_OK%==0 echo No browser could be installed automatically. Winget failed and no included browser installer was found. See C:\OEM\setup-log.txt for details. > "%USERPROFILE%\Desktop\BROWSER-INSTALL-FAILED.txt"
REM Edge download shortcut only helps if some browser exists to open it.
if %BROWSER_OK%==1 if %EDGE_OK%==0 powershell -NoProfile -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:USERPROFILE + '\Desktop\Download Edge.lnk'); $s.TargetPath = 'https://www.microsoft.com/en-us/edge/download'; $s.Save()" >> C:\OEM\setup-log.txt 2>&1

REM --- Free Download Manager (silent) ---
if %WINGET_OK%==1 echo [%DATE% %TIME%] winget installing FDM >> C:\OEM\setup-log.txt
if %WINGET_OK%==1 winget install --id FreeDownloadManager.FreeDownloadManager --silent --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
set FDM_OK=0
if exist "%ProgramFiles%\FreeDownloadManager\fdm.exe" set FDM_OK=1
if exist "%ProgramFiles(x86)%\FreeDownloadManager\fdm.exe" set FDM_OK=1
if %FDM_OK%==0 echo [%DATE% %TIME%] FDM not installed via winget, trying direct download (silent Inno switches) >> C:\OEM\setup-log.txt
if %FDM_OK%==0 powershell -NoProfile -Command "$html = (Invoke-WebRequest https://www.freedownloadmanager.org/download.htm -UseBasicParsing).Content; $m = [regex]::Match($html, 'https?://[^''\s]+\.exe'); if ($m.Success) { Invoke-WebRequest $m.Value -OutFile $env:TEMP\fdm-setup.exe; Start-Process $env:TEMP\fdm-setup.exe -ArgumentList '/SP-','/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait }" >> C:\OEM\setup-log.txt 2>&1
if exist "%ProgramFiles%\FreeDownloadManager\fdm.exe" set FDM_OK=1
if exist "%ProgramFiles(x86)%\FreeDownloadManager\fdm.exe" set FDM_OK=1
if %FDM_OK%==0 echo [%DATE% %TIME%] FDM still missing, leaving download shortcut >> C:\OEM\setup-log.txt
if %FDM_OK%==0 powershell -NoProfile -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:USERPROFILE + '\Desktop\Download FDM.lnk'); $s.TargetPath = 'https://www.freedownloadmanager.org/download.htm'; $s.Save()" >> C:\OEM\setup-log.txt 2>&1

REM --- Extension force-installs, Brave AND Edge ---
REM Brave (Chrome Web Store IDs, Chrome update URL):
REM   uBlock Origin Lite ddkjiahejlhfcafbddmgiahcphecmpfh, FDM ahmpjcflkgiildlgicmcieglgoilbfdp
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx" /f >> C:\OEM\setup-log.txt 2>&1
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" /v "2" /t REG_SZ /d "ahmpjcflkgiildlgicmcieglgoilbfdp;https://clients2.google.com/service/update2/crx" /f >> C:\OEM\setup-log.txt 2>&1
REM Edge (Edge Add-ons ID for uBlock Lite, Chrome Web Store ID for FDM):
REM   uBlock Origin Lite cimighlppcgcoapaliogpjjdehbnofhn, FDM ahmpjcflkgiildlgicmcieglgoilbfdp
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "cimighlppcgcoapaliogpjjdehbnofhn;https://edge.microsoft.com/extensionwebstorebase/v1/crx" /f >> C:\OEM\setup-log.txt 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" /v "2" /t REG_SZ /d "ahmpjcflkgiildlgicmcieglgoilbfdp;https://clients2.google.com/service/update2/crx" /f >> C:\OEM\setup-log.txt 2>&1

REM --- Verification: confirm everything, gate the marker on it ---
echo [%DATE% %TIME%] verification >> C:\OEM\setup-log.txt
set VERIFY_FAIL=0
set MISSING=
if %BROWSER_OK%==0 set VERIFY_FAIL=1
if %BROWSER_OK%==0 set MISSING=%MISSING% browser
if %FDM_OK%==0 set VERIFY_FAIL=1
if %FDM_OK%==0 set MISSING=%MISSING% fdm
set EXT_OK=0
reg query "HKLM\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" /v "1" >nul 2>&1
if not errorlevel 1 set EXT_OK=1
reg query "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" /v "1" >nul 2>&1
if not errorlevel 1 set EXT_OK=1
if %EXT_OK%==0 set VERIFY_FAIL=1
if %EXT_OK%==0 set MISSING=%MISSING% extension-keys
echo [%DATE% %TIME%] verify: browser=%BROWSER_OK% fdm=%FDM_OK% ext-keys=%EXT_OK% >> C:\OEM\setup-log.txt
if %VERIFY_FAIL%==0 echo [%DATE% %TIME%] setup done > C:\OEM\setup-done.txt
if %VERIFY_FAIL%==0 echo [%DATE% %TIME%] setup done >> C:\OEM\setup-log.txt
if not %VERIFY_FAIL%==0 echo [%DATE% %TIME%] setup incomplete, missing:%MISSING% > C:\OEM\setup-failed.txt
if not %VERIFY_FAIL%==0 echo [%DATE% %TIME%] setup incomplete, missing:%MISSING% >> C:\OEM\setup-log.txt
exit /b 0
