# Welcome to the AKS enabled by Arc repo

Azure Kubernetes Service (AKS) enabled by Azure Arc is a managed Kubernetes service that you can use to deploy and manage containerized applications on-premises, in datacenters, or at edge locations such as retail stores or manufacturing plants. See [What is AKS enabled by Arc?](https://learn.microsoft.com/azure/aks/hybrid/aks-overview) for more information.

To learn more about the Azure adaptive cloud check out this [blog post](https://azure.microsoft.com/blog/advancing-hybrid-cloud-to-adaptive-cloud-with-azure/).

This repo is where the AKS team tracks features and issues with you encounter with AKS on your infrastructure. We are monitoring this repo and triage new issues regularly.

## Overview

All AKS versions Microsoft ships for edge or datacenter deployment are part of the "AKS" family, this includes:

* **[AKS on Azure Stack HCI 23H2](https://learn.microsoft.com/azure/aks/hybrid/aks-whats-new-23h2)**: AKS on Azure Stack HCI 23H2 uses Azure Arc to create new Kubernetes clusters on Azure Stack HCI directly from Azure. It enables you to use familiar tools like the Azure portal and Azure Resource Manager templates to create and manage your Kubernetes clusters running on Azure Stack HCI.
* **[AKS Edge Essentials](https://learn.microsoft.com/azure/aks/hybrid/aks-edge-overview)**: AKS Edge Essentials includes a lightweight Kubernetes distribution with a small footprint and simple installation experience, making it easy for you to deploy Kubernetes on PC-class or "light" edge hardware. Please use [github.com/Azure/aksedge](https://github.com/Azure/AKS-Edge) for AKS EE requests.
* **[AKS on Windows Server/HCI 22H2](https://learn.microsoft.com/azure/aks/hybrid/overview)**: Azure Kubernetes Service on Windows Server (and on Azure Stack HCI 22H2) is an on-premises Kubernetes implementation of AKS that automates running containerized applications at scale, using Windows PowerShell and Windows Admin Center. It simplifies deployment and management of AKS on Windows Server 2019/2022 Datacenter and Azure Stack HCI 22H2.
* **[AKS on VMWare (preview)](https://learn.microsoft.com/azure/aks/hybrid/aks-vmware-overview)**: AKS on VMware (preview) enables you to use Azure Arc to create new Kubernetes clusters on VMware vSphere. With AKS on VMware, you can manage your AKS clusters running on VMware vSphere using familiar tools like Azure CLI.

## Related AKS products

* [AKS on Azure Stack Hub](https://learn.microsoft.com/azure-stack/user/azure-stack-kubernetes-aks-engine-overview). Please use [github.com/Azure/aks-engine-azurestack](https://github.com/Azure/aks-engine-azurestack) for this product.

## What you will find here

This repository is a central place for tracking features and issues with AKS enabled by Arc. This repository is monitored by the product team in order to engage with our community and discuss questions, customer scenarios, or feature requests.

Support through issues on this repository is provided on a best-effort basis for issues that are reproducible outside of a specific cluster configuration (see Bug Guidance below). To receive urgent support you should file a support request through official Azure support channels as production and urgent support is explicitly out of scope for issues filed in this repository.

> **IMPORTANT**: For official customer support with response-time SLAs please see
[Azure Support options][1] and [AKS Support Policies][2].

Do not file issues for AKS-Engine, Virtual-Kubelet, Azure Container Instances, or services on this repository unless it is related to that feature/service and functionality with AKS. For other tools, products and services see the Upstream Azure Compute projects page.

## Important AKS Arc links

* [Evaluate using Jumpstart](https://arcjumpstart.com/azure_jumpstart_hcibox)
* [AKS Arc Roadmap](https://github.com/orgs/Azure/projects/397/views/1)
* [Release Notes](https://github.com/Azure/aksArc/releases)
* [Known Issues](https://github.com/Azure/aksArc/issues)

## Bug Reports <a name="bugs"></a>

> **IMPORTANT**: An inability to meet the below requirements for bug reports are subject to being closed by maintainers and routed to official Azure support channels to provide the proper support experience to resolve user issues.

Bug reports filed on this repository should follow the default issue template
that is shown when opening a new issue. At a bare minimum, issues reported on
this repository must:

1. Be reproducible outside of the current cluster
    * This means that if you file an issue that would require direct access to
  your cluster and/or Azure resources you will be redirected to open an Azure
  support ticket. Microsoft employees may not ask for personal / subscription
  information on Github.
      * For example, if your issue is related to custom scenarios such as
    custom network devices, configuration, authentication issues related to
    your Azure subscription, etc.

2. Contain the following information:
   * A good title: Clear, relevant and descriptive - so that a general idea of the problem can be grasped immediately
   * Description: Before you go into the detail of steps to replicate the issue, you need a brief description.
   * Assume that whomever is reading the report is unfamiliar with the issue/system in question
   * Clear, concise steps to replicate the issue outside of your specific cluster.
     * These should let anyone clearly see what you did to see the problem, and also allow them to recreate it easily themselves. This section should also include results - both expected and the actual - along with relevant URLs.
   * Be sure to include any supporting information you might have that could aid the developers.
     * This includes YAML files/deployments, scripts to reproduce, exact commands used, screenshots, etc.

[1]: https://azure.microsoft.com/support/options/
[2]: https://learn.microsoft.com/azure/aks/hybrid/support-policies

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
