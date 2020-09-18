# Known Issues for Azure Kubernetes Service on Azure Stack HCI Public Preview


## Recovering from a failed AKS on Azure Stack HCI deployment
If you are experiencing deployment issues or want to reset your deployment make sure you close all Windows Admin Center instances connected to Azure Kubernetes Service on Azure Stack HCI before running Uninstall-AksHci from a PowerShell administrative window.

## When using kubectl to delete a node, the associated VM might not be deleted
You will encounter this issue if you follow these steps:
* Create a Kubernetes cluster
* Scale the cluster to more than 2 nodes
* Use kubectl delete node <node-name> to delete a node 
* Run kubectl get nodes. The removed node does is not listed in the output
* Open a PowerShell Admin Window
* Run get-vm, The removed node is still listed

This leads to the system not recognizing the node is missing and a new node will not be spun up. 
This will be fixed in a subsequent release

## Time synchronization must be configured across all physical cluster nodes and in Hyper-V
To ensure gMSA and AD authentication works, ensure that the Azure Stack HCI cluster nodes are configured to synchronize their time with a domain controller or other
time source and that Hyper-V is configured to synchronize time to any virtual machines.

## Special Active Directory permissions are needed for domain joined Azure Stack HCI nodes 
Users deploying and configuring Azure Kubernetes Service on Azure Stack HCI need to have "Full Control" permission to create AD objects in the Active Directory container the server and service objects are created in. 

## Get-AksHciLogs command may fail
With large clusters the Get-AksHciLogs command may throw an exception, fail to enumerate nodes or will not generate c:\wssd\wssdlogs.zip output file.
This is because the PowerShell command to zip a file `Compress-Archive` has an output file size limit of 2GB. 
This issue will be fixed in a later release.

## Azure Kubernetes Service PowerShell deployment does not check for available memory before creating a new target cluster
The Aks-Hci PowerShell commands does not validate the available memory on the host server before creating Kubernetes nodes. This can lead to memory exhaustion and virtual machines to not start. This failure is currently not handled gracefully and the deployment will hang with no clear error message.
If you have a deployment that seems hung, open Eventviewer and check for Hyper-V related error messages indicating not enough memory to start the VM.
This issue will be fixed in a future release

## Azure Kubernetes Service deployment fails on an Azure Stack HCI configured with static IPs, VLANs, SDN or proxies.
While deploying Azure Kubernetes Service on an Azure Stack HCI cluster that has static IPs, VLANs, SDN or proxies, the deployment fails at cluster creation. 
This issue will be fixed in a future release.

## IPv6 must be disabled in the hosting environment
If both IPv4 and IPv6 addresses are bound to the physical NIC, the cloudagent service for clustering uses the IPv6 address for communication. Other components in the deployment framework only use IPv4. This will result in Windows Admin Center unable to connect to the cluster and will report a remoting failure when trying to connect to the machine.
Workaround: Disable IPv6 on the physical network adapters
This issue will be fixed in a future release

## Moving virtual machines between Azure Stack HCI cluster nodes quickly leads to VM startup failures
When using the cluster administration tool to move a VM from one node (Node A) to another node (Node B) in the Azure Stack HCI cluster, the VM may fail to start on the new node. After moving the VM back to the original node it will fail to start there as well.
This issue happens because the logic to cleanup the first migration runs asynchronously. As a result, Azure Kubernetes Service's "update VM location" logic finds the VM on the original Hyper-V on node A, and deletes it, instead of unregistering it.
Workaround: Ensure the VM has started successfully on the new node before moving it back to the original node.
This issue will be fixed in a future release

## Load balancer in Azure Kubernetes Service requires DHCP reservation
The load balancing solution in Azure Kubernetes Service on Azure Stack HCI uses DHCP to assign IP addresses to service endpoints. If the IP address changes for the service endpoint due to a service restart, DHCP lease expires due to a short expiration time. The service will therefore become inaccessible because the IP address in the Kubernetes configuration is different from what it is on the end point. This can lead to the Kubernetes cluster becoming unavailable.
To get around this issue, use a MAC address pool for the load balanced service endpoints and reserve specific IP addresses for each MAC address in the pool.
This issue will be fixed in a future release.

## Cannot deploy Azure Kubernetes Service to an environment that has separate storage and compute clusters
Windows Admin Center will not deploy Azure Kubernetes Service to an environment with separate storage and compute clusters as it expects the compute and storage resources to be provided by the same cluster. In most cases it will not find CSVs exposed by the compute cluster and will refuse to proceed with deployment.
This issue will be fixed in a future release.


