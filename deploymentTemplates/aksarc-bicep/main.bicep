@description('The name of AKS Arc cluster resource')
param ClusterName string
param location string = 'eastus'

// Default to 1 node control plane, aksControlPlaneIP is optional
@description('The settings for cluster control plane, provide the parameters during deployment')
param aksControlPlaneNodeSize string = 'Standard_A4_v2'
param aksControlPlaneNodeCount int = 1
param aksControlPlaneIP string = ''

// Default to 1 node node pool
param aksNodePoolName string = 'nodepool1'
param aksNodePoolNodeSize string = 'Standard_A4_v2'
param aksNodePoolNodeCount int = 1
@allowed(['Linux', 'Windows'])
param aksNodePoolOSType string = 'Linux'

@description('SSH public key used for cluster creation, provide this parameter during deployment')
param SSHPublicKey string

// Build LNet ID from LNet name
@description('The name of LNet resource, provide this parameter during deployment')
param LogicalNetworkName string
resource logicalNetwork 'Microsoft.AzureStackHCI/logicalNetworks@2023-09-01-preview' existing = {
  name: LogicalNetworkName
}

// Build custom location ID from custom location name
@description('The name of custom location resource, provide this parameter during deployment')
param CustomLocationName string
var customLocationId = resourceId('Microsoft.ExtendedLocation/customLocations', CustomLocationName) 

// Create the connected cluster. This is the Arc representation of the AKS cluster, used to create a Managed Identity for the provisioned cluster.
resource connectedCluster 'Microsoft.Kubernetes/ConnectedClusters@2024-01-01' = {
  location: location
  name: ClusterName
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'ProvisionedCluster'
  properties: {
    agentPublicKeyCertificate: ''
    aadProfile: {
      enableAzureRBAC: false
    }
  }
}

// Create the provisioned cluster instance. This is the actual AKS cluster and provisioned on your Azure Local cluster via the Arc Resource Bridge.
resource provisionedClusterInstance 'Microsoft.HybridContainerService/provisionedClusterInstances@2024-01-01' = {
  name: 'default'
  scope: connectedCluster
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationId
  }
  properties: {
    linuxProfile: {
      ssh: {
        publicKeys: [
          {
            keyData: SSHPublicKey
          }
        ]
      }
    }
    controlPlane: {
      count: aksControlPlaneNodeCount
      controlPlaneEndpoint: {
        hostIP: aksControlPlaneIP
      }
      vmSize: aksControlPlaneNodeSize
    }
    networkProfile: {
      loadBalancerProfile: {
        count: 0
      }
      networkPolicy: 'calico'
    }
    agentPoolProfiles: [
      {
        name: aksNodePoolName
        count: aksNodePoolNodeCount
        vmSize: aksNodePoolNodeSize
        osType: aksNodePoolOSType
      }
    ]
    cloudProviderProfile: {
      infraNetworkProfile: {
        vnetSubnetIds: [
          logicalNetwork.id
        ]
      }
    }
    storageProfile: {
      nfsCsiDriver: {
        enabled: true
      }
      smbCsiDriver: {
        enabled: true
      }
    }
  }
}