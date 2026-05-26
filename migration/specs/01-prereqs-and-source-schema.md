# 01 — Prerequisites and Source Schema

> Depends on: nothing. Read `CONSTITUTION.md` first.

This spec establishes shared infrastructure: the source schema (read-only
view of `SalesSrc`), the shared lineage/watermark table, and the schemas in
the target Warehouse (or Lakehouse equivalent).

## SSIS Lineage

None — this is a prerequisite spec. The SSIS project does **not** create
infrastructure; the three packages assume the destination tables already
exist. This spec replaces the manual schema-creation step
(`ssis/sql/00-create-databases.sql` and `02-target-schema.sql`).

## Source Tables

From `migration/dacpac-analysis/SalesSrc/list-tables.json`:

### `SalesSrc.dbo.CountryLookup`

| Column | Type | Null | Notes |
|---|---|---|---|
| `CountryCode` | `CHAR(2)` | NOT NULL | PK |
| `CountryName` | `NVARCHAR(50)` | NOT NULL | Used in Customer enrichment join |

20 rows (ISO-2 codes). See `SalesSrc.bacpac`.

### `SalesSrc.dbo.Customers`

| Column | Type | Null | Notes |
|---|---|---|---|
| `CustomerID` | `INT` | NOT NULL | PK, business key |
| `FullName` | `NVARCHAR(100)` | NOT NULL | |
| `Email` | `NVARCHAR(200)` | NOT NULL | |
| `Country` | `NVARCHAR(50)` | NOT NULL | Joins `CountryLookup.CountryName` |
| `CreatedAt` | `DATETIME2(0)` | NOT NULL | |

500 rows.

### `SalesSrc.dbo.Products`

| Column | Type | Null | Notes |
|---|---|---|---|
| `ProductID` | `INT` | NOT NULL | PK |
| `Sku` | `NVARCHAR(50)` | NOT NULL | Will be UPPER-cased in DW |
| `Name` | `NVARCHAR(200)` | NOT NULL | |
| `Category` | `NVARCHAR(50)` | NOT NULL | |
| `Price` | `DECIMAL(10,2)` | NOT NULL | Drives derived `MarginCategory` |
| `IsActive` | `BIT` | NOT NULL | Not propagated to DW |

100 rows. The CSV file `products_incoming.csv` is generated from the same
deterministic formula as this table — by design they hold identical rows.

### `SalesSrc.dbo.Orders`

| Column | Type | Null | Notes |
|---|---|---|---|
| `OrderID` | `INT` | NOT NULL | PK |
| `CustomerID` | `INT` | NOT NULL | FK → `Customers.CustomerID` |
| `OrderDate` | `DATETIME2(0)` | NOT NULL | |
| `TotalAmount` | `DECIMAL(12,2)` | NOT NULL | |
| `Status` | `NVARCHAR(20)` | NOT NULL | one of `New|Paid|Shipped|Cancelled` |

2,000 rows.

### `SalesSrc.dbo.OrderItems`

| Column | Type | Null | Notes |
|---|---|---|---|
| `OrderItemID` | `INT` | NOT NULL | PK |
| `OrderID` | `INT` | NOT NULL | FK → `Orders.OrderID` |
| `ProductID` | `INT` | NOT NULL | FK → `Products.ProductID` |
| `Quantity` | `INT` | NOT NULL | |
| `UnitPrice` | `DECIMAL(10,2)` | NOT NULL | |

6,000 rows. Not consumed by the current SSIS project — preserved for future
fact-line extensions.

## Source Extraction Logic

Source tables are read directly — no extraction procs in `SalesSrc`. Each
SSIS data flow embeds its own `SELECT`; per-spec extraction SQL is
reproduced in the numbered specs that follow.

## Destination — shared infrastructure

### Flavor A (Warehouse) — T-SQL DDL ready to deploy

```sql
-- Schemas
IF SCHEMA_ID('stg')  IS NULL EXEC('CREATE SCHEMA stg  AUTHORIZATION dbo;');
IF SCHEMA_ID('dim')  IS NULL EXEC('CREATE SCHEMA dim  AUTHORIZATION dbo;');
IF SCHEMA_ID('fact') IS NULL EXEC('CREATE SCHEMA fact AUTHORIZATION dbo;');
GO

-- Shared lineage + watermark table
IF OBJECT_ID('stg.LoadWatermarks','U') IS NULL
CREATE TABLE stg.LoadWatermarks (
    Entity        NVARCHAR(50)  NOT NULL PRIMARY KEY NONCLUSTERED,
    LastLoadedUtc DATETIME2(0)  NOT NULL,
    LastLoadedKey BIGINT        NULL,        -- for fact-style high-watermark
    UpdatedUtc    DATETIME2(0)  NOT NULL
);

-- Seed: cutoff far in the past so initial loads pick up everything
MERGE stg.LoadWatermarks AS T
USING (VALUES
    (N'DimCustomer', CAST('1900-01-01' AS DATETIME2(0)), CAST(0 AS BIGINT)),
    (N'DimProduct',  CAST('1900-01-01' AS DATETIME2(0)), CAST(0 AS BIGINT)),
    (N'FactOrders',  CAST('1900-01-01' AS DATETIME2(0)), CAST(0 AS BIGINT))
) AS S(Entity, LastLoadedUtc, LastLoadedKey)
ON T.Entity = S.Entity
WHEN NOT MATCHED BY TARGET THEN
    INSERT (Entity, LastLoadedUtc, LastLoadedKey, UpdatedUtc)
    VALUES (S.Entity, S.LastLoadedUtc, S.LastLoadedKey, SYSUTCDATETIME());
```

### Flavor B (Lakehouse) equivalent

- Create Delta table `Tables/stg_load_watermarks` with columns
  `entity STRING, last_loaded_utc TIMESTAMP, last_loaded_key BIGINT, updated_utc TIMESTAMP`.
- Seed via PySpark `INSERT OVERWRITE` of the three rows above.

## Staging Schema

No staging tables for this spec — staging is per-load and lives in the
numbered specs.

## Column Mapping — Source to Destination

None for this spec.

## Watermark / Incremental Strategy

A single row in `stg.LoadWatermarks` per entity. For the demo, **initial
load** (`1900-01-01` seed) means each numbered spec performs a full
truncate-then-reload. After the demo proves end-to-end, the value is bumped
to the latest `SYSUTCDATETIME()` and incremental logic kicks in.

## Testing

After deploying the DDL:

```sql
SELECT COUNT(*) AS s FROM sys.schemas WHERE name IN ('stg','dim','fact');
-- expect 3
SELECT Entity, LastLoadedUtc FROM stg.LoadWatermarks ORDER BY Entity;
-- expect 3 rows, all 1900-01-01
```
