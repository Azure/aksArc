#!/bin/bash

# AKS Arc Deployment Script - Bash version
# This is a continuation of jumpstart.sh to deploy AKS Arc specific components
# At this point, MOC is expected to be installed on the VM

set -e  # Exit on error
set -o pipefail  # Exit on pipe failures

# Default values
GROUP_NAME="jumpstart-rg"
LOCATION="eastus2"
VNET_NAME="jumpstartVNet"
VM_NAME="jumpstartVM"
SUBNET_NAME="jumpstartSubnet"
WORKING_DIR="E:\\AKSArc"

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -s, --subscription <id>          Azure subscription ID (required)"
    echo "  -g, --group-name <name>          Resource group name (default: $GROUP_NAME)"
    echo "  -l, --location <location>        Azure region (default: $LOCATION)"
    echo "  -v, --vnet-name <name>           Virtual network name (default: $VNET_NAME)"
    echo "  -m, --vm-name <name>             Virtual machine name (default: $VM_NAME)"
    echo "  -n, --subnet-name <name>         Subnet name (default: $SUBNET_NAME)"
    echo "  -a, --appliance-name <name>      Appliance name (default: \${VM_NAME}-appliance)"
    echo "  -c, --custom-location <name>     Custom location name (default: \${APPLIANCE_NAME}-cl)"
    echo "  -k, --aks-cluster <name>         AKS Arc cluster name (default: generated)"
    echo "  -w, --working-dir <path>         Working directory (default: $WORKING_DIR)"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -s 12345678-1234-1234-1234-123456789012 -g my-rg -l eastus2"
    exit 1
}

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate required tools
validate_prerequisites() {
    log "Validating prerequisites..."
    
    if ! command_exists az; then
        echo "Error: Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists git; then
        echo "Error: git is not installed. Please install it first."
        exit 1
    fi
    
    log "All prerequisites validated successfully"
}

# Function to check Azure CLI login status
check_azure_login() {
    log "Checking Azure CLI login status..."
    if ! az account show >/dev/null 2>&1; then
        log "Not logged into Azure CLI. Please login first:"
        echo "  az login"
        exit 1
    fi
    log "Azure CLI login verified"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -g|--group-name)
            GROUP_NAME="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -v|--vnet-name)
            VNET_NAME="$2"
            shift 2
            ;;
        -m|--vm-name)
            VM_NAME="$2"
            shift 2
            ;;
        -n|--subnet-name)
            SUBNET_NAME="$2"
            shift 2
            ;;
        -a|--appliance-name)
            APPLIANCE_NAME="$2"
            shift 2
            ;;
        -c|--custom-location)
            CUSTOM_LOCATION_NAME="$2"
            shift 2
            ;;
        -k|--aks-cluster)
            AKS_ARC_CLUSTER_NAME="$2"
            shift 2
            ;;
        -w|--working-dir)
            WORKING_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    echo "Error: Subscription ID is required"
    usage
fi

# Set default derived values
if [[ -z "$APPLIANCE_NAME" ]]; then
    APPLIANCE_NAME="${VM_NAME}-appliance"
fi

if [[ -z "$CUSTOM_LOCATION_NAME" ]]; then
    CUSTOM_LOCATION_NAME="${APPLIANCE_NAME}-cl"
fi

if [[ -z "$ARC_LNET_NAME" ]]; then
    ARC_LNET_NAME="${APPLIANCE_NAME}-lnet"
fi

if [[ -z "$AKS_ARC_CLUSTER_NAME" ]]; then
    AKS_ARC_CLUSTER_NAME="${VM_NAME}-aksarc"
fi

# Validate prerequisites
validate_prerequisites
check_azure_login

log "Starting AKS Arc deployment..."
log "Configuration:"
log "  Resource Group: $GROUP_NAME"
log "  Location: $LOCATION"
log "  VM Name: $VM_NAME"
log "  Appliance Name: $APPLIANCE_NAME"
log "  Custom Location: $CUSTOM_LOCATION_NAME"
log "  ARC Logical Network: $ARC_LNET_NAME"
log "  AKS Arc Cluster: $AKS_ARC_CLUSTER_NAME"
log "  Working Directory: $WORKING_DIR"
log "  Subscription ID: $SUBSCRIPTION_ID"

# Set the subscription context
log "Setting Azure subscription context..."
az account set --subscription "$SUBSCRIPTION_ID"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to set subscription context"
    exit 1
fi

# Get git repository information
log "Getting git repository information..."
GIT_SOURCE=$(git config --get remote.origin.url | sed 's/github.com/raw.githubusercontent.com/' | sed 's/aksArc.git/aksArc/')
BRANCH=$(git branch --show-current)
SCRIPT_LOCATION="$GIT_SOURCE/refs/heads/$BRANCH/aksarc_jumpstart/scripts"

log "Script location: $SCRIPT_LOCATION"

# Check for required template file
EXEC_TEMPLATE="./configuration/executescript-template.json"
if [[ ! -f "$EXEC_TEMPLATE" ]]; then
    echo "Error: Execute script template not found: $EXEC_TEMPLATE"
    echo "Please ensure all required ARM templates are present in the configuration directory"
    exit 1
fi

# Execute deployment scripts on VM in sequence
log "Executing AKS Arc deployment scripts on VM..."

# Define script execution order and details
execute_script() {
    local script_name="$1"
    local script_params="$2"
    local script_url="${SCRIPT_LOCATION}/${script_name}"
    local deployment_name="executescript-${VM_NAME}-${script_name%.*}"
    local command_to_execute="powershell.exe -ExecutionPolicy Unrestricted -File ${script_name} ${script_params}"
    
    log "Executing ${script_name%.*} from $script_url on VM $VM_NAME..."
    
    az deployment group create \
        --name "$deployment_name" \
        --resource-group "$GROUP_NAME" \
        --template-file "$EXEC_TEMPLATE" \
        --parameters \
            location="$LOCATION" \
            vmName="$VM_NAME" \
            scriptFileUri="$script_url" \
            commandToExecute="$command_to_execute"
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to execute script ${script_name%.*}"
        echo "This may be due to:"
        echo "  - MOC not being properly installed"
        echo "  - Network connectivity issues"
        echo "  - Azure resource quota limitations"
        echo "  - Previous deployment steps not completed"
        exit 1
    fi
    
    log "Successfully completed: ${script_name%.*}"
}

# Execute scripts in the required order
execute_script "installazmodules.ps1" "-arcHciVersion \"1.3.15\""

execute_script "deployappliance.ps1" "-resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION_ID\""

execute_script "deployaksarcextension.ps1" "-resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION_ID\""

execute_script "deployvmssextension.ps1" "-resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION_ID\""
execute_script "deploycustomlocation.ps1" "-resource_group \"$GROUP_NAME\" -appliance_name \"$APPLIANCE_NAME\" -customLocationName \"$CUSTOM_LOCATION_NAME\" -subscription \"$SUBSCRIPTION_ID\""

execute_script "deploylnet.ps1" "-resource_group \"$GROUP_NAME\" -lnetName \"$ARC_LNET_NAME\" -customLocationName \"$CUSTOM_LOCATION_NAME\" -location \"$LOCATION\" -subscription \"$SUBSCRIPTION_ID\""

execute_script "deployaksarccluster.ps1" "-resource_group \"$GROUP_NAME\" -aksArcClusterName \"$AKS_ARC_CLUSTER_NAME\" -lnetName \"$ARC_LNET_NAME\" -customLocationName \"$CUSTOM_LOCATION_NAME\" -subscription \"$SUBSCRIPTION_ID\""

log "AKS Arc deployment completed successfully!"
log ""
log "Deployment Summary:"
log "  Resource Group: $GROUP_NAME"
log "  Appliance Name: $APPLIANCE_NAME"
log "  Custom Location: $CUSTOM_LOCATION_NAME"
log "  Logical Network: $ARC_LNET_NAME"
log "  AKS Arc Cluster: $AKS_ARC_CLUSTER_NAME"
log ""
log "Next Steps:"
log "1. Verify the AKS Arc cluster is running:"
log "   az connectedk8s show --resource-group $GROUP_NAME --name $AKS_ARC_CLUSTER_NAME"
log ""
log "2. [OPTIONAL] Enable Microsoft Entra ID (Azure AD) with Kubernetes RBAC:"
log "   az aksarc update --name $AKS_ARC_CLUSTER_NAME --resource-group $GROUP_NAME --aad-admin-group-object-ids <group-object-id>"
log ""
log "3. Get cluster credentials:"
log "   az connectedk8s proxy --resource-group $GROUP_NAME --name $AKS_ARC_CLUSTER_NAME"
log ""
log "4. Connect to the cluster using kubectl"
log ""
log "Setup is ready for AKS Arc workload deployment!"
