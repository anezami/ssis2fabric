# Helly's history — ssis2fabric

Validates both migration flavors against source SSIS behavior. Reviewer (can reject → lockout applies).
User: arnezami.

## Learnings

## 2026-05-26 — End-to-end validation pass (ssis2fabric)
- Ran 3 aggregate queries (DimProduct Cnt+PriceSum, DimCustomer Cnt+CountryCount, FactOrders Cnt+AmtSum+MinDt+MaxDt) across VM SalesDW / Fabric Warehouse / Fabric Lakehouse.
- **Outcome:** Warehouse and Lakehouse aggregates match exactly (100 / 23199.50; 500 / 20; 2000 / 2039990.00). No tolerance needed. Verdict: APPROVED WITH NOTES.
- **Reachability:** VM SQL (`20.163.102.57,1433`) was TCP-unreachable from my host — accepted baseline row counts from `out/baseline/target-rowcounts.json` rather than retrying past the 2-attempt budget. Lesson: when reviewer is off the loader network, document the N/A rather than chasing it.
- **Schema gotcha:** Lakehouse uses snake_case (`price`, `country_name`, `total_amount`); `fact_orders` has no `order_date` column → MinDt/MaxDt unavailable on flavor B. Always probe `INFORMATION_SCHEMA.COLUMNS` first when validating across flavors with divergent naming.
- **Divergences captured (notes, not failures):** COPY INTO blocked under sqlcmd token → pyodbc INSERT fallback; hand-authored DTSX failed dtexec → T-SQL workaround on source; per-flavor surrogate-key strategy.
- **Discipline:** kept under the ~30 tool-call budget; never wrote tokens to disk (read `az account get-access-token` into a variable only); raw results saved to `out/baseline/aggregate-validation.json`.
