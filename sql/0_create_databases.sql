-- Student Dormitory Room Allocation and Maintenance System
-- Run from the default PostgreSQL database.

SELECT 'CREATE DATABASE dormitory_oltp'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dormitory_oltp')\gexec

SELECT 'CREATE DATABASE dormitory_olap'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dormitory_olap')\gexec
