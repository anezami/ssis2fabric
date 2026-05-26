# Routing — ssis2fabric

| Signal / Topic | Owner |
|----------------|-------|
| Architecture, RG/workspace topology, sample package choice, reviewer gate | Mark |
| Azure resource group, VM, SQL Server, SSIS install, networking, secrets | Cobel |
| Fabric workspace, Warehouse, Lakehouse, capacity binding, SQL endpoints | Irving |
| ssis-migration skill use, DTSX export, T-SQL/notebook conversion, deploy migrated artifacts | Dylan |
| Validation of both migration flavors, reviewer verdicts | Helly |
| Session logging, decisions merge, history hygiene | Scribe |
| Work-queue monitoring, idle-watch | Ralph |

## Ordering
1. Mark drafts plan → user approves → Cobel + Irving provision in parallel.
2. Dylan waits for both (needs VM access and workspace IDs).
3. Helly validates after Dylan deploys.
4. Mark reviews; rejection triggers lockout per coordinator rules.
