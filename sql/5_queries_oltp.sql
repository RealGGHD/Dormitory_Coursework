\connect dormitory_oltp
SET search_path TO oltp;

-- 1. Current room occupancy by dormitory and room type.
SELECT d.dorm_name, rt.room_type_name,
       COUNT(DISTINCT r.room_id) AS rooms_count,
       COUNT(ra.assignment_id) AS active_assignments,
       SUM(r.capacity) AS total_beds
FROM rooms r
JOIN dormitories d ON d.dormitory_id = r.dormitory_id
JOIN room_types rt ON rt.room_type_id = r.room_type_id
LEFT JOIN room_assignments ra
  ON ra.room_id = r.room_id
 AND CURRENT_DATE BETWEEN ra.assigned_from AND ra.assigned_to
GROUP BY d.dorm_name, rt.room_type_name
ORDER BY d.dorm_name, rt.room_type_name;

-- 2. Payments by month and payment status.
SELECT payment_month,
       payment_status,
       COUNT(*) AS payments_count,
       SUM(amount_paid) AS total_amount
FROM payments
GROUP BY payment_month, payment_status
ORDER BY payment_month, payment_status;

-- 3. Maintenance request completion time by issue type.
SELECT issue_type,
       COUNT(*) AS requests_count,
       SUM(CASE WHEN maintenance_status = 'Completed' THEN 1 ELSE 0 END) AS completed_requests,
       ROUND(AVG(CASE WHEN completed_date IS NOT NULL THEN completed_date - request_date ELSE NULL END), 2) AS avg_completion_days
FROM maintenance_requests
GROUP BY issue_type
ORDER BY requests_count DESC;
