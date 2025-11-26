param customLocationResourceID string
param connectedClusterName string

// Logical network
param logicalNetworkName string

// Aks Arc cluster
param sshPublicKey string
param controlPlaneHostIP string
param kubernetesVersion string
param controlPlaneVMSize string
param controlPlaneNodeCount int
param nodePoolName string
param nodePoolVMSize string
@allowed(['Linux', 'Windows'])
param nodePoolOSType string
param nodePoolCount int
param nodePoolLabel string
param nodePoolLabelValue string
param nodePoolTaints array
param netWorkProfilNetworkPolicy string
param networkProfileLoadBalancerCount int
param enableAzureHybridBenefit string
param enableNfsCsiDriver bool
param enableSmbCsiDriver bool

// Reference an existing logical network.
resource logicalNetwork 'Microsoft.AzureStackHCI/logicalNetworks@2024-01-01' existing = {
  name: logicalNetworkName
}

// Reference the existing connected cluster.
resource connectedCluster 'Microsoft.Kubernetes/ConnectedClusters@2024-01-01' existing = {
  name: connectedClusterName
}

// Update the Aks Arc cluster instance.
resource provisionedClusterInstance 'Microsoft.HybridContainerService/provisionedClusterInstances@2024-01-01' = {
  name: 'default'
  scope: connectedCluster
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationResourceID
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    linuxProfile: {
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
    controlPlane: {
      count: controlPlaneNodeCount
      controlPlaneEndpoint: {
        hostIP: controlPlaneHostIP
      }
      vmSize: controlPlaneVMSize
    }
    networkProfile: {
      networkPolicy: netWorkProfilNetworkPolicy
      loadBalancerProfile: {
        count: networkProfileLoadBalancerCount
      }
    }
    agentPoolProfiles: [
      {
        name: nodePoolName
        count: nodePoolCount
        vmSize: nodePoolVMSize
        osType: nodePoolOSType
        nodeLabels: {
          '${nodePoolLabel}': nodePoolLabelValue
        }
        nodeTaints: empty(nodePoolTaints) ? null : nodePoolTaints
      }
    ]
    cloudProviderProfile: {
      infraNetworkProfile: {
        vnetSubnetIds: [
          logicalNetwork.id
        ]
      }
    }
    licenseProfile: {
      azureHybridBenefit: enableAzureHybridBenefit
    }
    storageProfile: {
      nfsCsiDriver: {
        enabled: enableNfsCsiDriver
      }
      smbCsiDriver: {
        enabled: enableSmbCsiDriver
      }
    }
  }
}
