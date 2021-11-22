Evaluate AKS on Azure Stack HCI in Azure
==============
Overview
-----------
With the introduction of [nested virtualization support in Azure](https://azure.microsoft.com/en-us/blog/nested-virtualization-in-azure/ "Nested virtualization announcement blog post") back in 2017, Microsoft opened the door to a number of new and interesting scenarios.  Nested virtualization in Azure is particularly useful for validating configurations that would require additional hardware in your environment, such as running Hyper-V hosts and clusters.

In this guide, you'll walk through the steps to stand up an AKS on Azure Stack HCI infrastructure. At a high level, this will consist of the following:

* Deploy an Azure VM, running Windows Server 2019 or 2022, to act as your main Hyper-V host - this will be automatically configured with the relevant roles and features needed for your evaluation
* On the Windows Server VM, deploy the AKS on Azure Stack HCI management cluster
* On the Windows Server VM, deploy the AKS on Azure Stack HCI target clusters, for running workloads

Contents
-----------
- [Overview](#overview)
- [Contents](#contents)
- [Architecture](#architecture)
- [Important Note](#important-note)
- [Get an Azure subscription](#get-an-azure-subscription)
- [Azure VM Size Considerations](#azure-vm-size-considerations)
- [Deploying the Azure VM](#deploying-the-azure-vm)
- [Access your Azure VM](#access-your-azure-vm)
- [Next Steps](#next-steps)
- [Troubleshooting](#troubleshooting)
- [Product improvements](#product-improvements)
- [Raising issues](#raising-issues)

Architecture
-----------

From an architecture perspective, the following graphic showcases the different layers and interconnections between the different components:

![Architecture diagram for AKS on Azure Stack HCI in Azure](/eval/media/nested_virt_arch_ga2.png "Architecture diagram for AKS on Azure Stack HCI in Azure")

The outer box represents the Azure Resource Group, which will contain all of the artifacts deployed in Azure, including the virtual machine itself, and accompaying network adapter, storage and so on. You'll deploy an Azure VM running Windows Server 2019 or 2022 Datacenter. Once deployed, you'll perform some host configuration, and then begin to deploy the other key components. Firstly, on the left hand side, you'll deploy the management cluster. This provides the the core orchestration mechanism and interface for deploying and managing one or more target clusters, which are shown on the right of the diagram. These target, or workload clusters contain worker nodes and are where application workloads run. These are managed by a management cluster. If you're interested in learning more about the building blocks of the Kubernetes infrastructure, you can [read more here](https://docs.microsoft.com/en-us/azure-stack/aks-hci/kubernetes-concepts "Kubernetes core concepts for Azure Kubernetes Service on Azure Stack HCI").

*******************************************************************************************************

Important Note
-----------
The steps outlined in this evaluation guide are **specific to running inside an Azure VM**, running a single Windows Server 2019 or 2022 OS, without a domain environment configured. If you plan to use these steps in an alternative environment, such as one nested/physical on-premises, or in a domain-joined environment, the steps may differ and certain procedures may not work. If that is the case, please refer to the [official documentation to deploy AKS on Azure Stack HCI](https://docs.microsoft.com/en-us/azure-stack/aks-hci/ "official documentation to deploy AKS on Azure Stack HCI").

*******************************************************************************************************

Get an Azure subscription
-----------
To evaluate AKS on Azure Stack HCI in Azure, you'll need an Azure subscription.  If you already have one provided by your company, you can skip this step, but if not, you have a couple of options.

The first option would apply to Visual Studio subscribers, where you can use Azure at no extra charge. With your monthly Azure DevTest individual credit, Azure is your personal sandbox for dev/test. You can provision virtual machines, cloud services, and other Azure resources. Credit amounts vary by subscription level, but if you manage your AKS on Azure Stack HCI Host VM run-time efficiently, you can test the scenario well within your subscription limits.

The second option would be to sign up for a [free trial](https://azure.microsoft.com/en-us/free/ "Azure free trial link"), which gives you $200 credit for the first 30 days, and 12 months of popular services for free.

*******************************************************************************************************

**NOTE** - The Free Trial subscription provides $200 for your usage, however the largest individual VM you can create is capped at 4 vCPUs, which is **not** enough to run this sandbox environment. Once you have signed up for the free trial, you can [upgrade this to a pay as you go subscription](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/upgrade-azure-subscription "Upgrade to a PAYG subscription") and this will allow you to keep your remaining credit ($200 to start with) for the full 30 days from when you signed up. You will also be able to deploy VMs with greater than 4 vCPUs.

*******************************************************************************************************

You can also use this same Azure subscription to integrate with Azure Arc, once the deployment is completed.

Azure VM Size Considerations
-----------

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

Deploying the Azure VM
-----------
The guidance below provides 2 main options for deploying the Azure VM.  In both cases, the deployment will be automated to the point of which you can proceed immediately to download the AKS on Azure Stack HCI software, and progress through your evaluation.

1. The first option, is to perform a deployment via a [custom Azure Resource Manager template](#option-1---creating-the-vm-with-an-azure-resource-manager-json-template). This option can be launched quickly, directly from the button within the documentation, and after completing a simple form, your VM will be deployed, and host configuration automated.
2. The second option, is a [deployment of the ARM template using PowerShell](#option-2---creating-the-azure-vm-with-powershell). Again, your VM will be deployed, and host configuration automated.

### Deployment detail ###
As part of the deployment, the following steps will be **automated for you**:

1. A Windows Server 2019 or 2022 Datacenter VM will be deployed in Azure
2. 8 x 32GiB (by default) Azure Managed Disks will be attached and provisioned with a Simple Storage Space for optimal nested VM performance
3. The Hyper-V role and management tools, including Failover Clustering tools will be installed and configured
4. An Internal vSwitch will be created and NAT configured to enable outbound networking
5. The DNS role and accompanying management tools will be installed and DNS fully configured
6. The DHCP role and accompanying management tools will be installed and DHCP fully configured. DHCP Scope will be **enabled**
7. Windows Admin Center will be installed and pre-installed extensions updated
8. The Microsoft Edge browser will be installed

This automated deployment **should take around 13-15 minutes**.

### Option 1 - Creating the VM with an Azure Resource Manager JSON Template ###
To keep things simple, and graphical to begin with, we'll show you how to deploy your VM via an Azure Resource Manager template.  To simplify things further, we'll use the following buttons.

Firstly, the **Visualize** button will launch the ARMVIZ designer view, where you will see a graphic representing the core components of the deployment, including the VM, NIC, disk and more. If you want to open this in a new tab, **hold CTRL** when you click the button.

[![Visualize your template deployment](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Faks-hci%2Fmain%2Feval%2Fjson%2Fakshcihost.json "Visualize your template deployment")

Secondly, the **Deploy to Azure** button, when clicked, will take you directly to the Azure portal, and upon login, provide you with a form to complete. If you want to open this in a new tab, **hold CTRL** when you click the button.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Faks-hci%2Fmain%2Feval%2Fjson%2Fakshcihost.json "Deploy to Azure")

Upon clicking the **Deploy to Azure** button, enter the details, which should look something similar to those shown below, and click **Purchase**.

![Custom template deployment in Azure](/eval/media/azure_vm_custom_template_new.png "Custom template deployment in Azure")

*******************************************************************************************************

**NOTE** - For customers with Software Assurance, Azure Hybrid Benefit for Windows Server allows you to use your on-premises Windows Server licenses and run Windows virtual machines on Azure at a reduced cost. By selecting **Yes** for the "Already have a Windows Server License", **you confirm I have an eligible Windows Server license with Software Assurance or Windows Server subscription to apply this Azure Hybrid Benefit** and have reviewed the [Azure hybrid benefit compliance](http://go.microsoft.com/fwlink/?LinkId=859786 "Azure hybrid benefit compliance document")

*******************************************************************************************************

The custom template will be validated, and if all of your entries are correct, you can click **Create**. Within a few minutes, your VM will be created.

![Custom template deployment in Azure completed](/eval/media/azure_vm_custom_template_completed.png "Custom template deployment in Azure completed")

If you chose to **enable** the auto-shutdown for the VM, and supplied a time, and time zone, but want to also add a notification alert, simply click on the **Go to resource group** button and then perform the following steps:

1. In the **Resource group** overview blade, click the **AKSHCIHost001** virtual machine
2. Once on the overview blade for your VM, **scroll down on the left-hand navigation**, and click on **Auto-shutdown**
3. Ensure the Enabled slider is still set to **On** and that your **time** and **time zone** information is correct
4. Click **Yes** to enable notifications, and enter a Webhook URL, or Email address
5. Click **Save**

You'll now be notified when the VM has been successfully shut down as the requested time.

With that completed, skip on to [connecting to your Azure VM](#connect-to-your-azure-vm)

#### Deployment errors ####
If your Azure VM fails to deploy successfully, and the error relates to the **AKSHCIHost001/ConfigureAksHciHost** PowerShell DSC extension, please refer to the [troubleshooting steps below](#troubleshooting).

### Option 2 - Creating the Azure VM with PowerShell ###
For simplicity and speed, can also use PowerShell on our local workstation to deploy the Windows Server VM to Azure using the ARM template described earlier. As an alternative, you can take the following commands, edit them, and run them directly in [PowerShell in Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/quickstart-powershell "PowerShell in Azure Cloud Shell").  For the purpose of this guide, we'll assume you're using the PowerShell console/ISE or Windows Terminal locally on your workstation.

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

In the below script, feel free to change the VM Name, along with other parameters.  The public DNS name for this VM will be generated by combining your VM name, with a random guid, to ensure it is unique, and the deployment completes without conflicts.

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
$enableDHCP = "Enabled" # Or Disabled #
$customRdpPort = "3389" # Between 0 and 65535 #
$autoShutdownStatus = "Enabled" # Or Disabled #
$autoShutdownTime = "00:00"
$autoShutdownTimeZone = (Get-TimeZone).Id # To list timezones, run [System.TimeZoneInfo]::GetSystemTimeZones() |ft -AutoSize
$existingWindowsServerLicense = "No" # See NOTE 2 below on Azure Hybrid Benefit


# Create Resource Group
New-AzResourceGroup -Name $rgName -Location  $location -Verbose

# Deploy ARM Template
New-AzResourceGroupDeployment -ResourceGroupName $rgName -Name $deploymentName `
    -TemplateUri "https://raw.githubusercontent.com/Azure/aks-hci/october_eval/eval/json/akshcihost.json" `
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
Get-AzVM -ResourceGroupName $rgName -Name $vmName
$getIp = Get-AzPublicIpAddress -Name "AKSHCILabPubIp" -ResourceGroupName $rgName
$getIp | Select-Object Name,IpAddress,@{label='FQDN';expression={$_.DnsSettings.Fqdn}}
```

*******************************************************************************************************

**NOTE 1** - When running the above script, if your VM size contains an 's', such as 'Standard_E16**s**_v4' it can use **Premium LRS storage**. If it does not contain an 's', it can only deploy with a Standard SSD. Refer to the [table earlier](#azure-vm-size-considerations) to determine the appropriate size for your deployment.

**NOTE 2** - For customers with Software Assurance, Azure Hybrid Benefit for Windows Server allows you to use your on-premises Windows Server licenses and run Windows virtual machines on Azure at a reduced cost. By removing the comment in the script above, for the -LicenseType parameter, **you confirm you have an eligible Windows Server license with Software Assurance or Windows Server subscription to apply this Azure Hybrid Benefit** and have reviewed the [Azure hybrid benefit compliance document](http://go.microsoft.com/fwlink/?LinkId=859786 "Azure hybrid benefit compliance document")

*******************************************************************************************************

Once you've made your size and region selection, based on the information provided earlier, run the PowerShell script and wait around 10 minutes for your VM deployment to complete.

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
If your Azure VM fails to deploy successfully, and the error relates to the **AKSHCIHost001/ConfigureAksHciHost** PowerShell DSC extension, please refer to the [troubleshooting steps below](#troubleshooting).

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

Once downloaded, locate the .rdp file on your local machine, and double-click to open it. Click **connect** and when prompted, enter the credentials you supplied when creating the VM earlier. Accept any certificate prompts, and within a few moments, you should be successfully logged into the Windows Server VM.

### Optional - Update your Azure VM ###

Now that you're successfully connected to the VM, it's a good idea to ensure your OS is running the latest security updates and patches. VMs deployed from marketplace images in Azure, should already contain most of the latest updates, however it's worthwhile checking for any additional updates, and applying them as necessary.

1. Open the **Start Menu** and search for **Update**
2. In the results, select **Check for Updates**
3. In the Updates window, click **Check for updates**. If any are required, ensure they are downloaded and installed.
4. Restart if required, and once completed, re-connect your RDP session using the steps earlier.

With the OS updated, and back online after any required reboot, you can proceed on to deploying AKS on Azure Stack HCI.

Next Steps
-----------
In this step, you've successfully created and automatically configured your Azure VM, which will serve as the host for your AKS on Azure Stack HCI infrastructure. You have 2 choices on how to proceed, either a more graphical way, using Windows Admin Center or via PowerShell. Make your choice below:

* [**Part 2a** - Deploy your AKS-HCI infrastructure with Windows Admin Center **(Choose 2a or 2b)**](/eval/steps/2a_DeployAKSHCI_WAC.md "Deploy your AKS-HCI infrastructure with Windows Admin Center")
* [**Part 2b** - Deploy your AKS-HCI infrastructure with PowerShell **(Choose 2a or 2b)**](/eval/steps/2b_DeployAKSHCI_PS.md "Deploy your AKS-HCI infrastructure with PowerShell")

Troubleshooting
-----------
From time to time, a transient, random deployment error may cause the Azure VM to show a failed deployment. This is typically caused by reboots and timeouts within the VM as part of the PowerShell DSC configuration process, in particular, when the Hyper-V role is enabled and the system reboots multiple times in quick succession. We've also seen instances where changes with Chocolatey Package Manager cause deployment issues.

![Azure VM deployment error](/eval/media/vm_deployment_error.png "Azure VM deployment error")

If the error is related to the **AKSHCIHost001/ConfigureAksHciHost**, most likely the installation did complete successfully in the end, but to double check, you can perform these steps:

1. Follow the steps above to [connect to your Azure VM](#connect-to-your-azure-vm)
2. Once successfully connected, open a **PowerShell console as administrator** and run the following command to confirm the status of the last run:

```powershell
# Check for last run
Get-DscConfigurationStatus
```
![Result of Get-DscConfigurationStatus](/eval/media/get-dscconfigurationstatus.png "Result of Get-DscConfigurationStatus")

3. As you can see, in this particular case, the PowerShell DSC configuration **status appears to have been successful**, however your results may show a different result. Just for good measure, you can re-apply the configuration by **running the following commands**:

```powershell
cd "C:\Packages\Plugins\Microsoft.Powershell.DSC\*\DSCWork\akshcihost.0\AKSHCIHost"
Start-DscConfiguration -Path . -Wait -Force -Verbose
```

4. If all goes well, you should see the DSC configuration reapplied without issues. If you then re-run the following PowerShell command, you should see success:

```powershell
# Check for last run
Get-DscConfigurationStatus
```

![Result of Get-DscConfigurationStatus](/eval/media/get-dscconfigurationstatus2.png "Result of Get-DscConfigurationStatus")

*******************************************************************************************************

**NOTE** - If this doesn't fix your issue, consider redeploying your Azure VM. If the issue persists, please **raise an issue!**

*******************************************************************************************************

Product improvements
-----------
If, while you work through this guide, you have an idea to make the product better, whether it's something in AKS on Azure Stack HCI, Windows Admin Center, or the Azure Arc integration and experience, let us know! We want to hear from you! [Head on over to our AKS on Azure Stack HCI GitHub page](https://github.com/Azure/aks-hci/issues "AKS on Azure Stack HCI GitHub"), where you can share your thoughts and ideas about making the technologies better.  If however, you have an issue that you'd like some help with, read on... 

Raising issues
-----------
If you notice something is wrong with the evaluation guide, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  Raise an issue in GitHub, and we'll be sure to fix this as quickly as possible!

If however, you're having a problem with AKS on Azure Stack HCI **outside** of this evaluation guide, make sure you post to [our GitHub Issues page](https://github.com/Azure/aks-hci/issues "GitHub Issues"), where Microsoft experts and valuable members of the community will do their best to help you.
