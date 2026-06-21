# Student Dormitory Room Allocation and Maintenance System

SQL coursework project.

Student: Egor Koptev

## Topic

Student Dormitory Room Allocation and Maintenance System.

The system supports student room applications, room assignments, payments, and maintenance requests in university dormitories.

## Project Contents

- `data/` - source CSV files without surrogate keys.
- `sql/0_create_databases.sql` - creates separate `dormitory_oltp` and `dormitory_olap` databases.
- `sql/1_create_oltp.sql` - creates the OLTP schema.
- `sql/2_load_oltp_from_csv.sql` - loads CSV data into OLTP tables.
- `sql/3_create_olap.sql` - creates the OLAP/DWH schema.
- `sql/4_etl_oltp_to_olap.sql` - moves and transforms data from OLTP to OLAP.
- `sql/5_queries_oltp.sql` - OLTP analytical queries.
- `sql/6_queries_olap.sql` - OLAP analytical queries.
- `schemas/` - OLTP and OLAP schema images.
- `powerbi/` - Power BI report and report layout image.
- `docs/` - DOCX report and presentation files.
- `bat/` - Windows helper scripts for local PostgreSQL setup.

## Scope

- OLTP: 9 tables.
- OLAP: 8 tables.
- Fact tables: 2.
- SCD Type 2: `dim_room`.
- Bridge table: `bridge_room_feature`.
- CSV files: 5.

## Run Order

```bash
psql -U postgres -d postgres -f sql/0_create_databases.sql
psql -U postgres -d postgres -f sql/1_create_oltp.sql
psql -U postgres -d postgres -f sql/2_load_oltp_from_csv.sql
psql -U postgres -d postgres -f sql/3_create_olap.sql
psql -U postgres -d postgres -f sql/4_etl_oltp_to_olap.sql
psql -U postgres -d dormitory_oltp -f sql/5_queries_oltp.sql
psql -U postgres -d dormitory_olap -f sql/6_queries_olap.sql
```

The ETL script uses PostgreSQL user `postgres` with password `1234` by default.

## Windows BAT Helpers

The `bat/` folder contains helper scripts for local use:

- `start_postgresql.bat` - starts local PostgreSQL service `postgresql-x64-18`.
- `stop_postgresql.bat` - stops local PostgreSQL service `postgresql-x64-18`.
- `setup_databases.bat` - creates OLTP/OLAP databases, creates schemas, loads CSV data, and runs ETL.
- `drop_databases.bat` - drops `dormitory_oltp` and `dormitory_olap`.

Start/stop scripts may require running as Administrator.
