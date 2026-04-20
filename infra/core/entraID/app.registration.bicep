extension microsoftGraphV1

param appDisplayName string
param appUniqueName string
param requiredResourcceAccess array

// requiredResourceAccess: [
//   {
//     resourceAppId: msGraphAppId
//     resourceAccess: [
//       {
//         id: userReadScopeId
//         type: 'Scope' // Delegated permission
//       }
//     ]
//   }
// ]

// MS Graph well-known application ID
var msGraphAppId = '00000003-0000-0000-c000-000000000000'

// Well-known permission ID for User.Read delegated scope
var userReadScopeId = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'

resource application 'Microsoft.Graph/applications@v1.0' = {
  displayName: appDisplayName
  uniqueName: appUniqueName
  signInAudience: 'AzureADMyOrg'
  api: {
    requestedAccessTokenVersion: 2
  }
  requiredResourceAccess: requiredResourcceAccess
  web: {
    implicitGrantSettings: {
      enableAccessTokenIssuance: false
      enableIdTokenIssuance: true
    }
  }
}

output applicationId string = application.appId
output applicationObjectId string = application.id
