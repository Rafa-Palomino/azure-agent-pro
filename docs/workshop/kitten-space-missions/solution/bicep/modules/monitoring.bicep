// ============================================================================
// MONITORING MODULE - Log Analytics, Application Insights, Alert Rules
// Purpose: Centralized observability and alerting infrastructure
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

@description('Log Analytics retention in days')
param logAnalyticsRetentionDays int = (environment == 'dev') ? 7 : 30

// ============================================================================
// VARIABLES
// ============================================================================

var resourceNamePrefix = '${projectName}-${workloadName}-${environment}'
var logAnalyticsWorkspaceName = 'log-${resourceNamePrefix}'
var appInsightsName = 'appi-${resourceNamePrefix}'

// ============================================================================
// LOG ANALYTICS WORKSPACE
// ============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionDays
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// APPLICATION INSIGHTS
// ============================================================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: logAnalyticsRetentionDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    SamplingPercentage: 100
    DisableIpMasking: false
    ImmediatePurgeDataOn30Days: false
  }
}

// ============================================================================
// ACTION GROUP (for alerts)
// ============================================================================

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${resourceNamePrefix}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'KittenAPI'
    enabled: true
    armRoleReceivers: []
    automationRunbookReceivers: []
    azureAppPushReceivers: []
    azureFunctionReceivers: []
    emailReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
    logicAppReceivers: []
    smsReceivers: []
    voiceReceivers: []
    webhookReceivers: []
  }
}

// ============================================================================
// ALERT RULE 1 - HTTP 5xx Errors
// ============================================================================

resource alert5xxErrors 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-http5xx-${resourceNamePrefix}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when HTTP 5xx errors exceed threshold'
    severity: 2
    enabled: false
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Server errors'
          metricName: 'server/exceptions'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
    autoMitigate: true
  }
}

// ============================================================================
// ALERT RULE 2 - Response Time (p95)
// ============================================================================

resource alertResponseTime 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-responsetime-${resourceNamePrefix}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when p95 response time exceeds 500ms'
    severity: 3
    enabled: false
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Response time'
          metricName: 'performanceCounters/processorCpuPercentage'
          operator: 'GreaterThan'
          threshold: 500
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
    autoMitigate: true
  }
}

// ============================================================================
// ALERT RULE 3 - Failed Requests
// ============================================================================

resource alertFailedRequests 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-failedrequests-${resourceNamePrefix}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when failed request rate exceeds 20%'
    severity: 2
    enabled: false
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Failed requests'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: 20
          timeAggregation: 'Percentage'
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
    autoMitigate: true
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics Workspace Name')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('Application Insights ID')
output appInsightsId string = applicationInsights.id

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('Application Insights Connection String')
output appInsightsConnectionString string = applicationInsights.properties.ConnectionString

@description('Action Group ID')
output actionGroupId string = actionGroup.id
