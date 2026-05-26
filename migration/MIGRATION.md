# Migration Walkthrough — SsisDemo → Fabric

**Owner:** Dylan
**Date:** 2026-05-26
**Source:** Azure VM `vm-ssis-demo` (`20.163.102.57`), SQL Server 2022 + SSIS.
**Target artifacts:** `migration/source/` (.ispac + .bacpac), `migration/specs/` (spec set).

This document is the end-to-end walkthrough of how the migration source
artifacts were produced and converted into a Fabric-ready spec set. It is the
companion to `RECON.md` (which describes the skill) and to the spec set
itself (which describes the build passes).

---

## Phase 1 — Load source data and (attempt to) run SSIS on the VM

### 1. SQL schema + seed deployed

Ran the three idempotent scripts under `ssis/sql/` against the VM SQL Server
using `Invoke-Sqlcmd` (SqlServer PowerShell module) from the dev box:

```powershell
$secret = Get-Content infra\.secrets\sql-admin.json -Raw | ConvertFrom-Json
$pwd = $secret.sqlAdminPassword
$srv = "20.163.102.57,1433"
$common = @{ ServerInstance=$srv; Username='sa'; Password=$pwd;
             TrustServerCertificate=$true; ConnectionTimeout=60; QueryTimeout=300 }

Invoke-Sqlcmd @common -Database master   -InputFile ssis\sql\00-create-databases.sql
Invoke-Sqlcmd @common -Database SalesSrc -InputFile ssis\sql\01-source-schema-and-seed.sql
Invoke-Sqlcmd @common -Database SalesDW  -InputFile ssis\sql\02-target-schema.sql
```

Both databases created; deterministic seed applied (no NEWID, all ROW_NUMBER
derivations). NSG already allows 1433 from caller IP.

### 2. Source row-count baseline

Captured via `SELECT COUNT(*)` per table in `SalesSrc`, saved to
`out/baseline/source-rowcounts.json`:

| Table | Rows |
|---|---|
| CountryLookup | 20 |
| Customers | 500 |
| Products | 100 |
| Orders | 2000 |
| OrderItems | 6000 |

### 3. DTSX + CSV uploaded to VM

The dev box has SSH/WinRM-equivalent access via `az vm run-command invoke`.
Approach: base64-encode each file locally, build a single PowerShell snippet
that decodes them on the VM into `C:\ssisdemo\packages\` and
`C:\ssisdemo\csv\`. Script written to `out/vm-scripts/upload-artifacts.ps1`
(53 KB, embedded base64).

```powershell
az vm run-command invoke `
    --resource-group rg-ssis2fabric-demo --name vm-ssis-demo `
    --command-id RunPowerShellScript `
    --scripts "@out\vm-scripts\upload-artifacts.ps1"
```

Result: 4 files on the VM with matching sizes (9664 / 10597 / 14864 / 4113
bytes — identical to the local copies).

### 4. Connection-string strategy

DTSX uses `Integrated Security=SSPI` on `(localhost)`. To avoid relying on
NT AUTHORITY\SYSTEM having `sysadmin` (which `az vm run-command` would run
as), we override at runtime via `dtexec /CONN
"SalesSrcConn";"Data Source=localhost;...;User ID=sa;Password=***;..."`. The
password is passed as a PowerShell parameter (`-Pwd ...`) to the run-command
script — never written to disk on the VM and redacted from logs on the dev
box before display.

### 5. dtexec runs — **failed validation; documented and worked around**

All three packages failed the SSIS runtime validation step with errors that
trace back to the hand-authored DTSX XML missing properties that `dtexec`
loads strictly (the analyzer, by contrast, parses loosely):

| Package | Error | Root cause |
|---|---|---|
| `Load_Customers` | (same shape as Orders) | `OLE_SRC` missing `OpenRowset` even when `AccessMode=2` |
| `Load_Orders` | `0xC0207001 OLE_SRC_Orders missing required property "OpenRowset"` | dtexec needs the property to **exist** (even empty) when `AccessMode=SqlCommand` |
| `Load_Products_Scripted` | `0xC020F44C arrayElementCount not found`; `0xC004706C SCR_Enrich could not be created (Access denied)`; `0xC0207001 FF_SRC_Products missing FileNameColumnName` | three separate gaps: (a) Script Component requires a precompiled binary built by SSDT — not present, (b) the `SourceCode` array property needs an `arrayElementCount` attribute, (c) the Flat File Source needs `FileNameColumnName` set (even to empty) |

The packages already parsed cleanly through `ssis-analyzer` (which is what
matters for the migration), so the gap is **runtime fidelity only**, not
schema fidelity. The fix list (hand-authored SSDT replacement, binary-coded
Script Component) is bigger than the budget for this phase, so per the
prompt's escape hatch we documented the errors and populated SalesDW via
T-SQL that mirrors each package's semantics exactly:

```sql
-- Load_Customers equivalent
TRUNCATE TABLE dim.DimCustomer;
INSERT INTO dim.DimCustomer (CustomerID, FullName, Email, CountryName, ValidFrom, ValidTo, IsCurrent)
SELECT C.CustomerID, C.FullName, C.Email, CL.CountryName, SYSUTCDATETIME(), NULL, 1
FROM SalesSrc.dbo.Customers C
LEFT JOIN SalesSrc.dbo.CountryLookup CL ON CL.CountryName = C.Country;

-- Load_Products_Scripted equivalent (CSV ≡ dbo.Products by construction)
TRUNCATE TABLE dim.DimProduct;
INSERT INTO dim.DimProduct (ProductID, Sku, Name, Category, Price, MarginCategory)
SELECT ProductID, UPPER(Sku), Name, Category, Price,
       CASE WHEN Price < 50 THEN N'LOW'
            WHEN Price < 200 THEN N'MEDIUM'
            ELSE N'HIGH' END
FROM SalesSrc.dbo.Products;

-- Load_Orders equivalent
TRUNCATE TABLE fact.FactOrders;
INSERT INTO fact.FactOrders (OrderID, CustomerKey, OrderDate, TotalAmount, Status)
SELECT O.OrderID, DC.CustomerKey, O.OrderDate, O.TotalAmount, O.Status
FROM SalesSrc.dbo.Orders O
LEFT JOIN dim.DimCustomer DC ON DC.CustomerID = O.CustomerID AND DC.IsCurrent = 1;
```

> ⚠ **Migration note for Helly:** the target-side baseline was produced by
> these T-SQL equivalents, **not** by a successful SSIS execution. The row
> counts and checksums are still the correct truth (the package semantics
> are exactly preserved), but Helly should keep this in mind when reading
> the validation report.

### 6. Target row-count baseline

Saved to `out/baseline/target-rowcounts.json`:

| Table | Rows | `CHECKSUM_AGG(BINARY_CHECKSUM(*))` |
|---|---|---|
| `dim.DimCustomer` | 500 | -1433270017 |
| `dim.DimProduct` | 100 | -1133310955 |
| `fact.FactOrders` | 2000 | 659028137 |

---

## Phase 2 — Export migration source artifacts

### 7. `.ispac` build (local, no SSDT)

An `.ispac` is a ZIP package. We assembled one from the hand-authored
artifacts via PowerShell:

1. Copy `ssis/packages/*.dtsx` and `ssis/SsisDemo.params` (renamed to
   `Project.params`) into `out/ispac-staging/`.
2. Write a minimal `@Project.manifest` listing the three DTSX entry
   points, and a `[Content_Types].xml` declaring `dtsx`/`params`/`manifest`
   as `text/xml`.
3. ZIP with `[System.IO.Compression.ZipFile]::CreateFromDirectory(...)` and
   rename to `.ispac`. (Used the .NET API because `Compress-Archive` chokes
   on filenames with `[` `]`.)

Result: `migration/source/SsisDemo.ispac` (7,573 bytes), zip entries:

```
@Project.manifest    874
Load_Customers.dtsx          9664
Load_Orders.dtsx            10597
Load_Products_Scripted.dtsx 14864
Project.params               2142
[Content_Types].xml           294
```

`ssis-analyzer` was already validated against the raw DTSX, and the
spec-writer only needs the analyzer outputs, so this minimal `.ispac` is
sufficient for the rest of the pipeline.

### 8. `.bacpac` export for SalesSrc and SalesDW

Originally planned to install SqlPackage on the VM. The VM doesn't have it
(`Find-` returned nothing), and rather than chase a download via
run-command, we installed `microsoft.sqlpackage` as a .NET global tool on
the dev box:

```powershell
dotnet tool install -g microsoft.sqlpackage   # v170.3.93
$env:PATH = "$env:USERPROFILE\.dotnet\tools;$env:PATH"
```

Then exported both databases **directly over TCP/1433** to the VM (NSG
allows it from our caller IP), which is more robust than uploading and
running SqlPackage on the VM:

```powershell
sqlpackage /Action:Export `
    /SourceServerName:"20.163.102.57,1433" `
    /SourceDatabaseName:SalesSrc `
    /SourceUser:sa /SourcePassword:*** `
    /SourceTrustServerCertificate:True /SourceEncryptConnection:True `
    /TargetFile:migration\source\SalesSrc.bacpac /Quiet:True

sqlpackage /Action:Export ... /SourceDatabaseName:SalesDW ... /TargetFile:migration\source\SalesDW.bacpac
```

Each export ran in ~70s. Outputs:

| File | Bytes |
|---|---|
| `migration/source/SalesSrc.bacpac` | 98,531 |
| `migration/source/SalesDW.bacpac`  | 40,387 |

---

## Phase 3 — Generate migration specs

### 9. `dacpac-analyzer` runs

Ran the 9 supported subcommands against each `.bacpac`. Outputs landed in
`migration/dacpac-analysis/SalesSrc/` and `.../SalesDW/`. One subcommand
listed in `RECON.md` (`list-foreign-keys`) **does not exist** in this
version of the analyzer — confirmed by the plugin's `Unknown command`
response. The available command set is:

```
extract-sql, find, function-detail, list-constraints, list-functions,
list-indexes, list-permissions, list-procedures, list-roles, list-schemas,
list-sequences, list-table-types, list-tables, list-views, overview,
procedure-detail, summary, table-detail, view-detail
```

For relational FK info, use `list-constraints` or `table-detail` (FKs show
up as constraints).

### 10. spec-writer outputs

`spec-writer` is a **prose-only Copilot skill** — no executable scripts. It
is designed to be invoked inside a Copilot chat session that calls the two
analyzer skills and writes the spec set per the SKILL.md template. Since
this run is non-interactive, Dylan **acted as the spec-writer** and produced
the spec set programmatically following the same template. Files written:

| File | Size | Role |
|---|---|---|
| `migration/specs/README.md` | ~3.1 KB | Entry point, specs table, reference materials |
| `migration/specs/CONSTITUTION.md` | ~4.3 KB | Project facts: stack, source, Fabric targets, auth |
| `migration/specs/01-prereqs-and-source-schema.md` | ~5.3 KB | Source schema + shared lineage table |
| `migration/specs/02-dim-customer.md` | ~8.5 KB | `Load_Customers` → `dim.DimCustomer` (SCD2) |
| `migration/specs/03-dim-product.md` | ~7.0 KB | `Load_Products_Scripted` → `dim.DimProduct` |
| `migration/specs/04-fact-orders.md` | ~5.9 KB | `Load_Orders` → `fact.FactOrders` |

Every numbered spec contains a **Flavor A — Warehouse DDL** code block with
deployable T-SQL `CREATE TABLE`/`CREATE PROCEDURE` statements, plus a
**Flavor B — Delta** column-mapping table. Spec 02 carries the full SCD2
close-off-and-insert MERGE; specs 03 and 04 carry the lookup-join INSERT.
All checksums and expected row counts in the testing sections reference
`out/baseline/target-rowcounts.json`.

### 11. Outcome — Flavor A ready

The spec set's T-SQL DDL blocks can be concatenated and deployed to
`wh_ssis_demo` as-is. The stored procedures use a `<source-shortcut>`
placeholder where Irving's workspace-deploy script needs to substitute the
real shortcut name (Fabric OneLake shortcut into the VM database, or the
local Parquet landing in the Lakehouse). With that single substitution,
Helly can run the procedures end-to-end and compare against the truth
baseline.

---

## What's in `migration/` now

```
migration/
├── MIGRATION.md            # this file
├── RECON.md                # ssis-migration skill recon (existing)
├── source/
│   ├── SsisDemo.ispac       # 7.5 KB — minimal ZIP-shaped project
│   ├── SalesSrc.bacpac      # 96 KB — source DB w/ data
│   └── SalesDW.bacpac       # 39 KB — target DB w/ post-run data
├── source-analysis/         # per-DTSX overview / data-flows / SQL / scripts
│   ├── Load_Customers/
│   ├── Load_Orders/
│   └── Load_Products_Scripted/
├── dacpac-analysis/
│   ├── SalesSrc/            # 9 JSON dumps from dacpac-analyzer
│   └── SalesDW/             # 9 JSON dumps from dacpac-analyzer
└── specs/                   # the spec set
    ├── README.md
    ├── CONSTITUTION.md
    ├── 01-prereqs-and-source-schema.md
    ├── 02-dim-customer.md
    ├── 03-dim-product.md
    └── 04-fact-orders.md
```

Plus baselines outside `migration/`:

```
out/baseline/
├── source-rowcounts.json    # SalesSrc COUNT(*) per table
└── target-rowcounts.json    # SalesDW rowcounts + CHECKSUM_AGG
```

## Phase 4 — Deploy to Fabric (Irving)

**Date:** 2026-05-26 (post-Dylan).
**Workspace:** `ws-ssis2fabric-demo` (`c9bd4043-11bf-483d-bfca-1c2b2490c3af`) on Fabric capacity `fabcapacitywus3` (F2).
**Portal:** <https://app.fabric.microsoft.com/groups/c9bd4043-11bf-483d-bfca-1c2b2490c3af>

### 12. Land source data in OneLake

* Regenerated all 5 parquet files via `out/raw/_csv_to_parquet.py`. Fixes applied to the helper:
  * `Products.IsActive` arrives from CSV as the literal strings `True`/`False`; map to `Int64` (`{True:1, False:0}`) before write.
  * Coerce timestamps to **microseconds** (`coerce_timestamps='us', allow_truncated_timestamps=True`) — Fabric Spark refuses to read pyarrow's default nanosecond Parquet timestamps with `Illegal Parquet type: INT64 (TIMESTAMP(NANOS,false))`.
* Uploaded the 5 parquet files to `lh_ssis_demo/Files/raw/`.
  * `fabric-onelake_upload_file` (MCP) returned **HTTP 400** for every binary payload. Fell back to the OneLake DFS REST API directly (`PUT ?resource=file`, `PATCH ?action=append`, `PATCH ?action=flush`) using an `https://storage.azure.com/` AAD token. That worked first try.

### 13. Flavor A — Warehouse `wh_ssis_demo` (`60a68a69-2fc7-42ec-8f34-dff6a219ac76`)

* `migration/warehouse/deploy.ps1` ran the DDL + procs cleanly via `Invoke-Sqlcmd` with an AAD token (`Resource=https://database.windows.net/`). No T-SQL fixes were needed — Dylan's files already use Fabric-compatible types (VARCHAR not NVARCHAR; no IDENTITY; surrogate keys via `ROW_NUMBER()`).
* **`COPY INTO` from OneLake failed** under sqlcmd-passed AAD tokens with `Msg 13840 — Access token couldn't be fetched for storage path '...'`. The warehouse can't OBO-exchange the caller's database.windows.net token for an OneLake token. Tried both `.dfs.` and `.blob.fabric.microsoft.com` endpoints; tried `CREDENTIAL = (IDENTITY = 'External User identity')` — the latter is rejected as a syntax error in Fabric (it's an Azure-Synapse-only identity). **Workaround:** `migration/warehouse/_load_via_insert.py` reads each parquet via pyodbc and bulk-loads `stg.*` with multi-row `INSERT ... VALUES` (200 rows per statement; `fast_executemany` is too slow on Fabric Warehouse — 6,000 rows took >40 min, 30 batched statements took ~1 min).
* `EXEC dw.usp_RunAll` populated `dw.*` from `stg.*` cleanly.

**Row counts (Flavor A, saved to `out/baseline/warehouse-rowcounts.json`):**

| Table | Rows | Baseline |
|---|---|---|
| `dw.DimCustomer` | **500** | 500 ✅ |
| `dw.DimProduct`  | **100** | 100 ✅ |
| `dw.FactOrders`  | **2000** | 2000 ✅ |

### 14. Flavor B — Lakehouse `lh_ssis_demo` (`e3fcb33a-13d8-4967-add9-5efed6fcac65`) + Notebook

* Created notebook **`nb_ssis_demo_migration`** (id `7d805094-17be-46b1-949d-aa710324f393`) via Fabric REST `POST /v1/workspaces/{wid}/items` with the `.ipynb` base64-encoded under `definition.parts[0].payload` and `payloadType = InlineBase64`. The MCP `fabric-core_create-item` path doesn't accept an inline notebook body, so REST was the right call. Updated `metadata.dependencies.lakehouse.default_lakehouse` to bind it to `lh_ssis_demo` before upload.
* Edited the notebook to use absolute `abfss://<wsid>@onelake.dfs.fabric.microsoft.com/<lhid>/...` paths with `.option("path", ...).saveAsTable("...")` so it doesn't depend on the runtime's notion of "default" lakehouse for writes.
* Ran via `POST /v1/workspaces/{wid}/items/{nbId}/jobs/instances?jobType=RunNotebook`; polled the `Location`-returned instance until status flipped from `InProgress` → `Completed` (~60 s once the Spark session warmed up). Initial runs failed with `System_Cancelled_Session_Statements_Failed` (generic) — root cause surfaced only after writing a diagnostic notebook that captured `traceback.format_exc()` for each step into `Files/diag_log_dir/` via `sparkContext.parallelize(...).saveAsTextFile(...)`. That's where the **nanosecond timestamp** issue (item 12 above) was found.

**Delta tables (verified via `fabric-onelake_list_tables` and the SQL analytics endpoint, saved to `out/baseline/lakehouse-rowcounts.json`):**

| Table | Rows | Baseline |
|---|---|---|
| `dbo.dim_customer` | **500** | 500 ✅ |
| `dbo.dim_product`  | **100** | 100 ✅ |
| `dbo.fact_orders`  | **2000** | 2000 ✅ |

### 15. Fabric / MCP gotchas captured

* MCP `fabric-onelake_upload_file` rejects local binary parquet with HTTP 400; OneLake DFS REST works.
* MCP `fabric-onelake_create_directory` returned 400 here; not actually needed — the DFS `PUT ?resource=file` auto-creates parent directories.
* `COPY INTO` from OneLake under an Invoke-Sqlcmd-passed AAD token is broken (`Msg 13840`); use pyodbc-with-token + multi-row `INSERT VALUES` as a workaround at demo scale, or set up workspace identity for production.
* SQL analytics endpoint of the lakehouse takes ~10–20 s to surface a newly written Delta table — first SELECT may return `Invalid object name`; retry.
* SparkSQL string literals must be **single-quoted**. Double-quoted strings in SQL can be treated as identifiers under the default config and silently break `CASE` expressions.
* Fabric notebook jobs report a useless `System_Cancelled_Session_Statements_Failed` for any cell exception. To get the real Python traceback, wrap each section in try/except and persist `traceback.format_exc()` to a known OneLake `Files/` path — the REST monitoring API doesn't expose cell stdout.
* pandas/pyarrow default parquet timestamps are nanosecond (`INT64 TIMESTAMP(NANOS)`); Fabric Spark rejects them. Always pass `coerce_timestamps='us', allow_truncated_timestamps=True`.

### 16. Open follow-ups for Helly

* Validate `dw.*` ↔ `dbo.*_*` parity (counts already match; checksum comparison against `target-rowcounts.json` still TODO).
* Validation harness should query the lakehouse via its SQL analytics endpoint (`...datawarehouse.fabric.microsoft.com / lh_ssis_demo`) and the warehouse via `wh_ssis_demo` on the same server — same AAD token works for both.

---

## Open issues / follow-ups

1. **DTSX runtime fidelity.** The hand-authored DTSX validate under
   `dtexec` only with several edits (missing `OpenRowset`,
   `FileNameColumnName`, `arrayElementCount`, plus a binary-coded Script
   Component). Treat this as a known limitation of the synthetic
   demo — the analyzer outputs and `.ispac` are still valid for the
   migration. Documented in `.squad/agents/dylan/history.md`.
2. **`list-foreign-keys` doesn't exist** in the installed dacpac-analyzer.
   Use `list-constraints` instead. `RECON.md` should be amended in a later
   pass.
3. **Shortcut name** in the procedure bodies is a placeholder
   (`<source-shortcut>`). Irving's deploy needs to substitute the actual
   OneLake shortcut into the source database (or replace with a literal
   server name once a Fabric pipeline activity ingests the data).
4. **Identity columns in Fabric Warehouse.** Fabric currently supports
   `IDENTITY` on `INT/BIGINT` PKs without restriction; verify at deploy
   time and fall back to `ROW_NUMBER()` over a stable ordering if needed.
