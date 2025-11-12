[CmdletBinding()]
param (
    [Parameter()]
    [string] $GroupName = "jumpstart-rg",
    [Parameter()]
    [string] $Location = "eastus2",
    [Parameter()]
    [string] $vnetName = "jumpstartVNet",
    [Parameter()]
    [string] $vmName = "jumpstartVM",
    [Parameter()]
    [string] $subnetName = "jumpstartSubnet",
    [Parameter(Mandatory = $true)]
    [string] $subscription,
    [Parameter()]
    [string] $applianceName,
    [Parameter()]
    [string] $ArcLnetName,
    [Parameter()]
    [string] $aksArcClusterName,
    [Parameter()]
    [string] $customLocationName,
    [Parameter()]
    [string] $workingDir = "E:\AKSArc",
    [Parameter()]
    [string] $aksAdditionalParameters = "--generate-ssh-keys"
)

if ([string]::IsNullOrEmpty($applianceName)) {
    $applianceName = "$vmName-appliance"
} 
if ([string]::IsNullOrEmpty($customLocationName)) {
    $customLocationName = "$applianceName-cl"
}
if ([string]::IsNullOrEmpty($ArcLnetName)) {
    $ArcLnetName = "$applianceName-lnet"
}
if ([string]::IsNullOrEmpty($aksArcClusterName)) {
    $aksArcClusterName = "$vmName-aksarc"
}

# This is a continuation of jumpstart.ps1 to deploy AKS Arc specific components
# At this point, MOC is expected to be installed.

$gitSource = (git config --get remote.origin.url).Replace("github.com", "raw.githubusercontent.com").Replace("aksArc.git", "aksArc")
$branch = (git branch --show-current)
$scriptLocation = "$gitSource/refs/heads/$branch/aksarc_jumpstart/scripts"

$applianceName = "$vmName-appliance"
$scriptToExecute = [ordered] @{
    "$scriptLocation/installazmodules.ps1"      = "installazmodules.ps1 -arcHciVersion ""1.3.15""  ";
    "$scriptLocation/deployappliance.ps1"       = "deployappliance.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription"" ";
    "$scriptLocation/deployaksarcextension.ps1" = "deployaksarcextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription""";
    "$scriptLocation/deployvmssextension.ps1"   = "deployvmssextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription""";
    "$scriptLocation/deploycustomlocation.ps1"  = "deploycustomlocation.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -customLocationName ""$customLocationName"" -subscription ""$subscription""";
    "$scriptLocation/deploylnet.ps1"            = "deploylnet.ps1 -resource_group ""$GroupName""  -lnetName ""$ArcLnetName"" -customLocationName ""$customLocationName"" -location ""$Location"" -subscription ""$subscription""";
    "$scriptLocation/deployaksarccluster.ps1"   = "deployaksarccluster.ps1 -resource_group ""$GroupName"" -aksArcClusterName ""$aksArcClusterName"" -lnetName ""$ArcLnetName"" -customLocationName ""$customLocationName"" -subscription ""$subscription"" -additionalParameters ""$aksAdditionalParameters""";
}

foreach ($script in $scriptToExecute.GetEnumerator()) {
    $scriptUrl = $script.Key
    $scriptName = $script.Value

    $deploymentName = "executescript-$($vmName)-$($scriptName.Split(" ")[0].Replace('.ps1',''))"
    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $scriptName"
    Write-Host "Executing $commandToExecute  from $scriptUrl on VM $vmName ..."
    az deployment group create --name $deploymentName --resource-group $GroupName --template-file ./configuration/executescript-template.json --parameters location=$Location vmName=$vmName scriptFileUri=$scriptUrl commandToExecute=$commandToExecute # --debug
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Azure CLI command failed with exit code $LASTEXITCODE"  
        exit $LASTEXITCODE
    }
}

Write-Host ""
Write-Host "AKS Arc deployment completed successfully!"
Write-Host ""
Write-Host "Deployment Summary:"
Write-Host "  Resource Group: $GroupName"
Write-Host "  Appliance Name: $applianceName"
Write-Host "  Custom Location: $customLocationName"
Write-Host "  Logical Network: $ArcLnetName"
Write-Host "  AKS Arc Cluster: $aksArcClusterName"
Write-Host "  Additional Parameters: $aksAdditionalParameters"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "1. Verify the AKS Arc cluster is running:"
Write-Host "   az connectedk8s show --resource-group $GroupName --name $aksArcClusterName"
Write-Host ""
Write-Host "2. Get cluster credentials:"
Write-Host "   az connectedk8s proxy --resource-group $GroupName --name $aksArcClusterName"
Write-Host ""
Write-Host "3. Connect to the cluster using kubectl"
Write-Host ""
Write-Host "Setup is ready for AKS Arc workload deployment!"
