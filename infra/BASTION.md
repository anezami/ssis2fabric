# Azure Bastion — VM Connection Guide

**Bastion Host:** `bastion-ssis-demo`  
**Resource Group:** `rg-ssis2fabric-demo`  
**SKU:** Standard (native client + tunneling enabled)  
**Provisioned:** 2026-05-26  
**Bastion Public IP:** `20.169.19.6` (`pip-bastion-ssis`)  
**AzureBastionSubnet:** `10.31.1.0/26` in `vm-ssis-demo-vnet`

---

## 1. Azure Portal Flow

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Virtual Machines → vm-ssis-demo**
3. Click **Connect → Bastion**
4. Enter:
   - **Username:** `sqladmin`
   - **Password:** *(see `infra/.secrets/sql-admin.json`)*
5. Click **Connect** — a native RDP session opens in the browser.

**Direct Bastion connect URL:**  
`https://portal.azure.com/#resource/subscriptions/fb5cf409-7bc6-4446-aea6-d49b899eaa8b/resourceGroups/rg-ssis2fabric-demo/providers/Microsoft.Compute/virtualMachines/vm-ssis-demo/bastionHost`

---

## 2. Native Client (az CLI) — Recommended for Developers

Requires: Azure CLI + bastion extension (`az extension add --name bastion --allow-preview true`)  
**Windows only** — launches native mstsc.exe RDP session.

```bash
az network bastion rdp \
  --name bastion-ssis-demo \
  --resource-group rg-ssis2fabric-demo \
  --target-resource-id /subscriptions/fb5cf409-7bc6-4446-aea6-d49b899eaa8b/resourceGroups/rg-ssis2fabric-demo/providers/Microsoft.Compute/virtualMachines/vm-ssis-demo
```

You will be prompted for credentials — use `sqladmin` and password from `infra/.secrets/sql-admin.json`.

---

## 3. NSG — Public RDP Status

The `vm-ssis-demo-nsg` has **no explicit Allow rule for port 3389 from the internet** — RDP over public IP (`20.163.102.57`) is already blocked by the NSG default-deny policy.

If you ever want to explicitly add a deny rule as a documented safeguard:

```bash
az network nsg rule create \
  -g rg-ssis2fabric-demo \
  --nsg-name vm-ssis-demo-nsg \
  -n Deny-RDP-Internet \
  --priority 900 \
  --access Deny \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes Internet \
  --destination-port-ranges 3389
```

> **Do not run this unless required** — Bastion already provides secure access without exposing port 3389.

---

## 4. Cost Note

| Component | Rate |
|---|---|
| Bastion Standard | ~$0.19/hr (~$140/mo) |
| `pip-bastion-ssis` public IP | ~$0.005/hr |

**Recommendations:**
- **Deallocate Bastion when not demoing** to avoid idle charges.
- If native client (mstsc) is not needed, downgrade to **Basic SKU** (~$0.19/hr base, no tunneling) — same cost but you lose the CLI native RDP flow.
- To deallocate: `az network bastion delete -g rg-ssis2fabric-demo -n bastion-ssis-demo`
- To recreate quickly, re-run `infra/deploy.ps1` or the bastion create command above.
