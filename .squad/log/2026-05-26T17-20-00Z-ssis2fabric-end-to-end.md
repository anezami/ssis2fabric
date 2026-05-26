# Session Log — SSIS→Fabric End-to-End Demo

**Date:** 2026-05-26T17:20:00Z (UTC)  
**Project:** ssis2fabric  
**Participants:** Mark (architect), Cobel (infra), Irving (Fabric), Dylan (migration), Helly (validation), Scribe (documentation)

---

## Overview

End-to-end execution of a multi-agent SSIS→Microsoft Fabric migration demo showcasing two deployment flavors: (1) Fabric Warehouse with T-SQL ETL, (2) Fabric Lakehouse with PySpark notebooks. Syntheticdata sourced from handwritten SSIS packages on SQL Server 2022; target row counts verified across both flavors.

---

## Spawn Manifest

1. **Mark** (sync-collected) — Architecture plan for SSIS→Fabric demo. Output: Mark architecture plan decision box.
2. **Dylan** (round 1) — Recon of ssis-migration plugins (all three installed). Output: RECON.md + decision inbox file.
3. **Cobel** (gpt-5.5) — Drafted infra scripts → **DEPLOYED VM** (vm-ssis-demo @ 20.163.102.57) with SQL 2022 + SSIS + SSISDB.
4. **Irving** (gpt-5.5) — Drafted Fabric scripts → **DEPLOYED workspace** ws-ssis2fabric-demo (id: c9bd4043-...), warehouse wh_ssis_demo, lakehouse lh_ssis_demo.
5. **Dylan** (round 2) — Authored 3 hand-DTSX packages + seed SQL + ispac/bacpac exports + spec set. dtexec runtime failed; T-SQL workaround populated SalesDW.
6. **Dylan** (round 3) — Produced deployable T-SQL for Flavor A (Warehouse) + PySpark notebook for Flavor B + parquet export script.
7. **Irving** (round 2) — Deployed Flavor A (Warehouse) and Flavor B (Lakehouse+notebook) via Fabric MCP + REST. Verified row counts: 500/100/2000 match source.
8. **Helly** (validation) — Validating both flavors in parallel.
9. **Scribe** (this run) — Consolidate decisions, log orchestration, commit records.

---

## Architecture Summary

### Infrastructure (Cobel)

- **Subscription:** `fb5cf409-7bc6-4446-aea6-d49b899eaa8b`
- **Resource Group:** `rg-ssis2fabric-demo` (westus3)
- **VM:** `vm-ssis-demo` (Standard_D2s_v5, 4 vCPU / 16 GB)
- **OS:** SQL 2022 Developer (free, includes Integration Services)
- **Auth:** Windows AD + SQL mixed-mode
- **NSG:** RDP + SQL restricted to caller's public IPv4
- **Status:** DEPLOYED ✓

### Fabric Topology (Irving)

- **Workspace:** `ws-ssis2fabric-demo` (bound to `fabcapacitywus3`)
- **Flavor A — Warehouse:** `wh_ssis_demo` (schemas: stg, dw)
- **Flavor B — Lakehouse:** `lh_ssis_demo` (Files/raw/, Tables/)
- **Notebook:** `nb_ssis_demo_lakehouse` (PySpark, attached to lh_ssis_demo)
- **Status:** DEPLOYED ✓

### Migration Strategy (Dylan)

**One spec set, two flavors:**
1. Run `spec-writer` once per SSIS package → produce shared migration specs (runtime-agnostic).
2. **Lakehouse pass** — Use spec's PySpark code blocks → assemble notebooks + Delta tables.
3. **Warehouse pass** — Extract spec's T-SQL table DDL + hand-translate transforms into stored procs (MERGE logic, lookups as joins, Script Task as CASE expressions).

**Hand-authored SSIS packages (3):**
- `Load_Customers.dtsx` — Baseline ETL (OLE DB Source → Data Conversion → Destination)
- `Load_Orders.dtsx` — Flat File + Lookup (CSV → data type conversion → lookup joins → fact load)
- `Load_Products_Scripted.dtsx` — Script Task (C# price_band derivation → dimension load)

**Sample data (synthetic):**
- DimCustomer: 500 rows
- DimProduct: 100 rows
- FactOrders: 2000 rows (sourced from 50k-row CSV)

### Deployments (Irving)

- **Flavor A (Warehouse):** T-SQL DDL + stored procs (`stg.sp_load_customers`, `stg.sp_load_products`, `stg.sp_load_orders`) + COPY INTO from OneLake Parquet staging.
- **Flavor B (Lakehouse):** PySpark notebooks reading Parquet from Files/raw/, writing Delta tables under Tables/, registering SparkSQL views.
- **Row count verification:** Both flavors match source counts (500/100/2000) ✓

### Validation (Helly — in progress)

- Source-of-truth queries against SalesDW on VM
- Flavor A (Warehouse) queries via SQL endpoint (AAD auth)
- Flavor B (Lakehouse) queries via SparkSQL in notebook
- Spot-check sampled rows by primary key
- Document per-package per-flavor pass/fail in `out/validation/report.md`

---

## Key Decisions Captured

1. **Azure subscription, region & Fabric capacity:** Subscription `fb5cf409-...` + Fabric capacity `fabcapacitywus3` + RG `rg-ssis2fabric-demo` in westus3.
2. **Team cast:** Names drawn from Severance universe (Mark, Cobel, Irving, Dylan, Helly).
3. **Auth strategy:** All Azure + Fabric calls via `az` CLI login. No SPN. SQL credentials local-only.
4. **Infrastructure design:** Standard_D2s_v5 (cost-optimized), caller's IP-restricted NSG, auto-shutdown 19:00 local, seed data + DTSX XML committed to repo.
5. **Fabric provisioning:** REST APIs + capacity discovery by display name + polling for async creation (1-3 min typical).
6. **SSIS migration:** One spec set → two build passes (Lakehouse native, Warehouse hand-adapted). Acknowledged gap: spec-writer is PySpark-only; Dylan adapts for T-SQL manually.
7. **Deploy defaults:** VM SKU D2s_v5 (~$70/mo), caller IP auto-detect, auto-shutdown 19:00, synthetic data commit OK, Fabric API surfaces permission errors.

---

## Known Risks & Gaps

1. **Skill is PySpark-only** — Warehouse flavor requires manual hand-translation; not automated.
2. **Fabric REST async latency** — 1–3 min typical; scripts implement polling with 10s interval, 5 min timeout.
3. **SSIS install on sqldev image** — May require explicit `setup.exe /Features=IS` run; Cobel confirmed availability.
4. **Fabric Warehouse T-SQL gaps** — No IDENTITY autoincrement, no CHECK constraints historically; surrogate keys generated in staging.
5. **Script Task migration risk** — C# logic in `Load_Products_Scripted.dtsx` requires manual re-expression in both PySpark (UDF) and T-SQL (CASE).
6. **AAD auth to Warehouse from VM** — Connection string requires `Authentication=Active Directory Interactive` or device code.
7. **WinRM over public IP** — Acceptable for demo with NSG restrictions; not recommended for production.
8. **OneLake shortcut cross-item access** — Assumes Warehouse can COPY INTO from Lakehouse Files in same workspace; confirmed operational.

---

## Artifacts Generated

- **Architecture:** `.squad/decisions.md` (consolidated decisions)
- **Reconnaissance:** `migration/RECON.md` (skill analysis)
- **SSIS Packages:** `ssis/packages/*.dtsx` (3 hand-authored)
- **Seed Data:** `ssis/seed/seed.sql`, `ssis/seed/orders.csv.ps1`
- **Infrastructure:** `infra/` (PowerShell scripts)
- **Fabric:** `fabric/deploy.ps1` (provisioning scripts)
- **Migration Output:** `out/` (analysis, specs, notebooks, warehouse DDL/procs, parquet exports)
- **Orchestration:** `.squad/orchestration-log/*` (per-agent logs)
- **Orchestration:** `.squad/decisions.md` (merged inbox)

---

## Status

**Complete to date:**
✓ Architecture planned (Mark)
✓ Skill recon complete (Dylan)
✓ Infrastructure deployed (Cobel) — VM operational
✓ Fabric environment deployed (Irving) — workspace + warehouse + lakehouse live
✓ SSIS packages hand-authored (Dylan)
✓ Migration specs + code generated (Dylan)
✓ Both flavors deployed (Irving) — row counts verified
✓ Decisions consolidated (Scribe)
✓ Orchestration logs written (Scribe)

**In progress:**
— Validation (Helly) — parallel to Scribe

**Next:**
- Helly completes validation report
- Scribe archives decisions if needed (future session)

---

## Execution Notes

- No dtexec runtime on VM; Dylan used T-SQL workaround to populate SalesDW.
- All three Copilot plugins (ssis-analyzer, dacpac-analyzer, spec-writer) installed cleanly; no Python pip deps.
- Spec-writer output was PySpark-targeted but T-SQL extraction + DDL/transform logic were reusable across flavors (Key finding: runtime-agnostic specs).
- OneLake shortcut cross-item access (Warehouse COPY INTO from Lakehouse Files) confirmed working.
- Warehouse + Lakehouse row counts match source (500/100/2000); verified via direct queries.

---

## Session Log Metadata

- **Start:** 2026-05-26T17:20:00Z (UTC, approximately)
- **Participants:** 6 agents + 1 Scribe
- **Scope:** Full multi-turn SSIS→Fabric demo end-to-end
- **Outcome:** Architecture validated, infrastructure live, data migrated, validation in progress

---

*End of session log. For detailed per-agent work, see .squad/orchestration-log/*
