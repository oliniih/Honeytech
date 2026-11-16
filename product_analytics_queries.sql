-- 1. PRODUCT FUNNEL ANALYSIS

WITH user_steps AS (
    SELECT 
        u.user_id,
        u.region,
        u.ab_group,
        MAX(CASE WHEN e.episode_number >= 1 THEN 1 ELSE 0 END) AS read_ep1,
        MAX(CASE WHEN (u.ab_group = 'Control_3ep' AND e.episode_number > 3) 
                   OR (u.ab_group = 'Test_5ep' AND e.episode_number > 5) THEN 1 ELSE 0 END) AS reached_paywall,
        MAX(CASE WHEN t.revenue_usd > 0 THEN 1 ELSE 0 END) AS made_purchase
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    LEFT JOIN transactions t ON u.user_id = t.user_id
    GROUP BY u.user_id, u.region, u.ab_group
)
SELECT 
    region,
    ab_group,
    COUNT(user_id) AS total_installs,
    SUM(read_ep1) AS step1_read_ep1,
    SUM(reached_paywall) AS step2_reached_paywall,
    SUM(made_purchase) AS step3_payers,
    ROUND(100.0 * SUM(made_purchase) / COUNT(user_id), 2) AS cr_install_to_pay_pct
FROM user_steps
GROUP BY region, ab_group
ORDER BY region, ab_group;


-- 2. COHORT RETENTION BY GENRE

WITH user_first_day AS (
    SELECT 
        u.user_id,
        e.comic_genre,
        MIN(CAST(julianday(e.event_date) - julianday(u.install_date) AS INTEGER)) AS first_day,
        MAX(CASE WHEN CAST(julianday(e.event_date) - julianday(u.install_date) AS INTEGER) >= 1 THEN 1 ELSE 0 END) AS ret_d1,
        MAX(CASE WHEN CAST(julianday(e.event_date) - julianday(u.install_date) AS INTEGER) >= 3 THEN 1 ELSE 0 END) AS ret_d3,
        MAX(CASE WHEN CAST(julianday(e.event_date) - julianday(u.install_date) AS INTEGER) >= 7 THEN 1 ELSE 0 END) AS ret_d7,
        MAX(CASE WHEN CAST(julianday(e.event_date) - julianday(u.install_date) AS INTEGER) >= 14 THEN 1 ELSE 0 END) AS ret_d14,
        MAX(CASE WHEN CAST(julianday(e.event_date) - julianday(u.install_date) AS INTEGER) >= 30 THEN 1 ELSE 0 END) AS ret_d30
    FROM users u
    JOIN events e ON u.user_id = e.user_id
    GROUP BY u.user_id, e.comic_genre
)
SELECT 
    comic_genre,
    COUNT(user_id) AS total_readers,
    ROUND(100.0 * SUM(ret_d1) / COUNT(user_id), 2) AS retention_d1_pct,
    ROUND(100.0 * SUM(ret_d3) / COUNT(user_id), 2) AS retention_d3_pct,
    ROUND(100.0 * SUM(ret_d7) / COUNT(user_id), 2) AS retention_d7_pct,
    ROUND(100.0 * SUM(ret_d14) / COUNT(user_id), 2) AS retention_d14_pct,
    ROUND(100.0 * SUM(ret_d30) / COUNT(user_id), 2) AS retention_d30_pct
FROM user_first_day
GROUP BY comic_genre
ORDER BY retention_d7_pct DESC;


-- 3. PARETO / WHALES ANALYSIS

WITH user_ltv AS (
    SELECT 
        u.user_id,
        u.region,
        u.platform,
        COALESCE(SUM(t.revenue_usd), 0) AS total_spent,
        NTILE(10) OVER (ORDER BY COALESCE(SUM(t.revenue_usd), 0) DESC) AS spending_decile
    FROM users u
    LEFT JOIN transactions t ON u.user_id = t.user_id
    GROUP BY u.user_id, u.region, u.platform
)
SELECT 
    CASE WHEN spending_decile = 1 THEN 'Top 10% (Whales)' ELSE 'Other 90%' END AS segment,
    COUNT(user_id) AS users_count,
    ROUND(SUM(total_spent), 2) AS total_revenue_usd,
    ROUND(100.0 * SUM(total_spent) / SUM(SUM(total_spent)) OVER (), 2) AS revenue_share_pct
FROM user_ltv
GROUP BY segment;
