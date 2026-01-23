#!/bin/bash

# AKS Arc Jump Start - Main deployment script (Bash version)
# Converts aksarc_jumpstart from PowerShell to Bash

set -e  # Exit on error
set -o pipefail  # Exit on pipe failures

# Default values
GROUP_NAME="jumpstart-rg"
VNET_NAME="jumpstartVNet"
VM_NAME="jumpstartVM"
SUBNET_NAME="jumpstartSubnet"

# Valid locations
VALID_LOCATIONS=("eastus" "australiaeast")

# Initialize execution status tracking
EXECUTION_STATUS="InProgress"
SCRIPT_NAME="jumpstart.sh"
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
COMPLETED_STEPS=()
FAILED_STEP=""
ERROR_MESSAGE=""
EXIT_CODE=0

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -u, --username <username>        VM admin username (required)"
    echo "  -p, --password <password>        VM admin password (required)"
    echo "  -s, --subscription <id>          Azure subscription ID (required)"
    echo "  -l, --location <location>        Azure region (required, valid values: eastus, australiaeast)"
    echo "  -g, --group-name <name>          Resource group name (default: $GROUP_NAME)"
    echo "  -v, --vnet-name <name>           Virtual network name (default: $VNET_NAME)"
    echo "  -m, --vm-name <name>             Virtual machine name (default: $VM_NAME)"
    echo "  -n, --subnet-name <name>         Subnet name (default: $SUBNET_NAME)"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -u myuser -p mypassword -s 12345678-1234-1234-1234-123456789012 -l eastus"
    exit 1
}

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to print execution status
print_execution_status() {
    local end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo ""
    echo "===== EXECUTION STATUS ====="
    echo "Status: $EXECUTION_STATUS"
    if [[ "$EXECUTION_STATUS" == "Failure" ]]; then
        echo "Failed Step: $FAILED_STEP"
        echo "Error Message: $ERROR_MESSAGE"
    fi
    echo "Exit Code: $EXIT_CODE"
    echo "Completed Steps: ${COMPLETED_STEPS[*]}"
    echo "Start Time: $START_TIME"
    echo "End Time: $end_time"
    echo "============================"
}

# Function to handle errors
handle_error() {
    local step_name="$1"
    local error_msg="$2"
    local exit_code="${3:-1}"
    
    EXECUTION_STATUS="Failure"
    FAILED_STEP="$step_name"
    ERROR_MESSAGE="$error_msg"
    EXIT_CODE="$exit_code"
    
    print_execution_status
    exit "$exit_code"
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
        echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    if ! command_exists git; then
        echo "Error: git is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists jq; then
        echo "Error: jq is not installed. Please install it first."
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
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
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
if [[ -z "$USERNAME" || -z "$PASSWORD" || -z "$SUBSCRIPTION_ID" || -z "$LOCATION" ]]; then
    echo "Error: Missing required parameters"
    usage
fi

# Validate location parameter
valid_location=false
for loc in "${VALID_LOCATIONS[@]}"; do
    if [[ "$LOCATION" == "$loc" ]]; then
        valid_location=true
        break
    fi
done

if [[ "$valid_location" == false ]]; then
    echo "Error: Invalid location '$LOCATION'. Valid values are: ${VALID_LOCATIONS[*]}"
    exit 1
fi

# Validate prerequisites
validate_prerequisites
check_azure_login

log "Starting AKS Arc Jump Start deployment..."
log "Configuration:"
log "  Resource Group: $GROUP_NAME"
log "  Location: $LOCATION"
log "  VM Name: $VM_NAME"
log "  VNet Name: $VNET_NAME"
log "  Subnet Name: $SUBNET_NAME"
log "  Subscription ID: $SUBSCRIPTION_ID"

# Set the subscription context
log "Setting Azure subscription context..."
az account set --subscription "$SUBSCRIPTION_ID"
if [[ $? -ne 0 ]]; then
    handle_error "SetSubscription" "Failed to set subscription context to '$SUBSCRIPTION_ID'"
fi

# Create Resource Group
log "Creating resource group '$GROUP_NAME' in '$LOCATION'..."
az group create --name "$GROUP_NAME" --location "$LOCATION"
if [[ $? -ne 0 ]]; then
    handle_error "CreateResourceGroup" "Failed to create resource group '$GROUP_NAME' in location '$LOCATION'"
fi
COMPLETED_STEPS+=("CreateResourceGroup")

# Check for required template files
VNET_TEMPLATE="./configuration/vnet-template.json"
VM_TEMPLATE="./configuration/vm-template.json"
EXEC_TEMPLATE="./configuration/executescript-template.json"

if [[ ! -f "$VNET_TEMPLATE" ]]; then
    echo "Error: VNet template not found: $VNET_TEMPLATE"
    echo "Please ensure all required ARM templates are present in the configuration directory"
    exit 1
fi

if [[ ! -f "$VM_TEMPLATE" ]]; then
    echo "Error: VM template not found: $VM_TEMPLATE"
    echo "Please ensure all required ARM templates are present in the configuration directory"
    exit 1
fi

if [[ ! -f "$EXEC_TEMPLATE" ]]; then
    echo "Error: Execute script template not found: $EXEC_TEMPLATE"
    echo "Please ensure all required ARM templates are present in the configuration directory"
    exit 1
fi

# Create Virtual Network and Subnet
log "Creating virtual network and subnet..."
az deployment group create \
    --name "vnet-deployment-$(date +%s)" \
    --resource-group "$GROUP_NAME" \
    --template-file "$VNET_TEMPLATE" \
    --parameters vnetName="$VNET_NAME" location="$LOCATION" subnetName="$SUBNET_NAME"
if [[ $? -ne 0 ]]; then
    handle_error "CreateVirtualNetwork" "Failed to create virtual network '$VNET_NAME' and subnet '$SUBNET_NAME'"
fi
COMPLETED_STEPS+=("CreateVirtualNetwork")

# Create Virtual Machine
log "Creating virtual machine..."
az deployment group create \
    --name "vm-deployment-$(date +%s)" \
    --resource-group "$GROUP_NAME" \
    --template-file "$VM_TEMPLATE" \
    --parameters \
        adminUsername="$USERNAME" \
        adminPassword="$PASSWORD" \
        vmName="$VM_NAME" \
        location="$LOCATION" \
        vnetName="$VNET_NAME" \
        vmSize="Standard_E16s_v4" \
        subnetName="$SUBNET_NAME"
if [[ $? -ne 0 ]]; then
    handle_error "CreateVirtualMachine" "Failed to create virtual machine '$VM_NAME'"
fi
COMPLETED_STEPS+=("CreateVirtualMachine")

# Assign Managed Identity and Contributor Role to VM
log "Assigning managed identity to VM..."
az vm identity assign --resource-group "$GROUP_NAME" --name "$VM_NAME"
if [[ $? -ne 0 ]]; then
    handle_error "AssignManagedIdentity" "Failed to assign managed identity to VM '$VM_NAME'"
fi
COMPLETED_STEPS+=("AssignManagedIdentity")

log "Getting VM principal ID..."
PRINCIPAL_ID=$(az vm show --resource-group "$GROUP_NAME" --name "$VM_NAME" --query identity.principalId -o tsv)
if [[ -z "$PRINCIPAL_ID" ]]; then
    handle_error "GetPrincipalId" "Failed to get VM principal ID for '$VM_NAME'"
fi

log "Assigning Contributor role to VM identity..."
az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role Contributor \
    --scope "/subscriptions/$SUBSCRIPTION_ID"
if [[ $? -ne 0 ]]; then
    handle_error "AssignContributorRole" "Failed to assign Contributor role to VM identity"
fi
COMPLETED_STEPS+=("AssignContributorRole")

# Enable Nested Virtualization
log "Enabling nested virtualization on VM..."
az vm update \
    --resource-group "$GROUP_NAME" \
    --name "$VM_NAME" \
    --set "additionalCapabilities.enableNestedVirtualization=true"
if [[ $? -ne 0 ]]; then
    handle_error "EnableNestedVirtualization" "Failed to enable nested virtualization on VM '$VM_NAME'"
fi
COMPLETED_STEPS+=("EnableNestedVirtualization")

# Get git repository information
log "Getting git repository information..."
GIT_SOURCE=$(git config --get remote.origin.url | sed 's/github.com/raw.githubusercontent.com/' | sed 's/aksArc.git/aksArc/')
BRANCH=$(git branch --show-current)
SCRIPT_LOCATION="$GIT_SOURCE/refs/heads/$BRANCH/aksarc_jumpstart/scripts"

log "Script location: $SCRIPT_LOCATION"

# Define scripts to execute in order
SCRIPTS_TO_EXECUTE=(
    "initializedisk.ps1"
    "0.ps1"
    "1.ps1"
    "deployazcli.ps1"
    "deploymoc.ps1"
)

# Execute scripts on VM
log "Executing initialization scripts on VM..."
for script_name in "${SCRIPTS_TO_EXECUTE[@]}"; do
    script_url="$SCRIPT_LOCATION/$script_name"
    deployment_name="executescript-${VM_NAME}-${script_name%.*}"
    command_to_execute="powershell.exe -ExecutionPolicy Unrestricted -File $script_name"
    
    log "Executing $script_name from $script_url on VM $VM_NAME..."
    
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
        handle_error "ExecuteScript_$script_name" "Failed to execute script '$script_name' on VM '$VM_NAME'"
    fi
    COMPLETED_STEPS+=("ExecuteScript_$script_name")
done

log "Jump start deployment completed successfully!"
log ""
log "Next steps:"
log "1. Login to the VM using Bastion or RDP"
log "2. Wait for MOC install to finish (should take 2-3 minutes)"
log "3. Run the AKS Arc deployment script:"
log "   ./deployaksarc.sh -s $SUBSCRIPTION_ID -g $GROUP_NAME -l $LOCATION -v $VNET_NAME -m $VM_NAME -n $SUBNET_NAME"
log ""
log "VM Connection Details:"
log "  Resource Group: $GROUP_NAME"
log "  VM Name: $VM_NAME"
log "  Location: $LOCATION"

# Final execution status - Success
EXECUTION_STATUS="Success"
print_execution_status
