@echo off
setlocal

set "PG_SERVICE=postgresql-x64-18"

echo Stopping PostgreSQL service: %PG_SERVICE%
net stop "%PG_SERVICE%"

if errorlevel 1 (
    echo.
    echo Failed to stop PostgreSQL. Run this file as Administrator if Windows denies access.
    exit /b 1
)

echo PostgreSQL is stopped.
endlocal
