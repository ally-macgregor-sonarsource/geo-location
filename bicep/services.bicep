targetScope = 'resourceGroup'

@description('The environment name (e.g. dev, test, prod)')
param parEnvironment string

@description('The location of the resource group')
param parLocation string

@description('The instance name (e.g. 01, 02, 03, etc.')
param parInstance string

@description('The Front Door configuration')
param parFrontDoor object

@description('The DNS configuration')
param parDns object

@description('The Strategic Services configuration')
param parStrategicServices object

@description('The tags to apply to the resources')
param parTags object

// Variables
var varEnvironmentUniqueId = uniqueString('geolocation', parEnvironment, parInstance)

var varKeyVaultName = 'kv-${varEnvironmentUniqueId}-${parLocation}'
var varAppInsightsName = 'ai-geolocation-${parEnvironment}-${parLocation}-${parInstance}'

module lookupWebApi 'services/lookupWebApi.bicep' = {
  name: '${deployment().name}-webapi'
  params: {
    parEnvironment: parEnvironment
    parEnvironmentUniqueId: varEnvironmentUniqueId
    parLocation: parLocation
    parInstance: parInstance

    parKeyVaultName: varKeyVaultName
    parAppInsightsName: varAppInsightsName
    parFrontDoorSubscriptionId: parFrontDoor.SubscriptionId
    parDnsSubscriptionId: parDns.SubscriptionId
    parFrontDoorResourceGroupName: parFrontDoor.FrontDoorResourceGroupName
    parDnsResourceGroupName: parDns.DnsResourceGroupName
    parFrontDoorName: parFrontDoor.FrontDoorName
    parParentDnsName: parDns.ParentDnsName
    parStrategicServicesSubscriptionId: parStrategicServices.SubscriptionId
    parApiManagementResourceGroupName: parStrategicServices.ApiManagementResourceGroupName
    parApiManagementName: parStrategicServices.ApiManagementName
    parWebAppsResourceGroupName: parStrategicServices.WebAppsResourceGroupName
    parAppServicePlanName: parStrategicServices.AppServicePlanName
    parTags: parTags
  }
}

module publicWebApp 'services/publicWebApp.bicep' = {
  name: '${deployment().name}-webapp'
  params: {
    parEnvironment: parEnvironment
    parEnvironmentUniqueId: varEnvironmentUniqueId
    parLocation: parLocation
    parInstance: parInstance

    parKeyVaultName: varKeyVaultName
    parAppInsightsName: varAppInsightsName
    parFrontDoorSubscriptionId: parFrontDoor.SubscriptionId
    parDnsSubscriptionId: parDns.SubscriptionId
    parFrontDoorResourceGroupName: parFrontDoor.FrontDoorResourceGroupName
    parDnsResourceGroupName: parDns.DnsResourceGroupName
    parFrontDoorName: parFrontDoor.FrontDoorName
    parPublicWebAppDnsPrefix: parDns.PublicWebAppDnsPrefix
    parParentDnsName: parDns.ParentDnsName
    parStrategicServicesSubscriptionId: parStrategicServices.SubscriptionId
    parApiManagementResourceGroupName: parStrategicServices.ApiManagementResourceGroupName
    parApiManagementName: parStrategicServices.ApiManagementName
    parWebAppsResourceGroupName: parStrategicServices.WebAppsResourceGroupName
    parAppServicePlanName: parStrategicServices.AppServicePlanName
    parTags: parTags
  }
}

// Outputs
output outWebAppIdentityPrincipalId string = publicWebApp.outputs.outWebAppIdentityPrincipalId
output outWebAppName string = publicWebApp.outputs.outWebAppName
output outWebApiName string = lookupWebApi.outputs.outWebAppName
