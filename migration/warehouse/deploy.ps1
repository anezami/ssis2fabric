<#
.SYNOPSIS
    Deploys the Fabric Warehouse DDL + procedures to wh_ssis_demo.

.DESCRIPTION
    Idempotent runner for migration/warehouse/*.sql in numeric order.
    Auth: AAD bearer token from `az account get-access-token --resource
    https://database.windows.net`. Uses Invoke-Sqlcmd with -AccessToken
    if available, otherwise falls back to the Microsoft.Data.SqlClient
    DLL shipped with the SqlServer PS module.

.NOTES
    Workspace / warehouse identifiers come from fabric/workspace.json.
    Run from the repository root:
        pwsh -File migration/warehouse/deploy.ps1
#>
[CmdletBinding()]
param(
    [string]$WorkspaceFile = "fabric/workspace.json",
    [string]$SqlDir        = "migration/warehouse",
    [switch]$IncludeCopyInto,    # also run 99_copy_into_template.sql
    [switch]$RunAll              # also EXEC dw.usp_RunAll after deploy
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $WorkspaceFile)) {
    throw "workspace.json not found at $WorkspaceFile"
}
$ws = Get-Content $WorkspaceFile -Raw | ConvertFrom-Json
$server   = $ws.warehouseSqlEndpointServer
$database = $ws.warehouseName

Write-Host "[deploy] target  : $server / $database"

# --- Acquire AAD token --------------------------------------------------
$tokenJson = az account get-access-token --resource https://database.windows.net --output json 2>$null
if ($LASTEXITCODE -ne 0 -or -not $tokenJson) {
    throw "Failed to acquire AAD token. Run 'az login' first."
}
$token = ($tokenJson | ConvertFrom-Json).accessToken

# --- Helper: run one .sql file -----------------------------------------
function Invoke-WarehouseSqlFile {
    param([string]$Path)

    Write-Host "[deploy] running: $Path"
    $sql = Get-Content -Raw -LiteralPath $Path

    try {
        Invoke-Sqlcmd `
            -ServerInstance $server `
            -Database $database `
            -AccessToken $token `
            -Query $sql `
            -TrustServerCertificate `
            -QueryTimeout 300 `
            -ConnectionTimeout 60 `
            -ErrorAction Stop
        return
    } catch {
        if ($_.Exception.Message -match 'AccessToken') {
            Write-Host "[deploy] -AccessToken not supported; falling back to SqlClient"
        } else {
            throw
        }
    }

    # Fallback path -----------------------------------------------------
    Add-Type -AssemblyName "Microsoft.Data.SqlClient" -ErrorAction SilentlyContinue
    $cs   = "Server=tcp:$server,1433;Database=$database;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60"
    $conn = New-Object Microsoft.Data.SqlClient.SqlConnection $cs
    $conn.AccessToken = $token
    $conn.Open()
    try {
        # Split on GO at start of line so multi-batch files work.
        $batches = [regex]::Split($sql, '(?im)^\s*GO\s*$')
        foreach ($b in $batches) {
            $body = $b.Trim()
            if (-not $body) { continue }
            $cmd = $conn.CreateCommand()
            $cmd.CommandText    = $body
            $cmd.CommandTimeout = 300
            [void]$cmd.ExecuteNonQuery()
        }
    } finally {
        $conn.Dispose()
    }
}

# --- Order files numerically -------------------------------------------
$files = Get-ChildItem -Path $SqlDir -Filter '*.sql' | Sort-Object Name
if (-not $IncludeCopyInto) {
    $files = $files | Where-Object { $_.Name -notlike '99_copy_into*' }
}

foreach ($f in $files) {
    Invoke-WarehouseSqlFile -Path $f.FullName
}

if ($RunAll) {
    Write-Host "[deploy] EXEC dw.usp_RunAll"
    Invoke-Sqlcmd -ServerInstance $server -Database $database `
        -AccessToken $token -TrustServerCertificate `
        -Query "EXEC dw.usp_RunAll;"
}

Write-Host "[deploy] done."
