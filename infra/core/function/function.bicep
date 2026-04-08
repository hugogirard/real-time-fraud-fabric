param location string
param serverFarmResourceName string
param functionResourceName string
param identityId string
param identityClientId string
param storageAccountName string
param containerName string
param appInsightResourceName string
param foundryResourceName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource insights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightResourceName
}

resource flexFunctionPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: serverFarmResourceName
  location: location
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}

resource flexFunctionApp 'Microsoft.Web/sites@2025-03-01' = {
  name: functionResourceName
  tags: {
    'azd-service-name': 'function'
  }
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: flexFunctionPlan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${containerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'python'
        version: '3.13'
      }
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: insights.properties.ConnectionString
      AzureWebJobsStorage__blobServiceUri: '$https://${storageAccountName}.blob.core.windows.net'
      AzureWebJobsStorage__queueServiceUri: '$https://${storageAccountName}.queue.core.windows.net'
      AzureWebJobsStorage__tableServiceUri: '$https://${storageAccountName}.table.core.windows.net'
      AzureWebJobsStorage__clientId: identityClientId
      AzureWebJobsStorage__credential: 'managedidentity'
      FOUNDRY_PROJECT_ENDPOINT: 'https://${foundryResourceName}.services.ai.azure.com/api/projects/fraud-detection'
      FOUNDRY_AGENT_NAME: 'FraudAgent'
      FOUNDRY_AGENT_VERSION: '1'
    }
  }
}
