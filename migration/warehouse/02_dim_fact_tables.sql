-- 02_dim_fact_tables.sql
-- Final dimensional / fact tables in the dw schema.
-- Fabric Warehouse caveats:
--   * No IDENTITY -> surrogate keys are assigned in the load procs via
--     ROW_NUMBER() over a stable ordering on the natural key.
--   * No NVARCHAR -> VARCHAR everywhere.
--   * No CHECK / FK constraints required at runtime (Warehouse treats them
--     as metadata-only); we omit them for clarity.

DROP TABLE IF EXISTS dw.DimCustomer;
CREATE TABLE dw.DimCustomer (
    CustomerKey   BIGINT          NOT NULL,
    CustomerID    INT             NOT NULL,
    FullName      VARCHAR(100)    NOT NULL,
    Email         VARCHAR(200)    NOT NULL,
    CountryName   VARCHAR(50)     NOT NULL,
    ValidFrom     DATETIME2(6)    NOT NULL,
    ValidTo       DATETIME2(6)    NULL,
    IsCurrent     BIT             NOT NULL
);

DROP TABLE IF EXISTS dw.DimProduct;
CREATE TABLE dw.DimProduct (
    ProductKey      BIGINT          NOT NULL,
    ProductID       INT             NOT NULL,
    Sku             VARCHAR(50)     NOT NULL,
    Name            VARCHAR(200)    NOT NULL,
    Category        VARCHAR(50)     NOT NULL,
    Price           DECIMAL(10,2)   NOT NULL,
    MarginCategory  VARCHAR(20)     NOT NULL
);

DROP TABLE IF EXISTS dw.FactOrders;
CREATE TABLE dw.FactOrders (
    OrderKey      BIGINT          NOT NULL,
    OrderID       INT             NOT NULL,
    CustomerKey   BIGINT          NULL,
    OrderDate     DATETIME2(6)    NOT NULL,
    TotalAmount   DECIMAL(12,2)   NOT NULL,
    Status        VARCHAR(20)     NOT NULL
);

-- Operational logging table for the orchestrator.
DROP TABLE IF EXISTS dw.LoadLog;
CREATE TABLE dw.LoadLog (
    LogID         BIGINT          NOT NULL,
    ProcName      VARCHAR(128)    NOT NULL,
    StartedUtc    DATETIME2(6)    NOT NULL,
    EndedUtc      DATETIME2(6)    NULL,
    Status        VARCHAR(20)     NOT NULL,   -- RUNNING|SUCCESS|FAILED
    RowsAffected  BIGINT          NULL,
    ErrorMessage  VARCHAR(4000)   NULL
);
