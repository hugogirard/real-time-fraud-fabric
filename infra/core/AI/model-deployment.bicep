param aiFoundryAccountName string
param deploymentName string
param deploymentSku string
param skuCapacity int
param modelProperties object

@allowed(['OnceNewDefaultVersionAvailable', 'NoAutoUpgrade', 'OnceCurrentVersionExpired'])
param versionUpgradeOption string

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiFoundryAccountName
}

resource model 'Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview' = {
  parent: account
  name: deploymentName
  sku: {
    name: deploymentSku
    capacity: skuCapacity
  }
  properties: {
    model: modelProperties
    versionUpgradeOption: versionUpgradeOption
    currentCapacity: skuCapacity
  }
}

output deploymentModelName string = model.name
