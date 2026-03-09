param fabricResourceName string
param location string
param administrationMember string

resource fabric 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: fabricResourceName
  location: location
  sku: {
    name: 'F2'
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: [
        administrationMember
      ]
    }
  }
}
