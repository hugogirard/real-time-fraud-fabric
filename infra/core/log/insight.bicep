param location string
param workspaceResourceName string
param appInsightResourceName string

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: workspaceResourceName
  location: location
}

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightResourceName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}

output insightResourceName string = insights.name
