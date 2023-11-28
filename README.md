# Welcome to the AKS repo

## What's new
We are now part of the Azure adaptive cloud and the AKS family. To reflect this huge move we have simplified the product name from "AKS hybrid deployment options" to AKS. 
When needed we will suffix AKS with a platform name i.e. AKS for Azure Stack HCI or AKS for Windows Server, in general though we are simply AKS which you can deploy on your own infrastructure and manage through the cloud using Azure Arc. 

**Why is the repo then named aksArc?**
There is already an AKS repo and merging into that will be one of our next steps we want to make.

To learn more about the Azure adaptive cloud check out this [blog post](https://azure.microsoft.com/blog/advancing-hybrid-cloud-to-adaptive-cloud-with-azure/).

This repo is where the AKS team tracks features and issues with you encounter with AKS on your infrastructure. We are monitoring this repo and triage new issues regularly.

## Overview

All AKS versions Microsoft ships for edge or datacenter deployment are part of the "AKS" family, this includes:
* [AKS on Azure Stack HCI and Windows Server (GA product)](https://aka.ms/aks-hybrid) 
  *  This is the Arc Connected version of AKS hybrid. AKS clusters created on premise are connnected to Azure using Azure Arc enabled Kubernetes agents and are managed using PowerShell or Windows Admin Center
* [AKS on Azure Stack Hub](https://learn.microsoft.com/azure-stack/user/azure-stack-kubernetes-aks-engine-overview)
* [AKS on IoT (AKS Edge Essentials)](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-overview)
* [AKS hybrid cluster provisioning from Azure (Public Preview)](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-hybrid-preview-overview)
  * This is the Arc Resource Bridge based implementation which allows you to provision AKS hybrid clusters on premise. Thes clustes are always Arc enabled and managed entirely from the cloud like a cloud based AKS cluster would be. 

## What you will find here
This repository is a central place for tracking features and issues with AKS. This repository is monitored by the product team in order to engage with our community and discuss questions, customer scenarios, or feature requests.

Support through issues on this repository is provided on a best-effort basis for issues that are reproducible outside of a specific cluster configuration (see Bug Guidance below). To receive urgent support you should file a support request through official Azure support channels as production and urgent support is explicitly out of scope for issues filed in this repository.

> **IMPORTANT**: For official customer support with response-time SLAs please see
[Azure Support options][1] and [AKS Support Policies][2]. 

Do not file issues for AKS-Engine, Virtual-Kubelet, Azure Container Instances, or services on this repository unless it is related to that feature/service and functionality with AKS. For other tools, products and services see the Upstream Azure Compute projects page.

We want to hear from you! Respond to this short and [anonymous survey](https://aka.ms/AKSHCIPreviewSurvey) to share your thoughts with us.

## Important AKS hybrid links
|||
|-----|-----|
|Evaluation Guide|https://aka.ms/aks-hybrid-evaluate|
|Roadmap|https://aka.ms/aks-hybrid-roadmap|
|Release Notes|https://aka.ms/AKS-hybrid-Releasenotes|
|Known Issues|https://aka.ms/AKS-hybrid-issues|
|Documentaton|https://aka.ms/aks-hybrid-docs|
|Customer Voice Community|https://aka.ms/aks-hybrid-community|
|Meet the product team in Microsoft Teams<br>Fill in the form and we will add you to the channel ASAP.|https://aka.ms/aks-hybrid-teams|

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

* A good title: Clear, relevant and descriptive - so that a general idea of the
  problem can be grasped immediately
* Description: Before you go into the detail of steps to replicate the issue,
  you need a brief description.
  * Assume that whomever is reading the report is unfamiliar with the
    issue/system in question
* Clear, concise steps to replicate the issue outside of your specific cluster.
  * These should let anyone clearly see what you did to see the problem, and
    also allow them to recreate it easily themselves. This section should also
    include results - both expected and the actual - along with relevant URLs.
* Be sure to include any supporting information you might have that could aid the developers.
  * This includes YAML files/deployments, scripts to reproduce, exact commands used, screenshots, etc.

[1]: https://azure.microsoft.com/support/options/
[2]: https://learn.microsoft.com/en-us/azure/aks/hybrid/support-policies

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
