// ============================================================================
// PRIVATE ENDPOINT MODULE - Generic Private Endpoint with DNS Integration
// Purpose: Reusable module supporting multiple Azure service types
// ============================================================================

@description('Azure region for resources')
param location string

@description('Project name')
param projectName string

@description('Workload name')
param workloadName string

@description('Environment name (dev, test, prod)')
param deploymentEnvironment string

@description('Resource tags')
param tags object

@description('Service name for PE (sql, keyvault, blob, etc.)')
param serviceName string

@description('Private Link Service Resource ID')
param privateLinkServiceId string

@description('Group ID for the service (sqlServer, vault, blob, etc.)')
param groupId string

@description('Subnet ID where PE will be deployed')
param subnetId string

@description('Virtual Network ID for DNS zone linking')
param vnetId string

// ============================================================================
// VARIABLES
// ============================================================================

var resourceNamePrefix = '${projectName}-${workloadName}-${deploymentEnvironment}'
var peConnectionName = 'pec-${serviceName}-${resourceNamePrefix}'
var peName = 'pe-${serviceName}-${resourceNamePrefix}'

// DNS Zone Name Mapping (using environment() function for cloud compatibility)
var dnsZoneNames = {
  sqlServer: 'privatelink${environment().suffixes.sqlServerHostname}'
  vault: 'privatelink${environment().suffixes.keyvaultDns}'
  blob: 'privatelink.blob${environment().suffixes.storage}'
  file: 'privatelink.file${environment().suffixes.storage}'
  queue: 'privatelink.queue${environment().suffixes.storage}'
  table: 'privatelink.table${environment().suffixes.storage}'
  sites: 'privatelink.azurewebsites.net'
  database: 'privatelink${environment().suffixes.sqlServerHostname}'
}

var dnsZoneName = dnsZoneNames[groupId]

// ============================================================================
// PRIVATE ENDPOINT
// ============================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: peConnectionName
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: [
            groupId
          ]
          requestMessage: ''
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: subnetId
    }
    customDnsConfigs: []
    ipConfigurations: []
  }
}

// ============================================================================
// PRIVATE DNS ZONE
// ============================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
  tags: tags
  properties: {}
}

// ============================================================================
// PRIVATE DNS ZONE - VNET LINK
// ============================================================================

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-${deploymentEnvironment}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ============================================================================
// PRIVATE DNS ZONE GROUP (for A record auto-creation)
// ============================================================================

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: dnsZoneName
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Private Endpoint ID')
output privateEndpointId string = privateEndpoint.id

@description('Private Endpoint Name')
output privateEndpointName string = privateEndpoint.name

@description('Private DNS Zone ID')
output privateDnsZoneId string = privateDnsZone.id

@description('Private DNS Zone Name')
output privateDnsZoneName string = privateDnsZone.name
