# Azure Kubernetes Service on Azure Stack HCI – Release notes
This document is for Azure Kubernetes Service on Azure Stack HCI Public Preview 1.

## What is Azure Kubernetes Service on Azure Stack HCI?
Last updated: 09/21/2020

Azure Kubernetes Service on Azure Stack HCI is an on-premises implementation of the popular Azure Kubernetes Service (AKS) orchestrator, which automates running containerized applications at scale. Azure Kubernetes Service is now in preview on Azure Stack HCI, making it quicker to get started hosting Linux and Windows containers in your datacenter.

To get started with Azure Kubernetes Service on-premises, register for the preview (there's no added cost during preview), then see Set up Azure Kubernetes Service on Azure Stack HCI. To instead use Azure Kubernetes Service to orchestrate your cloud-based containers, see Azure Kubernetes Service in Azure.

The following sections discuss some of the reasons to use Azure Kubernetes Service on Azure Stack HCI, then answer some common questions about the service and how to get started. For a background on containers, see Windows and containers.

## What's new in this release 

### Automate management of containerized applications
Here's some of the functionality provided by Azure Kubernetes Service while in preview on Azure Stack HCI:

* Deploy containerized apps at scale to a cluster of VMs (called a Kubernetes cluster) running across the Azure Stack HCI cluster
* Fail over when a node in the Kubernetes cluster fails
* Deploy and manage both Linux and Windows-based containerized apps
* Schedule workloads
* Monitor health
* Scale up or down by adding or removing nodes to the Kubernetes cluster
* Manage networking
* Discover services
* Coordinate app upgrades
* Assign pods to cluster nodes with cluster node affinity

### Simplified setup of a Kubernetes cluster
Azure Kubernetes Service simplifies the process of setting up Kubernetes on Azure Stack HCI and includes the following features:

* A Windows Admin Center wizard for setting up Kubernetes and its dependencies (such as kubeadm, kubelet, kubectl, and a pod network add-on)
* A Windows Admin Center wizard for creating Kubernetes clusters to run your containerized applications
* PowerShell cmdlets for setting up Kubernetes and creating Kubernetes clusters, in case you'd rather script the host setup and Kubernetes cluster creation

### View and manage Kubernetes using on-premises tools or Azure Arc
* Once you've set up Azure Kubernetes Service on your Azure Stack HCI cluster and created a Kubernetes cluster, we provide a couple ways to manage and monitor your Kubernetes infrastructure:
* On-premises using popular tools like Kubectl and Kubernetes dashboard - use an open-source web-based interface to deploy applications to a Kubernetes cluster, manage cluster resources, troubleshoot, and view running applications.
* In the Azure portal using Azure Arc - use an Azure service to manage Azure Kubernetes Service and Kubernetes clusters deployed across your cloud and on-premises environments. You can use Azure Arc to add and remove Kubernetes clusters as well as nodes to a Kubernetes cluster, change network settings, and install add-ons.
Azure Arc also enables you to manage your Kubernetes clusters with other Azure services including:
* Azure Monitor
* Azure Policy
* Role-Based Access Control

### Run Linux and Windows containers
Azure Kubernetes Service fully supports both Linux-based and Windows-based containers. When you create a Kubernetes cluster on Azure Stack HCI, you can choose whether to create node pools (groups of identical VMs) to run Linux containers, Windows containers, or both.
Azure Kubernetes Service creates the Linux and Windows VMs so that you don't have to directly manage the Linux or Windows operating systems.

### Secure your container infrastructure
Azure Kubernetes Service includes a number of features to help secure your container infrastructure:

* Hypervisor-based isolation for worker nodes - Each Kubernetes cluster runs on its own dedicated and isolated set of virtual machines so tenants can share the same physical infrastructure.
* Microsoft-maintained Linux and Windows images for worker nodes - Worker nodes run Linux and Windows virtual machine images created by Microsoft to adhere to security best practices. 
* Microsoft also refreshes these images monthly with the latest security updates.

## More Information
For more information check the the [Azure Kubernetes Service on Azure Stack HCI documentation](https://aka.ms/AKSonHCI-Docs)

