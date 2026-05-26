[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SqlAdminPassword,

    [string]$SqlInstance = "localhost",
    [string]$CatalogPassword = $SqlAdminPassword
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-LocalSql {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [switch]$IntegratedSecurity
    )

    $invokeSqlcmd = Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue
    if ($invokeSqlcmd) {
        $sqlcmdParams = @{
            ServerInstance = $SqlInstance
            Query          = $Query
        }
        if (-not $IntegratedSecurity) {
            $sqlcmdParams.Username = "sa"
            $sqlcmdParams.Password = $SqlAdminPassword
        }
        if ($invokeSqlcmd.Parameters.ContainsKey("TrustServerCertificate")) {
            $sqlcmdParams.TrustServerCertificate = $true
        }
        Invoke-Sqlcmd @sqlcmdParams
        return
    }

    if ($IntegratedSecurity) {
        $connectionString = "Server=$SqlInstance;Integrated Security=True;TrustServerCertificate=True;Encrypt=True"
    } else {
        $connectionString = "Server=$SqlInstance;User ID=sa;Password=$SqlAdminPassword;TrustServerCertificate=True;Encrypt=True"
    }
    $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 120
    $command.CommandText = $Query
    $connection.Open()
    try {
        [void]$command.ExecuteNonQuery()
    } finally {
        $connection.Dispose()
    }
}

function Test-IntegratedSqlSysadmin {
    try {
        $result = Invoke-LocalSql -IntegratedSecurity -Query "SET NOCOUNT ON; SELECT CAST(IS_SRVROLEMEMBER('sysadmin') AS int) AS IsSysadmin;"
        return (($result | Select-Object -First 1).IsSysadmin -eq 1)
    } catch {
        return $false
    }
}

function Invoke-LocalSqlWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [switch]$IntegratedSecurity,
        [int]$Retries = 12
    )

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            return Invoke-LocalSql -Query $Query -IntegratedSecurity:$IntegratedSecurity
        } catch {
            if ($attempt -eq $Retries) { throw }
            Start-Sleep -Seconds 5
        }
    }
}

function Enable-LocalSystemSqlSysadmin {
    if (Test-IntegratedSqlSysadmin) { return }

    Write-Host "Temporarily starting SQL Server in single-user mode to grant run-command sysadmin access..."
    Stop-Service -Name "SQLSERVERAGENT" -ErrorAction SilentlyContinue

    $instanceNamesKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    $instanceId = (Get-ItemProperty -Path $instanceNamesKey).MSSQLSERVER
    if (-not $instanceId) {
        throw "Could not resolve MSSQLSERVER instance id from registry."
    }
    $parametersKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\Parameters"
    $parameterProps = Get-ItemProperty -Path $parametersKey
    $existingSingleUser = $parameterProps.PSObject.Properties | Where-Object { $_.Name -like "SQLArg*" -and $_.Value -eq "-m" } | Select-Object -First 1
    $addedParameterName = $null

    if (-not $existingSingleUser) {
        $nextIndex = (($parameterProps.PSObject.Properties.Name | Where-Object { $_ -match "^SQLArg(\d+)$" } | ForEach-Object { [int]($Matches[1]) }) | Measure-Object -Maximum).Maximum + 1
        if ($null -eq $nextIndex) { $nextIndex = 0 }
        $addedParameterName = "SQLArg$nextIndex"
        New-ItemProperty -Path $parametersKey -Name $addedParameterName -Value "-m" -PropertyType String | Out-Null
    }

    try {
        Restart-Service -Name "MSSQLSERVER" -Force
        Invoke-LocalSqlWithRetry -IntegratedSecurity -Query @"
IF SUSER_ID(N'NT AUTHORITY\SYSTEM') IS NULL
    CREATE LOGIN [NT AUTHORITY\SYSTEM] FROM WINDOWS;
ALTER SERVER ROLE [sysadmin] ADD MEMBER [NT AUTHORITY\SYSTEM];
"@
    } finally {
        if ($addedParameterName) {
            Remove-ItemProperty -Path $parametersKey -Name $addedParameterName -ErrorAction SilentlyContinue
        }
        Restart-Service -Name "MSSQLSERVER" -Force
        Start-Service -Name "SQLSERVERAGENT" -ErrorAction SilentlyContinue
    }
}

Write-Host "Checking SQL Server Integration Services service..."
$ssisServices = Get-Service -Name "MsDtsServer*" -ErrorAction SilentlyContinue
if (-not $ssisServices) {
    Write-Host "SSIS service not found. Attempting SQL Server setup install with /Features=IS."
    $setupCandidates = @(
        "C:\SQLServerFull\Setup.exe",
        "C:\SQL2022\Setup.exe",
        "C:\SQLServer2022Media\Setup.exe"
    )
    $setupPath = $setupCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $setupPath) {
        throw "SSIS is missing and SQL Server setup media was not found. Checked: $($setupCandidates -join ', ')"
    }
    Start-Process -FilePath $setupPath -ArgumentList "/Q", "/ACTION=Install", "/FEATURES=IS", "/IACCEPTSQLSERVERLICENSETERMS" -Wait -NoNewWindow
    $ssisServices = Get-Service -Name "MsDtsServer*" -ErrorAction SilentlyContinue
    if (-not $ssisServices) {
        throw "SSIS installation completed but MsDtsServer service was still not found."
    }
}
$ssisServices | Start-Service

Write-Host "Enabling SQL Server TCP/IP..."
$namespace = "root\Microsoft\SqlServer\ComputerManagement16"
$tcp = Get-CimInstance -Namespace $namespace -ClassName ServerNetworkProtocol -Filter "ProtocolName='Tcp'" -ErrorAction SilentlyContinue
if ($tcp) {
    Invoke-CimMethod -InputObject $tcp -MethodName SetEnable | Out-Null
    $tcpPort = Get-CimInstance -Namespace $namespace -ClassName ServerNetworkProtocolProperty -Filter "InstanceName='MSSQLSERVER' AND ProtocolName='Tcp' AND IPAddressName='IPAll' AND PropertyName='TcpPort'" -ErrorAction SilentlyContinue
    if ($tcpPort) {
        Invoke-CimMethod -InputObject $tcpPort -MethodName SetStringValue -Arguments @{ StrValue = "1433" } | Out-Null
    }
    $tcpDynamicPorts = Get-CimInstance -Namespace $namespace -ClassName ServerNetworkProtocolProperty -Filter "InstanceName='MSSQLSERVER' AND ProtocolName='Tcp' AND IPAddressName='IPAll' AND PropertyName='TcpDynamicPorts'" -ErrorAction SilentlyContinue
    if ($tcpDynamicPorts) {
        Invoke-CimMethod -InputObject $tcpDynamicPorts -MethodName SetStringValue -Arguments @{ StrValue = "" } | Out-Null
    }
}
if (-not (Get-NetFirewallRule -DisplayName "SQL Server 1433 (SSIS demo)" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "SQL Server 1433 (SSIS demo)" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow | Out-Null
}

Enable-LocalSystemSqlSysadmin

$sqlAdminPasswordLiteral = $SqlAdminPassword.Replace("'", "''")
Invoke-LocalSqlWithRetry -IntegratedSecurity -Query @"
ALTER LOGIN [sa] ENABLE;
ALTER LOGIN [sa] WITH PASSWORD = N'$sqlAdminPasswordLiteral', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
"@

Write-Host "Restarting SQL Server service to apply authentication and TCP changes..."
Restart-Service -Name "MSSQLSERVER" -Force
Start-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue

Write-Host "Creating SSISDB catalog if needed..."
$ssisAssembly = "C:\Program Files (x86)\Microsoft SQL Server\160\SDK\Assemblies\Microsoft.SqlServer.Management.IntegrationServices.dll"
if (Test-Path $ssisAssembly) {
    Add-Type -Path $ssisAssembly
} else {
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices")
}
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null

$sqlConnection = [System.Data.SqlClient.SqlConnection]::new("Server=$SqlInstance;Integrated Security=True;TrustServerCertificate=True;Encrypt=True")
$sqlStoreConnection = [Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection]::new($sqlConnection)
$integrationServices = [Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices]::new($sqlStoreConnection)
if (-not $integrationServices.Catalogs.Contains("SSISDB")) {
    $catalog = [Microsoft.SqlServer.Management.IntegrationServices.Catalog]::new($integrationServices, "SSISDB", $CatalogPassword)
    $catalog.Create()
    Write-Host "Created SSISDB catalog."
} else {
    Write-Host "SSISDB catalog already exists."
}

Write-Host "Restarting SQL Server service..."
$sqlServices = Get-Service -Name "MSSQLSERVER", "SQLSERVERAGENT" -ErrorAction SilentlyContinue
$sqlServices | Where-Object Status -eq "Running" | Restart-Service -Force
Start-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
Start-Service -Name "SQLSERVERAGENT" -ErrorAction SilentlyContinue

Write-Host "Post-install configuration complete."
