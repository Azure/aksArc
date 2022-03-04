# Running the demo
>> NOTE: The instructions are a mixture of PS and AZ CLI commands, you run all of these from a PS ISE such as PS ISE in Windows or VS Code. They are split between PS and CLI because the InfraAdmin will be the individual who sets up the infra layers (server, connection to Azure and dependent componets). The end user (e.g. dev) will then use AZ CLI to create AKS clusters on HCI via Azure.

# Register for the preview!
You will need to register your interest to get access to the docs and have your subscription enabled for this private preview, please register [here (https://aka.ms/arcAksHciPriPreview).

## Register for features and providers
You can run the following commands on your laptop/devbox using Az PS. You can download Az PS [here](https://docs.microsoft.com/powershell/azure/install-az-ps?view=azps-7.3.0)

```PowerShell
Connect-AzAccount -TenantId <enter your Azure tenant ID>
Get-AzSubscription
$subscriptionID = "<enter your Azure subscription ID which has been enabled for this preview>"
Set-AzContext -Subscription $subscriptionID
```

```PowerShell
# register for features
Register-AzProviderFeature -FeatureName Appliances-ppauto -ProviderNamespace Microsoft.ResourceConnector 
Register-AzProviderFeature -FeatureName hiddenPreviewAccess -ProviderNamespace Microsoft.HybridContainerService
Register-AzProviderFeature -FeatureName hiddenPreviewAccess -ProviderNamespace Microsoft.HybridConnectivity

# Check feature registrationState == Registered
Get-AzProviderFeature -ProviderNamespace Microsoft.ResourceConnector | Select-Object -Property ProviderNamespace, Locations, RegistrationState
Get-AzProviderFeature -ProviderNamespace Microsoft.HybridContainerService | Select-Object -Property ProviderNamespace, Locations, RegistrationState
Get-AzProviderFeature -ProviderNamespace Microsoft.HybridConnectivity | Select-Object -Property ProviderNamespace, Locations, RegistrationState

# register for providers
Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration
Register-AzResourceProvider -ProviderNamespace Microsoft.ExtendedLocation
Register-AzResourceProvider -ProviderNamespace Microsoft.ResourceConnector
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridContainerService
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity

# Check provider registrationState == Registered
Get-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes | Select-Object -Property ProviderNamespace, Locations, RegistrationState
Get-AzResourceProvider -ProviderNamespace Microsoft.ExtendedLocation | Select-Object -Property ProviderNamespace, Locations, RegistrationState
Get-AzResourceProvider -ProviderNamespace Microsoft.ResourceConnector | Select-Object -Property ProviderNamespace, Locations, RegistrationState
Get-AzResourceProvider -ProviderNamespace Microsoft.HybridContainerService | Select-Object -Property ProviderNamespace, Locations, RegistrationState
Get-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity | Select-Object -Property ProviderNamespace, Locations, RegistrationState
```

## 1. Create an Azure VM and deploy AzStack-HCI on the Azure VM

```PowerShell
# Adjust any parameters you wish to change
$rgName = "akshcinodepoolsbugbash"
$location = "eastus" # To check available locations, run Get-AzureLocation 
$timeStamp = (Get-Date).ToString("MM-dd-HHmmss")
$deploymentName = ("AksHciDeploy_" + "$timeStamp")
$vmName = "AKSHCIHost004"
$vmSize = "Standard_E16s_v4"
$vmGeneration = "Generation 2" 
$domainName = "akshci.local"
$dataDiskType = "StandardSSD_LRS"
$dataDiskSize = "32"
$adminUsername = "azureuser"
$adminPassword = ConvertTo-SecureString 'P@ssw0rd123!' -AsPlainText -Force
$enableDHCP = "Enabled" # you have to enable DHCP for this preview
$customRdpPort = "3389" # Between 0 and 65535 #
$autoShutdownStatus = "Enabled" # Or Disabled #
$autoShutdownTime = "00:00"
$autoShutdownTimeZone = "Pacific Standard Time"
$existingWindowsServerLicense = "No"

# Create Resource Group
New-AzresourceGroup -Name $rgName -Location  $location -Verbose

# Deploy ARM Template
# using: https://github.com/Azure/aks-hci/tree/main/eval
New-AzresourceGroupDeployment -resourceGroupName $rgName -Name $deploymentName `
    -TemplateUri "https://raw.githubusercontent.com/Azure/aks-hci/main/eval/json/akshcihost.json" `
    -virtualMachineName $vmName `
    -virtualMachineSize $vmSize `
    -virtualMachineGeneration $vmGeneration `
    -domainName $domainName `
    -dataDiskType $dataDiskType `
    -dataDiskSize $dataDiskSize `
    -adminUsername $adminUsername `
    -adminPassword $adminPassword `
    -enableDHCP $enableDHCP `
    -customRdpPort $customRdpPort `
    -autoShutdownStatus $autoShutdownStatus `
    -autoShutdownTime $autoShutdownTime `
    -autoShutdownTimeZone $autoShutdownTimeZone `
    -alreadyHaveAWindowsServerLicense $existingWindowsServerLicense `
    -Verbose

# Get connection details of the newly created VM
$getIp = Get-AzPublicIpAddress -Name "AKSHCILabPubIp" -resourceGroupName $rgName
$getIp | Select-Object Name,IpAddress,@{label='FQDN';expression={$_.DnsSettings.Fqdn}}
```

### RDP into the Azure VM
RDP into the VM you just deployed in the previous step, then using PowerShell ISE (in Admin mode) or VScode run the following commands. You can find RDP instructions when you click on the virtual machine resource on the Azure portal.

### Install AZ CLI on the Azure VM
```PowerShell
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
Exit
```
Now verify the verison is 2.32 by running the below command:
```
az -v
```
If you get an error saying " The term 'az' is not recognized as the name of a cmdlet, function, script file, or operable program.", run the following command and then rerun az -v to check Az CLI version > 2.32
```
$env:PATH += ";C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin;"
```

### Install Az CLI Extensions on the Azure VM
```
az extension add -n k8s-extension 
az extension add -n customlocation
az extension add -n arcappliance
```

## 2. Install AKS on Azure Stack HCI on the Azure VM

### Install pre-requisites
Install PS client tools:
```PowerShell
Install-PackageProvider Nuget –Force
Install-Module –Name PowerShellGet –Force
Exit
```

In a new connection run:
```PowerShell
# install the AKSHCI modules
Install-Module -Name AksHci -Repository PSGallery -Force -AcceptLicense
Install-Module -Name ArcHci -RequiredVersion 0.2.8 -Force -Confirm:$false -SkipPublisherCheck -AcceptLicense
Exit
```

Now open a new window and run the following command:
```powershell
Initialize-AksHciNode 
Exit
```

### Networking & IP assignments in the Azure VM PoC environment
The following command creates a network object for the AKS on Azure Stack HCI host (or management cluster) as well as the Resource Bridge. This will take IPs from the VIP VIP Pool for:
* 1x AKS host / Mgmt Cluster
* 1x The Resource Bridge / Arc Appliance
* 2x IP addresses for updating the AKS on Azure Stack HCI host

```PowerShell
# For this you will use the DHCP server that comes with AzStack-HCI, these are the ranges you will use:
$mgmtVipPoolStart = "192.168.0.155"
$mgmtVipPoolEnd = "192.168.0.200"

#virtual switch name
$vSwitch = "InternalNAT"

# cloud service IP
$cloudServiceIP = "192.168.0.150"
```

For more details:
* [cloudserviceIP](https://docs.microsoft.com/azure-stack/aks-hci/concepts-node-networking#microsoft-on-premises-cloud-service) so that the Kubernetes bits can talk to your Azure Stack HCI physical nodes.
* *What are the IP's for?* You need a set of IP addresses in the same subnet as the DHCP server but excluded from the DHCP scope.
    * You will build “VIPPools” from this IP address list later during deployment.
    * You will need atleast two non-overlapping VIPPools for this preview. Apart from IP addresses in the DHCP server, we also need to statically assign IP addresses to some important agents, so they are long lived.


### Install AKS-HCI

```powershell
$subscriptionId = <Azure subscription ID>
$tenantId = <Azure tenant>
```
```powershell
# make sure your `–workingDir` parameter value does not contain any spaces. 
$workingDir = "V:\AKS-HCI\WorkingDir"
$cloudConfigLocation = "V:\AKS-HCI\Config"
$location = "eastus"
$resourceGroup = "akshcinodepoolsbugbash"

# create network object
$vnet = New-AksHciNetworkSetting -Name "vnet-mgmt-setting01" -vippoolstart $mgmtVipPoolStart -vippoolend $mgmtVipPoolEnd -vSwitchName $vSwitch

Set-AksHciConfig -vnet $vnet -workingDir $workingDir -cloudConfigLocation $cloudConfigLocation -cloudServiceIP $cloudServiceIP

# NOTE!!! when running this command you will be asked to authenticate
Set-AksHciRegistration -SubscriptionId $subscriptionId -resourceGroupName $resourceGroup -TenantId $tenantId -UseDeviceAuthentication

# install AKS-HCI mgmt cluster 
Install-AksHci
```
This command will take ~10-15mins and you maybe asked to authenticate and see the below, this is ok.

>> NOTE: If you are running Windows PowerShell remotely, note that some failover clustering cmdlets do not work remotely. When possible, run the commands locally and specify a remote computer as the target. To run the cmdlet remotely, try using the Credential Security Service Provider (CredSSP). All additional errors or warnings from this cmdlet might be caused by running it remotely. 

To check if you have successfully installed AKS on Azure Stack HCI, run the following command:

```powershell
Get-AksHciVersion
```
```output
1.0.8.10223
```

> Note! Do not proceed if you have any errors! If you face an issue installing AKS on Azure Stack HCI, review the AKS on Azure Stack HCI [troubleshooting section](https://docs.microsoft.com/azure-stack/aks-hci/known-issues). If the troubleshooting section does not help you, please file a [GitHub issue](https://github.com/Azure/aks-hci/issues). Make sure you attach logs (use `Get-AksHciLogs`), so that we can help you faster.

## 3. Install Arc Appliance

### Generate pre-requisite YAML files needed to deploy Arc Appliance 
```PowerShell
# set appliance name
$arcAppName="pocArcApp"
# import module
Import-Module ArcHci

New-ArcHciAksConfigFiles -subscriptionID $subscriptionId -location $location -resourceGroup $resourceGroup -resourceName $arcAppName -workDirectory $workingDir
```

Sample output:

```output
HCI login file successfully generated in 'V:\AKS-HCI\WorkingDir\kvatoken.tok'
Generating ARC HCI configuration files...
Config file successfully generated in 'V:\AKS-HCI\WorkingDir'
```

> Note! Here you will be switching to AZ CLI, please continue to run this from the PS ISE or VS Code inside the Azure VM. 

### Login to Azure using Az CLI
```
$subscription=<Enter subscription ID>
$tenantid = <Enter tenant ID>
```
```
az login -t $tenantid --use-device-code
az account set -s $subscription
```

### Create Arc Appliance
```
$workingDir = "V:\AKS-HCI\WorkingDir"
$configFilePath= $workingDir + "\hci-appliance.yaml"
$arcAppName="pocArcApp"
$resourceGroup = "akshcinodepoolsbugbash"
```
```
az arcappliance validate hci --config-file $configFilePath
az arcappliance prepare hci --config-file $configFilePath
az arcappliance deploy hci --config-file $configFilePath --outfile $workingDir\config
az arcappliance create hci --config-file $configFilePath --kubeconfig $workingDir\config
```
The above command may take upto 10mins to finish, so be patient. To check the status of your deployment, run the following command

```
# check the status == Connected 
az arcappliance show --resource-group $resourceGroup --name $arcAppName --query "status" -o tsv
```

## 4. Installing the AKS on Azure Stack HCI extension on the Arc Appliance 

```PowerShell
$arcExtnName = "akshcicluExtn1"
az k8s-extension create `
  --resource-group $resourceGroup `
  --cluster-name $arcAppName `
  --cluster-type appliances `
  --name $arcExtnName `
  --extension-type Microsoft.HybridAKSOperator `
  --version 0.0.21 `
  --config Microsoft.CustomLocation.ServiceAccount="default"
 ```

Check if the extension provisioningState is "Succeeded", this can take up to 10mins!!!
```
az k8s-extension show --resource-group $resourceGroup  --cluster-name $arcAppName --cluster-type appliances --name $arcExtnName --query "provisioningState" -o tsv
```

## 5. Installing a custom location on top of the AKS-HCI extension on the Arc Appliance 
```PowerShell
$customLocationName="AzStackEusCustLoc"

$ArcApplianceResourceId=az arcappliance show --resource-group $resourceGroup  --name $arcAppName --query id -o tsv

$ClusterExtensionResourceId=az k8s-extension show --resource-group $resourceGroup --cluster-name  $arcAppName --cluster-type appliances --name $arcExtnName --query id -o tsv

az customlocation create --name $customLocationName --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $ClusterExtensionResourceId --resource-group $resourceGroup 
```

Check if the custom location provisioningState is "Succeeded":
```
az customlocation show --name $customLocationName --resource-group $resourceGroup --query "provisioningState" -o tsv
```

```
$CustomLocationResourceId = az customlocation show --name $customLocationName --resource-group $resourceGroup --query id -o tsv 
```

## 6. Create a network for your AKS-HCI workload clusters
This VIP Pool must not overlap with the previous mgmt VIP Pool range you created by running New-AksHciNetworkSetting, this is for workload clusters only!

```PowerShell
$wkldClusterVnet = "wkldvnet"
$wkldCluVipPoolStart = "192.168.0.201"
$wkldCluVipPoolEnd = "192.168.0.250"
$vSwitch = "InternalNAT"
$workingDir = "V:\AKS-HCI\WorkingDir"

New-KvaVirtualNetwork -name $wkldClusterVnet -vippoolstart $wkldCluVipPoolStart -vippoolend $wkldCluVipPoolEnd -vswitchname $vSwitch -kubeconfig $workingDir\config
```

## 7. Download the Kubernetes VHD file

```PowerShell
Add-KvaGalleryImage -kubernetesVersion 1.21.2
```

## 8. Create and manage AKS-HCI clusters using Az CLI

[Download the hybridaks Az CLI extension](https://github.com/Azure/aks-hci/blob/main/preview/node-pools-bugbash/hybridaks-0.1.2-py3-none-any.whl) WHL file.

Install the hybridaks Az CLI Extension using the downloaded WHL file.
```bash
az extension add --yes --source <path to the downloaded hybridaks-0.1.1-py3-none-any.whl file>
az hybridaks -h
```

### Create an AKS-HCI cluster using Az CLI 
```bash 
az hybridaks create -n cluster-1 -g $resourceGroup --custom-location $CustomLocationResourceId --vnet-id $wkldClusterVnet --generate-ssh-keys
```
You can skip adding --generate-ssh-keys if you already have an SSH key named `id_rsa` in the ~/.ssh folder.

### Show the AKS-HCI cluster
```azurecli
az hybridaks show -g $resourceGroup -n cluster-1 
```

### Add a nodepool to your AKS-HCI cluster
```
az hybridaks nodepool add --name "samplenodepool" --cluster-name cluster-1 --resource-group $resourceGroup
```

### List nodepools in your AKS-HCI cluster
```
az hybridaks nodepool list -g $resourceGroup --cluster-name cluster-1 --query value -o table
```

### Get admin kubeconfig of AKS-HCI cluster created using Az CLI
RDP into to the Azure VM before proceeding.
```powershell
Get-TargetClusterAdminCredentials -clusterName "cluster-1" -outfile $workingDir\targetclusterconfig -kubeconfig $workingDir\config
```

### Access your clusters using kubectl
```
kubectl get pods -A --kubeconfig $workingDir\targetclusterconfig
```

### Delete a nodepool on your AKS-HCI cluster
```
az hybridaks nodepool delete --name "samplenodepool" --cluster-name cluster-1 --resource-group $resourceGroup
```

## [Admin role] Collecting logs
If things go wrong, you can collect logs using the following commands:

```powershell
Get-ArcHciLogs
```

```azurecli
az arcappliance logs hci --kubeconfig $workingDir\config
``` 

## Clean up
```azurecli
az login
az account set -s <subscriptionID>
```

Step 1: Delete all preview AKS-HCI clusters created using Az CLI

```azurecli
az hybridaks delete --resource-group <resource group name> --name <akshci cluster name>
```

Step 2: Delete the custom location

```azurecli
az customlocation delete --name <custom location name> --resource-group <resource group name>
```

Step 3: Delete the cluster extension

```azurecli
az k8s-extension delete --resource-group <resource group name> --cluster-name <arc appliance name> --cluster-type appliances --name <akshci extension name>
```

Step 4: Delete the Arc Appliance

```azurecli
az arcappliance delete hci --config-file $workingDir\config
```

Step 5: Delete the ArcHCI config files

```powershell
Remove-ArcHciConfigFiles -workDir $workingDir
```

Step 6: Delete the Azure VM if you're finished!
