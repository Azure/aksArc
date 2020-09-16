# AKSHCI – Release notes
This document is for Azure Kubernetes Service on Azure Stack HCI Public Preview 1.

## What's new in this release 
<TODO: Add content>

## Resolving Known Issues and Limitations
This document has been presented to assist the user in troubleshooting possible issues during AKSHCI deployment. It is a collection of several bugs and the known issues encountered during the private preview process, with comments that describe ways to remediation. 
The AKSHCI troubleshooting guide should be your first stop in trying to resolve a bug, as most bugs are relatively new with a limited number of online resources. The fault scenarios have been grouped into different sections for ease of accessibility. 

# Troubleshooting Azure Kubernetes Service on Azure Stack HCI
When you create or manage a Kubernetes cluster using Azure Kubernetes Service on Azure Stack HCI, you might occasionally come across problems. Below are the troubleshooting guidelines to help you resolve those issues. 

## Troubleshooting Windows Admin Center
This product is currently in the public preview state, which means it is still in development. Currently there are several issues with the Windows Admin Center Azure Kubernetes Service extension: 
* For CredSSP to function successfully within the cluster create wizard, Windows Admin Center must be installed and used by the same account. Installing with one account and then trying to use it with another will result in errors.
* During cluster deployment, there may be an issue with the helm.zip file transfer. This often results in an error saying the path to the helm.zip file does not exist or is not valid. To resolve this issue, go back and retry the deployment.
* If your deployment hangs for an extended period, you may be having CredSSP or connectivity issues. Try the following steps to troubleshoot your deployment: 
    1.	On the machine running WAC, run the following command in a PowerShell window: 
    ```PowerShell
    Enter-PSSession <servername>
    ```
    2.	If this command succeeds, then you can connect to the server, and there is not a connectivity issue.
    3.	If you are running into CredSSP issues, run this command to test the trust between the gateway machine and the target machine: 
    ```PowerShell
    Enter-PSSession –ComputerName <server> –Credential company\administrator –Authentication CredSSP
    ``` 
    You can also run the following command to test the trust in accessing the local gateway: 
    ```PowerShell
    Enter-PSSession -computer localhost -credential (Get-Credential)
    ``` 
* If you are using Azure Arc and have multiple tenant IDs, run the following command to specify your desired tenant prior to deployment. A failure to do so might cause deployment failure.
``` cmd
az login –tenant<tenant>
```
* If you have just created a new Azure account and have not logged into the account on your gateway machine, you may experience issues registering your WAC gateway with Azure. To mitigate this issue, sign into your Azure account in another browser tab or window, then register the WAC gateway to Azure.
* If you believe you are having issues with Arc during deployment, you may run the following command to view the status of your Arc pods: 
``` cmd
kubectl –kubeconfig=$kcl get pods -A
```

## Next steps
If you continue to run into issues while using Azure Kubernetes Service on Azure Stack HCI, please reach out through [Microsoft Collaborate](https://docs.microsoft.com/collaborate/intro-to-mscollaborate).  

## In general, where do I find information about debugging Kubernetes problems?
Try the official guide to troubleshooting Kubernetes clusters. There is also a troubleshooting guide published by a Microsoft engineer for troubleshooting pods, nodes, clusters, and other features.
### What is the maximum pods-per-node setting for AKSHCI?

## Known Issues with AKS-HCI Public Preview
### Port forwarding for Prometheus and Grafana stops working
When installing 10 or more Linux worker nodes port forwarding for monitoringstack-prometheus-grafana-access svc might stop working
1. Deploy MsK8s Cluster on HCI and add ~10 linux worker nodes
2. Install-WSSDAddOnMonitoring 
3. C:\wssd\kubectl.exe port-forward svc/monitoringstack-prometheus-grafana-access 7000:3000 -n=addons
To resolve this issue, close the port forwarding window and restart port forwarding from an administrative command prompt by typing 
C:\wssd\kubectl.exe port-forward svc/monitoringstack-prometheus-grafana-access 7000:3000 -n=addons

### 2 CoreDNS pods are running in the management cluster
When deploying the management cluster, it is deployed as a single node integrated appliance. The installation creates 2 redundant CoreDNS pods. 
This issue will be fixed in a future release.

### Collect-ECPLogs command may fail
With larger clusters the Collect-ECPLogs command may throw an exception, fail to enumerate nodes or does not generate c:\wssd\wssdlogs.zip output file
Root Cause: The PowerShell command to zip a file `Compress-Archive` has a output file size limit of 2GB. 
This issue will be fixed in a later release.

### ECP deployment does not check for available memory before creating a new target cluster
Currently neither Windows Admin Center nor the ECP.Day0 PowerShell commands validate the available memory on the host server before creating more virtual Kubernetes nodes. This can lead to memory exhaustion and virtual machines to not start. This failure is currently not handled gracefully and the deployment will hang with no clear error message.
If you have a deployment that seems hung, open Eventviewer and check for Hyper-V related error messages indicating not enough memory to start the VM.
This issue will be fixed in a future release
ECP deploy fails on a HCI or failover cluster configured with static IPs
Attempting to deploy ECP to a failover cluster that has static IP addresses assigned and DHCP is available in the same network, the deployment will fail with the following error:
 Root cause: The deployment framework is not checking for static addresses before the deployment starts. 
This issue will be fixed in a future release.

### IPv6 must be disabled in the hosting environment
If both v4 and v6 IP addresses are bound to the physical NIC the Cloudagent service for failover clustering is using the IPv6 address for communication. Other components in the deployment framework use only IPv4. This will result in Windows Admin Center not being able to connect to the cluster and will report a remoting failure when trying to connect to the machine.
Workaround: Disable IPv6 on the physical network adapters
This issue will be fixed in a future release

### ECP Private Preview has scale limitations
We have no validated the maximum number of nodes that can be deployed in a cluster. Therefore you could potentially hit scale limits even on the largest cluster hardware available.
It is recommended not to exceed 10 windows and 10 Linux nodes per target cluster, depending on the application to be deployed in the cluster.
Exceeding the current limit can lead to unpredictable behaviors and issues:
•	Machines stuck in “Provisioning” state 
•	This can be mitigated by deleting the “stuck” VM and reducing the replica count in the cluster
•	PODs stuck in terminating state
•	Issues with Monitoring running out of memory on the node it is installed on
•	Kubelet and Kubeproxy services on Windows failing
We are working to increase the overall scale as we progress towards GA.

### Moving VMs between failover cluster nodes quickly leads to VM startup failures
When using the cluster administration tool to move a VM from one node to another node in the failover cluster the VM may fail to start on the new node. 
After moving the VM back to the original node it will fail to start there as well.
Root cause: This issue happens because the VM moved from node A to node B, and then immediately came back to node A. The logic to cleanup the first migration runs asynchronously  after the VM was brought back to node A. As a result, ECP’s "update VM location" logic found the VM on the original Hyper-V on node A, and deleted it instead of unregistering it.
Workaround: Ensure the VM is starting successfully on the new node before moving it back to the original node.

This issue will be fixed in a future release

### Load balancer in ECP requires DHCP reservation
The load balancing solution in ECP is using DHCP to assign IP addresses to service endpoints. If the IP address changes for the service endpoint due to a service restart, DHCP lease expiring due to a short expiration time the service will become inaccessible because the IP address in the Kubernetes configuration is different from what it is on the end point. This can lead to the ECP cluster becoming unavailable.
Workaround: Use a MAC address pool for the load balanced service endpoints and reserve specific IP addresses for each MAC address in the pool
This issue will be fixed in a future release.

### Cannot deploy ECP to an environment which has separate storage and compute clusters
Windows Admin Center will not deploy ECP to an environment with separate storage and compute clusters as it expects the compute and storage resources to be provided by the same cluster. In most cases it will not find CSV's exposed by the compute cluster and will refuse to proceed with deployment.
This issue will be fixed in a future release.

