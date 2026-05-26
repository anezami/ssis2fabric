# 02 — `Load_Customers` → `dim.DimCustomer`

> Depends on: `01-prereqs-and-source-schema.md`. Read `CONSTITUTION.md`.

Migrates the `Load_Customers` SSIS package into a Fabric-native load that
produces `dim.DimCustomer` with SCD2-ready columns. The original package
performs an initial load (truncate then reload). This spec preserves that
behaviour while leaving the door open for incremental SCD2 in a follow-up.

## SSIS Lineage

From `migration/source-analysis/Load_Customers/`:

1. **`SQL_TruncateDimCustomer`** — Execute SQL Task on `SalesDwConn`,
   statement `TRUNCATE TABLE dim.DimCustomer;`
2. **Precedence constraint `TruncateThenLoad`** (LogicalAnd=True) →
3. **`DFT_LoadCustomers`** — Data Flow:
   - **`OLE_SRC_Customers`** — OLE DB Source, SQL command:

     ```sql
     SELECT C.CustomerID, C.FullName, C.Email, CL.CountryName,
            SYSUTCDATETIME() AS ValidFrom
     FROM dbo.Customers C
     LEFT JOIN dbo.CountryLookup CL ON CL.CountryName = C.Country;
     ```

   - **`OLE_DST_DimCustomer`** — OLE DB Destination, `AccessMode=3`
     (fast load), `OpenRowset=[dim].[DimCustomer]`. Maps the five source
     columns straight through; relies on the table defaults for
     `ValidTo` (NULL) and `IsCurrent`.

## Source Tables

`SalesSrc.dbo.Customers` (500 rows) and `SalesSrc.dbo.CountryLookup`
(20 rows). Schemas in `01-prereqs-and-source-schema.md`.

## Source Extraction Logic

The SSIS package embeds the `SELECT` shown above. Notes:

- **Join semantics:** `LEFT JOIN` keeps Customer rows even if the
  country name is missing from `CountryLookup`. In the seed data the join
  always matches (every Customer.Country exists in CountryLookup.CountryName).
- **`ValidFrom` derivation:** computed at extraction time via
  `SYSUTCDATETIME()` on the source server.
- **NULL handling:** `CountryName` can theoretically be NULL after the
  LEFT JOIN; for the seed it is never NULL. The destination column is
  `NOT NULL` in the original DDL — preserve that and let the load fail
  loudly if a stale country slips in. Document this as a known constraint.
- **Known bugs / quirks:** none. Hand-authored package, deterministic seed.

## Staging Schema

**Flavor A (Warehouse).** Use a staging table `stg.DimCustomer` for
idempotent loads:

```sql
CREATE TABLE stg.DimCustomer (
    CustomerID   INT            NOT NULL,
    FullName     NVARCHAR(100)  NOT NULL,
    Email        NVARCHAR(200)  NOT NULL,
    CountryName  NVARCHAR(50)   NOT NULL,
    ValidFrom    DATETIME2(0)   NOT NULL
);
```

## Destination Table

**Flavor A — Warehouse DDL (deployable to `wh_ssis_demo`):**

```sql
CREATE TABLE dim.DimCustomer (
    CustomerKey  INT             IDENTITY(1,1) NOT NULL,
    CustomerID   INT             NOT NULL,
    FullName     NVARCHAR(100)   NOT NULL,
    Email        NVARCHAR(200)   NOT NULL,
    CountryName  NVARCHAR(50)    NOT NULL,
    ValidFrom    DATETIME2(0)    NOT NULL,
    ValidTo      DATETIME2(0)    NULL,
    IsCurrent    BIT             NOT NULL
);
-- Fabric Warehouse does not support CREATE INDEX on columnstore by default.
-- Skip the IX_DimCustomer_CustomerID index that exists in the on-prem schema
-- (it is documented but not required for correctness).
```

**Flavor B — Lakehouse Delta table `dim_customer`:**

| SQL Server name | Delta name | Notes |
|---|---|---|
| `CustomerKey` | — | OMIT in Delta; generate via `monotonically_increasing_id()` or row_number() if needed. |
| `CustomerID` | `customer_id` | business key |
| `FullName` | `full_name` | |
| `Email` | `email` | |
| `CountryName` | `country_name` | |
| `ValidFrom` | `valid_from` | TIMESTAMP |
| `ValidTo` | `valid_to` | nullable TIMESTAMP |
| `IsCurrent` | `is_current` | BOOLEAN |

## Column Mapping — Source to Destination

| Destination | Source | Expression |
|---|---|---|
| `CustomerID` | `Customers.CustomerID` | direct |
| `FullName` | `Customers.FullName` | direct |
| `Email` | `Customers.Email` | direct |
| `CountryName` | `CountryLookup.CountryName` | LEFT JOIN on `CountryName = Customers.Country` |
| `ValidFrom` | (computed) | `SYSUTCDATETIME()` at extraction time |
| `ValidTo` | — | always `NULL` for initial load |
| `IsCurrent` | — | always `1` for initial load |

## SCD Type 2 Merge Logic

Initial-load semantics in the original package = truncate + insert.

**Flavor A — Warehouse MERGE-shaped procedure (exact T-SQL):**

```sql
CREATE OR ALTER PROCEDURE stg.sp_load_dim_customer
AS
BEGIN
    SET NOCOUNT ON;
    -- 1) Stage
    TRUNCATE TABLE stg.DimCustomer;
    INSERT INTO stg.DimCustomer (CustomerID, FullName, Email, CountryName, ValidFrom)
    SELECT C.CustomerID, C.FullName, C.Email, CL.CountryName, SYSUTCDATETIME()
    FROM <source-shortcut>.dbo.Customers C
    LEFT JOIN <source-shortcut>.dbo.CountryLookup CL
        ON CL.CountryName = C.Country;

    -- 2) Close off existing current rows whose attributes changed
    UPDATE D
       SET ValidTo   = SYSUTCDATETIME(),
           IsCurrent = 0
    FROM dim.DimCustomer D
    INNER JOIN stg.DimCustomer S ON S.CustomerID = D.CustomerID
    WHERE D.IsCurrent = 1
      AND (S.FullName    <> D.FullName
        OR S.Email       <> D.Email
        OR S.CountryName <> D.CountryName);

    -- 3) Insert new versions (and brand-new customers)
    INSERT INTO dim.DimCustomer (CustomerID, FullName, Email, CountryName,
                                 ValidFrom, ValidTo, IsCurrent)
    SELECT S.CustomerID, S.FullName, S.Email, S.CountryName,
           S.ValidFrom, NULL, 1
    FROM stg.DimCustomer S
    LEFT JOIN dim.DimCustomer D
        ON D.CustomerID = S.CustomerID AND D.IsCurrent = 1
    WHERE D.CustomerKey IS NULL
       OR S.FullName    <> D.FullName
       OR S.Email       <> D.Email
       OR S.CountryName <> D.CountryName;

    -- 4) Update lineage
    UPDATE stg.LoadWatermarks
       SET LastLoadedUtc = SYSUTCDATETIME(),
           UpdatedUtc    = SYSUTCDATETIME()
     WHERE Entity = N'DimCustomer';
END
```

`<source-shortcut>` is the name of the Fabric shortcut into the source data
(see CONSTITUTION). For the demo initial load, `dim.DimCustomer` is empty so
steps 2 and 3 reduce to a plain insert of all 500 staging rows.

**Flavor B — Delta MERGE skeleton (for the build agent to flesh out):**

```text
MERGE INTO dim_customer t
USING stg_dim_customer s
ON t.customer_id = s.customer_id AND t.is_current = true
WHEN MATCHED AND (
        s.full_name    <> t.full_name
     OR s.email        <> t.email
     OR s.country_name <> t.country_name) THEN
  UPDATE SET t.valid_to = current_timestamp(), t.is_current = false
WHEN NOT MATCHED THEN
  INSERT (customer_id, full_name, email, country_name,
          valid_from, valid_to, is_current)
  VALUES (s.customer_id, s.full_name, s.email, s.country_name,
          s.valid_from, NULL, true);
-- followed by a second INSERT pass for the "new version" rows where
-- attributes changed (Delta MERGE can't INSERT + UPDATE the same source row).
```

## Watermark / Incremental Strategy

Initial-load seed value: `1900-01-01`. After the first successful run, set
`stg.LoadWatermarks.LastLoadedUtc = SYSUTCDATETIME()`. Incremental runs
would filter `Customers.CreatedAt > LastLoadedUtc`; deferred until after the
demo validates the initial load.

## PySpark Source Query (Flavor B)

**Option A — JDBC pushdown of the SELECT:**

```python
src = (spark.read.format("jdbc")
    .option("url",   jdbc_url)
    .option("query", """
        SELECT C.CustomerID, C.FullName, C.Email, CL.CountryName,
               SYSUTCDATETIME() AS ValidFrom
        FROM dbo.Customers C
        LEFT JOIN dbo.CountryLookup CL ON CL.CountryName = C.Country""")
    .load())
```

**Option B — read both tables and join in Spark.** Use this if you've
already landed `Customers` and `CountryLookup` as Parquet in `Files/raw/`.

## Testing

- Row count: `SELECT COUNT(*) FROM dim.DimCustomer WHERE IsCurrent = 1` →
  expected **500** (matches `out/baseline/target-rowcounts.json`).
- Checksum: `SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM dim.DimCustomer`
  → expected **`-1433270017`** (baseline in `target-rowcounts.json`).
- Spot check: random `CustomerID` → matches `SalesSrc.dbo.Customers` for
  `FullName`/`Email`, and `CountryName` equals the join target.
- Idempotency: re-running the proc against unchanged staging produces zero
  new rows and zero closed-off rows.
