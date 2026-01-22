// ============================================================================
// KITTEN SPACE MISSIONS API - Bicep Main Orchestrator
// Deployment Scope: Subscription
// Environment: Development (with parameters for production)
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Environment name (dev, test, prod)')
param environment string

@description('Azure region for all resources')
param location string = 'westeurope'

@description('Project name for resource naming')
param projectName string

@description('Workload name (used in naming)')
param workloadName string = 'api'

@description('Resource tags for governance')
param tags object

@description('SQL Server administrator login')
@secure()
param sqlAdminLogin string

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

@description('App Service Plan SKU')
param appServiceSku string = 'B1'

@description('SQL Database tier')
param sqlDatabaseTier string = 'Basic'

@description('Enable auto-shutdown for cost optimization (dev only)')
param enableAutoShutdown bool = (environment == 'dev')

@description('Log Analytics retention in days')
param logAnalyticsRetentionDays int = (environment == 'dev') ? 7 : 30

// ============================================================================
// VARIABLES
// ============================================================================

var resourceNamePrefix = '${projectName}-${workloadName}-${environment}'
var resourceGroupName = 'rg-${resourceNamePrefix}'

// ============================================================================
// RESOURCE GROUP CREATION
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: union(tags, {
    deploymentEnvironment: environment
  })
}

// ============================================================================
// MODULE: MONITORING (Foundation - no dependencies)
// ============================================================================

module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring-deployment'
  params: {
    location: location
    projectName: projectName
    workloadName: workloadName
    environment: environment
    tags: tags
    logAnalyticsRetentionDays: logAnalyticsRetentionDays
  }
}

// ============================================================================
// MODULE: NETWORKING
// ============================================================================

module networking 'modules/networking.bicep' = {
  scope: rg
  name: 'networking-deployment'
  params: {
    location: location
    projectName: projectName
    workloadName: workloadName
    environment: environment
    tags: tags
  }
}

// ============================================================================
// MODULE: KEY VAULT
// ============================================================================

module keyVault 'modules/key-vault.bicep' = {
  scope: rg
  name: 'keyvault-deployment'
  params: {
    location: location
    projectName: projectName
    workloadName: workloadName
    environment: environment
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// ============================================================================
// MODULE: SQL DATABASE
// ============================================================================

module sqlDatabase 'modules/sql-database.bicep' = {
  scope: rg
  name: 'sql-deployment'
  params: {
    location: location
    projectName: projectName
    workloadName: workloadName
    environment: environment
    tags: tags
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    databaseTier: sqlDatabaseTier
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    monitoring
  ]
}

// ============================================================================
// MODULE: PRIVATE ENDPOINT (SQL)
// ============================================================================

module sqlPrivateEndpoint 'modules/private-endpoint.bicep' = {
  scope: rg
  name: 'sql-pe-deployment'
  params: {
    location: location
    projectName: projectName
    workloadName: workloadName
    deploymentEnvironment: environment
    tags: tags
    serviceName: 'sql'
    privateLinkServiceId: sqlDatabase.outputs.sqlServerId
    groupId: 'sqlServer'
    subnetId: networking.outputs.privateEndpointSubnetId
    vnetId: networking.outputs.vnetId
  }
  dependsOn: [
    sqlDatabase
  ]
}

// ============================================================================
// MODULE: PRIVATE ENDPOINT (Key Vault)
// ============================================================================

module kvPrivateEndpoint 'modules/private-endpoint.bicep' = {
  scope: rg
  name: 'kv-pe-deployment'
  params: {
    location: location
    projectName: projectName
    workloadName: workloadName
    deploymentEnvironment: environment
    tags: tags
    serviceName: 'keyvault'
    privateLinkServiceId: keyVault.outputs.keyVaultId
    groupId: 'vault'
    subnetId: networking.outputs.privateEndpointSubnetId
    vnetId: networking.outputs.vnetId
  }
  dependsOn: [
    keyVault
  ]
}

// ============================================================================
// MODULE: APP SERVICE
// ============================================================================

module appService 'modules/app-service.bicep' = {
  scope: rg
  name: 'appservice-deployment'
  params: {
    location: location
    projectName: projectName
    workloadName: workloadName
    environment: environment
    tags: tags
    appServicePlanSku: appServiceSku
    vnetSubnetId: networking.outputs.appServiceSubnetId
    keyVaultUri: keyVault.outputs.keyVaultUri
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    sqlServerFqdn: sqlDatabase.outputs.sqlServerFqdn
    sqlDatabaseName: sqlDatabase.outputs.sqlDatabaseName
    sqlServerResourceId: sqlDatabase.outputs.sqlServerId
  }
  dependsOn: [
    networking
    keyVault
    sqlDatabase
    monitoring
  ]
}

// ============================================================================
// MODULE: RBAC
// ============================================================================

module rbac 'modules/rbac.bicep' = {
  scope: rg
  name: 'rbac-deployment'
  params: {
    appServicePrincipalId: appService.outputs.managedIdentityPrincipalId
    sqlServerId: sqlDatabase.outputs.sqlServerId
    sqlServerName: sqlDatabase.outputs.sqlServerName
    keyVaultId: keyVault.outputs.keyVaultId
    tags: tags
  }
  dependsOn: [
    appService
    sqlDatabase
    keyVault
  ]
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource Group ID')
output resourceGroupId string = rg.id

@description('Resource Group Name')
output resourceGroupName string = rg.name

@description('App Service URL')
output appServiceUri string = appService.outputs.appServiceUri

@description('App Service ID')
output appServiceId string = appService.outputs.appServiceId

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn

@description('SQL Server ID')
output sqlServerId string = sqlDatabase.outputs.sqlServerId

@description('SQL Database Name')
output sqlDatabaseName string = sqlDatabase.outputs.sqlDatabaseName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = monitoring.outputs.appInsightsInstrumentationKey

@description('Virtual Network ID')
output vnetId string = networking.outputs.vnetId

@description('Private Endpoint Subnet ID')
output privateEndpointSubnetId string = networking.outputs.privateEndpointSubnetId

@description('App Service Subnet ID')
output appServiceSubnetId string = networking.outputs.appServiceSubnetId
