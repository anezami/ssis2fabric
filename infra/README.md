# SSIS to Fabric demo infrastructure

Draft Azure VM infrastructure for the SSIS to Fabric demo. Do not deploy until Mark approves.

## Prerequisites

- Azure CLI signed in with access to subscription `fb5cf409-7bc6-4446-aea6-d49b899eaa8b`
- PowerShell 7+ or Windows PowerShell
- Permission to create resources in `westus3`

## Deploy

From the repository root:

```powershell
.\infra\deploy.ps1
```

The script:

- verifies or switches the active Azure subscription
- detects your current public IP with `https://api.ipify.org`
- stores generated local credentials in `infra\.secrets\sql-admin.json`
- creates resource group `rg-ssis2fabric-demo`
- creates VM `vm-ssis-demo` with SQL Server 2022 Developer on Windows Server 2022
- restricts RDP `3389` and SQL `1433` NSG access to your detected public IP only
- writes non-secret connection metadata to `infra\connection.json`

After the VM is provisioned, run the post-install script on the VM:

```powershell
$secret = Get-Content .\infra\.secrets\sql-admin.json -Raw | ConvertFrom-Json
az vm run-command invoke `
  --resource-group rg-ssis2fabric-demo `
  --name vm-ssis-demo `
  --command-id RunPowerShellScript `
  --scripts "@infra\post-install.ps1" `
  --parameters "SqlAdminPassword=$($secret.sqlAdminPassword)"
```

## Connect

Open `infra\connection.json` for the public IP and DNS name. Retrieve passwords from the local-only secret file:

```powershell
Get-Content .\infra\.secrets\sql-admin.json -Raw | ConvertFrom-Json
```

- RDP user: `localadmin`
- SQL user: `sa`
- SQL endpoint: `<dns-or-public-ip>,1433`

## Destroy

```powershell
.\infra\destroy.ps1
```

Type `DELETE` when prompted. This deletes the full resource group.

## Cost reminder

`Standard_D4s_v5` is roughly `$0.20/hour` for compute in West US 3, about `$5/day`, before storage and public IP costs. Destroy the resource group after the demo.
