// ============================================================================
// AKS Hybrid and Edge on Bare Metal Linux — Example Parameters
//
// Copy this file, fill in your values, and deploy:
//   az deployment group create -g <RG> --parameters cluster-create.bicepparam
// ============================================================================

using './cluster-create.bicep'

// === Basics (Portal: Basics tab) ===

param location = '<CLUSTER_LOCATION>'
param clusterName = '<CLUSTER_NAME>'
param kubernetesVersion = '<KUBERNETES_VERSION>'
param controlPlaneIp = '<CONTROL_PLANE_VIP>'

// === Access (Portal: Access tab) ===

param enableAzureRbac = true
param adminGroupObjectIds = [
  '<ENTRA_ID_GROUP_OBJECT_ID>'
]

param sshPublicKey = '<SSH_PUBLIC_KEY>'

// === Integrations (Portal: Integrations tab) ===

param enableAzurePolicy = true
param enableContainerMonitoring = true
param logAnalyticsWorkspaceId = '/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.OperationalInsights/workspaces/<WORKSPACE_NAME>'

// === Infrastructure ===

param edgeMachineName = '<EDGE_MACHINE_NAME>'

// === Tags ===

param tags = {
  <TAGS>
}
