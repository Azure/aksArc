#!/bin/bash
set -euo pipefail

# Multi-Node AKS Arc Jumpstart - Phase 1
# Creates Azure VMs, shared disk, failover cluster, and installs MOC.

# --- Defaults ---
USERNAME=""
PASSWORD=""
GROUP_NAME="jumpstart-rg"
LOCATION="eastus"
SUBSCRIPTION_ID=""
NODE_COUNT=1
VM_NAME_PREFIX="jumpstartVM"
VM_SIZE="Standard_E16s_v4"
VNET_NAME="jumpstartVNet"
SUBNET_NAME="jumpstartSubnet"
LOCAL_DISK_SIZE_GB=1024
SHARED_DISK_SIZE_GB=256
AVAILABILITY_ZONE="1"
CLUSTER_NAME="jumpstart-cluster"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --username)       USERNAME="$2"; shift 2 ;;
        --password)       PASSWORD="$2"; shift 2 ;;
        --group-name)     GROUP_NAME="$2"; shift 2 ;;
        --location)       LOCATION="$2"; shift 2 ;;
        --subscription)   SUBSCRIPTION_ID="$2"; shift 2 ;;
        --node-count)     NODE_COUNT="$2"; shift 2 ;;
        --vm-name-prefix) VM_NAME_PREFIX="$2"; shift 2 ;;
        --vm-size)        VM_SIZE="$2"; shift 2 ;;
        --availability-zone) AVAILABILITY_ZONE="$2"; shift 2 ;;
        --cluster-name)   CLUSTER_NAME="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

if [[ -z "$USERNAME" || -z "$PASSWORD" || -z "$SUBSCRIPTION_ID" ]]; then
    echo "Usage: $0 --username <user> --password <pass> --subscription <sub-id> [--node-count N] [--location loc]"
    exit 1
fi

echo "=== Multi-Node AKS Arc Jumpstart ==="
echo "Nodes: $NODE_COUNT | Location: $LOCATION | VM Size: $VM_SIZE"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_SOURCE=$(git config --get remote.origin.url | sed 's|github.com|raw.githubusercontent.com|' | sed 's|aksArc.git|aksArc|')
BRANCH=$(git branch --show-current)
SCRIPT_LOCATION="$GIT_SOURCE/refs/heads/$BRANCH/aksarc_jumpstart_multinode/scripts"

# Step 1: Resource Group
echo "[1/8] Creating resource group '$GROUP_NAME'..."
az group create --name "$GROUP_NAME" --location "$LOCATION"

# Step 2: VNet
echo "[2/8] Creating virtual network..."
az deployment group create --resource-group "$GROUP_NAME" \
    --template-file "$SCRIPT_DIR/configuration/vnet-template.json" \
    --parameters vnetName="$VNET_NAME" location="$LOCATION" subnetName="$SUBNET_NAME"

# Step 3: VMs
echo "[3/8] Creating $NODE_COUNT VM(s)..."
az deployment group create --resource-group "$GROUP_NAME" \
    --template-file "$SCRIPT_DIR/configuration/vm-template.json" \
    --parameters vmNamePrefix="$VM_NAME_PREFIX" nodeCount="$NODE_COUNT" \
                 adminUsername="$USERNAME" adminPassword="$PASSWORD" \
                 location="$LOCATION" vnetName="$VNET_NAME" vmSize="$VM_SIZE" \
                 subnetName="$SUBNET_NAME" localDiskSizeGB="$LOCAL_DISK_SIZE_GB"

# Step 4: Shared disk (multi-node)
if [ "$NODE_COUNT" -gt 1 ]; then
    SHARED_DISK_NAME="$VM_NAME_PREFIX-shared-disk"
    echo "[4/8] Creating shared disk..."
    az deployment group create --resource-group "$GROUP_NAME" \
        --template-file "$SCRIPT_DIR/configuration/shared-disk-template.json" \
        --parameters diskName="$SHARED_DISK_NAME" diskSizeGB="$SHARED_DISK_SIZE_GB" \
                     maxShares="$NODE_COUNT" location="$LOCATION" availabilityZone="$AVAILABILITY_ZONE"

    echo "    Linking shared disk to VMs..."
    for i in $(seq 1 "$NODE_COUNT"); do
        CURRENT_VM="$VM_NAME_PREFIX-$i"
        echo "    Linking to $CURRENT_VM..."
        az vm disk attach --resource-group "$GROUP_NAME" --vm-name "$CURRENT_VM" --name "$SHARED_DISK_NAME" --lun 1
    done
else
    echo "[4/8] Skipping shared disk (single node)."
fi

# Step 5: Nested virtualization
echo "[5/8] Enabling nested virtualization..."
for i in $(seq 1 "$NODE_COUNT"); do
    CURRENT_VM="$VM_NAME_PREFIX-$i"
    az vm update --resource-group "$GROUP_NAME" --name "$CURRENT_VM" \
        --set additionalCapabilities.enableNestedVirtualization=true || true
done

# Step 6: Init scripts on all VMs
echo "[6/8] Running init scripts on all $NODE_COUNT VM(s)..."
INIT_SCRIPTS=(
    "initializedisk.ps1|initializedisk.ps1"
    "install-features.ps1|install-features.ps1"
    "configure-networking.ps1|configure-networking.ps1 -nodeIndex NODE_INDEX -nodeCount $NODE_COUNT"
    "install-prerequisites.ps1|install-prerequisites.ps1"
)

for i in $(seq 1 "$NODE_COUNT"); do
    CURRENT_VM="$VM_NAME_PREFIX-$i"
    echo "  --- $CURRENT_VM ---"
    for entry in "${INIT_SCRIPTS[@]}"; do
        SCRIPT_FILE="${entry%%|*}"
        SCRIPT_CMD="${entry##*|}"
        SCRIPT_CMD="${SCRIPT_CMD/NODE_INDEX/$i}"
        SCRIPT_BASE="${SCRIPT_FILE%.ps1}"
        DEPLOYMENT_NAME="init-$CURRENT_VM-$SCRIPT_BASE"
        CMD="powershell.exe -ExecutionPolicy Unrestricted -File $SCRIPT_CMD"

        echo "    Running $SCRIPT_BASE on $CURRENT_VM..."
        az deployment group create --name "$DEPLOYMENT_NAME" --resource-group "$GROUP_NAME" \
            --template-file "$SCRIPT_DIR/configuration/executescript-template.json" \
            --parameters location="$LOCATION" vmName="$CURRENT_VM" \
                         scriptFileUri="$SCRIPT_LOCATION/$SCRIPT_FILE" commandToExecute="$CMD"
    done
done

# Step 7: Clustering scripts on node 1
echo "[7/8] Running clustering scripts on $VM_NAME_PREFIX-1..."
NODE1="$VM_NAME_PREFIX-1"

CLUSTER_SCRIPTS=(
    "create-cluster.ps1|create-cluster.ps1 -nodeCount $NODE_COUNT -vmNamePrefix \"$VM_NAME_PREFIX\" -clusterName \"$CLUSTER_NAME\""
    "install-moc.ps1|install-moc.ps1 -nodeCount $NODE_COUNT -vmNamePrefix \"$VM_NAME_PREFIX\""
)

for entry in "${CLUSTER_SCRIPTS[@]}"; do
    SCRIPT_FILE="${entry%%|*}"
    SCRIPT_CMD="${entry##*|}"
    SCRIPT_BASE="${SCRIPT_FILE%.ps1}"
    DEPLOYMENT_NAME="cluster-$NODE1-$SCRIPT_BASE"
    CMD="powershell.exe -ExecutionPolicy Unrestricted -File $SCRIPT_CMD"

    echo "    Running $SCRIPT_BASE on $NODE1..."
    az deployment group create --name "$DEPLOYMENT_NAME" --resource-group "$GROUP_NAME" \
        --template-file "$SCRIPT_DIR/configuration/executescript-template.json" \
        --parameters location="$LOCATION" vmName="$NODE1" \
                     scriptFileUri="$SCRIPT_LOCATION/$SCRIPT_FILE" commandToExecute="$CMD"
done

# Step 8: Done
echo ""
echo "[8/8] Phase 1 complete!"
echo ""
echo "Next steps:"
echo "  1. Log into $NODE1 via Bastion/RDP"
echo "  2. Wait for MOC install to finish (RunOnce on boot)"
echo "  3. Run: ./deployaksarc.sh --location $LOCATION --subscription $SUBSCRIPTION_ID"
