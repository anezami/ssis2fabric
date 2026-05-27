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

### 2026-05-26: Final validation verdict — both Fabric flavors PASS
**By:** Helly
**What:** End-to-end validation approved with notes. Fabric Warehouse and Fabric Lakehouse aggregates match byte-for-byte for DimProduct, DimCustomer, and FactOrders; migration-quality notes are non-blocking correctness observations.
**Why:** Confirms the demo is ready with both Fabric flavors passing aggregate validation; live VM source re-query remains noted as environment-limited from the reviewer host.
### 2026-05-26: Bastion Setup for vm-ssis-demo
**By:** Cobel (Azure Infra)
**Status:** Implemented
**What:** Deploy Azure Bastion (Standard SKU) into the existing VNet to provide browser-based and native-client RDP without exposing port 3389 to the internet. Bastion host `bastion-ssis-demo` in subnet `AzureBastionSubnet` `10.31.1.0/26` with public IP `20.169.19.6`. Standard Bastion cost ~$0.19/hr (~$140/mo).

### 2026-05-26: Customer README published at repo root
**By:** Mark
**Status:** Done
**What:** Customer-facing migration README written to `README.md` at repo root (619 lines). Polished, externally-shareable counterpart to `migration/MIGRATION.md`. All GUIDs, IPs, hostnames and passwords replaced with placeholders. Walks customer through ssis-analyzer, dacpac-analyzer, spec-writer, Fabric provisioning, and both Flavor A (Warehouse T-SQL) and Flavor B (Lakehouse PySpark) deployment with validation.

### 2026-05-27: Presentation deck — DECKIO
**By:** Mark
**Status:** Done
**What:** Built DECKIO presentation deck (12 slides) for customer narrative, committed to master. Scaffolded at `deck/`, sourced from README.md (no Severance/squad references). Slides cover problem, demo scope, architectures, both Fabric flavors, comparison, validation, live demo flow, lessons, and next steps. Smoke-tested with `npm run dev`; pushed as `892a43a`.

### 2026-05-26: Private Repo Creation
**By:** Scribe (Copilot)
**Status:** Completed
**What:** Created private GitHub repository at https://github.com/anezami/ssis2fabric. All commits pushed to origin/master via GitHub CLI (gh). Visibility confirmed as PRIVATE.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction


# Mark — Dark mode deck + E2E flow diagram + SSIS→SQL/SparkSQL conversion docs

**Date:** 2026-05-27
**By:** Mark (Lead / Migration Architect)
**Status:** Implemented, built clean, committed

## What changed

Three deliverables in one pass against `master`:

1. **DECKIO deck flipped to dark mode by default.**
   - `deck/src/index.css` — kept the engine `@import` of `themes/fabric.css`, then appended a `:root { … }` override block with a near-black canvas (`#0a0e1a`), light foreground (`#e6edf3`), Fabric teal as `--primary`/`--accent` (`#00B7C3`), Fabric purple as decorative (`#742774` / `#B084CC`), and a strengthened `--shadow-elevated`.
   - `deck/deck.config.js` — `appearance: 'dark'`, `accent: '#00B7C3'`.
   - Existing slide modules required **no edits** — every slide consumes `var(--…)` tokens, so the single override re-skins the entire deck. Validated with `npm run build` (3.96s clean).

2. **End-to-end flow diagram, in both surfaces.**
   - **README** — `## 0. End-to-end flow at a glance`, just under the project intro, rendered with a Mermaid `flowchart LR` block. Uses inline `%%{init: {'theme':'dark', 'themeVariables': {...}}}%%` so it renders dark on GitHub regardless of viewer theme. Three subsystems: Azure VM (SQL + SSIS), the Copilot skill (analyzer / dacpac / spec-writer), and the two Fabric build passes. `classDef` + `class … src/skill/spec/wh/lh/ws` assignments give per-subsystem colour coding.
   - **Deck** — new slide `E2EFlowSlide.jsx` registered at index 1 (immediately after the cover). Hand-built layout in `E2EFlowSlide.module.css` using rows of `.node` cards with colour-coded `border-left` per subsystem (source = blue, skill = purple, spec/accent = teal, warehouse = cyan, lakehouse = purple, workspace = teal). Avoids pulling a Mermaid renderer into the deck bundle.

3. **`How the conversion works` explainer.**
   - **README** — new section `## 3a. How the conversion works` between Architecture and Prerequisites. Covers: what the skill parses out of `.dtsx`, what it parses out of `.bacpac`, what the IR contains, then the canonical side-by-side mapping table (12 SSIS components mapped to Warehouse T-SQL and Lakehouse SparkSQL/PySpark equivalents), then a worked Derived Column example in three forms (SSIS expression → T-SQL `CASE` → PySpark `when/otherwise` and equivalent `CREATE TABLE AS SELECT` SparkSQL).
   - **Deck** — two new slides registered after `MigrationToolSlide`:
     - `ConversionSlide.jsx` — the mapping table (compact 9-row version), reusing `ContentSlide.module.css`.
     - `ConversionExampleSlide.jsx` — the Derived Column worked example in three cards (SSIS / T-SQL / SparkSQL), reusing `ContentSlide.module.css`.

## Architectural decisions

### Theme palette (authoritative)

| Token | Value | Role |
|---|---|---|
| `--background` | `#0a0e1a` | Near-black canvas |
| `--card` | `#141a28` | Surface for cards / panels |
| `--foreground` | `#e6edf3` | Body text |
| `--muted-foreground` | `#9aa6bc` | Secondary text |
| `--primary` / `--accent` | `#00B7C3` | Fabric teal — primary action / hairline accents |
| `--purple` | `#B084CC` | Decorative purple |
| `--purple-deep` | `#742774` | Microsoft Fabric brand purple |
| `--border` | `#2a3349` | Card borders |
| `--border-subtle` | `rgba(255,255,255,0.08)` | Hairlines on dark surfaces |
| `--shadow-elevated` | `0 8px 28px rgba(0,0,0,.55), 0 2px 6px rgba(0,0,0,.35)` | Stronger than light-mode to register on near-black bg |

### Diagram tool choice

* **README → Mermaid.** GitHub renders it natively, no SVG checked in, dark theme via init directive. Future edits are pure markdown.
* **Deck → hand-built React/CSS module.** Pulling a Mermaid render-engine into a Vite/React deck bundle is not justified for a single diagram; the engine already exposes a flow primitive vocabulary (`.flow/.flowStep/.flowArrow` in `ContentSlide.module.css`) and the new `E2EFlowSlide.module.css` extends that vocabulary with subsystem colour-coding via `border-left` accents. Stays inside the DECKIO authoring conventions (`AGENTS.md`, `slide-jsx.instructions.md`, `slide-css.instructions.md`).

### Authoritative SSIS → Fabric mapping table

This table is the canonical reference for any future migration work — Dylan and Helly should treat divergences from it as defects:

| SSIS | Warehouse (T-SQL) | Lakehouse (SparkSQL/PySpark) |
|---|---|---|
| OLE DB Source | Pipeline Copy Activity → staging | `spark.read.jdbc/parquet/delta` |
| OLE DB Destination | `INSERT … SELECT` / `MERGE` | `df.write.format("delta")` |
| Flat File Source | Copy Activity (delimited) | `spark.read.csv` |
| Derived Column | `CASE WHEN` in projection | `df.withColumn(when().otherwise())` |
| Lookup | `LEFT JOIN` on staging | `df.join(dim, "key", "left")` |
| Conditional Split | Branched `WHERE` / multiple INSERTs | `df.filter(...)` per branch |
| Aggregate | `GROUP BY` / window functions | `df.groupBy().agg(...)` |
| Sort | `ORDER BY` / `ROW_NUMBER()` | `df.orderBy(...)` |
| Merge / Union All | `UNION ALL` | `df1.unionByName(df2)` |
| Execute SQL Task | Stored procedure | `spark.sql("...")` |
| Foreach Loop | Pipeline `ForEach` activity | Python `for` over list |
| Script Task | Stored proc / pipeline notebook step | Native PySpark cell |
| Connection Manager | Linked service | Spark conf / OneLake path |
| Project / Package Param | Pipeline parameter | Notebook parameter cell |

## Slide registration (final order)

```
1.  CoverSlide
2.  E2EFlowSlide                ← new
3.  ProblemSlide
4.  DemoScopeSlide
5.  SourceArchitectureSlide
6.  MigrationToolSlide
7.  ConversionSlide              ← new (mapping table)
8.  ConversionExampleSlide       ← new (Derived Column worked example)
9.  WarehousePathSlide
10. LakehousePathSlide
11. ComparisonSlide
12. ValidationSlide
13. DemoFlowSlide
14. LessonsSlide
15. ThankYouSlide
```

## Verification

- `npm run build` in `deck/` → clean, 273 modules transformed, 3.96s, no warnings.
- README Mermaid block uses GitHub-supported syntax (init directive + flowchart LR + classDef).
- Dev server already running on :5173; refresh shows dark canvas and new slides.

## Files touched

```
deck/src/index.css                                 (dark palette override)
deck/deck.config.js                                (appearance, accent, slide registry)
deck/src/slides/E2EFlowSlide.jsx                   (new)
deck/src/slides/E2EFlowSlide.module.css            (new)
deck/src/slides/ConversionSlide.jsx                (new)
deck/src/slides/ConversionExampleSlide.jsx        (new)
README.md                                          (Mermaid diagram + §3a conversion section)
```

## Reviewer gate

This is documentation + visual polish; Dylan's previously approved warehouse/lakehouse artifacts are untouched. No new reviewer rejection lockout.

