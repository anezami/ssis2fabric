# Squad Team

> ssis2fabric — Demo migrating SSIS packages to Microsoft Fabric (Warehouse + Lakehouse/SparkSQL)

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Mark   | 🏗️ Lead             | .squad/agents/mark/charter.md   | active |
| Cobel  | ⚙️ Azure Infra      | .squad/agents/cobel/charter.md  | active |
| Irving | 🔧 Fabric Engineer  | .squad/agents/irving/charter.md | active |
| Dylan  | 📊 Migration Eng    | .squad/agents/dylan/charter.md  | active |
| Helly  | 🧪 Tester           | .squad/agents/helly/charter.md  | active |
| Scribe | 📋 Session Logger   | .squad/agents/scribe/charter.md | active |
| Ralph  | 🔄 Work Monitor     | .squad/agents/ralph/charter.md  | active |

## Project Context

- **Project:** ssis2fabric
- **User:** arnezami
- **Created:** 2026-05-26
- **Goal:** End-to-end demo: provision SSIS on Azure VM → export package → migrate to Fabric Warehouse AND Fabric Lakehouse/SparkSQL.
- **Migration tool:** https://github.com/markgar/ssis-migration (skill to be cloned locally and used by Dylan).
- **Azure subscription:** `fb5cf409-7bc6-4446-aea6-d49b899eaa8b`
- **Fabric capacity:** `/subscriptions/fb5cf409-7bc6-4446-aea6-d49b899eaa8b/resourceGroups/rgfabric/providers/Microsoft.Fabric/capacities/fabcapacitywus3`
- **New resource group:** `rg-ssis2fabric-demo` (to be created in West US 3 to co-locate with Fabric capacity).
