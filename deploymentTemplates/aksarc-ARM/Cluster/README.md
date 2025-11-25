# ARM template to deploy an AKS Arc Kubernetes cluster

This template deploys an AKS Arc Kubernetes cluster with workload identity federation enabled.

## Folder Structure

- **CreateWithExistingLnet/**: Deploy a cluster using an existing logical network
- **CreateWithoutExistingLnet/**: Deploy a cluster and create a new logical network
- **Update/**: Update an existing Aks Arc cluster's configuration

## Instructions

Update azuredeploy.parameters.json with Aks Arc cluster name, ssh public key, and ARM IDs of vnet and custom location.

## Deploy

You can use the following command to deploy the template

```CLI
az deployment group create -g $resourceGroup --template-file azuredeploy.json -p azuredeploy.parameters.json
```

## Update Existing Cluster

The **Update/** folder contains a template to update an existing AKS Arc cluster. ARM template updates use PUT operations which require the complete resource specification.

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
   az deployment group create -g <resource-group> --template-file deploymentTemplates/aksarc-ARM/Cluster/Update/azuredeploy.json -p deploymentTemplates/aksarc-ARM/Cluster/Update/azuredeploy.parameters.json
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

**Nodepool-specific settings** (node count, autoscaling, labels, taints) should be updated using the [nodepool deployment template](../Nodepool/) instead of the cluster update template. Updating the nodepool spec through the cluster template will **not** work as intended and should **not** be used.

## Additional Resources

For more details please look through:
- [ARM template deployment with Powershell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell)
- [ARM template documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/)
