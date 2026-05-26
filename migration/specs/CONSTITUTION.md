# CONSTITUTION — SsisDemo Migration

Project-level facts shared by every numbered spec in this directory.
Numbered specs reference this file; never duplicate its values.

## Package

| Field | Value |
|---|---|
| Package name | `SsisDemo` |
| Source layout | `ssis/packages/*.dtsx`, `ssis/sql/*.sql`, `ssis/csv/products_incoming.csv` |
| Target spec dir | `migration/specs/` |
| SSIS project file | `migration/source/SsisDemo.ispac` |

## Stack — Flavor B (Lakehouse)

| Field | Value |
|---|---|
| PySpark | 3.5 (Fabric runtime 1.3 default) |
| Delta Lake | bundled with Fabric runtime 1.3 |
| Python | 3.11 |
| Fabric runtime | 1.3 |

## Stack — Flavor A (Warehouse)

| Field | Value |
|---|---|
| Engine | Fabric Warehouse (T-SQL surface) |
| DDL caveats | `IDENTITY` columns supported on `INT/BIGINT`; `MERGE` supported; no `CHECK` constraints (`dim`/`fact` schemas defined below avoid them). |
| Orchestration | Fabric Data Pipeline `pl_ssis_demo_warehouse` chaining T-SQL stored procedures; manual sequential execution acceptable for demo. |

## Source Database

| Field | Value |
|---|---|
| Server | `20.163.102.57,1433` (Azure VM `vm-ssis-demo` in `rg-ssis2fabric-demo`) |
| Source DB | `SalesSrc` |
| Target DB (on the VM, source of bacpac) | `SalesDW` |
| Driver (SSIS) | `SQLOLEDB.1` |
| Auth on VM | SQL auth, `sa` (password in `infra/.secrets/sql-admin.json`, **never committed**) |

## Destination — Flavor A (Warehouse)

| Field | Value |
|---|---|
| Workspace | `ws-ssis2fabric-demo` (id `c9bd4043-11bf-483d-bfca-1c2b2490c3af`) |
| Warehouse | `wh_ssis_demo` (id `60a68a69-2fc7-42ec-8f34-dff6a219ac76`) |
| SQL endpoint | `2cmo46ndvemuvau5r4jl6j4dx4-inal3sn7ce6urp6kdqvsjegdv4.datawarehouse.fabric.microsoft.com,1433` |
| Schemas | `stg` (transient landing), `dim` (dimensions), `fact` (facts) |
| Naming | PascalCase tables/columns identical to SQL Server; staging tables `stg.<EntityName>` |

## Destination — Flavor B (Lakehouse)

| Field | Value |
|---|---|
| Lakehouse | `lh_ssis_demo` (id `e3fcb33a-13d8-4967-add9-5efed6fcac65`) |
| OneLake path | `abfss://ws-ssis2fabric-demo@onelake.dfs.fabric.microsoft.com/lh_ssis_demo.Lakehouse` |
| Raw landing | `Files/raw/` (Parquet exports of source tables + `products_incoming.csv`) |
| Tables | Delta tables under `Tables/` |
| Naming | snake_case Delta names; mapping table in each numbered spec |

## Authentication

| Context | Mechanism |
|---|---|
| Local (dev box) → VM SQL | SQL auth, `sa` credentials read at runtime from `infra/.secrets/sql-admin.json` (gitignored) |
| Local (dev box) → Fabric | `az` CLI bearer token, `Authentication=Active Directory Default` |
| Fabric Warehouse runtime | Workspace identity (Entra) — set by Irving's deploy script |
| Fabric Lakehouse runtime | Workspace identity (Entra) — set by Irving's deploy script |

## Environment Configuration

- Local runs read SQL creds from `infra/.secrets/sql-admin.json`.
- Fabric runs use the workspace identity; no secrets in code.
- Watermark storage: a single-row table `stg.LoadWatermarks` (see `01-prereqs-and-source-schema.md`) in the Warehouse; equivalent Delta table `stg_load_watermarks` in the Lakehouse.

## Fabric Targets

| Field | Value |
|---|---|
| Workspace | `ws-ssis2fabric-demo` |
| Warehouse | `wh_ssis_demo` |
| Lakehouse | `lh_ssis_demo` |
| Spark Job Definition | (Flavor B only) `sjd_ssis_demo_lakehouse` — TBD until Irving provisions |
| Environment | (Flavor B only) `env_ssis_demo` — TBD |

## Source Material

| Artifact | Path | Purpose |
|----------|------|---------|
| `.ispac` | `migration/source/SsisDemo.ispac` | SSIS project: 3 DTSX + project params |
| `.bacpac` (source) | `migration/source/SalesSrc.bacpac` | Source OLTP schema + seed |
| `.bacpac` (target) | `migration/source/SalesDW.bacpac` | DW schema + populated tables (truth baseline) |

## Migration Context

The SsisDemo project is a synthetic but realistic SSIS demo: one OLE DB→OLE DB
package, one CSV→Script→OLE DB package, and one OLE DB→Lookup→OLE DB package.
The migration goal is to retire SSIS in favour of Fabric while preserving the
exact row counts and aggregate checksums (`out/baseline/target-rowcounts.json`).
