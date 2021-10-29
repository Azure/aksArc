Explore the AKS on Azure Stack HCI environment
==============
Overview
-----------
With all key components deployed, including the management cluster, along with target clusters, you can now begin to explore some of the additional capabilities within AKS on Azure Stack HCI. We'll list a few recommended activities below, to expose you to some of the key elements, but for the rest, we'll [direct you over to the official documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/ "AKS on Azure Stack HCI documentation").

Contents
-----------
- [Overview](#overview)
- [Contents](#contents)
- [Deploying a simple Linux application](#deploying-a-simple-linux-application)
- [Expose a nested application to the internet](#expose-a-nested-application-to-the-internet)
- [Deploy hybrid end-to-end solutions on AKS-HCI](#deploy-hybrid-end-to-end-solutions-on-aks-hci)
- [Continue your learning](#continue-your-learning)
- [Shutting down the environment](#shutting-down-the-environment)
- [Congratulations!](#congratulations)
- [Product improvements](#product-improvements)
- [Raising issues](#raising-issues)

Deploying a simple Linux application
-----------
With your cluster up and running, to illustrate how easy it is to deploy a containerized application, The following steps will highlight key areas of deployment, testing and scaling an application.

During the deployment of AKS on Azure Stack HCI, **kubectl** was configured on your Azure VM Host. Kubectl provides a number of different ways to manage your Kubernetes clusters and applications.

As part of this brief tutorial, you'll deploy an [Azure vote application](https://github.com/Azure-Samples/azure-voting-app-redis "Azure vote application on GitHub"). In order to deploy the application, you'll need a Kubernetes manifest file. A Kubernetes manifest file defines a desired state for the cluster, such as what container images to run. The manifest we'll use in this tutorial includes two Kubernetes deployments - one for the sample Azure Vote Python application, and the other for a Redis instance. Two Kubernetes services are also created - an internal service for the Redis instance, and an external service to access the Azure Vote application from the internet.

Before you start, make sure you [review the manifest file here](/eval/yaml/azure-vote.yaml "Azure vote manifest file")

1. First, run the following command from an **administrative PowerShell command** to list your Kubernetes nodes

```powershell
kubectl get nodes
```

![Output of kubectl get nodes](/eval/media/kubectl_get_nodes.png "Output of kubectl get nodes")

*******************************************************************************************************

**NOTE** - if you receive an error that *"kubectl is not recognized as the name of a cmdlet, function, script file or operable program"*, you can either log out of the Azure VM, then log back in, or run the following command from your PowerShell console: **choco install kubernetes-cli**, then **close and re-open PowerShell**.

*******************************************************************************************************

If you've followed the steps in this eval guide, your output should look similar, with 2 Linux worker nodes and 3 control plane nodes.

2. Next, from the same **PowerShell **console**** run the following command to deploy the application directly from GitHub:

```powershell
kubectl apply -f https://raw.githubusercontent.com/Azure/aks-hci/main/eval/yaml/azure-vote.yaml
```

![Output of kubectl apply](/eval/media/kubectl_apply.png "Output of kubectl apply")

3. Next, run the following command to monitor the progress of the deployment (using the --watch argument):

```powershell
kubectl get service azure-vote-front --watch
```

During deployment, you may see the **External-IP** showing as *Pending* - when this changes to an IP address, you can use **CTRL + C** to stop the watch process.

![Output of kubectl get service](/eval/media/kubectl_get_service.png "Output of kubectl get service")

In our case, you can see that the service has been allocated the **192.168.0.152** IP address.

4. At this point, you should then be able to **open Microsoft Edge** and after accepting the defaults, you should be able to navigate to that IP address. Note, it may take a few moments to start

![Azure vote app in Edge](/eval/media/azure_vote_app.png "Azure vote app in Edge")

5. We have created a single replica of the Azure Vote front end and Redis instance. To see the number and state of pods in your cluster, use the **kubectl get command** as follows. The output should show one front end pod and one back-end pod:

```powershell
kubectl get pods -n default
```

![Output of kubectl get pods](/eval/media/kubectl_get_pods.png "Output of kubectl get pods")

6. To change the number of pods in the azure-vote-front deployment, use the **kubectl scale command**. The following example **increases the number of front end pods to 5**

```powershell
kubectl scale --replicas=5 deployment/azure-vote-front
```

![Output of kubectl scale](/eval/media/kubectl_scale.png "Output of kubectl scale")

7. Run **kubectl get pods** again to verify that additional pods have been created. After a minute or so, the additional pods are available in your cluster

```powershell
kubectl get pods -n default
```

![Output of kubectl get pods](/eval/media/kubectl_get_pods_scaled.png "Output of kubectl get pods")

You should now have 5 pods for this application.

If you want to continue your learning on AKS-HCI, and are interested in deploying Windows applications in AKS on Azure Stack HCI, [you can check out these resources on the official docs page](https://docs.microsoft.com/en-us/azure-stack/aks-hci/deploy-windows-application "Deploy Windows applications in Azure Kubernetes Service on Azure Stack HCI").

Expose a nested application to the internet
-----------
If you've followed all the steps in this guide, you'll have a running AKS-HCI infrastructure, including a target cluster that can run your containerized workloads. Additionally, if you've deployed the simple Linux application using the [tutorial above](#deploying-a-simple-linux-application), you'll now have an Azure Voting web application running in a container on your AKS-HCI infrastructure. This application will likely have been allocated an IP address from your internal NAT network, **192.168.0.0/16**, and opening your Edge browser within the Azure VM allows you to access that web application using it's 192.168.0.x IP address and optionally, its port number..

However, the Azure Voting web app, and any other apps on the 192.168.0.0/16 internal network inside your Azure VM, cannot be reached from outside of the Azure VM, unless you perform some additional configuration.

**NOTE** - This is specific to the Azure VM nested configuration, and would not be required in a production deployment on-premises.

### Add an inbound rule to your NSG ###
In this example, using the [previously deployed simple Linux application](#deploying-a-simple-linux-application), I'm going to expose **port 80** through to my Azure VM internal NAT network, and then on to my Azure Voting app.

1. Firstly, visit https://portal.azure.com/, and login with your credentials you've been using for the evaluation. 
2. Once logged in, using the search box on the dashboard, enter "akshci" and once the results are returned, click on your AKSHCIHost virtual machine.

![Virtual machine located in Azure](/eval/media/azure_vm_search.png "Virtual machine located in Azure")

1. Once on the overview blade for your VM, **in the left-hand navigation**, click on **Networking**
2. You'll see the existing network security group rules. On the right-hand side, click **Add inbound port rule**
3. In the **Add inbound security rule** blade, make any adjustments, including the **Protocol**, the **Destination port ranges** and **Name** then click **Add**

![Add inbound security rule in Azure](/eval/media/new_security_rule.png "Add inbound security rule in Azure")

**NOTE** - If you wish to expose multiple ports, you can create additional rules, or specify a range of ports within the same rule. You can also be more specific about the source traffic type, source port, and destination traffic type.

6. With the network security group rule created, **make a note of the NIC Public IP** on the **Networking blade**. Once noted down, **connect to your Azure VM** using your existing RDP information.

### Add a new NAT Static Mapping
With the network security group rule configured, there are some additional steps required to NAT the incoming traffic through to the containerized application.

1. Firstly, inside the Azure VM, in an **administrative PowerShell console**, you'll need to retrieve the external IP and port of your deployed application, by running the following command (in this case, the app front end name is "azure-vote-front")

```powershell
kubectl get service azure-vote-front
```

![Using kubectl to retrieve info about the application](/eval/media/kubectl_service.png "Using kubectl to retrieve info about the application")

2. As you can see from the image, this particular app has been assigned the IP address **192.168.0.153** and is accessible on port **80**
3. To create a new Static NAT Mapping, run the following PowerShell command:

```powershell
Add-NetNatStaticMapping -NatName "AKSHCINAT" -Protocol TCP -ExternalIPAddress '0.0.0.0/24' -ExternalPort 80 `
    -InternalIPAddress '192.168.0.153' -InternalPort 80
```
![Result of Add-NetNatStaticMapping](/eval/media/Add-NetNatStaticMapping.png "Result of Add-NetNatStaticMapping")

4. The NAT static mapping should be successfully created, and you can now test the access of your application from outside of the Azure VM. You should try to access the web application using the **Azure VM Public IP** which you [noted down earlier](#add-an-inbound-rule-to-your-nsg).

![Access web application using Azure Public IP](/eval/media/access_web_app.png "Access web application using Azure Public IP")

**NOTE** - This process creates a NAT static mapping that's specific to that External IP and Port of that specific Kubernetes service you have deployed in the environment. You will need to repeat the process for additional applications. To learn more about PowerShell NetNat commands, [visit the official documentation](https://docs.microsoft.com/en-us/powershell/module/netnat "Official documentation for NetNat").

Deploy hybrid end-to-end solutions on AKS-HCI
-----------

Now that you are knowledgeable on how to interact with various aspects of AKS on Azure Stack HCI,it's a good time to build your knowledge by experimenting with more advanced hybrid solutions that run on AKS-HCI. These hybrid solutions use AKS on Azure Stack HCI capabilities in combination with other Azure Services to enable more complex hybrid use cases.

The following samples demonstrate how to quickly get started developing various hybrid solutions, using AKS on Azure Stack HCI and other Azure Services. Each sample solution is self-contained and may require extra Azure resources for its operations.

### AI Video Analytics at the Edge (Vision on Edge)

Vision on Edge (VoE) is an open-source end-to-end solution for AKS on Azure Stack HCI that simplifies the customer journey in creating and deploying vision-based AI analytics at the edge using a combination of various Azure services and open-source software. Vision on Edge takes advantage of:
* Azure Custom Vision
* Azure IoT Hub/Azure IoT Edge

To help you to:
* Go from zero to PoC by deploying our pre-built use-case scenarios such as defect detection and people counting in manufacturing and retail industries, respectively, on your own camera feeds
* Go from PoC to MVP by creating your very own custom AI model capable of detecting your desired objects from data gathered from your cameras easily through VoE UI
* Go from MVP to Production by deploying your custom AI solution/model, accelerated to 10+ cameras in parallel

<p align="center">
   <img src="../media/VoEBox.gif" height="450"/>
</p>

**Deployment Steps**

Please follow the [instructions given here](https://github.com/penorouzi/azure-intelligent-edge-patterns/blob/master/factory-ai-vision/Tutorial/K8s_helm_deploy.md) to install VoE on Kubernetes (AKS/AKS-HCI) using VoE Helm chart.

Continue your learning
-----------
In addition to the scenarios covered, there are a number of other useful tutorials that you can follow to help grow your knowledge around Kubernetes, including tutorials that cover using GitOps, and Azure Policy.

* [Deploy configurations using GitOps on Arc enabled Kubernetes cluster](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/use-gitops-connected-cluster "Deploy configurations using GitOps on Arc enabled Kubernetes cluster")
* [Use Azure Policy to apply cluster configurations at scale](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/use-azure-policy "Use Azure Policy to apply cluster configurations at scale")
* [Enable monitoring of Azure Arc enabled Kubernetes cluster](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-enable-arc-enabled-clusters "Enable monitoring of Azure Arc enabled Kubernetes cluster")

In addition to these resources, it's certainly worth exploring additional scenarios around Azure Arc, on the [Azure Arc jumpstart website](https://azurearcjumpstart.io "Azure Arc jumpstart website").  Here, you can explore scenarios around [Azure Arc enabled Kubernetes](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/ "Azure Arc enabled Kubernetes"), and [Azure Arc enabled data services](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/ "Azure Arc enabled data services").

Shutting down the environment
-----------
To save costs, you may wish to shut down your AKS on Azure Stack HCI infrastructure, and Hyper-V host. In order to do so, it's advisable to run the following commands, from the Hyper-V host, to cleanly power down the different components, before powering down the Azure VM itself.

1. On your Hyper-V host, open **PowerShell as administrator** and run the following command:

```powershell
# Power down VMs on your Hyper-V host
Get-VM | Stop-VM -Force
```

2. Once all the VMs are switched off, you can then shut down your Hyper-V host. Visit https://portal.azure.com/, and login with your Azure credentials.  Once logged in, using the search box on the dashboard, enter "akshci" and once the results are returned, click on your AKSHCIHost001 virtual machine.

![Virtual machine located in Azure](/eval/media/azure_vm_search.png "Virtual machine located in Azure")

3. Once on the overview blade for your VM, along the **top navigation**, click **Stop**, and then click **OK**.  Your VM will then be deallocated and **compute charges** will cease.

Congratulations!
-----------
You've reached the end of the evaluation guide.  In this guide you have:

* Deployed/Configured a Windows Server 2019 or 2022 Hyper-V host in Azure to run your nested sandbox environment
* Deployed the AKS on Azure Stack HCI management cluster on your Windows Server Hyper-V environment
* Deployed a target cluster to run applications and services
* Optionally integrated with Azure Arc
* Set the foundation for further learning!

Great work!

Product improvements
-----------
If, while you work through this guide, you have an idea to make the product better, whether it's something in AKS on Azure Stack HCI, Windows Admin Center, or the Azure Arc integration and experience, let us know! We want to hear from you! [Head on over to our AKS on Azure Stack HCI GitHub page](https://github.com/Azure/aks-hci/issues "AKS on Azure Stack HCI GitHub"), where you can share your thoughts and ideas about making the technologies better.  If however, you have an issue that you'd like some help with, read on... 

Raising issues
-----------
If you notice something is wrong with the evaluation guide, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  Raise an issue in GitHub, and we'll be sure to fix this as quickly as possible!

If however, you're having a problem with AKS on Azure Stack HCI **outside** of this evaluation guide, make sure you post to [our GitHub Issues page](https://github.com/Azure/aks-hci/issues "GitHub Issues"), where Microsoft experts and valuable members of the community will do their best to help you.
