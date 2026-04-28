@echo off
title Build Android APK
color 0A
echo ============================================================
echo   Invoice POS - Build Android APK
echo ============================================================
echo.

set ROOT=%~dp0..
set APP=%ROOT%\app
set DIST=%ROOT%\dist

cd /d "%APP%"

echo [1/4] Checking Flutter...
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter not found. Install from https://flutter.dev
    pause & exit /b 1
)

echo.
echo [2/4] Accepting Android licenses...
echo y | flutter doctor --android-licenses >nul 2>&1

echo.
echo [3/4] Installing dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (echo [ERROR] pub get failed & pause & exit /b 1)

echo.
echo [4/4] Building release APK (split per ABI for smaller size)...
flutter build apk --release --split-per-abi
if %ERRORLEVEL% NEQ 0 (echo [ERROR] Build failed & pause & exit /b 1)

echo.
echo Copying APKs to dist\apk\...
if not exist "%DIST%\apk" mkdir "%DIST%\apk"
copy /y "build\app\outputs\flutter-apk\*.apk" "%DIST%\apk\" >nul

echo.
echo ============================================================
echo   SUCCESS! APK files:
echo ============================================================
dir /b "%DIST%\apk\*.apk"
echo.
echo   arm64-v8a  → for modern Android phones (recommended)
echo   armeabi-v7a → for older Android phones
echo   x86_64     → for emulators
echo.
echo   Copy the arm64-v8a APK to the device and install.
echo   (Enable "Install from unknown sources" in Android settings)
echo.
pause
