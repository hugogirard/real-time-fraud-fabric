extension microsoftGraphV1

param appDisplayName string
param appUniqueName string
param requiredResourcceAccess array
param redirectUris array = []

resource application 'Microsoft.Graph/applications@v1.0' = {
  displayName: appDisplayName
  uniqueName: appUniqueName
  signInAudience: 'AzureADMyOrg'
  identifierUris: [
    'api://${appUniqueName}'
  ]
  api: {
    requestedAccessTokenVersion: 2
  }
  requiredResourceAccess: requiredResourcceAccess
  web: {
    implicitGrantSettings: {
      enableAccessTokenIssuance: false
      enableIdTokenIssuance: true
    }
    redirectUris: redirectUris
  }
}

output applicationId string = application.appId
output applicationObjectId string = application.id
