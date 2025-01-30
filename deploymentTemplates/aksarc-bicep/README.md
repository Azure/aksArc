
# AKS Arc Bicep

## Deploy

1. Open a terminal like PowerShell.
1. Change into this directory
1. Log into Azure CLI.
1. Deploy using Azure CLI:

    ```powershell
    az deployment sub create --name "<deployment name>" --location "<location>" --template-file "main.bicep" --parameters "aksarc.bicepparam"
    ```

## Information

For more information about deploying Bicep templates, see the this [link](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli).
