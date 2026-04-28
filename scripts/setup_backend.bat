@echo off
title Setup Backend Server
color 0B
echo ============================================================
echo   Invoice POS - Backend Server Setup (PostgreSQL)
echo ============================================================
echo.

cd /d "%~dp0..\backend"

echo [1/3] Checking Node.js...
node --version
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js not found. Download from https://nodejs.org
    pause & exit /b 1
)

echo.
echo [2/3] Installing dependencies...
npm install
if %ERRORLEVEL% NEQ 0 (echo ERROR: npm install failed & pause & exit /b 1)

echo.
echo [3/3] Checking .env file...
if not exist ".env" (
    echo Creating .env from example...
    copy ".env.example" ".env"
    echo.
    echo *** IMPORTANT: Edit backend\.env and set your DATABASE_URL ***
    echo.
    notepad .env
    echo.
    pause
)

echo.
echo Running database migration...
npm run migrate
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [WARN] Migration failed - is PostgreSQL running and DATABASE_URL correct?
    echo        Edit backend\.env then run: npm run migrate
)

echo.
echo ============================================================
echo   Backend ready!
echo.
echo   Start server:  npm start
echo   Development:   npm run dev
echo   Re-migrate:    npm run migrate
echo ============================================================
echo.
pause
