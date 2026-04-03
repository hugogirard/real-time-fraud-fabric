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

var abbrs = loadJsonContent('./abbreviations.json')

var tags = {
  SecurityControl: 'Ignore'
}

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

module rbac_ai_owner 'rbac/rbac.bicep' = {
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

// Workload hosting (backend and frontend)
module serverFarm 'core/web/webapp.bicep' = {
  scope: rg
  params: {
    location: location
    appServicePlanResourceName: '${abbrs.webServerFarms}${resourceToken}'
    agentWebAppName: 'agent-${resourceToken}'
    frontEndWebAppName: 'web-${resourceToken}'
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

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = '${acr.outputs.resourceName}.azurecr.io'
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.resourceName
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_FRONTEND_WEBAPP_NAME string = serverFarm.outputs.frontEndWebAppName
output FOUNDRY_RESOURCE_NAME string = foundry.outputs.resourceName
output PROJECT_ENDPOINT string = foundry.outputs.projectEndpoint
output PROJECT_RESOURCE_NAME string = foundry.outputs.projectResourceName
output CHAT_COMPLETION_DEPLOYMENT_MODEL string = chatCompletionModelDeployment.outputs.deploymentModelName
