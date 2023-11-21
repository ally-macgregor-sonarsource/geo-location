targetScope = 'resourceGroup'

// Parameters
@description('The environment name (e.g. dev, test, prod)')
param parEnvironment string

@description('The environment unique identifier (e.g. 1234)')
param parEnvironmentUniqueId string

@description('The location of the resource group.')
param parLocation string

@description('The instance name (e.g. 01, 02, 03)')
param parInstance string

@description('The name of the key vault.')
param parKeyVaultName string

@description('The name of the application insights.')
param parAppInsightsName string

@description('The subscription id of the front door. (e.g. 12345678-1234-1234-1234-123456789012)')
param parFrontDoorSubscriptionId string

@description('The resource group name of the front door.')
param parFrontDoorResourceGroupName string

@description('The name of the front door.')
param parFrontDoorName string

@description('The subscription id of the DNS. (e.g. 12345678-1234-1234-1234-123456789012)')
param parDnsSubscriptionId string

@description('The resource group name of the DNS.')
param parDnsResourceGroupName string

@description('The parent DNS name (e.g. example.com)')
param parParentDnsName string

@description('The subscription id of the strategic services. (e.g. 12345678-1234-1234-1234-123456789012)')
param parStrategicServicesSubscriptionId string

@description('The resource group name of the API Management.')
param parApiManagementResourceGroupName string

@description('The name of the API Management.')
param parApiManagementName string

@description('The resource group name of the web apps.')
param parWebAppsResourceGroupName string

@description('The name of the app service plan.')
param parAppServicePlanName string

@description('The tags to apply to the resources.')
param parTags object

// Variables
var varWorkloadName = 'app-geolocation-api-${parEnvironment}-${parInstance}-${parEnvironmentUniqueId}'
var varAppInsightsName = 'ai-geolocation-${parEnvironment}-${parLocation}-${parInstance}'

// Existing Out-Of-Scope Resources
@description('https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

// Module Resources
module appDataStorage 'lookupWebApi/appDataStorage.bicep' = {
  name: '${deployment().name}-appdata'

  params: {
    parDeploymentPrefix: deployment().name
    parLocation: parLocation
    parKeyVaultName: parKeyVaultName
    parTags: parTags
  }
}

module webApp 'lookupWebApi/webApp.bicep' = {
  name: '${deployment().name}-webapp'
  scope: resourceGroup(parStrategicServicesSubscriptionId, parWebAppsResourceGroupName)

  params: {
    parEnvironment: parEnvironment
    parEnvironmentUniqueId: parEnvironmentUniqueId
    parLocation: parLocation
    parInstance: parInstance

    parKeyVaultName: parKeyVaultName
    parAppDataStorageAccountName: appDataStorage.outputs.outStorageAccountName
    parAppServicePlanName: parAppServicePlanName

    parAppInsightsRef: {
      Name: varAppInsightsName
      SubscriptionId: subscription().subscriptionId
      ResourceGroupName: resourceGroup().name
    }

    parTags: parTags
  }
}

module lookupWebApiKeyVaultRoleAssignment 'br:acrty7og2i6qpv3s.azurecr.io/bicep/modules/keyvaultroleassignment:latest' = {
  name: '${deployment().name}-kvwebapirole'

  params: {
    parKeyVaultName: parKeyVaultName
    parRoleDefinitionId: keyVaultSecretUserRoleDefinition.id
    parPrincipalId: webApp.outputs.outWebAppIdentityPrincipalId
  }
}

module apiManagementApi 'lookupWebApi/apiManagementApi.bicep' = {
  name: '${deployment().name}-api'
  scope: resourceGroup(parStrategicServicesSubscriptionId, parApiManagementResourceGroupName)

  params: {
    parEnvironment: parEnvironment
    parInstance: parInstance

    parApiManagementName: parApiManagementName
    parFrontDoorDns: varWorkloadName
    parParentDnsName: parParentDnsName

    parAppInsightsName: parAppInsightsName
  }
}

module frontDoorEndpoint 'br:acrty7og2i6qpv3s.azurecr.io/bicep/modules/frontdoorendpoint:latest' = {
  name: '${deployment().name}-webapifdendpoint'
  scope: resourceGroup(parFrontDoorSubscriptionId, parFrontDoorResourceGroupName)

  params: {
    parDeploymentPrefix: deployment().name
    parFrontDoorName: parFrontDoorName
    parDnsSubscriptionId: parDnsSubscriptionId
    parDnsResourceGroupName: parDnsResourceGroupName
    parParentDnsName: parParentDnsName
    parWorkloadName: varWorkloadName
    parOriginHostName: webApp.outputs.outWebAppDefaultHostName
    parDnsZoneHostnamePrefix: varWorkloadName
    parCustomHostname: '${varWorkloadName}.${parParentDnsName}'

    parTags: parTags
  }
}

// Outputs
output outWebAppIdentityPrincipalId string = webApp.outputs.outWebAppIdentityPrincipalId
output outWebAppName string = webApp.outputs.outWebAppName
