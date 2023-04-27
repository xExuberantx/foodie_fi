-- A. Customer Journey
-- Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
-- Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!
/*
Customer 1 downgraded to the basic version after the trial week expired.
Customer 2 upgraded to the pro annual version after the trial week expired.
Customer 11 cancelled his subscription after the trial.
Customer 13 downgraded to the basic version after the trial and after 3 months upgraded to pro monthly.
Customer 15 probably forgot to cancel his subscription as it switched to pro monthly and got cancelled a month later.
Customer 16 downgraded to the basic version after the trial, but then upgraded to pro annual after 4 months.
Customer 18 probably forgot to cancel his subscription as it switched to pro monthly.
Customer 19 used pro monthly for 2 months after trial and upgraded to pro annual.
*/
SELECT
    customer_id,
    plan_name,
    start_date
FROM foodie_fi.subscriptions
JOIN foodie_fi.plans
USING(plan_id)
WHERE customer_id IN (1, 2, 11, 13, 15, 16, 18, 19)
ORDER BY customer_id;

-- B. Data Analysis Questions

-- 1. How many customers has Foodie-Fi ever had?

SELECT
    COUNT(DISTINCT customer_id),
    MAX(customer_id)
FROM foodie_fi.subscriptions;

-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT
    DATE_PART('month', start_date) as month,
    COUNT(*)
FROM foodie_fi.subscriptions
GROUP BY month
ORDER BY count DESC;

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT
    plan_name,
    COUNT(*)
FROM foodie_fi.subscriptions
JOIN foodie_fi.plans
USING(plan_id)
WHERE start_date > '2020-12-31'
GROUP BY plan_name;
-- No new trials after 2020

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

SELECT
    COUNT(DISTINCT customer_id) as cust_count,
    (SELECT COUNT(customer_id) FROM foodie_fi.subscriptions WHERE plan_id = 4) as churned,
    ROUND((SELECT COUNT(customer_id) FROM foodie_fi.subscriptions WHERE plan_id = 4)*100.0/COUNT(DISTINCT customer_id), 1) as churn_perc
FROM foodie_fi.subscriptions
JOIN foodie_fi.plans
USING(plan_id);

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH cte as (
    SELECT
        *,
        LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY plan_id ASC) as next_plan
    FROM foodie_fi.subscriptions
    )

SELECT
    COUNT(*) as churn_cnt,
    ROUND(COUNT(*)*100.0/1000) as churn_perc
FROM cte
WHERE plan_id = 0 AND next_plan = 4;

-- 6. What is the number and percentage of customer plans after their initial free trial?
WITH cte as (
    SELECT
        *,
        LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY plan_id ASC) as next_plan
    FROM foodie_fi.subscriptions
    )

SELECT
    next_plan,
    plan_name,
    count,
    perc
FROM (
    SELECT
        next_plan,
        COUNT(*),
        ROUND(COUNT(*)*100.0/1000,2) as perc
    FROM cte
    WHERE plan_id = 0 AND next_plan IS NOT NULL
    GROUP BY next_plan
    ORDER BY next_plan) as t
JOIN foodie_fi.plans p
ON t.next_plan=p.plan_id;

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH cte as (
    SELECT
        customer_id,
        MAX(plan_id) as current_plan
    FROM foodie_fi.subscriptions
    WHERE start_date <= '2020-12-31'
    GROUP BY customer_id
)

SELECT
    plan_name,
    COUNT(*),
    ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM cte), 2) as perc
FROM cte 
JOIN foodie_fi.plans p
ON cte.current_plan=p.plan_id
GROUP BY plan_name
ORDER BY count;

-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT COUNT(*)
FROM foodie_fi.subscriptions
WHERE start_date BETWEEN '2020-01-01' AND '2020-12-31' AND plan_id = 3;

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH annual as (
    SELECT
        customer_id,
        start_date as start_annual
    FROM foodie_fi.subscriptions
    WHERE plan_id = 3
    ),
    start as (
    SELECT
        customer_id,
        start_date as join_date
    FROM foodie_fi.subscriptions
    WHERE plan_id = 0
    )

SELECT
    ROUND(AVG(start_annual-join_date)) as avg_to_annual
FROM start s
JOIN annual a
USING(customer_id);

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH annual as (
    SELECT
        customer_id,
        start_date as start_annual
    FROM foodie_fi.subscriptions
    WHERE plan_id = 3
    ),
    start as (
    SELECT
        customer_id,
        start_date as join_date
    FROM foodie_fi.subscriptions
    WHERE plan_id = 0
    ),
    days_to_annual as (
    SELECT
        start_annual-join_date as days
    FROM start s
    JOIN annual a
    USING(customer_id)
    )

-- Establishing min and max values for bins (7-346)
SELECT
    MIN(start_annual-join_date),
    MAX(start_annual-join_date)
FROM start s
JOIN annual a
USING(customer_id);

SELECT
    lower,
    upper,
    COUNT(*)
FROM
    (SELECT
        generate_series(1, 340, 30) as lower,
        generate_series(30, 360, 30) as upper) as bins
LEFT JOIN days_to_annual as d
ON d.days >= bins.lower AND d.days <= bins.upper
GROUP BY lower, upper
ORDER BY lower, upper;

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH cte as (
    SELECT
        *,
        LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY plan_id ASC) as next_plan
    FROM foodie_fi.subscriptions
    )

SELECT COUNT(DISTINCT customer_id) as downgrade_cnt
FROM cte
WHERE start_date BETWEEN '2020-01-01' AND '2020-12-31'
    AND plan_id = 2 AND next_plan = 1;