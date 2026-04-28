@echo off
title Invoice POS - Production Release Builder
color 0E
echo.
echo  ██████████████████████████████████████████████████
echo  █                                                █
echo  █      Invoice ^& POS  —  Release Builder         █
echo  █                                                █
echo  ██████████████████████████████████████████████████
echo.

set ROOT=%~dp0..
set DIST=%ROOT%\dist
set ISCC=

:: Locate Inno Setup compiler (checks standard + winget user install paths)
for %%P in (
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
) do (if exist %%P set ISCC=%%P)

:: ── STEP 1: Preflight checks ─────────────────────────────────────
echo [STEP 1/5]  Preflight checks...

flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo  [X] Flutter not found. Download from https://flutter.dev
    pause & exit /b 1
)
echo  [OK] Flutter found.

node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo  [X] Node.js not found. Download from https://nodejs.org
    pause & exit /b 1
)
echo  [OK] Node.js found.

pkg --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo  Installing pkg globally...
    npm install -g pkg >nul 2>&1
)
echo  [OK] pkg found.

if "%ISCC%"=="" (
    echo.
    echo  [!] Inno Setup 6 not found.
    echo      Download free from: https://jrsoftware.org/isdl.php
    echo      Install it, then re-run this script.
    echo.
    start https://jrsoftware.org/isdl.php
    pause & exit /b 1
)
echo  [OK] Inno Setup found.

:: Kill anything on port 5000
for /f "tokens=5" %%P in ('netstat -ano 2^>nul ^| findstr ":5000 " ^| findstr "LISTENING"') do (
    taskkill /PID %%P /F >nul 2>&1
)

:: ── STEP 2: Build Flutter Windows app ────────────────────────────
echo.
echo [STEP 2/5]  Building Flutter Windows app (this takes 1-3 minutes)...
cd /d "%ROOT%\app"
flutter config --enable-windows-desktop >nul 2>&1
flutter pub get >nul 2>&1
flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo  [X] Flutter build failed. See errors above.
    pause & exit /b 1
)

:: Copy Flutter output
if not exist "%DIST%\windows" mkdir "%DIST%\windows"
xcopy /s /e /y /q "build\windows\x64\runner\Release\*" "%DIST%\windows\" >nul
echo  [OK] Flutter app built → dist\windows\

:: ── STEP 3: Compile backend server exe ───────────────────────────
echo.
echo [STEP 3/5]  Compiling backend server to .exe...
cd /d "%ROOT%\backend"
npm install >nul 2>&1
npm run compile
if %ERRORLEVEL% NEQ 0 (
    echo  [X] Backend compile failed. See errors above.
    pause & exit /b 1
)

:: Copy .env next to the server exe
if exist ".env" (
    copy /y ".env" "dist\.env" >nul
) else if exist ".env.example" (
    copy /y ".env.example" "dist\.env" >nul
    echo  [!] No .env found — using .env.example. Edit backend\dist\.env if needed.
)
echo  [OK] Backend compiled → backend\dist\invoice_pos_server.exe

:: ── STEP 4: Prepare output folders ───────────────────────────────
echo.
echo [STEP 4/5]  Preparing installer output...
if not exist "%DIST%\installer" mkdir "%DIST%\installer"
echo  [OK] dist\installer\ ready.

:: ── STEP 5: Build Inno Setup installer ───────────────────────────
echo.
echo [STEP 5/5]  Compiling installer (Inno Setup)...
%ISCC% "%ROOT%\scripts\create_installer.iss"
if %ERRORLEVEL% NEQ 0 (
    echo  [X] Inno Setup compilation failed.
    pause & exit /b 1
)

:: ── Done ─────────────────────────────────────────────────────────
echo.
color 0A
echo  ██████████████████████████████████████████████████
echo  █                                                █
echo  █   BUILD COMPLETE — Ready to distribute!        █
echo  █                                                █
echo  ██████████████████████████████████████████████████
echo.
echo  Installer: dist\installer\InvoicePOS_Setup_v1.0.0.exe
echo  Size:
dir /b "%DIST%\installer\InvoicePOS_Setup_v1.0.0.exe" 2>nul
echo.
echo  Share this single file with anyone.
echo  They double-click it and follow the wizard. Done.
echo.

:: Open the installer folder
explorer "%DIST%\installer"
pause
