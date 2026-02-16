# Multi-Node AKS Arc Jumpstart

Deploy a multi-node AKS Arc environment on Azure VMs with failover clustering — simulating an Azure Local (HCI) setup for development and testing.

## Architecture

```
Azure VNet (10.0.0.0/16)
├── Subnet (10.0.0.0/24)
│   ├── jumpstartVM-1 ─┐
│   ├── jumpstartVM-2 ─┤── Shared Disk (Premium SSD v2)
│   └── jumpstartVM-N ─┘
│
│   Inside each VM:
│   ├── Hyper-V + Failover Clustering
│   ├── DNS + DHCP (node 1 only)
│   └── InternalNAT switch (172.16.0.0/16)
│
│   Failover Cluster (AD-less):
│   ├── Shared disk witness
│   ├── MOC (multi-node)
│   ├── Arc Resource Bridge
│   └── AKS Arc cluster
```

## Prerequisites

- Azure subscription with Contributor access
- Azure CLI installed locally
- Git (scripts are fetched from this repository)
- Sufficient quota for `Standard_E16s_v4` VMs (or chosen size)
- For multi-node: region + zone that supports Premium SSD v2 shared disks

## Quick Start

### Single Node (default)

```powershell
.\jumpstart.ps1 -userName "adminuser" -password "YourP@ssw0rd!" `
    -Location eastus -subscriptionId "your-sub-id"
```

### Multi-Node (2 nodes)

```powershell
.\jumpstart.ps1 -userName "adminuser" -password "YourP@ssw0rd!" `
    -Location eastus -subscriptionId "your-sub-id" -nodeCount 2
```

### Bash

```bash
./jumpstart.sh --username adminuser --password 'YourP@ssw0rd!' \
    --location eastus --subscription your-sub-id --node-count 2
```

### Phase 2: Deploy AKS Arc

After Phase 1 completes and MOC is installed (RunOnce on first boot):

```powershell
.\deployaksarc.ps1 -Location eastus -subscription "your-sub-id"
```

## Parameters

### jumpstart.ps1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-userName` | (required) | VM admin username |
| `-password` | (required) | VM admin password |
| `-Location` | eastus | Azure region |
| `-subscriptionId` | (required) | Azure subscription ID |
| `-nodeCount` | 1 | Number of VMs (1-4) |
| `-vmNamePrefix` | jumpstartVM | VM name prefix (VMs named prefix-1, prefix-2, ...) |
| `-vmSize` | Standard_E16s_v4 | Azure VM size |
| `-GroupName` | jumpstart-rg | Resource group name |
| `-localDiskSizeGB` | 1024 | Local data disk size per VM |
| `-sharedDiskSizeGB` | 256 | Shared disk size (multi-node only) |
| `-availabilityZone` | 1 | AZ for shared disk |
| `-clusterName` | jumpstart-cluster | Failover cluster name |

### deployaksarc.ps1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Location` | (required) | Azure region |
| `-subscription` | (required) | Azure subscription ID |
| `-GroupName` | jumpstart-rg | Resource group name |
| `-vmNamePrefix` | jumpstartVM | VM name prefix |
| `-arcHciVersion` | 1.3.15 | ArcHci module version |

## Deployment Flow

### Phase 1: Infrastructure (`jumpstart.ps1`)

1. Create resource group and VNet
2. Deploy N Azure VMs with nested virtualization
3. Create + link shared disk (multi-node only)
4. Run on each VM: initialize disk → install features → configure networking → install prerequisites
5. Run on node 1: create AD-less failover cluster → stage MOC install (RunOnce)

### Phase 2: AKS Arc (`deployaksarc.ps1`)

1. Install ArcHci module + register providers
2. Deploy Arc Resource Bridge (appliance)
3. Install AKS Arc + VMSS extensions
4. Create custom location
5. Create logical network
6. Create AKS Arc cluster

## Key Design Decisions

- **AD-less clustering**: Uses `-AdministrativeAccessPoint DNS` — no domain controller needed
- **Shared disk witness**: Self-contained quorum, no cloud witness dependency
- **DNS/DHCP on node 1 only**: Other nodes use node 1 as DNS server
- **Premium SSD v2**: Supports multi-attach (`maxShares`) for shared disk
- **Single node works too**: Always creates a cluster, even with 1 node

## Troubleshooting

### Logs

Inside each VM, logs are at: `E:\AKSArc\log\`

| Log File | Description |
|----------|-------------|
| `install-features.ps1.log` | Windows feature installation |
| `configure-networking.ps1.log` | Network/DNS/DHCP setup |
| `install-prerequisites.ps1.log` | Azure CLI, MOC, firewall |
| `create-cluster.ps1.log` | Failover cluster creation |
| `install-moc.ps1.log` | MOC staging |
| `InstallMocStack.log` | MOC actual install (RunOnce) |
| `deployappliance.ps1.log` | Arc Resource Bridge |

### Common Issues

- **Shared disk not available**: Ensure region supports Premium SSD v2 shared disks in your chosen AZ
- **Cluster creation fails**: Check that all nodes can reach each other (same VNet/subnet)
- **MOC install stuck**: Check `InstallMocStack.log` — CredSSP issues require local session
- **Nested virt not enabled**: VM size must support nested virtualization

## Cleanup

```bash
az group delete --name jumpstart-rg --yes --no-wait
```
