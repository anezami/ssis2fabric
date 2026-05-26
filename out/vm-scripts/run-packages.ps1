param([string]$Pwd)
$ErrorActionPreference = 'Continue'
$dtexec = 'C:\Program Files\Microsoft SQL Server\160\DTS\Binn\dtexec.exe'
if (-not (Test-Path $dtexec)) {
    Write-Host "dtexec NOT found at $dtexec"
    Get-ChildItem 'C:\Program Files\Microsoft SQL Server' -Directory | Select-Object Name
    exit 2
}

$srcConn = "Data Source=localhost;Initial Catalog=SalesSrc;Provider=SQLOLEDB.1;User ID=sa;Password=$Pwd;Auto Translate=False;"
$dwConn  = "Data Source=localhost;Initial Catalog=SalesDW;Provider=SQLOLEDB.1;User ID=sa;Password=$Pwd;Auto Translate=False;"

$packages = @(
  @{ Name='Load_Customers';           File='C:\ssisdemo\packages\Load_Customers.dtsx';           Conns=@('SalesSrcConn','SalesDwConn') },
  @{ Name='Load_Orders';              File='C:\ssisdemo\packages\Load_Orders.dtsx';              Conns=@('SalesSrcConn','SalesDwConn') },
  @{ Name='Load_Products_Scripted';   File='C:\ssisdemo\packages\Load_Products_Scripted.dtsx';   Conns=@('SalesDwConn') }
)

foreach ($p in $packages) {
    Write-Host "=========================================="
    Write-Host "RUN: $($p.Name)"
    Write-Host "=========================================="
    $args = @('/F', $p.File, '/REPORTING', 'E')
    foreach ($cn in $p.Conns) {
        $cs = if ($cn -eq 'SalesSrcConn') { $srcConn } else { $dwConn }
        $args += @('/CONN', ('"{0}";"{1}"' -f $cn, $cs))
    }
    Write-Host ("ARGS: " + ($args -replace [regex]::Escape($Pwd), '***'))
    $log = "C:\ssisdemo\logs\$($p.Name).log"
    & $dtexec @args *>&1 | Tee-Object -FilePath $log
    Write-Host "ExitCode: $LASTEXITCODE"
    Write-Host ""
}

# Row counts after run
Write-Host "=========================================="
Write-Host "TARGET ROW COUNTS"
Write-Host "=========================================="
$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = "Server=localhost;Database=SalesDW;User Id=sa;Password=$Pwd;Encrypt=False;TrustServerCertificate=True;"
$conn.Open()
foreach ($t in @('dim.DimCustomer','dim.DimProduct','fact.FactOrders')) {
    $cmd = $conn.CreateCommand(); $cmd.CommandText = "SELECT COUNT(*) FROM $t"
    $c = $cmd.ExecuteScalar()
    Write-Host "$t = $c"
}
$conn.Close()
