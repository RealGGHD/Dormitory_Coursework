# Student Dormitory Room Allocation and Maintenance System

Курсовая работа по SQL.

Студент: Egor Koptev

## Тема

**Student Dormitory Room Allocation and Maintenance System**

Система распределения комнат и обработки заявок на обслуживание в студенческом общежитии.

## Состав проекта

- `data/` - исходные CSV-файлы без surrogate keys.
- `sql/0_create_databases.sql` - создание отдельных баз данных `dormitory_oltp` и `dormitory_olap`.
- `sql/1_create_oltp.sql` - создание OLTP-схемы.
- `sql/2_load_oltp_from_csv.sql` - загрузка CSV-данных в OLTP.
- `sql/3_create_olap.sql` - создание OLAP/DWH-схемы.
- `sql/4_etl_oltp_to_olap.sql` - перенос и трансформация данных из OLTP в OLAP.
- `sql/5_queries_oltp.sql` - SQL-запросы к OLTP.
- `sql/6_queries_olap.sql` - SQL-запросы к OLAP.
- `schemas/` - изображения схем OLTP, OLAP и Power BI report layout.
- `powerbi/` - Power BI report.
- `docs/` - DOCX-отчёт.
- `bat/` - Windows BAT-скрипты для локального запуска PostgreSQL и настройки баз данных.

## Объём проекта

- OLTP: 9 таблиц.
- OLAP: 8 таблиц.
- Fact tables: 2.
- SCD Type 2: `dim_room`.
- Bridge table: `bridge_room_feature`.
- CSV-файлы: 5.

## Порядок запуска SQL-скриптов

```bash
psql -U postgres -d postgres -f sql/0_create_databases.sql
psql -U postgres -d postgres -f sql/1_create_oltp.sql
psql -U postgres -d postgres -f sql/2_load_oltp_from_csv.sql
psql -U postgres -d postgres -f sql/3_create_olap.sql
psql -U postgres -d postgres -f sql/4_etl_oltp_to_olap.sql
psql -U postgres -d dormitory_oltp -f sql/5_queries_oltp.sql
psql -U postgres -d dormitory_olap -f sql/6_queries_olap.sql
```

По умолчанию ETL-скрипт использует PostgreSQL user `postgres` с паролем `1234`.

## BAT-скрипты

В папке `bat/` находятся вспомогательные скрипты для Windows:

- `start_postgresql.bat` - запускает локальную службу PostgreSQL `postgresql-x64-18`.
- `stop_postgresql.bat` - останавливает локальную службу PostgreSQL `postgresql-x64-18`.
- `setup_databases.bat` - создаёт базы данных, создаёт схемы, загружает CSV и запускает ETL.
- `drop_databases.bat` - удаляет базы данных `dormitory_oltp` и `dormitory_olap`.

Скрипты запуска и остановки PostgreSQL могут требовать запуск от имени администратора.

## Power BI

Power BI report находится в файле:

```text
powerbi/Dormitory_PowerBI_Report.pbix
```

Для подключения используется база данных:

```text
Server: localhost
Database: dormitory_olap
User: postgres
Password: 1234
```

Основные источники данных для отчёта:

- `dwh.vw_powerbi_occupancy`
- `dwh.vw_powerbi_maintenance`

## Документация

Основной отчёт:

```text
docs/Dormitory_Coursework_Report.docx
```
