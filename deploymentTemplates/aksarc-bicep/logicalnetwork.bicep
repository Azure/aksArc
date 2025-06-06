param azureLocation string
param customLocationResourceID string

// Logical network
param logicalNetworkName string
param dnsServers array
param addressPrefix string
param vmSwitchName string
param ipAllocationMethod string
param vlan int
param vipPoolStart string
param vipPoolEnd string
param nextHopIpAddress string

resource logicalNetwork 'Microsoft.AzureStackHCI/logicalNetworks@2024-01-01' = {

  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationResourceID
  }
  location: azureLocation
  name: logicalNetworkName
  properties: {
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: [
      {
        name: 'bicepSubnet'
        properties: {
          addressPrefix: addressPrefix
          ipAllocationMethod: ipAllocationMethod
          vlan: vlan
          ipPools: [
            {
              name: 'bicepIPPool'
              start: vipPoolStart
              end: vipPoolEnd
              ipPoolType: 'vippool'
            }
          ]
          routeTable: {
            properties: {
              routes: [
                {
                  name: 'defaultRoute'
                  properties: {
                    addressPrefix: '0.0.0.0/0'
                    nextHopIpAddress: nextHopIpAddress
                  }
                }
              ]
            }
          }
        }
      }
    ]
    vmSwitchName: vmSwitchName
  }
}

