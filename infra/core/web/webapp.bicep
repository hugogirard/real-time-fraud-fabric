param appServicePlanResourceName string
param location string
param agentWebAppName string

resource asp 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanResourceName
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    tier: 'PremiumV3'
    name: 'P1V3'
  }
}

resource fraudAgent 'Microsoft.Web/sites@2025-03-01' = {
  name: agentWebAppName
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://mcr.microsoft.com'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: ''
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: ''
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
      alwaysOn: true
    }
    serverFarmId: asp.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    clientAffinityEnabled: false
  }
}
