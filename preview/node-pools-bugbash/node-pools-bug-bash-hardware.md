## Step 0: Prerequisites

First, you need to make sure that you have your environment set up. Follow the table below to ensure you've covered everything you need for a successful installation:

Azure Stack HCI/AKS on Azure Stack HCI admin:

| Prerequisite |  Item  |  Details  |  Value  |
| -- | ----- | ------- | ------- |
| 1   | Do you have an Azure subscription?  | [Guide to get an Azure subscription](https://docs.microsoft.com/azure-stack/aks-hci/system-requirements#azure-account-and-subscription), if you don’t already have one. Need Azure subscription to create AKS-HCI clusters + AKS-HCI billing.  |  Make sure you have your subscription ID. |
| 2 | Do you have the right permissions on your Azure subscription? | Required to register AKS-HCI for billing. You have two options: <br> *Option 1*: [You are an Azure subscription "owner"](https://docs.microsoft.com/azure-stack/aks-hci/system-requirements#azure-subscription-role-and-access-level) AND [Ability to register applications](https://docs.microsoft.com/azure-stack/aks-hci/system-requirements#azure-ad-permissions-role-and-access-level). <br> *Option 2*: Have a service principal. Ask your Azure subscription "owner" to create this service principal for you, using this [guide](https://docs.microsoft.com/azure-stack/aks-hci/system-requirements#optional-create-a-new-service-principal). | If you used option 2: Make sure you have a service principal "AppID" and service principal "Password/Secret" |
| 3 | Is your subscription in the "allow list" for this private preview?  | You will need to register your interest and have your subscription enabled for this private preview. Register at [aka.ms/lifecycle-management-preview](https://aka.ms/arcAksHciPriPreview).  | We will email you back when your subscription has been added. |
| 4 | Do you have a recent version of Az CLI installed? | Required to run the Az commands. [Install Az CLI](https://docs.microsoft.com/cli/azure/install-azure-cli-windows?tabs=azure-cli). You can upgrade to the latest version by running `az upgrade`. | Verify that you have Az CLI by running `az -v`. |
| 5 | Have you registered your subscription for this preview feature? | `az account set -s <subscriptionID from step 1>` <br> `az feature register --namespace Microsoft.HybridContainerService --name hiddenPreviewAccess` <br> `az feature register --namespace Microsoft.ResourceConnector --name Appliances-ppauto` <br>`az feature register --namespace Microsoft.HybridConnectivity --name hiddenPreviewAccess`| Verify if you have registered the features by running the command: <br> `az account set -s <subscriptionID from #1>` <br> `az feature show --namespace Microsoft.HybridContainerService --name hiddenPreviewAccess -o table` <br> `az feature show --namespace Microsoft.HybridContainerService --name hiddenPreviewAccess -o table` |
| 6 | Have you registered all the right providers on your subscription? | You need to register the providers to use this preview: <br> `az account set -s <subscriptionID from step #1>` <br> `az provider register --namespace Microsoft.Kubernetes` <br> `az provider register --namespace Microsoft.KubernetesConfiguration` <br> `az provider register --namespace Microsoft.ExtendedLocation` <br> `az provider register --namespace Microsoft.ResourceConnector` <br> `az provider register --namespace Microsoft.HybridContainerService`  <br> `az provider register --namespace Microsoft.HybridConnectivity` | If the status shows *registering*, try again after some time. <br> `az account set -s <subscriptionID from step #1>` <br> `az provider show --namespace Microsoft.Kubernetes -o table` <br> `az provider show --namespace Microsoft.KubernetesConfiguration -o table` <br> `az provider show --namespace Microsoft.ExtendedLocation -o table` <br> `az provider show --namespace Microsoft.ResourceConnector -o table` <br> `az provider show --namespace Microsoft.HybridContainerService -o table` | 
| 7 | Do you have a DHCP server with enough IP addresses in your environment? | For this month’s preview release, you need a DHCP server. [Follow this guide for recommended number of IP addresses in your DHCP server](https://docs.microsoft.com/en-us/azure-stack/aks-hci/concepts-node-networking#minimum-ip-address-reservation) <br> This DHCP server will be used to assign IP addresses to VMs that are the underlying compute for your Kubernetes cluster nodes. | Check with your admin if your Azure Stack HCI network environment has a DHCP server. |
| 8 | Do you have a continuous set of IP addresses in the same subnet as the DHCP server but excluded from the DHCP scope? | You need a set of IP addresses in the same subnet as the DHCP server but excluded from the DHCP scope. <br> You will build "VIPPools" from this IP address list later during deployment. <br> You will need atleast two non-overlapping VIPPools for this preview. Apart from IP addresses in the DHCP server, we also need to statically assign IP addresses to some important agents, so they are long lived. | List of IP addresses in the same subnet as the DHCP server but excluded from the DHCP scope. |
| 9 | Do you have an external virtual switch? | You need an external virtual switch for the VMs that are the underlying compute for your Kubernetes cluster nodes | Name of your virtual switch |
| 10 | Do you have a cloudserviceIP? | You need a [cloudserviceIP](https://docs.microsoft.com/azure-stack/aks-hci/concepts-node-networking#microsoft-on-premises-cloud-service) so that the Kubernetes bits can talk to your Azure Stack HCI physical nodes. | Enter your cloudserviceIP address |
| 11 | Did you install the AKS-HCI PowerShell module? | `Install-Module -Name AksHci -Repository PSGallery` | Confirm that the AksHci module version is `1.1.27` by running the following command: `Get-Module -Name akshci` |
| 12 | Did you install the ArcHCI PowerShell module? | `Install-Module -Name ArcHci -RequiredVersion 0.2.8 -Force -Confirm:$false -SkipPublisherCheck -AcceptLicense` | |
| 13 | Did you install the Az extensions? | `az extension add --name k8s-extension` <br> `az extension add --name customlocation` <br> `az extension add --name arcappliance` | You can check if you have the extensions installed and their versions by running the following command: `az -v` <br> Expected output: <br> `azure-cli                         2.33.1` <br> `core                              2.33.1` <br> `telemetry                          1.0.6` <br> Extensions: <br>` arcappliance                      0.2.16` <br> `customlocation                     0.1.3` <br> `k8s-extension                      1.0.4` |

## Step 1: Install AKS on Azure Stack HCI 

Install AKS on Azure Stack HCI's management cluster using either PowerShell or Windows Admin Center. You can only install the management cluster using DHCP networking, without VLAN, in an environment that does not have a proxy. Since you will be running preview software beside your AKS on Azure Stack HCI setup, we do not recommend running AKS on Azure Stack HCI and this private preview in your production environment.

For detail documentation, see [AKS on Azure Stack HCI](https://docs.microsoft.com/azure-stack/aks-hci).

### Sample steps to install AKS on Azure Stack HCI using PowerShell 

> [!NOTE]
> The steps below assume that you are familiar with AKS on Azure Stack HCI and have deployed AKS on Azure Stack HCI in the past. If you're new, please follow the [AKS on Azure Stack HCI documentation](https://docs.microsoft.com/azure-stack/aks-hci). 

You must first close ALL open PowerShell windows on ALL HCI nodes and then open a fresh admin PowerShell session. 

Run the following command on all your Azure Stack HCI nodes:

```powershell
Initialize-AksHciNode 
```

The following command creates a network object for the AKS on Azure Stack HCI host (or management cluster) as well as the Resource Bridge. Make sure your VIP Pool contains at least 4 IP addresses - one for the AKS on Azure Stack HCI host, one for the Resource Bridge, and 2 IP addresses for updating the AKS on Azure Stack HCI host. 


In the example below, the VIP Pool has 4 IP addresses - from 10.10.180.241 to 10.10.180.244. The values below are example values and must be customized according to your environment. Please talk to your network administrator and your HCI administrator for more information on these values.

<span style="color:red">$vippoolstart = "10.10.180.241" <br>
$vippoolend = "10.10.180.244" <br> $vswitch = "myVMSwitch"</span>


```powershell
$vnet = New-AksHciNetworkSetting -Name "vnet-mgmt" -vippoolstart $vippoolstart -vippoolend $vippoolend -vSwitchName $vswitch
```

Once you have created a network object, set other configurations for the management cluster.

> [!NOTE]
> Make sure your `-workingDir` parameter value does not contain any spaces. 

> [!NOTE]
> The values below are example values and must be customized according to your environment. Please talk to your network administrator and your HCI administrator for more information on these values.
<span style="color:red">$workingDir = "C:\ClusterStorage\Volume01\WorkDir" <br>
$cloudConfig = "C:\ClusterStorage\Volume01\cloudConfig" <br> $susbcription="Azure subscription ID" <br> $resourcegroup = "Azure resource group name" <br> $tenant="Azure tenant ID" <br>
$cloudServiceIP = "10.10.127.298"</span>

> [!NOTE]
> For more information on cloudServiceIP, visit [cloudserviceCIDR/IP](https://docs.microsoft.com/azure-stack/aks-hci/concepts-node-networking#microsoft-on-premises-cloud-service).

```powershell
Set-AksHciConfig -vnet $vnet -workingDir $workingDir -cloudConfigLocation $cloudConfigLocation -cloudServiceIP $cloudServiceIP

Set-AksHciRegistration -SubscriptionId $subscription -ResourceGroupName $resourcegroup -TenantId $tenant -UseDeviceAuthentication

Install-AksHci
```

If you face an issue installing AKS on Azure Stack HCI, review the AKS on Azure Stack HCI [troubleshooting section](https://docs.microsoft.com/azure-stack/aks-hci/known-issues). If the troubleshooting section does not help you, please file a [GitHub issue](https://github.com/Azure/aks-hci/issues). Make sure you attach logs (use `Get-AksHciLogs`), so that we can help you faster.

To check if you have successfully installed AKS on Azure Stack HCI, run the following command:

```powershell
Get-AksHciVersion
```

Make sure your AKS on Azure Stack HCI version is the following version. 

Expected Output:

```powershell
1.0.8.10223
```
> Note! Do not proceed if you have any errors! If you face an issue installing AKS on Azure Stack HCI, review the AKS on Azure Stack HCI [troubleshooting section](https://docs.microsoft.com/azure-stack/aks-hci/known-issues). If the troubleshooting section does not help you, please file a [GitHub issue](https://github.com/Azure/aks-hci/issues). Make sure you attach logs (use `Get-AksHciLogs`), so that we can help you faster.


## Step 2: Install Arc Appliance 

Installing Arc Appliance requires you to create a YAML file. Fortunately, we have automated the process of creating this YAML file for you. Run the following command to create the YAML file.

```
$workingDir = "<csv path to store config files, yamls, etc>"
```
The workingDir is the path to a shared cluster volume that stores the config files we create for you. I recommend you use the same workDir you used while installing AKS-HCI. Make sure your workDir full path does not contain any spaces. 

```powershell
New-ArcHciAksConfigFiles -subscriptionID "<subscriptionID from #1>" -location "<eastus/westeurope>" -resourceGroup "<azure resource group>" -resourceName "<name of appliance/resource bridge>" -workDirectory "<csv path to store config files, yamls, etc>"
```

|  Parameter  |  Parameter details |
| -----------| ------------ |
| subscriptionID | Your Appliance will be installed on this Azure subscription ID. Pass in the same subscription ID you put in the Step 0 Item #1. |
| resourceGroup | A resource group in the Azure subscription listed above (Step 0 Item #1). Make sure your resource group is in the eastus or westeurope location. |
| location | The Azure location where your Appliance will be deployed. Make sure this location is either eastus or westeurope. It's recommended you use the same location you used while creating the resource group. |
| resourceName | The name of your Arc Appliance |
| workDirectory | Path to a shared cluster volume that stores the config files we create for you. I recommend you use the same workDir you used while installing AKS-HCI. Make sure your workDir full path does not contain any spaces. |

Sample output:

```output
HCI login file successfully generated in 'C:\ClusterStorage\Volume01\WorkDir\kvatoken.tok'
Generating ARC HCI configuration files...
Config file successfully generated in 'C:\ClusterStorage\Volume01\WorkDir'
```

Navigate to the `Config file` location in the output above and note down the full path of the config file. **This path is extremely important for the next 3 commands**. In the example output above, the config file was generated at `C:\ClusterStorage\Volume01\WorkDir` and the full path of the config file is `C:\ClusterStorage\Volume01\WorkDir\hci-appliance.yaml`.

You can now proceed with deploying Appliance.

```azurecli
az login //login to Azure
az account set -s "<subscription from #1>"
az arcappliance validate hci --config-file '<full path of the config file>'
az arcappliance prepare hci --config-file '<full path of the config file>'
```

Sample input:
```
az arcappliance validate hci --config-file 'C:\ClusterStorage\Volume01\WorkDir\hci-appliance.yaml'
az arcappliance prepare hci --config-file 'C:\ClusterStorage\Volume01\WorkDir\hci-appliance.yaml'
```

In the below command, the outfile is the location where you want to store Arc Appliance's kubeconfig. I recommend storing it in the WorkDir shared cluster volume location. For example, `C:\ClusterStorage\Volume01\WorkDir\appliancekubeconfig` 

```azurecli
az arcappliance deploy hci --config-file '<full path of the config file>' --outfile $workingDir\applianceconfig

az arcappliance create hci --config-file '<full path of the config file>' --kubeconfig $workingDir\applianceconfig
```

Sample input:
```
az arcappliance deploy hci --config-file 'C:\ClusterStorage\Volume01\WorkDir\hci-appliance.yaml' --outfile 'C:\ClusterStorage\Volume01\WorkDir\appliancekubeconfig'
az arcappliance create hci --config-file 'C:\ClusterStorage\Volume01\WorkDir\hci-appliance.yaml' --kubeconfig 'C:\ClusterStorage\Volume01\WorkDir\appliancekubeconfig'
```

And with the `az arcappliance create` command, you're done with deploying the Appliance! 

Before proceeding to the next step, run the following command to check if the Arc Appliance status says *Connected*. It might not say *Connected* at first. This takes time. Try again after a few minutes.

```azurecli
az arcappliance show --resource-group <azure resource group> --name <name of appliance/resource bridge> --query "status" -o tsv
```

## Step 3: Installing the AKS on Azure Stack HCI extension on the Arc Appliance 

To install the extension, run the following command:

```azurecli
az account set -s <subscription from #1>

az k8s-extension create --resource-group <azure resource group> --cluster-name <arc appliance name> --cluster-type appliances --name <akshci cluster extension name> --extension-type Microsoft.HybridAKSOperator --version 0.0.21 --config Microsoft.CustomLocation.ServiceAccount="default" 
```

|  Parameter  |  Parameter details  |
| ------------|  ----------------- |
| resource-group |  A resource group in the Azure subscription listed above (Step 0 Item #1). Make sure you use the same resource group you used when deploying Arc Appliance.  |
| cluster-name  |  The name of your Arc Appliance. |
| name  |  Name of your AKS-HCI cluster extension on top of Arc Appliance  |
| cluster-type  | Must be *appliances*. Do not change this value.  |
| extension-type  |  Must be *Microsoft.HybridAKSOperator*. Do not change this value. |
| version | Must be *0.0.21*. Do not change this value. |
| config  | Must be *config Microsoft.CustomLocation.ServiceAccount="default"*. Do not change this value. |

Once you have created the AKS on Azure Stack HCI extension on top of the Arc Appliance, run the following command to check if the extension status says *Running*. It might say *pending* at first. Be patient! This takes time. Try again after a few minutes.

```azurecli
az k8s-extension show --resource-group <resource group name> --cluster-name <arc appliance name> --cluster-type appliances --name <akshci extension name> --query "status" -o tsv
```

## Step 4: Installing a custom location on top of the AKS-HCI extension on the Arc Appliance 

You need to first collect the ARM IDs of the Arc Appliance and the AKS on Azure Stack HCI extension in PowerShell variables.

```azurecli
$ArcApplianceResourceId=az arcappliance show --resource-group <resource group name> --name <arc appliance name> --query id -o tsv

$ClusterExtensionResourceId=az k8s-extension show --resource-group <resource group name> --cluster-name <arc appliance name> --cluster-type appliances --name <akshci extension name> --query id -o tsv
```

You can then create the custom location for your Azure Stack HCI cluster that has the AKS-HCI extension installed on it.

```azurecli
az customlocation create --name <customlocation name> --namespace "default" --host-resource-id $ArcApplianceResourceId --cluster-extension-ids $ClusterExtensionResourceId --resource-group <resource group name>
```

|  Parameter  |  Parameter details  |
| ------------|  ----------------- |
| resource-group |  A resource group in the Azure subscription listed above (Step 0 Item #1). Make sure you use the same resource group you used when deploying Arc Appliance.  |
| namespace  |  Must be *default*. Do not change this value. |
| name  |  Name of your AKS on Azure Stack HCI custom location on top of Arc Appliance + AKS-HCI extension. |
| host-resource-id  | ARM ID of the Appliance. You can get the ARM ID using `az arcappliance show --resource-group <resource group name> --name <arc appliance name> --query id -o tsv`.  |
| cluster-extension-ids   | ARM ID of the AKS-HCI extension on top of Appliance. You can get the ARM ID using `az k8s-extension show --resource-group <resource group name> --cluster-name <arc appliance name> --cluster-type appliances --name <aks-hci extension name> --query id -o tsv`. |

Once you create the custom location on top of the Arc Appliance, run the following command to check if the custom location provisioning state says *Succeeded*. It might say something else at first. Be patient! This takes time. Try again after 10 minutes.

```azurecli
az customlocation show --name <custom location name> --resource-group <resource group name> --query "provisioningState" -o tsv
```

## Step 5: Create a network for your AKS-HCI workload clusters

We're so close! Create a network for your developers to use to create AKS on Azure Stack HCI clusters using the following command.

```powershell
New-KvaVirtualNetwork -name "<vnet name>" -vippoolstart "<vippoolstart IP address>" -vippoolend "<vippoolstart IP address>" -vswitchname "<vmswitchname>" -kubeconfig $workingDir\applianceconfig
```

Make sure the IP addresses you give in the VIP pool (vippoolstart and vippoolend) do not overlap with the VIP pool you created by running `New-AksHciNetworkSetting`.

IP address exhaustion can lead to AKS on Azure Stack HCI cluster deployment failures. Plan your IP addresses very carefully. For more information, you can [learn more about DHCP IP address planning](https://docs.microsoft.com/azure-stack/aks-hci/concepts-node-networking#minimum-ip-address-reservations-for-an-aks-on-azure-stack-hci-deployment).


## Step 6: Assign user role RBAC access to create AKS on Azure Stack HCI clusters

Use the following steps to create AKS on Azure Stack HCI clusters and assign RBAC access:

1. Go to Azure Portal, navigate to the subscription and then resource group that you used to create your Appliance and the custom location.
2. Go to IAM in the left-hand side of the portal.
3. Click **Role assignment** -> **Add assignment**.
4. Type in the name of the end user and assign them *contributor* access.


## Step 7: Download the Kubernetes VHD file 

Run the following command to download the Linux VHD file specific to the Kubernetes version. For this preview release, you can only download the VHD file for Kubernetes version 1.21.2

```powershell
Add-KvaGalleryImage -kubernetesVersion 1.21.2
```

## Step 8: Give the dev user the details 

Provide the following details to the end user:

| Parameter |  Parameter details |
| --------- | ------------------|
| Custom-location  | ARM ID of the custom location you created in step 4. You can get the ARM ID using `az customlocation show --name <custom location name> --resource-group <azure resource group> --query "id" -o tsv`
| vnet-id | The name of the virtual network you created using New-KvaVirtualNetwork in step 5. |

## Step 9: Create AKS-HCI clusters using Az CLI [User role] 

Before creating AKS on Azure Stack HCI clusters, make sure you have Az CLI and the hybrid AKS extension installed in your environment. 

[Download the hybridaks Az CLI extension](https://github.com/Azure/aks-hci/blob/main/preview/node-pools-bugbash/hybridaks-0.1.2-py3-none-any.whl) WHL file.

```azurecli
az extension remove -n hybridaks
az extension add --yes --source <path to the downloaded hybridaks-0.1.2-py3-none-any.whl file>
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
Get-TargetClusterAdminCredentials -clusterName "cluster-1" -outfile $workingDir\targetclusterconfig -kubeconfig $workingDir\applianceconfig
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
az arcappliance logs hci --kubeconfig 'C:\ClusterStorage\Volume01\WorkDir\config'
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

