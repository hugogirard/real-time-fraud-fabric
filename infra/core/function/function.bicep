param location string
param serverFarmResourceName string
param functionResourceName string
param identityId string
param identityClientId string
param storageAccountName string
param containerName string
param appInsightResourceName string
param foundryResourceName string
param appRegistrationClientId string
param allowedAudiences array

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
      PYTHON_ENABLE_INIT_INDEXING: '1'
      PYTHON_ISOLATE_WORKER_DEPENDENCIES: '1'
      FOUNDRY_PROJECT_ENDPOINT: 'https://${foundryResourceName}.services.ai.azure.com/api/projects/fraud-detection'
      FOUNDRY_AGENT_NAME: 'FraudAgent'
      FOUNDRY_AGENT_VERSION: '1'
    }
  }
}

var openIdIssuer = 'https://login.microsoftonline.com/${tenant().tenantId}/v2.0'

resource configAuth 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: flexFunctionApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    httpSettings: {
      requireHttps: true
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: appRegistrationClientId
          openIdIssuer: openIdIssuer
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
        validation: {
          allowedAudiences: allowedAudiences
        }
      }
    }
  }
}
