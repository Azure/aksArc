Deploy your AKS-HCI infrastructure with PowerShell
==============
Overview
-----------
With your Windows Server Hyper-V host up and running, it's now time to deploy AKS on Azure Stack HCI. You'll first deploy the AKS management cluster onto your Windows Server Hyper-V host, then deploy a target cluster, onto which you can test deployment of a workload.

Contents
-----------
- [Overview](#overview)
- [Contents](#contents)
- [Architecture](#architecture)
- [Prepare environment](#prepare-environment)
- [Optional - Enable/Disable DHCP](#optional---enabledisable-dhcp)
- [Enable Azure integration](#enable-azure-integration)
- [Deploying AKS on Azure Stack HCI management cluster](#deploying-aks-on-azure-stack-hci-management-cluster)
- [Create a Kubernetes cluster (Target cluster)](#create-a-kubernetes-cluster-target-cluster)
- [Integrate with Azure Arc](#integrate-with-azure-arc)
- [Next Steps](#next-steps)
- [Product improvements](#product-improvements)
- [Raising issues](#raising-issues)

*******************************************************************************************************

### Important Note ###

In this step, you'll be using PowerShell to deploy AKS on Azure Stack HCI. If you prefer to use Windows Admin Center, which may provide more familiarity, head on over to the [Windows Admin Center guide](/eval/steps/2a_DeployAKSHCI_WAC.md).

*******************************************************************************************************

Architecture
-----------

From an architecture perspective, as shown earlier, this graphic showcases the different layers and interconnections between the different components:

![Architecture diagram for AKS on Azure Stack HCI in Azure](/eval/media/nested_virt_arch_ga2.png "Architecture diagram for AKS on Azure Stack HCI in Azure")

You've already deployed the outer box , which represents the Azure Resource Group. Inside here, you've deployed the virtual machine itself, and accompaying network adapter, storage and so on. You've also completed some host configuration

In this section, you'll first deploy the management cluster. This provides the the core orchestration mechanism and interface for deploying and managing one or more target clusters, which are shown on the right of the diagram. These target, or workload clusters contain worker nodes and are where application workloads run. These are managed by a management cluster. If you're interested in learning more about the building blocks of the Kubernetes infrastructure, you can [read more here](https://docs.microsoft.com/en-us/azure-stack/aks-hci/kubernetes-concepts "Kubernetes core concepts for Azure Kubernetes Service on Azure Stack HCI").

Prepare environment
-----------
Before you deploy AKS on Azure Stack HCI, there are a few steps required to prepare your host, including downloading the latest PowerShell packages and modules along with cleanup of any existing artifacts to ensure you're starting from a clean slate. First, you'll install pre-requisite Powershell packages and modules.

1. Run the following **PowerShell command as administrator**, accepting any prompts:

```powershell
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-PackageProvider -Name NuGet -Force 
Install-Module -Name PowershellGet -Force
Exit
```

2. Open a new **administrative PowerShell console**, and run the following to install the required PowerShell module and dependencies:

```powershell
Install-Module -Name AksHci -Repository PSGallery -AcceptLicense -Force
```

3. Once complete, if you haven't already, make sure you **close all PowerShell windows**

Optional - Enable/Disable DHCP
-----------
Static IP configurations are supported for deployment of the management cluster and workload clusters. When you deployed your Azure VM, DHCP was installed and configured automatically for you, but you had the chance to control whether it was enabled or disabled on your Windows Server host OS. If you want to adjust DHCP now, make changes to the **$dhcpState** below and run the following **PowerShell command as administrator**:

```powershell
# Check current DHCP state for Active/Inactive
Get-DhcpServerv4Scope -ScopeId 192.168.0.0
# Adjust DHCP state if required
$dhcpState = "Active" # Or Inactive
Set-DhcpServerv4Scope -ScopeId 192.168.0.0 -State $dhcpState -Verbose
```

Enable Azure integration
-----------
Before downloading and deploying AKS on Azure Stack HCI, there are a set of steps that are required to prepare your Azure environment for integration. This can be performed using Azure CLI, but for the purpose of this guide, you will be using PowerShell

Now, seeing as you're deploying this evaluation in Azure, it assumes you already have a valid Azure subscription, but to confirm, in order to integrate AKS on Azure Stack HCI with an Azure subscription, you will need the following:

* An Azure subscription with **at least one** of the following:
   1. A user account with the built-in **Owner** role 
   2. A Service Principal with either the built-in **Kubernetes Cluster - Azure Arc Onboarding** (Minimum), built-in **Contributer** role or built-in **Owner** role

#### Optional - Create a new Service Principal ####

If you need to create a new Service Principal, the following steps will create a new Service Principal, with the built-in **Kubernetes Cluster - Azure Arc Onboarding** role and set the scope at the subscription level.

```powershell
# Login to Azure
Connect-AzAccount

# Optional - if you wish to switch to a different subscription
# First, get all available subscriptions as the currently logged in user
$subList = Get-AzSubscription
# Display those in a grid, select the chosen subscription, then press OK.
if (($subList).count -gt 1) {
    $subList | Out-GridView -OutputMode Single | Set-AzContext
}

# Retrieve the current subscription ID
$sub = (Get-AzContext).Subscription.Id

# Create a unique name for the Service Principal
$date = (Get-Date).ToString("MMddyy-HHmmss")
$spName = "AksHci-SP-$date"

# Create the Service Principal

$sp = New-AzADServicePrincipal -DisplayName $spName `
    -Role 'Kubernetes Cluster - Azure Arc Onboarding' `
    -Scope "/subscriptions/$sub"

# Retrieve the password for the Service Principal

$secret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret)
)

Write-Host "Application ID: $($sp.ApplicationId)"
Write-Host "App Secret: $secret"
```

From the above output, you have the **Application ID** and the **secret** for use when deploying AKS on Azure Stack HCI, so take a note of those and store them safely.

With that created, in the **Azure portal**, under **Subscriptions**, **Access **Control****, and then **Role Assignments**, you should see your new Service Principal.

![Service principal shown in Azure](/eval/media/akshci-spcreated.png "Service principal shown in Azure")

#### Register the resource provider to your subscription ####
Ahead of the registration process, you need to enable the appropriate resource provider in Azure for AKS on Azure Stack HCI integration. To do that, run the following PowerShell commands:

```powershell
# Login to Azure
Connect-AzAccount

# Optional - if you wish to switch to a different subscription
# First, get all available subscriptions as the currently logged in user
$subList = Get-AzSubscription
# Display those in a grid, select the chosen subscription, then press OK.
if (($subList).count -gt 1) {
    $subList | Out-GridView -OutputMode Single | Set-AzContext
}

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration
```

This registration process can take up to 10 minutes, so please be patient. It only needs to be performed once on a particular subscription. To validate the registration process, run the following PowerShell command:

```powershell
Get-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Get-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration
```

![Resource Provider enabled in Azure](/eval/media/akshci_rp_enable.png "Resource Provider enabled Azure")

With those steps completed, you're ready to deploy the AKS management cluster, onto your Windows Server Hyper-V host.

Deploying AKS on Azure Stack HCI management cluster
-----------
You're now ready to deploy the AKS on Azure Stack HCI management cluster onto your Windows Server Hyper-V host.

1. Open **PowerShell as Administrator** and run the following command to import the new modules, and list their functions. If you receive an error while running these commands, ensure you **closed all PowerShell windows earlier** and run them in a fresh administrative PowerShell console.

```powershell
Import-Module AksHci
Get-Command -Module AksHci
```

![Output of Get-Command -Module AksHci](/eval/media/get_module_functions.png "Output of Get-Command -Module AksHci")

As you can see, there are a number of functions that the module provides, from retrieving information, installing and deploying AKS and Kubernetes clusters, updating and scaling, and cleanup. We'll explore a number of these functions as we move through the steps.

2. Next, it's important to validate your single node to ensure it meets all the requirements to install AKS on Azure Stack HCI. Run the following command in your **administrative PowerShell** window:

```powershell
Initialize-AksHciNode
```

PowerShell remoting and WinRM will be configured, if they haven't been already, and the relevant roles and features are validated. Deployment of the Azure VM automatically installed Hyper-V and the RSAT clustering PowerShell tools so you should be good to proceed. If anything is missing, the process will install/configure the missing components, which may require you to reboot your Azure VM.

Next, you'll configure your deployment by defining the configuration settings for the AKS management cluster.

3. In your **administrative PowerShell** window, run the following commands to create some folders that will be used during the deployment process:

```powershell
New-Item -Path "V:\" -Name "AKS-HCI" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "Images" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "WorkingDir" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "Config" -ItemType "directory" -Force
```

4. With these folders created, you're almost ready to create your configuration settings. Before doing so, you need to create a **networking configuration for AKS on Azure Stack HCI to use** - please refer to the 2 options below, and **choose the one that matches your host configuration**:

#### If you wish to use DHCP-issued IP addresses ####
Run the following command in your **administrative PowerShell window**:

```powershell
$vnet = New-AksHciNetworkSetting -Name "mgmtvnet" -vSwitchName "InternalNAT" `
    -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
```

#### If you wish to use Static IP addresses ####
Run the following command in your **administrative PowerShell window**:

```powershell
$vnet = New-AksHciNetworkSetting -Name "mgmtvnet" -vSwitchName "InternalNAT" -gateway "192.168.0.1" -dnsservers "192.168.0.1" `
    -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.3" -k8snodeippoolend "192.168.0.149" `
    -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
```

5. With the **networking configuration** defined, you can now finalize the configuration of your AKS on Azure Stack HCI deployment

```powershell
Set-AksHciConfig -vnet $vnet -imageDir "V:\AKS-HCI\Images" -workingDir "V:\AKS-HCI\WorkingDir" `
-cloudConfigLocation "V:\AKS-HCI\Config" -Verbose
```

This command will take a few moments to complete, but once done, you should see confirmation that the configuration has been saved.

![Output of Set-AksHciConfig](/eval/media/akshci_config_new.png "Output of Set-AksHciConfig")

*******************************************************************************************************

**NOTE** - If you're interested in learning more about some of the other parameters that can be used when defining your configuration, make sure you take a [look at the official documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/setup-powershell#step-3-configure-your-deployment "Official documentation for defining your configuration file").

*******************************************************************************************************

Now, if you make a mistake, simply run **Set-AksHciConfig** without any parameters, and that will reset your configuration.

6. With the configuration files finalized, you need to **finalize the registration configuration**. From your **administrative PowerShell** window, run the following commands:

```powershell
# Login to Azure
Connect-AzAccount

# Optional - if you wish to switch to a different subscription
# First, get all available subscriptions as the currently logged in user
$subList = Get-AzSubscription
# Display those in a grid, select the chosen subscription, then press OK.
if (($subList).count -gt 1) {
    $subList | Out-GridView -OutputMode Single | Set-AzContext
}

# Retrieve the subscription and tenant ID
$sub = (Get-AzContext).Subscription.Id
$tenant = (Get-AzContext).Tenant.Id

# First create a resource group in Azure that will contain the registration artifacts
$rg = (New-AzResourceGroup -Name AksHciAzureEval -Location "East US" -Force).ResourceGroupName
```
7. You then need to run the **Set-AksHciRegistration** command, and this will vary depending on the type of login you prefer:

```powershell
# For an Interactive Login with a user account:
Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg

# For a device login or if you are running in a headless shell, again with a user account:
Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg -UseDeviceAuthentication

# To use your Service Principal, first enter your Service Principal credentials (app ID, secret) then set the registration
$cred = Get-Credential
Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg -TenantId $tenant -Credential $cred
```

After you've configured your deployment, you're now ready to start the installation process, which will install the AKS on Azure Stack HCI management cluster.

8. From your **administrative PowerShell** window, run the following command:

```powershell
Install-AksHci
```

This will take a few minutes, so please be patient and allow the process to finish.

### Updates and Cleanup ###
To learn more about **updating**, **redeploying** or **uninstalling** AKS on Azure Stack HCI, you can [read the official documentation here.](https://docs.microsoft.com/en-us/azure-stack/aks-hci/setup-powershell#update-to-the-latest-version-of-azure-kubernetes-service-on-azure-stack-hci "Official documentation on updating, redeploying and uninstalling AKS on Azure Stack HCI")

Create a Kubernetes cluster (Target cluster)
-----------
With the management cluster deployed successfully, you're ready to move on to deploying Kubernetes clusters that can host your workloads.  We'll then briefly walk through how to scale your Kubernetes cluster and upgrade the Kubernetes version of your cluster.

1. Open **PowerShell as Administrator** and run the following command to check the available versions of Kubernetes that are currently available:

```powershell
# Show available Kubernetes versions
Get-AksHciKubernetesVersion
```

In the output, you'll see a number of available versions across both Windows and Linux:

![Output of Get-AksHciKubernetesVersion](/eval/media/get_akshcikubernetesversion.png "Output of Get-AksHciKubernetesVersion")

2. You can then run the following command to **create and deploy a new Kubernetes cluster**:

```powershell
New-AksHciCluster -Name akshciclus001 -nodePoolName linuxnodepool -controlPlaneNodeCount 1 -nodeCount 1 -osType linux
```

This command will deploy a new Kubernetes cluster named **akshciclus001** with the following:

* A single Control Plane node (VM)
* A single Load Balancer VM
* A single Node Pool called linuxnodepool, containing a single Linux worker node (VM)

This is fine for evaluation purposes to begin with. There are a number of optional parameters that you can add here if you wish:

* **-kubernetesVersion** - by default, the deployment will use the latest, but you can specify a version
* **-controlPlaneVmSize** - Size of the control plane VM. Default is Standard_A2_v2.
* **-loadBalancerVmSize** - Size of your load balancer VM. Default is Standard_A2_V2
* **-nodeVmSize** - Size of your worker node VM. Default is Standard_K8S3_v1

For more parameters that you can use with New-AksHciCluster, refer to the [official documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/reference/ps/new-akshcicluster "official documentation"). To get a list of available VM sizes, run **Get-AksHciVmSize**

____________________

### Node Pools, Taints and Max Pod Counts ###

If you're not familiar with the concept of **node pools**, a node pool is a **group of nodes**, or virtual machines that run your applications, within a Kubernetes cluster that have the same configuration, giving you more granular control over your clusters. You can deploy multiple Windows node pools and multiple Linux node pools of different sizes, within the same Kubernetes cluster.

Another configuration option that can be applied to a node pool is the concept of **taints**. A taint can be specified for a particular node pool at both cluster and node pool creation time, and essential allow you to prevent pods being placed on specific nodes based on characteristics that you specify. You can learn more about [taints here](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ "Information about taints").

This guide doesn't require you to specify a taint, but if you do wish to explore the commands for adding a taint to a node pool, make sure you read the [official docs](https://docs.microsoft.com/en-us/azure-stack/aks-hci/use-node-pools#specify-a-taint-for-a-node-pool "Official docs on taints").

In addition to taints, we have recently added suport for configuring the **maximum number of pods** that can run on a node, with the **-nodeMaxPodCount** parameter. You can specify this parameter when creating a cluster, or when creating a new node pool, **and the number has to be greater than 50**.

_____________________

The deployment of this Kubernetes workload cluster should take a few minutes, and once complete, should present information about the deployment, however you can verify the details by running the following command:

```powershell
Get-AksHciCluster
```

![Output of Get-AksHciCluster](/eval/media/get_akshcicluster_sept.png "Output of Get-AksHciCluster")

____________

**NOTE** - For more information about the node pool, please use the command Get-AksHciNodePool with the specified cluster name:

```powershell
Get-AksHciNodePool -clusterName akshciclus001
```

![Output of Get-AksHciNodePool](/eval/media/get_akshcinodepool_sept.png "Output of Get-AksHciNodePool")

____________

3. Next, you'll scale your Kubernetes cluster to **add a Windows Node Pool and worker node**. Note, this will trigger the download and extraction of a Windows container host image, which will take a few minutes, so please be patient.

```powershell
New-AksHciNodePool -clusterName akshciclus001 -name windowsnodepool -count 1 -osType windows
```

4. Next, you'll scale your Kubernetes cluster to have **2 Linux worker nodes**:

```powershell
Set-AksHciNodePool -clusterName akshciclus001 -name linuxnodepool -count 2
```

With your cluster scaled out, you can check the node pool status by running:

```powershell
Get-AksHciNodePool -clusterName akshciclus001
```

![Output of Get-AksHciNodePool](/eval/media/get_akshcinodepool2_sept.png "Output of Get-AksHciNodePool")

*******************************************************************************************************

**NOTE** - You can also scale your Control Plane nodes for this particular cluster, however it has to be **scaled independently from the worker nodes** themselves. You can scale the Control Plane nodes using the command. Before you run this command however, check that you have an extra 16GB memory left of your AKSHCIHost001 OS - if your host has been deployed with 64GB RAM, you may not have enough capacity for an additonal 2 Control Plane VMs.

```powershell
Set-AksHciCluster –Name akshciclus001 -controlPlaneNodeCount 3
```

**NOTE** - the control plane node count should be an **odd** number, such as 1, 3, 5 etc.

*******************************************************************************************************

5. Once these steps have been completed, you can verify the details by running the following command:

```powershell
Get-AksHciCluster
```

![Output of Get-AksHciCluster](/eval/media/get_akshcicluster_sept2.png "Output of Get-AksHciCluster")

To access this **akshciclus001** cluster using **kubectl** (which was installed on your host as part of the overall installation process), you'll first need the **kubeconfig file**.

6. To retrieve the kubeconfig file for the akshciclus001 cluster, you'll need to run the following command from your **administrative PowerShell** and accept the prompt when prompted:

```powershell
Get-AksHciCredential -Name akshciclus001 -Confirm:$false
dir $env:USERPROFILE\.kube
```

![Output of Get-AksHciCredential](/eval/media/get_akshcicred_sept.png "Output of Get-AksHciCredential")

The **default** output of this command is to create the kubeconfig file in **%USERPROFILE%\\.kube.** folder, and will name the file **config**. This **config** file will overwrite the previous kubeconfig file retrieved earlier. You can also specify a custom location by using **-configPath c:\myfiles\kubeconfig**

Integrate with Azure Arc
-----------
With your target cluster deployed and scaled, you can quickly and easily integrate this cluster with Azure Arc.

When an Azure Kubernetes Service on Azure Stack HCI cluster is attached to Azure Arc, it will get an Azure Resource Manager representation. Clusters are attached to standard Azure subscriptions, are located in a resource group, and can receive tags just like any other Azure resource. Also the Azure Arc-enabled Kubernetes representation allows for extending the following capabilities on to your Kubernetes cluster:

* Management services - Configurations (GitOps), Azure Monitor for containers, Azure Policy (Gatekeeper)
* Data Services - SQL Managed Instance, PostgreSQL Hyperscale
* Application services - App Service, Functions, Event Grid, Logic Apps, API Management

To connect a Kubernetes cluster to Azure, the cluster administrator needs to deploy agents. These agents run in a Kubernetes namespace named `azure-arc` and are standard Kubernetes deployments. The agents are responsible for connectivity to Azure, collecting Azure Arc logs and metrics, and enabling above-mentioned scenarios on the cluster.

Azure Arc-enabled Kubernetes supports industry-standard SSL to secure data in transit. Also, data is stored encrypted at rest in an Azure Cosmos DB database to ensure data confidentiality.

### Before you begin ###
If you didn't earlier, make sure you double-check the [requirements for integrating with Azure](#before-you-begin "Requirements for integrating with Azure").

### Enabling Azure Arc integration ###
In order to integrate your target cluster with Azure Arc, run the following commands.

```powershell
# Login to Azure
Connect-AzAccount

# Integrate your target cluster with Azure Arc
Enable-AksHciArcConnection -name akshciclus001
```

****************
**NOTE** - This example connects your target cluster to Azure Arc using the subscription ID and resource group passed in the **Set-AksHciRegistration** command when deploying AKS on Azure Stack HCI. If you wish to use alternative settings, [review the official documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/reference/ps/enable-akshciarcconnection "review the official documentation for Enable-AksHciArcConnection")
****************

### Verify connected cluster

You can view your Kubernetes cluster resource on the [Azure portal](https://portal.azure.com/). Once you have the portal open in your browser, navigate to the resource group and the Azure Arc-enabled Kubernetes resource that's based on the resource name and resource group name inputs used earlier in the [Enable-AksHciArcConnection](https://docs.microsoft.com/en-us/azure-stack/aks-hci/reference/ps/enable-akshciarcconnection) PowerShell command.

**************
**NOTE** - After connecting the cluster, it may take between five to ten minutes for the cluster metadata (cluster version, agent version, number of nodes) to surface on the overview page of the Azure Arc-enabled Kubernetes resource in Azure portal.

**************

To learn more about integrating with Azure Arc, head over to the [official documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/connect-to-arc)

### Updates and Cleanup ###
To learn more about **updating**, **redeploying** or **uninstalling** AKS on Azure Stack HCI, you can [read the official documentation here.](https://docs.microsoft.com/en-us/azure-stack/aks-hci/create-kubernetes-cluster-powershell#step-3-upgrade-kubernetes-version "Official documentation on updating, redeploying and uninstalling AKS on Azure Stack HCI")

Next Steps
-----------
In this step, you've successfully deployed the AKS on Azure Stack HCI management cluster, deployed and scaled a Kubernetes cluster and integrated with Azure Arc. You can now move forward to the next stage, in which you can deploy a sample application.

* [**Part 3** - Explore AKS on Azure Stack HCI](/eval/steps/3_ExploreAKSHCI.md "Explore AKS on Azure Stack HCI")

Product improvements
-----------
If, while you work through this guide, you have an idea to make the product better, whether it's something in AKS on Azure Stack HCI, Windows Admin Center, or the Azure Arc integration and experience, let us know! We want to hear from you! [Head on over to our AKS on Azure Stack HCI GitHub page](https://github.com/Azure/aks-hci/issues "AKS on Azure Stack HCI GitHub"), where you can share your thoughts and ideas about making the technologies better.  If however, you have an issue that you'd like some help with, read on... 

Raising issues
-----------
If you notice something is wrong with the evaluation guide, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  Raise an issue in GitHub, and we'll be sure to fix this as quickly as possible!

If however, you're having a problem with AKS on Azure Stack HCI **outside** of this evaluation guide, make sure you post to [our GitHub Issues page](https://github.com/Azure/aks-hci/issues "GitHub Issues"), where Microsoft experts and valuable members of the community will do their best to help you.