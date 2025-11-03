[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $userName,
    [Parameter()]
    [string]
    $password,
    [Parameter()]
    [string]
    $GroupName = "test-rg1",
    [Parameter()]
    [string]
    $Location = "eastus2",
    [Parameter()]
    [string]
    $vnetName = "test-vnet1",
    [Parameter()]
    [string]
    $vmName = "test-vm1",
    [Parameter()]
    [string]
    $subnetName = "test-subnet1",
    [Parameter()]
    [string]
    $subscription,
    [Parameter()]
    [string]
    $workingDir = "E:\AKSArc"
)
# This is a continuation of jumpstart.ps1 to deploy ARB specific components
# At this point, MOC is expected to be installed.

$gitSource = (git config --get remote.origin.url).Replace("github.com","raw.githubusercontent.com").Replace("aksArc.git","aksArc")
$scriptLocation = "$gitSource/refs/heads/jumpStart/aksarc_jumpstart"
$applianceName = "$vmName-appliance"
$scriptToExecute = [ordered] @{
  "$scriptLocation/installazmodules.ps1" = "installazmodules.ps1 -arcHciVersion ""1.3.15""  ";
  "$scriptLocation/deployappliance.ps1" = "deployappliance.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription"" ";
  "$scriptLocation/deployaksarcextension.ps1" = "deployaksarcextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription""";
  # "$scriptLocation/deployvmssextension.ps1" = "deployvmssextension.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription""";
  "$scriptLocation/deploycustomlocation.ps1" = "deploycustomlocation.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription""";
  #"$scriptLocation/deploylnet.ps1" = "deploylnet.ps1 -resource_group ""$GroupName"" -appliance_name ""$applianceName"" -workDirectory ""$workingDir"" -location ""$Location"" -subscription ""$subscription""";
}

foreach ($script in $scriptToExecute.GetEnumerator()) {
    $scriptUrl = $script.Key
    $scriptName = $script.Value

    $deploymentName = "executescript-$($vmName)-$($scriptName.Split(" ")[0].Replace('.ps1',''))"
    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $scriptName"
    Write-Host "Executing $commandToExecute  from $scriptUrl on VM $vmName ..."
    az deployment group create --name $deploymentName --resource-group $GroupName --template-file .\configuration\executescript-template.json --parameters location=$Location vmName=$vmName scriptFileUri=$scriptUrl commandToExecute=$commandToExecute # --debug
    if ($LASTEXITCODE -ne 0) {
      Write-Host "Azure CLI command failed with exit code $LASTEXITCODE"  
      exit $LASTEXITCODE
    }
}

Write-Host "Setup is ready for AKS Arc deployment"