# 04 — `Load_Orders` → `fact.FactOrders`

> Depends on: `01-prereqs-and-source-schema.md`, `02-dim-customer.md`
> (CustomerKey lookup requires `dim.DimCustomer` to be populated first).

Migrates `Load_Orders` — OLE DB Source → Lookup against
`dim.DimCustomer` → OLE DB Destination — into a join-driven INSERT.

## SSIS Lineage

From `migration/source-analysis/Load_Orders/`:

1. **`DFT_LoadOrders`** — Data Flow:
   - **`OLE_SRC_Orders`** — OLE DB Source, SQL command:

     ```sql
     SELECT OrderID, CustomerID, OrderDate, TotalAmount, Status
     FROM dbo.Orders;
     ```

   - **`LKP_CustomerKey`** — Lookup transform, `CacheType=1` (full cache),
     `NoMatchBehavior=1` (send-no-match-to-no-match-output), reference SQL:

     ```sql
     SELECT CustomerID, CustomerKey
     FROM dim.DimCustomer
     WHERE IsCurrent = 1;
     ```

     Join key: `CustomerID`. Adds the `CustomerKey` column from
     the lookup match output.
   - **`OLE_DST_FactOrders`** — OLE DB Destination, `AccessMode=3`
     (fast load), `OpenRowset=[fact].[FactOrders]`. Receives the
     match-output stream.

## Source Tables

`SalesSrc.dbo.Orders` (2,000 rows) and `dim.DimCustomer`
(after spec 02 loads it). Schemas in `01-prereqs-and-source-schema.md`
and `02-dim-customer.md`.

## Source Extraction Logic

The package embeds the simple `SELECT` above. Notes:

- **No filtering** — full table scan.
- **NULL handling:** all source columns are NOT NULL. The lookup may not
  match if `dim.DimCustomer` is incomplete; SSIS sends those rows to the
  no-match output (which the package does NOT consume — they're dropped).
  Migration target uses a `LEFT JOIN` so unmatched orders land with
  `CustomerKey = NULL`, matching the destination DDL (`CustomerKey INT NULL`).
- **Known quirks:** none. Deterministic seed.

## Staging Schema (Flavor A)

Optional; you can join directly. If used:

```sql
CREATE TABLE stg.FactOrders (
    OrderID     INT             NOT NULL,
    CustomerID  INT             NOT NULL,
    OrderDate   DATETIME2(0)    NOT NULL,
    TotalAmount DECIMAL(12,2)   NOT NULL,
    Status      NVARCHAR(20)    NOT NULL
);
```

## Destination Table

**Flavor A — Warehouse DDL:**

```sql
CREATE TABLE fact.FactOrders (
    OrderKey     BIGINT          IDENTITY(1,1) NOT NULL,
    OrderID      INT             NOT NULL,
    CustomerKey  INT             NULL,
    OrderDate    DATETIME2(0)    NOT NULL,
    TotalAmount  DECIMAL(12,2)   NOT NULL,
    Status       NVARCHAR(20)    NOT NULL
);
```

**Flavor B — Delta `fact_orders`:**

| SQL Server | Delta | Notes |
|---|---|---|
| `OrderKey` | — | OMIT in Delta. |
| `OrderID` | `order_id` | business key |
| `CustomerKey` | `customer_key` | nullable, FK-style reference to `dim_customer` |
| `OrderDate` | `order_date` | TIMESTAMP |
| `TotalAmount` | `total_amount` | DECIMAL(12,2) |
| `Status` | `status` | STRING |

## Column Mapping — Source to Destination

| Destination | Source | Expression |
|---|---|---|
| `OrderID` | `Orders.OrderID` | direct |
| `CustomerKey` | `DimCustomer.CustomerKey` | LEFT JOIN `DimCustomer DC ON DC.CustomerID = Orders.CustomerID AND DC.IsCurrent = 1` |
| `OrderDate` | `Orders.OrderDate` | direct |
| `TotalAmount` | `Orders.TotalAmount` | direct |
| `Status` | `Orders.Status` | direct |

## Insert Logic (no SCD2)

```sql
CREATE OR ALTER PROCEDURE stg.sp_load_fact_orders
AS
BEGIN
    SET NOCOUNT ON;

    -- Initial-load semantics: clear and reload
    TRUNCATE TABLE fact.FactOrders;

    INSERT INTO fact.FactOrders (OrderID, CustomerKey, OrderDate, TotalAmount, Status)
    SELECT O.OrderID,
           DC.CustomerKey,
           O.OrderDate,
           O.TotalAmount,
           O.Status
    FROM <source-shortcut>.dbo.Orders O
    LEFT JOIN dim.DimCustomer DC
        ON DC.CustomerID = O.CustomerID
       AND DC.IsCurrent = 1;

    UPDATE stg.LoadWatermarks
       SET LastLoadedUtc = SYSUTCDATETIME(),
           UpdatedUtc    = SYSUTCDATETIME()
     WHERE Entity = N'FactOrders';
END
```

For incremental loads (future), replace the `TRUNCATE` with a watermark
filter on `O.OrderDate > (SELECT LastLoadedUtc FROM stg.LoadWatermarks
WHERE Entity = N'FactOrders')` and use INSERT-only semantics (orders are
append-only in the source).

## Watermark / Incremental Strategy

Watermark column: `Orders.OrderDate`. Seed value: `1900-01-01`. After
initial load, set to `MAX(OrderDate)`.

## PySpark Source Query (Flavor B)

```python
orders = (spark.read.format("jdbc")
    .option("url", jdbc_url)
    .option("dbtable", "dbo.Orders").load())

fact = (orders.alias("o")
    .join(dim_customer.filter("is_current = true").alias("dc"),
          on=col("o.CustomerID") == col("dc.customer_id"),
          how="left")
    .select(col("o.OrderID").alias("order_id"),
            col("dc.customer_key"),
            col("o.OrderDate").alias("order_date"),
            col("o.TotalAmount").alias("total_amount"),
            col("o.Status").alias("status")))
```

Write with `mode("overwrite")` for initial load; switch to `mode("append")`
once incremental watermarking is wired up.

## Testing

- Row count: `SELECT COUNT(*) FROM fact.FactOrders` → expected **2000**.
- Checksum: `SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM fact.FactOrders`
  → expected **`659028137`**.
- Orphan check: `SELECT COUNT(*) FROM fact.FactOrders WHERE CustomerKey IS NULL`
  → expected **0** for the demo data (every CustomerID has a matching row
  in DimCustomer).
- FK integrity: every non-NULL `CustomerKey` exists in `dim.DimCustomer`.
- Sample join: `SELECT TOP 5 f.OrderID, f.TotalAmount, dc.FullName
  FROM fact.FactOrders f JOIN dim.DimCustomer dc
       ON dc.CustomerKey = f.CustomerKey ORDER BY f.OrderID;`
