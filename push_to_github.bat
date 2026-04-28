@echo off
title Push to GitHub
color 0B
echo ============================================================
echo   Invoice POS Backend — Push to GitHub
echo ============================================================
echo.
echo Step 1: Go to https://github.com/new
echo         Create a NEW repository named:  invoice-pos-backend
echo         Set it to PUBLIC
echo         Do NOT add README or .gitignore
echo         Click "Create repository"
echo.
echo Step 2: Come back here and paste your GitHub username below.
echo.
set /p USERNAME=Enter your GitHub username:

echo.
echo Connecting to GitHub...
git remote remove origin >nul 2>&1
git remote add origin https://github.com/%USERNAME%/invoice-pos-backend.git

echo Pushing code...
git push -u origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    color 0A
    echo [SUCCESS] Code is now on GitHub!
    echo.
    echo Your repo URL:
    echo   https://github.com/%USERNAME%/invoice-pos-backend
    echo.
    echo Next step: Deploy to Koyeb
    echo   1. Go to https://koyeb.com
    echo   2. Sign up free
    echo   3. New App - Connect GitHub - select invoice-pos-backend
    echo   4. Add environment variables from backend\.env
    echo   5. Deploy!
    echo.
    start https://github.com/%USERNAME%/invoice-pos-backend
) else (
    echo.
    color 0C
    echo [ERROR] Push failed.
    echo.
    echo If asked for password - use a GitHub Personal Access Token, not your password.
    echo Get one at: https://github.com/settings/tokens/new
    echo   - Select: repo (full control)
    echo   - Copy the token and paste it as the password
    echo.
)
pause
