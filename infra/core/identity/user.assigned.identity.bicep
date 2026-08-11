param resourceName string
param location string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' = {
  name: resourceName
  location: location
}

output identityId string = identity.id
output identityPrincipalId string = identity.properties.principalId
output identityClientId string = identity.properties.clientId
