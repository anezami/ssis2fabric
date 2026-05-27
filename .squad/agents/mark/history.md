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

## 2026-05-26 — Customer-facing README published

Wrote /README.md (619 lines) as the external public walkthrough of the SSIS-to-Fabric migration using the ssis-migration Copilot skill. Sourced facts from migration/MIGRATION.md, migration/RECON.md, migration/specs/, tests/validation-report.md, out/baseline/aggregate-validation.json. Anonymised all GUIDs/IPs/hostnames (workspace.json, infra/connection.json) with placeholders. Covers: what/why two flavors, ASCII architecture, prereqs (sqlpackage, az, Copilot CLI, skill install), 8-step walkthrough referencing real files in migration/warehouse and migration/lakehouse, file map, gotchas (Fabric T-SQL surface, Msg 13840 COPY INTO, OneLake DFS binary upload, capacity GUID vs ARM ID, DTSX dtexec strictness, parquet nanos), results table (500/100/2000, sum 2,039,990.00), CTA links. No agent names, no Severance refs, no .squad mentions.

## Learnings — DECKIO presentation deck (2026-05-27)

- Scaffold via `cmd /c "npx -y create-deckio@latest <dir> --theme fabric --title ... --subtitle ... < NUL"`. The scaffolder uses @clack/prompts; `--yes` is not a flag, but it detects non-TTY stdin and uses defaults. Piping from `NUL` (on Windows) makes it non-interactive cleanly. Flags: `--title`, `--subtitle`, `--icon`, `--theme {fabric|shadcn|default}`, `--appearance`, `--accent`, `--palette`, `--no-install`.
- Slide file format: each slide is a default-exported React function that returns `<Slide index={index} className={styles.slide}>...</Slide>`. Wrap in `content-frame content-gutter`, add an `accent-bar` div, end with `<BottomBar text={...} />`. Use `<Editable as="..." id="...">` for editable text regions (powers inline editing in dev).
- Slides import from `@deckio/deck-engine` (`Slide`, `BottomBar`, `Editable`, `EditableList`). Slide order + accent + theme live in `deck.config.js` at the project root; `src/App.jsx` reads it and renders.
- Fabric theme expects `src/data/fabric-icons.js` (re-exports from `@fabric-msft/svg-icons`). The scaffolder only copies it when an engine install is already discoverable; in our flow (`npx` + install in one step) it ran before `node_modules` existed, so the file was missing. Workaround: `Copy-Item node_modules/@deckio/deck-engine/themes/fabric-icons.js src/data/fabric-icons.js` after install. Worth filing upstream.
- The scaffolder marks sample slides with a `SAMPLE CONTENT ONLY` JSDoc banner and the project `meta.contentStatus: 'sample'` so Copilot ignores them. Strip the banner and set `contentStatus: 'final'` when replacing.
- Theme CSS variables to use: `--background`, `--foreground`, `--card`, `--border`, `--border-subtle`, `--primary`, `--accent`, `--glow-accent`, `--muted-foreground`, `--secondary`, `--radius-sm/md/lg/xl`, `--shadow-elevated`. The fabric theme is light by default; the Microsoft mark (four colored squares) is a recurring brand anchor in the sample slides — kept it for visual consistency.
- `npm run dev` (Vite 8) starts on :5173. First load triggers dependency optimization for `@fabric-msft/svg-icons/dist/*` — the page-reload that follows is normal, not an error.
- Gitignore that the scaffolder writes already covers `node_modules`, `dist`, `.vite`, `.env*`, and crash dumps — safe to `git add deck/` wholesale.

## Learnings — dark-mode deck + conversion docs (2026-05-27)

- **Dark mode pattern (DECKIO + fabric theme):** Cleanest approach is to keep the engine theme imports (@deckio/deck-engine/styles/global.css and 	hemes/fabric.css) and override CSS variables in a second `:root { … }` block at the bottom of `src/index.css`. All slide modules consume tokens (`var(--background)`, `var(--foreground)`, `var(--card)`, `var(--accent)` …) so re-skinning is single-file. Set `color-scheme: dark` and update `--shadow-elevated` to a stronger black shadow — light-mode shadows look invisible on a near-black canvas.
- **Palette:** `--background #0a0e1a` / `--card #141a28` / `--foreground #e6edf3` / `--primary`+`--accent #00B7C3` (Fabric teal) / `--purple-deep #742774` decorative. `--border-subtle` switched from grey to `rgba(255,255,255,0.08)` to keep card edges legible without harsh lines.
- **`color-mix(in srgb, var(--secondary) X%, var(--card))`** in slide CSS adapts automatically when the variable values flip — no per-slide CSS edits required for the re-skin. Validated by `npm run build` (no warnings, 3.96s).
- **Mermaid embedding pattern:** For the README, `%%{init: {'theme':'dark', 'themeVariables': {...}}}%%` directive at the top of the fenced `mermaid` block gives full control over node fill, stroke, line, font without any external SVG. `classDef` blocks at the bottom + `class A,B,C name` assignments are the cleanest way to colour-code subsystems (source / skill / spec / warehouse / lakehouse / workspace).
- **Deck-side flow diagram:** Don't try to bolt mermaid into the engine — DECKIO already exposes a flow primitive (the `ContentSlide.module.css` `.flow`/`.flowStep`/`.flowArrow` classes). For a richer diagram with subgroups, building a custom slide module (`E2EFlowSlide.module.css`) with rows + colored `border-left` accents per node type matches the deck visual language without new dependencies.
- **Conversion mapping authoritative reference (use this any time the README/deck need to be re-stated):**
  - OLE DB Source → `Copy Activity` / `spark.read.jdbc`
  - OLE DB Destination → `INSERT...MERGE` / `df.write.format("delta")`
  - Derived Column → `CASE WHEN` / `df.withColumn(when().otherwise())`
  - Lookup → `LEFT JOIN` / `df.join(dim, "key", "left")`
  - Conditional Split → branched `WHERE` / `df.filter` per branch
  - Aggregate → `GROUP BY` / `groupBy().agg()`
  - Foreach Loop → pipeline `ForEach` activity / Python `for`
  - Execute SQL Task → stored procedure / `spark.sql(...)`
  - Script Task → stored proc or notebook step / native PySpark cell
- **Slide registration:** Per `AGENTS.md`/`deck-config.instructions.md`, the only valid registration step is import + array insertion in `deck.config.js`. New slides registered: `E2EFlowSlide` (index 1, right after cover), `ConversionSlide` + `ConversionExampleSlide` (after MigrationToolSlide, before path-specific slides).
- **Don't touch:** `App.jsx`, `main.jsx`, `vite.config.js`, `package.json`, `index.html`, and anything under `node_modules`. AGENTS.md is explicit.
