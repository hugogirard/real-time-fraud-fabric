@description('The principal ID to assign the role')
param principalId string

@description('The role name (GUID)')
param roleName string

@description('The resource ID where to do the role assignement')
param resourceId string

resource role 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roleName
  scope: subscription()
}

module role_assignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  params: {
    principalId: principalId
    resourceId: resourceId
    roleDefinitionId: role.id
  }
}
// for id in webAppPrincipalIds: {
//   name: 'webArcPull-${id}'
//   params: {
//     principalId: id
//     resourceId: containerRegistryResourceId
//     roleDefinitionId: acr_pull.id
//   }
// }
