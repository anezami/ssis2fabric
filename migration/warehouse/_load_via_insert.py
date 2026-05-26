"""Bulk-load stg.* tables from local parquet files into Fabric Warehouse using
batched INSERT ... VALUES via pyodbc + AAD access token.

Workaround: COPY INTO from OneLake fails from Invoke-Sqlcmd ("Access token
couldn't be fetched for storage path ...") because the warehouse cannot
delegate the caller's identity to OneLake without workspace identity setup.
INSERT batches are slower but fine for the 8.6k total rows in this demo.
"""
import os, sys, struct, subprocess, datetime
import pandas as pd
import pyodbc

SERVER = "2cmo46ndvemuvau5r4jl6j4dx4-inal3sn7ce6urp6kdqvsjegdv4.datawarehouse.fabric.microsoft.com"
DB     = "wh_ssis_demo"
RAW    = os.path.join(os.path.dirname(__file__), "..", "..", "out", "raw")

TABLES = [
    ("stg.CountryLookup", "CountryLookup.parquet",
        ["CountryCode", "CountryName"]),
    ("stg.Customers",     "Customers.parquet",
        ["CustomerID", "FullName", "Email", "Country", "CreatedAt"]),
    ("stg.Products",      "Products.parquet",
        ["ProductID", "Sku", "Name", "Category", "Price", "IsActive"]),
    ("stg.Orders",        "Orders.parquet",
        ["OrderID", "CustomerID", "OrderDate", "TotalAmount", "Status"]),
    ("stg.OrderItems",    "OrderItems.parquet",
        ["OrderItemID", "OrderID", "ProductID", "Quantity", "UnitPrice"]),
]

def aad_token():
    out = subprocess.check_output(
        ["az", "account", "get-access-token",
         "--resource", "https://database.windows.net",
         "--query", "accessToken", "-o", "tsv"],
        shell=True)
    return out.decode().strip()

def token_struct(token):
    # SQL_COPT_SS_ACCESS_TOKEN expects UTF-16LE length-prefixed bytes.
    btoken = token.encode("utf-16-le")
    return struct.pack(f"=i{len(btoken)}s", len(btoken), btoken)

def connect(token):
    SQL_COPT_SS_ACCESS_TOKEN = 1256
    drivers = [d for d in pyodbc.drivers() if "ODBC Driver" in d and "SQL Server" in d]
    if not drivers:
        raise RuntimeError("No ODBC Driver for SQL Server installed")
    drv = sorted(drivers)[-1]
    cs  = f"Driver={{{drv}}};Server={SERVER},1433;Database={DB};Encrypt=yes;TrustServerCertificate=no;"
    return pyodbc.connect(cs, attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct(token)})

def load_table(cn, table, parquet, cols):
    df = pd.read_parquet(os.path.join(RAW, parquet))
    df = df[cols]
    cur = cn.cursor()
    cur.execute(f"DELETE FROM {table};")
    cn.commit()
    rows = []
    for rec in df.itertuples(index=False, name=None):
        rec = list(rec)
        for i, v in enumerate(rec):
            if isinstance(v, pd.Timestamp):
                rec[i] = v.to_pydatetime()
            elif v is None:
                rec[i] = None
            elif hasattr(v, "item") and not isinstance(v, (str, bytes)):
                try:
                    rec[i] = v.item()
                except Exception:
                    rec[i] = v
            elif pd.isna(v):
                rec[i] = None
        rows.append(rec)
    # Multi-row VALUES to dramatically reduce roundtrips on Fabric Warehouse.
    one = "(" + ", ".join(["?"] * len(cols)) + ")"
    ROWS_PER_STMT = 200
    n = 0
    for i in range(0, len(rows), ROWS_PER_STMT):
        chunk = rows[i:i+ROWS_PER_STMT]
        values = ", ".join([one] * len(chunk))
        sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES {values}"
        flat = [v for row in chunk for v in row]
        cur.execute(sql, flat)
        n += len(chunk)
    cn.commit()
    print(f"  {table}: inserted {n} rows")

def main():
    token = aad_token()
    cn = connect(token)
    print(f"connected to {SERVER} / {DB}")
    for tbl, pq, cols in TABLES:
        load_table(cn, tbl, pq, cols)
    cn.close()
    print("done.")

if __name__ == "__main__":
    main()
