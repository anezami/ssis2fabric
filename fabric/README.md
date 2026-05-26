# Fabric deployment draft

This folder contains draft automation for provisioning the Microsoft Fabric artifacts for the ssis2fabric demo. Do not run `deploy.ps1` until Mark approves the deployment.

## Target artifacts

- Capacity: `fabcapacitywus3`
- Workspace: `ws-ssis2fabric-demo`
- Warehouse: `wh_ssis_demo`
- Lakehouse: `lh_ssis_demo`

## Prerequisites

1. Azure CLI installed and signed in with `az login`.
2. Active account set to subscription `fb5cf409-7bc6-4446-aea6-d49b899eaa8b` if needed:
   ```powershell
   az account set --subscription fb5cf409-7bc6-4446-aea6-d49b899eaa8b
   ```
3. The signed-in user must be able to acquire a Fabric API token and must have Fabric admin, workspace-create, or equivalent permissions.
4. The signed-in user must be able to see Fabric capacity `fabcapacitywus3` through `GET https://api.fabric.microsoft.com/v1/capacities`.

## Read-only verification

A read-only capacity check was drafted/run with:

```powershell
$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
az rest --method GET --url "https://api.fabric.microsoft.com/v1/capacities" --headers "Authorization=Bearer $token"
```

The response is saved in `capacities.json` without the token.

## Deploy after approval

From the repository root:

```powershell
.\fabric\deploy.ps1
```

The script is idempotent by display name. It reuses an existing workspace, Warehouse, or Lakehouse if present, and writes `fabric\workspace.json` with discovered IDs and endpoint metadata.

## Destroy

Deleting the workspace removes child Fabric items. The script prompts for confirmation unless `-Force` is supplied:

```powershell
.\fabric\destroy.ps1
```

## Verify in Fabric portal

1. Open https://app.fabric.microsoft.com.
2. Locate workspace `ws-ssis2fabric-demo`.
3. Confirm it is assigned to capacity `fabcapacitywus3`.
4. Confirm Warehouse `wh_ssis_demo` and Lakehouse `lh_ssis_demo` exist.
5. Use the SQL endpoint values written to `fabric\workspace.json` for downstream validation.
