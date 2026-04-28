@echo off
title Build Windows Release
color 0A
echo ============================================================
echo   Invoice POS - Full Windows Build
echo   Flutter app + Backend exe + Inno Setup installer
echo ============================================================
echo.

set ROOT=%~dp0..
set APP=%ROOT%\app
set BACKEND=%ROOT%\backend
set DIST=%ROOT%\dist

:: ─── 1. Flutter Windows app ──────────────────────────────
echo [1/4] Building Flutter Windows app...
cd /d "%APP%"
flutter config --enable-windows-desktop >nul
flutter pub get
if %ERRORLEVEL% NEQ 0 (echo [ERROR] pub get failed & pause & exit /b 1)
flutter build windows --release
if %ERRORLEVEL% NEQ 0 (echo [ERROR] Flutter build failed & pause & exit /b 1)

echo       Copying Flutter output to dist\windows...
if not exist "%DIST%\windows" mkdir "%DIST%\windows"
xcopy /s /e /y "build\windows\x64\runner\Release\*" "%DIST%\windows\" >nul
echo [OK] Flutter app built.

:: ─── 2. Backend exe ──────────────────────────────────────
echo.
echo [2/4] Compiling backend server to exe...
cd /d "%BACKEND%"
npm install >nul 2>&1
npm run compile
if %ERRORLEVEL% NEQ 0 (echo [ERROR] pkg compile failed & pause & exit /b 1)

:: Copy .env next to the server exe so it is read at runtime
if exist ".env" (
    copy /y ".env" "dist\.env" >nul
    echo       Copied .env to backend\dist\.env
) else (
    copy /y ".env.example" "dist\.env" >nul
    echo [WARN] No .env found — copied .env.example. Edit dist\.env before packaging!
)
echo [OK] Backend exe compiled ^(dist\invoice_pos_server.exe^).

:: ─── 3. Installer dist folder ────────────────────────────
echo.
echo [3/4] Preparing installer output folder...
if not exist "%DIST%\installer" mkdir "%DIST%\installer"
echo [OK] dist\installer ready.

:: ─── 4. Inno Setup ───────────────────────────────────────
echo.
echo [4/4] Compiling Inno Setup installer...
set ISCC=""
for %%P in (
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
) do (if exist %%P set ISCC=%%P)

if %ISCC%=="" (
    echo.
    echo [WARN] Inno Setup not found. Download from https://jrsoftware.org/isinfo.php
    echo        Then run manually: ISCC.exe "%~dp0create_installer.iss"
) else (
    %ISCC% "%~dp0create_installer.iss"
    if %ERRORLEVEL% NEQ 0 (echo [ERROR] Inno Setup compile failed & pause & exit /b 1)
    echo [OK] Installer created in dist\installer\
)

echo.
echo ============================================================
echo   BUILD COMPLETE
echo.
echo   Flutter app  : dist\windows\invoice_pos.exe
echo   Backend exe  : backend\dist\invoice_pos_server.exe
echo   Installer    : dist\installer\InvoicePOS_Setup_1.0.0.exe
echo ============================================================
echo.
pause
