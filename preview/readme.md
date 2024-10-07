# Preview Announcement

Microsoft has deprecated  **AKS hybrid cluster provisioning from Azure (preview)** features and replaced them with the release version of the feature set since March 2024. This decision was made after careful consideration of our product roadmap and the needs of our customers.

Customers using the **AKS hybrid cluster provisioning from Azure (preview)** will need to redeploy their workloads using the [AKS enabled by Azure Arc, on Azure Stack HCI 23H2](https://learn.microsoft.com/azure/aks/hybrid/aks-whats-new-23h2).

For more details, see the following announcements.

* [AKS enabled by Azure Arc is now available on Azure Stack HCI 23H2](https://techcommunity.microsoft.com/t5/azure-stack-blog/aks-enabled-by-azure-arc-is-now-available-on-azure-stack-hci/ba-p/4045648)
* [Azure Stack HCI version 23H2 is generally available](https://techcommunity.microsoft.com/t5/azure-stack-blog/azure-stack-hci-version-23h2-is-generally-available/ba-p/4046110)

If you have any questions or concerns, please reach out to us by [opening a GitHub issue](https://github.com/Azure/aks-hybrid/issues). We appreciate your understanding and continued support.

## IMPORTANT!

With [AKS enabled by Azure Arc, on Azure Stack HCI 23H2](https://learn.microsoft.com/azure/aks/hybrid/aks-whats-new-23h2), We have reintroduced the portal experience with resource model changes. This impacts the cluster create experience for the customers using **Azure Stack HCI 22H2 and Windows Server**. You may continue to use Azure CLI to manage your existing clusters. The AKS hybrid cluster provisioning from Azure preview and API model, available on Azure Stack HCI 22H2 and Windows Server, is retired since March 2024.   

### Steps to delete existing clusters and recreate

1. Follow the instructions to delete existing preview cluster
    * [Uninstall the AKS cluster provisioning preview](https://learn.microsoft.com/azure/aks/hybrid/aks-hybrid-preview-uninstall)
2. Follow the instructions to create new cluster
    * [Using CLI](https://learn.microsoft.com/azure/aks/hybrid/aks-create-clusters-cli)
    * [Using Azure Portal](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-create-clusters-portal)
