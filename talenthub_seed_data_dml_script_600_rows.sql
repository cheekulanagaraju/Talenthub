-- ============================================================================
-- TalentHub: Seed Data & DML Workflows (Generates 600+ Relational Rows)
-- Note: Uses recursive CTEs in MySQL 8.0+ to populate realistic synthetic data
-- ============================================================================
USE talenthub_hr;

-- 1. Seed Departments (6 rows)
INSERT INTO departments (department_name, location, annual_budget) VALUES
('Engineering', 'Bengaluru', 4500000.00),
('Data Science', 'Hyderabad', 2800000.00),
('Product Management', 'Bengaluru', 1900000.00),
('Sales & Marketing', 'Mumbai', 3200000.00),
('Human Resources', 'Chennai', 1100000.00),
('Customer Success', 'Pune', 1500000.00);

-- 2. Seed Positions (18 rows)
INSERT INTO positions (department_id, title, salary_band, min_salary, max_salary, opened_date, status) VALUES
(1, 'Backend Software Engineer', 'L2-Mid', 1200000, 1800000, '2024-01-10', 'Open'),
(1, 'Senior Distributed Systems Engineer', 'L3-Senior', 2200000, 3200000, '2024-02-01', 'Open'),
(1, 'Frontend React Developer', 'L1-Entry', 700000, 1100000, '2024-03-15', 'Closed'),
(2, 'Data Scientist', 'L2-Mid', 1400000, 2100000, '2024-01-15', 'Open'),
(2, 'Senior ML Engineer', 'L3-Senior', 2400000, 3500000, '2024-02-20', 'Open'),
(2, 'Data Analyst', 'L1-Entry', 650000, 950000, '2024-04-01', 'Closed'),
(3, 'Product Manager', 'L3-Senior', 2000000, 2900000, '2024-01-25', 'Open'),
(3, 'Associate Product Manager', 'L1-Entry', 900000, 1300000, '2024-05-10', 'Open'),
(4, 'Enterprise Account Executive', 'L3-Senior', 1600000, 2500000, '2024-02-05', 'Open'),
(4, 'Growth Marketing Specialist', 'L2-Mid', 950000, 1400000, '2024-03-01', 'Closed'),
(5, 'Technical Recruiter', 'L2-Mid', 750000, 1150000, '2024-01-12', 'Open'),
(6, 'Customer Success Manager', 'L2-Mid', 850000, 1300000, '2024-02-18', 'Open');

-- 3. Generate 250 Candidates via Recursive CTE
SET SESSION cte_max_recursion_depth = 1000;

INSERT INTO candidates (full_name, email, phone, hiring_source, total_experience_years, created_at)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 250
)
SELECT 
    CONCAT('Candidate_', LPAD(n, 3, '0')) AS full_name,
    CONCAT('candidate', n, '@talenthub-demo.com') AS email,
    CONCAT('+91-98', LPAD(10000000 + n * 137, 8, '0')) AS phone,
    ELT(1 + (n % 5), 'LinkedIn', 'Referral', 'Job Portal', 'Campus', 'Agency') AS hiring_source,
    ROUND((n % 12) + ((n % 10) / 10.0), 1) AS total_experience_years,
    DATE_ADD('2024-01-01', INTERVAL (n % 300) DAY) AS created_at
FROM seq;

-- 4. Generate 300 Applications across Candidates & Positions
INSERT INTO applications (candidate_id, position_id, applied_date, current_stage, offered_salary)
WITH RECURSIVE app_seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM app_seq WHERE n < 300
)
SELECT 
    1 + ((n * 7) % 250) AS candidate_id,
    1 + (n % 12) AS position_id,
    DATE_ADD('2024-01-15', INTERVAL (n % 320) DAY) AS applied_date,
    CASE 
        WHEN n % 10 IN (0, 1, 2) THEN 'Hired'
        WHEN n % 10 = 3 THEN 'Offer'
        WHEN n % 10 = 4 THEN 'Managerial'
        WHEN n % 10 = 5 THEN 'Technical'
        WHEN n % 10 = 6 THEN 'Screening'
        WHEN n % 10 = 7 THEN 'Applied'
        ELSE 'Rejected'
    END AS current_stage,
    CASE 
        WHEN n % 10 IN (0, 1, 2, 3) THEN 800000 + ((n % 15) * 120000)
        ELSE NULL
    END AS offered_salary
FROM app_seq
ON DUPLICATE KEY UPDATE current_stage = VALUES(current_stage);

-- 5. Generate 220 Interviews for Applications past 'Applied'
INSERT INTO interviews (application_id, round_name, interview_date, score, result)
SELECT 
    application_id,
    ELT(1 + (application_id % 4), 'HR Screening', 'Technical Round 1', 'Technical Round 2', 'Hiring Manager'),
    DATE_ADD(applied_date, INTERVAL (5 + (application_id % 14)) DAY),
    CASE WHEN current_stage IN ('Hired', 'Offer', 'Managerial') THEN 7 + (application_id % 4) ELSE 4 + (application_id % 5) END,
    CASE WHEN current_stage IN ('Hired', 'Offer', 'Managerial') THEN 'Pass' ELSE 'Fail' END
FROM applications
WHERE current_stage <> 'Applied'
LIMIT 220;

-- 6. Convert 'Hired' Applications into Employees (~90 Employees)
INSERT INTO employees (candidate_id, department_id, position_id, hire_date, base_salary, employment_status)
SELECT 
    a.candidate_id,
    p.department_id,
    a.position_id,
    DATE_ADD(a.applied_date, INTERVAL (18 + (a.application_id % 25)) DAY) AS hire_date,
    COALESCE(a.offered_salary, p.min_salary) AS base_salary,
    'Active'
FROM applications a
JOIN positions p ON a.position_id = p.position_id
WHERE a.current_stage = 'Hired'
GROUP BY a.candidate_id;

-- 7. Simulate DML Workflow: Resignations / Exits for ~25% of Employees
INSERT INTO exits (employee_id, exit_date, exit_type, primary_reason)
SELECT 
    employee_id,
    DATE_ADD(hire_date, INTERVAL (120 + (employee_id * 19) % 450) DAY) AS exit_date,
    ELT(1 + (employee_id % 3), 'Voluntary Resignation', 'Involuntary Termination', 'Retirement'),
    ELT(1 + (employee_id % 5), 'Compensation', 'Career Growth', 'Work-Life Balance', 'Relocation', 'Performance')
FROM employees
WHERE employee_id % 4 = 0;

-- Update employees status to 'Exited' for logged exits
UPDATE employees 
SET employment_status = 'Exited' 
WHERE employee_id IN (SELECT employee_id FROM exits);

-- 8. Demonstrate DML Stage Updates (Fires `trg_log_application_stage_change`)
UPDATE applications 
SET current_stage = 'Technical' 
WHERE current_stage = 'Screening' 
LIMIT 10;