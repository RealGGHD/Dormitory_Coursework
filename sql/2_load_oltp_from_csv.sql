\connect dormitory_oltp
SET search_path TO oltp;

BEGIN;

CREATE TEMP TABLE stg_students (
    student_code TEXT, first_name TEXT, last_name TEXT, email TEXT, phone TEXT,
    study_program TEXT, study_year INTEGER, enrolled_at DATE
) ON COMMIT DROP;

CREATE TEMP TABLE stg_dormitories (
    dorm_code TEXT, dorm_name TEXT, city TEXT, address TEXT, district TEXT
) ON COMMIT DROP;

CREATE TEMP TABLE stg_rooms (
    room_code TEXT, dorm_code TEXT, room_type_name TEXT, floor_number INTEGER,
    capacity INTEGER, monthly_price NUMERIC(10, 2), room_status TEXT, feature_codes TEXT
) ON COMMIT DROP;

CREATE TEMP TABLE stg_staff (
    staff_code TEXT, first_name TEXT, last_name TEXT, position_name TEXT, dorm_code TEXT, phone TEXT
) ON COMMIT DROP;

CREATE TEMP TABLE stg_events (
    row_type TEXT, application_code TEXT, student_code TEXT, preferred_room_type TEXT,
    application_date DATE NULL, application_status TEXT, assignment_code TEXT, room_code TEXT,
    assigned_from DATE NULL, assigned_to DATE NULL, assigned_by_staff_code TEXT,
    payment_code TEXT, payment_month DATE NULL, amount_paid NUMERIC(10, 2) NULL,
    payment_status TEXT, maintenance_code TEXT, reported_by_student_code TEXT,
    reported_room_code TEXT, issue_type TEXT, request_date DATE NULL, completed_date DATE NULL,
    maintenance_status TEXT, repair_cost NUMERIC(10, 2) NULL, maintenance_staff_code TEXT
) ON COMMIT DROP;

\copy stg_students FROM 'data/students.csv' WITH (FORMAT csv, HEADER true)
\copy stg_dormitories FROM 'data/dormitories.csv' WITH (FORMAT csv, HEADER true)
\copy stg_rooms FROM 'data/rooms.csv' WITH (FORMAT csv, HEADER true)
\copy stg_staff FROM 'data/staff.csv' WITH (FORMAT csv, HEADER true)
\copy stg_events FROM 'data/dormitory_events.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO students (student_code, first_name, last_name, email, phone, study_program, study_year, enrolled_at)
SELECT student_code, first_name, last_name, email, phone, study_program, study_year, enrolled_at
FROM stg_students
ON CONFLICT (student_code) DO UPDATE
SET first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    study_program = EXCLUDED.study_program,
    study_year = EXCLUDED.study_year,
    enrolled_at = EXCLUDED.enrolled_at;

INSERT INTO dormitories (dorm_code, dorm_name, city, address, district)
SELECT dorm_code, dorm_name, city, address, district
FROM stg_dormitories
ON CONFLICT (dorm_code) DO UPDATE
SET dorm_name = EXCLUDED.dorm_name,
    city = EXCLUDED.city,
    address = EXCLUDED.address,
    district = EXCLUDED.district;

INSERT INTO room_types (room_type_name, capacity)
SELECT DISTINCT room_type_name, capacity
FROM stg_rooms
ON CONFLICT (room_type_name) DO UPDATE
SET capacity = EXCLUDED.capacity;

INSERT INTO rooms (room_code, dormitory_id, room_type_id, floor_number, capacity, monthly_price, room_status)
SELECT r.room_code, d.dormitory_id, rt.room_type_id, r.floor_number, r.capacity, r.monthly_price, r.room_status
FROM stg_rooms r
JOIN dormitories d ON d.dorm_code = r.dorm_code
JOIN room_types rt ON rt.room_type_name = r.room_type_name
ON CONFLICT (room_code) DO UPDATE
SET dormitory_id = EXCLUDED.dormitory_id,
    room_type_id = EXCLUDED.room_type_id,
    floor_number = EXCLUDED.floor_number,
    capacity = EXCLUDED.capacity,
    monthly_price = EXCLUDED.monthly_price,
    room_status = EXCLUDED.room_status;

INSERT INTO staff (staff_code, first_name, last_name, position_name, dormitory_id, phone)
SELECT s.staff_code, s.first_name, s.last_name, s.position_name, d.dormitory_id, s.phone
FROM stg_staff s
JOIN dormitories d ON d.dorm_code = s.dorm_code
ON CONFLICT (staff_code) DO UPDATE
SET first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    position_name = EXCLUDED.position_name,
    dormitory_id = EXCLUDED.dormitory_id,
    phone = EXCLUDED.phone;

INSERT INTO applications (application_code, student_id, preferred_room_type_id, application_date, application_status)
SELECT e.application_code, s.student_id, rt.room_type_id, e.application_date, e.application_status
FROM stg_events e
JOIN students s ON s.student_code = e.student_code
JOIN room_types rt ON rt.room_type_name = e.preferred_room_type
WHERE e.row_type = 'assignment'
ON CONFLICT (application_code) DO UPDATE
SET student_id = EXCLUDED.student_id,
    preferred_room_type_id = EXCLUDED.preferred_room_type_id,
    application_date = EXCLUDED.application_date,
    application_status = EXCLUDED.application_status;

INSERT INTO room_assignments (assignment_code, application_id, room_id, assigned_by_staff_id, assigned_from, assigned_to)
SELECT e.assignment_code, a.application_id, r.room_id, st.staff_id, e.assigned_from, e.assigned_to
FROM stg_events e
JOIN applications a ON a.application_code = e.application_code
JOIN rooms r ON r.room_code = e.room_code
JOIN staff st ON st.staff_code = e.assigned_by_staff_code
WHERE e.row_type = 'assignment'
ON CONFLICT (assignment_code) DO UPDATE
SET application_id = EXCLUDED.application_id,
    room_id = EXCLUDED.room_id,
    assigned_by_staff_id = EXCLUDED.assigned_by_staff_id,
    assigned_from = EXCLUDED.assigned_from,
    assigned_to = EXCLUDED.assigned_to;

INSERT INTO payments (payment_code, assignment_id, payment_month, amount_paid, payment_status)
SELECT e.payment_code, ra.assignment_id, e.payment_month, e.amount_paid, e.payment_status
FROM stg_events e
JOIN room_assignments ra ON ra.assignment_code = e.assignment_code
WHERE e.row_type = 'assignment'
ON CONFLICT (payment_code) DO UPDATE
SET assignment_id = EXCLUDED.assignment_id,
    payment_month = EXCLUDED.payment_month,
    amount_paid = EXCLUDED.amount_paid,
    payment_status = EXCLUDED.payment_status;

INSERT INTO maintenance_requests (
    maintenance_code, room_id, reported_by_student_id, assigned_staff_id,
    issue_type, request_date, completed_date, maintenance_status, repair_cost
)
SELECT e.maintenance_code, r.room_id, s.student_id, st.staff_id,
       e.issue_type, e.request_date, e.completed_date, e.maintenance_status, e.repair_cost
FROM stg_events e
JOIN rooms r ON r.room_code = e.reported_room_code
JOIN students s ON s.student_code = e.reported_by_student_code
JOIN staff st ON st.staff_code = e.maintenance_staff_code
WHERE e.row_type = 'maintenance'
ON CONFLICT (maintenance_code) DO UPDATE
SET room_id = EXCLUDED.room_id,
    reported_by_student_id = EXCLUDED.reported_by_student_id,
    assigned_staff_id = EXCLUDED.assigned_staff_id,
    issue_type = EXCLUDED.issue_type,
    request_date = EXCLUDED.request_date,
    completed_date = EXCLUDED.completed_date,
    maintenance_status = EXCLUDED.maintenance_status,
    repair_cost = EXCLUDED.repair_cost;

DELETE FROM maintenance_requests mr
WHERE NOT EXISTS (
    SELECT 1
    FROM stg_events e
    WHERE e.row_type = 'maintenance'
      AND e.maintenance_code = mr.maintenance_code
);

COMMIT;
