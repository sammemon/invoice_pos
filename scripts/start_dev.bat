@echo off
title Invoice POS - Development Mode
color 0B
echo ============================================================
echo   Invoice POS - Development Environment
echo   Backend: http://localhost:5000   DB: Neon PostgreSQL
echo ============================================================
echo.

set ROOT=%~dp0..

echo [0/2] Freeing port 5000 (killing any leftover server)...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":5000 " ^| findstr "LISTENING"') do (
    echo        Killing PID %%P on port 5000...
    taskkill /PID %%P /F >nul 2>&1
)
timeout /t 1 /nobreak >nul

echo [1/2] Starting backend server (nodemon - auto-reloads on change)...
start "Invoice POS - Backend" cmd /k "cd /d "%ROOT%\backend" && npm run dev"
timeout /t 3 /nobreak >nul

:: Health check
curl -s http://localhost:5000/health >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Backend is up at http://localhost:5000
) else (
    echo [WARN] Backend still starting — Flutter app will retry automatically.
)

echo.
echo [2/2] Starting Flutter Windows app (hot-reload enabled)...
cd /d "%ROOT%\app"
flutter run -d windows
