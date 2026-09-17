#!/bin/bash
#
# Copyright (c) Microsoft Corporation.
#
# This script will
#   1.  Configure host machine to download from packages.microsoft.com
#   2.  Install Azcmagent package
#   3.  Configure for proxy operation (if specified on the command line)
#   4.  Connect the Arc enabled Server to Azure if not already connected
#   5.  Provision AKS everywhere cluster
# Note that this script is for Linux only

set -e
export subscriptionId="";
export tenantId="";
export resourceGroup="";
export location="eastus";
export authType="token";
export cloud="AzureCloud";

# Function to display usage information
usage() {
    echo "Usage: $0 [-s <subscription-id> -t <tenant-id>]"
    echo "  -s <subscription-id>     Specify the subscription to use"
    echo "  -t <tenant-id>     Specify the tenant ID to use"
    echo "  -h                    Display this help message"
	echo "Example1: curl -sSL https://aka.ms/aksbm | bash -s -- -s subscription-id -t tenant-id"
	echo "Example2: wget https://aka.ms/aksbm -O aksbm.sh; ./aksbm.sh -s subscription-id -t tenant-id"
}

goto() {
    label=$1
    # Finds the line with your label, extracts everything after it, and runs it
    cmd=$(sed -n "/^:${label}/{:a;n;p;ba};" "$0")
    eval "$cmd"
    exit
}
if [ $# -eq 0 ]; then
   echo "### Error: No arguments provided"
   usage
   exit 1
fi

# Parse command line arguments
while getopts "s:t:h" opt; do
    case ${opt} in
        s )
            export subscriptionId=$OPTARG
            ;;
        t )
            export tenantId=$OPTARG
            ;;
        h )
            usage
            exit 0
            ;;

        * )
            usage
	    exit 1
            ;;
    esac
done

if [[ -n "$subscriptionId" && -n "$tenantId" ]]; then
    echo "### Using subscription: $subscriptionId and tenant: $tenantId"
else
    echo "Subscription ID and Tenant ID must be provided"
    usage
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo "### Error: Azure CLI (az) is not installed."
    echo "### Downloading and installing Azure CLI"
    curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash
#    echo "Please install it by visiting: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
fi

echo "### Azure CLI is installed. Logging in to Azure using the subscription and tenant id"
if ! az account show &> /dev/null; then
		echo "### Logging into Azure with device code flow using subscription $subscriptionId and tenantid $tenantId."
		echo "### Device code flow needs exception https://eng.ms/docs/microsoft-security/ciso-organization/iamprotect/enterprise-iam/productivity-environment/tsgs/devicecodeflowdcfrestrictions"
        az login -s "$subscriptionId" -t "$tenantId"
fi
# Check if Azure CLI is logged in without printing output to the terminal
if az account show &> /dev/null; then
    echo "### Azure login is active and successful using following context."
    az account show
else
    echo "### Error: Not logged in. Please run 'az login'."
    exit 1
fi

if ! command -v azcmagent &> /dev/null; then
    echo "### Error: Azure Connected Machine agent (azcmagent) is not installed."
    echo "### Downloading and installing Azure Connected Machine agent"
    echo "Download the installation package."
    LINUX_INSTALL_SCRIPT="/tmp/install_linux_azcmagent.sh"
    if [ -f "$LINUX_INSTALL_SCRIPT" ]; then rm -f "$LINUX_INSTALL_SCRIPT"; fi;
    output=$(wget https://gbl.his.arc.azure.com/azcmagent-linux -O "$LINUX_INSTALL_SCRIPT" 2>&1);
    if [ $? != 0 ]; then wget -qO- --method=PUT --body-data="{\"subscriptionId\":\"$subscriptionId\",\"resourceGroup\":\"$resourceGroup\",\"tenantId\":\"$tenantId\",\"location\":\"$location\",\"authType\":\"$authType\",\"operation\":\"onboarding\",\"messageType\":\"DownloadScriptFailed\",\"message\":\"$output\"}" "https://gbl.his.arc.azure.com/log" &> /dev/null || true; fi;
    echo "$output";
    echo "Install the Arc enabled Server hybrid agent"
    bash "$LINUX_INSTALL_SCRIPT";
    sleep 5;
    export resourceGroup="$(hostname)-rg"
else
    while IFS=':' read -r field1 field2; do
     if [[ "$field1" == "Resource Group Name                     " ]]; then
        echo "## Resource Group Name = $field2";
        export resourceGroup="${field2:1}";
     fi 
    done < <(azcmagent show)
    if [[ "$resourceGroup" == "" ]]; then
        export resourceGroup="$(hostname)-rg"
        echo "## Resource Group Name = $resourceGroup";
    fi
fi

if ! command -v azcmagent show &> /dev/null; then
    echo "### Running Arc enabled Server connect to Azure command with resourceGroup=$resourceGroup, subscription=$subscriptionId, tenantId=$tenantId, location=$location"
    sudo azcmagent connect --resource-group "$resourceGroup" --tenant-id "$tenantId" --location "$location" --subscription-id "$subscriptionId" --cloud "$cloud" --enable-automatic-upgrade;
else
    export agentStatus="";
    while IFS=':' read -r field1 field2; do
     if [[ "$field1" == "Agent Status                            " ]]; then
        echo "## Agent Status = $field2";
        export agentStatus="${field2:1}";
     fi 
    done < <(azcmagent show)

    if [[ "$agentStatus" != "Connected" ]]; then
        echo "### Running Arc enabled Server connect to Azure command with resourceGroup=$resourceGroup, subscription=$subscriptionId, tenantId=$tenantId, location=$location"
        sudo azcmagent connect --resource-group "$resourceGroup" --tenant-id "$tenantId" --location "$location" --subscription-id "$subscriptionId" --cloud "$cloud" --enable-automatic-upgrade;
    fi
fi
echo "### Show Arc enabled Server Azure ARM resource"
azcmagent show

echo "### Register resource provided necessary for the AKS bare metal preview"
az feature register --subscription "$subscriptionId" --namespace Microsoft.HybridConnectivity --name hiddenPreviewAccess 
az provider register --namespace Microsoft.HybridCompute
az provider register --namespace Microsoft.HybridContainerService
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.ExtendedLocation
az provider register --namespace Microsoft.HybridConnectivity
az provider register --namespace Microsoft.AzureStackHCI

echo "### Add Azure Arc CLI extensions"
az extension add --name connectedk8s
az extension add --name connectedmachine

echo "### Upgrading AKS Arc CLI extension"
az extension add --name aksarc --upgrade
az extension show --name aksarc --query version -o tsv

echo "### Provision AKS bare metal cluster with resourceGroup=$resourceGroup, and arcMachineName=$(hostname)"
az aksarc deploy -g "$resourceGroup" --arc-machine-names $(hostname) -y

echo "### Show AKS bare metal resource properties and provisioning status"
export clusterName="$(hostname)-cluster"
# az aksarc show -g "$resourceGroup" -n "$clusterName"
az aksarc show -g "$resourceGroup" -n "$clusterName"  --query "properties.provisioningState" -o tsv 

echo "### Successfully created AKS bare metal cluster in Azure resourceGroup=$resourceGroup, clusterName=$clusterName, subscriptionId=$subscriptionId, tenantId=$tenantId"
