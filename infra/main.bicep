@description('The base name of the Azure Functions app')
param name string

@description('The location for all resources')
param location string

@description('The environment name (e.g., dev, test, prod)')
param environment string

// Tags to apply to all resources
var tags object = {
  Environment: environment
  Project: 'AzureFunctionsApp'
  ManagedBy: 'Bicep'
}

// Variables
var functionAppName = '${name}-${environment}'
var storageAccountName = take('${replace(functionAppName, '-', '')}san', 24)
var logAnalyticsWorkspaceName = '${functionAppName}-law'
var applicationInsightsName = '${functionAppName}-ai'
var appServicePlanName = '${functionAppName}-asp'

// Storage Account for Azure Functions
// https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/2025-01-01/storageaccounts?pivots=deployment-language-bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_3'
    defaultToOAuthAuthentication: true
  }
}

// Log Analytics Workspace for structured logging
// https://learn.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/2025-02-01/workspaces?pivots=deployment-language-bicep
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights for monitoring and telemetry
// https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/2020-02-02/components?pivots=deployment-language-bicep
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan - Flex Consumption on Linux
// https://learn.microsoft.com/en-us/azure/templates/microsoft.web/2024-11-01/serverfarms?pivots=deployment-language-bicep
resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true // Linux app service plan
  }
}

// Azure Functions App
// https://learn.microsoft.com/en-us/azure/templates/microsoft.web/2024-11-01/sites?pivots=deployment-language-bicep
resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|9.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}deployments'
          authentication: {
            type: 'StorageAccountConnectionString'
            storageAccountConnectionStringName: 'AzureWebJobsStorage'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '9.0'
      }
    }
    httpsOnly: true
  }
}

// Output values
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output resourceGroupName string = resourceGroup().name
output storageAccountName string = storageAccount.name
output applicationInsightsName string = applicationInsights.name
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
