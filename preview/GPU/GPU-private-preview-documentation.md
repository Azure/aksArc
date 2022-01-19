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

## Enabling GPU features in AKS on Azure Stack HCI ##

The Azure Kubernetes Service on Azure Stack HCI October update has all GPU required driver packages installed. 

1. Deploy the AKS Host according to the [public documentation](https://docs.microsoft.com/en-us/azure-stack/aks-hci/kubernetes-walkthrough-powershell)
2. Enable the Preview Channel
```powershell
PS C:\> Enable-AksHciPreview
```
3. Update the current deployment
``` powershell
PS C:\> Get-AksHciUpdates
PS C:\> Update-AksHci
```
This will install the required preview bits and enable updates for the preview channel.

4. Create a new AKS-HCI target cluster
> **[NOTE]** Do not change the VMSize when running the command.
> **[NOTE]** GPU is now supported on the latest Kubernetes version available in AKS on Azure Stack HCI.
> 
```powershell	
PS C:\> New-AksHciCluster -name gpuwl -linuxNodeVmSize "Standard_NK6"
```
Once the AKS cluster is deployed you need to configure a few things to ensure GPUs are working as expected. These steps will be automated later in the release cycle.

### Post-setup ###
1.	Get your Kubeconfig for the target cluster
```powershell
PS C:> Get-AksHciCredential -Name gpuwl
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
$ sudo vim /etc/containerd/config.toml
```

2. Replace the existing text with the below text: 

```toml
version = 2
[plugins]
  [plugins."io.containerd.gc.v1.scheduler"]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "ecpacr.azurecr.io/pause:3.2"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "nvidia"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = false
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
           privileged_without_host_devices = false
           runtime_engine = ""
           runtime_root = ""
           runtime_type = "io.containerd.runc.v1"
           [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
              BinaryName = "/usr/bin/nvidia-container-runtime"
              SystemdCgroup = false
  [plugins."io.containerd.runtime.v1.linux"]
    runtime = "nvidia"
```

3.	Reload containerD
```bash
$ sudo systemctl restart containerd
```

You can now exit out of the worker node.

Use kubectl to configure Kubernetes for node discovery. This will allow Kubernetes to automatically detect and tag workernodes with the required annotations.

```powershell
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.10.0/nvidia-device-plugin.yml
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/gpu-feature-discovery/v0.4.1/deployments/static/nfd.yaml
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/gpu-feature-discovery/v0.4.1/deployments/static/gpu-feature-discovery-daemonset.yaml
```

9.	Verify that there is a GPU associated with the worker node.
```powershell
PS C:\> kubectl describe node | findstr "gpu" 
```
The output should display the GPU(s) from the worker node and look something like this

```yaml
Annotations:        cluster.x-k8s.io/cluster-name: gpuwl
                    cluster.x-k8s.io/machine: gpuwl-control-plane-l2bvg
                    cluster.x-k8s.io/owner-name: gpuwl-control-plan
ProviderID:         moc://gpuwl-control-plane-f697t
                    nvidia.com/gpu.compute.major=7
                    nvidia.com/gpu.compute.minor=5
                    nvidia.com/gpu.count=1
                    nvidia.com/gpu.family=turing
                    nvidia.com/gpu.machine=Virtual-Machine
                    nvidia.com/gpu.memory=15109
                    nvidia.com/gpu.product=Tesla-T4
Annotations:        cluster.x-k8s.io/cluster-name: gpuwl
                    cluster.x-k8s.io/machine: gpuwl-linux-md-86d8f64464-79v9t
                    cluster.x-k8s.io/owner-name: gpuwl-linux-md-86d8f64464
  nvidia.com/gpu:     1
  nvidia.com/gpu:     1
ProviderID:                   moc://gpuwl-linux-md-n7n9p
  default                     gpu-feature-discovery-9tvgw             0 (0%)        0 (0%)      0 (0%)           0 (0%)         25h
  nvidia.com/gpu     0          0
```

### Testing ###
Once the above steps are completed create a new yaml file for testing e.g. gpupod.yaml:
Copy and paste the below yaml into the new file named 'gpupod.yaml' and save it.
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
Verify if the pod has started, completed running and the GPU is assigned:
```powershell
 kubectl describe pod cuda-vector-add |findstr 'gpu'
```
should show one GPU assigned.
```
      nvidia.com/gpu:  1
      nvidia.com/gpu:  1
```
Check the log file of the pod to see if the test has passed
```powershell
kubectl logs cuda-vector-add
```
should show 
```
[Vector addition of 50000 elements]
Copy input data from the host memory to the CUDA device
CUDA kernel launch with 196 blocks of 256 threads
Copy output data from the CUDA device to the host memory
Test PASSED
Done
```
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
