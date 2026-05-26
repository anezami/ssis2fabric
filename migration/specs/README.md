# SsisDemo → Fabric — Migration Specs

Ground-truth specifications for migrating the **SsisDemo** SSIS project (three
packages — Customers, Products, Orders) from a SQL Server 2022 source to
Microsoft Fabric. The same spec set drives two build passes:

- **Flavor A — Fabric Warehouse** (T-SQL DDL + MERGE/INSERT procs).
- **Flavor B — Fabric Lakehouse** (PySpark notebooks writing Delta tables).

The numbered specs below contain the T-SQL DDL needed for Flavor A. The
Lakehouse Delta-name mapping appears alongside each destination table.

## What it migrates

The `SsisDemo.ispac` SSIS project ships three packages that together load a
small star schema in `SalesDW`:

1. `Load_Customers` — OLE DB Source (`SalesSrc.dbo.Customers` join
   `dbo.CountryLookup`) → OLE DB Destination (`SalesDW.dim.DimCustomer`).
   Initial-load semantics; the destination table is modelled SCD2-ready
   (`ValidFrom`, `ValidTo`, `IsCurrent`).
2. `Load_Products_Scripted` — Flat File Source
   (`C:\ssisdemo\csv\products_incoming.csv`) → Script Component
   (`UPPER(Sku)`, derive `MarginCategory` from `Price`) → OLE DB Destination
   (`SalesDW.dim.DimProduct`).
3. `Load_Orders` — OLE DB Source (`SalesSrc.dbo.Orders`) → Lookup against
   current `dim.DimCustomer` → OLE DB Destination
   (`SalesDW.fact.FactOrders`).

## Specs

Implement in order — each spec builds on the previous.

| File | Description |
|---|---|
| `CONSTITUTION.md` | Project-level facts: source server, Fabric workspace/warehouse/lakehouse, auth, naming. |
| `01-prereqs-and-source-schema.md` | Source database schema (`SalesSrc`), shared lineage table, watermark strategy. |
| `02-dim-customer.md` | `Load_Customers` → `dim.DimCustomer` (SCD2 initial load). |
| `03-dim-product.md` | `Load_Products_Scripted` → `dim.DimProduct` (CSV + transform). |
| `04-fact-orders.md` | `Load_Orders` → `fact.FactOrders` (lookup join, fact insert). |

## How to use

Pick **sjd-builder** from the Copilot chat-mode dropdown (or any equivalent
build agent for Fabric Warehouse T-SQL) and hand it one spec at a time:

```
implement migration/specs/01-prereqs-and-source-schema.md
```

For the full pipeline:

```
implement the spec in migration/specs/
```

## Reference materials

| Artifact | Path | Purpose |
|----------|------|---------|
| SSIS project (.ispac) | `migration/source/SsisDemo.ispac` | Three DTSX packages + project params |
| Source DB (.bacpac) | `migration/source/SalesSrc.bacpac` | `SalesSrc` schema + seed data (CountryLookup, Customers, Products, Orders, OrderItems) |
| Target DB (.bacpac) | `migration/source/SalesDW.bacpac` | `SalesDW` schema + post-run data (dim.DimCustomer, dim.DimProduct, fact.FactOrders) |
| Source row counts | `out/baseline/source-rowcounts.json` | Helly's source-side baseline |
| Target row counts + checksums | `out/baseline/target-rowcounts.json` | Helly's target-side baseline |
| SSIS analyzer dumps | `migration/source-analysis/` | Per-package overview + data flows + SQL + scripts |
| DACPAC analyzer dumps | `migration/dacpac-analysis/` | Per-database schema dumps |
