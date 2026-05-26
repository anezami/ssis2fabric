[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SubscriptionId = "fb5cf409-7bc6-4446-aea6-d49b899eaa8b",
    [string]$ResourceGroupName = "rg-ssis2fabric-demo"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$account = az account show -o json | ConvertFrom-Json
if ($account.id -ne $SubscriptionId) {
    Write-Host "Switching Azure subscription from $($account.id) to $SubscriptionId"
    az account set --subscription $SubscriptionId
}

$exists = (az group exists --name $ResourceGroupName --output tsv).Trim()
if ($exists -ne "true") {
    Write-Host "Resource group $ResourceGroupName does not exist. Nothing to destroy."
    return
}

$confirmation = Read-Host "Delete resource group '$ResourceGroupName' and all contained resources? Type DELETE to continue"
if ($confirmation -ne "DELETE") {
    Write-Host "Destroy cancelled."
    return
}

az group delete --name $ResourceGroupName --yes --no-wait
Write-Host "Deletion started for $ResourceGroupName."
