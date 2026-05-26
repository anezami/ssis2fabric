<#
.SYNOPSIS
Creates or reuses the Fabric demo workspace, Warehouse, and Lakehouse.

.DESCRIPTION
Uses the signed-in Azure CLI identity to call Microsoft Fabric REST APIs. The script is
idempotent by display name: existing workspace/items are reused and workspace.json is
refreshed with discovered IDs and endpoint metadata.
#>
[CmdletBinding()]
param(
    [string]$ApiBase = "https://api.fabric.microsoft.com/v1",
    [string]$CapacityName = "fabcapacitywus3",
    [string]$WorkspaceName = "ws-ssis2fabric-demo",
    [string]$WarehouseName = "wh_ssis_demo",
    [string]$LakehouseName = "lh_ssis_demo",
    [string]$OutputPath = (Join-Path $PSScriptRoot "workspace.json")
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-FabricToken {
    $output = @(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to acquire Fabric token with az CLI. Output: $($output -join [Environment]::NewLine)"
    }

    $token = @($output | Where-Object { $_ -is [string] -and $_ -match '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' }) | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "az CLI did not return a Fabric access token."
    }
    return $token.Trim()
}

$script:FabricToken = Get-FabricToken

function Resolve-FabricUrl {
    param([Parameter(Mandatory)][string]$PathOrUrl)
    if ($PathOrUrl -match '^https?://') { return $PathOrUrl }
    if ($PathOrUrl.StartsWith('/')) { return "$ApiBase$PathOrUrl" }
    return "$ApiBase/$PathOrUrl"
}

function Invoke-FabricRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','DELETE','PATCH')][string]$Method,
        [Parameter(Mandatory)][string]$PathOrUrl,
        [object]$Body,
        [switch]$AllowNotFound
    )

    $headers = @{ Authorization = "Bearer $script:FabricToken" }
    $url = Resolve-FabricUrl $PathOrUrl
    $parameters = @{
        Method = $Method
        Uri = $url
        Headers = $headers
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = ($Body | ConvertTo-Json -Depth 20)
    }

    try {
        $response = Invoke-WebRequest @parameters
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
        if ($AllowNotFound -and $statusCode -eq 404) { return $null }
        $message = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $message = $_.ErrorDetails.Message }
        throw "Fabric REST $Method $url failed: $message"
    }

    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        try { $json = $response.Content | ConvertFrom-Json } catch { $json = $null }
    }

    [pscustomobject]@{
        StatusCode = [int]$response.StatusCode
        Headers = $response.Headers
        Content = $response.Content
        Json = $json
    }
}

function Get-HeaderValue {
    param([object]$Headers, [string]$Name)
    if (-not $Headers) { return $null }
    $value = $Headers[$Name]
    if (-not $value) { $value = $Headers[$Name.ToLowerInvariant()] }
    if ($value -is [array]) { return $value[0] }
    return $value
}

function Wait-FabricOperation {
    param(
        [Parameter(Mandatory)][string]$Location,
        [int]$TimeoutSeconds = 900,
        [int]$DelaySeconds = 10
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds $DelaySeconds
        $result = Invoke-FabricRequest -Method GET -PathOrUrl $Location
        $status = $null
        if ($result.Json) { $status = $result.Json.status }
        if ($status -in @('Succeeded','Completed')) { return $result.Json }
        if ($status -in @('Failed','Cancelled')) {
            throw "Fabric long-running operation ended with status '$status': $($result.Content)"
        }
        if (-not $status -and $result.StatusCode -in @(200,201) -and $result.Json -and $result.Json.id) {
            return $result.Json
        }
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for Fabric long-running operation: $Location"
}

function Get-FabricCollection {
    param([Parameter(Mandatory)][string]$Path)

    $items = @()
    $next = $Path
    while ($next) {
        $response = Invoke-FabricRequest -Method GET -PathOrUrl $next
        if ($response.Json -and $response.Json.value) { $items += @($response.Json.value) }

        if ($response.Json -and $response.Json.continuationUri) {
            $next = [string]$response.Json.continuationUri
        }
        elseif ($response.Json -and $response.Json.continuationToken) {
            $separator = if ($Path.Contains('?')) { '&' } else { '?' }
            $next = "$Path${separator}continuationToken=$($response.Json.continuationToken)"
        }
        else {
            $next = $null
        }
    }
    return $items
}

function Find-ByDisplayName {
    param([object[]]$Items, [Parameter(Mandatory)][string]$DisplayName)
    return @($Items | Where-Object { $_.displayName -eq $DisplayName }) | Select-Object -First 1
}

function Get-FabricProperty {
    param([object]$Object, [string[]]$Paths)
    foreach ($path in $Paths) {
        $current = $Object
        foreach ($part in $path.Split('.')) {
            if (-not $current) { break }
            $property = $current.PSObject.Properties[$part]
            if (-not $property) { $current = $null; break }
            $current = $property.Value
        }
        if ($current) { return $current }
    }
    return $null
}

function Ensure-Workspace {
    param([Parameter(Mandatory)][string]$DisplayName, [Parameter(Mandatory)][string]$CapacityId)

    $workspace = Find-ByDisplayName -Items (Get-FabricCollection -Path '/workspaces') -DisplayName $DisplayName
    if ($workspace) {
        Write-Host "Reusing workspace '$DisplayName' ($($workspace.id))."
        return $workspace
    }

    Write-Host "Creating workspace '$DisplayName' on capacity '$CapacityId'."
    $response = Invoke-FabricRequest -Method POST -PathOrUrl '/workspaces' -Body @{ displayName = $DisplayName; capacityId = $CapacityId }
    $location = Get-HeaderValue -Headers $response.Headers -Name 'Location'
    if ($location) { Wait-FabricOperation -Location $location | Out-Null }

    $workspace = Find-ByDisplayName -Items (Get-FabricCollection -Path '/workspaces') -DisplayName $DisplayName
    if (-not $workspace -and $response.Json -and $response.Json.id) { $workspace = $response.Json }
    if (-not $workspace) { throw "Workspace '$DisplayName' was not found after create." }
    return $workspace
}

function Ensure-FabricItem {
    param(
        [Parameter(Mandatory)][string]$WorkspaceId,
        [Parameter(Mandatory)][string]$KindPlural,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $collectionPath = "/workspaces/$WorkspaceId/$KindPlural"
    $item = Find-ByDisplayName -Items (Get-FabricCollection -Path $collectionPath) -DisplayName $DisplayName
    if ($item) {
        Write-Host "Reusing $KindPlural item '$DisplayName' ($($item.id))."
        return $item
    }

    Write-Host "Creating $KindPlural item '$DisplayName'."
    $response = Invoke-FabricRequest -Method POST -PathOrUrl $collectionPath -Body @{ displayName = $DisplayName }
    $location = Get-HeaderValue -Headers $response.Headers -Name 'Location'
    if ($location) { Wait-FabricOperation -Location $location | Out-Null }

    $item = Find-ByDisplayName -Items (Get-FabricCollection -Path $collectionPath) -DisplayName $DisplayName
    if (-not $item -and $response.Json -and $response.Json.id) { $item = $response.Json }
    if (-not $item) { throw "Fabric item '$DisplayName' was not found after create." }
    return $item
}

$capacity = Find-ByDisplayName -Items (Get-FabricCollection -Path '/capacities') -DisplayName $CapacityName
if (-not $capacity) { throw "Fabric capacity '$CapacityName' was not visible to the signed-in user." }
$capacityId = $capacity.id

$workspace = Ensure-Workspace -DisplayName $WorkspaceName -CapacityId $capacityId
$warehouse = Ensure-FabricItem -WorkspaceId $workspace.id -KindPlural 'warehouses' -DisplayName $WarehouseName
$lakehouse = Ensure-FabricItem -WorkspaceId $workspace.id -KindPlural 'lakehouses' -DisplayName $LakehouseName

$warehouseDetailsResponse = Invoke-FabricRequest -Method GET -PathOrUrl "/workspaces/$($workspace.id)/warehouses/$($warehouse.id)" -AllowNotFound
$lakehouseDetailsResponse = Invoke-FabricRequest -Method GET -PathOrUrl "/workspaces/$($workspace.id)/lakehouses/$($lakehouse.id)" -AllowNotFound
$warehouseDetails = if ($warehouseDetailsResponse) { $warehouseDetailsResponse.Json } else { $warehouse }
$lakehouseDetails = if ($lakehouseDetailsResponse) { $lakehouseDetailsResponse.Json } else { $lakehouse }

$warehouseSqlConnectionString = Get-FabricProperty -Object $warehouseDetails -Paths @(
    'properties.sqlEndpointProperties.connectionString',
    'properties.sqlEndpointConnectionString',
    'properties.connectionString',
    'connectionString'
)
$warehouseSqlServer = $warehouseSqlConnectionString
if ($warehouseSqlServer -and $warehouseSqlServer -notmatch '^\s*Server\s*=') {
    $warehouseSqlConnectionString = "Server=tcp:$warehouseSqlServer,1433;Initial Catalog=$WarehouseName;Encrypt=True;Trust Server Certificate=False;Connection Timeout=30;"
}
$lakehouseSqlEndpoint = Get-FabricProperty -Object $lakehouseDetails -Paths @(
    'properties.sqlEndpointProperties.connectionString',
    'properties.sqlEndpointConnectionString',
    'properties.sqlEndpointProperties.id',
    'properties.sqlEndpointId'
)
$lakehouseSqlEndpointId = Get-FabricProperty -Object $lakehouseDetails -Paths @(
    'properties.sqlEndpointProperties.id',
    'properties.sqlEndpointId'
)
$lakehouseSqlEndpointServer = Get-FabricProperty -Object $lakehouseDetails -Paths @(
    'properties.sqlEndpointProperties.connectionString',
    'properties.sqlEndpointConnectionString'
)
$lakehouseSqlEndpointConnectionString = $lakehouseSqlEndpointServer
if ($lakehouseSqlEndpointServer -and $lakehouseSqlEndpointServer -notmatch '^\s*Server\s*=') {
    $lakehouseSqlEndpointConnectionString = "Server=tcp:$lakehouseSqlEndpointServer,1433;Initial Catalog=$LakehouseName;Encrypt=True;Trust Server Certificate=False;Connection Timeout=30;"
}
$oneLakePath = "abfss://$WorkspaceName@onelake.dfs.fabric.microsoft.com/$LakehouseName.Lakehouse"

$workspaceInfo = [ordered]@{
    workspaceId = $workspace.id
    workspaceName = $WorkspaceName
    capacityId = $capacityId
    capacityName = $CapacityName
    warehouseId = $warehouse.id
    warehouseName = $WarehouseName
    warehouseSqlEndpointServer = $warehouseSqlServer
    warehouseSqlEndpointConnectionString = $warehouseSqlConnectionString
    lakehouseId = $lakehouse.id
    lakehouseName = $LakehouseName
    lakehouseSqlAnalyticsEndpoint = $lakehouseSqlEndpoint
    lakehouseSqlAnalyticsEndpointId = $lakehouseSqlEndpointId
    lakehouseSqlAnalyticsEndpointServer = $lakehouseSqlEndpointServer
    lakehouseSqlAnalyticsEndpointConnectionString = $lakehouseSqlEndpointConnectionString
    lakehouseOneLakePath = $oneLakePath
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
}

$workspaceInfo | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputPath -Encoding utf8
Write-Host "Fabric artifacts are ready. Metadata written to $OutputPath."
