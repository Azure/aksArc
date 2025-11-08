#!/bin/bash

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --userName)
      userName="$2"
      shift 2
      ;;
    --password)
      password="$2"
      shift 2
      ;;
    --GroupName)
      GroupName="$2"
      shift 2
      ;;
    --Location)
      Location="$2"
      shift 2
      ;;
    --vnetName)
      vnetName="$2"
      shift 2
      ;;
    --vmName)
      vmName="$2"
      shift 2
      ;;
    --subnetName)
      subnetName="$2"
      shift 2
      ;;
    --subscriptionId)
      subscriptionId="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Set default values
GroupName="${GroupName:-test-rg1}"
Location="${Location:-eastus2}"
vnetName="${vnetName:-test-vnet1}"
vmName="${vmName:-test-vm1}"
subnetName="${subnetName:-test-subnet1}"

# Create Resource Group
az group create --name "$GroupName" --location "$Location"

# Create Vnet and VM
az deployment group create --resource-group "$GroupName" --template-file ./configuration/vnet-template.json --parameters vnetName="$vnetName" location="$Location" subnetName="$subnetName"
az deployment group create --resource-group "$GroupName" --template-file ./configuration/vm-template.json --parameters adminUsername="$userName" adminPassword="$password" vmName="$vmName" location="$Location" vnetName="$vnetName" vmSize="Standard_E16s_v4" subnetName="$subnetName"

if [ $? -ne 0 ]; then
  echo "Azure CLI command failed with exit code $?"
  exit $?
fi

# Assign Managed Identity and Contributor Role to VM
az vm identity assign --resource-group "$GroupName" --name "$vmName"
principalId=$(az vm show --resource-group "$GroupName" --name "$vmName" --query identity.principalId -o tsv)
az role assignment create --assignee "$principalId" --role Contributor --scope /subscriptions/"$subscriptionId"

# Enable Nested Virtualization
az vm update --resource-group "$GroupName" --name "$vmName" --set additionalCapabilities.enableNestedVirtualization=true

gitSource=$(git config --get remote.origin.url | sed 's/github.com/raw.githubusercontent.com/' | sed 's/aksArc.git/aksArc/')
branch=$(git branch --show-current)
scriptLocation="$gitSource/refs/heads/$branch/aksarc_jumpstart/scripts"

# Array of scripts to execute (in order)
declare -a scripts=(
  "initializedisk.ps1"
  "0.ps1"
  "1.ps1"
  "deployazcli.ps1"
  "deploymoc.ps1"
)

for scriptName in "${scripts[@]}"; do
  scriptUrl="$scriptLocation/$scriptName"
  deploymentName="executescript-${vmName}-${scriptName%.ps1}"
  commandToExecute="powershell.exe -ExecutionPolicy Unrestricted -File $scriptName"
  echo "Executing $scriptName from $scriptUrl on VM $vmName ..."
  az deployment group create --name "$deploymentName" --resource-group "$GroupName" --template-file ./configuration/executescript-template.json --parameters location="$Location" vmName="$vmName" scriptFileUri="$scriptUrl" commandToExecute="$commandToExecute"
  if [ $? -ne 0 ]; then
    echo "Azure CLI command failed with exit code $?"
    exit $?
  fi
done

echo "Login to the VM using Bastion or RDP. Wait for MOC install to finish. Then continue with aksarc deployment by running the script deployaksarc.ps1."
