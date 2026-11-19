-- ============================================================================
-- TalentHub: HR Recruitment & Employee Attrition Analytics
-- Relational Schema (MySQL 8.0+ / Normalized to 3NF)
-- ============================================================================

DROP DATABASE IF EXISTS talenthub_hr;
CREATE DATABASE talenthub_hr;
USE talenthub_hr;

-- 1. Departments
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100) NOT NULL,
    annual_budget DECIMAL(12, 2) CHECK (annual_budget > 0)
);

-- 2. Job Positions (Openings)
CREATE TABLE positions (
    position_id INT AUTO_INCREMENT PRIMARY KEY,
    department_id INT NOT NULL,
    title VARCHAR(120) NOT NULL,
    salary_band ENUM('L1-Entry', 'L2-Mid', 'L3-Senior', 'L4-Lead', 'L5-Director') NOT NULL,
    min_salary DECIMAL(10, 2) NOT NULL,
    max_salary DECIMAL(10, 2) NOT NULL,
    opened_date DATE NOT NULL,
    status ENUM('Open', 'Closed', 'On Hold') DEFAULT 'Open',
    CONSTRAINT fk_pos_dept FOREIGN KEY (department_id) REFERENCES departments(department_id),
    CONSTRAINT chk_salary_range CHECK (max_salary >= min_salary)
);

-- 3. Candidates
CREATE TABLE candidates (
    candidate_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(25),
    hiring_source ENUM('LinkedIn', 'Referral', 'Job Portal', 'Campus', 'Agency') NOT NULL,
    total_experience_years DECIMAL(4, 1) DEFAULT 0.0,
    created_at DATE NOT NULL
);

-- 4. Applications
CREATE TABLE applications (
    application_id INT AUTO_INCREMENT PRIMARY KEY,
    candidate_id INT NOT NULL,
    position_id INT NOT NULL,
    applied_date DATE NOT NULL,
    current_stage ENUM('Applied', 'Screening', 'Technical', 'Managerial', 'Offer', 'Hired', 'Rejected') DEFAULT 'Applied',
    offered_salary DECIMAL(10, 2) NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_app_cand FOREIGN KEY (candidate_id) REFERENCES candidates(candidate_id),
    CONSTRAINT fk_app_pos FOREIGN KEY (position_id) REFERENCES positions(position_id),
    CONSTRAINT uq_cand_pos UNIQUE (candidate_id, position_id)
);

-- 5. Application Status Audit Log (Populated by Trigger)
CREATE TABLE application_status_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    application_id INT NOT NULL,
    old_stage VARCHAR(30),
    new_stage VARCHAR(30) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_app FOREIGN KEY (application_id) REFERENCES applications(application_id)
);

-- 6. Interviews
CREATE TABLE interviews (
    interview_id INT AUTO_INCREMENT PRIMARY KEY,
    application_id INT NOT NULL,
    round_name ENUM('HR Screening', 'Technical Round 1', 'Technical Round 2', 'Hiring Manager') NOT NULL,
    interview_date DATE NOT NULL,
    score TINYINT CHECK (score BETWEEN 1 AND 10),
    result ENUM('Pass', 'Fail', 'Pending') DEFAULT 'Pending',
    CONSTRAINT fk_int_app FOREIGN KEY (application_id) REFERENCES applications(application_id)
);

-- 7. Employees
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    candidate_id INT UNIQUE,
    department_id INT NOT NULL,
    position_id INT NOT NULL,
    hire_date DATE NOT NULL,
    base_salary DECIMAL(10, 2) NOT NULL,
    employment_status ENUM('Active', 'Exited') DEFAULT 'Active',
    CONSTRAINT fk_emp_cand FOREIGN KEY (candidate_id) REFERENCES candidates(candidate_id),
    CONSTRAINT fk_emp_dept FOREIGN KEY (department_id) REFERENCES departments(department_id),
    CONSTRAINT fk_emp_pos FOREIGN KEY (position_id) REFERENCES positions(position_id)
);

-- 8. Employee Exits (Attrition Tracking)
CREATE TABLE exits (
    exit_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL UNIQUE,
    exit_date DATE NOT NULL,
    exit_type ENUM('Voluntary Resignation', 'Involuntary Termination', 'Retirement') NOT NULL,
    primary_reason ENUM('Compensation', 'Career Growth', 'Work-Life Balance', 'Relocation', 'Performance', 'Other') NOT NULL,
    CONSTRAINT fk_exit_emp FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

-- ============================================================================
-- TRIGGER: Log Application Stage Changes & Sync Hired Candidates
-- ============================================================================
DELIMITER //
CREATE TRIGGER trg_log_application_stage_change
AFTER UPDATE ON applications
FOR EACH ROW
BEGIN
    IF OLD.current_stage <> NEW.current_stage THEN
        INSERT INTO application_status_logs (application_id, old_stage, new_stage)
        VALUES (NEW.application_id, OLD.current_stage, NEW.current_stage);
    END IF;
END//
DELIMITER ;

-- ============================================================================
-- VIEW: Department Recruitment & Attrition Summary View
-- ============================================================================
CREATE VIEW vw_department_hr_metrics AS
SELECT 
    d.department_id,
    d.department_name,
    COUNT(DISTINCT e.employee_id) AS total_hires,
    SUM(CASE WHEN e.employment_status = 'Active' THEN 1 ELSE 0 END) AS active_headcount,
    SUM(CASE WHEN e.employment_status = 'Exited' THEN 1 ELSE 0 END) AS exited_headcount,
    ROUND(
        (SUM(CASE WHEN e.employment_status = 'Exited' THEN 1 ELSE 0 END) / 
        NULLIF(COUNT(DISTINCT e.employee_id), 0)) * 100, 2
    ) AS attrition_rate_pct,
    ROUND(AVG(e.base_salary), 2) AS avg_department_salary
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name;