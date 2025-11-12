# AKS Arc Jump Start

Automated deployment toolkit for AKS enabled by Azure Arc. Deploy a complete AKS Arc environment in under 30 minutes for testing and validation purposes.

> **⚠️ IMPORTANT:** This is for testing and evaluation only. **DO NOT use in production environments.**

## Overview

This toolkit creates a fully functional AKS Arc environment on Azure infrastructure, including:
- Azure VM (Standard E16s_v4: 16 vCPUs, 128 GiB RAM)
- Hyper-V with nested virtualization
- Azure Arc Appliance & MOC
- Custom Location & Logical Network
- AKS Arc Cluster

**Read the [detailed blog post](blog.md) for use cases, validation scenarios, and comprehensive guide.**

## Quick Start

### Prerequisites

- Azure subscription with E16s_v4 VM quota
- Azure CLI installed
- Git installed
- Contributor access to subscription

## Script Parameters

### jumpstart.sh / jumpstart.ps1 Parameters (Infrastructure Setup)

| Parameter        | Description           | Default Value   | Required |
| ---------------- | --------------------- | --------------- | -------- |
| `--username`     | VM admin username     | -               | ✅       |
| `--password`     | VM admin password     | -               | ✅       |
| `--subscription` | Azure subscription ID | -               | ✅       |
| `--group-name`   | Resource group name   | jumpstart-rg    | ❌       |
| `--location`     | Azure region          | eastus2         | ❌       |
| `--vnet-name`    | Virtual network name  | jumpstartVNet   | ❌       |
| `--vm-name`      | Virtual machine name  | jumpstartVM     | ❌       |
| `--subnet-name`  | Subnet name           | jumpstartSubnet | ❌       |

### deployaksarc.sh / deployaksarc.ps1 Parameters (AKS Arc Deployment)

| Parameter (Bash)      | Parameter (PowerShell)     | Description                                    | Default Value         | Required |
| --------------------- | -------------------------- | ---------------------------------------------- | --------------------- | -------- |
| `--subscription`      | `-subscription`            | Azure subscription ID                          | -                     | ✅       |
| `--group-name`        | `-GroupName`               | Resource group name                            | jumpstart-rg          | ❌       |
| `--location`          | `-Location`                | Azure region                                   | eastus2               | ❌       |
| `--vnet-name`         | `-vnetName`                | Virtual network name                           | jumpstartVNet         | ❌       |
| `--vm-name`           | `-vmName`                  | Virtual machine name                           | jumpstartVM           | ❌       |
| `--subnet-name`       | `-subnetName`              | Subnet name                                    | jumpstartSubnet       | ❌       |
| `--appliance-name`    | `-applianceName`           | Arc appliance name                             | {VM_NAME}-appliance   | ❌       |
| `--custom-location`   | `-customLocationName`      | Custom location name                           | {APPLIANCE_NAME}-cl   | ❌       |
| `--aks-cluster`       | `-aksArcClusterName`       | AKS Arc cluster name                           | {VM_NAME}-aksarc      | ❌       |
| `--aks-params`        | `-aksAdditionalParameters` | Additional parameters for `az aksarc create`   | --generate-ssh-keys   | ❌       |
| `--working-dir`       | `-workingDir`              | Working directory on VM                        | E:\AKSArc             | ❌       |

## VM Specifications

The deployment creates a **Standard E16s v4** virtual machine with the following specifications:

- **vCPUs**: 16
- **Memory**: 128 GiB RAM
- **Storage**: Premium SSD (OS disk + 1TB data disk)
- **Networking**: Accelerated networking enabled
- **Features**: Nested virtualization enabled for Hyper-V support
- **OS**: Windows Server 2022 Datacenter Azure Edition
- **Network**: Public IP address with NSG (RDP, SSH, HTTPS allowed)

## Deployment

### Option 1: Using Bash (Recommended for Linux/macOS/WSL)

```bash
# Step 1: Clone and prepare
git clone https://github.com/Azure/aksArc.git
cd aksArc/aksarc_jumpstart
az login --use-device-code

# Step 2: Make bash scripts executable
chmod +x jumpstart.sh deployaksarc.sh

# Step 3: Deploy infrastructure and initialize VM
./jumpstart.sh \
  --username <username> \
  --password <password> \
  --subscription <subscriptionid> \
  --group-name <resource-group-name> \
  --location <location> \
  --vnet-name <vnet-name> \
  --vm-name <vm-name> \
  --subnet-name <subnet-name>

# Step 4: Wait for VM initialization
# Login to the VM using RDP or Bastion.
# MOC install will start automatically in PowerShell.
# This was done because Install-Moc has to be done directly or via CredSSP.
# Wait for it to complete. It should only take 2-3 minutes.

# Step 5: Deploy AKS Arc components (basic)
./deployaksarc.sh \
  --subscription <subscriptionid> \
  --group-name <resource-group-name> \
  --location <location> \
  --vnet-name <vnet-name> \
  --vm-name <vm-name> \
  --subnet-name <subnet-name>

# OR with custom cluster name and additional parameters
./deployaksarc.sh \
  --subscription <subscriptionid> \
  --group-name <resource-group-name> \
  --aks-cluster <cluster-name> \
  --aks-params "--enable-azure-rbac --enable-workload-identity --enable-oidc-issuer --generate-ssh-keys"
```

### Option 2: Using PowerShell (Windows)

```powershell
# Step 1: Clone and prepare
git clone https://github.com/Azure/aksArc.git
cd aksArc\aksarc_jumpstart
az login --use-device-code

# Step 2: Deploy infrastructure and initialize VM
powershell .\jumpstart.ps1 -userName <username> -password <password> -subscription <subscriptionid> -GroupName <resourcegroup> -Location <location> -vNetName <vnetname> -VMName <vmname> -subnetName <subnetname>

# Step 3: Wait for VM initialization
# Login to the VM using RDP or Bastion.
# MOC install will start automatically in PowerShell.
# Wait for it to complete. It should only take 2-3 minutes.

# Step 4: Deploy AKS Arc components (basic)
powershell .\deployaksarc.ps1 -subscription <subscriptionid> -GroupName <resourcegroup> -Location <location> -vNetName <vnetname> -VMName <vmname> -subnetName <subnetname>

# OR with custom cluster name and additional parameters
powershell .\deployaksarc.ps1 -subscription <subscriptionid> -GroupName <resourcegroup> -aksArcClusterName <clustername> -aksAdditionalParameters "--enable-azure-rbac --enable-workload-identity --enable-oidc-issuer --generate-ssh-keys"
```

## Advanced Configuration

Use `--aks-params` (bash) or `-aksAdditionalParameters` (PowerShell) to customize cluster creation:

```bash
# Enable Azure RBAC and Workload Identity
./deployaksarc.sh --subscription "..." --aks-params "--enable-azure-rbac --enable-workload-identity --enable-oidc-issuer --generate-ssh-keys"
```

**Common parameters:**
- `--enable-azure-rbac` - Azure RBAC for Kubernetes
- `--enable-workload-identity` - Workload identity support
- `--enable-oidc-issuer` - OIDC issuer for workload identity
- `--node-count` - Number of nodes
- `--node-vm-size` - VM size for nodes

See [az aksarc create docs](https://learn.microsoft.com/en-us/cli/azure/aksarc) for all parameters.

## Post-Deployment

```bash
# Verify cluster
az connectedk8s show --resource-group <rg> --name <cluster>

# Get credentials
az connectedk8s proxy --resource-group <rg> --name <cluster>
```

**Optional:** Enable Microsoft Entra ID authentication:
```bash
az aksarc update --name <cluster> --resource-group <rg> --aad-admin-group-object-ids <group-id>
```

## Cleanup

To remove all deployed resources:

```bash
az group delete --name <groupname> --yes
```

## Troubleshooting

- **Permission Issues**: Ensure you have Contributor access to the Azure subscription
- **Quota Issues**: Verify your subscription has quota for E16s v4 VMs in the target region
- **Network Issues**: Check that the VM can access GitHub for script downloads
- **MOC Installation**: If MOC install fails, RDP to the VM and check the PowerShell logs in `E:\log\`
