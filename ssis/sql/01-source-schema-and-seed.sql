/*
  01-source-schema-and-seed.sql
  Build schema and deterministic seed data in SalesSrc.
    - 20 countries
    - 100 products
    - 500 customers
    - 2000 orders
    - 6000 order items
  All keys are derived from ROW_NUMBER (no NEWID) so re-runs produce identical data.
*/

USE [SalesSrc];
GO

-- ============================================================
-- Drop in dependency order so reseeding is clean.
-- ============================================================
IF OBJECT_ID('dbo.OrderItems','U')    IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID('dbo.Orders','U')        IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Products','U')      IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Customers','U')     IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.CountryLookup','U') IS NOT NULL DROP TABLE dbo.CountryLookup;
GO

-- ============================================================
-- Schema
-- ============================================================
CREATE TABLE dbo.CountryLookup (
    CountryCode CHAR(2)        NOT NULL PRIMARY KEY,
    CountryName NVARCHAR(50)   NOT NULL
);

CREATE TABLE dbo.Customers (
    CustomerID  INT            NOT NULL PRIMARY KEY,
    FullName    NVARCHAR(100)  NOT NULL,
    Email       NVARCHAR(200)  NOT NULL,
    Country     NVARCHAR(50)   NOT NULL,
    CreatedAt   DATETIME2(0)   NOT NULL
);

CREATE TABLE dbo.Products (
    ProductID   INT            NOT NULL PRIMARY KEY,
    Sku         NVARCHAR(50)   NOT NULL,
    Name        NVARCHAR(200)  NOT NULL,
    Category    NVARCHAR(50)   NOT NULL,
    Price       DECIMAL(10,2)  NOT NULL,
    IsActive    BIT            NOT NULL
);

CREATE TABLE dbo.Orders (
    OrderID     INT            NOT NULL PRIMARY KEY,
    CustomerID  INT            NOT NULL,
    OrderDate   DATETIME2(0)   NOT NULL,
    TotalAmount DECIMAL(12,2)  NOT NULL,
    Status      NVARCHAR(20)   NOT NULL
);

CREATE TABLE dbo.OrderItems (
    OrderItemID INT            NOT NULL PRIMARY KEY,
    OrderID     INT            NOT NULL,
    ProductID   INT            NOT NULL,
    Quantity    INT            NOT NULL,
    UnitPrice   DECIMAL(10,2)  NOT NULL
);
GO

-- ============================================================
-- Seed: CountryLookup (20 ISO countries, deterministic)
-- ============================================================
INSERT INTO dbo.CountryLookup (CountryCode, CountryName) VALUES
('US','United States'),('CA','Canada'),('MX','Mexico'),('GB','United Kingdom'),
('DE','Germany'),('FR','France'),('NL','Netherlands'),('BE','Belgium'),
('ES','Spain'),('IT','Italy'),('SE','Sweden'),('NO','Norway'),
('DK','Denmark'),('FI','Finland'),('JP','Japan'),('AU','Australia'),
('NZ','New Zealand'),('BR','Brazil'),('IN','India'),('ZA','South Africa');
GO

-- ============================================================
-- Numbers CTE helper: 1..N from sys.all_objects cross join.
-- ============================================================

-- ---- Products: 100 rows ----
;WITH N AS (
    SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Products (ProductID, Sku, Name, Category, Price, IsActive)
SELECT
    n                                              AS ProductID,
    'sku-' + RIGHT('0000' + CAST(n AS VARCHAR(10)), 5) AS Sku,
    'Product ' + CAST(n AS NVARCHAR(10))           AS Name,
    CHOOSE(((n - 1) % 5) + 1,
           N'Books', N'Electronics', N'Apparel', N'Home', N'Toys') AS Category,
    CAST(5.00 + ((n * 13) % 500) + ((n * 7) % 100) / 100.0 AS DECIMAL(10,2)) AS Price,
    CASE WHEN n % 10 = 0 THEN 0 ELSE 1 END         AS IsActive
FROM N;
GO

-- ---- Customers: 500 rows ----
;WITH N AS (
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
), Countries AS (
    SELECT CountryCode, CountryName,
           ROW_NUMBER() OVER (ORDER BY CountryCode) AS rn,
           COUNT(*)   OVER ()                       AS cnt
    FROM dbo.CountryLookup
)
INSERT INTO dbo.Customers (CustomerID, FullName, Email, Country, CreatedAt)
SELECT
    N.n                                            AS CustomerID,
    N'Customer ' + CAST(N.n AS NVARCHAR(10))       AS FullName,
    'cust' + CAST(N.n AS VARCHAR(10)) + '@example.com' AS Email,
    C.CountryName                                  AS Country,
    DATEADD(DAY, -((N.n * 3) % 1000),
            CAST('2026-01-01' AS DATETIME2(0)))    AS CreatedAt
FROM N
JOIN Countries C ON ((N.n - 1) % C.cnt) + 1 = C.rn;
GO

-- ---- Orders: 2000 rows ----
;WITH N AS (
    SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (OrderID, CustomerID, OrderDate, TotalAmount, Status)
SELECT
    n                                              AS OrderID,
    ((n - 1) % 500) + 1                            AS CustomerID,
    DATEADD(HOUR, -((n * 7) % 8760),
            CAST('2026-05-26' AS DATETIME2(0)))    AS OrderDate,
    CAST(20.00 + ((n * 17) % 2000) + ((n * 11) % 100) / 100.0 AS DECIMAL(12,2)) AS TotalAmount,
    CHOOSE(((n - 1) % 4) + 1,
           N'New', N'Paid', N'Shipped', N'Cancelled') AS Status
FROM N;
GO

-- ---- OrderItems: 6000 rows (3 per order on average) ----
;WITH N AS (
    SELECT TOP (6000) ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.OrderItems (OrderItemID, OrderID, ProductID, Quantity, UnitPrice)
SELECT
    n                                              AS OrderItemID,
    ((n - 1) % 2000) + 1                           AS OrderID,
    ((n * 7) % 100) + 1                            AS ProductID,
    ((n * 3) % 5) + 1                              AS Quantity,
    CAST(5.00 + ((n * 13) % 500) AS DECIMAL(10,2)) AS UnitPrice
FROM N;
GO

PRINT '--- SalesSrc seed complete ---';
SELECT 'CountryLookup' AS TableName, COUNT(*) AS Rows FROM dbo.CountryLookup
UNION ALL SELECT 'Customers',  COUNT(*) FROM dbo.Customers
UNION ALL SELECT 'Products',   COUNT(*) FROM dbo.Products
UNION ALL SELECT 'Orders',     COUNT(*) FROM dbo.Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems;
GO
