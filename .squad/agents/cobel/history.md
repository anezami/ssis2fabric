# Cobel's history — ssis2fabric

Owns Azure infra: RG, VM (Windows + SQL Server 2022 Dev + SSIS), networking, secrets.
User: arnezami. Subscription: fb5cf409-7bc6-4446-aea6-d49b899eaa8b. Region: westus3 (match Fabric capacity).
Auth: user's existing `az` login. Never commit secrets.

## Learnings

- 2026-05-26: Verified active Azure subscription is `fb5cf409-7bc6-4446-aea6-d49b899eaa8b` (`ME-MngEnvMCAP698191-arnezami-1`) and `rg-ssis2fabric-demo` does not yet exist.
- 2026-05-26: Drafted `infra\deploy.ps1`, `infra\destroy.ps1`, `infra\post-install.ps1`, and `infra\README.md` only; no resource-creating Azure commands were run.
- 2026-05-26: Design keeps generated VM and SQL credentials in local-only `infra\.secrets\sql-admin.json` and allows inbound RDP/SQL only from the deploy-time caller IP.
- 2026-05-26: Deployed `rg-ssis2fabric-demo` in `westus3` with VM `vm-ssis-demo` (`Standard_D2s_v5`) and SQL Server image `MicrosoftSQLServer:sql2022-ws2022:sqldev-gen2:latest`, resolved exact image version `16.0.260415` / SQL image SKU `Developer`.
- 2026-05-26: Deploy tripped on three Azure CLI compatibility issues and was fixed in place: marketplace image reported no terms to accept, `az vm create --enable-agent` emitted invalid `linuxConfiguration`, and this CLI's `az vm open-port` lacks `--source-address-prefixes`, so NSG rules are now managed directly. Existing SQL VM registrations skip unsupported auth update args.
- 2026-05-26: Post-install tripped on older `Invoke-Sqlcmd` lacking `-TrustServerCertificate`, run-command not being SQL sysadmin, and SSIS SMO constructor differences; fixed by capability-checking `Invoke-Sqlcmd`, temporarily granting `NT AUTHORITY\SYSTEM` SQL sysadmin via single-user mode, and using `SqlStoreConnection` over a .NET SQL connection.
- 2026-05-26: Post-install completed: SSIS service `MsDtsServer160` is installed/running, SQL TCP/IP is enabled on 1433, SQL auth works for local secret user `sa`, and `SSISDB` was created. Dev-box smoke test reached `20.163.102.57,1433` and returned SQL Server `16.0.4250.1` Developer Edition; `SERVERPROPERTY(''IsIntegrationServicesInstalled'')` returned null, so service + SSISDB are the practical SSIS checks.
- 2026-05-26: Cost estimate confirmed from Azure Retail Prices API for `westus3`: VM compute `Standard_D2s_v5` Windows is USD 0.188/hour; default Premium SSD P10 OS disk is USD 17.92/month plus USD 0.91/month disk mount. Auto-shutdown is configured for 19:00 local (17:00 UTC on current +02:00 offset).

## Bastion Setup — 2026-05-26

- Provisioned `AzureBastionSubnet` (`10.31.1.0/26`) in `vm-ssis-demo-vnet` (VNet space `10.31.0.0/16`, existing `default` subnet at `10.31.0.0/24`).
- Created public IP `pip-bastion-ssis` (Standard, Static, `20.169.19.6`) in westus3.
- Deployed `bastion-ssis-demo` (Standard SKU, tunneling enabled) — provisioningState: `Succeeded`.
- `az network bastion list` and `az network bastion create` both stall when the bastion CLI extension is not pre-installed; workaround: run `az config set extension.dynamic_install_allow_preview=true && az extension add --name bastion --allow-preview true` first.
- The `vm-ssis-demo-nsg` had no pre-existing Allow-RDP rule for internet (only Allow-SQL-Caller on 1433 and Allow-Tmp-8080); no NSG changes needed since RDP over public IP was already blocked.
- Connection docs written to `infra/BASTION.md`; `infra/connection.json` updated with `bastionHost` and `bastionResourceGroup`.
- Standard Bastion costs ~$0.19/hr (~$140/mo); recommend deallocating when not demoing.
