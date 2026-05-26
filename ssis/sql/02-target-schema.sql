/*
  02-target-schema.sql
  Build target Data Warehouse schema in SalesDW.
  Schemas:
    dim  - dimension tables (SCD2-ish for DimCustomer)
    fact - fact tables
*/

USE [SalesDW];
GO

-- ============================================================
-- Schemas
-- ============================================================
IF SCHEMA_ID('dim') IS NULL EXEC('CREATE SCHEMA dim AUTHORIZATION dbo;');
IF SCHEMA_ID('fact') IS NULL EXEC('CREATE SCHEMA fact AUTHORIZATION dbo;');
GO

-- ============================================================
-- Drop existing tables (in FK-safe order) for clean rebuild
-- ============================================================
IF OBJECT_ID('fact.FactOrders','U') IS NOT NULL DROP TABLE fact.FactOrders;
IF OBJECT_ID('dim.DimCustomer','U') IS NOT NULL DROP TABLE dim.DimCustomer;
IF OBJECT_ID('dim.DimProduct','U')  IS NOT NULL DROP TABLE dim.DimProduct;
GO

-- ============================================================
-- dim.DimCustomer  (SCD Type 2)
-- ============================================================
CREATE TABLE dim.DimCustomer (
    CustomerKey  INT             IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CustomerID   INT             NOT NULL,
    FullName     NVARCHAR(100)   NOT NULL,
    Email        NVARCHAR(200)   NOT NULL,
    CountryName  NVARCHAR(50)    NOT NULL,
    ValidFrom    DATETIME2(0)    NOT NULL,
    ValidTo      DATETIME2(0)    NULL,
    IsCurrent    BIT             NOT NULL
);
CREATE INDEX IX_DimCustomer_CustomerID ON dim.DimCustomer (CustomerID) INCLUDE (IsCurrent);
GO

-- ============================================================
-- dim.DimProduct
-- ============================================================
CREATE TABLE dim.DimProduct (
    ProductKey   INT             IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProductID    INT             NOT NULL,
    Sku          NVARCHAR(50)    NOT NULL,
    Name         NVARCHAR(200)   NOT NULL,
    Category     NVARCHAR(50)    NOT NULL,
    Price        DECIMAL(10,2)   NOT NULL,
    MarginCategory NVARCHAR(20)  NULL
);
CREATE INDEX IX_DimProduct_ProductID ON dim.DimProduct (ProductID);
GO

-- ============================================================
-- fact.FactOrders
-- ============================================================
CREATE TABLE fact.FactOrders (
    OrderKey     BIGINT          IDENTITY(1,1) NOT NULL PRIMARY KEY,
    OrderID      INT             NOT NULL,
    CustomerKey  INT             NULL,
    OrderDate    DATETIME2(0)    NOT NULL,
    TotalAmount  DECIMAL(12,2)   NOT NULL,
    Status       NVARCHAR(20)    NOT NULL
);
CREATE INDEX IX_FactOrders_CustomerKey ON fact.FactOrders (CustomerKey);
GO

PRINT '--- SalesDW schema ready ---';
GO
