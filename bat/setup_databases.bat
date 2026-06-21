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

pushd "%~dp0.."

echo Creating databases...
"%PSQL%" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -f "sql\0_create_databases.sql"
if errorlevel 1 goto fail

echo Creating OLTP schema...
"%PSQL%" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -f "sql\1_create_oltp.sql"
if errorlevel 1 goto fail

echo Loading CSV data to OLTP...
"%PSQL%" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -f "sql\2_load_oltp_from_csv.sql"
if errorlevel 1 goto fail

echo Creating OLAP schema...
"%PSQL%" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -f "sql\3_create_olap.sql"
if errorlevel 1 goto fail

echo Running ETL from OLTP to OLAP...
"%PSQL%" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d postgres -v ON_ERROR_STOP=1 -f "sql\4_etl_oltp_to_olap.sql"
if errorlevel 1 goto fail

echo.
echo Setup completed successfully.
popd
endlocal
exit /b 0

:fail
echo.
echo Setup failed. Check the error message above.
popd
endlocal
exit /b 1
