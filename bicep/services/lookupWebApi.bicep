targetScope = 'resourceGroup'

// Parameters
param parLocation string
param parEnvironment string
param parKeyVaultName string
param parAppInsightsName string
param parConnectivitySubscriptionId string
param parDnsResourceGroupName string
param parParentDnsName string
param parStrategicServicesSubscriptionId string
param parApimResourceGroupName string
param parApiManagementName string
param parWebAppsResourceGroupName string
param parAppServicePlanName string
param parTags object

// Variables
var varFrontDoorName = 'fd-webapi-geolocation-lookup-${parEnvironment}'
var varFrontDoorDns = 'webapi-geolocation-lookup-${parEnvironment}'

// Existing Resources
resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: parKeyVaultName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: parAppInsightsName
}

resource apiManagement 'Microsoft.ApiManagement/service@2021-12-01-preview' existing = {
  name: parApiManagementName
  scope: resourceGroup(parStrategicServicesSubscriptionId, parApimResourceGroupName)
}

// Module Resources
module scopedLookupWebApi 'modules/scopedLookupWebApi.bicep' = {
  name: 'scopedLookupWebApi'
  scope: resourceGroup(parStrategicServicesSubscriptionId, parWebAppsResourceGroupName)

  params: {
    parLocation: parLocation
    parEnvironment: parEnvironment
    parKeyVaultName: parKeyVaultName
    parAppInsightsName: parAppInsightsName
    parAppServicePlanName: parAppServicePlanName
    parWorkloadSubscriptionId: subscription().id
    parWorkloadResourceGroupName: resourceGroup().name
    parTags: parTags
  }
}

resource webAppKeyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = {
  name: 'add'
  parent: keyVault

  properties: {
    accessPolicies: [
      {
        objectId: scopedLookupWebApi.outputs.outWebAppIdentityPrincipalId
        permissions: {
          certificates: []
          keys: []
          secrets: [
            'get'
          ]
          storage: []
        }
        tenantId: tenant().tenantId
      }
    ]
  }
}

//module lookupWebApiFrontDoor 'modules/frontDoor.bicep' = {
//  name: 'lookupWebApiFrontDoor'
//
//  params: {
//    parFrontDoorName: varFrontDoorName
//    parFrontDoorDns: varFrontDoorDns
//    parParentDnsName: parParentDnsName
//    parConnectivitySubscriptionId: parConnectivitySubscriptionId
//    parDnsResourceGroupName: parDnsResourceGroupName
//    parOriginHostName: scopedLookupWebApi.outputs.outWebAppDefaultHostName
//    parTags: parTags
//  }
//}

module apiManagementLookupApi 'modules/apiManagementLookupApi.bicep' = {
  name: 'apiManagementLookupApi'
  scope: resourceGroup(parStrategicServicesSubscriptionId, parApimResourceGroupName)

  params: {
    parApiManagementName: parApiManagementName
    parFrontDoorDns: varFrontDoorDns
    parParentDnsName: parParentDnsName
    parEnvironment: parEnvironment
    parKeyVaultUri: keyVault.properties.vaultUri
    parAppInsightsName: parAppInsightsName
  }
}
