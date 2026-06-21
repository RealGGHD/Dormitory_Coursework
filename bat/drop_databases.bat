@echo off
setlocal

set "PGUSER=postgres"
set "PGPASSWORD=1234"
set "PGHOST=localhost"
set "PGPORT=5432"
set "PSQL=C:\Program Files\PostgreSQL\18\bin\psql.exe"

if not exist "%PSQL%" (
    set "PSQL=psql"
)

echo Dropping coursework databases...

"%PSQL%" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 ^
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname IN ('dormitory_olap', 'dormitory_oltp');" ^
  -c "DROP DATABASE IF EXISTS dormitory_olap;" ^
  -c "DROP DATABASE IF EXISTS dormitory_oltp;"

if errorlevel 1 (
    echo.
    echo Failed to drop databases. Check that PostgreSQL is running and credentials are correct.
    endlocal
    exit /b 1
)

echo Databases were dropped successfully.
endlocal
