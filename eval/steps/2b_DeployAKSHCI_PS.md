Deploy your AKS-HCI infrastructure with PowerShell
==============
Overview
-----------
With your Windows Server 2019 Hyper-V host up and running, it's now time to deploy AKS on Azure Stack HCI. You'll first download the necessary artifacts, then deploy the AKS management cluster onto your Windows Server 2019 Hyper-V host, and finally, deploy a target cluster, onto which you can test deployment of a workload.

Contents
-----------
- [Overview](#overview)
- [Contents](#contents)
- [Architecture](#architecture)
- [Prepare environment](#prepare-environment)
- [Optional - Enable/Disable DHCP](#optional---enabledisable-dhcp)
- [Download artifacts](#download-artifacts)
- [Deploying AKS on Azure Stack HCI management cluster](#deploying-aks-on-azure-stack-hci-management-cluster)
- [Create a Kubernetes cluster (Target cluster)](#create-a-kubernetes-cluster-target-cluster)
- [Next Steps](#next-steps)
- [Product improvements](#product-improvements)
- [Raising issues](#raising-issues)

### Important Note ###

In this step, you'll be using PowerShell to deploy AKS on Azure Stack HCI. If you prefer to use Windows Admin Center, which may provide more familiarity, head on over to the [Windows Admin Center guide](/eval/steps/2a_DeployAKSHCI_WAC.md).

Architecture
-----------

From an architecture perspective, as shown earlier, this graphic showcases the different layers and interconnections between the different components:

![Architecture diagram for AKS on Azure Stack HCI in Azure](/eval/media/nested_virt_arch_ga.png "Architecture diagram for AKS on Azure Stack HCI in Azure")

You've already deployed the outer box , which represents the Azure Resource Group. Inside here, you've deployed the virtual machine itself, and accompaying network adapter, storage and so on. You've also completed some host configuration

In this section, you'll first deploy the management cluster. This provides the the core orchestration mechanism and interface for deploying and managing one or more target clusters, which are shown on the right of the diagram. These target, or workload clusters contain worker nodes and are where application workloads run. These are managed by a management cluster. If you're interested in learning more about the building blocks of the Kubernetes infrastructure, you can [read more here](https://docs.microsoft.com/en-us/azure-stack/aks-hci/kubernetes-concepts "Kubernetes core concepts for Azure Kubernetes Service on Azure Stack HCI").

Prepare environment
-----------
Before you deploy AKS on Azure Stack HCI, there are a few steps required to prepare your host, including downloading the latest PowerShell packages and modules along with cleanup of any existing artifacts to ensure you're starting from a clean slate. First, you'll install pre-requisite Powershell packages and modules.

1. Run the following **PowerShell command as administrator**:

```powershell
Install-PackageProvider -Name NuGet -Force 
Install-Module -Name PowershellGet -Force -Confirm:$false -SkipPublisherCheck
```

2. Still in the **administrative PowerShell console**, run the following to uninstall previous modules and unregister private powershell repositories:

```powershell
Uninstall-Module -Name AksHci -AllVersions -Force -ErrorAction:SilentlyContinue 
Uninstall-Module -Name Kva -AllVersions -Force -ErrorAction:SilentlyContinue 
Uninstall-Module -Name Moc -AllVersions -Force -ErrorAction:SilentlyContinue 
Uninstall-Module -Name MSK8SDownloadAgent -AllVersions -Force -ErrorAction:SilentlyContinue 
Unregister-PSRepository -Name WSSDRepo -ErrorAction:SilentlyContinue 
Unregister-PSRepository -Name AksHciPSGallery -ErrorAction:SilentlyContinue 
Unregister-PSRepository -Name AksHciPSGalleryPreview -ErrorAction:SilentlyContinue
Exit
```

3. Once complete, if you haven't already, make sure you **close all PowerShell windows**

Optional - Enable/Disable DHCP
-----------
Static IP configurations are supported for deployment of the management cluster and workload clusters. When you deployed your Azure VM, DHCP was installed and configured automatically for you, but you had the chance to control whether it was enabled or disabled on your Windows Server 2019 OS. If you want to adjust DHCP now, make changes to the **$dhcpState** below and run the following **PowerShell command as administrator**:

```powershell
# Check current DHCP state for Active/Inactive
Get-DhcpServerv4Scope -ScopeId 192.168.0.0
# Adjust DHCP state if required
$dhcpState = "Active" # Or Inactive
Set-DhcpServerv4Scope -ScopeId 192.168.0.0 -State $dhcpState -Verbose
```

Download artifacts
-----------
In order to deploy AKS on Azure Stack HCI, you'll need to register, and then download the public preview software.  Once downloaded, you'll extract the files, and copy them to their final destinations before starting the deployment.

1. Inside your **AKSHCIHOST001 VM**, open **Microsoft Edge** and navigate to https://aka.ms/AKS-HCI-Evaluate
2. Complete the registration form, and once completed, click on the **Download AKS on Azure Stack HCI** button to download the software
3. When prompted, click **Save as** and choose to save the ZIP file in your **Downloads folder**
4. With the download completed, open **File Explorer**, navigate to your **Downloads** folder
5. **Right-click** on the AKS-HCI zip file, click **Extract **All****, then in the popup window, click **Extract**
6. Inside the extracted folder should be a number of files.  **Right-click** the **AksHci.Powershell.ZIP**, click **Extract All**, then **Extract**
7. As these files have been downloaded from the internet, they may require **unblocking** to allow successful import later, so run the following **PowerShell command as administrator** to unblock all files:

```powershell
# Adjust the path to your extracted AKS-HCI download
$path = "C:\Users\AzureUser\Downloads\AKS-HCI-Public-Preview"
Get-ChildItem -Path $path -Recurse | Unblock-File -Verbose
```

8. With the files all unblocked, inside the extracted **AksHci.Powershell** folder, you should find 4 folders containing various PowerShell modules and components.

![4 folders containing various PowerShell modules and components](/eval/media/akshci_powershell_folders.png "4 folders containing various PowerShell modules and components")

9. Select all 4 folders, then **right-click** and **copy**, then navigate to **C:\Program Files\WindowsPowerShell\Modules** and **right-click**, and paste the 4 folders into their new location.

With those steps completed, you're ready to deploy the AKS management cluster, onto your Windows Server 2019 Hyper-V host.

Deploying AKS on Azure Stack HCI management cluster
-----------
You're now ready to deploy the AKS on Azure Stack HCI management cluster onto your Windows Server 2019 host.

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
New-Item -Path "V:\AKS-HCI\" -Name "Config" -ItemType "directory" -Force
```

4. With these folders created, you're almost ready to create your configuration settings. Before doing so, you need to create a **networking configuration for AKS on Azure Stack HCI to use** - please refer to the 2 options below, and **choose the one that matches your host configuration**:

#### If you wish to use DHCP-issued IP addresses ####
Run the following command in your **administrative PowerShell window**:

```powershell
$vnet = New-AksHciNetworkSetting -vnetName "InternalNAT" -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
```

#### If you wish to use Static IP addresses ####
Run the following command in your **administrative PowerShell window**:

```powershell
$vnet = New-AksHciNetworkSetting -vnetName "InternalNAT" -gateway "192.168.0.1" -dnsservers "192.168.0.1" `
    -ipaddressprefix "192.168.0.0/16" -k8snodeippoolstart "192.168.0.3" -k8snodeippoolend "192.168.0.149" `
    -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"
```

5. With the **networking configuration** defined, you can now finalize the configuration of your AKS on Azure Stack HCI deployment

```powershell
Set-AksHciConfig -vnet $vnet -imageDir "V:\AKS-HCI\Images" -cloudConfigLocation "V:\AKS-HCI\Config" `
    -enableDiagnosticData -Verbose
```

This command will take a few moments to complete, but once done, you should see confirmation that the configuration has been saved.

![Output of Set-AksHciConfig](/eval/media/akshci_config_new.png "Output of Set-AksHciConfig")

**NOTE** - If you're interested in learning more about some of the other parameters that can be used when defining your configuration, make sure you take a [look at the official documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/setup-powershell#step-3-configure-your-deployment "Official documentation for defining your configuration file").

Now, if you make a mistake, simply run **Set-AksHciConfig** without any parameters, and that will reset your configuration.

After you've configured your deployment, you're now ready to start the installation process, which will install the AKS on Azure Stack HCI management cluster.

1. From your **administrative PowerShell** window, run the following command:

```powershell
Install-AksHci
```

This will take a few minutes.

7. Once deployment is completed, you can verify the details by running the following command:

```powershell
Get-AksHciCluster
```

Your output should look like this:

![Output of Get-AksHciCluster](/eval/media/get_akshcicluster_new.png "Output of Get-AksHciCluster")

With the cluster verified, if you'd like to access the cluster using **kubectl** (which was installed on your host as part of the overall installation process), you'll first need a **kubeconfig file**.

8. To retrieve the kubeconfig file, you'll need to run the following commands from your **administrative PowerShell**:

```powershell
Get-AksHciCredential -Name clustergroup-management
dir $env:USERPROFILE\.kube
```

![Output of Get-AksHciCredential](/eval/media/get_akshcicred.png "Output of Get-AksHciCredential")

The **default** output of this command is to create the kubeconfig file in **%USERPROFILE%\\.kube.** folder, and will name the file **config**, as you can see in the above image. This is important, because if you choose to run Get-AksHciCredential again, against a different cluster, this **config** file will be **overwritten**.

### Updates and Cleanup ###
To learn more about **updating**, **redeploying** or **uninstalling** AKS on Azure Stack HCI, you can [read the official documentation here.](https://docs.microsoft.com/en-us/azure-stack/aks-hci/setup-powershell#update-to-the-latest-version-of-azure-kubernetes-service-on-azure-stack-hci "Official documentation on updating, redeploying and uninstalling AKS on Azure Stack HCI")

Create a Kubernetes cluster (Target cluster)
-----------
With the management cluster deployed successfully, you're ready to move on to deploying Kubernetes clusters that can host your workloads.  We'll then briefly walk through how to scale your Kubernetes cluster and upgrade the Kubernetes version of your cluster.

1. Open **PowerShell as Administrator** and run the following command to check the available versions of Kubernetes that are currently available:

```powershell
# Allow PowerShell to show more than 4 versions in the output
$FormatEnumerationLimit = -1
Get-AksHciKubernetesVersion
```

In the output, you'll see a number of available versions across both Windows and Linux:

![Output of Get-AksHciKubernetesVersion](/eval/media/get_akshcikubernetesversion.png "Output of Get-AksHciKubernetesVersion")

2. You can then run the following command to **create and deploy a new Kubernetes cluster**:

```powershell
New-AksHciCluster -Name akshciclus001 -controlPlaneNodeCount 1 -linuxNodeCount 1 -windowsNodeCount 0
```

This command will deploy a new Kubernetes cluster named **akshciclus001** with a single control plane node, and a single Linux worker node, which is fine for evaluation purposes to begin with. There are a number of optional parameters that you can add here if you wish:

* **-kubernetesVersion** - by default, the deployment will use the latest, but you can specify a version
* **-controlPlaneVmSize** - Size of the control plane VM. Default is Standard_A2_v2.
* **-loadBalancerVmSize** - Size of your load balancer VM. Default is Standard_A2_V2
* **-linuxNodeVmSize** - Size of your Linux Node VM. Default is Standard_K8S3_v1
* **-windowsNodeVmSize** - Size of your Windows Node VM. Default is Standard_K8S3_v1

To get a list of available VM sizes, run **Get-AksHciVmSize**

The deployment of this Kubernetes workload cluster should take a few minutes, and once complete, should present an output like this:

3. Once deployment is completed, you can verify the details by running the following command:

```powershell
Get-AksHciCluster
```

Notice that this time, this command lists both the management cluster and also the new workload cluster.

![Output of Get-AksHciCluster](/eval/media/get_akshcicluster_2.png "Output of Get-AksHciCluster")

1. Next, you'll scale your Kubernetes cluster to **add a Windows worker node**. Note, this will trigger the download and extraction of a Windows container host image, which will take a few minutes, so please be patient.

```powershell
Set-AksHciClusterNodeCount –Name akshciclus001 -linuxNodeCount 1 -windowsNodeCount 1
```

5. Next, you'll scale your Kubernetes cluster to have **2 Linux worker nodes**:

```powershell
Set-AksHciClusterNodeCount –Name akshciclus001 -linuxNodeCount 2 -windowsNodeCount 1
```

**NOTE** - You can also scale your Control Plane nodes for this particular cluster, however it has to be **scaled independently from the worker nodes** themselves. You can scale the Control Plane nodes using the command:

```powershell
Set-AksHciClusterNodeCount –Name akshciclus001 -controlPlaneNodeCount 3
```

**NOTE** - the control plane node count should be an **odd** number, such as 1, 3, 5 etc.

5. Once these steps have been completed, you can verify the details by running the following command:

```powershell
Get-AksHciCluster
```

![Output of Get-AksHciCluster](/eval/media/get_akshcicluster_3.png "Output of Get-AksHciCluster")

To access this **akshciclus001** cluster using **kubectl** (which was installed on your host as part of the overall installation process), you'll first need the **kubeconfig file**.

6. To retrieve the kubeconfig file for the akshciclus001 cluster, you'll need to run the following command from your **administrative PowerShell**:

```powershell
Get-AksHciCredential -Name akshciclus001
dir $env:USERPROFILE\.kube
```

![Output of Get-AksHciCredential](/eval/media/get_akshcicred_2.png "Output of Get-AksHciCredential")

As we saw earlier, the **default** output of this command is to create the kubeconfig file in **%USERPROFILE%\\.kube.** folder, and will name the file **config**. This **config** file will overwrite the previous kubeconfig file for the management cluster retrieved earlier.

### Updates and Cleanup ###
To learn more about **updating**, **redeploying** or **uninstalling** AKS on Azure Stack HCI, you can [read the official documentation here.](https://docs.microsoft.com/en-us/azure-stack/aks-hci/create-kubernetes-cluster-powershell#step-3-upgrade-kubernetes-version "Official documentation on updating, redeploying and uninstalling AKS on Azure Stack HCI")

Next Steps
-----------
In this step, you've successfully deployed the AKS on Azure Stack HCI management cluster, and subsequently, deployed and scaled a Kubernetes cluster that you can move forward with to the next stage, in which you can deploy your applications, and optionally, integrate with Azure Arc.

* [**Part 3** - Explore AKS on Azure Stack HCI](/eval/steps/3_ExploreAKSHCI.md "Explore AKS on Azure Stack HCI")

Product improvements
-----------
If, while you work through this guide, you have an idea to make the product better, whether it's something in AKS on Azure Stack HCI, Windows Admin Center, or the Azure Arc integration and experience, let us know! We want to hear from you! [Head on over to our AKS on Azure Stack HCI GitHub page](https://github.com/Azure/aks-hci/issues "AKS on Azure Stack HCI GitHub"), where you can share your thoughts and ideas about making the technologies better.  If however, you have an issue that you'd like some help with, read on... 

Raising issues
-----------
If you notice something is wrong with the evaluation guide, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  Raise an issue in GitHub, and we'll be sure to fix this as quickly as possible!

If however, you're having a problem with AKS on Azure Stack HCI **outside** of this evaluation guide, make sure you post to [our GitHub Issues page](https://github.com/Azure/aks-hci/issues "GitHub Issues"), where Microsoft experts and valuable members of the community will do their best to help you.
