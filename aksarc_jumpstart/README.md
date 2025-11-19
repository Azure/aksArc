# AKS enabled by Azure Arc Jump Start

## IMPORTANT NOTICE

This software is provided "AS IS", without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement.

**DO NOT** use this software in production environments. It is intended solely for testing, evaluation, and development purposes. Using this software in production may result in unexpected behavior, data loss, security vulnerabilities, or system instability.
The authors and contributors assume no liability for any damages, losses, or issues arising from the use or misuse of this software. By using this software, you agree to these terms and accept all associated risks.

## Prerequisites

Before starting the deployment, ensure you have the following prerequisites installed:

- **Azure CLI**: [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Git**: For cloning the repository
- **jq**: JSON processor (for bash scripts) - `sudo apt install jq` (Ubuntu/Debian) or `brew install jq` (macOS)
- **Valid Azure Subscription** with sufficient quotas for Standard E16s v4 VMs (16 vCPUs, 128 GiB memory)

## Script Parameters

The deployment scripts accept the following parameters:

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

## VM Specifications

The deployment creates a **Standard E16s v4** virtual machine with the following specifications:

- **vCPUs**: 16
- **Memory**: 128 GiB RAM
- **Storage**: Premium SSD (OS disk + 1TB data disk)
- **Networking**: Accelerated networking enabled
- **Features**: Nested virtualization enabled for Hyper-V support
- **OS**: Windows Server 2022 Datacenter Azure Edition
- **Network**: Public IP address with NSG (RDP, SSH, HTTPS allowed)

## Example Usage

### Bash Example (Recommended for Linux/macOS/WSL)

```bash
# Clone repository and prepare
git clone https://github.com/Azure/aksArc.git
cd aksArc/aksarc_jumpstart
az login --use-device-code

# Make bash scripts executable (required after git clone)
chmod +x jumpstart.sh deployaksarc.sh

# Deploy infrastructure with custom parameters
./jumpstart.sh \
  --username "azureuser" \
  --password "YourSecurePassword123!" \
  --subscription "12345678-1234-1234-1234-123456789012" \
  --group-name "aksarc-demo-rg" \
  --location "eastus2" \
  --vm-name "aksarc-demo-vm"

# After VM setup is complete, deploy AKS Arc components
./deployaksarc.sh \
  --subscription "12345678-1234-1234-1234-123456789012" \
  --group-name "aksarc-demo-rg" \
  --location "eastus2" \
  --vm-name "aksarc-demo-vm"
```

### PowerShell Example (Windows)

```powershell
# Clone repository and prepare
git clone https://github.com/Azure/aksArc.git
cd aksArc\aksarc_jumpstart
az login --use-device-code

# Deploy infrastructure
powershell .\jumpstart.ps1 -userName "azureuser" -password "YourSecurePassword123!" -subscription "12345678-1234-1234-1234-123456789012" -GroupName "aksarc-demo-rg" -Location "eastus2" -VMName "aksarc-demo-vm"

# Deploy AKS Arc components
powershell .\deployaksarc.ps1 -subscription "12345678-1234-1234-1234-123456789012" -GroupName "aksarc-demo-rg" -Location "eastus2" -VMName "aksarc-demo-vm"
```

## Deployment Steps

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

# Step 5: Deploy AKS Arc components
./deployaksarc.sh \
  --subscription <subscriptionid> \
  --group-name <resource-group-name> \
  --location <location> \
  --vnet-name <vnet-name> \
  --vm-name <vm-name> \
  --subnet-name <subnet-name>
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

# Step 4: Deploy AKS Arc components
powershell .\deployaksarc.ps1 -subscription <subscriptionid> -GroupName <resourcegroup> -Location <location> -vNetName <vnetname> -VMName <vmname> -subnetName <subnetname>
```

## Post-Deployment

After successful deployment, you can:

1. **Verify the AKS Arc cluster**:

   ```bash
   az connectedk8s show --resource-group <resource-group> --name <cluster-name>
   ```

2. **[OPTIONAL] Enable Microsoft Entra ID (Azure AD) with Kubernetes RBAC**:

   ```bash
   az aksarc update \
     --name <cluster-name> \
     --resource-group <resource-group> \
     --aad-admin-group-object-ids <group-object-id>
   ```

3. **Get cluster credentials**:

   ```bash
   az connectedk8s proxy --resource-group <resource-group> --name <cluster-name>
   ```

4. **Connect using kubectl** to manage your AKS Arc cluster

## Cleanup

To remove all deployed resources:

```bash
az group delete --name <groupname> --yes
```

## Troubleshooting

- **Permission Issues**: Ensure you have Contributor access to the Azure subscription
- **Quota Issues**: Verify your subscription has quota for E16s v4 VMs in the target region
- **Network Issues**: Check that the VM can access GitHub for script downloads
- **MOC Installation**: If MOC install fails, RDP to the VM and check the PowerShell logs in `$env:LogDirectory\`
