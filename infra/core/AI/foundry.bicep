param accountName string
param location string

#disable-next-line BCP036
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  tags: {
    SecurityControl: 'Ignore'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
      bypass: 'AzureServices'
    }
    publicNetworkAccess: 'Enabled'
    networkInjections: null
    disableLocalAuth: false
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: 'fraud-detection'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Real Time Fraud Detection'
    displayName: 'Fraud'
  }
}

output resourceName string = account.name
output projectResourceName string = project.name
output projectEndpoint string = 'https://${account.name}.services.ai.azure.com/api/projects/${project.name}'
