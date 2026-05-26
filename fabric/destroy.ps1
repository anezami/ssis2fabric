<#
.SYNOPSIS
Deletes the Fabric demo workspace and all child items.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$ApiBase = "https://api.fabric.microsoft.com/v1",
    [string]$WorkspaceName = "ws-ssis2fabric-demo",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

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
        [Parameter(Mandatory)][ValidateSet('GET','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$PathOrUrl
    )

    try {
        $response = Invoke-WebRequest -Method $Method -Uri (Resolve-FabricUrl $PathOrUrl) -Headers @{ Authorization = "Bearer $script:FabricToken" }
    }
    catch {
        $message = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $message = $_.ErrorDetails.Message }
        throw "Fabric REST $Method $PathOrUrl failed: $message"
    }

    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        try { $json = $response.Content | ConvertFrom-Json } catch { $json = $null }
    }

    [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Headers = $response.Headers; Content = $response.Content; Json = $json }
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
    param([Parameter(Mandatory)][string]$Location)
    $deadline = (Get-Date).AddMinutes(15)
    do {
        Start-Sleep -Seconds 10
        $result = Invoke-FabricRequest -Method GET -PathOrUrl $Location
        $status = if ($result.Json) { $result.Json.status } else { $null }
        if ($status -in @('Succeeded','Completed')) { return }
        if ($status -in @('Failed','Cancelled')) { throw "Delete operation ended with status '$status': $($result.Content)" }
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for delete operation: $Location"
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

$workspace = @(Get-FabricCollection -Path '/workspaces' | Where-Object { $_.displayName -eq $WorkspaceName }) | Select-Object -First 1
if (-not $workspace) {
    Write-Host "Workspace '$WorkspaceName' was not found. Nothing to delete."
    return
}

if (-not $Force) {
    $confirmation = Read-Host "Type '$WorkspaceName' to permanently delete this workspace and all child items"
    if ($confirmation -ne $WorkspaceName) { throw "Confirmation did not match. Delete cancelled." }
}

if ($PSCmdlet.ShouldProcess($WorkspaceName, 'Delete Fabric workspace')) {
    $deleteResponse = Invoke-FabricRequest -Method DELETE -PathOrUrl "/workspaces/$($workspace.id)"
    $location = Get-HeaderValue -Headers $deleteResponse.Headers -Name 'Location'
    if ($location) { Wait-FabricOperation -Location $location }
    Write-Host "Deleted workspace '$WorkspaceName' ($($workspace.id))."
}
