[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SubscriptionId = "fb5cf409-7bc6-4446-aea6-d49b899eaa8b",
    [string]$Location = "westus3",
    [string]$ResourceGroupName = "rg-ssis2fabric-demo",
    [string]$VmName = "vm-ssis-demo",
    [string]$VmSize = "Standard_D2s_v5",
    [string]$Image = "MicrosoftSQLServer:sql2022-ws2022:sqldev-gen2:latest"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$InfraRoot = Split-Path -Parent $PSCommandPath
$SecretsDir = Join-Path $InfraRoot ".secrets"
$SecretFile = Join-Path $SecretsDir "sql-admin.json"
$ConnectionFile = Join-Path $InfraRoot "connection.json"

function Invoke-AzJson {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $output = & az @Arguments -o json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "az $(Format-AzCommand $Arguments) failed: $(Format-AzOutput $output)"
    }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }
    $jsonText = ($output | Out-String).Trim()
    $objectStart = $jsonText.IndexOf("{")
    $arrayStart = $jsonText.IndexOf("[")
    $starts = @($objectStart, $arrayStart) | Where-Object { $_ -ge 0 }
    if (-not $starts) {
        throw "az $(Format-AzCommand $Arguments) did not return JSON: $output"
    }
    $jsonText = $jsonText.Substring(($starts | Measure-Object -Minimum).Minimum)
    return $jsonText | ConvertFrom-Json
}

function Invoke-AzText {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $output = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "az $(Format-AzCommand $Arguments) failed: $(Format-AzOutput $output)"
    }
    return $output
}

function Format-AzCommand {
    param([string[]]$Arguments)

    $secretValueFlags = @("--admin-password", "--sql-auth-update-pwd", "--password")
    $safe = for ($i = 0; $i -lt $Arguments.Count; $i++) {
        if ($secretValueFlags -contains $Arguments[$i]) {
            $Arguments[$i]
            if ($i + 1 -lt $Arguments.Count) {
                "<redacted>"
                $i++
            }
        } else {
            $Arguments[$i]
        }
    }
    return ($safe -join " ")
}

function Format-AzOutput {
    param($Output)

    $text = ($Output | Out-String)
    return ($text -replace "(--(?:admin-password|sql-auth-update-pwd|password)\s+)\S+", '$1<redacted>')
}

function New-StrongPassword {
    $upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $lower = "abcdefghijkmnopqrstuvwxyz"
    $digits = "23456789"
    $symbols = "!#$%&*-_=+?"
    $upperChars = $upper.ToCharArray()
    $lowerChars = $lower.ToCharArray()
    $digitChars = $digits.ToCharArray()
    $symbolChars = $symbols.ToCharArray()
    $all = ($upper + $lower + $digits + $symbols).ToCharArray()
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    function Get-RandomChar([char[]]$Chars) {
        $bytes = [byte[]]::new(4)
        $rng.GetBytes($bytes)
        $index = [BitConverter]::ToUInt32($bytes, 0) % $Chars.Length
        return $Chars[$index]
    }

    $chars = @(
        (Get-RandomChar $upperChars)
        (Get-RandomChar $lowerChars)
        (Get-RandomChar $digitChars)
        (Get-RandomChar $symbolChars)
    )
    for ($i = $chars.Count; $i -lt 28; $i++) {
        $chars += Get-RandomChar $all
    }
    $rng.Dispose()
    return -join ($chars | Sort-Object { Get-Random })
}

function Set-NsgInboundRule {
    param(
        [Parameter(Mandatory = $true)][string]$ResourceGroupName,
        [Parameter(Mandatory = $true)][string]$NsgName,
        [Parameter(Mandatory = $true)][string]$RuleName,
        [Parameter(Mandatory = $true)][string]$Port,
        [Parameter(Mandatory = $true)][int]$Priority,
        [Parameter(Mandatory = $true)][string]$SourceCidr
    )

    $commonArgs = @(
        "--resource-group", $ResourceGroupName,
        "--nsg-name", $NsgName,
        "--name", $RuleName,
        "--priority", "$Priority",
        "--source-address-prefixes", $SourceCidr,
        "--source-port-ranges", "*",
        "--destination-address-prefixes", "*",
        "--destination-port-ranges", $Port,
        "--access", "Allow",
        "--protocol", "Tcp",
        "--direction", "Inbound"
    )

    & az network nsg rule show --resource-group $ResourceGroupName --nsg-name $NsgName --name $RuleName -o none 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Invoke-AzText @(@("network", "nsg", "rule", "update") + $commonArgs) | Out-Null
    } else {
        Invoke-AzText @(@("network", "nsg", "rule", "create") + $commonArgs) | Out-Null
    }
}

function Get-OrCreateSecrets {
    if (-not (Test-Path $SecretsDir)) {
        New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
    }

    if (Test-Path $SecretFile) {
        return Get-Content $SecretFile -Raw | ConvertFrom-Json
    }

    $secrets = [ordered]@{
        vmAdminUser     = "localadmin"
        vmAdminPassword = New-StrongPassword
        sqlAdminUser    = "sa"
        sqlAdminPassword = New-StrongPassword
        createdUtc      = (Get-Date).ToUniversalTime().ToString("o")
    }
    $secrets | ConvertTo-Json | Set-Content -Path $SecretFile -Encoding UTF8
    Write-Host "Created local secret file: $SecretFile"
    return [pscustomobject]$secrets
}

function Ensure-AzSubscription {
    $account = Invoke-AzJson @("account", "show")
    if ($account.id -ne $SubscriptionId) {
        Write-Host "Switching Azure subscription from $($account.id) to $SubscriptionId"
        Invoke-AzText @("account", "set", "--subscription", $SubscriptionId) | Out-Null
        $account = Invoke-AzJson @("account", "show")
    }
    if ($account.id -ne $SubscriptionId) {
        throw "Active subscription is $($account.id), expected $SubscriptionId."
    }
    Write-Host "Using Azure subscription $($account.name) ($($account.id))"
}

Ensure-AzSubscription

$callerIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 30).Trim()
if ($callerIp -notmatch "^\d{1,3}(\.\d{1,3}){3}$") {
    throw "Could not detect a valid IPv4 caller IP. Detected: $callerIp"
}
$callerCidr = "$callerIp/32"
Write-Host "Restricting RDP and SQL access to $callerCidr"

$secrets = Get-OrCreateSecrets

$vnetName = "$VmName-vnet"
$subnetName = "default"
$nsgName = "$VmName-nsg"
$pipName = "$VmName-pip"
$nicName = "$VmName-nic"
$dnsSuffix = ($SubscriptionId.Split("-")[0]).ToLowerInvariant()
$dnsLabel = "ssis2fabric-demo-$dnsSuffix"

if ((Invoke-AzText @("group", "exists", "--name", $ResourceGroupName, "--output", "tsv")).Trim() -ne "true") {
    Invoke-AzJson @("group", "create", "--name", $ResourceGroupName, "--location", $Location) | Out-Null
}

Invoke-AzText @("network", "nsg", "create", "--resource-group", $ResourceGroupName, "--name", $nsgName, "--location", $Location) | Out-Null

Invoke-AzText @("network", "vnet", "create", "--resource-group", $ResourceGroupName, "--location", $Location, "--name", $vnetName, "--address-prefixes", "10.31.0.0/16", "--subnet-name", $subnetName, "--subnet-prefixes", "10.31.0.0/24") | Out-Null
Invoke-AzText @("network", "public-ip", "create", "--resource-group", $ResourceGroupName, "--location", $Location, "--name", $pipName, "--sku", "Standard", "--allocation-method", "Static", "--dns-name", $dnsLabel) | Out-Null
Invoke-AzText @("network", "nic", "create", "--resource-group", $ResourceGroupName, "--location", $Location, "--name", $nicName, "--vnet-name", $vnetName, "--subnet", $subnetName, "--network-security-group", $nsgName, "--public-ip-address", $pipName) | Out-Null

& az vm show --resource-group $ResourceGroupName --name $VmName -o none 2>$null | Out-Null
$vmExists = ($LASTEXITCODE -eq 0)
if (-not $vmExists) {
    $termsOutput = & az vm image terms accept --urn $Image 2>&1
    if ($LASTEXITCODE -ne 0 -and ($termsOutput -join "`n") -notmatch "has no terms to accept") {
        throw "az vm image terms accept --urn $Image failed: $termsOutput"
    }
    Invoke-AzJson @(
        "vm", "create",
        "--resource-group", $ResourceGroupName,
        "--name", $VmName,
        "--location", $Location,
        "--size", $VmSize,
        "--image", $Image,
        "--nics", $nicName,
        "--admin-username", $secrets.vmAdminUser,
        "--admin-password", $secrets.vmAdminPassword,
        "--authentication-type", "password"
    ) | Out-Null
} else {
    Write-Host "VM $VmName already exists; skipping VM creation."
}

Set-NsgInboundRule -ResourceGroupName $ResourceGroupName -NsgName $nsgName -RuleName "Allow-RDP-Caller" -Port "3389" -Priority 1000 -SourceCidr $callerCidr
Set-NsgInboundRule -ResourceGroupName $ResourceGroupName -NsgName $nsgName -RuleName "Allow-SQL-Caller" -Port "1433" -Priority 1010 -SourceCidr $callerCidr

$shutdownHour = 19
$shutdownMinute = 0
$shutdownLocal = Get-Date -Hour $shutdownHour -Minute $shutdownMinute -Second 0
$shutdownUtc = $shutdownLocal.ToUniversalTime().ToString("HHmm")
Invoke-AzText @("vm", "auto-shutdown", "--resource-group", $ResourceGroupName, "--name", $VmName, "--time", $shutdownUtc) | Out-Null

& az sql vm show --resource-group $ResourceGroupName --name $VmName -o none 2>$null | Out-Null
$sqlVmExists = ($LASTEXITCODE -eq 0)
if ($sqlVmExists) {
    Write-Host "SQL VM registration already exists; skipping SQL auth update."
} else {
    Invoke-AzText @(
        "sql", "vm", "create",
        "--resource-group", $ResourceGroupName,
        "--name", $VmName,
        "--location", $Location,
        "--license-type", "PAYG",
        "--sql-mgmt-type", "Full",
        "--sql-auth-update-username", $secrets.sqlAdminUser,
        "--sql-auth-update-pwd", $secrets.sqlAdminPassword
    ) | Out-Null
}

$pip = Invoke-AzJson @("network", "public-ip", "show", "--resource-group", $ResourceGroupName, "--name", $pipName)
$connection = [ordered]@{
    resourceGroup = $ResourceGroupName
    location = $Location
    vmName = $VmName
    publicIp = $pip.ipAddress
    dns = $pip.dnsSettings.fqdn
    rdpPort = 3389
    sqlPort = 1433
    sqlAdminUser = $secrets.sqlAdminUser
    secretFile = ".secrets/sql-admin.json"
    allowedSource = $callerCidr
    generatedUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$connection | ConvertTo-Json | Set-Content -Path $ConnectionFile -Encoding UTF8
Write-Host "Wrote connection metadata to $ConnectionFile"
