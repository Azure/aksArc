// ============================================================================
// AKS Hybrid and Edge on Bare Metal Linux — Cluster Creation Bicep Template
//
// Creates an AKS Hybrid and Edge cluster on a bare metal Linux edge machine that is
// already in the "Provisioned" state. Achieves parity with the portal UX
// creation flow.
//
// Prerequisites:
//   - Edge machine provisioned and Arc-connected (provisioningState = Succeeded)
//   - Resource providers registered: Microsoft.HybridContainerService,
//     Microsoft.Kubernetes, Microsoft.KubernetesConfiguration
//   - Entra ID security group for cluster admin access
//
// Resource creation order:
//   1. DevicePool (binds EdgeMachine to CMP, auto-creates CustomLocation)
//   2. RBAC: DevicePool MSI → Device Pool Manager (on DP)
//   3. RBAC: DevicePool MSI → Edge Machine Contributor (on EM)
//   4. LogicalNetwork (placeholder — required by API, not used for networking)
//   5. Connected Cluster (Arc identity for the cluster)
//   6. Provisioned Cluster Instance (the actual K8s cluster)
//   7. Optional extensions (Azure Policy, Container Monitoring)
//
// Fixed values (Public Preview):
//   - Node count: 1 (single-node only)
//   - CNI: Cilium
//   - Network Policy: Cilium
// ============================================================================

// === Parameters matching Portal UX ===

@allowed([
  'eastus'
])
@description('Azure region. Must match the edge machine region.')
param location string

@description('Name for the AKS Hybrid and Edge cluster.')
param clusterName string

@description('Kubernetes version (e.g., "1.33.3")')
param kubernetesVersion string

@description('Static IP for the Kubernetes API server.')
param controlPlaneIp string

@description('Enable Azure RBAC for Kubernetes authorization.')
param enableAzureRbac bool = true

@description('Entra ID group Object IDs for cluster admin access.')
param adminGroupObjectIds array

@description('SSH public key for node access (e.g., contents of ~/.ssh/id_rsa.pub). Required by the AksArc-Operator webhook.')
param sshPublicKey string

@description('Auto-enable Azure Policy extension.')
param enableAzurePolicy bool = true

@description('Auto-enable Container Monitoring extension.')
param enableContainerMonitoring bool = true

@description('Log Analytics workspace resource ID. Required if enableContainerMonitoring is true.')
param logAnalyticsWorkspaceId string = ''

@description('Azure resource tags applied to all created resources.')
param tags object = {}

// === Infrastructure Parameters ===

@description('Name of the existing EdgeMachine resource (must be in Provisioned state).')
param edgeMachineName string

@description('Name for the DevicePool resource. Defaults to the edge machine name.')
param devicePoolName string = edgeMachineName

@description('Name for the CustomLocation created by HCI RP during DevicePool provisioning.')
param customLocationName string = edgeMachineName

// === Constants (Public Preview) ===

var controlPlaneCount = 1
var podCidr = '10.244.0.0/16'
// Logical Network is required by the PCI webhook but never actually used for networking.
// These are valid placeholder values that pass go's net.ParseIP() validation.
var lnetName = '${clusterName}-lnet'
var lnetAddressPrefix = '10.0.0.0/24'
var lnetGateway = '10.0.0.1'
var lnetIpPoolStart = '10.0.0.2'
var lnetIpPoolEnd = '10.0.0.10'
var lnetVmSwitchName = 'PlaceholderSwitch'

// === API Versions ===

// === Derived values ===

var edgeMachineResourceId = resourceId(
  'Microsoft.AzureStackHCI/EdgeMachines',
  edgeMachineName
)

var mergedTags = union(tags, {
  'aks-arc-cluster': clusterName
  purpose: 'aks-arc-bmlinux'
})

// Well-known RBAC role definition IDs
// "Microsoft.AzureStackHCI Device Pool Manager" role
var devicePoolManagerRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'adc3c795-c41e-4a89-a478-0b321783324c'
)
// "Azure Stack HCI Edge Machine Contributor Role"
var edgeMachineContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '1a6f9009-515c-4455-b170-143e4c9ce229'
)

// ============================================================================
// Resource 1: DevicePool
//
// Binds the EdgeMachine to a CMP instance. HCI RP auto-creates a
// CustomLocation during DevicePool provisioning — we do NOT create the CL.
// ============================================================================

resource devicePool 'Microsoft.AzureStackHCI/devicePools@2024-11-01-preview' = {
  name: devicePoolName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    devices: [
      {
        deviceResourceId: edgeMachineResourceId
      }
    ]
    customLocationName: customLocationName
  }
  tags: mergedTags
}

// ============================================================================
// Resource 2: RBAC — DevicePool MSI → "Device Pool Manager" on DP scope
//
// Required for CAPE to read DevicePool properties during cluster provisioning.
// ============================================================================

// The role assignment name must be deterministic at deploy-start, so we use
// the DevicePool resource name (not the runtime principalId) in the guid seed.
resource dpManagerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(devicePool.id, 'dpManager', devicePoolManagerRoleId)
  scope: devicePool
  properties: {
    roleDefinitionId: devicePoolManagerRoleId
    principalId: devicePool.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'DevicePool MSI needs Device Pool Manager role for CAPE operations'
  }
}

// ============================================================================
// Resource 3: RBAC — DevicePool MSI → "Edge Machine Contributor" on EM scope
//
// Required for CAPE to manage EdgeMachine lifecycle during cluster provisioning.
// EdgeMachine is in the same RG as the cluster, so we scope directly.
// ============================================================================

resource edgeMachine 'Microsoft.AzureStackHCI/EdgeMachines@2024-11-01-preview' existing = {
  name: edgeMachineName
}

resource emContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(edgeMachineResourceId, 'emContributor', edgeMachineContributorRoleId)
  scope: edgeMachine
  properties: {
    roleDefinitionId: edgeMachineContributorRoleId
    principalId: devicePool.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'DevicePool MSI needs Edge Machine Contributor role for CAPE lifecycle operations'
  }
}

// ============================================================================
// Resource 4: LogicalNetwork (placeholder)
//
// Required by the PCI webhook (infraNetworkProfile validation) but NOT used
// for actual networking. Created with valid dummy values to pass validation.
// ============================================================================

resource logicalNetwork 'Microsoft.AzureStackHCI/logicalNetworks@2024-09-01-preview' = {
  name: lnetName
  location: location
  extendedLocation: {
    type: 'CustomLocation'
    name: resourceId('Microsoft.ExtendedLocation/customLocations', customLocationName)
  }
  properties: {
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: lnetAddressPrefix
          ipAllocationMethod: 'Static'
          ipPools: [
            {
              start: lnetIpPoolStart
              end: lnetIpPoolEnd
            }
          ]
          routeTable: {
            properties: {
              routes: [
                {
                  name: 'default'
                  properties: {
                    addressPrefix: '0.0.0.0/0'
                    nextHopIpAddress: lnetGateway
                  }
                }
              ]
            }
          }
        }
      }
    ]
    vmSwitchName: lnetVmSwitchName
  }
  tags: mergedTags
  dependsOn: [
    devicePool // CustomLocation must exist (created by HCI RP during DP provisioning)
  ]
}

// ============================================================================
// Resource 5: Connected Cluster (Arc identity)
//
// The Connected Cluster is the Arc identity for the AKS cluster. It is
// created with kind=ProvisionedCluster so AKS Hybrid and Edge recognizes it.
// ============================================================================

resource connectedCluster 'Microsoft.Kubernetes/connectedClusters@2024-01-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'ProvisionedCluster'
  properties: {
    agentPublicKeyCertificate: ''
    aadProfile: {
      enableAzureRBAC: enableAzureRbac
      adminGroupObjectIDs: adminGroupObjectIds
    }
  }
  tags: mergedTags
  dependsOn: [
    logicalNetwork
  ]
}

// ============================================================================
// Resource 6: Provisioned Cluster Instance
//
// The actual Kubernetes cluster. Created as a child resource of the
// Connected Cluster. Uses Cilium CNI (only supported CNI for BM Linux SFF).
// Single control plane node for Public Preview.
// ============================================================================

resource provisionedCluster 'Microsoft.HybridContainerService/provisionedClusterInstances@2024-09-01-preview' = {
  name: 'default'
  scope: connectedCluster
  extendedLocation: {
    type: 'CustomLocation'
    name: resourceId('Microsoft.ExtendedLocation/customLocations', customLocationName)
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    controlPlane: {
      count: controlPlaneCount
      controlPlaneEndpoint: {
        hostIP: controlPlaneIp
      }
    }
    networkProfile: {
      podCidr: podCidr
      loadBalancerProfile: {
        count: 0
      }
    }
    cloudProviderProfile: {
      infraNetworkProfile: {
        vnetSubnetIds: [
          logicalNetwork.id
        ]
      }
    }

    agentPoolProfiles: []
    linuxProfile: {
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
  }
}

// ============================================================================
// Resource 7 (Optional): Azure Policy Extension
// ============================================================================

resource azurePolicyExtension 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = if (enableAzurePolicy) {
  name: 'azure-policy'
  scope: connectedCluster
  properties: {
    extensionType: 'microsoft.policyinsights'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    provisionedCluster
  ]
}

// ============================================================================
// Resource 8 (Optional): Container Monitoring Extension
// ============================================================================

resource containerMonitoringExtension 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = if (enableContainerMonitoring && !empty(logAnalyticsWorkspaceId)) {
  name: 'azuremonitor-containers'
  scope: connectedCluster
  properties: {
    extensionType: 'microsoft.azuremonitor.containers'
    autoUpgradeMinorVersion: true
    configurationSettings: {
      logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
    }
  }
  dependsOn: [
    provisionedCluster
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the Connected Cluster.')
output connectedClusterId string = connectedCluster.id

@description('Resource ID of the Provisioned Cluster Instance.')
output provisionedClusterId string = provisionedCluster.id

@description('Resource ID of the DevicePool.')
output devicePoolId string = devicePool.id

@description('Resource ID of the CustomLocation (created by HCI RP).')
output customLocationId string = resourceId('Microsoft.ExtendedLocation/customLocations', customLocationName)

@description('DevicePool Managed Identity principal ID.')
output devicePoolPrincipalId string = devicePool.identity.principalId
