<#
.SYNOPSIS
    Phase 6 -- Land the five SalesSrc tables in OneLake as Parquet.

.DESCRIPTION
    a) Pulls each source table from the VM SQL (20.163.102.57,1433)
       using Invoke-Sqlcmd + sa credentials from infra\.secrets\sql-admin.json.
       Writes one CSV per table under out\raw\.
    b) Converts each CSV to Parquet via a Python helper (pandas + pyarrow).
    c) Uploads out\raw\*.parquet to
       https://onelake.dfs.fabric.microsoft.com/<workspace>/<lakehouse>.Lakehouse/Files/raw/
       using the OneLake DFS REST API (PUT path?resource=file, PATCH ?action=append,
       PATCH ?action=flush). Auth = AAD token for https://storage.azure.com/.

.NOTES
    Idempotent: it always recreates the local files and overwrites the remote
    files. Tables are SELECTed in their entirety (demo data is small).
#>
[CmdletBinding()]
param(
    [string]$WorkspaceFile = "fabric/workspace.json",
    [string]$SecretFile    = "infra/.secrets/sql-admin.json",
    [string]$VmSqlServer   = "20.163.102.57,1433",
    [string]$SourceDb      = "SalesSrc",
    [string]$OutDir        = "out/raw"
)

$ErrorActionPreference = 'Stop'

# --- Inputs -------------------------------------------------------------
$ws     = Get-Content $WorkspaceFile -Raw | ConvertFrom-Json
$secret = Get-Content $SecretFile    -Raw | ConvertFrom-Json
$saPwd  = $secret.sqlAdminPassword

$wsName = $ws.workspaceName
$lhName = $ws.lakehouseName  # "lh_ssis_demo"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Force invariant culture so decimals serialize as "18.07" (not "18,07")
# and datetimes use ISO-ish formatting -- both required by pandas read_csv.
[System.Threading.Thread]::CurrentThread.CurrentCulture =
    [System.Globalization.CultureInfo]::InvariantCulture

$tables = @('Customers', 'Products', 'Orders', 'OrderItems', 'CountryLookup')

# --- (a) Export each table to CSV --------------------------------------
Write-Host "[export] pulling tables from $VmSqlServer / $SourceDb"
foreach ($t in $tables) {
    $csvPath = Join-Path $OutDir "$t.csv"
    Write-Host "  -> $t"
    $rows = Invoke-Sqlcmd `
        -ServerInstance $VmSqlServer -Database $SourceDb `
        -Username sa -Password $saPwd `
        -TrustServerCertificate `
        -ConnectionTimeout 60 -QueryTimeout 300 `
        -Query "SELECT * FROM dbo.$t" `
        -OutputAs DataRows
    # Export-Csv handles quoting + NULLs deterministically.
    $rows | Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors `
          | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
}

# --- (b) Convert CSV -> Parquet via Python helper ----------------------
Write-Host "[export] converting CSV -> Parquet"
$pyHelper = Join-Path $OutDir "_csv_to_parquet.py"
@'
import os, sys, pandas as pd
out_dir = sys.argv[1]
tables_with_dtypes = {
    "Customers":     {"CustomerID": "Int64", "FullName": "string", "Email": "string",
                      "Country": "string", "CreatedAt": "string"},
    "Products":      {"ProductID": "Int64", "Sku": "string", "Name": "string",
                      "Category": "string", "Price": "float64", "IsActive": "Int64"},
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
    for col in ts_cols.get(t, []):
        df[col] = pd.to_datetime(df[col], format="mixed")
    df.to_parquet(dst, engine="pyarrow", index=False, compression="snappy")
    print(f"  {t}: {len(df)} rows -> {dst}")
'@ | Set-Content -LiteralPath $pyHelper -Encoding UTF8

python $pyHelper $OutDir
if ($LASTEXITCODE -ne 0) { throw "csv->parquet conversion failed" }
Remove-Item $pyHelper

# --- (c) Upload parquet to OneLake ------------------------------------
Write-Host "[export] uploading to OneLake"
$storageTokenJson = az account get-access-token --resource https://storage.azure.com/ --output json
$storageToken = ($storageTokenJson | ConvertFrom-Json).accessToken
$hdr = @{
    Authorization  = "Bearer $storageToken"
    'x-ms-version' = '2021-04-10'
}

$baseUri = "https://onelake.dfs.fabric.microsoft.com/$wsName/$lhName.Lakehouse/Files/raw"

foreach ($t in $tables) {
    $local = Join-Path $OutDir "$t.parquet"
    $bytes = [IO.File]::ReadAllBytes($local)
    $len   = $bytes.Length
    $uri   = "$baseUri/$t.parquet"

    Write-Host "  -> $t.parquet ($len bytes)"

    # 1) Create file (truncates any existing).
    Invoke-WebRequest -Method PUT -Headers $hdr `
        -Uri "$uri`?resource=file" `
        -UseBasicParsing | Out-Null

    # 2) Append the whole body (single chunk; demo files are small).
    Invoke-WebRequest -Method PATCH `
        -Headers ($hdr + @{ 'Content-Type' = 'application/octet-stream' }) `
        -Uri "$uri`?action=append&position=0" `
        -Body $bytes -UseBasicParsing | Out-Null

    # 3) Flush at the file length.
    Invoke-WebRequest -Method PATCH -Headers $hdr `
        -Uri "$uri`?action=flush&position=$len" `
        -UseBasicParsing | Out-Null
}

Write-Host ""
Write-Host "[export] done. Files landed at:"
Write-Host "  $baseUri/"
Write-Host "  ($(($tables | ForEach-Object { $_ + '.parquet' }) -join ', '))"
