## Prerequisites

1. Register `KubernetesRuntime` ARM resource provider:

```bash
az provider register -n Microsoft.KubernetesRuntime --wait
```

2. Install MetalLB Arc Extension following one of the options in documentation https://learn.microsoft.com/en-us/azure/aks/aksarc/deploy-load-balancer-cli#enable-arc-extension-for-metallb

## ARM Template

You can deploy a load balancer using the following command:

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file arm.loadbalancer.json \
  --parameters @loadbalancer.parameters.json
```

Please note that you need to use your own parameters in file `loadbalancer.parameters.json`.


## Bicep template

You can deploy a load balancer using the following command:

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file loadbalancer.bicep \
  --parameters @loadbalancer.parameters.json
```

Please note that you need to use your own parameters in file `loadbalancer.parameters.json`.
