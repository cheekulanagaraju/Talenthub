"""
TalentHub: HR Recruitment & Employee Attrition Analytics
Python DB-API Integration, Analytical Queries & Trend Visualization
Requirements: pip install mysql-connector-python pandas matplotlib seaborn
"""

import mysql.connector
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# 1. Database Connection Configuration (Update credentials as needed)
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "your_password",
    "database": "talenthub_hr"
}

def fetch_dataframe(conn, query: str) -> pd.DataFrame:
    """Executes SQL via DB-API cursor and returns a Pandas DataFrame."""
    cursor = conn.cursor(dictionary=True)
    cursor.execute(query)
    rows = cursor.fetchall()
    cursor.close()
    return pd.DataFrame(rows)

def main():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        print("Connected to TalentHub MySQL Database successfully.\n")

        # Query A: Department HR Metrics (From View)
        df_dept = fetch_dataframe(conn, "SELECT * FROM vw_department_hr_metrics;")
        print("=== Department HR Metrics ===")
        print(df_dept.to_string(index=False), "\n")

        # Query B: Hiring Funnel Counts
        funnel_query = """
            SELECT current_stage, COUNT(*) AS count
            FROM applications
            GROUP BY current_stage
            ORDER BY FIELD(current_stage, 'Applied', 'Screening', 'Technical', 'Managerial', 'Offer', 'Hired', 'Rejected');
        """
        df_funnel = fetch_dataframe(conn, funnel_query)

        # Query C: Monthly Hiring vs. Exit Trends
        trends_query = """
            SELECT DATE_FORMAT(hire_date, '%Y-%m') AS month, COUNT(*) AS hires, 0 AS exits
            FROM employees
            GROUP BY month
            UNION ALL
            SELECT DATE_FORMAT(exit_date, '%Y-%m') AS month, 0 AS hires, COUNT(*) AS exits
            FROM exits
            GROUP BY month;
        """
        df_trends_raw = fetch_dataframe(conn, trends_query)
        df_trends = df_trends_raw.groupby("month", as_index=False).sum().sort_values("month")

        # 2. Generate Visualizations
        sns.set_theme(style="whitegrid")
        fig, axes = plt.subplots(1, 3, figsize=(18, 5))

        # Chart 1: Hiring Funnel
        sns.barplot(data=df_funnel, x="current_stage", y="count", ax=axes[0], palette="Blues_d")
        axes[0].set_title("Recruitment Funnel by Stage", fontsize=13, fontweight="bold")
        axes[0].set_xlabel("Stage")
        axes[0].set_ylabel("Applications")
        axes[0].tick_params(axis="x", rotation=35)

        # Chart 2: Attrition Rate by Department
        sns.barplot(data=df_dept, x="department_name", y="attrition_rate_pct", ax=axes[1], palette="Reds_d")
        axes[1].set_title("Attrition Rate (%) by Department", fontsize=13, fontweight="bold")
        axes[1].set_xlabel("Department")
        axes[1].set_ylabel("Attrition Rate (%)")
        axes[1].tick_params(axis="x", rotation=35)

        # Chart 3: Hiring vs Exit Trends
        axes[2].plot(df_trends["month"], df_trends["hires"], marker="o", label="Hires", color="#2e7d32")
        axes[2].plot(df_trends["month"], df_trends["exits"], marker="s", label="Exits", color="#c62828")
        axes[2].set_title("Monthly Hiring vs. Exit Trends", fontsize=13, fontweight="bold")
        axes[2].set_xlabel("Month")
        axes[2].set_ylabel("Headcount Change")
        axes[2].tick_params(axis="x", rotation=45)
        axes[2].legend()

        plt.tight_layout()
        plt.savefig("talenthub_analytics_dashboard.png", dpi=300)
        print("Saved analytics dashboard to 'talenthub_analytics_dashboard.png'.")

    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
    finally:
        if 'conn' in locals() and conn.is_connected():
            conn.close()

if __name__ == "__main__":
    main()