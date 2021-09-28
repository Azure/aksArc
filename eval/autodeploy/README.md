AKS on Azure Stack HCI in Azure - Full Auto Edition
==============

Have you already walked through the deployment of AKS on Azure Stack HCI both with PowerShell and Windows Admin Center? If so, and you don't want to walk through those steps again for future deployments...fear not, we have a solution!

The **AKS on Azure Stack HCI in Azure - Full Auto Edition** saves you time, and effort in deploying AKS on Azure Stack HCI in an Azure VM, for evaluation purposes. Simply provide some parameters via the Azure Portal or PowerShell, wait around 45 minutes, and you'll have a complete AKS-HCI infrastructure, including a target cluster, integrated with Azure Arc! BOOM!

This guide will walk you through all the pre-requisites you need, and the steps you need to perform to configure your end-to-end deployment of AKS-HCI.

Version
-----------
This guide has been tested and validated with the **August 2021 release** of AKS on Azure Stack HCI.

Contents
-----------
- [Version](#version)
- [Contents](#contents)
- [What is AKS on Azure Stack HCI?](#what-is-aks-on-azure-stack-hci)
- [Why follow this guide?](#why-follow-this-guide)
- [Evaluate AKS on Azure Stack HCI using Nested Virtualization](#evaluate-aks-on-azure-stack-hci-using-nested-virtualization)
- [Deployment Overview](#deployment-overview)
- [Before you deploy](#before-you-deploy)
- [Deploying the Azure VM](#deploying-the-azure-vm)
- [Access your Azure VM](#access-your-azure-vm)
- [Next Steps](#next-steps)
- [Troubleshooting](#troubleshooting)
- [Product improvements](#product-improvements)
- [Raising issues](#raising-issues)

What is AKS on Azure Stack HCI?
-----------

If you've landed on this page, and you're still wondering what AKS on Azure Stack HCI is, Azure Kubernetes Service on Azure Stack HCI is an on-premises implementation of Azure Kubernetes Service (AKS), which automates running containerized applications at scale. Azure Kubernetes Service is now available on Azure Stack HCI 20H2 and Windows Server 2019 Datacenter-based clusters, making it quicker to get started hosting Linux and Windows containers in your datacenter.

If you're interested in learning more about what AKS on Azure Stack HCI is, make sure you [check out the official documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/overview "What is Azure Kubernetes Service on Azure Stack HCI documentation"), before coming back to continue your evaluation experience. We'll refer to the docs in various places in the guide, to help you build your knowledge of AKS on Azure Stack HCI.

Why follow this guide?
-----------

This evaluation guide will walk you through **automating** the deployment of a sandboxed, isolated AKS on Azure Stack HCI environment using **nested virtualization** in Azure. Whilst not designed as a production scenario, the important takeaway here is, by following this guide, you'll lay down a solid foundation on to which you can explore additional AKS on Azure Stack HCI scenarios in the future, so keep checking back for additional scenarios over time.

**If you haven't deployed AKS on Azure Stack HCI before, it's worthwhile going through documentation, to ensure you understand what's happening under the covers:**

* Deploy AKS-HCI with Windows Admin Center](https://docs.microsoft.com/azure-stack/aks-hci/setup) 
* Deploy AKS-HCI with PowerShell](https://docs.microsoft.com/azure-stack/aks-hci/kubernetes-walkthrough-powershell)

Evaluate AKS on Azure Stack HCI using Nested Virtualization
-----------

As with any infrastructure technology, in order to test, validate and evaluate the technology, there's typically a requirement for hardware.  If you're fortunate enough to have multiple server-class pieces of hardware going spare (ideally hardware validated for Azure Stack HCI, found on our [Azure Stack HCI Catalog](https://aka.ms/azurestackhcicatalog "Azure Stack HCI Catalog")), you can certainly perform a more real-world evaluation of AKS on Azure Stack HCI. For those that don't have spare hardware, using nested virtualization can be a great alternative for evaluation.

If you're not familiar with nested virtualization, at a high level, it allows a virtualization platform, such as Hyper-V, or VMware ESXi, to run virtual machines that, within those virtual machines, run a virtualization platform. It may be easier to think about this in an architectural view.

![Nested virtualization architecture](/eval/media/nested_virt.png "Nested virtualization architecture")

*******************************************************************************************************

### Important Note ###
The use of nested virtualization in this evaluation guide is aimed at providing flexibility for **evaluating AKS on Azure Stack HCI in test environment**, and it shouldn't be seen as a substitute for real-world deployments, performance and scale testing etc. With each level of nesting, comes the trade-off of performance, hence for **production** use, **AKS on Azure Stack HCI should be deployed on validated physical hardware**, of which you can find a vast array of choices on the [Azure Stack HCI Catalog](https://aka.ms/azurestackhcicatalog "Azure Stack HCI Catalog") or the [Windows Server Catalog](https://www.windowsservercatalog.com/results.aspx?bCatID=1283&cpID=0&avc=126&ava=0&avq=0&OR=1&PGS=25 "Windows Server Catalog") for systems running Windows Server 2019 Datacenter edition.

*******************************************************************************************************

Deployment Overview
-----------
This guide will focus on the end-to-end, automated deployment of AKS on Azure Stack HCI, running on a single Azure VM, using the power of **nested virtualization**. If you've not yet experienced walking through a deployment of AKS-HCI, either with PowerShell, or Windows Admin Center, it's recommended you start there to better understand what this automated deployment will handle for you.

![Architecture diagram for AKS on Azure Stack HCI nested in Azure](/eval/media/nested_virt_arch_ga2.png "Architecture diagram for AKS on Azure Stack HCI nested in Azure")

In this configuration, you'll take advantage of the nested virtualization support provided within certain Azure VM sizes. By following these steps, the ARM template will first deploy a single Azure VM running Windows Server 2019 Datacenter, and then begin the automated customization inside this VM, including all the necessary roles and features, before moving on to automatically installing AKS-HCI, creating a target cluster, and integrating with Azure Arc. All of this, in a single Azure VM!

*******************************************************************************************************

### Important Note ###
The steps outlined in this evaluation guide are **specific to this automated deployment, running in an Azure VM**, running a single Windows Server 2019 OS, without a domain environment configured. If you plan to try to use these steps in an alternative environment, such as one nested/physical on-premises, or in a domain-joined environment, the steps may differ and certain procedures may not work. If that is the case, please refer to the [official documentation to deploy AKS on Azure Stack HCI](https://docs.microsoft.com/en-us/azure-stack/aks-hci/ "official documentation to deploy AKS on Azure Stack HCI").

*******************************************************************************************************

Before you deploy
-----------

Before you start the deployment of your automated AKS-HCI configuration, there's a number of things to verify, in addition to cofiguring a few artifacts ahead of deployment.

### Get an Azure subscription ###

To evaluate AKS on Azure Stack HCI in Azure, you'll need an Azure subscription on which you're an **owner** or **contributor**. To check your access level, navigate to your subscription, click **Access control (IAM)** on the left-hand side of the Azure portal, and then click **View my access**.

If you already have a subscription with the above access levels provided by your company, you can skip this step. If not, you have a couple of options:

- The first option would apply to Visual Studio subscribers, where you can use Azure at no extra charge. With your monthly Azure DevTest individual credit, Azure is your personal sandbox for dev/test. You can provision virtual machines, cloud services, and other Azure resources. Credit amounts vary by subscription level, but if you manage your AKS on Azure Stack HCI Host VM run-time efficiently, you can test the scenario well within your subscription limits.

- The second option would be to sign up for a [free trial](https://azure.microsoft.com/en-us/free/ "Azure free trial link"), which gives you $200 credit for the first 30 days, and 12 months of popular services for free. The credit for the first 30 days will give you plenty of headroom to validate AKS on Azure Stack HCI.


### Azure VM Size Considerations ###

Now, before you deploy the VM in Azure, it's important to choose a **size** that's appropriate for your needs for this evaluation, along with a preferred region. It's highly recommended to choose a VM size that has **at least 64GB memory**. This deployment, by default, recommends using a **Standard_E16s_v4**, which is a memory-optimized VM size, with 16 vCPUs, 128 GiB memory, and no temporary SSD storage. The OS drive will be the default 127 GiB in size and the Azure VM deployment will add an additional 8 data disks (32 GiB each by default), so you'll have around 256GiB to deploy AKS on Azure Stack HCI. You can also make this larger after deployment, if you wish.

This is just one VM size that we recommend - you can adjust accordingly to suit your needs, even after deployment. The point here is, think about how large an AKS on Azure Stack HCI infrastructure you'd like to deploy inside this Azure VM, and select an Azure VM size from there. Some potential examples would be:

**D-series VMs (General purpose) with at least 64GB memory**

| Size | vCPU | Memory: GiB | Temp storage (SSD): GiB | Premium Storage |
|:--|---|---|---|---|
| Standard_D16s_v3  | 16  | 64 | 128 | Yes |
| Standard_D16_v4  | 16  | 64 | 0 | No |
| **Standard_D16s_v4**  | **16**  | **64**  | **0**  | **Yes** |
| Standard_D16d_v4 | 16 | 64  | 600 | No |
| Standard_D16ds_v4 | 16 | 64 | 600 | Yes |

For reference, the Standard_D16s_v4 VM size costs approximately US $0.77 per hour based on East US region, under a Visual Studio subscription.

**E-series VMs (Memory optimized - Recommended for AKS on Azure Stack HCI) with at least 64GB memory**

| Size | vCPU | Memory: GiB | Temp storage (SSD): GiB | Premium Storage |
|:--|---|---|---|---|
| Standard_E8s_v3  | 8  | 64  | 128  | Yes  |
| Standard_E8_v4  | 8  | 64  | 0  | No |
| **Standard_E8s_v4**  | **8**  | **64**  | **0**  | **Yes** |
| Standard_E8d_v4 | 8 | 64  | 300  | No |
| Standard_E8ds_v4 | 8 | 64 | 300  | Yes |
| Standard_E16s_v3  | 16  | 128 | 256 | Yes |
| **Standard_E16s_v4**  | **16**  | **128**  | **0**  | **Yes** |
| Standard_E16d_v4 | 16 | 128  | 600 | No |
| Standard_E16ds_v4 | 16 | 128 | 600 | Yes |

For reference, the Standard_E8s_v4 VM size costs approximately US $0.50 per hour based on East US region, under a Visual Studio subscription.

*******************************************************************************************************

**NOTE 1** - A number of these VM sizes include temp storage, which offers high performance, but is not persistent through reboots, Azure host migrations and more. It's therefore advisable, that if you are going to be running the Azure VM for a period of time, but shutting down frequently, that you choose a VM size with no temp storage, and ensure your nested VMs are placed on the persistent data drive within the OS.

**NOTE 2** - It's strongly recommended that you choose a VM size that supports **premium storage** - when running nested virtual machines, increasing the number of available IOPS can have a significant impact on performance, hence choosing **premium storage** over Standard HDD or Standard SSD, is strongly advised. Refer to the table above to make the most appropriate selection.

**NOTE 3** - Please ensure that whichever VM size you choose, it [supports nested virtualization](https://docs.microsoft.com/en-us/azure/virtual-machines/acu "Nested virtualization support") and is [available in your chosen region](https://azure.microsoft.com/en-us/global-infrastructure/services/?products=virtual-machines "Virtual machines available by region").

*******************************************************************************************************


### Create a Service Principal with required permissions ###

In addition to having the correct permissions for your user account that you wish to use to deploy the sandbox environment, the automated deployment **requires** the creation and use of a **Service Principal** in order to perform some of the automated tasks in the deployment. One of the uses of the Service Principal is to connect your AKS on Azure Stack HCI environment with Azure, and integrate with Azure Arc.

Note that only subscription **owners** can create service principals with the right role assignment. You can check your access level by navigating to your subscription, clicking on **Access control (IAM)** on the left hand side of the Azure portal and then clicking on **View my access**. If you do not have **owner** access on your subscription, skip creating a service principal and ask your subscription admin to create a service principal following the steps below.

The following commands will create a new Service Principal, with the built-in **Kubernetes Cluster - Azure Arc Onboarding** role and set the scope at the subscription level. The script will also assign the Service Principal the **Virtual Machine Contributer** role, which is required specifically for the automated deployment of this sandbox, and not for AKS-HCI itself.

You can optionally adjust **$spName** to a more preferred name for your Service Principal.

```powershell
# Login to Azure
Connect-AzAccount

# Set the subscription on which you have "owner" access AND want to use for deploying AKS-HCI:
$sub = "<my Azure subscription on which I'm an owner>"

# Create a unique name for the Service Principal
$date = (Get-Date).ToString("MMddyy-HHmmss")
$spName = "AksHci-SP-$date"

# Create the Service Principal
$sp = New-AzADServicePrincipal -DisplayName $spName `
    -Role 'Kubernetes Cluster - Azure Arc Onboarding' `
    -Scope "/subscriptions/$sub"

New-AzRoleAssignment -ObjectId $sp.ObjectId `
    -RoleDefinitionName "Virtual Machine Contributor" `
    -Scope "/subscriptions/$sub"

# Retrieve the password for the Service Principal
$secret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret)
)

Write-Host "Application ID: $($sp.ApplicationId)"
Write-Host "App Secret: $secret"
```

From the above output, you have the **Application ID** and the **secret** for use when deploying the automated AKS on Azure Stack HCI sandbox, so take a note of those and store them safely.

With that created, in the **Azure portal**, under **Subscriptions**, **Access Control**, and then **Role Assignments**, you should see your new Service Principal.

![Service principal shown in Azure](/eval/media/akshci-spcreated.png "Service principal shown in Azure")

With the Service Principal created, you can verify that the Service Principal has the appropriate permissions in Azure Active Directory by logging into the **Azure portal**, under **Azure Active Directory**, **App Registrations**, and then **All Applications**, you should see your new Service Principal listed. Click on your Service Principal, then click on **Roles and administrators**. The Service Principal should have the built-in **Cloud application administrator** role, as shown in the scren below.

![Service principal permissions shown in Azure AD](/eval/media/akshci-spaad.png "Service principal permissions shown in Azure AD")

With your service principal created and assigned, and user account permissions verified, the final step to check is to ensure you have registered the appropriate Kubernetes Resource Providers for your chosen subscription.

### Register the Kubernetes resource providers ###

Ahead of the deployment process, you need to register the appropriate resource providers in Azure for AKS on Azure Stack HCI integration. **You only need to perform this task once, per subscription**. To do that, run the following PowerShell commands:

```powershell
# Login to Azure
Connect-AzAccount
Set-AzContext -subscription "<Subscription ID of the subscription you want to deploy AKS-HCI into (must match the subscription you created a service principal for above)>"

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration
```

This registration process can take up to 10 minutes, so please be patient. It only needs to be performed once on a particular subscription. To validate the registration process, run the following PowerShell command:

```powershell
Get-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Get-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration
```

![Resource Provider enabled in Azure](/eval/media/akshci_rp_enable.png "Resource Provider enabled Azure")

With that completed, you're ready to deploy your automated AKS-HCI environment!

Deploying the Azure VM
-----------
The guidance below provides 2 main options for deploying the Azure VM. In both cases, the deployment will be fully automated through to the integration of a target cluster with Azure Arc.

1. The first option, is to perform a deployment via a [custom Azure Resource Manager template](#option-1---creating-the-vm-with-an-azure-resource-manager-json-template). This option can be launched quickly, directly from the button within the documentation, and after completing a simple form, your VM will be deployed, and AKS-HCI configuration fully automated.
2. The second option, is a [deployment of the ARM template using PowerShell](#option-2---creating-the-azure-vm-with-powershell). Again, your VM will be deployed, and AKS-HCI configuration fully automated.

### Deployment detail ###
As part of the deployment, the following will be **automated for you**:

1. A Windows Server 2019 Datacenter VM will be deployed in Azure
2. 8 x 32GiB (by default) Azure Managed Disks will be attached and provisioned with a Simple Storage Space for optimal nested VM performance
3. The Hyper-V role and management tools, including Failover Clustering tools will be installed and configured
4. An Internal vSwitch will be created and NAT configured to enable outbound networking
5. The DNS role and accompanying management tools will be installed and DNS fully configured
6. The DHCP role and accompanying management tools will be installed and DHCP fully configured. DHCP Scope will be **enabled**
7. Windows Admin Center will be installed and pre-installed extensions updated
8. The Microsoft Edge browser will be installed
9. AKS on Azure Stack HCI will be installed, and a Management Cluster will be created
10. A target cluster consisting of a user-defined number and size of Linux and Windows worker nodes will be deployed
11. The target cluster will be integrated with Azure Arc, and all resources will reside in the original resource group used for deployment

This automated deployment **should take around 35-60 minutes** depending on how many worker nodes, Kubernetes versions etc.

### Option 1 - Creating the VM with an Azure Resource Manager JSON Template ###
To keep things simple, and graphical to begin with, we'll show you how to deploy your VM via an Azure Resource Manager template.  To simplify things further, we'll use the following buttons.

Firstly, the **Visualize** button will launch the ARMVIZ designer view, where you will see a graphic representing the core components of the deployment, including the VM, NIC, disk and more. If you want to open this in a new tab, **hold CTRL** when you click the button.

[![Visualize your template deployment](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Faks-hci%2Fmain%2Feval%2Fautodeploy%2Fjson%2Fakshciauto.json "Visualize your template deployment")

Secondly, the **Deploy to Azure** button, when clicked, will take you directly to the Azure portal, and upon login, provide you with a form to complete. If you want to open this in a new tab, **hold CTRL** when you click the button.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Faks-hci%2Fmain%2Feval%2Fautodeploy%2Fjson%2Fakshciauto.json "Deploy to Azure")

Upon clicking the **Deploy to Azure** button, enter the details, which should look something similar to those shown below. Once completed, click **Review + Create**.

![Custom template deployment in Azure](/eval/media/azure_vm_custom_template_new_auto.png "Custom template deployment in Azure")

Please be aware of some of the important parameters that you must provide for deploying the template. Specifically:

* **AKS-HCI App Id** - This is your Service Principal ID which you created earlier
* **AKS-HCI App Secret** - this is the corresponding secret/password for the Service Principal
* **Kubernetes Version** - this is the preferred version of your Kubernetes target cluster. "Match Management Cluster" will select the same version as the KVA for the AKS-HCI management cluster, which you can check here: https://github.com/Azure/aks-hci/releases. This will result in fewer images downloaded, and a faster deployment time, but it may not be the very latest Kubernetes version for your clusters.

Finally, be aware of the **size** and **number** of control plane/worker nodes you are deploying. Your Azure VM has a finite size, and choosing to deploy multiple workers and control plane nodes, of a large size will result in a deployment failure of the AKS-HCI sandbox.  You can read more about this below.

*******************************************************************************************************

**NOTE** - For customers with Software Assurance, Azure Hybrid Benefit for Windows Server allows you to use your on-premises Windows Server licenses and run Windows virtual machines on Azure at a reduced cost. By selecting **Yes** for the "Already have a Windows Server License", **you confirm I have an eligible Windows Server license with Software Assurance or Windows Server subscription to apply this Azure Hybrid Benefit** and have reviewed the [Azure hybrid benefit compliance](http://go.microsoft.com/fwlink/?LinkId=859786 "Azure hybrid benefit compliance document")

*******************************************************************************************************

The custom template will be validated, and if all of your entries are correct, you can click **Create**.

The **deployment of the sandbox should take between 35 and 60 minutes**, depending on the number of control planes, node pools and worker nodes you have chosen to deploy.

![Custom template deployment in Azure completed](/eval/media/azure_autovm_custom_template_completed.png "Custom template deployment in Azure completed")

Once completed, you can check the artifacts that have been deployed by clicking on the **Resource Group** name. You'll see all of the Azure VM artifacts, alongside the Arc-enabled Kubernetes objects that have been integrated with Azure during the deployment.

![Custom template deployment in Azure completed](/eval/media/azure_autovm_artifacts.png "Custom template deployment in Azure completed")

Finally, if you chose to **enable** the auto-shutdown for the VM, and supplied a time, and time zone, but want to also add a notification alert, simply click on the **Go to resource group** button and then perform the following steps:

1. In the **Resource group** overview blade, click the **AKSHCIHost001** virtual machine
2. Once on the overview blade for your VM, **scroll down on the left-hand navigation**, and click on **Auto-shutdown**
3. Ensure the Enabled slider is still set to **On** and that your **time** and **time zone** information is correct
4. Click **Yes** to enable notifications, and enter a Webhook URL, or Email address
5. Click **Save**

You'll now be notified when the VM has been successfully shut down as the requested time.

With that completed, skip on to [connecting to your Azure VM](#connect-to-your-azure-vm)

#### Deployment errors ####
If your Azure VM fails to deploy successfully, please refer to the [troubleshooting steps below](#troubleshooting).

### Option 2 - Creating the Azure VM with PowerShell ###
For simplicity and speed, can also use PowerShell on your local machine to deploy the AKS-HCI sandbox environment using the ARM template described earlier. If preferred, you can take the following commands, edit them, and run them directly in [PowerShell in Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/quickstart-powershell "PowerShell in Azure Cloud Shell").  For the purpose of this guide, we'll assume you're using the PowerShell console/ISE or Windows Terminal locally on your workstation.

#### Update the Execution Policy ####
In this step, you'll update your PowerShell execution policy to RemoteSigned

```powershell
# Get the Execution Policy on the system, and make note of it before making changes
Get-ExecutionPolicy
# Set the Execution Policy for this process only
if ((Get-ExecutionPolicy) -ne "RemoteSigned") { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force }
```

#### Download the Azure PowerShell modules ####
In order for us to create a new VM in Azure, we'll need to ensure we have the latest Azure PowerShell modules

> [!WARNING]
> We do not support having both the AzureRM and Az modules installed for PowerShell 5.1 on Windows at the same time. If you need to keep AzureRM available on your system, install the Az module for > PowerShell 6.2.4 or later.

```powershell
# Install latest NuGet provider
Install-PackageProvider -Name NuGet -Force

# Check if the AzureRM PowerShell modules are installed - if so, present a warning
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
    Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
        'Az modules installed at the same time is not supported.')
} else {
    # If no AzureRM PowerShell modules are detected, install the Azure PowerShell modules
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
}
```
By default, the PowerShell gallery isn't configured as a trusted repository for PowerShellGet so you may be prompted to allow installation from this source, and trust the repository. Answer **(Y) Yes** or **(A) Yes to All** to continue with the installation.  The installation will take a few moments to complete, depending on your download speeds.

#### Sign into Azure ####
With the modules installed, you can sign into Azure.  By using the Login-AzAccount, you'll be presented with a login screen for you to authenticate with Azure.  Use the credentials that have access to the subscription where you'd like to deploy this VM.

```powershell
# Login to Azure
Login-AzAccount
```

When you've successfully logged in, you will be presented with the default subscription and tenant associated with those credentials.

![Result of Login-AzAccount](/eval/media/Login-AzAccount.png "Result of Login-AzAccount")

If this is the subscription and tenant you wish to use for this evaluation, you can move on to the next step, however if you wish to deploy the VM to an alternative subscription, you will need to run the following commands:

```powershell
# Optional - if you wish to switch to a different subscription
# First, get all available subscriptions as the currently logged in user
$context = Get-AzContext -ListAvailable
# Display those in a grid, select the chosen subscription, then press OK.
if (($context).count -gt 1) {
    $context | Out-GridView -OutputMode Single | Set-AzContext
}
```

With login successful, and the target subscription confirmed, you can move on to deploy the VM.

#### Deploy the VM with PowerShell ####
In order to keep things as streamlined and quick as possible, we're going to be deploying the VM that will host AKS on Azure Stack HCI, using PowerShell.

In the below script, feel free to change the VM Name, along with other parameters. The public DNS name for this VM will be generated by combining your VM name, with a random guid, to ensure it is unique, and the deployment completes without conflicts.

```powershell
# Adjust any parameters you wish to change

$rgName = "AKSHCILabRg"
$location = "East US" # To check available locations, run Get-AzureLocation #
$timeStamp = (Get-Date).ToString("MM-dd-HHmmss")
$deploymentName = ("AksHciDeploy_" + "$timeStamp")
$vmName = "AKSHCIHost001"
$vmSize = "Standard_E16s_v4"
$vmGeneration = "Generation 2" # Or Generation 1
$domainName = "akshci.local"
$dataDiskType = "StandardSSD_LRS"
$dataDiskSize = "32"
$adminUsername = "azureuser"
$adminPassword = ConvertTo-SecureString 'P@ssw0rd123!' -AsPlainText -Force
$akshciNetworking = "DHCP" # Or Static
$customRdpPort = "3389" # Between 0 and 65535
$akshciAppId = "Service_Principal_App_ID"
$akshciAppSecret = ConvertTo-SecureString 'ServicePrincipalSecret' -AsPlainText -Force
$kubernetesVersion = "Match Management Cluster" # Or v1.19.9, v1.19.11, v1.20.5, v1.20.7, v1.21.1, v1.21.2 - check https://github.com/Azure/aks-hci/releases
$controlPlanNodes = "1" # 1, 3 or 5
$controlPlaneNodeSize = "Standard_A4_v2 (4vCPU, 8GB RAM)" # See below for more sizes
$loadBalancerSize = "Standard_A4_v2 (4vCPU, 8GB RAM)" # See below for more sizes
$linuxWorkerNodes = "1" # 1, 2, 3, 4 or 5"
$linuxWorkerNodeSize = "Standard_K8S3_v1 (4vCPU, 6GB RAM)" # See below for more sizes
$windowsWorkerNodes = "0" # 0, 1, 2, 3, 4 or 5
$windowsWorkerNodeSize = "Standard_K8S3_v1 (4vCPU, 6GB RAM)" # See below for more sizes
$autoShutdownStatus = "Enabled" # Or Disabled
$autoShutdownTime = "00:00"
$autoShutdownTimeZone = (Get-TimeZone).Id # To list timezones, run [System.TimeZoneInfo]::GetSystemTimeZones() |ft -AutoSize
$existingWindowsServerLicense = "No" # See NOTE 2 below on Azure Hybrid Benefit

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location  $location -Verbose

# Deploy ARM Template
New-AzResourceGroupDeployment -ResourceGroupName $rgName -Name $deploymentName `
    -TemplateUri "https://raw.githubusercontent.com/Azure/aks-hci/main/eval/autodeploy/json/akshcihost.json" `
    -virtualMachineName $vmName `
    -virtualMachineSize $vmSize `
    -virtualMachineGeneration $vmGeneration `
    -domainName $domainName `
    -dataDiskType $dataDiskType `
    -dataDiskSize $dataDiskSize `
    -adminUsername $adminUsername `
    -adminPassword $adminPassword `
    -AKS-HCINetworking $akshciNetworking `
    -customRdpPort $customRdpPort `
    -AKS-HCIAppId $akshciAppId `
    -AKS-HCIAppSecret $akshciAppSecret `
    -kubernetesVersion $kubernetesVersion `
    -controlPlaneNodes $controlPlanNodes `
    -controlPlaneNodeSize $controlPlaneNodeSize `
    -loadBalancerSize $loadBalancerSize `
    -linuxWorkerNodes $linuxWorkerNodes `
    -linuxWorkerNodeSize $linuxWorkerNodeSize `
    -windowsWorkerNodes $windowsWorkerNodes `
    -windowsWorkerNodeSize $windowsWorkerNodeSize `
    -autoShutdownStatus $autoShutdownStatus `
    -autoShutdownTime $autoShutdownTime `
    -autoShutdownTimeZone $autoShutdownTimeZone `
    -alreadyHaveAWindowsServerLicense $existingWindowsServerLicense `
    -Verbose

# Get connection details of the newly created VM
Get-AzVM -ResourceGroupName $rgName -Name $vmName
$getIp = Get-AzPublicIpAddress -Name "AKSHCILabPubIp" -ResourceGroupName $rgName
$getIp | Select-Object Name,IpAddress,@{label='FQDN';expression={$_.DnsSettings.Fqdn}}
```

*******************************************************************************************************

**NOTE 1** - When running the above script, if your VM size contains an 's', such as 'Standard_E16**s**_v4' it can use **Premium LRS storage**. If it does not contain an 's', it can only deploy with a Standard SSD. Refer to the [table earlier](#azure-vm-size-considerations) to determine the appropriate size for your deployment.

**NOTE 2** - For customers with Software Assurance, Azure Hybrid Benefit for Windows Server allows you to use your on-premises Windows Server licenses and run Windows virtual machines on Azure at a reduced cost. By removing the comment in the script above, for the -LicenseType parameter, **you confirm you have an eligible Windows Server license with Software Assurance or Windows Server subscription to apply this Azure Hybrid Benefit** and have reviewed the [Azure hybrid benefit compliance document](http://go.microsoft.com/fwlink/?LinkId=859786 "Azure hybrid benefit compliance document")

*******************************************************************************************************

#### Available AKS-HCI VM Sizes ####
Here's a list of VM sizes that you can use for your PowerShell-based deployment. The size you select should be copied exactly how it shows below, including the (info between the brackets)

* Default (4vCPU, 4GB RAM)
* Standard_A2_v2 (2vCPU, 4GB RAM)
* Standard_A4_v2 (4vCPU, 8GB RAM)
* Standard_D2s_v3 (2vCPU, 8GB RAM)
* Standard_D4s_v3 (4vCPU, 16GB RAM)
* Standard_D8s_v3 (8vCPU, 32GB RAM)
* Standard_D16s_v3 (16vCPU, 64GB RAM)
* Standard_D32s_v3 (32vCPU, 128GB RAM)
* Standard_DS2_v2 (2vCPU, 7GB RAM)
* Standard_DS3_v2 (2vCPU, 14GB RAM)
* Standard_DS4_v2 (8vCPU, 28GB RAM)
* Standard_DS5_v2 (16vCPU, 56GB RAM)
* Standard_DS13_v2 (8vCPU, 56GB RAM)
* Standard_K8S_v1 (4vCPU, 2GB RAM)
* Standard_K8S2_v1 (2vCPU, 2GB RAM)
* Standard_K8S3_v1 (4vCPU, 6GB RAM)

Once you've made your size and region selection, based on the information provided earlier, run the PowerShell script. The **deployment of the sandbox should take between 40 and 60 minutes**, depending on the number of control planes, node pools and worker nodes you have chosen to deploy.

![Virtual machine successfully deployed with PowerShell](/eval/media/powershell_vm_deployed.png "Virtual machine successfully deployed with PowerShell")

With the VM successfully deployed, make a note of the fully qualified domain name, as you'll use that to connect to the VM shortly.

#### OPTIONAL - Enable Auto-Shutdown Notifications for your VM ####
If you chose to **enable** the auto-shutdown for the VM, and supplied a time and time zone, but want to also add a notification alert, simply perform the following steps:

1. Firstly, visit https://portal.azure.com/, and login with the same credentials used earlier. 
2. Once logged in, using the search box on the dashboard, enter "akshci" and once the results are returned, click on your AKSHCIHost virtual machine.

![Virtual machine located in Azure](/eval/media/azure_vm_search.png "Virtual machine located in Azure")

3. Once on the overview blade for your VM, **scroll down on the left-hand navigation**, and click on **Auto-shutdown**
4. Ensure the Enabled slider is still set to **On** and that your **time** and **time zone** information is correct
5. Click **Yes** to enable notifications, and enter a Webhook URL, or Email address
6. Click **Save**

You'll now be notified when the VM has been successfully shut down as the requested time.

![Enable VM auto-shutdown in Azure](/eval/media/auto_shutdown.png "Enable VM auto-shutdown in Azure")

#### Deployment errors ####
If your Azure VM fails to deploy successfully, please refer to the [troubleshooting steps below](#troubleshooting).

Access your Azure VM
-----------

With your Azure VM (AKSHCIHost001) successfully deployed and configured, you're ready to connect to the VM to start the deployment of the AKS on Azure Stack HCI infrastructure.

### Connect to your Azure VM ###
Firstly, you'll need to connect into the VM, with the easiest approach being via Remote Desktop.  If you're not already logged into the Azure portal, visit https://portal.azure.com/, and login with the same credentials used earlier.  Once logged in, using the search box on the dashboard, enter "**azshci**" and once the results are returned, **click on your AKSHCIHost001 virtual machine**.

![Virtual machine located in Azure](/eval/media/azure_vm_search.png "Virtual machine located in Azure")

Once you're on the Overview blade for your VM, along the top of the blade, click on **Connect** and from the drop-down options.

![Connect to a virtual machine in Azure](/eval/media/connect_to_vm.png "Connect to a virtual machine in Azure")

Select **RDP**. On the newly opened Connect blade, ensure the **Public IP** is selected. Ensure the RDP port matches what you provided at deployment time. By default, this should be **3389**. Then click **Download RDP File** and select a suitable folder to store the .rdp file.

![Configure RDP settings for Azure VM](/eval/media/connect_to_vm_properties.png "Configure RDP settings for Azure VM")

Once downloaded, locate the .rdp file on your local machine, and double-click to open it. Click **connect** and when prompted, enter the credentials you supplied when creating the VM earlier. Accept any certificate prompts, and within a few moments, you should be successfully logged into the Windows Server 2019 VM.

Next Steps
-----------
In this guide, you've successfully created and automatically configured your AKS on Azure Stack HCI environment, and integrated with Azure Arc. This can serve as the foundation for further learning, specifically:

* [**Part 3** - Explore AKS on Azure Stack HCI](/eval/steps/3_ExploreAKSHCI.md "Explore AKS on Azure Stack HCI")

Troubleshooting
-----------

Occasionally, deployments will fail. Here's some common failures that we see from testing:

![Azure VM deployment error](/eval/media/vm_deployment_error_auto.png "Azure VM deployment error")

### Not enough memory inside Azure VM ###
If you specify too many worker nodes/control plane VMs, or the Kubernetes VM sizes that you choose are too large, deployment will fail with an error message containing the following information:

*Insufficient memory capacity to deploy the target cluster. Total estimated free memory on the host after AKS-HCI management cluster deployment = 53.91GB, yet your target cluster with 1 Standard_A4_v2 Load Balancer, 5 Standard_A4_v2 control plane node(s) and 5 Standard_K8S3_v1 worker node(s) requires 78.89GB memory. Please redeploy using a larger Azure VM, or a smaller target cluster.*

### Not enough vCPUs inside Azure VM ###
When you create your VM in Azure, it will be created with a specific number of vCPUs available to the guest OS. When you deploy AKS-HCI inside this Azure VM, you cannot create a nested AKS-HCI VM with more nested vCPUs, than exists vCPUs in the Azure VM.

For example, if you deploy your Azure VM with size: **Standard_E16s_v4 (16 vCPUs)**, this means that inside the Azure VM, you **cannot create any AKS-HCI VMs with more vCPUs than 16**. if you try, the deployment will fail with an error message containing the following information:

*Your target cluster Linux worker node size (Standard_D32s_v3) has more vCPUs (32) than the number of logical processors in your Azure VM Hyper-V host (20). Ensure all sizes for your target cluster VMs (Load Balancer, Control Planes, Worker Nodes) have less than 20 vCPUs in your ARM template for this specific Azure VM size.*

### Transient deployment issues ###

From time to time, a transient, random deployment error may cause the Azure VM to show a failed deployment. This is typically caused by reboots and timeouts within the VM as part of the PowerShell DSC configuration process, in particular, when the Hyper-V role is enabled and the system reboots multiple times in quick succession. We've also seen instances where changes with Chocolatey Package Manager cause deployment issues.

If the error is related to the **AKSHCIHost001/ConfigureAksHciHost**, because the installation of AKS-HCI depends on this step completing successfully, it is recommended that your **redeploy** your Azure VM from the template.

Product improvements
-----------
If, while you work through this guide, you have an idea to make the product better, whether it's something in AKS on Azure Stack HCI, Windows Admin Center, or the Azure Arc integration and experience, let us know! We want to hear from you! [Head on over to our AKS on Azure Stack HCI GitHub page](https://github.com/Azure/aks-hci/issues "AKS on Azure Stack HCI GitHub"), where you can share your thoughts and ideas about making the technologies better.  If however, you have an issue that you'd like some help with, read on... 

Raising issues
-----------
If you notice something is wrong with the evaluation guide, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  Raise an issue in GitHub, and we'll be sure to fix this as quickly as possible!

If however, you're having a problem with AKS on Azure Stack HCI **outside** of this evaluation guide, make sure you post to [our GitHub Issues page](https://github.com/Azure/aks-hci/issues "GitHub Issues"), where Microsoft experts and valuable members of the community will do their best to help you.
