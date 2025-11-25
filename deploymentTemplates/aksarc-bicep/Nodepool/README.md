# Bicep template to deploy/update an AKS Arc node pool

This template is to deploy a new node pool on an existing AKS Arc cluster or can be used to update an existing nodepool.

## Prerequisites

In order to deploy this template, there must be an operational AKS Arc cluster.

## Deploy New Node Pool

You can use the following command to deploy a new node pool:

```bash
az deployment group create \
  -g <resource-group> \
  --template-file main.bicep \
  --parameters nodepool.bicepparam
```

## Update Existing Node Pool

This template can also be used to update an existing node pool. Bicep deployment updates use PUT operations which require the complete resource specification.

### Updatable Fields

Some parameters you can modify to update your node pool:
- `nodePoolCount` - Number of nodes in the pool
- `enableAutoScaling` - Enable/disable cluster autoscaler
- `minCount` - Minimum node count when autoscaling is enabled
- `maxCount` - Maximum node count when autoscaling is enabled
- `nodeLabels` - Key-value pairs for node labels
- `nodeTaints` - Array of taints to apply to nodes

### Update Process

1. **Get current node pool configuration:**
   ```bash
   az aksarc nodepool show --cluster-name <cluster-name> --name <nodepool-name> --resource-group <resource-group>
   ```

2. **Fill parameters file with current values** from the show command output

3. **Modify only the fields you want to update**

4. **Deploy the update:**
   ```bash
   az deployment group create \
     -g <resource-group> \
     --template-file main.bicep \
     --parameters nodepool.bicepparam
   ```

### Example: Enable Autoscaling

To enable autoscaling on an existing node pool, set:
```bicep
param enableAutoScaling = true
param minCount = 1
param maxCount = 5
```

### Example: Add Node Taints

```bicep
param nodeTaints = ['workload=special:PreferNoSchedule']
```

## Additional Resources

For more details please look through:
- [Bicep documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [AKS Arc documentation](https://learn.microsoft.com/en-us/azure/aks/hybrid/)
