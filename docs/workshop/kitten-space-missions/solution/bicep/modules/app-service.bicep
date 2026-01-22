// ============================================================================
// APP SERVICE MODULE - App Service Plan + App Service with Managed Identity
// Purpose: Deploy .NET 8 API application with VNet integration
// ============================================================================

@description('Azure region for resources')
param location string

@description('Project name')
param projectName string

@description('Workload name')
param workloadName string

@description('Environment name')
param environment string

@description('Resource tags')
param tags object

@description('App Service Plan SKU (B1, B2, S1, etc.)')
param appServicePlanSku string = 'B1'

@description('VNet Subnet ID for VNet integration')
param vnetSubnetId string

@description('Key Vault URI')
param keyVaultUri string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Application Insights Instrumentation Key')
param appInsightsInstrumentationKey string

@description('SQL Server FQDN')
param sqlServerFqdn string

@description('SQL Database Name')
param sqlDatabaseName string

@description('SQL Server Resource ID (for RBAC)')
param sqlServerResourceId string

// ============================================================================
// VARIABLES
// ============================================================================

var resourceNamePrefix = '${projectName}-${workloadName}-${environment}'
var appServicePlanName = 'plan-${resourceNamePrefix}'
var appServiceName = 'app-${resourceNamePrefix}'
var appServiceUri = 'https://${appServiceName}.azurewebsites.net'

// ============================================================================
// APP SERVICE PLAN
// ============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: (appServicePlanSku == 'B1' || appServicePlanSku == 'B2' || appServicePlanSku == 'B3') ? 'Basic' : (appServicePlanSku == 'S1' || appServicePlanSku == 'S2' || appServicePlanSku == 'S3') ? 'Standard' : 'Premium'
  }
  kind: 'Linux'
  properties: {
    reserved: true
  }
}

// ============================================================================
// APP SERVICE
// ============================================================================

resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: vnetSubnetId
    vnetRouteAllEnabled: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      minTlsVersion: '1.2'
      http20Enabled: true
      alwaysOn: true
      numberOfWorkers: 1
      defaultDocuments: []
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment == 'prod' ? 'Production' : 'Development'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'KeyVault:Uri'
          value: keyVaultUri
        }
        {
          name: 'Sql:Server'
          value: sqlServerFqdn
        }
        {
          name: 'Sql:Database'
          value: sqlDatabaseName
        }
        {
          name: 'Sql:Authentication'
          value: 'ManagedIdentity'
        }
      ]
    }
  }
}

// ============================================================================
// VNet INTEGRATION CONFIGURATION
// ============================================================================

resource vnetIntegration 'Microsoft.Web/sites/virtualNetworkConnections@2023-01-01' = {
  parent: appService
  name: 'VNet'
  properties: {
    vnetResourceId: vnetSubnetId
    isSwift: true
  }
}

// ============================================================================
// DIAGNOSTIC SETTINGS
// ============================================================================

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appService.name}-diagnostics'
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
      {
        category: 'AppServiceApplicationLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// ============================================================================
// AUTOSCALE SETTINGS (for B2 and above)
// ============================================================================

resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2015-04-01' = if (appServicePlanSku != 'B1') {
  name: '${appServicePlan.name}-autoscale'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'Auto scale based on CPU'
        capacity: {
          minimum: '1'
          maximum: '3'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('App Service ID')
output appServiceId string = appService.id

@description('App Service Name')
output appServiceName string = appService.name

@description('App Service URI')
output appServiceUri string = appServiceUri

@description('Managed Identity Principal ID')
output managedIdentityPrincipalId string = appService.identity.principalId

@description('App Service Plan ID')
output appServicePlanId string = appServicePlan.id
