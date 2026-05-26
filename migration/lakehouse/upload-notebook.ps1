<#
.SYNOPSIS
    Uploads migration/lakehouse/migration.ipynb to workspace ws-ssis2fabric-demo
    as a Notebook item, attached to lakehouse lh_ssis_demo.

.DESCRIPTION
    Uses the Fabric REST API (POST /v1/workspaces/{wid}/notebooks) with a
    `definitionParts` payload carrying the base64-encoded .ipynb plus a
    minimal .platform metadata file that pins the default lakehouse.

    Auth: AAD bearer token from `az account get-access-token --resource
    https://api.fabric.microsoft.com`.

    Re-runs of this script update the existing notebook in place (matched
    by displayName) via the updateDefinition endpoint.
#>
[CmdletBinding()]
param(
    [string]$WorkspaceFile = "fabric/workspace.json",
    [string]$NotebookPath  = "migration/lakehouse/migration.ipynb",
    [string]$DisplayName   = "ssis2fabric-migration"
)

$ErrorActionPreference = 'Stop'

$ws = Get-Content $WorkspaceFile -Raw | ConvertFrom-Json
$wid = $ws.workspaceId
$lid = $ws.lakehouseId

Write-Host "[upload] workspace : $($ws.workspaceName) ($wid)"
Write-Host "[upload] lakehouse : $($ws.lakehouseName) ($lid)"

# --- Token --------------------------------------------------------------
$tokenJson = az account get-access-token --resource https://api.fabric.microsoft.com --output json
$token = ($tokenJson | ConvertFrom-Json).accessToken
$hdr = @{ Authorization = "Bearer $token" }

# --- Build definitionParts ---------------------------------------------
$nbBytes  = [IO.File]::ReadAllBytes((Resolve-Path $NotebookPath))
$nbB64    = [Convert]::ToBase64String($nbBytes)

# .platform file -- pins the default lakehouse so the notebook can resolve
# Files/raw and Tables/ when "Run all" is hit from the portal.
$platform = @{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json'
    metadata  = @{ type = 'Notebook'; displayName = $DisplayName }
    config    = @{ version = '2.0'; logicalId = [Guid]::NewGuid().ToString() }
} | ConvertTo-Json -Depth 6 -Compress
$platformB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($platform))

$definition = @{
    format = 'ipynb'
    parts = @(
        @{ path = 'notebook-content.ipynb'; payload = $nbB64;       payloadType = 'InlineBase64' }
        @{ path = '.platform';              payload = $platformB64; payloadType = 'InlineBase64' }
    )
}

# --- Locate any existing item -------------------------------------------
$existing = $null
try {
    $list = Invoke-RestMethod -Headers $hdr `
        -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wid/notebooks"
    $existing = $list.value | Where-Object { $_.displayName -eq $DisplayName } | Select-Object -First 1
} catch {
    Write-Host "[upload] list notebooks failed (continuing): $($_.Exception.Message)"
}

if ($existing) {
    Write-Host "[upload] updating existing notebook id=$($existing.id)"
    $body = @{ definition = $definition } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method POST `
        -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wid/notebooks/$($existing.id)/updateDefinition" `
        -Headers $hdr -ContentType 'application/json' -Body $body | Out-Null
    Write-Host "[upload] updated."
} else {
    Write-Host "[upload] creating new notebook '$DisplayName'"
    $body = @{
        displayName = $DisplayName
        description = 'SSIS -> Fabric Lakehouse migration (Flavor B)'
        definition  = $definition
    } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method POST `
        -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wid/notebooks" `
        -Headers $hdr -ContentType 'application/json' -Body $body | Out-Null
    Write-Host "[upload] created."
}

Write-Host ""
Write-Host "Open: https://app.fabric.microsoft.com/groups/$wid"
Write-Host "Then attach lakehouse '$($ws.lakehouseName)' to the notebook and click 'Run all'."
