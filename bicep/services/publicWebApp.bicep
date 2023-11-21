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

@description('The name of the Key Vault.')
param parKeyVaultName string

@description('The name of the Application Insights resource.')
param parAppInsightsName string

@description('The subscription ID of the Front Door.')
param parFrontDoorSubscriptionId string

@description('The resource group name of the Front Door.')
param parFrontDoorResourceGroupName string

@description('The name of the Front Door.')
param parFrontDoorName string

@description('The subscription ID of the DNS.')
param parDnsSubscriptionId string

@description('The resource group name of the DNS.')
param parDnsResourceGroupName string

@description('The DNS prefix of the public web app.')
param parPublicWebAppDnsPrefix string

@description('The parent DNS name.')
param parParentDnsName string

@description('The subscription ID of the Strategic Services.')
param parStrategicServicesSubscriptionId string

@description('The resource group name of the API Management.')
param parApiManagementResourceGroupName string

@description('The name of the API Management.')
param parApiManagementName string

@description('The resource group name of the Web Apps.')
param parWebAppsResourceGroupName string

@description('The name of the App Service Plan.')
param parAppServicePlanName string

@description('The tags to apply to the resources.')
param parTags object

// Variables
var varWorkloadName = 'app-geolocation-web-${parEnvironment}-${parInstance}-${parEnvironmentUniqueId}'
var varAppInsightsName = 'ai-geolocation-${parEnvironment}-${parLocation}-${parInstance}'

// Existing Out-Of-Scope Resources
@description('https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
resource keyVaultSecretUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

// Existing In-Scope Resources
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: parAppInsightsName
}

// Module Resources
module webApp 'publicWebApp/webApp.bicep' = {
  name: '${deployment().name}-webapp'
  scope: resourceGroup(parStrategicServicesSubscriptionId, parWebAppsResourceGroupName)

  params: {
    parEnvironment: parEnvironment
    parEnvironmentUniqueId: parEnvironmentUniqueId
    parLocation: parLocation
    parInstance: parInstance

    parKeyVaultName: parKeyVaultName
    parApiManagementSubscriptionId: parStrategicServicesSubscriptionId
    parApiManagementResourceGroupName: parApiManagementResourceGroupName
    parApiManagementName: parApiManagementName
    parAppServicePlanName: parAppServicePlanName

    parAppInsightsRef: {
      Name: varAppInsightsName
      SubscriptionId: subscription().subscriptionId
      ResourceGroupName: resourceGroup().name
    }

    parTags: parTags
  }
}

module publicWebAppKeyVaultRoleAssignment 'br:acrty7og2i6qpv3s.azurecr.io/bicep/modules/keyvaultroleassignment:latest' = {
  name: '${deployment().name}-kvwebapprole'

  params: {
    parKeyVaultName: parKeyVaultName
    parRoleDefinitionId: keyVaultSecretUserRoleDefinition.id
    parPrincipalId: webApp.outputs.outWebAppIdentityPrincipalId
  }
}

module apiManagementSubscription 'br:acrty7og2i6qpv3s.azurecr.io/bicep/modules/apimanagementsubscription:latest' = {
  name: '${deployment().name}-apimsubscription'
  scope: resourceGroup(parStrategicServicesSubscriptionId, parApiManagementResourceGroupName)

  params: {
    parDeploymentPrefix: deployment().name
    parApiManagementName: parApiManagementName
    parWorkloadSubscriptionId: subscription().subscriptionId
    parWorkloadResourceGroupName: resourceGroup().name
    parWorkloadName: varWorkloadName
    parKeyVaultName: parKeyVaultName
    parSubscriptionScopeIdentifier: 'geolocation'
    parSubscriptionScope: '/apis/geolocation-api'
    parTags: parTags
  }
}

module frontDoorEndpoint 'br:acrty7og2i6qpv3s.azurecr.io/bicep/modules/frontdoorendpoint:latest' = {
  name: '${deployment().name}-webappfdendpoint'
  scope: resourceGroup(parFrontDoorSubscriptionId, parFrontDoorResourceGroupName)

  params: {
    parDeploymentPrefix: deployment().name
    parFrontDoorName: parFrontDoorName
    parDnsSubscriptionId: parDnsSubscriptionId
    parDnsResourceGroupName: parDnsResourceGroupName
    parParentDnsName: parParentDnsName
    parWorkloadName: varWorkloadName
    parOriginHostName: webApp.outputs.outWebAppDefaultHostName
    parDnsZoneHostnamePrefix: parPublicWebAppDnsPrefix
    parCustomHostname: '${parPublicWebAppDnsPrefix}.${parParentDnsName}'
    parTags: parTags
  }
}

resource webTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: '${deployment().name}-webtest'
  location: parLocation
  tags: union(parTags, {
      'hidden-link:${appInsights.id}': 'Resource'
    })

  dependsOn: [
    frontDoorEndpoint
  ]

  properties: {
    SyntheticMonitorId: '${varWorkloadName}-availability-test'
    Name: '${varWorkloadName}-availability-test'
    Enabled: true
    Frequency: 300
    Timeout: 120
    Kind: 'ping'
    RetryEnabled: true

    Locations: [
      {
        Id: 'emea-ru-msa-edge'
      }
      {
        Id: 'emea-se-sto-edge'
      }
      {
        Id: 'us-il-ch1-azr'
      }
      {
        Id: 'emea-ch-zrh-edge'
      }
      {
        Id: 'apac-hk-hkn-azr'
      }
    ]

    Configuration: {
      WebTest: '<WebTest         Name="${varWorkloadName}-availability-test"         Id="1f60b4da-4c5f-4d68-9b9b-afe669fa26e4"         Enabled="True"         CssProjectStructure=""         CssIteration=""         Timeout="120"         WorkItemIds=""         xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010"         Description=""         CredentialUserName=""         CredentialPassword=""         PreAuthenticate="True"         Proxy="default"         StopOnError="False"         RecordedResultFile=""         ResultsLocale="">        <Items>        <Request         Method="GET"         Guid="a4c43a5a-cc8c-b111-1f8a-7b7f03187fd1"         Version="1.1"         Url="https://${parPublicWebAppDnsPrefix}.${parParentDnsName}/Home"         ThinkTime="0"         Timeout="120"         ParseDependentRequests="False"         FollowRedirects="True"         RecordResult="True"         Cache="False"         ResponseTimeGoal="0"         Encoding="utf-8"         ExpectedHttpStatusCode="200"         ExpectedResponseUrl=""         ReportingName=""         IgnoreHttpStatusCode="False" />        </Items>        </WebTest>'
    }
  }
}

// Outputs
output outWebAppIdentityPrincipalId string = webApp.outputs.outWebAppIdentityPrincipalId
output outWebAppName string = webApp.outputs.outWebAppName
