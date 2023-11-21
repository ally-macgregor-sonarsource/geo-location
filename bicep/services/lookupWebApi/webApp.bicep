targetScope = 'resourceGroup'

// Parameters
@description('The environment name (e.g. dev, test, prod).')
param parEnvironment string

@description('The environment unique identifier (e.g. 1234).')
param parEnvironmentUniqueId string

@description('The location of the resource group.')
param parLocation string

@description('The instance name (e.g. 01, 02, 03).')
param parInstance string

@description('The name of the key vault.')
param parKeyVaultName string

@description('The name of the application data storage account.')
param parAppDataStorageAccountName string

@description('The name of the application service plan.')
param parAppServicePlanName string

@description('The app insights reference')
param parAppInsightsRef object

@description('The tags to apply to the resources.')
param parTags object

// Variables
var varWebAppName = 'app-geolocation-api-${parEnvironment}-${parLocation}-${parInstance}-${parEnvironmentUniqueId}'

// Existing In-Scope Resources
resource appServicePlan 'Microsoft.Web/serverfarms@2020-10-01' existing = {
  name: parAppServicePlanName
}

// Existing Out-Of-Scope Resources
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: parAppInsightsRef.Name
  scope: resourceGroup(parAppInsightsRef.SubscriptionId, parAppInsightsRef.ResourceGroupName)
}

// Module Resources
resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: varWebAppName
  location: parLocation
  kind: 'app'
  tags: parTags

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    serverFarmId: appServicePlan.id

    httpsOnly: true

    siteConfig: {
      ftpsState: 'Disabled'

      alwaysOn: true
      linuxFxVersion: 'DOTNETCORE|7.0'
      netFrameworkVersion: '7.0'
      minTlsVersion: '1.2'

      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'AzureAd__TenantId'
          value: tenant().tenantId
        }
        {
          name: 'AzureAd__Instance'
          value: environment().authentication.loginEndpoint
        }
        {
          name: 'AzureAd__ClientId'
          value: '@Microsoft.KeyVault(VaultName=${parKeyVaultName};SecretName=geolocation-api-${parEnvironment}-clientid)'
        }
        {
          name: 'AzureAd__ClientSecret'
          value: '@Microsoft.KeyVault(VaultName=${parKeyVaultName};SecretName=geolocation-api-${parEnvironment}-clientsecret)'
        }
        {
          name: 'AzureAd__Audience'
          value: 'api://geolocation-api-${parEnvironment}-${parInstance}'
        }
        {
          name: 'maxmind_apikey'
          value: '@Microsoft.KeyVault(VaultName=${parKeyVaultName};SecretName=maxmind-apikey)'
        }
        {
          name: 'maxmind_userid'
          value: '@Microsoft.KeyVault(VaultName=${parKeyVaultName};SecretName=maxmind-userid)'
        }
        {
          name: 'appdata_storage_connectionstring'
          value: '@Microsoft.KeyVault(VaultName=${parKeyVaultName};SecretName=${parAppDataStorageAccountName}-connectionstring)'
        }
      ]
    }
  }
}

// Outputs
output outWebAppDefaultHostName string = webApp.properties.defaultHostName
output outWebAppIdentityPrincipalId string = webApp.identity.principalId
output outWebAppName string = webApp.name
