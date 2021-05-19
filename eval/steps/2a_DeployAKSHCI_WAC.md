Deploy your AKS-HCI infrastructure with Windows Admin Center
==============
Overview
-----------
With your Windows Server 2019 Hyper-V host up and running, it's now time to deploy AKS on Azure Stack HCI. You'll first use the Windows Admin Center to deploy the AKS on Azure Stack HCI management cluster onto your Windows Server 2019 Hyper-V host, and finally, deploy a target cluster, onto which you can test deployment of a workload.

Contents
-----------
- [Overview](#overview)
- [Contents](#contents)
- [Architecture](#architecture)
- [Set Microsoft Edge as default browser](#set-microsoft-edge-as-default-browser)
- [Allow popups in Edge browser](#allow-popups-in-edge-browser)
- [Update Windows Admin Center](#update-windows-admin-center)
- [Configure Windows Admin Center](#configure-windows-admin-center)
- [Finalize Azure integration](#finalize-azure-integration)
- [Optional - Enable/Disable DHCP](#optional---enabledisable-dhcp)
- [Deploying AKS on Azure Stack HCI management cluster](#deploying-aks-on-azure-stack-hci-management-cluster)
- [Create a Kubernetes cluster (Target cluster)](#create-a-kubernetes-cluster-target-cluster)
- [Scale your Kubernetes cluster (Target cluster)](#scale-your-kubernetes-cluster-target-cluster)
- [Next Steps](#next-steps)
- [Product improvements](#product-improvements)
- [Raising issues](#raising-issues)

*******************************************************************************************************

### Important Note ###

In this step, you'll be using Windows Admin Center to deploy AKS on Azure Stack HCI. If you prefer to use PowerShell, head on over to the [PowerShell guide](/eval/steps/2b_DeployAKSHCI_PS.md).

*******************************************************************************************************

Architecture
-----------

From an architecture perspective, as shown earlier, this graphic showcases the different layers and interconnections between the different components:

![Architecture diagram for AKS on Azure Stack HCI in Azure](/eval/media/nested_virt_arch_ga.png "Architecture diagram for AKS on Azure Stack HCI in Azure")

You've already deployed the outer box , which represents the Azure Resource Group. Inside here, you've deployed the virtual machine itself, and accompaying network adapter, storage and so on. You've also completed some host configuration

In this section, you'll first install and configure the Windows Admin Center. You'll use this to deploy the management cluster, also known as a management cluster. This provides the the core orchestration mechanism and interface for deploying and managing one or more target clusters, which are shown on the right of the diagram. These target, or workload clusters contain worker nodes and are where application workloads run. These are managed by a management cluster. If you're interested in learning more about the building blocks of the Kubernetes infrastructure, you can [read more here](https://docs.microsoft.com/en-us/azure-stack/aks-hci/kubernetes-concepts "Kubernetes core concepts for Azure Kubernetes Service on Azure Stack HCI").

Set Microsoft Edge as default browser
-----------
To streamline things later, we'll set Microsoft Edge as the default browser over Internet Explorer.

1. Inside your **AKSHCIHOST001 VM**, click on Start, then type "**default browser**" (without quotes) and then under **Best match**, select **Choose a default web browser**

![Set the default browser](/eval/media/default_browser.png "Set the default browser")

2. In the **Default apps** settings view, under **Web browser**, click on **Internet Explorer**
3. In the **Choose an app** popup, select **Microsoft Edge** then **close the Settings window**

Allow popups in Edge browser
-----------
To give the optimal experience with Windows Admin Center, you should enable **Microsoft Edge** to allow popups for Windows Admin Center.

1. Still inside your **AKSHCIHOST001 VM**, double-click the **Microsoft Edge icon** on your desktop
2. Navigate to **edge://settings/content/popups**
3. In the **Allow** box, click on **Add**
4. In the **Add a site** box, enter **https://akshcihost001** (assuming you didn't change the host name at deployment time)

![Allow popups in Edge](/eval/media/allow_popup_edge.png "Allow popups in Edge")

5. Close the **settings tab**.

Update Windows Admin Center
-----------
Your Azure VM deployment automatically installed Windows Admin Center 2103, which is the public build currently available.

*******************************************************************************************************

**IMPORTANT** - For this release of AKS on Azure Stack HCI, an **updated version of Windows Admin Center is required**. Ensure you download the correct version from the Microsoft internal location. To update the installed version of Windows Admin Center, follow these steps:

1. Navigate to your downloaded Windows Admin Center MSI file and **Double-click** to start the update process
2. Follow the installation wizard, make the selections for diagnostic data and the use of Microsoft Update, leaving the **default selections** for the rest of the options, to complete the upgrade of Windows Admin Center. This will take a few minutes to complete.

*******************************************************************************************************

Configure Windows Admin Center
-----------
With Windows Admin Center installed and updated, there are some additional configuration steps that must be performed before you can use it to deploy AKS on Azure Stack HCI.

1. **Double-click the Windows Admin Center** shortcut on the desktop.
2. Once Windows Admin Center is open, you may receive notifications in the top-right corner, indicating that some extensions are updating automatically. **Let these finish updating before proceeding**. Windows Admin Center may refresh automatically during this process. Once complete, **minimize Windows Admin Center**.
3. In Windows Admin Center, navigate to **Settings**, then **Extensions**
4. Click on **Available extensions** and you should see **Azure Kubernetes Service** listed as available

![Available extensions in Windows Admin Center](/eval/media/available_extensions.png "Available extensions in Windows Admin Center")

5. To install the extension, simply click on it, and click **Install** and then **OK**. Within a few moments, this will be completed. You can double-check by navigating to **Installed extensions**, where you should see Azure Kubernetes Service listed as **Installed**

With your extension correctly deployed, in order to deploy AKS-HCI with Windows Admin Center, you need to connect your Windows Admin Center instance to Azure.

6. Click on **Settings** then under **Gateway** click on **Azure**.
7. Click **Register**, and in the **Get started with Azure in Windows Admin Center** blade, follow the instructions to **Copy the code** and then click on the link to configure device login.
8.   When prompted for credentials, **enter your Azure credentials** for a tenant you'd like to use to register the Windows Admin Center
9.   Back in Windows Admin Center, you'll notice your tenant information has been added.  You can now click **Connect** to connect Windows Admin Center to Azure

![Connecting Windows Admin Center to Azure](/eval/media/wac_azure_connect.png "Connecting Windows Admin Center to Azure")

10. Click on **Sign in** and when prompted for credentials, **enter your Azure credentials** and you should see a popup that asks for you to accept the permissions, so click **Accept**

![Permissions for Windows Admin Center](/eval/media/wac_azure_permissions.png "Permissions for Windows Admin Center")

*******************************************************************************************************

**NOTE** - if you receive an error when signing in, still in **Settings**, under **User**, click on **Account** and click **Sign-in**. You should then be prompted for Azure credentials and permissions, to which you can then click **Accept**. Sometimes it just takes a few moments from Windows Admin Center creating the Azure AD application and being able to sign in. Retry the sign-in until you've successfully signed in.

*******************************************************************************************************

Finalize Azure integration
-----------
In order to successfully deploy AKS on Azure Stack HCI with Windows Admin Center, you need to grant some additional permissions on the Windows Admin Center Azure AD application that was created when you connected Windows Admin Center to Azure, earlier.

1. Still in Windows Admin Center, click on the **Settings** gear in the top-right corner
2. Under **Gateway**, click **Azure**. You should see your previously registered Azure AD app:

![Your Azure AD app in Windows Admin Center](/eval/media/wac_azureadapp.png "Your Azure AD app in Windows Admin Center")

3. Click on **View in Azure** to be taken to the Azure AD app portal, where you should see information about this app, including permissions required. If you're prompted to log in, provide appropriate credentials.
4. Once logged in, under **Configured permissions**, you may see the **Microsoft.Graph (5)** listed with the status **Not granted for...**

![Your Azure AD app permissions in Windows Admin Center](/eval/media/wac_azuread_grant.png "Your Azure AD app permissions in Windows Admin Center")

*******************************************************************************************************

**NOTE** If you don't see Microsoft Graph listed in the API permissions, you can either [re-register Windows Admin Center using steps here](#configure-windows-admin-center "re-register Windows Admin Center using steps here") for the permissions to appear correctly, or manually add the **Microsoft Graph Appliation.ReadWrite.All** permission.

*******************************************************************************************************

5. If you have the permissions shown in the graphic above, click on **Grant admin consent for __________** and when prompted to confirm permissions, click **Yes**

![Confirm Azure AD app permissions in Windows Admin Center](/eval/media/wac_azuread_confirm.png "Confirm Azure AD app permissions in Windows Admin Center")

*******************************************************************************************************

**NOTE** - If you don't see the permissions shown in the graphic, to manually add the permission:

- Click **+ Add a permission**
- Select **Microsoft Graph**, then **Delegated permissions**
- Search for **Application.ReadWrite.All**, then if required, expand the **Application** dropdown
- Select the **checkbox** and click **Add permissions**
- Click on **Grant admin consent for __________** and when prompted to confirm permissions, click **Yes**

*******************************************************************************************************

6.  Switch back to the **Windows Admin Center tab** and click on **Windows Admin Center** in the top-left corner to return to the home page

You'll notice that your AKSHCIHOST001 is already under management, so at this stage, you're ready to proceed to deploy the AKS on Azure Stack HCI management cluster onto your Windows Server 2019 Hyper-V host.

![AKSHCIHOST001 under management in Windows Admin Center](/eval/media/akshcihost_in_wac.png "AKSHCIHOST001 under management in Windows Admin Center")

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

Deploying AKS on Azure Stack HCI management cluster
-----------
The next section will walk through configuring the AKS on Azure Stack HCI management cluster, on your single node Windows Server 2019 host.

1. From the Windows Admin Center homepage, click on your **akshcihost001.akshci.local \[Gateway\]** machine.
2. You'll be presented with a rich array of information about your akshcihost001 machine, of which you can feel free to explore the different options and metrics. When you're ready, on the left-hand side, scroll down and under **Extensions**, click **Azure Kubernetes Service**

![Ready to deploy AKS-HCI with Windows Admin Center](/eval/media/aks_extension.png "Ready to deploy AKS-HCI with Windows Admin Center")

You'll notice the terminology used refers to the **Azure Kubernetes Service Runtime on Windows Server​​** - the naming differs depending on if you're running the installation of AKS on a Windows Server 2019 platform, or the newer Azure Stack HCI 20H2 platform. The overall deployment experience is the same regardless of underlying platform.

3. Click on **Set up** to start the deployment process
4. Firstly, review the prerequisites - your Azure VM environment will meet all the prerequisites, so you should be fine to click **Next: System checks**
5. On the **System checks** page, enter the password for your **azureuser** account
6. Once your credentials have been validated, Windows Admin Center will begin to validate it's own configuration, and the configuration of your target nodes, which in this case, is the Windows Server 2019 Hyper-V host (running in your Azure VM)

![System checks performed by Windows Admin Center](/eval/media/wac_system_checks.png "System checks performed by Windows Admin Center")

You'll notice that Windows Admin Center will validate memory, storage, networking, roles and features and more. If you've followed the guide correctly, you'll find you'll pass all the checks and can proceed.

7. Once validated, click **Apply**, wait a few moments, then click **Next: Connectivity**
8. On the **Connectivity** page, read the information about **CredSSP**, then click **Enable**. Once enabled, click **Next: Host configuration**

![Enable CredSSP in Windows Admin Center](/eval/media/aks_hostconfig_credssp.png "Enable CredSSP in Windows Admin Center")

9.  On the **Host configuration** page, under **Host details**, select your **V:**, and leave the other settings as default

![Host configuration in Windows Admin Center](/eval/media/aks_hostconfig_hostdetails.png "Host configuration in Windows Admin Center")

10. Under **VM Networking**, ensure that **InternalNAT** is selected for the **Internet-connected virtual switch**
11. For **Enable virtual LAN identification**, leave this selected as **No**
12. For **Cloudagent IP** this is optional, so we will leave this blank
13. For **IP address allocation method** choose **either DHCP or Static** depending on the choice you made for deployment of your Azure VM. If you're not sure, you can check by [validating your DHCP config](#optional---enabledisable-dhcp)
14. If you select **Static**, you should enter the following:
    1.  **Subnet Prefix**: 192.168.0.0/16
    2.  **Gateway**: 192.168.0.1
    3.  **DNS Servers**: 192.168.0.1
    4.  **Kubernetes node IP pool start**: 192.168.0.3
    5.  **Kubernetes node IP pool end**: 192.168.0.149

![Host configuration in Windows Admin Center](/eval/media/aks_hostconfig_vmnet.png "Host configuration in Windows Admin Center")

15. Under **Load balancer settings**, enter the range from **192.168.0.150** to **192.168.0.250** and then click **Next: Azure registration**

![Host configuration in Windows Admin Center](/eval/media/aks_hostconfig_lb.png "Host configuration in Windows Admin Center")

16. On the **Azure registration page**, your Azure account should be automatically populated. Use the drop-down to select your preferred subscription. If you are prompted, log into Azure with your Azure credentials. Once successfully authenticated, you should see your **Account**, then **choose your subscription**

![AKS on Azure Stack HCI Azure Registration in Windows Admin Center](/eval/media/aks_azure_reg.png "AKS on Azure Stack HCI Azure Registration in Windows Admin Center")

*******************************************************************************************************

**NOTE** - No charges will be incurred for using AKS on Azure Stack HCI during the preview.

*******************************************************************************************************

17. Once you've chosen your subscription, choose an **existing Resource Group** or **create a new one** - Your resource group should be in the **East US, Southeast Asia, or West Europe region**
18. Click on **Next:Review**
19. Review your choices and settings, then click **Apply**. After a few moments, you should receive some notifications:

![Setting the AKS-HCI config in Windows Admin Center](/eval/media/aks_host_mgmtconfirm.png "Setting the AKS-HCI config in Windows Admin Center")

20. Once confirmed, you can click **Next: New cluster** to start the deployment process of the management cluster.

![AKS on Azure Stack HCI management cluster deployment started in Windows Admin Center](/eval/media/aks_deploy_started.png "AKS on Azure Stack HCI management cluster deployment started in Windows Admin Center")

*******************************************************************************************************

**NOTE 1** - Do not close the Windows Admin Center browser at this time. Leave it open and wait for successful completion.

**NOTE 2** - You may receive a WinRM error message stating "Downloading virtual machine images and binaries for the AKS host failed" - this can be ignored, so **do not close/refresh the browser**.

*******************************************************************************************************

21.  Upon completion you should receive a notification of success. In this case, you can see deployment of the AKS on Azure Stack HCI management cluster took just over 11 minutes.

![AKS-HCI management cluster deployment completed in Windows Admin Center](/eval/media/aks_deploy_success.png "AKS-HCI management cluster deployment completed in Windows Admin Center")

22. Once reviewed, click **Finish**. You will then be presented with a management dashboard where you can create and manage your Kubernetes clusters.

### Updates and Cleanup ###
To learn more about **updating**, **redeploying** or **uninstalling** AKS on Azure Stack HCI with Windows Admin Center, you can [read the official documentation here.](https://docs.microsoft.com/en-us/azure-stack/aks-hci/setup "Official documentation on updating, redeploying and uninstalling AKS on Azure Stack HCI")

Create a Kubernetes cluster (Target cluster)
-----------
With the management cluster deployed successfully, you're ready to move on to deploying Kubernetes clusters that can host your workloads. We'll then briefly walk through how to scale your Kubernetes cluster and upgrade the Kubernetes version of your cluster.

There are two ways to create a Kubernetes cluster in Windows Admin Center.

#### Option 1 ####
1. From your Windows Admin Center landing page (https://akshcihost001), click on **+Add**.
2. In the **Add or create resources blade**, in the **Kubernetes clusters (preview) tile**, click **Create new**

![Create Kubernetes cluster in Windows Admin Center](/eval/media/create_cluster_method1.png "Create Kubernetes cluster in Windows Admin Center")

#### Option 2 ####
1. From your Windows Admin Center landing page (https://akshcihost001), click on your **akshcihost001.akshci.local \[Gateway\]** machine.
2. Then, on the left-hand side, scroll down and under **Extensions**, click **Azure Kubernetes Service**.
3. In the central pane, click on **Add cluster**

![Create Kubernetes cluster in Windows Admin Center](/eval/media/create_cluster_method2.png "Create Kubernetes cluster in Windows Admin Center")

Whichever option you chose, you will now be at the start of the **Create kubernetes cluster** wizard.

1. Firstly, review the prerequisites - your Azure VM environment will meet all the prerequisites, so you should be fine to click **Next: Basics**
2. On the **Basics** page, firstly, choose whether you wish to **optionally** integrate with Azure Arc for Kubernetes. You can click the link on the page to learn more about Azure Arc. If you do wish to integrate, select the **Enabled** radio button, then use the drop downs to select the **subscription** and **resource group**. Alternatively, you can create a new resource group, in a specific region, exclusively for the Azure Arc integration resource.

![Enable Arc integration with Windows Admin Center](/eval/media/aks_basics_arc.png "Enable Arc integration with Windows Admin Center")

3. Still on the **Basics** page, under **Cluster details**, provide a **Kubernetes cluster name**, **Azure Kubernetes Service host**, which should be **AKSHCIHost001**, enter your host credentials, then select the **Kubernetes version** from the drop down.

![AKS cluster details in Windows Admin Center](/eval/media/aks_basics_cluster_details.png "AKS cluster details in Windows Admin Center")

4. Under **Primary node pool**, accept the defaults, and then click **Next: Node pools**

![AKS primary node pool in Windows Admin Center](/eval/media/aks_basics_primarynp.png "AKS primary node pool in Windows Admin Center")

5. On the **Node pools** page, click on **+Add node pool**
6. In the **Add a node pool** blade, enter the following, then click **Add**
   1. **Node pool name**: LinuxPool1
   2. **OS type**: Linux
   3. **Node size**: Standard_K8S3_v1 (6 GB Memory, 4 CPU)
   4. **Node count**: 1
7. Repeat step 6, to add a **Windows node** and the following info, then click **Add**
   1. **Node pool name**: WindowsPool1
   2. **OS type**: Windows
   3. **Node size**: Standard_K8S3_v1 (6 GB Memory, 4 CPU)
   4. **Node count**: 1

![AKS node pools in Windows Admin Center](/eval/media/aks_node_pools.png "AKS node pools in Windows Admin Center")

8. Once your **Node pools** have been defined, click **Next: Authentication**
9. For this evaluation, for **AD Authentication** click **Disabled** and then click **Next: Networking**
10. On the **Networking** page, review the **defaults**. For this deployment, you'll deploy this kubernetes cluster on the existing virtual network that was created when you installed AKS-HCI in the previous steps.

![AKS virtual networking in Windows Admin Center](/eval/media/aks_virtual_networking.png "AKS virtual networking in Windows Admin Center")

11. Click on the **aks-default-network**, ensure **Flannel** network configuration is selected, and then click **Next: Review + Create**
12. On the **Review + Create** page, review your chosen settings, then click **Create**

![Finalize creation of AKS cluster in Windows Admin Center](/eval/media/aks_create.png "Finalize creation of AKS cluster in Windows Admin Center")

13. The creation process will begin and take a few minutes

![Start deployment of AKS cluster in Windows Admin Center](/eval/media/aks_create_start.png "Start deployment of AKS cluster in Windows Admin Center")

14. Once completed, you should see a message for successful creation, then click **Finish**

![Completed deployment of AKS cluster in Windows Admin Center](/eval/media/aks_create_complete.png "Completed deployment of AKS cluster in Windows Admin Center")

15. Back in the **Azure Kubernetes Service Runtime on Windows Server**, you should now see your cluster listed

![AKS cluster in Windows Admin Center](/eval/media/aks_dashboard.png "AKS cluster in Windows Admin Center")

16. On the dashboard, if you chose to integrate with Azure Arc, you should be able to click the **Azure instance** link to be taken to the Azure Arc view in the Azure portal.

![AKS cluster in Azure Arc](/eval/media/aks_in_arc.png "AKS cluster in Azure Arc")

17. In addition, you may wish to download your **Kubernetes cluster kubeconfig** file in order to access this Kubernetes cluster via **kubectl** later.
18. Once you have your Kubeconfig file, you can click **Finish**


Scale your Kubernetes cluster (Target cluster)
-----------
Next, you'll scale your Kubernetes cluster to add an additional Linux worker node. As it stands, this has to be performed with **PowerShell** but will be available in Windows Admin Center in the future.

1. Open **PowerShell as Administrator** and run the following command to import the new modules, and list their functions.

```powershell
Import-Module AksHci
Get-Command -Module AksHci
```

2. Next, to check on the status of the existing cluster, run the following

```powershell
Get-AksHciCluster
```

![Output of Get-AksHciCluster](/eval/media/get_akshcicluster_2.png "Output of Get-AksHciCluster")

3. Next, you'll scale your Kubernetes cluster to have **2 Linux worker nodes**:

```powershell
Set-AksHciClusterNodeCount –Name akshciclus001 -linuxNodeCount 2 -windowsNodeCount 1
```
*******************************************************************************************************

**NOTE** - You can also scale your Control Plane nodes for this particular cluster, however it has to be **scaled independently from the worker nodes** themselves. You can scale the Control Plane nodes using the command. Before you run this command however, check that you have an extra 16GB memory left of your AKSHCIHost001 OS - if your host has been deployed with 64GB RAM, you may not have enough capacity for an additonal 2 Control Plane VMs.

```powershell
Set-AksHciClusterNodeCount –Name akshciclus001 -controlPlaneNodeCount 3
```

**NOTE** - the control plane node count should be an **odd** number, such as 1, 3, 5 etc.

*******************************************************************************************************

4. Once these steps have been completed, you can verify the details by running the following command:

```powershell
Get-AksHciCluster
```

![Output of Get-AksHciCluster](/eval/media/get_akshcicluster_4.png "Output of Get-AksHciCluster")

To access this **akshciclus001** cluster using **kubectl** (which was installed on your host as part of the overall installation process), you'll first need the **kubeconfig file**.

5. To retrieve the kubeconfig file for the akshciclus001 cluster, you'll need to run the following command from your **administrative PowerShell**:

```powershell
Get-AksHciCredential -Name akshciclus001
dir $env:USERPROFILE\.kube
```

Next Steps
-----------
In this step, you've successfully deployed the AKS on Azure Stack HCI management cluster using Windows Admin Center, optionally integrated with Azure Arc, and subsequently, deployed and scaled a Kubernetes cluster that you can move forward with to the next stage, in which you can deploy your applications.

* [**Part 3** - Explore AKS on Azure Stack HCI](/eval/steps/3_ExploreAKSHCI.md "Explore AKS on Azure Stack HCI")

Product improvements
-----------
If, while you work through this guide, you have an idea to make the product better, whether it's something in AKS on Azure Stack HCI, Windows Admin Center, or the Azure Arc integration and experience, let us know! We want to hear from you! [Head on over to our AKS on Azure Stack HCI GitHub page](https://github.com/Azure/aks-hci/issues "AKS on Azure Stack HCI GitHub"), where you can share your thoughts and ideas about making the technologies better.  If however, you have an issue that you'd like some help with, read on... 

Raising issues
-----------
If you notice something is wrong with the evaluation guide, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  Raise an issue in GitHub, and we'll be sure to fix this as quickly as possible!

If however, you're having a problem with AKS on Azure Stack HCI **outside** of this evaluation guide, make sure you post to [our GitHub Issues page](https://github.com/Azure/aks-hci/issues "GitHub Issues"), where Microsoft experts and valuable members of the community will do their best to help you.