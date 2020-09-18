# Known Issues for Azure Kubernetes Service on Azure Stack HCI Public Preview

## Deployment after running Remove-AKSHCI PowerShell command fails from Windows Admin Center
If you are experiencing deployment issues or want to reset your deployment make sure you close all Windows Admin Center Instances
connected to Azure Kubernetes Service on Azure Stack HCI before running Remove-AKSHCI from a PowerShell window.

## When using kubectl to delete a node the associated virtual machine might not be cleaned up correctly

Steps to reproduce
* Deploy a workload cluster
* Scale the workload cluster to > 2 nodes
* Use kubectl delete to delete a node. 
* run kubctl get nodes. NOTE: The removed node does is not listed in the output.
* Open a PowerShell Admin Window
* Run get-vm, NOTE: the removed node is still listed

This leads to the system not recognizing the node is missing and a new node will not be spun up. 
This will be fixed in a subsequent release

## Time syncchornization must be configured across all physical cluster nodes and in Hyper-V
To ensure gMSA and AD authentication will work ensure that the nodes in the Azure Stack HCI cluster are configured to synchronize their time with a domain controller or other
time source and that Hyper-V is configured to synchronize time to any virtual machines.

## Special Active Directory permissions are needed for domain joined Azure Stack HCI nodes 
Users deploying and configuring Azure Kubernetes Service on Azure Stack HCI need to have "Full Control" permission to create AD objects in the Active Directory container the server and service
objects are created in. 

## Port forwarding for Prometheus and Grafana stops working
When installing 10 or more Linux worker nodes port forwarding for monitoringstack-prometheus-grafana-access svc might stop working
1. Deploy a Kubernetes cluster on Azure Stack HCI and add ~10 Linux worker nodes
2. Install-WSSDAddOnMonitoring 
3. C:\wssd\kubectl.exe port-forward svc/monitoringstack-prometheus-grafana-access 7000:3000 -n=addons
To resolve this issue, close the port forwarding window and restart port forwarding from an administrative command prompt by typing 
C:\wssd\kubectl.exe port-forward svc/monitoringstack-prometheus-grafana-access 7000:3000 -n=addons

## 2 CoreDNS pods are running in the management cluster
When deploying the management cluster, it is deployed as a single node integrated appliance. The installation creates 2 redundant CoreDNS pods. 
This issue will be fixed in a future release.

## Collect-AKSHCILogs command may fail
With larger clusters the Collect-AKS-HCI Logs command may throw an exception, fail to enumerate nodes or does not generate c:\wssd\wssdlogs.zip output file
Root Cause: The PowerShell command to zip a file `Compress-Archive` has a output file size limit of 2GB. 
This issue will be fixed in a later release.

## AKS-HCI deployment does not check for available memory before creating a new target cluster
Currently neither Windows Admin Center nor the AKS-HCI.Day0 PowerShell commands validate the available memory on the host server before creating more virtual Kubernetes nodes. This can lead to memory exhaustion and virtual machines to not start. This failure is currently not handled gracefully and the deployment will hang with no clear error message.
If you have a deployment that seems hung, open Eventviewer and check for Hyper-V related error messages indicating not enough memory to start the VM.
This issue will be fixed in a future release
AKS-HCI deploy fails on a HCI or failover cluster configured with static IPs
Attempting to deploy AKS-HCI to a failover cluster that has static IP addresses assigned and DHCP is available in the same network, the deployment will fail with the following error:
 Root cause: The deployment framework is not checking for static addresses before the deployment starts. 
This issue will be fixed in a future release.

## IPv6 must be disabled in the hosting environment
If both v4 and v6 IP addresses are bound to the physical NIC the Cloudagent service for failover clustering is using the IPv6 address for communication. Other components in the deployment framework use only IPv4. This will result in Windows Admin Center not being able to connect to the cluster and will report a remoting failure when trying to connect to the machine.
Workaround: Disable IPv6 on the physical network adapters
This issue will be fixed in a future release

## Moving virtual machines between failover cluster nodes quickly leads to VM startup failures
When using the cluster administration tool to move a VM from one node to another node in the failover cluster the VM may fail to start on the new node. 
After moving the VM back to the original node it will fail to start there as well.
Root cause: This issue happens because the VM moved from node A to node B, and then immediately came back to node A. The logic to cleanup the first migration runs asynchronously  after the VM was brought back to node A. As a result, AKS-HCI’s "update VM location" logic found the VM on the original Hyper-V on node A, and deleted it instead of unregistering it.
Workaround: Ensure the VM is starting successfully on the new node before moving it back to the original node.

This issue will be fixed in a future release

## Load balancer in AKS-HCI requires DHCP reservation
The load balancing solution in AKS-HCI is using DHCP to assign IP addresses to service endpoints. If the IP address changes for the service endpoint due to a service restart, DHCP lease expiring due to a short expiration time the service will become inaccessible because the IP address in the Kubernetes configuration is different from what it is on the end point. This can lead to the AKS-HCI cluster becoming unavailable.
Workaround: Use a MAC address pool for the load balanced service endpoints and reserve specific IP addresses for each MAC address in the pool
This issue will be fixed in a future release.

## Cannot deploy AKS-HCI to an environment which has separate storage and compute clusters
Windows Admin Center will not deploy AKS-HCI to an environment with separate storage and compute clusters as it expects the compute and storage resources to be provided by the same cluster. In most cases it will not find CSV's exposed by the compute cluster and will refuse to proceed with deployment.
This issue will be fixed in a future release.
