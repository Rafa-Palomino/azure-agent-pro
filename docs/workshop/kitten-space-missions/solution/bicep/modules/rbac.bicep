// ============================================================================
// RBAC MODULE - Role-Based Access Control Assignments
// Purpose: Configure Managed Identity permissions for secure access
// ============================================================================

@description('App Service Managed Identity Principal ID')
param appServicePrincipalId string

@description('SQL Server Resource ID')
param sqlServerId string

@description('SQL Server Name')
param sqlServerName string

@description('Key Vault Resource ID')
param keyVaultId string

@description('Resource tags')
param tags object

// ============================================================================
// VARIABLES
// ============================================================================

// RBAC Role Definitions
var roleIds = {
  sqlDbContributor: '9b7fa17d-e63a-4f14-b0d0-5d2b24b8ee29' // SQL DB Contributor
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0dc8fde00a6d' // Key Vault Secrets User
}

// ============================================================================
// ROLE ASSIGNMENT 1 - SQL DB Contributor for App Service on SQL Server
// ============================================================================

resource sqlDbRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appServicePrincipalId, sqlServerId, roleIds.sqlDbContributor)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.sqlDbContributor)
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// ROLE ASSIGNMENT 2 - Key Vault Secrets User for App Service on Key Vault
// ============================================================================

resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appServicePrincipalId, keyVaultId, roleIds.keyVaultSecretsUser)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.keyVaultSecretsUser)
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('SQL DB Contributor Role Assignment ID')
output sqlDbRoleAssignmentId string = sqlDbRoleAssignment.id

@description('Key Vault Secrets User Role Assignment ID')
output keyVaultRoleAssignmentId string = keyVaultSecretsUserAssignment.id
