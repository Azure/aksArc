# GPU enabled containers for AKS-HCI Preview Feature #

© 2021 Microsoft Corporation. All rights reserved. Any use or distribution of these materials without express authorization of Microsoft Corp. is strictly prohibited.
​​​​​​​
## Disclaimer ##
Azure may include preview, beta, or other pre-release features, services, software, or regions offered by Microsoft ("Previews"). Previews are licensed to you as part of your agreement governing use of Azure.

Pursuant to the terms of your Azure subscription, PREVIEWS ARE PROVIDED "AS-IS," "WITH ALL FAULTS," AND "AS AVAILABLE," AND ARE EXCLUDED FROM THE SERVICE LEVEL AGREEMENTS AND LIMITED WARRANTY. Previews may not be covered by customer support. Previews may be subject to reduced or different security, compliance and privacy commitments, as further explained in the Microsoft Privacy Statement, Microsoft Azure Trust Center, the Product Terms, the DPA, and any additional notices provided with the Preview. The following terms in the DPA do not apply to Previews: Processing of Personal Data; GDPR, Data Security, and HIPAA Business Associate. Customers should not use Previews to process Personal Data or other data that is subject to heightened legal or regulatory requirements.

Certain named Previews are subject to additional terms set forth below, if any. These Previews are made available to you pursuant to these additional terms, which supplement your agreement governing use of Azure. We may change or discontinue Previews at any time without notice. We also may choose not to release a Preview into "General Availability".

See [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/en-us/support/legal/preview-supplemental-terms/) for the latest version of the Supplemental Terms of Use for Microsoft Azure Previews.

NVIDIA Software. The software may include components developed and owned by NVIDIA Corporation or its licensors. The use of these components is governed by the NVIDIA end user license agreement located at https://www.nvidia.com/content/DriverDownload-March2009/licence.php?lang=us.

## Known issues and limitations ##
* VMs with GPU enabled are not added to HA clustering in Windows Server 2019 or AKS-HCI. This functionality will be available in a later version of Windows Server and AKS-HCI.
* There is a 1:1 mapping of GPU to VM.
* GPU enabled VMs are not pinned to a specific worker node and will not automatically failover to another physical node. AKS-HCI will recreate the VM on another physical node should the node hosting the current VM go down. This might incur application downtime during this preview if the application is not redundantly setup.
* Some manual configuration steps are needed to configure the Linux workernodes once the target cluster is set up.
* **This preview requires a clean install.**

## New AKS-HCI deployment ##w
## Before you begin
Uninstall AKS-HCI completely!

```powershell
PS C:\> Uninstall-AksHci
```
### Verify prerequisites for GPU support ###
1.	Use PowerShell to verify NVIDIA Tesla T4 GPU is available on all physical nodes in the system. You might have to install the driver (on all physical nodes).
```powershell
PS C:\> Get-PnpDevice -class Display
```

In addition to above GPU prerequisites 

- Make sure you have satisfied all the prerequisites on the [system requirements](https://docs.microsoft.com/en-us/azure-stack/aks-hci/system-requirements) page. 
- An Azure account to register your AKS host for billing. For more information, visit [Azure requirements](https://docs.microsoft.com/en-us/azure-stack/aks-hci/system-requirement#azure-requirements).
- **At least one** of the following access levels to your Azure subscription you use for AKS on Azure Stack HCI: 
   - A user account with the built-in **Owner** role. You can check your access level by navigating to your subscription, clicking on "Access control (IAM)" on the left hand side of the Azure portal and then clicking on "View my access".
   - A service principal with either the built-in **Kubernetes Cluster - Azure Arc Onboarding** role (minimum), the built-in **Contributer** role, or the built-in **Owner** role. 
- An Azure resource group in the East US, Southeast Asia, or West Europe Azure region, available before registration, on the subscription mentioned above.
- **At least one** of the following:
   - 2-4 node Azure Stack HCI cluster
   - Windows Server 2019 Datacenter failover cluster
   > **[NOTE]**
   > **We recommend having a 2-4 node Azure Stack HCI cluster.** If you don't have any of the above, follow instructions on the [Azure Stack HCI registration page](https://azure.microsoft.com/products/azure-stack/hci/hci-download/).

## Update to the deployment steps ##

The Azure Kubernetes Service on Azure Stack HCI October update has all GPU required driver packages installed. 

1. Deploy the AKS Host according to the [public documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/kubernetes-walkthrough-powershell)
2. Enable the Preview Channel
```powershell
PS C:\> Enable-AksHciPreview
```
3. Update the current deployment
``` powershell
PS C:\> Get-AksHciUpdates
PS C:\> Uppdate-AksHci
```
This will install the preview bits and enable updates for the preview channel.

4. Create a new AKS-HCI target cluster
> **[NOTE]** Do not change the VMSize when running the command.
> **[NOTE]** the updated Kubernetes version!
```powershell	
PS C:\> New-AksHciCluster -name gpuwl -linuxNodeVmSize "Standard_NK6" -kubernetesVersion v1.19.13
```
> **[NOTE]** The Kubernetes version must be v1.19.9!

### Post-setup ###
1.	Get your Kubeconfig for the target cluster
```powershell
PS C:? Get-AksHciCredentials -Name gpuwl
```
2. Use kubectl to get the node IP address
```powershell
kubectl get nodes -o wide
```

4.	Use SSH to connect to the linux worker and setup the configuration.
> **[NOTE]** Make sure to replace the IP address below!

```powershell
PS C:\> ssh -i C:\AksHci\.ssh\akshci_rsa clouduser@<ipaddress of linux worker node>
```
Once logged into the worker node use the below to edit the config file to enable the nvidia driver.

```bash
$ sudo vim /etc/docker/daemon.json
```

2. Change the above file content to: 

```json
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
```
3.	Reload the daemon
```bash
$ sudo systemctl daemon-reload
```
4.	Restart the Docker engine
```bash
$ sudo systemctl restart docker
```
5. Go back to powershell and retrieve the kubeconfig for the target cluster
```powershell
PS C:\> Get-AksHciCredential -Name gpuwl
```
Use kubectl to configure Kubernetes for node discovery
```powershell
PS C:\> kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/node-feature-discovery/v0.8.2/nfd-master.yaml.template
PS C:\> kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/node-feature-discovery/v0.8.2/nfd-worker-daemonset.yaml.template
PS C:\> kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.9.0/nvidia-device-plugin.yml
```
9.	Verify that there is a GPU associated with the worker node.
```powershell
PS C:\> kubectl describe node | findstr "gpu" 
```
The output should display the GPU(s) from the worker node

### Testing ###
Once the above steps are completed create a new yaml file for testing e.g. gpupod.yaml:
Copy and paste the below yaml into the new file and save it.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cuda-vector-add
spec:
  restartPolicy: OnFailure
  containers:
    - name: cuda-vector-add
      image: "k8s.gcr.io/cuda-vector-add:v0.1"
      resources:
        limits:
          nvidia.com/gpu: 1
```
```powershell
PS C:\> kubectl apply -f gpupod.yaml
```
Verify if the pod has started and the GPU is working

## Dealing with errors ##
________________________________________
```powershell
PS C:\> Get-PnpDevice -class Display 
```
If NVIDIA Tesla T4 does not appear, you need to install the drivers. If the Status of it is "Unkown", run the following commands:
```powershell
PS C:\> $InstanceId = (Get-PnpDevice -Class Display -FriendlyName "$deviceName")[0].InstanceID
PS C:\> $InstanceId = $InstanceId.replace("PCI", "PCIP")
PS C:\> Remove-VMAssignableDevice -InstancePath "$InstanceId" -VM $vm 
```
Optionally if it's attached to another vm

```powershell
PS C:\> Mount-VMHostAssignableDevice -InstancePath "$InstanceId"
PS C:\> $InstanceId = $InstanceId.replace("PCIP", "PCI")
PS C:\> Enable-PnpDevice  -InstanceId "$InstanceId" -Confirm:$false
```
If the Status of it is "Error", try: 
```powershell
PS C:\> $InstanceId = (Get-PnpDevice -Class Display -FriendlyName "$deviceName")[0].InstanceID
PS C:\> Enable-PnpDevice  -InstanceId "$InstanceId" -Confirm:$false 
```
If it doesn't solve the issue, try: 
```powershell
PS C:\> $InstanceId= (Get-PnpDevice -Class Display -FriendlyName "$deviceName")[0].InstanceID
PS C:\> Disable-PnpDevice -InstanceId "$InstanceId" -Confirm:$false
PS C:\> Dismount-VMHostAssignableDevice -force -InstancePath "$InstanceId" -Confirm:$false
PS C:\> $InstanceId = $InstanceId.replace("PCI", "PCIP")
PS C:\> Mount-VMHostAssignableDevice -InstancePath "$InstanceId"
PS C:\> $InstanceId = $InstanceId.replace("PCIP", "PCI")
PS C:\> Enable-PnpDevice  -InstanceId "$InstanceId" -Confirm:$false 
```
If it doesn't solve the issue, go into Device Manager, look into Display adapters node and try to repair the device.
 
If it doesn't solve the issue, reinstall the driver and/or restart the machine.

If none of the above solves the issue send us a note at mikek@microsoft.com and we will get engineering involved to debug the issue.
