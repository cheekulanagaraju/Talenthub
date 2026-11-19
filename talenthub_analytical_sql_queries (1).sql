-- ============================================================================
-- TalentHub: Analytical SQL Queries
-- Covers: Hiring Funnel, Time-to-Hire, Attrition by Dept & Tenure, Salary Bands
-- ============================================================================
USE talenthub_hr;

-- 1. Hiring Funnel Breakdown by Stage & Conversion Percentage
SELECT 
    current_stage AS stage,
    COUNT(*) AS application_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM applications), 2) AS pct_of_total_applications
FROM applications
GROUP BY current_stage
ORDER BY FIELD(current_stage, 'Applied', 'Screening', 'Technical', 'Managerial', 'Offer', 'Hired', 'Rejected');

-- 2. Average Time-to-Hire (in Days) by Department & Hiring Source
SELECT 
    d.department_name,
    c.hiring_source,
    COUNT(e.employee_id) AS total_hired,
    ROUND(AVG(DATEDIFF(e.hire_date, a.applied_date)), 1) AS avg_days_to_hire,
    MIN(DATEDIFF(e.hire_date, a.applied_date)) AS fastest_hire_days,
    MAX(DATEDIFF(e.hire_date, a.applied_date)) AS slowest_hire_days
FROM employees e
JOIN candidates c ON e.candidate_id = c.candidate_id
JOIN applications a ON a.candidate_id = c.candidate_id AND a.position_id = e.position_id
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.department_name, c.hiring_source
ORDER BY d.department_name, avg_days_to_hire ASC;

-- 3. Attrition Rate & Top Exit Reasons by Department
SELECT 
    d.department_name,
    COUNT(e.employee_id) AS total_employees,
    SUM(CASE WHEN e.employment_status = 'Exited' THEN 1 ELSE 0 END) AS exits,
    ROUND(SUM(CASE WHEN e.employment_status = 'Exited' THEN 1 ELSE 0 END) * 100.0 / COUNT(e.employee_id), 2) AS attrition_rate_pct,
    COALESCE(MAX(ex.primary_reason), 'None') AS top_exit_reason
FROM departments d
JOIN employees e ON d.department_id = e.department_id
LEFT JOIN exits ex ON e.employee_id = ex.employee_id
GROUP BY d.department_name
ORDER BY attrition_rate_pct DESC;

-- 4. Attrition Analysis by Employee Tenure Bucket
SELECT 
    CASE 
        WHEN DATEDIFF(COALESCE(ex.exit_date, CURRENT_DATE), e.hire_date) < 180 THEN '< 6 Months'
        WHEN DATEDIFF(COALESCE(ex.exit_date, CURRENT_DATE), e.hire_date) BETWEEN 180 AND 365 THEN '6 - 12 Months'
        ELSE '> 12 Months'
    END AS tenure_bucket,
    COUNT(e.employee_id) AS headcount,
    SUM(CASE WHEN e.employment_status = 'Exited' THEN 1 ELSE 0 END) AS exited_count,
    ROUND(SUM(CASE WHEN e.employment_status = 'Exited' THEN 1 ELSE 0 END) * 100.0 / COUNT(e.employee_id), 2) AS bucket_attrition_pct
FROM employees e
LEFT JOIN exits ex ON e.employee_id = ex.employee_id
GROUP BY tenure_bucket
ORDER BY bucket_attrition_pct DESC;

-- 5. Salary Band Utilization & Compensation Benchmarking
SELECT 
    p.salary_band,
    COUNT(e.employee_id) AS employees_in_band,
    ROUND(MIN(e.base_salary), 0) AS actual_min_salary,
    ROUND(AVG(e.base_salary), 0) AS actual_avg_salary,
    ROUND(MAX(e.base_salary), 0) AS actual_max_salary,
    ROUND(AVG((e.base_salary - p.min_salary) / NULLIF(p.max_salary - p.min_salary, 0)) * 100, 1) AS avg_band_penetration_pct
FROM positions p
JOIN employees e ON p.position_id = e.position_id
GROUP BY p.salary_band
ORDER BY p.salary_band;

-- 6. Verify Trigger Execution & View Output
SELECT * FROM application_status_logs LIMIT 10;
SELECT * FROM vw_department_hr_metrics;