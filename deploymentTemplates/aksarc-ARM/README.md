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

The **Samples/Update/** folder contains a template to update an existing AKS Arc provisioned cluster. ARM template updates use PUT operations which require the complete resource specification.

### Updatable Fields

Some parameters you can modify to update your cluster:
- `controlPlaneNodeCount` - Scale the control plane nodes
- `enableAzureHybridBenefit` - Enable/disable Azure Hybrid User Benefits ("True" or "False")
- `enableNfsCsiDriver` - Enable/disable NFS CSI driver
- `enableSmbCsiDriver` - Enable/disable SMB CSI driver
- `kubernetesVersion` - Upgrade Kubernetes version

### Update Process

1. **Get current cluster configuration:**
   ```bash
   az aksarc show --name <cluster-name> --resource-group <resource-group>
   ```

2. **Fill parameters file with current values** from the show command output

3. **Modify only the fields you want to update**

4. **Deploy the update:**
   ```bash
   az deployment group create -g <resource-group> --template-file deploymentTemplates/aksarc-ARM/HCI/Samples/Update/azuredeploy.json -p deploymentTemplates/aksarc-ARM/HCI/Samples/Update/azuredeploy.parameters.json
   ```

### Example: Scale Control Plane

To scale the control plane from 1 to 3 nodes:
```json
"controlPlaneNodeCount": { "value": 3 }
```

### Example: Enable NFS CSI Driver

```json
"enableNfsCsiDriver": { "value": true }
```

### Important Note

**Nodepool-specific settings** (node count, autoscaling, labels, taints) should be updated using the [nodepool deployment template](../aks-nodepool/) instead of the cluster update template.

## Additional Resources

For more details please look through:
- [ARM template deployment with Powershell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell)
- [ARM template documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/)
