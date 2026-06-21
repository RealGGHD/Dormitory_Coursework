\connect dormitory_olap

CREATE SCHEMA IF NOT EXISTS dwh;
SET search_path TO dwh;

CREATE TABLE IF NOT EXISTS dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    month_number INTEGER NOT NULL,
    quarter_number INTEGER NOT NULL,
    year_number INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_dormitory (
    dormitory_key BIGSERIAL PRIMARY KEY,
    dorm_code VARCHAR(20) NOT NULL UNIQUE,
    dorm_name VARCHAR(100) NOT NULL,
    city VARCHAR(80) NOT NULL,
    district VARCHAR(80) NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_room (
    room_key BIGSERIAL PRIMARY KEY,
    room_code VARCHAR(20) NOT NULL,
    dorm_name VARCHAR(100) NOT NULL,
    room_type_name VARCHAR(50) NOT NULL,
    capacity INTEGER NOT NULL,
    monthly_price NUMERIC(10, 2) NOT NULL,
    room_status VARCHAR(30) NOT NULL,
    effective_start_date DATE NOT NULL,
    effective_end_date DATE NULL,
    is_current BOOLEAN NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_room_current
    ON dim_room(room_code)
    WHERE is_current;

CREATE TABLE IF NOT EXISTS dim_staff (
    staff_key BIGSERIAL PRIMARY KEY,
    staff_code VARCHAR(20) NOT NULL UNIQUE,
    full_name VARCHAR(120) NOT NULL,
    position_name VARCHAR(60) NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_feature (
    feature_key BIGSERIAL PRIMARY KEY,
    feature_code VARCHAR(40) NOT NULL UNIQUE,
    feature_name VARCHAR(80) NOT NULL
);

CREATE TABLE IF NOT EXISTS fact_occupancy (
    occupancy_key BIGSERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date(date_key),
    dormitory_key BIGINT NOT NULL REFERENCES dim_dormitory(dormitory_key),
    room_key BIGINT NOT NULL REFERENCES dim_room(room_key),
    occupied_beds INTEGER NOT NULL,
    room_capacity INTEGER NOT NULL,
    available_beds INTEGER NOT NULL,
    occupancy_rate NUMERIC(5, 2) NOT NULL,
    monthly_revenue NUMERIC(12, 2) NOT NULL,
    UNIQUE (date_key, dormitory_key, room_key)
);

CREATE TABLE IF NOT EXISTS fact_maintenance (
    maintenance_fact_key BIGSERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date(date_key),
    dormitory_key BIGINT NOT NULL REFERENCES dim_dormitory(dormitory_key),
    room_key BIGINT NOT NULL REFERENCES dim_room(room_key),
    staff_key BIGINT NOT NULL REFERENCES dim_staff(staff_key),
    issue_type VARCHAR(50) NOT NULL,
    requests_count INTEGER NOT NULL,
    completed_requests INTEGER NOT NULL,
    repair_cost NUMERIC(12, 2) NOT NULL,
    avg_completion_days NUMERIC(10, 2) NULL,
    UNIQUE (date_key, dormitory_key, room_key, staff_key, issue_type)
);

CREATE TABLE IF NOT EXISTS bridge_room_feature (
    room_key BIGINT NOT NULL REFERENCES dim_room(room_key),
    feature_key BIGINT NOT NULL REFERENCES dim_feature(feature_key),
    PRIMARY KEY (room_key, feature_key)
);
