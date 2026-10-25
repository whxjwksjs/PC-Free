@echo off
REM Windows X-Lite 26H1 first-boot setup (dockurr copies ./oem to C:\OEM,
REM then runs install.bat as the last step of automatic installation).
REM Best-effort throughout: never fail the install. Log: C:\OEM\setup-log.txt
echo [%DATE% %TIME%] setup start > C:\OEM\setup-log.txt

REM Hibernation off (no-op on X-Lite, harmless)
powercfg /h off >> C:\OEM\setup-log.txt 2>&1

REM No auto-reboot on Windows Update while a user is logged on
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >> C:\OEM\setup-log.txt 2>&1

REM --- winget repair (best-effort) ---
echo [%DATE% %TIME%] winget repair >> C:\OEM\setup-log.txt
powershell -NoProfile -Command "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" >> C:\OEM\setup-log.txt 2>&1
where winget >> C:\OEM\setup-log.txt 2>&1
if errorlevel 1 (
  echo [%DATE% %TIME%] winget missing, fetching DesktopAppInstaller >> C:\OEM\setup-log.txt
  powershell -NoProfile -Command "$rel = Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest; $asset = $rel.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1; Invoke-WebRequest $asset.browser_download_url -OutFile $env:TEMP\DesktopAppInstaller.msixbundle; Add-AppxPackage $env:TEMP\DesktopAppInstaller.msixbundle" >> C:\OEM\setup-log.txt 2>&1
)
where winget >> C:\OEM\setup-log.txt 2>&1
if errorlevel 1 (
  echo [%DATE% %TIME%] winget still missing, using fallbacks below >> C:\OEM\setup-log.txt
) else (
  winget --version >> C:\OEM\setup-log.txt 2>&1
)

REM --- Edge first (build ships no browser) ---
REM 1. Included browser installer, if present on a Desktop
set EDGESETUP=
for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-ChildItem -Path $env:USERPROFILE\Desktop,$env:PUBLIC\Desktop -Filter *Edge*.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName"') do set EDGESETUP=%%I
if defined EDGESETUP (
  echo [%DATE% %TIME%] installing included Edge installer: %EDGESETUP% >> C:\OEM\setup-log.txt
  "%EDGESETUP%" /silent /install >> C:\OEM\setup-log.txt 2>&1
)
REM 2. winget
where winget >nul 2>&1
if not errorlevel 1 (
  where msedge >nul 2>&1
  if errorlevel 1 (
    echo [%DATE% %TIME%] winget installing Edge >> C:\OEM\setup-log.txt
    winget install --id Microsoft.Edge --silent --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
  )
)
REM 3. Last resort: desktop shortcut to the Edge download page
where msedge >nul 2>&1
if errorlevel 1 (
  echo [%DATE% %TIME%] Edge install did not land, leaving download shortcut >> C:\OEM\setup-log.txt
  powershell -NoProfile -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:USERPROFILE + '\Desktop\Download Edge.lnk'); $s.TargetPath = 'https://www.microsoft.com/en-us/edge/download'; $s.Save()" >> C:\OEM\setup-log.txt 2>&1
)

REM --- Free Download Manager ---
where winget >nul 2>&1
if not errorlevel 1 (
  echo [%DATE% %TIME%] winget installing FDM >> C:\OEM\setup-log.txt
  winget install --id FreeDownloadManager.FreeDownloadManager --silent --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
)
if not exist "%ProgramFiles%\FreeDownloadManager\fdm.exe" (
  if not exist "%ProgramFiles(x86)%\FreeDownloadManager\fdm.exe" (
    echo [%DATE% %TIME%] FDM not installed via winget, trying direct download >> C:\OEM\setup-log.txt
    powershell -NoProfile -Command "$html = (Invoke-WebRequest https://www.freedownloadmanager.org/download.htm -UseBasicParsing).Content; $m = [regex]::Match($html, 'https?://[^''\s]+\.exe'); if ($m.Success) { Invoke-WebRequest $m.Value -OutFile $env:TEMP\fdm-setup.exe; Start-Process $env:TEMP\fdm-setup.exe -Wait }" >> C:\OEM\setup-log.txt 2>&1
  )
)
if not exist "%ProgramFiles%\FreeDownloadManager\fdm.exe" (
  if not exist "%ProgramFiles(x86)%\FreeDownloadManager\fdm.exe" (
    powershell -NoProfile -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:USERPROFILE + '\Desktop\Download FDM.lnk'); $s.TargetPath = 'https://www.freedownloadmanager.org/download.htm'; $s.Save()" >> C:\OEM\setup-log.txt 2>&1
  )
)

REM --- Edge extension force-installs (uBlock Origin Lite, FDM) ---
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "cimighlppcgcoapaliogpjjdehbnofhn;https://edge.microsoft.com/extensionwebstorebase/v1/crx" /f >> C:\OEM\setup-log.txt 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" /v "2" /t REG_SZ /d "ahmpjcflkgiildlgicmcieglgoilbfdp;https://clients2.google.com/service/update2/crx" /f >> C:\OEM\setup-log.txt 2>&1

echo [%DATE% %TIME%] setup done > C:\OEM\setup-done.txt
echo [%DATE% %TIME%] setup done >> C:\OEM\setup-log.txt
exit /b 0
