# ssis-migration Skill — Recon

**Owner:** Dylan
**Date:** 2026-05-26
**Skill source:** https://github.com/markgar/ssis-migration (cloned to `tools/ssis-migration/`)

## TL;DR

The `ssis-migration` repo ships **three Copilot plugins** that, together, take SSIS
artifacts in and produce a directory of Markdown migration specs out. They do
**not** produce runnable code. They are *analyzer + spec writer*, not *code generator*.

All three plugins installed cleanly via Copilot CLI v1.0.55 on Windows. Pure-stdlib
Python 3.10+ — no `pip install` required.

## Plugins

### 1. `ssis-analyzer` — `.dtsx` package inspector

- **Input:** path to a `.dtsx` (SSIS package XML).
- **Output:** Markdown (default) or JSON (`--json`) for one of ~20 subcommands.
- **What it does:** parses the DTSX XML and exposes control flow, data flows,
  precedence constraints, Execute SQL bodies, Script Task code (C#/VB),
  connection managers, variables, parameters, column lineage through data flows,
  and topological execution order with parallel-branch detection.
- **Sample command (raw script form):**
  ```bash
  python tools/ssis-migration/plugins/ssis-analyzer/scripts/analyze.py \
      sample.dtsx overview
  python .../analyze.py sample.dtsx extract-sql --json
  ```
- **Sample command (Copilot CLI skill form):** the skill is invoked by name
  inside a Copilot chat — `@ssis-analyzer overview package.dtsx`.

### 2. `dacpac-analyzer` — `.dacpac` / `.bacpac` schema inspector

- **Input:** path to a `.dacpac` or `.bacpac` (zip of SQL model XML).
- **Output:** Markdown / JSON for ~18 subcommands.
- **What it does:** extracts schemas, tables (columns/types/nullability/constraints/
  indexes), views (+ body), stored procedures (+ body + params), functions,
  PK/FK/unique/check/default constraints, indexes, sequences, table types,
  roles, permissions. `extract-sql` dumps every body script.
- **Sample command:**
  ```bash
  python tools/ssis-migration/plugins/dacpac-analyzer/scripts/analyze.py \
      MyDb.dacpac list-tables
  python .../analyze.py MyDb.dacpac procedure-detail "dbo.usp_LoadCustomers"
  ```

### 3. `spec-writer` — orchestrator that writes migration spec sets

- **Input:** workspace containing `.ispac`/`.dtsx` + `.bacpac`/`.dacpac`, plus
  user-supplied project facts (package name, target dir, Fabric workspace,
  lakehouse, SJD, env, auth mechanism — see SKILL.md "Step 0" table).
- **Output:** a directory of Markdown files:
  - `README.md` — index of the spec set
  - `CONSTITUTION.md` — stack, auth, naming conventions, Fabric targets
  - `01-<name>.md` … `NN-<name>.md` — one numbered spec per pipeline stage
    (prereqs first, then dimensions, then facts)
- **What each numbered spec contains** (from SKILL.md):
  1. SSIS lineage (task-by-task, in execution order)
  2. **Source Tables** with SQL Server column types, nullability, notes
  3. **Source Extraction Logic** including the exact extraction T-SQL / proc body,
     change detection, NULL handling, known bugs to preserve
  4. **Staging Schema** (SQL Server types)
  5. **Destination Table** with both SQL Server column names *and* the Delta
     column-name mapping
  6. Column mapping (source → destination), join conditions, NULL handling
  7. **SCD Type 2 merge logic** with exact T-SQL for "close off existing rows"
     and "insert new rows", plus a translation to Delta `MERGE`
  8. Watermark / incremental strategy
  9. PySpark source-query options (call proc via JDBC, or inline)
  10. Testing strategy
- **Constraint:** never writes code. Only writes specs.
- **Sample invocation (Copilot chat):**
  ```
  Write migration specs from artifacts/MyPackage.ispac and
  artifacts/MyDb.bacpac into specs/daily-etl/
  ```

## Install status

All three plugins installed via Copilot CLI v1.0.55:

```
Marketplace "ssis-migration" added successfully.
Plugin "ssis-analyzer" installed successfully. Installed 1 skill.
Plugin "dacpac-analyzer" installed successfully. Installed 1 skill.
Plugin "spec-writer" installed successfully. Installed 1 skill.
```

We also have the source under `tools/ssis-migration/` so we can call the raw
Python scripts directly if/when we need to do bulk extraction in CI without
going through a chat session.

## Dependencies

- **Python 3.10+** — verified `python --version` → `3.11.9` ✅
- **No pip packages required** — both analyzer plugins explicitly state "Pure
  Python stdlib"; no `requirements.txt` anywhere in the repo. (No `lxml`,
  no `defusedxml`, no `pandas`.)
- **Copilot CLI** for the spec-writer skill workflow (already present, v1.0.55).
- **`sqlpackage`** (NOT a skill dep, but a *workflow* dep) — we'll need it on
  the VM or locally to produce a `.dacpac`/`.bacpac` from the live SQL Server
  that backs the SSIS packages. Cobel's responsibility.

## Gap: Warehouse (T-SQL) flavor vs. Lakehouse (PySpark) flavor

The skill is heavily PySpark/Lakehouse-flavored — the CONSTITUTION template
literally lists "PySpark version, Delta Lake version, Fabric runtime version"
and "target (Fabric Lakehouse Delta tables)". The build-agent it pairs with
(`sjd-builder`) emits PySpark.

**However — the numbered specs themselves are runtime-agnostic for the
important bits:**

| Spec section | Already T-SQL-shaped? | Notes for Warehouse flavor |
|---|---|---|
| Source Tables (DDL) | ✅ SQL Server types verbatim | Reuse directly for `CREATE TABLE` in Warehouse. |
| Source extraction proc body | ✅ exact T-SQL | Already T-SQL. May need light edits for Fabric Warehouse T-SQL surface (e.g., no `FOR SYSTEM_TIME`, limited temporal). |
| Destination DDL | ✅ SQL Server types + Delta name mapping | Strip the Delta-name column, keep SQL Server types — that's the Warehouse DDL. |
| SCD2 merge logic | ✅ "exact SQL that closes current rows" + "exact SQL that inserts staging rows" | Already T-SQL `UPDATE` + `INSERT`, or a `MERGE`. Drop-in for Warehouse. |
| Column mapping | ✅ expressions, joins, NULL handling | Reusable. |
| PySpark source query (Option A/B) | ❌ PySpark-specific | Skip for Warehouse — replace with a Fabric Data Pipeline copy activity or Warehouse stored proc. |
| Watermark strategy | ✅ value + storage location | Reusable; storage moves from a lakehouse Delta table to a Warehouse table. |
| Testing | ⚠ PySpark-leaning | Translate to T-SQL unit tests (tSQLt or simple compare queries) for Warehouse. |

**Conclusion: the spec-writer output is ~80% reusable for both flavors.** The
heavy lifting (schema, transformation logic, SCD2 SQL) is already in T-SQL.
The only Lakehouse-specific section is the PySpark source query and the
testing harness suggestions.

## Plan for producing BOTH flavors

We have two viable options:

### Option A (preferred): one spec set, two build passes

1. **Cobel** exports `.ispac` + `.bacpac` from the Azure VM (his task).
2. **Dylan** runs `spec-writer` once → produces `specs/<package>/` with the
   full T-SQL-rich spec set. Use a generic destination phrasing in the
   CONSTITUTION ("Fabric — flavor-specific, see build pass") instead of
   locking it to Lakehouse.
3. **Dylan** drives two build passes off the same specs:
   - **Lakehouse pass** → notebooks + Delta tables, deployed by Irving's
     workspace deploy script.
   - **Warehouse pass** → T-SQL `CREATE TABLE`/`MERGE` scripts + Fabric Data
     Pipeline JSON for extraction, also deployed by Irving.

Pros: single source of truth, less drift, clearly demos that the migration is
"target-agnostic" up to the last mile.

### Option B: run spec-writer twice

Run once with CONSTITUTION targeted at Lakehouse, run again with CONSTITUTION
targeted at Warehouse (different `specs/<package>-lakehouse/` and
`specs/<package>-warehouse/` directories). The analyzer output is identical
between runs, so this is mostly a CONSTITUTION/destination diff. More
expensive, more duplication, but cleaner per-flavor handoff.

**Recommendation:** start with **Option A**. Drop to Option B only if the
build passes end up diverging more than expected.

## What we need from teammates

| From | What | Why |
|---|---|---|
| **Cobel** (VM owner) | `.ispac` file(s) — exported SSIS project(s) from `SSISDB`/file system on the Azure VM | Spec-writer needs `.ispac`/`.dtsx` as primary input |
| **Cobel** | `.bacpac` of the source OLTP database(s) the SSIS packages read from, *and* the destination DW database(s) they write to, produced via `sqlpackage /Action:Export` on the VM | Spec-writer needs `.bacpac`/`.dacpac` for table & proc schemas |
| **Cobel** | Read-only summary of connection strings the packages use (server names, DBs) — for the CONSTITUTION's "Source Database" section | spec-writer Step 0 user-supplied facts |
| **Irving** (workspace owner) | Fabric workspace name, lakehouse name, warehouse name, SJD name, environment name, target Fabric runtime version | Populates CONSTITUTION; required by spec-writer Step 0 |
| **Irving** | Confirmation that the workspace deploy story can publish both (a) notebooks + lakehouse tables and (b) Warehouse T-SQL + Data Pipelines | Drives whether Option A is feasible |

## Blockers

- None hard-blocking right now. The skill is installed and ready.
- **Waiting on Cobel** to produce the actual `.ispac` + `.bacpac` artifacts —
  without them spec-writer has nothing to chew on.
- **Waiting on Irving** to confirm Fabric workspace identifiers so the
  CONSTITUTION isn't full of `TBD`s.

## File map (what got cloned)

```
tools/ssis-migration/
├── README.md
├── LICENSE
├── plugins/
│   ├── ssis-analyzer/      # .dtsx parser (stdlib python)
│   ├── dacpac-analyzer/    # .dacpac/.bacpac parser (stdlib python)
│   └── spec-writer/        # orchestrator skill (no scripts/, prose-only)
```
