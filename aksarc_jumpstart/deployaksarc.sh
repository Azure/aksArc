#!/bin/bash

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
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
    --subscription)
      subscription="$2"
      shift 2
      ;;
    --applianceName)
      applianceName="$2"
      shift 2
      ;;
    --ArcLnetName)
      ArcLnetName="$2"
      shift 2
      ;;
    --aksArcClusterName)
      aksArcClusterName="$2"
      shift 2
      ;;
    --customLocationName)
      customLocationName="$2"
      shift 2
      ;;
    --workingDir)
      workingDir="$2"
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
workingDir="${workingDir:-E:\\AKSArc}"

# Check required parameter
if [ -z "$subscription" ]; then
  echo "Error: --subscription is required"
  exit 1
fi

# Set conditional defaults
if [ -z "$applianceName" ]; then
  applianceName="${vmName}-appliance"
fi

if [ -z "$customLocationName" ]; then
  customLocationName="${applianceName}-cl"
fi

if [ -z "$ArcLnetName" ]; then
  ArcLnetName="${applianceName}-lnet"
fi

# This is a continuation of jumpstart.sh to deploy ARB specific components
# At this point, MOC is expected to be installed.

gitSource=$(git config --get remote.origin.url | sed 's/github.com/raw.githubusercontent.com/' | sed 's/aksArc.git/aksArc/')
branch=$(git branch --show-current)
scriptLocation="$gitSource/refs/heads/$branch/aksarc_jumpstart/scripts"

# Array of scripts to execute with their parameters (in order)
declare -a scriptNames=(
  "installazmodules.ps1"
  "deployappliance.ps1"
  "deployaksarcextension.ps1"
  "deployvmssextension.ps1"
  "deploycustomlocation.ps1"
  "deploylnet.ps1"
  "deployaksarccluster.ps1"
)

declare -a scriptParams=(
  "-arcHciVersion \"1.3.15\""
  "-resource_group \"$GroupName\" -appliance_name \"$applianceName\" -workDirectory \"$workingDir\" -location \"$Location\" -subscription \"$subscription\""
  "-resource_group \"$GroupName\" -appliance_name \"$applianceName\" -workDirectory \"$workingDir\" -location \"$Location\" -subscription \"$subscription\""
  "-resource_group \"$GroupName\" -appliance_name \"$applianceName\" -workDirectory \"$workingDir\" -location \"$Location\" -subscription \"$subscription\""
  "-resource_group \"$GroupName\" -appliance_name \"$applianceName\" -customLocationName \"$customLocationName\" -subscription \"$subscription\""
  "-resource_group \"$GroupName\" -lnetName \"$ArcLnetName\" -customLocationName \"$customLocationName\" -location \"$Location\" -subscription \"$subscription\""
  "-resource_group \"$GroupName\" -aksArcClusterName \"$aksArcClusterName\" -lnetName \"$ArcLnetName\" -customLocationName \"$customLocationName\" -subscription \"$subscription\""
)

for i in "${!scriptNames[@]}"; do
  scriptName="${scriptNames[$i]}"
  scriptUrl="$scriptLocation/$scriptName"
  params="${scriptParams[$i]}"
  
  deploymentName="executescript-${vmName}-${scriptName%.ps1}"
  commandToExecute="powershell.exe -ExecutionPolicy Unrestricted -File $scriptName $params"
  echo "Executing $commandToExecute from $scriptUrl on VM $vmName ..."
  az deployment group create --name "$deploymentName" --resource-group "$GroupName" --template-file ./configuration/executescript-template.json --parameters location="$Location" vmName="$vmName" scriptFileUri="$scriptUrl" commandToExecute="$commandToExecute"
  
  if [ $? -ne 0 ]; then
    echo "Azure CLI command failed with exit code $?"
    exit $?
  fi
done

echo "Setup is ready for AKS Arc deployment"
