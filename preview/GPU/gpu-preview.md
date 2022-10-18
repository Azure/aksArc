# Use GPUs for compute-intensive workloads on Azure Kubernetes Service (AKS) on Azure Stack HCI and Windows Server

© 2022 Microsoft Corporation. All rights reserved. Any use or distribution of these materials without express authorization of Microsoft Corp. is strictly prohibited.

## Disclaimer

Azure may include preview, beta, or other pre-release features, services, software, or regions offered by Microsoft ("Previews"). Previews are licensed to you as part of your agreement governing use of Azure.

Pursuant to the terms of your Azure subscription, PREVIEWS ARE PROVIDED "AS-IS," "WITH ALL FAULTS," AND "AS AVAILABLE," AND ARE EXCLUDED FROM THE SERVICE LEVEL AGREEMENTS AND LIMITED WARRANTY. Previews may not be covered by customer support. Previews may be subject to reduced or different security, compliance and privacy commitments, as further explained in the Microsoft Privacy Statement, Microsoft Azure Trust Center, the Product Terms, the DPA, and any additional notices provided with the Preview. The following terms in the DPA do not apply to Previews: Processing of Personal Data; GDPR, Data Security, and HIPAA Business Associate. Customers should not use Previews to process Personal Data or other data that is subject to heightened legal or regulatory requirements.

Certain named Previews are subject to additional terms set forth below, if any. These Previews are made available to you pursuant to these additional terms, which supplement your agreement governing use of Azure. We may change or discontinue Previews at any time without notice. We also may choose not to release a Preview into "General Availability".

See [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/en-us/support/legal/preview-supplemental-terms/) for the latest version of the Supplemental Terms of Use for Microsoft Azure Previews.

NVIDIA Software. The software may include components developed and owned by NVIDIA Corporation or its licensors. The use of these components is governed by the NVIDIA end user license agreement located at https://www.nvidia.com/content/DriverDownload-March2009/licence.php?lang=us.


Graphical Processing Units (GPU) are used for compute-intensive workloads such as graphics and video rendering in High Performance Computing (HPC), deep learning and more.

## Known issues and limitations

- VMs with GPU enabled are not added to HA clustering in Windows Server 2019, Windows Server 2002 or Azure Stack HCI. This functionality will be available in a later version of Windows Server and Azure Stack HCI.
- There is a 1:1 mapping of GPU to VM.
- GPU enabled VMs are not pinned to a specific worker node and will not automatically failover to another physical node. AKS-HCI will recreate the VM on another physical node should the node hosting the current VM go down. This might incur application downtime during this preview if the application is not redundantly setup.
- GPU-enabled node pools running with `Standard_NK12` have not been thoroughly tested. We recommend using `Standard_NK6` only.
- If you allocate more worker nodes than available GPUs, this causes a VM leak (the VM appearing in off state). This VM has no impact on the cluster and should be cleaned up by either running remove-akshcicluster or uninstall-akshci. This issue will be resolved in an upcoming release. 
- On a cluster with 4 GPUs, if you start off with 1 worker node enabled with GPU, then scale up to 4 nodes, the set-akshcinodepool command incorrectly reports that cluster does not have enough resources however, all the worker nodes are properly created.

Important: The GPU-enabled node pools feature is still in preview and some scenarios are still being actively validated and tested; you might notice some behavior that is different from what is described in this preview document.

## Before you begin

If you are updating AKS from an older preview version that is running GPU-enabled node pools, make sure you remove all workload clusters running GPU before you begin. 

### Step 1: Uninstall the Nvidia host driver

On each host machine, run the following command to uninstall the NVIDIA host driver, then reboot the machine:

```
PS C:\> "C:\Windows\SysWOW64\RunDll32.EXE" "C:\Program Files\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL",UninstallPackage Display.Driver
```

On Windows Server host machines, you can navigate to the Control Panel > Add or Remove programs and uninstall the NVIDIA host driver, then reboot the machine. 

After the host machine reboots, confirm that the driver has been successfully uninstalled. Open an elevated PowerShell terminal and run the following command. 

```
PS C:\> Get-PnpDevice  | select status, class, friendlyname, instanceid | findstr /i /c:"3d video" 
```

You should see the GPU devices appearing in an error state as shown in this sample output.

```output
Error       3D Video Controller                   PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
Error       3D Video Controller                   PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000 
```

### Step 2: Dismount the host driver from the host 

Uninstalling the host driver will cause the physical GPU to go into an error state. You will need to dismount all the GPU devices from the host. 

For each GPU (3D Video Controller) device, run the following commands in PowerShell. You will need to copy the instance id e.g. `PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000` from the previous command output.

```output
$id1 = "<Copy and paste GPU instance id into this string>"  
$lp1 = (Get-PnpDeviceProperty -KeyName DEVPKEY_Device_LocationPaths -InstanceId $id1).Data[0] 
Disable-PnpDevice -InstanceId $id1 -Confirm:$false 
Dismount-VMHostAssignableDevice -LocationPath $lp1 -Force 
```

To confirm that the GPUs have been correctly dismounted from the host, run the following command. You should GPUs in an `Unknown` state. 

```output
PS C:\> Get-PnpDevice  | select status, class, friendlyname, instanceid | findstr /i /c:"3d video" 
Unknown       3D Video Controller               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
Unknown       3D Video Controller               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000 
```

### Step 3: Install the NVIDIA mitigation driver 

Visit the [NVIDIA data center documentation](https://docs.nvidia.com/datacenter/tesla/gpu-passthrough/) to download the NVIDIA mitigation driver. After downloading the driver, expand the archive and follow these steps to install the mitigation driver on each host machine. 

To install the mitigation driver, navigate to the folder containing the extracted files, right click on `nvidia_azure_stack_T4_base.inf` and select Install. Check that you have the correct driver; AKS currently supports only the NVIDIA Tesla T4 GPU. 

You could also install using the command line by navigating to the folder and run the following commands to install the mitigation driver.

```powershell
pnputil /add-driver nvidia_azure_stack_T4_base.inf /install 

pnputil /scan-devices 
```

After installing the mitigation driver, you will see the GPU’s listed as `OK` state under `Nvidia T4_base - Dismounted `

```powershell
PS C:\> Get-PnpDevice  | select status, class, friendlyname, instanceid | findstr /i /c:"nvidia" 
OK       Nvidia T4_base - Dismounted               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&32EEF88F&0&0000 
OK       Nvidia T4_base - Dismounted               PCI\VEN_10DE&DEV_1EB8&SUBSYS_12A210DE&REV_A1\4&3569C1D3&0&0000
```

### Step 4: Repeat steps 1 to 3 for each node in your failover cluster.


## Install or Update AKS on Azure Stack HCI or Windows Server

Visit the AKS quickstart using [PowerShell](https://docs.microsoft.com/en-us/azure-stack/aks-hci/kubernetes-walkthrough-powershell) or using [Windows Admin Center](https://docs.microsoft.com/en-us/azure-stack/aks-hci/setup) to install or update AKS on Azure Stack HCI or Windows Server.

## Enable the Preview Channel

```powershell
PS C:\> Enable-AksHciPreview 
```

## Create a new workload cluster with a GPU-enabled node pool

Create a workload cluster with a GPU node pool. Currently, using GPU-enabled node pools is only available for Linux node pools.

Note:  We recommend using only *Standard_NK6* in this preview.  GPU-enabled node pools running with `Standard_NK12` have not been thoroughly tested. 

```powershell
New-AksHciCluster -Name "gpucluster" -nodePoolName "gpunodepool" -nodeCount 2 -OSType linux -nodeVmSize Standard_NK6 
```

Post installation of the workload cluster, run the following command to get your Kubeconfig:

```powershell
PS C:> Get-AksHciCredential -Name gpucluster
```

##  Confirm that GPUs are schedulable

With your GPU node pool created, confirm that GPUs are schedulable in Kubernetes. First, list the nodes in your cluster using the [kubectl get nodes](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command:

```
$ kubectl get nodes
```

```output
NAME             STATUS  ROLES                 AGE   VERSION
moc-l9qz36vtxzj  Ready   control-plane,master  6m14s  v1.22.6
moc-lhbkqoncefu  Ready   <none>                3m19s  v1.22.6
moc-li87udi8l9s  Ready   <none>                3m5s  v1.22.6
```

 Now use the [kubectl describe node](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe) command to confirm that the GPUs are schedulable. Under the *Capacity* section, the GPU should list as `nvidia.com/gpu: 1`.

```powershell
kubectl describe node <nodename> | findstr "gpu"
```

The output should display the GPU(s) from the worker node and look something like this

```output
         nvidia.com/gpu.compute.major=7
         nvidia.com/gpu.compute.minor=5
         nvidia.com/gpu.count=1
         nvidia.com/gpu.family=turing
         nvidia.com/gpu.machine=Virtual-Machine
         nvidia.com/gpu.memory=16384
         nvidia.com/gpu.product=Tesla-T4
Annotations:    cluster.x-k8s.io/cluster-name: gpucluster
	            cluster.x-k8s.io/machine: gpunodepool-md-58d9b96dd9-vsdbl
	            cluster.x-k8s.io/owner-name: gpunodepool-md-58d9b96dd9
         nvidia.com/gpu:   1
		 nvidia.com/gpu:   1
ProviderID:         moc://gpunodepool-97d9f5667-49lt4
kube-system         gpu-feature-discovery-gd62h       0 (0%)    0 (0%)   0 (0%)      0 (0%)     7m1s
         nvidia.com/gpu   0     0
```

## Run a GPU-enabled workload

Once the above steps are completed create a new yaml file for testing e.g. gpupod.yaml: Copy and paste the below yaml into the new file named 'gpupod.yaml' and save it.

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

Run the following command to deploy the sample application

```powershell
kubectl apply -f gpupod.yaml
```

Verify if the pod has started, completed running and the GPU is assigned:

```powershell
kubectl describe pod cuda-vector-add | findstr 'gpu'
```

should show one GPU assigned.

```output
    nvidia.com/gpu: 1
    nvidia.com/gpu: 1
```

Check the log file of the pod to see if the test has passed

```powershell
kubectl logs cuda-vector-add
```

Sample output

```
[Vector addition of 50000 elements]
Copy input data from the host memory to the CUDA device
CUDA kernel launch with 196 blocks of 256 threads
Copy output data from the CUDA device to the host memory
Test PASSED
Done
```

Note: If you receive a version mismatch error when calling into drivers, such as, CUDA driver version is insufficient for CUDA runtime version, review the NVIDIA driver matrix compatibility chart - https://docs.nvidia.com/deploy/cuda-compatibility/index.html

# Frequently Asked Questions

### What GPU-enabled VM sizes does AKS on Azure Stack HCI or Windows Server support?

In this preview version we support creating node pools using `Standard_NK6` only. GPU-enabled node pools running with `Standard_NK12` have not been thoroughly tested. 

### What happens during upgrade of a GPU-enabled node pool?

Upgrading GPU-enabled node pools follows the same rolling upgrade pattern that's used for regular node pools. Hence, for GPU-enabled node pools for a new VM to be successfully created on the physical host machine, it requires one or more physical GPUs to be available for successful device assignment. This ensures that your applications can continue running when Kubernetes schedules pods on this upgraded node. 

Before you upgrade

1. Plan for downtime during the upgrade 
2. Have 1 extra GPU per physical host if you a running the *Standard_NK6* or 2 extra GPUs if you are running *Standard_NK12*. If you are running at full capacity don’t have an extra GPU, we recommend scaling down your node pool to a single node before the upgrade, then scaling up after upgrade succeeds.

### What happens if I don't have extra physical GPUs on my physical machine during an upgrade?

If an upgrade is triggered on a cluster without extra GPU resources to facilitate the rolling upgrade, the upgrade process will hang. This is because the upgrade process does not check if the physical host has enough GPU resources available before deploying the VM. If you are running at full capacity don’t have an extra GPU, we recommend scaling down your node pool to a single node before the upgrade, then scaling up after upgrade succeeds.

### What should I do if a physical host machine running a GPU-enabled node pool reboots?

Once the host machine has rebooted, your AKS cluster should recover seamlessly.

### What happens if I attempt to create a GPU-enabled node pool or scale a node pool but all physical GPUs are already assigned?

When you create a GPU enabled or scale a GPU enabled node pool but all physical GPUs are already assigned and there are no resources available, you will see an error such as: `Error: The Host does not have enough hardware (GPU) resources to complete the <add|Set>-AksHciNodePool request. Make sure there are enough resources available and try again.` 

To resolve this, make sure you have available GPUs before scaling the node pool.

