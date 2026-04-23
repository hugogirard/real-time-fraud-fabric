extension microsoftGraphV1

param appDisplayName string
param appUniqueName string
param requiredResourcceAccess array
param webRedirectUris array = []
param spaRedirectUris array = []
param oauth2PermissionScopes array = []

resource application 'Microsoft.Graph/applications@v1.0' = {
  displayName: appDisplayName
  uniqueName: appUniqueName
  signInAudience: 'AzureADMyOrg'
  identifierUris: [
    'api://${appUniqueName}'
  ]
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: oauth2PermissionScopes
  }
  requiredResourceAccess: requiredResourcceAccess
  spa: {
    redirectUris: spaRedirectUris
  }
  web: {
    implicitGrantSettings: {
      enableAccessTokenIssuance: false
      enableIdTokenIssuance: true
    }
    redirectUris: webRedirectUris
  }
}

output applicationId string = application.appId
output applicationObjectId string = application.id
output identifierUris array = application.identifierUris
