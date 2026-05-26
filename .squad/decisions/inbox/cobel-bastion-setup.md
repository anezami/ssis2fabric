# Decision: Bastion Setup for vm-ssis-demo

**Date:** 2026-05-26  
**Agent:** Cobel (Azure Infra)  
**Status:** Implemented

## Context

The VM `vm-ssis-demo` was accessible over public RDP (port 3389) via `20.163.102.57`. While the NSG already scoped SQL access to the caller IP, RDP was not explicitly restricted. The team wanted a more secure access path.

## Decision

Deploy **Azure Bastion (Standard SKU)** into the existing VNet to provide browser-based and native-client RDP without exposing port 3389 to the internet.

## What Was Built

| Resource | Value |
|---|---|
| Bastion Host | `bastion-ssis-demo` |
| SKU | Standard (tunneling enabled) |
| Subnet | `AzureBastionSubnet` `10.31.1.0/26` |
| Public IP | `pip-bastion-ssis` (`20.169.19.6`) |
| Status | `Succeeded` |

## Alternatives Considered

- **Basic SKU Bastion** — cheaper but no native client / CLI RDP tunneling; rejected because dev workflow benefits from mstsc integration.
- **Keep public RDP** — simpler but exposes attack surface; rejected in favour of Bastion.
- **Just-in-time (JIT) VM access** — requires Defender for Cloud; overkill for demo environment.

## NSG Impact

No changes required. `vm-ssis-demo-nsg` had no pre-existing Allow-RDP rule from the internet — port 3389 was already blocked by NSG default-deny. An explicit Deny rule can be added optionally (command documented in `infra/BASTION.md`).

## Cost Impact

Standard Bastion adds ~$0.19/hr (~$140/mo). Recommendation: deallocate Bastion when not actively demoing.

## Files Changed

- `infra/BASTION.md` — created (connection guide, cost note)
- `infra/connection.json` — appended `bastionHost`, `bastionResourceGroup`, `bastionSubnet`, `bastionPublicIp`, `bastionProvisionedUtc`
- `.squad/agents/cobel/history.md` — updated with learnings
