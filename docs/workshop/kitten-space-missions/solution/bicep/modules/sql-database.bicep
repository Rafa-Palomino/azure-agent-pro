// ============================================================================
// SQL DATABASE MODULE - SQL Server + Database with AAD Auth
// Purpose: Deploy Azure SQL with Managed Identity and security hardening
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

@description('SQL Server admin login')
param adminLogin string

@description('SQL Server admin password')
@secure()
param adminPassword string

@description('SQL Database tier (Basic, Standard, Premium)')
param databaseTier string = 'Basic'

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

// ============================================================================
// VARIABLES
// ============================================================================

var resourceNamePrefix = '${projectName}-${workloadName}-${environment}'
var sqlServerName = 'sqlsrv-${resourceNamePrefix}-${uniqueString(resourceGroup().id)}'
var sqlDatabaseName = 'sqldb-${resourceNamePrefix}'

// ============================================================================
// SQL SERVER
// ============================================================================

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: 'Disabled'
    primaryUserAssignedIdentityId: null
    keyId: null
    administrators: {
      login: 'AzureAD Admin'
      sid: '00000000-0000-0000-0000-000000000000'
      tenantId: subscription().tenantId
      principalType: 'Group'
    }
  }
}

// ============================================================================
// FIREWALL RULE - Allow Azure Services
// ============================================================================

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ============================================================================
// SQL DATABASE
// ============================================================================

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    name: databaseTier
    tier: databaseTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: (databaseTier == 'Basic') ? 104857600 : (databaseTier == 'Standard') ? 268435456 : 1099511627776
    createMode: 'Default'
    zoneRedundant: false
    isLedgerOn: false
  }
}

// ============================================================================
// TRANSPARENT DATA ENCRYPTION
// ============================================================================

resource transparentDataEncryption 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-05-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// ============================================================================
// DIAGNOSTIC SETTINGS
// ============================================================================

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlDatabase.name}-diagnostics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'SQLInsights'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'Errors'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'Basic'
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
// OUTPUTS
// ============================================================================

@description('SQL Server ID')
output sqlServerId string = sqlServer.id

@description('SQL Server Name')
output sqlServerName string = sqlServer.name

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Database ID')
output sqlDatabaseId string = sqlDatabase.id

@description('SQL Database Name')
output sqlDatabaseName string = sqlDatabase.name
