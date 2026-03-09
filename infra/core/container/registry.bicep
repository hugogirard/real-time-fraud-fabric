param acrName string
param location string
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

output resourceName string = acr.name
