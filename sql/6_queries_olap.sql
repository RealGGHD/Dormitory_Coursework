\connect dormitory_olap
SET search_path TO dwh;

-- 1. Monthly occupancy by dormitory.
SELECT d.year_number, d.month_number, dorm.dorm_name,
       SUM(f.occupied_beds) AS occupied_beds,
       SUM(f.room_capacity) AS room_capacity,
       ROUND(AVG(f.occupancy_rate), 2) AS avg_occupancy_rate,
       SUM(f.monthly_revenue) AS monthly_revenue
FROM fact_occupancy f
JOIN dim_date d ON d.date_key = f.date_key
JOIN dim_dormitory dorm ON dorm.dormitory_key = f.dormitory_key
GROUP BY d.year_number, d.month_number, dorm.dorm_name
ORDER BY d.year_number, d.month_number, dorm.dorm_name;

-- 2. Maintenance cost and completion by dormitory and issue type.
SELECT dorm.dorm_name,
       f.issue_type,
       SUM(f.requests_count) AS requests_count,
       SUM(f.completed_requests) AS completed_requests,
       SUM(f.repair_cost) AS repair_cost,
       ROUND(AVG(f.avg_completion_days), 2) AS avg_completion_days
FROM fact_maintenance f
JOIN dim_dormitory dorm ON dorm.dormitory_key = f.dormitory_key
GROUP BY dorm.dorm_name, f.issue_type
ORDER BY repair_cost DESC;

-- 3. Room features through bridge table.
SELECT r.room_code,
       r.room_type_name,
       STRING_AGG(feat.feature_name, ', ' ORDER BY feat.feature_name) AS features
FROM bridge_room_feature b
JOIN dim_room r ON r.room_key = b.room_key
JOIN dim_feature feat ON feat.feature_key = b.feature_key
WHERE r.is_current
GROUP BY r.room_code, r.room_type_name
ORDER BY r.room_code;
