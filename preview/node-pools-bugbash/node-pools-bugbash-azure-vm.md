## Running the demo
Once you create the Azure VM, run all commands from an RDP session there.

>> NOTE: The instructions are a mixture of PS and AZ CLI commands, you run all of these from a PS ISE such as PS ISE in Windows or VS Code. They are split between PS and CLI because the InfraAdmin will be the individual who sets up the infra layers (server, connection to Azure and dependent componets). The end user (e.g. dev) will then use AZ CLI to create AKS clusters on HCI via Azure.

# Register for the preview!
You will need to register your interest to get access to the docs and have your subscription enabled for this private preview, please register [here (https://aka.ms/arcAksHciPriPreview).

### Register for features and providers
```PowerShell
Login-AzAccount
Get-AzSubscription
Connect-AzAccount -TenantId <your Azure tenant ID>
Set-AzContext -Subscription <your Azure subscription>
$currentAzContext = Get-AzContext
$subscriptionID = $currentAzContext.Subscription.Id
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

### Create an Azure VM and deploy AzStack-HCI Host on the Azure VM
```PowerShell
# Get the Execution Policy on the system
Get-ExecutionPolicy
# Set the Execution Policy for this process only
if ((Get-ExecutionPolicy) -ne "RemoteSigned") { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force }

# Update all modules
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Update-Module -Force  
```

### Deployment of the AzStack host
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
$existingWindowsServerLicense = "No" # See NOTE 2 below on Azure Hybrid Benefit

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

# Configure the Az-Stack HCI Host on the Azure VM
RDP to the VM you just deployed in the previous step, then using PowerShell ISE (in Admin mode) or VScode:

## Install AZ CLI on Host
```PowerShell
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
Exit
```
Now verify the verison in 2.32:
```bash
az -v
```

## Connect Az CLI to Azure
Run these commands from VS Code or the Windows PowerShell ISE
```bash
$subscription=<enter subscription ID>
az login -t <enter tenant ID>

az account show --output table
az account set --subscription $subscription
$subscriptionId=az account show --subscription $subscription --query "id" -o tsv

# Install Az CLI Extensions
az extension add --name connectedk8s --version 1.2.0 
az extension add --name k8s-configuration --version 1.1.1 
az extension add --name k8s-extension --version 1.0.0 
az extension add --name customlocation --version 0.1.3 
```

## Add Arc Appliance Az CLI Extension
Install the arcappliance Az CLI Extension
```bash
az extension remove -n arcappliance
# the above is just to make sure any arc appliance extn is removed and you have the latest
az extension add -n arcappliance
```

## Install AKS on Azure Stack HCI [Infra admin role]

Install PS client tools:
```PowerShell
# install updated PowerShellGet, was needed for running on Server
Install-PackageProvider Nuget –Force
Install-Module –Name PowerShellGet –Force

# Update all modules
Update-Module -Force  
# you need to exit the ISE so you can use the updated version of PowerShellGet
Exit
```
In a new connection run:
```PowerShell
# set repo
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
# install the DownloadSDK prereq
Install-Module -Name DownloadSdk -Force -AcceptLicense
# install the AKSHCI modules
Install-Module -Name AksHci -Repository PSGallery -Force -AcceptLicense
Install-Module -Name ArcHci -RequiredVersion 0.2.7 -Force -Confirm:$false -SkipPublisherCheck -AcceptLicense
Exit
```

Now open a new window and run the following command on all your Azure Stack HCI nodes:

```powershell
Initialize-AksHciNode 
```

## Networking & IP Assignments in PoC Environment
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

```powershell
# set other configurations for the management cluster

Connect-AzAccount -TenantId 8548a469-8c0e-4aa4-b534-ac75ca1e02f7
Set-AzContext -Subscription 3959ec86-5353-4b0c-b5d7-3877122861a0
$currentAzContext = Get-AzContext
$subscriptionId = $currentAzContext.Subscription.Id
$tenantId=$currentAzContext.Tenant.Id 
# make sure your `–workingDir` parameter value does not contain any spaces. 
$workingDir = "V:\AKS-HCI\WorkingDir"
$cloudConfigLocation = "V:\AKS-HCI\Config"
$location = "eastus"
$resourceGroup = "akshciPP2bugbash04"

# create network object
$vnet = New-AksHciNetworkSetting -Name "vnet-mgmt-setting01" -vippoolstart $mgmtVipPoolStart -vippoolend $mgmtVipPoolEnd -vSwitchName $vSwitch

Set-AksHciConfig -vnet $vnet -workingDir $workingDir -cloudConfigLocation $cloudConfigLocation -cloudServiceIP $cloudServiceIP

# NOTE!!! when running this command you will be asked to authenticate
Set-AksHciRegistration -SubscriptionId $subscriptionId -resourceGroupName $resourceGroup -TenantId $tenantId -UseDeviceAuthentication

# install AKS-HCI mgmt cluster and arc connected
Install-AksHci
```

This command will take ~10-15mins and you maybe asked to authenticate and see the below, this is ok.
```text
WARNING: If you are running Windows PowerShell remotely, note that some failover clustering cmdlets do not work remotely. When possible, run the cmd locally and specify a remote computer as the target. To run the cmdlet remotely, try using the Credential Security Service Provider (CredSSP). A
ll additional errors or warnings from this cmdlet might be caused by running it remotely. 
```

If you face an issue installing AKS on Azure Stack HCI, review the AKS on Azure Stack HCI [troubleshooting section](https://docs.microsoft.com/azure-stack/aks-hci/known-issues). If the troubleshooting section does not help you, please file a [GitHub issue](https://github.com/Azure/aks-hci/issues). Make sure you attach logs (use `Get-AksHciLogs`), so that we can help you faster.

To check if you have successfully installed AKS on Azure Stack HCI, run the following command:

```powershell
Get-AksHciVersion
```
Make sure your AKS on Azure Stack HCI version is at least the following versions. We currently work with both January and February releases.

Expected Output:

```powershell
> 1.0.5.11028
```

> Note! Now the AzStack-HCI node is configured, if you have had any errors please do not proceed.

## Install Arc Appliance [Infra admin role] 
```PowerShell
# set appliance name
$arcAppName="pocArcApp"
# import module
Import-Module ArcHci

New-ArcHciConfigFiles -subscriptionID $subscriptionId -location $location -resourceGroup $resourceGroup -resourceName $arcAppName -workDirectory $workingDir
```

Sample output:

```output
HCI login file successfully generated in 'C:\ClusterStorage\Volume01\WorkDir\kvatoken.tok'
MOC config file successfully generated in 'C:\ClusterStorage\Volume01\WorkDir\hci-config.json'
Cloud agent service FQDN/IP: 'ca-b9772182-2492-4ab3-aa8f-05547413aac7.sa18.nttest.microsoft.com'
Config file successfully generated in 'C:\ClusterStorage\Volume01\WorkDir'
```

> Note! Here you will be switching to AZ CLI, please continue to run this from the PS ISE or VS Code, they will continue to use the vars declared in PS in the AZ CLI commands as you are using PS Shell.

```bash
# connect the AZ CLI on the server to the Az Sub
$subscription=<Enter subscription ID>
az login -t <Enter tenant ID>

az account show --output table
az account set --subscription $subscription
$subscriptionId=az account show --subscription $subscription --query "id" -o tsv

# Deploy the appliance
$configFilePath= $workingDir + "\hci-appliance.yaml"

az arcappliance validate hci --config-file $configFilePath
az arcappliance prepare hci --config-file $configFilePath
az arcappliance deploy hci --config-file $configFilePath --outfile $workingDir\config
az arcappliance create hci --config-file $configFilePath --kubeconfig $workingDir\config

# the command above may ~10mins so be patient!!
# to check on the status

az arcappliance show --resource-group $resourceGroup --name $arcAppName --query "provisioningState" -o tsv
# check the provisioningState ==  Succeeded 
```

## Installing the AKS on Azure Stack HCI extension on the Arc Appliance [Infra admin role]

```PowerShell
$arcExtnName = "akshcicluExtn1"
az k8s-extension create `
  --resource-group $resourceGroup `
  --cluster-name $arcAppName `
  --cluster-type appliances `
  --name $arcExtnName `
  --extension-type Microsoft.HybridAKSOperator `
  --version 0.0.9 `
  --config Microsoft.CustomLocation.ServiceAccount="default"

az k8s-extension show --resource-group $resourceGroup --cluster-name $arcAppName --cluster-type appliances --name $arcExtnName 

# check install, the extension provisioningState is "Succeeded", can take up to 10mins!!!
az k8s-extension show --resource-group $resourceGroup  --cluster-name $arcAppName --cluster-type appliances --name $arcExtnName --query "provisioningState" -o tsv
```

## Installing a custom location on top of the AKS-HCI extension on the Arc Appliance [Infra admin role]
```PowerShell
$customLocationName="AzStackEusCustLoc"

$ArcApplianceResourceId=az arcappliance show --resource-group $resourceGroup  --name $arcAppName --query id -o tsv

$ClusterExtensionResourceId=az k8s-extension show --resource-group $resourceGroup --cluster-name  $arcAppName --cluster-type appliances --name $arcExtnName --query id -o tsv

az customlocation create --name $customLocationName --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $ClusterExtensionResourceId --resource-group $resourceGroup 

az customlocation show --name $customLocationName --resource-group $resourceGroup --query "provisioningState" -o tsv

$CustomLocationResourceId = az customlocation show --name $customLocationName --resource-group $resourceGroup --query id -o tsv 

```

## Create a network for your AKS-HCI workload clusters [Infra admin role]
This VIP Pool must not overlap with the previous mgmt VIP Pool range you created by running New-AksHciNetworkSetting, this is for workload clusters only!

```PowerShell

$wkldClusterVnet = "wkldvnet"
$wkldCluVipPoolStart = "192.168.0.201"
$wkldCluVipPoolEnd = "192.168.0.250"

New-KvaVirtualNetwork -name $wkldClusterVnet -vippoolstart $wkldCluVipPoolStart -vippoolend $wkldCluVipPoolEnd -vswitchname $vSwitch 

```

## Download the Kubernetes VHD file [Infra admin role] 

```PowerShell
Add-KvaGalleryImage -kubernetesVersion 1.21.2
```

## Create AKS-HCI clusters using Az CLI [User role]

[Download the hybridaks Az CLI extension]() WHL file.

Install the hybridaks Az CLI Extension using the downloaded WHL file.
```bash
az extension remove -n hybridaks
az extension add --yes --source <path to the downloaded hybridaks-0.1.1-py3-none-any.whl file>
az hybridaks -h
```

### Create an AKS-HCI cluster using Az CLI 
```bash 
# demo only
k8sClusterName="akscluster01"
resourceGroup="akshciPP2bugbash"
location="eastus"
wkldClusterVnet="wkldvnet"
customLocationName="AzStackEusCustLoc"
customLocationResourceId = $(az customlocation show --name $customLocationName --resource-group $resourceGroup --query id -o tsv) 

az hybridaks create --name $k8sClusterName `
      --resource-group $resourceGroup `
      --location $location `
      --custom-location $customLocationResourceId `
      --vnet-id $wkldClusterVnet `
      --kubernetes-version "v1.21.2" `
      --generate-ssh-keys `
```
You can skip adding --generate-ssh-keys if you already have an SSH key named `id_rsa` in the ~/.ssh folder.

### Show the AKS-HCI cluster
```azurecli
az hybridaks show --resource-group $resourceGroup --name $k8sClusterName 
```
## Access your clusters using kubectl
In a different session while the above proxy command is running, access your target AKS-HCI cluster using kubectl.
```
kubectl get pods -A --kubeconfig "<file path where you stored your target akshci cluster admin kubeconfig in the previous step 10>"
```

## Delete an AKS-HCI cluster
Run the following command to delete an AKS-HCI cluster:
```azurecli
az hybridaks delete --resource-group $resourceGroup --name $k8sClusterName -y
```

## Clean up

In the mean time please review the deletion steps at the end of the [Private Preview 1– AKS on Azure Stack HCI cluster lifecycle management through Azure Arc](https://github.com/Azure/azure-arc-kubernetes-preview/blob/master/docs/aks-hci/cluster-lifecycle-pp1-nov-2021.md).

# Common Errors
You may see this error:
```Text
az hybridaks show --resource-group  $resourceGroup --name $k8sClusterName
az : WARNING: Command group 'hybridaks' is in preview and under development. Reference and support levels: https://aka.ms/CLI_refstatus
At line:1 char:1
+ az hybridaks show --resource-group  $resourceGroup --name $k8sCluster ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (WARNING: Comman...s/CLI_refstatus:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
ERROR: AADSTS70043: The refresh token has expired or is invalid due to sign-in frequency checks by conditional access. The token was issued on 
2021-11-18T04:19:03.3260000Z and the maximum allowed lifetime for this request is 43200.
Trace ID: fcd27086-9a1d-42e7-97dd-991cd2391800
Correlation ID: b9e78969-459f-4066-ac6c-6fd6942fad2e
Timestamp: 2021-11-19 17:18:43Z
To re-authenticate, please run:
az login --scope https://management.core.windows.net//.default 
```
If so, please run:
```PowerShell
az login --scope https://management.core.windows.net//.default 
az account set --subscription <subscriptionName> 
```
