# SSIS Demo — Sample Source Artifacts

Hand-authored SSIS source set for the **ssis2fabric** migration demo. All artifacts
in this folder are checked in so the demo is fully reproducible without SSDT/Visual Studio.

## Layout

```
ssis/
├── SsisDemo.dtproj          # SSIS project file (references the 3 packages)
├── SsisDemo.params          # Project-level parameters (connection strings, CSV path)
├── sql/
│   ├── 00-create-databases.sql        # CREATE DATABASE SalesSrc, SalesDW (idempotent)
│   ├── 01-source-schema-and-seed.sql  # SalesSrc tables + deterministic seed data
│   └── 02-target-schema.sql           # SalesDW dim.* + fact.* DDL
├── csv/
│   └── products_incoming.csv          # 100-row CSV consumed by Load_Products_Scripted
└── packages/
    ├── Load_Customers.dtsx            # Customers + CountryLookup -> dim.DimCustomer
    ├── Load_Orders.dtsx               # Orders -> Lookup CustomerKey -> fact.FactOrders
    └── Load_Products_Scripted.dtsx    # CSV -> Script Component -> dim.DimProduct
```

## What the three packages demonstrate

| Package | Source | Transforms | Destination | Notable for migration |
|---|---|---|---|---|
| `Load_Customers` | OLE DB Source (T-SQL JOIN of `dbo.Customers` and `dbo.CountryLookup`) | Truncate target via Execute SQL Task; precedence constraint | OLE DB Destination → `dim.DimCustomer` (fast-load) | Baseline straight ETL pattern. |
| `Load_Orders` | OLE DB Source (`dbo.Orders`) | **Lookup** transform against `dim.DimCustomer` (IsCurrent=1) to resolve `CustomerKey` | OLE DB Destination → `fact.FactOrders` | Lookup transform — common migration risk surface. |
| `Load_Products_Scripted` | Flat File Source (`products_incoming.csv`) | **Script Component (C#)** — uppercases `Sku`, derives `MarginCategory` from `Price` thresholds | OLE DB Destination → `dim.DimProduct` | Script Task / Script Component — must be hand-translated. |

## Provisioning on the VM

The packages assume:
- SQL Server reachable as `localhost`, Windows-integrated auth.
- Databases `SalesSrc` and `SalesDW` exist (created by `00-create-databases.sql`).
- CSV file is at `C:\ssisdemo\data\products_incoming.csv` (the `ProductsCsv` connection
  string in the package uses a relative path `..\csv\products_incoming.csv` which works
  when the package runs from `C:\ssisdemo\packages\`; the project parameter
  `ProductsCsv_Path` carries the absolute VM path).

### Step 1 — Load schema and seed on the VM

Run on the VM (or remotely) against the default instance:

```powershell
sqlcmd -S localhost -E -i ssis\sql\00-create-databases.sql
sqlcmd -S localhost -E -i ssis\sql\01-source-schema-and-seed.sql
sqlcmd -S localhost -E -i ssis\sql\02-target-schema.sql
```

Expected counts after seed:

| Table | Rows |
|---|---|
| `SalesSrc.dbo.CountryLookup` | 20 |
| `SalesSrc.dbo.Products` | 100 |
| `SalesSrc.dbo.Customers` | 500 |
| `SalesSrc.dbo.Orders` | 2000 |
| `SalesSrc.dbo.OrderItems` | 6000 |

### Step 2 — Copy SSIS artifacts to the VM

From the host (Cobel's WinRM session works fine):

```powershell
$s = New-PSSession -ComputerName <vm-public-ip> -Credential (Get-Credential)
Invoke-Command -Session $s -ScriptBlock {
    New-Item -ItemType Directory -Force -Path C:\ssisdemo\packages,C:\ssisdemo\data | Out-Null
}
Copy-Item -ToSession $s ssis\packages\*.dtsx C:\ssisdemo\packages\
Copy-Item -ToSession $s ssis\csv\products_incoming.csv C:\ssisdemo\data\
```

### Step 3 — Execute the packages

On the VM, in execution order (Customers must complete first so the lookup in
`Load_Orders` finds keys):

```cmd
cd C:\ssisdemo\packages

"C:\Program Files\Microsoft SQL Server\150\DTS\Binn\dtexec.exe" /F Load_Customers.dtsx /CONSOLELOG NCOSGXMT
"C:\Program Files\Microsoft SQL Server\150\DTS\Binn\dtexec.exe" /F Load_Products_Scripted.dtsx /CONSOLELOG NCOSGXMT
"C:\Program Files\Microsoft SQL Server\150\DTS\Binn\dtexec.exe" /F Load_Orders.dtsx /CONSOLELOG NCOSGXMT
```

(`dtexec.exe` major version maps to SSIS / SQL Server release — `150` is SQL Server 2019.
On the `sqldev-gen2` image used by Cobel it's `160` for SQL 2022. Adjust as needed.)

### Step 4 — Sanity-check the load

```sql
USE SalesDW;
SELECT COUNT(*) FROM dim.DimCustomer;   -- 500
SELECT COUNT(*) FROM dim.DimProduct;    -- 100
SELECT COUNT(*) FROM fact.FactOrders;   -- 2000
SELECT TOP 5 * FROM fact.FactOrders ORDER BY OrderID;
```

## Validating the DTSX with the ssis-analyzer

The packages are parseable by `tools/ssis-migration/plugins/ssis-analyzer`:

```powershell
$env:PYTHONIOENCODING = "utf-8"   # required on Windows for the U+2192 arrow in path output
python tools\ssis-migration\plugins\ssis-analyzer\scripts\analyze.py ssis\packages\Load_Customers.dtsx overview
python tools\ssis-migration\plugins\ssis-analyzer\scripts\analyze.py ssis\packages\Load_Orders.dtsx data-flow-detail DFT_LoadOrders --json
python tools\ssis-migration\plugins\ssis-analyzer\scripts\analyze.py ssis\packages\Load_Products_Scripted.dtsx extract-scripts
```

Captured JSON for all three packages is checked in under `migration/source-analysis/`
and is the input to the next step (`spec-writer`).
