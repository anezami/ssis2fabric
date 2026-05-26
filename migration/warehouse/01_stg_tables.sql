-- 01_stg_tables.sql
-- Staging tables in wh_ssis_demo mirroring SalesSrc source columns 1:1.
-- Fabric Warehouse type rules applied:
--   * NVARCHAR is not supported -> VARCHAR (UTF-8 collation handles unicode)
--   * No IDENTITY, no DEFAULT NEWID()
--   * DATETIME2 supported; use DATETIME2(6) (default precision)
--   * DECIMAL(p,s), INT, BIT supported
-- These tables are populated by COPY INTO from Parquet in OneLake
-- (see 99_copy_into_template.sql).

DROP TABLE IF EXISTS stg.CountryLookup;
CREATE TABLE stg.CountryLookup (
    CountryCode  VARCHAR(2)    NOT NULL,
    CountryName  VARCHAR(50)   NOT NULL
);

DROP TABLE IF EXISTS stg.Customers;
CREATE TABLE stg.Customers (
    CustomerID   INT           NOT NULL,
    FullName     VARCHAR(100)  NOT NULL,
    Email        VARCHAR(200)  NOT NULL,
    Country      VARCHAR(50)   NOT NULL,
    CreatedAt    DATETIME2(6)  NOT NULL
);

DROP TABLE IF EXISTS stg.Products;
CREATE TABLE stg.Products (
    ProductID    INT             NOT NULL,
    Sku          VARCHAR(50)     NOT NULL,
    Name         VARCHAR(200)    NOT NULL,
    Category     VARCHAR(50)     NOT NULL,
    Price        DECIMAL(10,2)   NOT NULL,
    IsActive     BIT             NOT NULL
);

DROP TABLE IF EXISTS stg.Orders;
CREATE TABLE stg.Orders (
    OrderID      INT             NOT NULL,
    CustomerID   INT             NOT NULL,
    OrderDate    DATETIME2(6)    NOT NULL,
    TotalAmount  DECIMAL(12,2)   NOT NULL,
    Status       VARCHAR(20)     NOT NULL
);

DROP TABLE IF EXISTS stg.OrderItems;
CREATE TABLE stg.OrderItems (
    OrderItemID  INT             NOT NULL,
    OrderID      INT             NOT NULL,
    ProductID    INT             NOT NULL,
    Quantity     INT             NOT NULL,
    UnitPrice    DECIMAL(10,2)   NOT NULL
);
