# ARM template to deploy an AKS Arc Kubernetes cluster

This template deploys an AKS Arc Kubernetes cluster with workload identity federation enabled.

## Folder Structure

- **Samples/Create1/**: Deploy a cluster using an existing logical network
- **Samples/Create2/**: Deploy a cluster and create a new logical network
- **Samples/Update/**: Update an existing provisioned cluster's configuration

## Instructions

Update azuredeploy.parameters.json with provisioned cluster name, ssh public key, and ARM IDs of vnet and custom location.

## Deploy

You can use the following command to deploy the template

```CLI
az deployment group create -g $resourceGroup --template-file azuredeploy.json -p azuredeploy.parameters.json
```

## Update Existing Cluster

The **Samples/Update/** folder contains a template to update an existing AKS Arc provisioned cluster. 

Examples of parameters to update your provisioned cluster:
- `controlPlaneNodeCount` - Scale the control plane nodes
- `enableAzureHybridBenefit` - Enable/disable Azure Hybrid User Benefits ("True" or "False")
- `enableNfsCsiDriver` - Enable/disable NFS CSI driver
- `enableSmbCsiDriver` - Enable/disable SMB CSI driver

### Important Notes

- **All other fields must remain unchanged** and match your existing cluster configuration
- ARM template updates use PUT operations, which require the complete resource specification
- Fill the parameters file with your current cluster's values, then modify only the fields you want to change
- To get your current cluster configuration: `az aksarc show --name <cluster-name> --resource-group <rg>`
- Nodepool-specific settings (autoscaling, node count etc) should be updated via the nodepool API

### Example Update Command

```bash
az deployment group create -g <resource-group> --template-file deploymentTemplates/aksarc-ARM/HCI/Samples/Update/azuredeploy.json -p deploymentTemplates/aksarc-ARM/HCI/Samples/Update/azuredeploy.parameters.json
```

## Additional Resources

For more details please look through:
- [ARM template deployment with Powershell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell)
- [ARM template documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/)
