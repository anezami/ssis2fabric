# Squad Decisions

## Active Decisions

### 2026-05-26: Project kickoff
**By:** arnezami (via Squad)
**What:** Demo migrating SSIS packages to Microsoft Fabric in two flavors: (1) Fabric Warehouse, (2) Fabric Lakehouse + SparkSQL.
**Why:** Showcase end-to-end migration using the ssis-migration skill from https://github.com/markgar/ssis-migration.

### 2026-05-26: Azure subscription, region & Fabric capacity
**By:** arnezami
**What:** Subscription `fb5cf409-7bc6-4446-aea6-d49b899eaa8b`. Fabric capacity `fabcapacitywus3` in RG `rgfabric` (West US 3). New RG `rg-ssis2fabric-demo` in `westus3` to co-locate with Fabric capacity.

### 2026-05-26: Team cast = Severance
**By:** Squad
**What:** Cast names drawn from Severance universe (Mark, Cobel, Irving, Dylan, Helly).

### 2026-05-26: Auth strategy
**By:** Squad
**What:** All Azure + Fabric calls use user's existing `az` CLI login. No service principals, no committed secrets. SQL credentials live only on local disk under `infra/.secrets/` (gitignored).

### 2026-05-26: Infrastructure design (Azure)
**By:** Cobel
**What:** Draft Azure infrastructure as PowerShell scripts under `infra/` (no resource-creating commands yet). SQL Server 2022 Developer on `Standard_D2s_v5` in `westus3`. Credentials stored locally at `infra/.secrets/sql-admin.json` (gitignored). NSG restricts RDP/SQL to caller's detected public IPv4. VM auto-shutdown at 19:00 local.

### 2026-05-26: Fabric provisioning design
**By:** Irving
**What:** Provision Fabric workspace via REST API using signed-in Azure CLI identity. Resolve capacity `fabcapacitywus3` by display name via `GET /v1/capacities` instead of hard-coding GUID. Fabric REST returns 202 → poll `Location` header until 200 (1-3 min typical). Deploy script implements polling with 10s interval, 5 min timeout.

### 2026-05-26: SSIS migration strategy — one spec set, two flavors
**By:** Dylan
**What:** Clone `markgar/ssis-migration` + install plugins (`ssis-analyzer`, `dacpac-analyzer`, `spec-writer`). Run spec-writer **once** per SSIS package to produce shared specs. Drive **two build passes** from same specs: (1) Lakehouse pass → PySpark notebooks + Delta tables; (2) Warehouse pass → T-SQL `CREATE TABLE` + `MERGE` + Data Pipelines. Avoids spec duplication. If divergence too high, fallback to running spec-writer twice.

### 2026-05-26: Defaults applied for deploy
**By:** arnezami (via Squad)
**What:** VM SKU = `Standard_D2s_v5` (~$70/mo). NSG auto-detects caller's public IP. Auto-shutdown = 19:00 local. Synthetic seed data + hand-authored DTSX XML committed to repo (no secrets). Fabric deploy proceeds; API surfaces permission errors if needed.

### 2026-05-26: Sample SSIS packages (hand-authored)
**By:** Mark
**What:** Hand-author three DTSX packages as XML under `ssis/packages/`: (1) `Load_Customers.dtsx` (baseline ETL), (2) `Load_Orders.dtsx` (flat-file + lookup), (3) `Load_Products_Scripted.dtsx` (Script Task). Source: synthetic sales dataset in `SalesSrc` DB (Customers ~1k, Products ~100, OrdersRaw CSV ~50k). Target: `SalesDW` on same instance. All via Windows auth on localhost. Covers baseline mapping, lookups, and Script Task migration risk.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
