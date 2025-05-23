@allowed(['prod', 'dev'])
param env string
param vmSize string
param location string
param vnetName string
param documentIntelligenceName string
param customDocumentIntelligenceName string
param storageAccountName string
param bastionName string
param vmName string
param adminUsername string
@secure()
param adminPassword string

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'privateendpointsubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: genericNsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: bastionSubnetNsg.id
          }
        }
      }
      {
        name: 'jumpsubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: genericNsg.id
          }
        }
      }
      {
        name: 'mockappsubnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
          networkSecurityGroup: {
            id: genericNsg.id
          }
        }
      }
    ]
  }
}

resource docIntel 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: documentIntelligenceName
  location: location
  kind: 'FormRecognizer'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: env == 'prod' ? 'Disabled' : 'Enabled'
    customSubDomainName: customDocumentIntelligenceName
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: env == 'dev' ? [
        {
          value: '20.3.165.95'
        }
      ] : []
    }
  }
}

resource docIntelPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: '${documentIntelligenceName}-pe'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'privateendpointsubnet')
    }
    privateLinkServiceConnections: [
      {
        name: '${documentIntelligenceName}-connection'
        properties: {
          privateLinkServiceId: docIntel.id
          groupIds: ['account']
        }
      }
    ]
  }
}

resource docIntelDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = {
  name: 'default'
  parent: docIntelPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'docIntelDnsZoneConfig'
        properties: {
          privateDnsZoneId: dnsCognitive.id
        }
      }
    ]
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: env == 'prod' ? 'Disabled' : 'Enabled'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: env == 'dev' ? [
        {
          value: '20.3.165.95'
        }
      ] : []
      resourceAccessRules: [
        {
          resourceId: docIntel.id
          tenantId: subscription().tenantId
        }
      ]
    }
  }
}


resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  name: 'default'
  parent: storage
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: 'dropzone'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: '${storage.name}-pe'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'privateendpointsubnet')
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-blob'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource storageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = {
  name: 'default'
  parent: storagePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storageDnsZoneConfig'
        properties: {
          privateDnsZoneId: dnsBlob.id
        }
      }
    ]
  }
}

resource containerRole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(docIntel.name, container.id, 'storage-blob-reader')
  scope: container
  properties: {
    principalId: docIntel.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  }
}

resource bastionIp 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: '${bastionName}-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-09-01' = {
  name: bastionName
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConf'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionIp.id
          }
        }
      }
    ]
  }
}

resource vmNic 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: '${vmName}-nic'
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'jumpsubnet')
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
  }
}

resource dnsCognitive 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'
}

resource dnsCognitiveLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${dnsCognitive.name}-link'
  parent: dnsCognitive
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource dnsBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource dnsBlobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${dnsBlob.name}-link'
  parent: dnsBlob
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource mockAppNic 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: 'mockApp-nic'
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'mockappsubnet')
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource mockAppVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: 'mockApp'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'mockApp'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: mockAppNic.id
        }
      ]
    }
  }
}

resource mockAppDocIntelRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('mockApp-docIntel-role')
  scope: docIntel
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
    principalId: mockAppVm.identity.principalId
  }
}

resource genericNsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: '${env}-generic-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowInternalVnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource bastionSubnetNsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: '${env}-bastion-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowInboundHttps'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationPortRanges: ['443']
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowOutboundTcp'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowOutboundUdp'
        properties: {
          priority: 130
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Udp'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

