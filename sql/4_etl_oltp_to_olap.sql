\connect dormitory_olap

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER IF NOT EXISTS dormitory_oltp_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', dbname 'dormitory_oltp', port '5432');

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_user_mappings
        WHERE srvname = 'dormitory_oltp_server' AND usename = CURRENT_USER
    ) THEN
        EXECUTE format(
            'DROP USER MAPPING FOR %I SERVER dormitory_oltp_server',
            CURRENT_USER
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_user_mappings
        WHERE srvname = 'dormitory_oltp_server' AND usename = CURRENT_USER
    ) THEN
        EXECUTE format(
            'CREATE USER MAPPING FOR %I SERVER dormitory_oltp_server OPTIONS (user %L, password %L)',
            CURRENT_USER,
            CURRENT_USER,
            '1234'
        );
    END IF;
END $$;

DROP SCHEMA IF EXISTS src_oltp CASCADE;
CREATE SCHEMA src_oltp;

IMPORT FOREIGN SCHEMA oltp
LIMIT TO (
    students, dormitories, room_types, rooms, staff, applications,
    room_assignments, payments, maintenance_requests
)
FROM SERVER dormitory_oltp_server
INTO src_oltp;

SET search_path TO dwh;

BEGIN;

INSERT INTO dim_date (date_key, full_date, month_number, quarter_number, year_number)
SELECT DISTINCT TO_CHAR(d::DATE, 'YYYYMMDD')::INTEGER,
       d::DATE,
       EXTRACT(MONTH FROM d)::INTEGER,
       EXTRACT(QUARTER FROM d)::INTEGER,
       EXTRACT(YEAR FROM d)::INTEGER
FROM (
    SELECT application_date AS d FROM src_oltp.applications
    UNION SELECT assigned_from FROM src_oltp.room_assignments
    UNION SELECT request_date FROM src_oltp.maintenance_requests
    UNION SELECT DATE_TRUNC('month', assigned_from)::DATE FROM src_oltp.room_assignments
) dates
WHERE d IS NOT NULL
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO dim_dormitory (dorm_code, dorm_name, city, district)
SELECT dorm_code, dorm_name, city, district
FROM src_oltp.dormitories
ON CONFLICT (dorm_code) DO UPDATE
SET dorm_name = EXCLUDED.dorm_name,
    city = EXCLUDED.city,
    district = EXCLUDED.district;

INSERT INTO dim_staff (staff_code, full_name, position_name)
SELECT staff_code, first_name || ' ' || last_name, position_name
FROM src_oltp.staff
ON CONFLICT (staff_code) DO UPDATE
SET full_name = EXCLUDED.full_name,
    position_name = EXCLUDED.position_name;

WITH src_rooms AS (
    SELECT r.room_code, d.dorm_name, rt.room_type_name, r.capacity, r.monthly_price, r.room_status
    FROM src_oltp.rooms r
    JOIN src_oltp.dormitories d ON d.dormitory_id = r.dormitory_id
    JOIN src_oltp.room_types rt ON rt.room_type_id = r.room_type_id
)
UPDATE dim_room dr
SET effective_end_date = CURRENT_DATE - 1,
    is_current = FALSE
FROM src_rooms sr
WHERE dr.room_code = sr.room_code
  AND dr.is_current
  AND (dr.dorm_name, dr.room_type_name, dr.capacity, dr.monthly_price, dr.room_status)
      IS DISTINCT FROM
      (sr.dorm_name, sr.room_type_name, sr.capacity, sr.monthly_price, sr.room_status);

WITH src_rooms AS (
    SELECT r.room_code, d.dorm_name, rt.room_type_name, r.capacity, r.monthly_price, r.room_status
    FROM src_oltp.rooms r
    JOIN src_oltp.dormitories d ON d.dormitory_id = r.dormitory_id
    JOIN src_oltp.room_types rt ON rt.room_type_id = r.room_type_id
)
INSERT INTO dim_room (
    room_code, dorm_name, room_type_name, capacity, monthly_price,
    room_status, effective_start_date, effective_end_date, is_current
)
SELECT room_code, dorm_name, room_type_name, capacity, monthly_price,
       room_status, CURRENT_DATE, NULL, TRUE
FROM src_rooms sr
WHERE NOT EXISTS (
    SELECT 1 FROM dim_room dr
    WHERE dr.room_code = sr.room_code AND dr.is_current
);

TRUNCATE TABLE fact_maintenance, fact_occupancy, bridge_room_feature;

INSERT INTO dim_feature (feature_code, feature_name)
SELECT DISTINCT feature_code,
       INITCAP(REPLACE(feature_code, '_', ' ')) AS feature_name
FROM (
    SELECT regexp_split_to_table(feature_codes, '\|') AS feature_code
    FROM (
        SELECT room_code,
               CASE room_code
                   WHEN 'R101' THEN 'WIFI|DESK|PRIVATE_BATH'
                   ELSE 'WIFI|DESK'
               END AS feature_codes
        FROM src_oltp.rooms
    ) f
) features
WHERE feature_code <> ''
ON CONFLICT (feature_code) DO NOTHING;

WITH occupancy_months AS (
    SELECT DISTINCT DATE_TRUNC('month', assigned_from)::DATE AS month_start
    FROM src_oltp.room_assignments
),
room_months AS (
    SELECT m.month_start, r.room_id, r.room_code, d.dorm_code, r.capacity, r.monthly_price
    FROM occupancy_months m
    CROSS JOIN src_oltp.rooms r
    JOIN src_oltp.dormitories d ON d.dormitory_id = r.dormitory_id
),
occupied AS (
    SELECT DATE_TRUNC('month', ra.assigned_from)::DATE AS month_start,
           ra.room_id,
           COUNT(*) AS occupied_beds,
           SUM(p.amount_paid) AS monthly_revenue
    FROM src_oltp.room_assignments ra
    JOIN src_oltp.payments p ON p.assignment_id = ra.assignment_id
    GROUP BY DATE_TRUNC('month', ra.assigned_from)::DATE, ra.room_id
)
INSERT INTO fact_occupancy (
    date_key, dormitory_key, room_key, occupied_beds, room_capacity,
    available_beds, occupancy_rate, monthly_revenue
)
SELECT dd.date_key, dorm.dormitory_key, dr.room_key,
       COALESCE(o.occupied_beds, 0) AS occupied_beds,
       rm.capacity AS room_capacity,
       GREATEST(rm.capacity - COALESCE(o.occupied_beds, 0), 0) AS available_beds,
       ROUND(100.0 * COALESCE(o.occupied_beds, 0) / rm.capacity, 2) AS occupancy_rate,
       COALESCE(o.monthly_revenue, 0) AS monthly_revenue
FROM room_months rm
LEFT JOIN occupied o ON o.month_start = rm.month_start AND o.room_id = rm.room_id
JOIN dim_date dd ON dd.full_date = rm.month_start
JOIN dim_dormitory dorm ON dorm.dorm_code = rm.dorm_code
JOIN dim_room dr ON dr.room_code = rm.room_code AND dr.is_current
ON CONFLICT (date_key, dormitory_key, room_key) DO UPDATE
SET occupied_beds = EXCLUDED.occupied_beds,
    room_capacity = EXCLUDED.room_capacity,
    available_beds = EXCLUDED.available_beds,
    occupancy_rate = EXCLUDED.occupancy_rate,
    monthly_revenue = EXCLUDED.monthly_revenue;

WITH maintenance_src AS (
    SELECT dd.date_key, dorm.dormitory_key, dr.room_key, ds.staff_key,
           mr.issue_type,
           COUNT(*) AS requests_count,
           SUM(CASE WHEN mr.maintenance_status = 'Completed' THEN 1 ELSE 0 END) AS completed_requests,
           SUM(mr.repair_cost) AS repair_cost,
           ROUND(AVG(CASE WHEN mr.completed_date IS NOT NULL THEN mr.completed_date - mr.request_date ELSE NULL END), 2) AS avg_completion_days
    FROM src_oltp.maintenance_requests mr
    JOIN src_oltp.rooms r ON r.room_id = mr.room_id
    JOIN src_oltp.dormitories d ON d.dormitory_id = r.dormitory_id
    JOIN dim_date dd ON dd.full_date = mr.request_date
    JOIN dim_dormitory dorm ON dorm.dorm_code = d.dorm_code
    JOIN dim_room dr ON dr.room_code = r.room_code AND dr.is_current
    JOIN src_oltp.staff st ON st.staff_id = mr.assigned_staff_id
    JOIN dim_staff ds ON ds.staff_code = st.staff_code
    GROUP BY dd.date_key, dorm.dormitory_key, dr.room_key, ds.staff_key, mr.issue_type
)
INSERT INTO fact_maintenance (
    date_key, dormitory_key, room_key, staff_key, issue_type,
    requests_count, completed_requests, repair_cost, avg_completion_days
)
SELECT date_key, dormitory_key, room_key, staff_key, issue_type,
       requests_count, completed_requests, repair_cost, avg_completion_days
FROM maintenance_src
ON CONFLICT (date_key, dormitory_key, room_key, staff_key, issue_type) DO UPDATE
SET requests_count = EXCLUDED.requests_count,
    completed_requests = EXCLUDED.completed_requests,
    repair_cost = EXCLUDED.repair_cost,
    avg_completion_days = EXCLUDED.avg_completion_days;

INSERT INTO bridge_room_feature (room_key, feature_key)
SELECT dr.room_key, df.feature_key
FROM dim_room dr
JOIN dim_feature df ON df.feature_code IN ('WIFI', 'DESK')
WHERE dr.is_current
ON CONFLICT (room_key, feature_key) DO NOTHING;

COMMIT;

CREATE OR REPLACE VIEW dwh.vw_powerbi_occupancy AS
SELECT dd.full_date, dd.month_number, dd.year_number, dorm.dorm_name,
       SUM(f.occupied_beds) AS occupied_beds,
       SUM(f.room_capacity) AS room_capacity,
       ROUND(AVG(f.occupancy_rate), 2) AS avg_occupancy_rate,
       SUM(f.monthly_revenue) AS monthly_revenue
FROM dwh.fact_occupancy f
JOIN dwh.dim_date dd ON dd.date_key = f.date_key
JOIN dwh.dim_dormitory dorm ON dorm.dormitory_key = f.dormitory_key
GROUP BY dd.full_date, dd.month_number, dd.year_number, dorm.dorm_name;

CREATE OR REPLACE VIEW dwh.vw_powerbi_maintenance AS
SELECT dd.full_date, dd.month_number, dd.year_number, dorm.dorm_name,
       f.issue_type, SUM(f.requests_count) AS requests_count,
       SUM(f.completed_requests) AS completed_requests,
       SUM(f.repair_cost) AS repair_cost,
       ROUND(AVG(f.avg_completion_days), 2) AS avg_completion_days
FROM dwh.fact_maintenance f
JOIN dwh.dim_date dd ON dd.date_key = f.date_key
JOIN dwh.dim_dormitory dorm ON dorm.dormitory_key = f.dormitory_key
GROUP BY dd.full_date, dd.month_number, dd.year_number, dorm.dorm_name, f.issue_type;
