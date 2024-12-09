# ARM template to deploy/update an AKS Arc node pool

This template is to deploy a new node pool on an existing AKS Arc cluster or can be used to update an existing nodepool. 

## Prerequisites

In order to deploy this template, there must be an operational AKS Arc cluster.

## Deploy

You can use the following command to deploy the template

```CLI
az deployment group create -g $resourceGroup -n cluster01 --template-file azuredeploy.json --parameters azuredeploy.parameters.json
```
> [NOTE]
> _cluster01_ is an existing ASK Arc cluster in the resource group.
