# Provisioned cluster ARM template

Deploys a provisioned cluster with workload identity federation enabled and OIDC issuer URL enabled on ASZ environment.

```CLI
az deployment group create -g $resourceGroup -n sstest02 --template-file template.json --parameters `@parameters.json
```
