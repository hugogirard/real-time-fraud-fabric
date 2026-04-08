param resourceName string
param location string
param publisherEmail string

resource apim 'Microsoft.ApiManagement/service@2025-03-01-preview' = {
  name: resourceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: 'Contoso'
  }
}

output resourceName string = apim.name
