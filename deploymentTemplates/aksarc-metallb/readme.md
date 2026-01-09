## Prerequisites

1. Register `KubernetesRuntime` ARM resource provider:

```bash
az provider register -n Microsoft.KubernetesRuntime --wait
```

2. The templates will automatically install the MetalLB Arc Extension. You need to provide the `k8sRuntimeFpaObjectId` parameter in your parameters file. You can find this value by running:

```bash
az ad sp list --filter "appId eq '087fca6e-4606-4d41-b3f6-5ebdf75b8b4c'" --output json
```

Look for the `id` field in the output to get the required object ID.

## ARM Template

You can deploy a load balancer using the following command:

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file arm.loadbalancer.json \
  --parameters @loadbalancer.parameters.json
```

Please note that you need to use your own parameters in file `loadbalancer.parameters.json`, including the required `k8sRuntimeFpaObjectId` parameter.

## Bicep template

You can deploy a load balancer using the following command:

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file loadbalancer.bicep \
  --parameters @loadbalancer.parameters.json
```

Please note that you need to use your own parameters in file `loadbalancer.parameters.json`, including the required `k8sRuntimeFpaObjectId` parameter.
