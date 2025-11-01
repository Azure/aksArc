$GroupName = "madhanm-test1"
$Location = "eastus2"
$username = "myuser"
$password = "MySecurePassword123!"
$vnetName = "madhanm-vnet1"
$vmName = "madhanm-vm1"
$subscriptionId = "0709bd7a-8383-4e1d-98c8-f81d1b3443fc"
$tenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47"

az group create --name $GroupName --location $Location 

az deployment group create --resource-group $GroupName --template-file .\configuration\vnet-template.json --parameters vnetName=$vnetName location=$Location
az deployment group create --resource-group $GroupName --template-file .\configuration\vm-template.json --parameters adminUsername=$username adminPassword=$password vmName=$vmName location=$Location vnetName=$vnetName


#az deployment group create --resource-group $GroupName --template-file a4s-template.json --parameters location=$Location vmName=$vmName arcResourceGroup=$GroupName subscriptionId=$subscriptionId tenantId=$tenantId
az vm update   --resource-group $GroupName   --name $vmName --set additionalCapabilities.enableNestedVirtualization=true
az deployment group create --resource-group $GroupName --template-file .\configuration\execute-template.json --parameters location=$Location vmName=$vmName commandToExecute="powershell.exe -Command 'Add-WindowsFeature -name Hyper-V  -IncludeAllSubFeature -IncludeManagementTools -Restart' "
az deployment group create --resource-group $GroupName --template-file .\configuration\execute-template.json --parameters location=$Location vmName=$vmName commandToExecute="powershell.exe -ExecutionPolicy Unrestricted -Command 'Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -NoNewWindow -Wait; Remove-Item .\AzureCLI.msi' "

ExecuteScriptOnVm .\bootstrap.ps1 $GroupName $Location $vmName
ExecuteScriptOnVm .\bootstrap.ps1 $GroupName $Location $vmName

function ExecuteScriptOnVm($scriptPath, $GroupName, $Location, $vmName) {
  $commandsToExecute = Get-Content $scriptPath
  foreach ($command in $commandsToExecute) 
  {
    Write-Host "Executing command: $command"
    if ($command.StartsWith("#") -or [string]::IsNullOrWhiteSpace($command)) 
    {
      continue
    }
    az deployment group create --resource-group $GroupName --template-file .\configuration\execute-template.json --parameters location=$Location vmName=$vmName commandToExecute="powershell.exe -ExecutionPolicy Unrestricted -Command '$command' "
  }

}
# Deploy MOC & ARB
