# Bicep template to deploy an AKS Arc Kubernetes cluster

This template deploys an AKS Arc Kubernetes cluster with workload identity federation enabled.

## Folder Structure

- **CreateWithExistingLnet/**: Deploy a cluster using an existing logical network
- **CreateWithoutExistingLnet/**: Deploy a cluster and create a new logical network
- **Update/**: Update an existing Aks Arc cluster's configuration

## Instructions

Update the `.bicepparam` file with your Aks Arc cluster name, ssh public key, and resource IDs of the logical network and custom location.

## Deploy

### CreateWithExistingLnet

Deploy a cluster using an existing logical network:

```bash
az deployment group create \
  -g <resource-group> \
  --template-file deploymentTemplates/aksarc-bicep/Cluster/CreateWithExistingLnet/main.bicep \
  --parameters deploymentTemplates/aksarc-bicep/Cluster/CreateWithExistingLnet/aksarc.bicepparam
```

### CreateWithoutExistingLnet

Deploy a cluster and create a new logical network:

```bash
az deployment group create \
  -g <resource-group> \
  --template-file deploymentTemplates/aksarc-bicep/Cluster/CreateWithoutExistingLnet/main.bicep \
  --parameters deploymentTemplates/aksarc-bicep/Cluster/CreateWithoutExistingLnet/aksarc.bicepparam
```

## Update Existing Cluster

The **Update/** folder contains a template to update an existing AKS Arc cluster. Bicep deployment updates use PUT operations which require the complete resource specification.

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
   az deployment group create \
     -g <resource-group> \
     --template-file deploymentTemplates/aksarc-bicep/Cluster/Update/main.bicep \
     --parameters deploymentTemplates/aksarc-bicep/Cluster/Update/aksarc.bicepparam
   ```

### Example: Scale Control Plane

To scale the control plane from 1 to 3 nodes:
```bicep
param controlPlaneNodeCount = 3
```

### Example: Enable NFS CSI Driver

```bicep
param enableNfsCsiDriver = true
```

### Important Notes

- **Nodepool-specific settings** (node count, autoscaling, labels, taints) should be updated using the [nodepool deployment template](../Nodepool/) instead of the cluster update template. Updating the nodepool spec through the cluster template will **not** work as intended and should **not** be used.

## Additional Resources

For more details please look through:
- [Bicep documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [AKS Arc documentation](https://learn.microsoft.com/en-us/azure/aks/hybrid/)
