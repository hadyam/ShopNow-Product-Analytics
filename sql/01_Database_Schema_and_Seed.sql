/* =====================================================================
   SHOPNOW PRODUCT ANALYTICS DATABASE - TUTORIAL EDITION
   Microsoft SQL Server (SSMS) - run the whole script with F5

   الهدف: أي حد يشغّل السكربت ده هيطلع بنفس البيانات بالظبط (deterministic)
   ويقدر يقارن نتايجه بالأرقام المتوقعة تحت.

   المحتوى:
     Users 2,500 | Products 20 | Events 39,450 | Transactions 9,075

   الأرقام المتوقعة (Expected Results)
   -----------------------------------
   Event distribution:
     app_opened          11,325 events | 2,500 users
     product_viewed      10,200 events | 2,500 users
     add_to_cart          7,950 events | 2,500 users
     checkout_started     5,675 events | 2,450 users
     purchase_completed   4,300 events | 2,300 users

   Transactions:
     total_transaction_lines = 9,075
     total_orders            = 4,300
     total_revenue           = 178,115,910.00
     avg_item_revenue        = 19,627.10 (approx.)
     AOV                     = 41,422.30 (approx.)

   ملاحظة: كل INSERT فيه ORDER BY صريح علشان الـ IDENTITY (event_id)
   يتولّد بنفس الترتيب عند أي حد. من غيره الأرقام ممكن تختلف.
   السكربت بيعمل DROP للجداول الأربعة ويبنيها من الأول، فتقدر تشغّله أكتر من مرة.
   ===================================================================== */

-- 1. Create Database
IF DB_ID('ShopNow_ProductAnalytics') IS NULL
BEGIN
    CREATE DATABASE ShopNow_ProductAnalytics;
END;
GO

USE ShopNow_ProductAnalytics;
GO

-- 2. Rebuild Tables (child tables first)
DROP TABLE IF EXISTS dbo.Transactions;
DROP TABLE IF EXISTS dbo.Events;
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Users;
GO

-- =====================================================
-- TABLE 1: USERS (2,500 users, signups spread over 180 days)
-- =====================================================
CREATE TABLE dbo.Users
(
    user_id     INT          PRIMARY KEY,
    signup_date DATE         NOT NULL,
    source      VARCHAR(50)  NOT NULL,
    country     VARCHAR(50)  NOT NULL,
    device_type VARCHAR(30)  NOT NULL
);
GO

WITH Numbers AS
(
    SELECT TOP (2500)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Users (user_id, signup_date, source, country, device_type)
SELECT
    n,
    DATEADD(DAY, (n - 1) % 180, '20260101'),
    CASE n % 4
        WHEN 1 THEN 'Facebook'
        WHEN 2 THEN 'Google'
        WHEN 3 THEN 'Organic'
        ELSE 'TikTok'
    END,
    CASE n % 3
        WHEN 1 THEN 'Egypt'
        WHEN 2 THEN 'Saudi Arabia'
        ELSE 'UAE'
    END,
    CASE n % 3
        WHEN 1 THEN 'Android'
        WHEN 2 THEN 'iOS'
        ELSE 'Desktop'
    END
FROM Numbers
ORDER BY n;
GO

-- =====================================================
-- TABLE 2: PRODUCTS (20 products)
-- =====================================================
CREATE TABLE dbo.Products
(
    product_id   INT           PRIMARY KEY,
    product_name VARCHAR(100)  NOT NULL,
    category     VARCHAR(50)   NOT NULL,
    unit_price   DECIMAL(12,2) NOT NULL
);
GO

INSERT INTO dbo.Products (product_id, product_name, category, unit_price)
VALUES
(1,  'Laptop A',      'Electronics', 25000),
(2,  'Laptop B',      'Electronics', 30000),
(3,  'Smartphone A',  'Electronics', 15000),
(4,  'Smartphone B',  'Electronics', 18000),
(5,  'Headphones A',  'Accessories', 1200),
(6,  'Headphones B',  'Accessories', 1800),
(7,  'Keyboard A',    'Accessories', 900),
(8,  'Mouse A',       'Accessories', 500),
(9,  'Smart Watch A', 'Wearables',   3500),
(10, 'Smart Watch B', 'Wearables',   5000),
(11, 'Tablet A',      'Electronics', 9000),
(12, 'Tablet B',      'Electronics', 11000),
(13, 'Backpack A',    'Fashion',     1200),
(14, 'Backpack B',    'Fashion',     1600),
(15, 'T-Shirt A',     'Fashion',     450),
(16, 'T-Shirt B',     'Fashion',     600),
(17, 'Shoes A',       'Fashion',     2200),
(18, 'Shoes B',       'Fashion',     2800),
(19, 'Monitor A',     'Electronics', 7000),
(20, 'Monitor B',     'Electronics', 9500);
GO

-- =====================================================
-- TABLE 3: EVENTS
-- =====================================================
CREATE TABLE dbo.Events
(
    event_id    BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT          NOT NULL,
    event_name  VARCHAR(50)  NOT NULL,
    event_time  DATETIME2    NOT NULL,
    session_id  VARCHAR(100) NOT NULL,
    device_type VARCHAR(30)  NOT NULL,
    product_id  INT          NULL,

    CONSTRAINT FK_Events_Users
        FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id),

    CONSTRAINT FK_Events_Products
        FOREIGN KEY (product_id) REFERENCES dbo.Products(product_id)
);
GO

-- 3A. Day-0 funnel (signup day), one session per user
--     ORDER BY مهم: بيثبّت ترتيب الـ event_id
INSERT INTO dbo.Events (user_id, event_name, event_time, session_id, device_type, product_id)
SELECT
    u.user_id,
    v.event_name,
    DATEADD(MINUTE, v.minute_offset, DATEADD(HOUR, 9, CAST(u.signup_date AS DATETIME2))),
    CONCAT('S-', u.user_id, '-D0'),
    u.device_type,
    CASE
        WHEN v.event_name = 'app_opened' THEN NULL
        ELSE ((u.user_id - 1) % 20) + 1
    END
FROM dbo.Users u
CROSS APPLY
(
    VALUES
    ('app_opened',         0,  1),
    ('product_viewed',     5,  CASE WHEN u.user_id % 10 <= 8 THEN 1 ELSE 0 END),
    ('add_to_cart',        10, CASE WHEN u.user_id % 10 <= 6 THEN 1 ELSE 0 END),
    ('checkout_started',   15, CASE WHEN u.user_id % 10 <= 4 THEN 1 ELSE 0 END),
    ('purchase_completed', 20, CASE WHEN u.user_id % 10 <= 2 THEN 1 ELSE 0 END)
) v(event_name, minute_offset, include_event)
WHERE v.include_event = 1
ORDER BY u.user_id, v.minute_offset;
GO

-- 3B. Returning-user funnels at 8 retention milestones (day 1,3,7,14,30,45,60,90)
INSERT INTO dbo.Events (user_id, event_name, event_time, session_id, device_type, product_id)
SELECT
    u.user_id,
    f.event_name,
    DATEADD(
        MINUTE,
        f.minute_offset,
        DATEADD(
            HOUR,
            10 + (r.day_number % 8),
            CAST(DATEADD(DAY, r.day_number, u.signup_date) AS DATETIME2)
        )
    ),
    CONCAT('S-', u.user_id, '-D', r.day_number),
    u.device_type,
    CASE
        WHEN f.event_name = 'app_opened' THEN NULL
        ELSE ((u.user_id + r.day_number - 1) % 20) + 1
    END
FROM dbo.Users u
CROSS APPLY
(
    VALUES
        (1,  75),
        (3,  65),
        (7,  55),
        (14, 45),
        (30, 38),
        (45, 30),
        (60, 25),
        (90, 20)
) r(day_number, retention_percentage)
CROSS APPLY
(
    VALUES
        ('app_opened',         0,  1),
        ('product_viewed',     4,  CASE WHEN (u.user_id + r.day_number) % 10 <= 8 THEN 1 ELSE 0 END),
        ('add_to_cart',        9,  CASE WHEN (u.user_id + r.day_number) % 10 <= 6 THEN 1 ELSE 0 END),
        ('checkout_started',   14, CASE WHEN (u.user_id + r.day_number) % 10 <= 4 THEN 1 ELSE 0 END),
        ('purchase_completed', 19, CASE WHEN (u.user_id + r.day_number) % 10 <= 3 THEN 1 ELSE 0 END)
) f(event_name, minute_offset, include_event)
WHERE ((u.user_id * 7 + r.day_number) % 100) < r.retention_percentage
  AND f.include_event = 1
ORDER BY u.user_id, r.day_number, f.minute_offset;
GO

-- =====================================================
-- TABLE 4: TRANSACTIONS (multi-item baskets)
-- =====================================================
CREATE TABLE dbo.Transactions
(
    transaction_id   BIGINT IDENTITY(1,1) PRIMARY KEY,
    event_id         BIGINT        NOT NULL,
    user_id          INT           NOT NULL,
    product_id       INT           NOT NULL,
    quantity         INT           NOT NULL,
    unit_price       DECIMAL(12,2) NOT NULL,
    discount         DECIMAL(12,2) NOT NULL DEFAULT 0,
    revenue AS (quantity * unit_price - discount) PERSISTED,
    transaction_time DATETIME2     NOT NULL,

    -- أكتر من منتج مختلف في نفس الـ purchase event (basket)
    CONSTRAINT UQ_Transactions_Event_Product UNIQUE (event_id, product_id),

    CONSTRAINT FK_Transactions_Users
        FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id),

    CONSTRAINT FK_Transactions_Products
        FOREIGN KEY (product_id) REFERENCES dbo.Products(product_id),

    CONSTRAINT FK_Transactions_Events
        FOREIGN KEY (event_id) REFERENCES dbo.Events(event_id)
);
GO

INSERT INTO dbo.Transactions
    (event_id, user_id, product_id, quantity, unit_price, discount, transaction_time)
SELECT
    e.event_id,
    e.user_id,
    p.product_id,
    1 + ((e.user_id + b.item_seq) % 3) AS quantity,
    p.unit_price,
    CASE
        WHEN (e.user_id + b.item_seq) % 4 = 0
            THEN ROUND(p.unit_price * (1 + ((e.user_id + b.item_seq) % 3)) * 0.10, 2)
        WHEN e.user_id % 3 = 0
            THEN ROUND(p.unit_price * (1 + ((e.user_id + b.item_seq) % 3)) * 0.05, 2)
        ELSE 0
    END AS discount,
    DATEADD(SECOND, b.item_seq * 10, e.event_time)
FROM dbo.Events e
CROSS APPLY
(
    -- Item 1: المنتج الأساسي من الـ event (دايمًا)
    -- Item 2: منتج تاني في السلة (~70% من الطلبات: event_id % 10 <= 6)
    -- Item 3: منتج تالت في السلة (~40% من الطلبات: event_id % 10 <= 3)
    VALUES
        (1, e.product_id,                  1),
        (2, ((e.product_id + 3) % 20) + 1, CASE WHEN e.event_id % 10 <= 6 THEN 1 ELSE 0 END),
        (3, ((e.product_id + 9) % 20) + 1, CASE WHEN e.event_id % 10 <= 3 THEN 1 ELSE 0 END)
) b(item_seq, target_product_id, include_item)
INNER JOIN dbo.Products p
    ON b.target_product_id = p.product_id
WHERE e.event_name = 'purchase_completed'
  AND b.include_item = 1
ORDER BY e.event_id, b.item_seq;
GO

-- =====================================================
-- 5. DATA VALIDATION
-- =====================================================

-- 5.1 Row counts (expected: 2500 / 20 / 39450 / 9075)
SELECT 'Users' AS table_name, COUNT(*) AS total_rows FROM dbo.Users
UNION ALL
SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL
SELECT 'Events', COUNT(*) FROM dbo.Events
UNION ALL
SELECT 'Transactions', COUNT(*) FROM dbo.Transactions;
GO

-- 5.2 Event distribution
--     expected: app_opened 11325/2500, product_viewed 10200/2500, add_to_cart 7950/2500,
--               checkout_started 5675/2450, purchase_completed 4300/2300
SELECT
    event_name,
    COUNT(*)                AS total_events,
    COUNT(DISTINCT user_id) AS unique_users
FROM dbo.Events
GROUP BY event_name
ORDER BY total_events DESC;
GO

-- 5.3 Revenue and basket metrics
--     expected: lines 9075 | orders 4300 | revenue 178115910.00 | AOV ~41422.30
SELECT
    COUNT(*)                                       AS total_transaction_lines,
    COUNT(DISTINCT event_id)                       AS total_orders,
    SUM(revenue)                                   AS total_revenue,
    AVG(revenue)                                   AS avg_item_revenue,
    SUM(revenue) / COUNT(DISTINCT event_id)        AS average_order_value_AOV
FROM dbo.Transactions;
GO

-- 5.4 Automatic check: هل نتيجتك مطابقة للمتوقع؟
SELECT
    CASE WHEN
        (SELECT COUNT(*) FROM dbo.Users)        = 2500
    AND (SELECT COUNT(*) FROM dbo.Products)     = 20
    AND (SELECT COUNT(*) FROM dbo.Events)       = 39450
    AND (SELECT COUNT(*) FROM dbo.Transactions) = 9075
    AND (SELECT SUM(revenue) FROM dbo.Transactions) = 178115910.00
    THEN 'PASS - your data matches the tutorial'
    ELSE 'FAIL - your data differs, re-run the whole script'
    END AS validation_result;
GO
