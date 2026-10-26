@echo off
REM Windows X-Lite 26H1 first-boot setup v4 (dockurr copies ./oem to C:\OEM,
REM then runs install.bat as the last step of automatic installation).
REM v4 changes (2026-10-25, lean 4-core rebuild): one-time first-logon script
REM sets a fixed 1 GB pagefile (system-managed pagefile on 8 GB RAM eats
REM ~10 GB; the download reuses the freed blocks), then reboots once and
REM deletes itself. All winget installs pin --source winget (the msstore
REM source threw a cert-mismatch error on the 2026-10-25 build).
REM Note: the pagefile applies at first logon, AFTER install.bat finishes,
REM so it is not part of the setup-done gate; verify it separately.
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
if %WINGET_OK%==1 winget install --id Brave.Brave -e --silent --source winget --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
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
if %BRAVE_OK%==0 if %WINGET_OK%==1 winget install --id Microsoft.Edge --silent --source winget --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
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
if %WINGET_OK%==1 winget install --id FreeDownloadManager.FreeDownloadManager --silent --source winget --accept-source-agreements --accept-package-agreements >> C:\OEM\setup-log.txt 2>&1
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

REM --- StartAllBack welcome: one-time closer at first logon ---
REM X-Lite bundles StartAllBack, whose first-run welcome window ("Where do you
REM want to go today?") blocks the desktop until someone picks a layout. There
REM is no documented registry value to suppress it, so instead this drops a
REM one-time script into the all-users Startup folder. At first logon it tries
REM every 10s for ~60s to close the StartAllBack configurator process
REM (StartAllBackCfg.exe, verified as the config app's process name), then
REM deletes itself. StartAllBack itself stays installed with defaults; only
REM the blocking welcome window is closed. Best-effort: if X-Lite's welcome
REM is hosted elsewhere, the script harmlessly does nothing and one manual
REM click on the default still closes it.
echo @echo off > "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo REM One-time StartAllBack welcome closer, dropped by C:\OEM\install.bat. Deletes itself after running. >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo timeout /t 10 /nobreak ^>nul >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo taskkill /IM StartAllBackCfg.exe /F ^>nul 2^>^&1 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo timeout /t 10 /nobreak ^>nul >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo taskkill /IM StartAllBackCfg.exe /F ^>nul 2^>^&1 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo timeout /t 10 /nobreak ^>nul >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo taskkill /IM StartAllBackCfg.exe /F ^>nul 2^>^&1 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo timeout /t 10 /nobreak ^>nul >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo taskkill /IM StartAllBackCfg.exe /F ^>nul 2^>^&1 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo timeout /t 10 /nobreak ^>nul >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo taskkill /IM StartAllBackCfg.exe /F ^>nul 2^>^&1 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo timeout /t 10 /nobreak ^>nul >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo taskkill /IM StartAllBackCfg.exe /F ^>nul 2^>^&1 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo del "%%~f0" >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\close-startallback-welcome.cmd"
echo [%DATE% %TIME%] StartAllBack welcome closer installed to all-users Startup >> C:\OEM\setup-log.txt

REM --- Small fixed pagefile: one-time script at first logon ---
REM System-managed pagefile on 8 GB RAM eats ~10 GB of the 32 GB codespace
REM disk and helped fill it during the 2026-10-25 Part 2 download. This drops
REM a one-time script into the all-users Startup folder: at first logon it
REM sets a fixed 1 GB pagefile (plenty for a browser + downloader VM),
REM deletes itself, and reboots once so the new size takes effect. The
REM download reuses the freed blocks in the sparse disk image. The script
REM logs to C:\OEM\pagefile-log.txt. Runs once only.
mkdir "C:\ProgramData\pcfree-setup" >> C:\OEM\setup-log.txt 2>&1
echo $cs = Get-CimInstance Win32_ComputerSystem > "C:\ProgramData\pcfree-setup\set-pagefile.ps1"
echo $cs.AutomaticManagedPagefile = $false >> "C:\ProgramData\pcfree-setup\set-pagefile.ps1"
echo Set-CimInstance -InputObject $cs >> "C:\ProgramData\pcfree-setup\set-pagefile.ps1"
echo $pf = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue >> "C:\ProgramData\pcfree-setup\set-pagefile.ps1"
echo if ($pf) { $pf.InitialSize = 1024; $pf.MaximumSize = 1024; Set-CimInstance -InputObject $pf } else { New-CimInstance -ClassName Win32_PageFileSetting -Arguments @{Name='C:\pagefile.sys'; InitialSize=1024; MaximumSize=1024} } >> "C:\ProgramData\pcfree-setup\set-pagefile.ps1"
echo Get-CimInstance Win32_PageFileSetting ^| Format-List Name,InitialSize,MaximumSize ^| Out-File C:\OEM\pagefile-log.txt -Append >> "C:\ProgramData\pcfree-setup\set-pagefile.ps1"
echo @echo off > "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\set-pagefile-once.cmd"
echo REM One-time pagefile shrink, dropped by C:\OEM\install.bat. Sets a fixed 1 GB pagefile, then reboots once and deletes itself. >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\set-pagefile-once.cmd"
echo powershell -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\pcfree-setup\set-pagefile.ps1" ^>^> C:\OEM\pagefile-log.txt 2^>^&1 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\set-pagefile-once.cmd"
echo del "C:\ProgramData\pcfree-setup\set-pagefile.ps1" >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\set-pagefile-once.cmd"
echo del "%%~f0" >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\set-pagefile-once.cmd"
echo shutdown /r /t 30 >> "%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp\set-pagefile-once.cmd"
echo [%DATE% %TIME%] pagefile once-script installed to all-users Startup >> C:\OEM\setup-log.txt

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
