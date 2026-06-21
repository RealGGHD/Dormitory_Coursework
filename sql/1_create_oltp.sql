\connect dormitory_oltp

CREATE SCHEMA IF NOT EXISTS oltp;
SET search_path TO oltp;

CREATE TABLE IF NOT EXISTS students (
    student_id BIGSERIAL PRIMARY KEY,
    student_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(30) NOT NULL UNIQUE,
    study_program VARCHAR(100) NOT NULL,
    study_year INTEGER NOT NULL CHECK (study_year BETWEEN 1 AND 6),
    enrolled_at DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS dormitories (
    dormitory_id BIGSERIAL PRIMARY KEY,
    dorm_code VARCHAR(20) NOT NULL UNIQUE,
    dorm_name VARCHAR(100) NOT NULL,
    city VARCHAR(80) NOT NULL,
    address VARCHAR(120) NOT NULL,
    district VARCHAR(80) NOT NULL
);

CREATE TABLE IF NOT EXISTS room_types (
    room_type_id BIGSERIAL PRIMARY KEY,
    room_type_name VARCHAR(50) NOT NULL UNIQUE,
    capacity INTEGER NOT NULL CHECK (capacity > 0)
);

CREATE TABLE IF NOT EXISTS rooms (
    room_id BIGSERIAL PRIMARY KEY,
    room_code VARCHAR(20) NOT NULL UNIQUE,
    dormitory_id BIGINT NOT NULL REFERENCES dormitories(dormitory_id),
    room_type_id BIGINT NOT NULL REFERENCES room_types(room_type_id),
    floor_number INTEGER NOT NULL CHECK (floor_number > 0),
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    monthly_price NUMERIC(10, 2) NOT NULL CHECK (monthly_price >= 0),
    room_status VARCHAR(30) NOT NULL CHECK (room_status IN ('Available', 'Maintenance'))
);

CREATE TABLE IF NOT EXISTS staff (
    staff_id BIGSERIAL PRIMARY KEY,
    staff_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position_name VARCHAR(60) NOT NULL,
    dormitory_id BIGINT NOT NULL REFERENCES dormitories(dormitory_id),
    phone VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS applications (
    application_id BIGSERIAL PRIMARY KEY,
    application_code VARCHAR(20) NOT NULL UNIQUE,
    student_id BIGINT NOT NULL REFERENCES students(student_id),
    preferred_room_type_id BIGINT NOT NULL REFERENCES room_types(room_type_id),
    application_date DATE NOT NULL,
    application_status VARCHAR(30) NOT NULL CHECK (application_status IN ('Approved', 'Rejected', 'Pending'))
);

CREATE TABLE IF NOT EXISTS room_assignments (
    assignment_id BIGSERIAL PRIMARY KEY,
    assignment_code VARCHAR(20) NOT NULL UNIQUE,
    application_id BIGINT NOT NULL UNIQUE REFERENCES applications(application_id),
    room_id BIGINT NOT NULL REFERENCES rooms(room_id),
    assigned_by_staff_id BIGINT NOT NULL REFERENCES staff(staff_id),
    assigned_from DATE NOT NULL,
    assigned_to DATE NOT NULL,
    CHECK (assigned_to >= assigned_from)
);

CREATE TABLE IF NOT EXISTS payments (
    payment_id BIGSERIAL PRIMARY KEY,
    payment_code VARCHAR(20) NOT NULL UNIQUE,
    assignment_id BIGINT NOT NULL REFERENCES room_assignments(assignment_id),
    payment_month DATE NOT NULL,
    amount_paid NUMERIC(10, 2) NOT NULL CHECK (amount_paid >= 0),
    payment_status VARCHAR(30) NOT NULL CHECK (payment_status IN ('Paid', 'Pending'))
);

CREATE TABLE IF NOT EXISTS maintenance_requests (
    maintenance_id BIGSERIAL PRIMARY KEY,
    maintenance_code VARCHAR(20) NOT NULL UNIQUE,
    room_id BIGINT NOT NULL REFERENCES rooms(room_id),
    reported_by_student_id BIGINT NOT NULL REFERENCES students(student_id),
    assigned_staff_id BIGINT NOT NULL REFERENCES staff(staff_id),
    issue_type VARCHAR(50) NOT NULL,
    request_date DATE NOT NULL,
    completed_date DATE NULL,
    maintenance_status VARCHAR(30) NOT NULL CHECK (maintenance_status IN ('Open', 'Completed')),
    repair_cost NUMERIC(10, 2) NOT NULL CHECK (repair_cost >= 0),
    CHECK (completed_date IS NULL OR completed_date >= request_date)
);

CREATE INDEX IF NOT EXISTS ix_assignments_dates ON room_assignments(assigned_from, assigned_to);
CREATE INDEX IF NOT EXISTS ix_maintenance_request_date ON maintenance_requests(request_date);
