# 03 — `Load_Products_Scripted` → `dim.DimProduct`

> Depends on: `01-prereqs-and-source-schema.md`. Read `CONSTITUTION.md`.

Migrates the `Load_Products_Scripted` SSIS package. Original layout:
Flat File Source → Script Component (`UPPER(Sku)` + `MarginCategory`
derivation) → OLE DB Destination. Migration target eliminates the Script
Component — the transformation is expressed as a SQL `CASE`/`UPPER`.

## SSIS Lineage

From `migration/source-analysis/Load_Products_Scripted/`:

1. **`DFT_LoadProducts`** — Data Flow:
   - **`FF_SRC_Products`** — Flat File Source (`ProductsCsv` connection
     manager → `..\csv\products_incoming.csv`). Columns: `ProductID INT,
     Sku STR(50), Name STR(200), Category STR(50), Price NUMERIC(10,2),
     IsActive INT`. Row delimiter `CRLF`, column delimiter `,`.
   - **`SCR_Enrich`** — Script Component (CSharp). Source code captured in
     `migration/source-analysis/Load_Products_Scripted/extract-scripts.json`.
     Behaviour:
     - `Row.Sku = Row.Sku.ToUpperInvariant();`
     - if `price < 50m` → `MarginCategory = "LOW"`
     - else if `price < 200m` → `MarginCategory = "MEDIUM"`
     - else → `MarginCategory = "HIGH"`
   - **`OLE_DST_DimProduct`** — OLE DB Destination, `AccessMode=3`,
     `OpenRowset=[dim].[DimProduct]`. Maps `ProductID, Sku, Name,
     Category, Price, MarginCategory`.

## Source Tables

Logical source = `products_incoming.csv` (100 rows). By construction this
CSV is byte-equivalent in semantics to `SalesSrc.dbo.Products`:

| Column | CSV type | SQL Server equivalent |
|---|---|---|
| `ProductID` | INT | `INT NOT NULL` (PK) |
| `Sku` | STR(50) | `NVARCHAR(50)` |
| `Name` | STR(200) | `NVARCHAR(200)` |
| `Category` | STR(50) | `NVARCHAR(50)` |
| `Price` | NUMERIC(10,2) | `DECIMAL(10,2)` |
| `IsActive` | INT (0/1) | `BIT` |

For Fabric, **prefer reading `SalesSrc.dbo.Products` over the CSV** —
they're identical and the SQL source is easier to govern. Keep the CSV
path documented for parity with the original package.

## Source Extraction Logic

```sql
SELECT ProductID, Sku, Name, Category, Price, IsActive
FROM dbo.Products;
```

Or, when reading the CSV instead, the equivalent PySpark read:

```python
df = spark.read.option("header", True).schema(
    "ProductID INT, Sku STRING, Name STRING, Category STRING, "
    "Price DECIMAL(10,2), IsActive INT"
).csv("Files/raw/products_incoming.csv")
```

- **NULL handling:** none in source; all columns are NOT NULL.
- **Known quirks:** the original Script Component is C# and requires a
  precompiled binary in the DTSX; the demo's hand-authored package fails
  validation under `dtexec` for this reason (see `migration/MIGRATION.md`).
  The migration **eliminates** the script — its logic is fully captured
  as the SQL expressions below, so this is a feature, not a regression.

## Staging Schema (Flavor A)

```sql
CREATE TABLE stg.DimProduct (
    ProductID  INT            NOT NULL,
    Sku        NVARCHAR(50)   NOT NULL,
    Name       NVARCHAR(200)  NOT NULL,
    Category   NVARCHAR(50)   NOT NULL,
    Price      DECIMAL(10,2)  NOT NULL
);
```

`IsActive` is intentionally dropped — destination has no such column.

## Destination Table

**Flavor A — Warehouse DDL:**

```sql
CREATE TABLE dim.DimProduct (
    ProductKey      INT             IDENTITY(1,1) NOT NULL,
    ProductID       INT             NOT NULL,
    Sku             NVARCHAR(50)    NOT NULL,
    Name            NVARCHAR(200)   NOT NULL,
    Category        NVARCHAR(50)    NOT NULL,
    Price           DECIMAL(10,2)   NOT NULL,
    MarginCategory  NVARCHAR(20)    NULL
);
```

**Flavor B — Delta `dim_product`:**

| SQL Server | Delta | Notes |
|---|---|---|
| `ProductKey` | — | OMIT in Delta. |
| `ProductID` | `product_id` | business key |
| `Sku` | `sku` | UPPER-cased |
| `Name` | `name` | |
| `Category` | `category` | |
| `Price` | `price` | DECIMAL(10,2) |
| `MarginCategory` | `margin_category` | STRING |

## Column Mapping — Source to Destination

| Destination | Source | Expression |
|---|---|---|
| `ProductID` | `Products.ProductID` | direct |
| `Sku` | `Products.Sku` | `UPPER(Sku)` (replaces `Row.Sku.ToUpperInvariant()`) |
| `Name` | `Products.Name` | direct |
| `Category` | `Products.Category` | direct |
| `Price` | `Products.Price` | direct, `DECIMAL(10,2)` |
| `MarginCategory` | derived | `CASE WHEN Price < 50 THEN N'LOW' WHEN Price < 200 THEN N'MEDIUM' ELSE N'HIGH' END` |

## Merge Logic

This is a non-SCD dimension (no `IsCurrent`/`ValidFrom` columns). Use a
truncate-then-load for initial deploy, then a `MERGE` for incremental:

```sql
CREATE OR ALTER PROCEDURE stg.sp_load_dim_product
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE stg.DimProduct;
    INSERT INTO stg.DimProduct (ProductID, Sku, Name, Category, Price)
    SELECT P.ProductID,
           UPPER(P.Sku),
           P.Name,
           P.Category,
           P.Price
    FROM <source-shortcut>.dbo.Products P;

    MERGE dim.DimProduct AS T
    USING (
        SELECT ProductID, Sku, Name, Category, Price,
               CASE WHEN Price < 50  THEN N'LOW'
                    WHEN Price < 200 THEN N'MEDIUM'
                    ELSE N'HIGH' END AS MarginCategory
        FROM stg.DimProduct
    ) AS S
    ON T.ProductID = S.ProductID
    WHEN MATCHED AND (T.Sku <> S.Sku OR T.Name <> S.Name OR T.Category <> S.Category
                      OR T.Price <> S.Price OR ISNULL(T.MarginCategory,N'') <> S.MarginCategory) THEN
        UPDATE SET Sku = S.Sku, Name = S.Name, Category = S.Category,
                   Price = S.Price, MarginCategory = S.MarginCategory
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (ProductID, Sku, Name, Category, Price, MarginCategory)
        VALUES (S.ProductID, S.Sku, S.Name, S.Category, S.Price, S.MarginCategory);

    UPDATE stg.LoadWatermarks
       SET LastLoadedUtc = SYSUTCDATETIME(),
           UpdatedUtc    = SYSUTCDATETIME()
     WHERE Entity = N'DimProduct';
END
```

## Watermark / Incremental Strategy

Initial-load only for the demo. There is no audit column on
`SalesSrc.dbo.Products`, so a true incremental load would need a CDC source
or full-table compare. Out of scope.

## PySpark Source Query (Flavor B)

Either read from JDBC (`dbo.Products`) or `Files/raw/products_incoming.csv`.
Apply the same `UPPER(sku)` and `when().when().otherwise()` for
`margin_category` in Spark.

## Testing

- Row count: `SELECT COUNT(*) FROM dim.DimProduct` → expected **100**
  (matches `out/baseline/target-rowcounts.json`).
- Checksum: `SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM dim.DimProduct`
  → expected **`-1133310955`**.
- Sku uppercased: `SELECT TOP 10 Sku FROM dim.DimProduct` — every value
  matches `^SKU-[0-9]{5}$`.
- Margin bands: assert counts per band match
  `(price < 50, price between 50 and <200, price >= 200)` applied to the
  source data.
