import os, sys, pandas as pd
out_dir = sys.argv[1]
tables_with_dtypes = {
    "Customers":     {"CustomerID": "Int64", "FullName": "string", "Email": "string",
                      "Country": "string", "CreatedAt": "string"},
    "Products":      {"ProductID": "Int64", "Sku": "string", "Name": "string",
                      "Category": "string", "Price": "float64", "IsActive": "string"},
    "Orders":        {"OrderID": "Int64", "CustomerID": "Int64", "OrderDate": "string",
                      "TotalAmount": "float64", "Status": "string"},
    "OrderItems":    {"OrderItemID": "Int64", "OrderID": "Int64", "ProductID": "Int64",
                      "Quantity": "Int64", "UnitPrice": "float64"},
    "CountryLookup": {"CountryCode": "string", "CountryName": "string"},
}
ts_cols = {"Customers": ["CreatedAt"], "Orders": ["OrderDate"]}
for t, dtypes in tables_with_dtypes.items():
    src = os.path.join(out_dir, f"{t}.csv")
    dst = os.path.join(out_dir, f"{t}.parquet")
    df = pd.read_csv(src, dtype=dtypes)
    if t == "Products":
        df["IsActive"] = df["IsActive"].map({"True": 1, "False": 0, "true": 1, "false": 0, "1": 1, "0": 0}).astype("Int64")
    for col in ts_cols.get(t, []):
        df[col] = pd.to_datetime(df[col], format="mixed")
    df.to_parquet(dst, engine="pyarrow", index=False, compression="snappy",
                  coerce_timestamps="us", allow_truncated_timestamps=True)
    print(f"  {t}: {len(df)} rows -> {dst}")
