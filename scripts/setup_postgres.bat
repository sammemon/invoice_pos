@echo off
title Setup PostgreSQL for Invoice POS
color 0B
echo ============================================================
echo   Invoice POS - PostgreSQL Database Setup
echo ============================================================
echo.

:: ─── Check if psql is already installed ────────────────────
where psql >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] PostgreSQL is already installed.
    psql --version
    goto :create_db
)

echo PostgreSQL is NOT installed.
echo.
echo OPTIONS:
echo  [1] Download PostgreSQL installer (recommended for local use)
echo  [2] Use Supabase (free cloud - no local install needed)
echo  [3] Use Neon (free serverless PostgreSQL)
echo  [4] Already have PostgreSQL - just create the database
echo.
set /p choice=Enter option (1-4):

if "%choice%"=="1" goto :download_postgres
if "%choice%"=="2" goto :supabase
if "%choice%"=="3" goto :neon
if "%choice%"=="4" goto :create_db
goto :end

:download_postgres
echo.
echo Opening PostgreSQL download page...
start https://www.postgresql.org/download/windows/
echo.
echo INSTRUCTIONS:
echo 1. Download and run the installer
echo 2. Set password for 'postgres' user (remember it!)
echo 3. Keep default port 5432
echo 4. After install, run THIS script again
echo.
pause
goto :end

:supabase
echo.
echo ============================================================
echo   Using Supabase (Free Cloud PostgreSQL)
echo ============================================================
echo.
echo 1. Go to: https://supabase.com
echo 2. Sign up (free) and create a new project
echo 3. Go to: Settings ^> Database
echo 4. Copy the "Connection string" (URI format)
echo 5. Paste it into backend\.env as DATABASE_URL
echo.
echo Example:
echo DATABASE_URL=postgresql://postgres:[password]@db.[project].supabase.co:5432/postgres
echo.
echo NOTE: Set NODE_ENV=production in .env so SSL is enabled automatically.
echo.
start https://supabase.com
pause
goto :configure_env

:neon
echo.
echo ============================================================
echo   Using Neon (Free Serverless PostgreSQL)
echo ============================================================
echo.
echo 1. Go to: https://neon.tech
echo 2. Sign up (free) and create a database
echo 3. Copy the connection string
echo 4. Paste into backend\.env as DATABASE_URL
echo.
start https://neon.tech
pause
goto :configure_env

:create_db
echo.
echo ============================================================
echo   Creating database: invoice_pos
echo ============================================================
echo.
set /p PG_PASS=Enter PostgreSQL password for 'postgres' user:
echo.

set PGPASSWORD=%PG_PASS%
psql -U postgres -c "CREATE DATABASE invoice_pos;" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Database 'invoice_pos' created.
) else (
    echo [INFO] Database may already exist - continuing...
)

echo.
echo Running schema migration...
psql -U postgres -d invoice_pos -f "%~dp0..\backend\src\config\schema.sql"
if %ERRORLEVEL% EQU 0 (
    echo [OK] Schema applied - all tables created!
) else (
    echo [ERROR] Schema migration failed. Check PostgreSQL is running.
    pause & exit /b 1
)

echo.
echo Updating backend\.env ...
(
echo PORT=5000
echo NODE_ENV=development
echo DATABASE_URL=postgresql://postgres:%PG_PASS%@localhost:5432/invoice_pos
echo JWT_SECRET=InvoicePOS_SuperSecretKey_2024_ChangeInProduction_Min32Chars
echo JWT_EXPIRE=7d
echo CURRENT_APP_VERSION=1.0.0
echo APK_DOWNLOAD_URL=https://yourdomain.com/downloads/app-release.apk
) > "%~dp0..\backend\.env"

echo [OK] .env updated with local PostgreSQL connection.
goto :done

:configure_env
echo.
echo Remember to update backend\.env with your DATABASE_URL.
echo Then run: cd backend ^&^& npm run migrate
goto :done

:done
echo.
echo ============================================================
echo   PostgreSQL setup complete!
echo.
echo   Start the backend:
echo     cd backend
echo     npm install
echo     npm run migrate   (if not done above)
echo     npm start
echo ============================================================
echo.
pause

:end
