targetScope = 'subscription'

// Parameters
param parLocation string
param parEnvironment string
param parLoggingSubscriptionId string
param parLoggingResourceGroupName string
param parLoggingWorkspaceName string
param parManagementSubscriptionId string
param parManagementResourceGroupName string
param parParentDnsName string

// Variables
var varResourceGroupName = 'rg-geolocation-${parEnvironment}-${parLocation}'
var varKeyVaultName = 'kv-geoloc-${parEnvironment}-${parLocation}'
var varAppInsightsName = 'ai-geolocation-${parEnvironment}-${parLocation}'
var varApimName = 'apim-geolocation-${parEnvironment}-${parLocation}'
var varAppServicePlanName = 'plan-geolocation-${parEnvironment}-${parLocation}'
var varDnsZoneName = 'geolocation-${parEnvironment}'

resource defaultResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: varResourceGroupName
  location: parLocation
  properties: {}
}

// Platform
module keyVault 'platform/keyVault.bicep' = {
  name: 'keyVault'
  scope: resourceGroup(defaultResourceGroup.name)
  params: {
    parKeyVaultName: varKeyVaultName
    parLocation: parLocation
  }
}

module logging 'platform/logging.bicep' = {
  name: 'logging'
  scope: resourceGroup(defaultResourceGroup.name)
  params: {
    parAppInsightsName: varAppInsightsName
    parKeyVaultName: keyVault.outputs.outKeyVaultName
    parLocation: parLocation
    parLoggingSubscriptionId: parLoggingSubscriptionId
    parLoggingResourceGroupName: parLoggingResourceGroupName
    parLoggingWorkspaceName: parLoggingWorkspaceName
  }
}

module apiManagment 'platform/apiManagement.bicep' = {
  name: 'apiManagement'
  scope: resourceGroup(defaultResourceGroup.name)
  params: {
    parApimName: varApimName
    parAppInsightsName: logging.outputs.outAppInsightsName
    parKeyVaultName: keyVault.outputs.outKeyVaultName
    parLocation: parLocation
  }
}

module appServicePlan 'platform/appServicePlan.bicep' = {
  name: 'appServicePlan'
  scope: resourceGroup(defaultResourceGroup.name)
  params: {
    parAppServicePlanName: varAppServicePlanName
    parLocation: parLocation
  }
}

module dnsZone 'platform/dns.bicep' = {
  name: 'dnsZone'
  scope: resourceGroup(defaultResourceGroup.name)
  params: {
    parDnsZoneName: varDnsZoneName
    parManagementSubscriptionId: parManagementSubscriptionId
    parManagementResourceGroupName: parManagementResourceGroupName
    parParentDnsName: parParentDnsName
  }
}
