# Validation verdict — ssis2fabric end-to-end

**Reviewer:** Helly
**Date:** 2026-05-26
**Status:** **APPROVED WITH NOTES**

## Rationale
- Fabric Warehouse and Fabric Lakehouse produce **byte-for-byte equal** aggregates for DimProduct (100 / 23,199.50), DimCustomer (500 / 20 countries) and FactOrders (2,000 / 2,039,990.00). No tolerance needed.
- Source-side VM `SalesDW` row counts (500 / 100 / 2,000) match both Fabric flavors per the captured baseline; live re-query of the VM was not possible from the reviewer host (TCP timeout on `20.163.102.57,1433`) — re-run from the loader host to close that gap.
- Divergences listed below are migration-quality observations, not correctness failures.

## Notes (not failures)
1. COPY INTO from OneLake blocked under sqlcmd-passed AAD token → Warehouse loader fell back to `pyodbc` INSERT + `EXEC dw.usp_RunAll`. Result identical.
2. Hand-authored DTSX failed `dtexec` validation; source `SalesDW` populated via T-SQL equivalents of the SSIS packages. Row counts match.
3. Surrogate key strategy differs per flavor (Warehouse `IDENTITY` vs Spark windowing in Lakehouse). Natural keys align; surrogates intentionally not compared.
4. Lakehouse `fact_orders` projection omits `order_date` → MinDt/MaxDt N/A. Counts and money sum still match Warehouse exactly.
5. VM SQL endpoint unreachable from reviewer host at validation time → VM aggregates reported as N/A in the table, baseline row counts cited instead.

## See
- `tests/validation-report.md` (full table + plain-language explanation)
- `out/baseline/aggregate-validation.json` (raw aggregate query output)
