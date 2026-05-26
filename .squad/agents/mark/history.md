# Mark's history — ssis2fabric

Project: SSIS→Fabric migration demo. Two target flavors: Fabric Warehouse, Fabric Lakehouse+SparkSQL.
User: arnezami. Stack: Azure VM (Windows + SQL Server 2022 + SSIS), Microsoft Fabric.
Tool: https://github.com/markgar/ssis-migration.
Capacity: fabcapacitywus3 (West US 3). Subscription: fb5cf409-7bc6-4446-aea6-d49b899eaa8b.

## Learnings

### 2026-05-26 — Initial architecture plan drafted
- Wrote `.squad/decisions/inbox/mark-architecture-plan.md` covering sample SSIS strategy, Azure infra (for Cobel), Fabric topology (for Irving), migration flow (for Dylan), validation (for Helly), and risks.
- Decided **hand-authored DTSX XML** over SSDT GUI for reproducibility — three packages: straight ETL (`Load_Customers`), Lookup (`Load_Orders` from CSV), Script Task (`Load_Products_Scripted`). Synthetic sales dataset, seeded by T-SQL.
- VM: `Standard_D4s_v5`, image `MicrosoftSQLServer:sql2022-ws2022:sqldev-gen2:latest`. NSG locked to caller IP for RDP/SQL/WinRM. Auto-shutdown 19:00.
- Fabric: workspace `ws-ssis2fabric-demo` on `fabcapacitywus3`, one Warehouse `wh_ssis_demo`, one Lakehouse `lh_ssis_demo`, one notebook scaffold.
- Key gap: skill is **PySpark-only**. Warehouse flavor is hand-adapted from analyzer + DACPAC output — Dylan rewrites transforms as T-SQL stored procs. Source data lands once as Parquet in Lakehouse `Files/raw/`, Warehouse `COPY INTO`s from same OneLake path.
- Validation: row counts + checksums; T-SQL `BINARY_CHECKSUM`/`HASHBYTES` for Warehouse, Spark `hash()` for Lakehouse. Helly compares per-key, not raw checksum equality, across flavors due to hash function differences.
- Open questions surfaced to user: VM SKU confirm, NSG IP allow-list, workspace admin rights, auto-shutdown time, OK-to-commit synthetic data.
