# Provisioned cluster ARM template

This template is to deploy node pool on an existing kubernetes cluster. The template requires an existing AKS Arc cluster.

```CLI
az deployment group create -g $resourceGroup -n sstest02 --template-file template.json --parameters `@parameters.json
```
