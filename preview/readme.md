Microsoft is deprecating the AKS hybrid cluster provisioning from Azure (preview) features and replacing them with the release version of the feature set in the next two months. This decision was made after careful consideration of our product roadmap and the needs of our customers.

We understand that this change may impact your workflow, and we are committed to making this transition as smooth as possible.

Our team is working hard to provide steps and processes to help transition workloads from the preview AKS clusters to the release version of AKS hybrid. We will post these in this document as we get closer to the transition date. You will also receive email communication from Azure on the steps to take as soon as they are ready. 

If you have any questions or concerns, please reach out to us by [opening a GitHub issue](https://github.com/Azure/aks-hybrid/issues). We appreciate your understanding and continued support.

# IMPORTANT!
We have reintroduced the portal experice with resource model changes. This impacts the cluster create experience for the customers using Azure Stack HCI 22H2. You may continue to use Azure CLI to manage your existing cluters.The AKS hybrid cluster provisioning from Azure preview and API model, available on Azure Stack HCI 22H2 and Windows Server, will be retired in March 2024. Customers using the original preview will need to redeploy their workloads on the new preview using the new API.  

### For each node pool
az hybridaks nodepool delete --name $aksNodepoolName --resource-group $resource_group --cluster-name $aksClusterName

### For each AKS cluster
az hybridaks delete --resource-group $resource_group --name $aksClusterName


