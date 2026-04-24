targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('The name of the resource group that will contains all the resources')
param resourceGroupName string

@description('The email of the administrator for Fabric')
param administrationMember string

@description('The user principal ID')
param userPrincipalId string = ''

@description('The publisher email for notification in APIM')
param publisherEmail string

@description('OAuth2 permission ID for the function')
param oauth2FuncId string = newGuid()

@description('Client ID of the angular app if already exist (only use multi deployment)')
param webAppClientId string = ''

@description('Client ID of the function app if already exist (only use multi deployment)')
param funcAppClientId string = ''

var abbrs = loadJsonContent('./abbreviations.json')

var tags = {
  SecurityControl: 'Ignore'
}

var functionName = 'func-${resourceToken}'

// Model deployments, change it depending on your region
// and the model you want to use
// https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure?tabs=global-standard-aoai%2Cglobal-standard&pivots=azure-openai#global-standard-model-availability
var chatCompletionModel = {
  format: 'OpenAI'
  name: 'gpt-5.1'
  version: '2025-11-13'
}

var chatCompletionModelSkuCapacity = 150

var chatCompletionModelDeploymentSKU = 'GlobalStandard'

var requiredResourceAccess = [
  {
    // MS Graph well-known application ID
    resourceAppId: '00000003-0000-0000-c000-000000000000'
    resourceAccess: [
      {
        // Well-known permission ID for User.Read delegated scope
        id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
        type: 'Scope' // Delegated permission
      }
    ]
  }
]

// End model properties deployment

#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// AI Resources
module foundry 'core/AI/foundry.bicep' = {
  scope: rg
  name: 'foundry'
  params: {
    location: location
    accountName: '${abbrs.foundryAccount}${resourceToken}'
    logAnalyticResourceId: monitoring.outputs.logAnalyticResourceId
  }
}

module chatCompletionModelDeployment 'core/AI/model-deployment.bicep' = {
  scope: rg
  name: chatCompletionModel.name
  params: {
    aiFoundryAccountName: foundry.outputs.resourceName
    deploymentName: chatCompletionModel.name
    deploymentSku: chatCompletionModelDeploymentSKU
    modelProperties: chatCompletionModel
    skuCapacity: chatCompletionModelSkuCapacity
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

module rbac_ai_owner 'core/rbac/rbac.bicep' = {
  scope: rg
  dependsOn: [
    chatCompletionModelDeployment
  ]
  params: {
    principalId: userPrincipalId
    resourceId: foundry.outputs.foundryResourceId
    roleName: 'c883944f-8b7b-4483-af10-35834be79c4a' // Azure AI Owner 
  }
}

// End AI Resources

// Data resources
module fabric 'core/data/fabric.bicep' = {
  scope: rg
  params: {
    location: location
    administrationMember: administrationMember
    fabricResourceName: 'fabric${resourceToken}'
  }
}
var frontEndResourceName = 'web-${resourceToken}'

// Workload hosting (backend and frontend)
module serverFarm 'core/web/webapp.bicep' = {
  scope: rg
  dependsOn: [acr]
  params: {
    location: location
    appServicePlanResourceName: '${abbrs.webServerFarms}${resourceToken}'
    frontEndWebAppName: frontEndResourceName
    acrName: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
}

module webAppRegistration 'core/entraID/app.registration.bicep' = if (empty(webAppClientId)) {
  scope: rg
  params: {
    appDisplayName: 'Fraud Detection Angular App'
    appUniqueName: frontEndResourceName
    requiredResourcceAccess: requiredResourceAccess
    spaRedirectUris: [
      'https://${serverFarm.outputs.frontEndWebAppName}.azurewebsites.net'
      'http://localhost:4200'
    ]
  }
}

// Container Registry
module acr 'core/container/registry.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    acrName: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
}

// Application Insights
module monitoring 'core/log/insight.bicep' = {
  scope: rg
  params: {
    location: location
    appInsightResourceName: '${abbrs.insightsComponents}${resourceToken}'
    workspaceResourceName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
  }
}

// Storage Account
module storage 'core/storage/storage.bicep' = {
  scope: rg
  params: {
    location: location
    containerName: 'app-package-${functionName}'
    resourceName: 'str${resourceToken}'
  }
}

// Function and dependencies
module functionIdentity 'core/identity/user.assigned.identity.bicep' = {
  scope: rg
  params: {
    location: location
    resourceName: '${abbrs.managedIdentityUserAssignedIdentities}${functionName}'
  }
}

module rbac_blob_data_owner 'core/rbac/rbac.bicep' = {
  scope: rg
  dependsOn: [
    chatCompletionModelDeployment
  ]
  params: {
    principalId: functionIdentity.outputs.identityPrincipalId
    resourceId: storage.outputs.resourceId
    roleName: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner 
  }
}

module ai_user_foundry 'core/rbac/rbac.bicep' = {
  scope: rg
  params: {
    principalId: functionIdentity.outputs.identityPrincipalId
    resourceId: foundry.outputs.foundryResourceId
    roleName: '53ca6127-db72-4b80-b1b0-d745d6d5456d' // Azure AI User
  }
}

// Create app registration for the function
var functionResourceName = '${abbrs.webSitesFunctions}${resourceToken}'

module appRegistrationFunction 'core/entraID/app.registration.bicep' = if (empty(funcAppClientId)) {
  scope: rg
  params: {
    appDisplayName: 'Fraud-Agent-Function'
    appUniqueName: functionResourceName
    requiredResourcceAccess: requiredResourceAccess
    oauth2PermissionScopes: [
      {
        id: oauth2FuncId
        adminConsentDescription: 'Allow the application to access chatbot on behalf of the signed-in user.'
        adminConsentDisplayName: 'Access chatbot'
        isEnabled: true
        type: 'User'
        userConsentDescription: 'Allow the application to access chatbot on your behalf.'
        userConsentDisplayName: 'Access chatbot'
        value: 'user_impersonation'
      }
    ]
  }
}

module function 'core/function/function.bicep' = {
  scope: rg
  params: {
    location: location
    serverFarmResourceName: '${abbrs.webServerFarms}${functionName}'
    containerName: storage.outputs.containerName
    functionResourceName: '${abbrs.webSitesFunctions}${resourceToken}'
    identityClientId: functionIdentity.outputs.identityClientId
    identityId: functionIdentity.outputs.identityId
    storageAccountName: storage.outputs.resourceName
    appInsightResourceName: monitoring.outputs.insightResourceName
    foundryResourceName: foundry.outputs.resourceName
    appRegistrationClientId: appRegistrationFunction.outputs.applicationId
    allowedAudiences: union(
      appRegistrationFunction.outputs.identifierUris,
      [appRegistrationFunction.outputs.applicationId]
    )
  }
}

// APIM
module apim 'core/apim/apim.bicep' = {
  scope: rg
  params: {
    location: location
    publisherEmail: publisherEmail
    resourceName: '${abbrs.apiManagementService}${resourceToken}'
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = '${acr.outputs.resourceName}.azurecr.io'
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.resourceName
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_FRONTEND_WEBAPP_NAME string = serverFarm.outputs.frontEndWebAppName
output FOUNDRY_RESOURCE_NAME string = foundry.outputs.resourceName
output PROJECT_ENDPOINT string = foundry.outputs.projectEndpoint
output PROJECT_RESOURCE_NAME string = foundry.outputs.projectResourceName
output CHAT_COMPLETION_DEPLOYMENT_MODEL string = chatCompletionModelDeployment.outputs.deploymentModelName
output FRONTEND_CLIENTID string = empty(webAppClientId) ? webAppRegistration.outputs.applicationId : webAppClientId
output AUTHORITY string = 'https://login.microsoftonline.com/${tenant().tenantId}'
output FUNCTION_SCOPE string = 'api://${functionResourceName}/user_impersonation'
output FUNCTION_BASE_URL string = 'https://${functionResourceName}.azurewebsites.net'
output FRONTEND_REDIRECT_URL string = 'https://${frontEndResourceName}.azurewebsites.net'
output APPLICATION_INSIGHTS_KEY string = monitoring.outputs.key
