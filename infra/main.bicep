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

// End AI Resources

// Workload hosting (backend and frontend)
module serverFarm 'core/web/webapp.bicep' = {
  scope: rg
  params: {
    location: location
    appServicePlanResourceName: '${abbrs.webServerFarms}${resourceToken}'
    agentWebAppName: '${abbrs.webServerFarms}${resourceToken}'
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

output foundryResourceName string = foundry.outputs.resourceName
output projectEndpoint string = foundry.outputs.projectEndpoint
output projectResourceName string = foundry.outputs.projectResourceName
output chatCompletionDeploymentModel string = chatCompletionModelDeployment.outputs.deploymentModelName
