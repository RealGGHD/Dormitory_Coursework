@echo off
setlocal

set "PG_SERVICE=postgresql-x64-18"

echo Starting PostgreSQL service: %PG_SERVICE%
net start "%PG_SERVICE%"

if errorlevel 1 (
    echo.
    echo Failed to start PostgreSQL. Run this file as Administrator if Windows denies access.
    exit /b 1
)

echo PostgreSQL is running.
endlocal
