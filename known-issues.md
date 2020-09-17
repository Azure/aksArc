# Known Issues for zure Kubernetes Service on Azure Stack HCI Public Preview

## Deployment after running Remove-AKSHCI PowerShell command fails from Windows Admin Center
If you are experiencing deployment issues or want to reset your deployment make sure you close all Windows Admin Center Instances
connected to Azure Kubernetes Service on Azure Stack HCI before running Remove-AKSHCI from a PowerShell window.

## When using kubectl to delete a node the associated virtual machine might not be cleaned up correctly
### Steps to reproduce
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

## Active Directory permissions for domain joined Azure Stack HCI nodes 
Users deploying and configuring Azure Kubernetes Service on Azure Stack HCI need to have "Full Control" permission to create AD objects in the Active Directory container the server and service
objects are created in. 
