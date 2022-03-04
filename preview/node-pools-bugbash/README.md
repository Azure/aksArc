# Read this first, before you begin
Currently you can manage the life cycle of AKS on Azure Stack HCI clusters through PowerShell and Windows Admin Center via the AKS-HCI mgmt cluster.

This preview feature will enable you to now manage AKS on Azure Stack HCI clusters through Az CLI using the Azure control plane. The preview is only intended for folks engaged in the private preview program who want to be able to PoC the core functionality, it is not a best practice guide!

# Register for the preview!
You will need to get your subscription enabled for this private preview, please register at [https://aka.ms/arcAksHciPriPreview](https://aka.ms/arcAksHciPriPreview).

# Bug bash goals
- Create AKS-HCI clusters using Az CLI 
- Azure RBAC for cluster creation - an "admin" can do all the pre-requisite install operations, give Azure RBAC scope to a "user", who can then create an AKS-HCI cluster using Azure CLI 
- Get the certificate based kubeconfig of the AKS-HCI cluster – this is an admin operation for this release and requires you to login to the Azure Stack HCI cluster to retrieve the kubeconfig
- Add nodepools on your AKS-HCI cluster using Az CLI
- List/show AKS-HCI cluster nodepools using Az CLI
- Delete AKS-HCI nodepools using Az CLI
- List/show AKS-HCI clusters using Az CLI
- Delete the AKS-HCI cluster using Az CLI
- Collect logs for troubleshooting

# Do you have hardware?
If you have an Azure Stack HCI cluster, a Windows Server cluster or a single node Windows Server, follow [this document](https://github.com/Azure/aks-hci/blob/main/preview/node-pools-bugbash/node-pools-bug-bash-hardware.md) to create AKS clusters on your Azure Stack HCI/Windows Server cluster via Azure.

# What to do if you do not have hardware?
If you do not have hardware, follow [this document](https://github.com/Azure/aks-hci/blob/main/preview/node-pools-bugbash/node-pools-bugbash-azure-vm.md) to setup an Azure VM demo environment and then create AKS clusters on your Azure VM. 

# How to file bugs for this bugbash?
Click on [this link](https://msazure.visualstudio.com/msk8s/_workitems/create/Bug?templateId=4374d822-3296-4097-bd84-2b0791978202&ownerId=14abcc74-dc70-4881-a373-f5c12c28f688) to create a new bug that you found in this bug bash. Please capture all the details of the bug and the required steps to reproduce it, and make sure to upload the logs to a share and link it in the bug. (Don't forget to hit the "Save" button on the top right :P )

# Glossary of terms you should know

## AKS on Azure Stack HCI (AKS-HCI)

If you aren't familiar with AKS on Azure Stack HCI, read this great introduction - [What is AKS on Azure Stack HCI?](https://docs.microsoft.com/azure-stack/aks-hci/overview) AKS on Azure Stack HCI is generally available since June 2021. You can create AKS on Azure Stack HCI clusters using both PowerShell and Windows Admin Center. This private preview covers creating AKS on Azure Stack HCI clusters through Azure using Az CLI.

## AKS host/management cluster

The management cluster is created for you when you install AKS on Azure Stack HCI. The management cluster is a specialized Kubernetes cluster that provisions and manages all AKS on Azure Stack HCI Kubernetes workload clusters (these Kubernetes workload clusters are the real deal, and they run your applications). The management cluster today is backed by a single VM. You can check that this VM exists by looking at Hyper-V or the Windows Admin Center VM extension. For this preview release, the management cluster is required to manage all the Kubernetes workload clusters created using PowerShell or Windows Admin Center.

## Arc Appliance/Resource Bridge

Arc Appliance (or Resource Bridge) connects a private cloud (for example, Azure Stack HCI, VMWare/VSPhere, OpenStack, or SCVMM) to Azure and enables on-premises resource management from Azure. Arc Appliance provides the line of sight to private clouds required to manage resources such as VMs and Kubernetes clusters on-premises through Azure. Technically, Arc Appliance is an AKS on Azure Stack HCI management cluster under covers with Azure magic on top. 
 
Today, you can manage AKS on Azure Stack HCI clusters through PowerShell and Windows Admin Center. This preview feature will enable you to also manage AKS on Azure Stack HCI clusters through Az CLI and the Azure portal. To use this preview feature, you're required to install Arc Appliance for HCI as a pre-requisite (similar to how you need to install the AKS on Azure Stack HCI management cluster before you can create workload clusters). 

## Arc Kubernetes cluster extensions 

A cluster extension is the on-premises equivalent of an Azure Resource Manager resource provider. Just as you have the `Microsoft.ContainerService` resource provider that manages AKS clusters in Azure, the AKS on Azure Stack HCI cluster extension, once added to your Appliance, helps manage AKS clusters on your Azure Stack HCI cluster. 

## Custom location

A custom location is the on-premises equivalent of an Azure region and is an extension of the Azure location construct. Custom locations provide a way for tenant administrators to use their Azure Stack HCI clusters with the right extensions installed, as target locations for deploying Azure services instances.

## Admin role

The role of the infrastructure administrator is to set up the platform components: for example, setting up Azure Stack HCI, the management cluster, Arc resource bridge, the cluster extension, and the custom location. The admin role then creates networks on the Azure Stack HCI cluster that the "user" will use while creating AKS on Azure Stack HCI workload clusters. 

Apart from the above on-premises work, the admin also assigns permissions to "users" on the Azure subscription to create and access AKS on Azure Stack HCI clusters. 

While the admin needs to have some degree of understanding about Kubernetes, the end goal with this preview program is that the admin can do the previous operations without having to know a lot about Kubernetes.

## User role

The role of the user is to create AKS on Azure Stack HCI workload clusters and run applications on the AKS on Azure Stack HCI cluster. In this preview program, the user will be given pertinent information about creating AKS on Azure Stack HCI clusters, such as subscription, custom location, and network by the admin. The user will also be given Azure access to create the cluster by the administrator.

Once the user has the details described in the previous paragraph, they are free to create an AKS on Azure Stack HCI cluster as they see fit - Windows/Linux node pools, Kubernetes versions, etc. The user can then run their containerized applications by downloading the cluster *kubeconfig*.


