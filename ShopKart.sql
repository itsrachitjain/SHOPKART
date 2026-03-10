CREATE DATABASE ShopKart;
USE DATABASE ShopKart;

CREATE SCHEMA sales_data;
USE SCHEMA sales_data;

CREATE WAREHOUSE Shopkart_Warehouse
WITH WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE;

USE WAREHOUSE Shopkart_Warehouse;

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    order_date DATE,
    customer_id INT,
    product_id INT,
    category STRING,
    price FLOAT,
    quantity INT,
    region STRING,
    payment_method STRING
);

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    age INT,
    gender STRING,
    city_tier STRING,
    annual_income FLOAT,
    preferred_category STRING
);

CREATE TABLE marketing (
    campaign_id INT PRIMARY KEY,
    date DATE,
    channel STRING,
    impressions INT,
    clicks INT,
    conversions INT,
    ad_spend FLOAT,
    region STRING
);

SELECT * FROM orders;
SELECT * FROM marketing;
SELECT * FROM customers;

SELECT COUNT(DISTINCT customer_id) FROM customers;
SELECT COUNT(DISTINCT order_id) FROM orders;


ALTER TABLE orders ADD COLUMN revenue FLOAT;

UPDATE orders
SET revenue = price * quantity;

ALTER TABLE customers 
ADD COLUMN age_group STRING;

UPDATE customers
SET age_group =
CASE
    WHEN age BETWEEN 11 AND 18 THEN '11-18'
    WHEN age BETWEEN 19 AND 30 THEN '19-30'
    WHEN age BETWEEN 31 AND 40 THEN '31-40'
    WHEN age BETWEEN 41 AND 50 THEN '41-50'
    WHEN age BETWEEN 51 AND 60 THEN '51-60'
    ELSE '61+'
END;

ALTER TABLE customers ADD COLUMN churn_flag INT;

UPDATE customers c
SET churn_flag = CASE
    WHEN last_order_date < DATEADD(day, -90, CURRENT_DATE) THEN 1
    ELSE 0
END
FROM (
    SELECT customer_id, MAX(order_date) AS last_order_date
    FROM orders
    GROUP BY customer_id
) o
WHERE c.customer_id = o.customer_id;

SELECT churn_flag, COUNT(*) 
FROM customers
GROUP BY churn_flag;


-- 1 Sales Performance Analysis
-- Total revenue generated each month
SELECT
    TO_CHAR(TO_DATE('2026-' || MONTH(order_date) || '-01'), 'MON') AS month_name,
    SUM(price * quantity) AS total_revenue
FROM orders
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date);


-- Product categories generating highest revenue
SELECT 
    category,
    SUM(revenue) AS revenue,
FROM orders
GROUP BY category
ORDER BY revenue DESC;

-- Regions contributing most sales in Quantity & Revenue
SELECT 
    region,
    SUM(quantity) AS Quantity_Sales,
    SUM(revenue) as Total_Amount
FROM orders
GROUP BY region
ORDER BY Total_Amount DESC;

-- Most frequently used payment method
SELECT 
    payment_method,
    COUNT(*) AS total
FROM orders
GROUP BY payment_method
ORDER BY total DESC;

-- Top 10 selling products
SELECT 
    product_id,
    COUNT(*) AS total_orders
FROM orders
GROUP BY product_id
ORDER BY total_orders DESC
LIMIT 10;


-- 2 Profitability Insights
-- Product categories with highest average order value
SELECT 
    category,
    AVG(revenue) AS avg_order_value
FROM orders
GROUP BY category
ORDER BY avg_order_value DESC;

-- Regions with lowest revenue growth
SELECT 
    region,
    SUM(revenue) AS total_revenue
FROM orders
GROUP BY region
ORDER BY total_revenue
LIMIT 1;


-- 3 Customer Behavior Analysis
-- Percentage of customers who have churned
SELECT 
    ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_percentage
FROM customers;

-- Age group generating highest revenue
SELECT 
    CASE
        WHEN c.age BETWEEN 11 AND 18 THEN '11-18'
        WHEN c.age BETWEEN 19 AND 30 THEN '19-30'
        WHEN c.age BETWEEN 31 AND 40 THEN '31-40'
        WHEN c.age BETWEEN 41 AND 50 THEN '41-50'
        WHEN c.age BETWEEN 51 AND 60 THEN '51-60'
        ELSE '61+'
    END AS age_group,
    SUM(o.revenue) AS total_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY age_group
ORDER BY total_revenue DESC;

-- City tier with most valuable customers
WITH customer_revenue AS (
    SELECT 
        c.customer_id,
        c.city_tier,
        SUM(o.revenue) AS total_revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.city_tier
)
SELECT 
    city_tier,
    AVG(total_revenue) AS avg_customer_value,
    SUM(total_revenue) AS total_revenue,
    COUNT(customer_id) AS total_customers
FROM customer_revenue
GROUP BY city_tier
ORDER BY avg_customer_value DESC;

-- Top 5% highest spending customers
WITH customer_total AS (
    SELECT 
        customer_id,
        SUM(quantity) AS total_quantity,
        SUM(revenue) AS total_spending
    FROM orders
    GROUP BY customer_id
)
SELECT 
    customer_id,
    total_spending,
    total_quantity
FROM customer_total
QUALIFY RANK() OVER (ORDER BY total_spending DESC) <= CEIL(0.05 * COUNT(*) OVER());


-- 4 Marketing Performance
-- Most conversions by channel
SELECT 
    channel,
    SUM(conversions) AS total_conversions
FROM marketing
GROUP BY channel
ORDER BY total_conversions DESC;

-- Conversion rate for each channel
SELECT 
    channel,
    SUM(conversions) AS total_conversions,
    SUM(clicks) AS total_clicks,
    ROUND(SUM(conversions)*100.0 / NULLIF(SUM(clicks),0), 2) AS conversion_rate_percent
FROM marketing
GROUP BY channel
ORDER BY conversion_rate_percent DESC;

-- Channel with highest ROI
WITH aov AS (
    SELECT AVG(revenue) AS avg_order_value FROM orders
),
marketing_revenue AS (
    SELECT 
        m.channel,
        m.region,
        SUM(m.ad_spend) AS total_ad_spend,
        SUM(m.conversions) AS total_conversions,
        SUM(m.conversions) * (SELECT avg_order_value FROM aov) AS revenue_generated
    FROM marketing m
    GROUP BY m.channel, m.region
)
SELECT 
    channel,
    region,
    total_ad_spend,
    total_conversions,
    revenue_generated,
    ROUND((revenue_generated - total_ad_spend)/NULLIF(total_ad_spend,0),2) AS ROI
FROM marketing_revenue
ORDER BY ROI DESC;

-- Region responding best to marketing campaigns
WITH aov AS (
    SELECT AVG(price * quantity) AS avg_order_value FROM orders
),
region_marketing AS (
    SELECT 
        m.region,
        SUM(m.ad_spend) AS total_ad_spend,
        SUM(m.conversions) AS total_conversions,
        SUM(m.conversions) * (SELECT avg_order_value FROM aov) AS revenue_generated
    FROM marketing m
    GROUP BY m.region
)
SELECT 
    region,
    total_ad_spend,
    total_conversions,
    revenue_generated,
    ROUND((revenue_generated - total_ad_spend)/NULLIF(total_ad_spend,0),2) AS ROI
FROM region_marketing
ORDER BY ROI DESC;

