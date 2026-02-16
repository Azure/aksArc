#!/bin/bash
set -euo pipefail

# Multi-Node AKS Arc Jumpstart - Phase 2 (AKS Arc Deployment)
# Runs deployment scripts on the primary VM (node 1).

# --- Defaults ---
GROUP_NAME="jumpstart-rg"
LOCATION="eastus"
VM_NAME_PREFIX="jumpstartVM"
SUBSCRIPTION=""
APPLIANCE_NAME=""
CUSTOM_LOCATION_NAME=""
ARC_LNET_NAME=""
AKS_ARC_CLUSTER_NAME=""
ARC_HCI_VERSION="1.3.15"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --group-name)      GROUP_NAME="$2"; shift 2 ;;
        --location)        LOCATION="$2"; shift 2 ;;
        --vm-name-prefix)  VM_NAME_PREFIX="$2"; shift 2 ;;
        --subscription)    SUBSCRIPTION="$2"; shift 2 ;;
        --appliance-name)  APPLIANCE_NAME="$2"; shift 2 ;;
        --arc-hci-version) ARC_HCI_VERSION="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

if [[ -z "$SUBSCRIPTION" ]]; then
    echo "Usage: $0 --subscription <sub-id> --location <loc> [--node-count N]"
    exit 1
fi

PRIMARY_VM="$VM_NAME_PREFIX-1"

if [[ -z "$APPLIANCE_NAME" ]]; then APPLIANCE_NAME="$VM_NAME_PREFIX-appliance"; fi
if [[ -z "$CUSTOM_LOCATION_NAME" ]]; then CUSTOM_LOCATION_NAME="$APPLIANCE_NAME-cl"; fi
if [[ -z "$ARC_LNET_NAME" ]]; then ARC_LNET_NAME="$APPLIANCE_NAME-lnet"; fi
if [[ -z "$AKS_ARC_CLUSTER_NAME" ]]; then AKS_ARC_CLUSTER_NAME="$APPLIANCE_NAME-aksarc"; fi

echo "=== Multi-Node AKS Arc Deployment (Phase 2) ==="
echo "Primary VM: $PRIMARY_VM | Location: $LOCATION"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_SOURCE=$(git config --get remote.origin.url | sed 's|github.com|raw.githubusercontent.com|' | sed 's|aksArc.git|aksArc|')
BRANCH=$(git branch --show-current)
SCRIPT_LOCATION="$GIT_SOURCE/refs/heads/$BRANCH/aksarc_jumpstart_multinode/scripts"

SCRIPTS=(
    "installazmodules.ps1|installazmodules.ps1 -arcHciVersion \"$ARC_HCI_VERSION\""
    "deployappliance.ps1|deployappliance.ps1 -resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION\""
    "deployaksarcextension.ps1|deployaksarcextension.ps1 -resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION\""
    "deployvmssextension.ps1|deployvmssextension.ps1 -resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION\""
    "deploycustomlocation.ps1|deploycustomlocation.ps1 -resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -customLocationName \"$CUSTOM_LOCATION_NAME\" -subscription \"$SUBSCRIPTION\""
    "deploylnet.ps1|deploylnet.ps1 -resource_group \"$GROUP_NAME\" -lnetName \"$ARC_LNET_NAME\" -customLocationName \"$CUSTOM_LOCATION_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION\""
    "deployaksarccluster.ps1|deployaksarccluster.ps1 -resource_group \"$GROUP_NAME\" -aksArcClusterName \"$AKS_ARC_CLUSTER_NAME\" -lnetName \"$ARC_LNET_NAME\" -customLocationName \"$CUSTOM_LOCATION_NAME\" -subscription \"$SUBSCRIPTION\""
)

STEP=1
TOTAL=${#SCRIPTS[@]}

for entry in "${SCRIPTS[@]}"; do
    SCRIPT_FILE="${entry%%|*}"
    SCRIPT_CMD="${entry##*|}"
    SCRIPT_BASE="${SCRIPT_FILE%.ps1}"
    DEPLOYMENT_NAME="deploy-$PRIMARY_VM-$SCRIPT_BASE"
    CMD="powershell.exe -ExecutionPolicy Unrestricted -File $SCRIPT_CMD"

    echo "[$STEP/$TOTAL] Running $SCRIPT_BASE on $PRIMARY_VM..."
    az deployment group create --name "$DEPLOYMENT_NAME" --resource-group "$GROUP_NAME" \
        --template-file "$SCRIPT_DIR/configuration/executescript-template.json" \
        --parameters location="$LOCATION" vmName="$PRIMARY_VM" \
                     scriptFileUri="$SCRIPT_LOCATION/$SCRIPT_FILE" commandToExecute="$CMD"
    STEP=$((STEP + 1))
done

echo ""
echo "=== Phase 2 complete! ==="
echo "AKS Arc cluster '$AKS_ARC_CLUSTER_NAME' is ready."
