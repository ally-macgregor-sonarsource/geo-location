targetScope = 'resourceGroup'

// Parameters
param parEnvironment string
param parInstance string

param parApiManagementName string
param parFrontDoorDns string
param parParentDnsName string
param parWorkloadSubscriptionId string
param parWorkloadResourceGroupName string
param parAppInsightsName string

// Existing In-Scope Resources
resource apiManagement 'Microsoft.ApiManagement/service@2021-12-01-preview' existing = {
  name: parApiManagementName
}

// Existing Out-Of-Scope Resources
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: parAppInsightsName
  scope: resourceGroup(parWorkloadSubscriptionId, parWorkloadResourceGroupName)
}

// Module Resources
resource apiBackend 'Microsoft.ApiManagement/service/backends@2021-08-01' = {
  name: parFrontDoorDns
  parent: apiManagement

  properties: {
    title: parFrontDoorDns
    description: parFrontDoorDns
    url: 'https://${parFrontDoorDns}.${parParentDnsName}/'
    protocol: 'http'
    properties: {}

    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource apiActiveBackendNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  name: 'geolocation-active-backend'
  parent: apiManagement

  properties: {
    displayName: 'geolocation-active-backend'
    value: apiBackend.name
    secret: false
  }
}

resource apiAudienceNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  name: 'geolocation-api-audience'
  parent: apiManagement

  properties: {
    displayName: 'geolocation-api-audience'
    value: 'api://geolocation-api-${parEnvironment}-${parInstance}'
    secret: false
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  name: 'geolocation-api'
  parent: apiManagement

  properties: {
    apiRevision: '1.0'
    apiType: 'http'
    type: 'http'

    displayName: 'GeoLocation Lookup API'
    path: 'geolocation'

    protocols: [
      'https'
    ]

    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
    }

    format: 'openapi+json'
    value: loadTextContent('./../../../.azure-pipelines/api-definitions/lookup-api.openapi+json.json')
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-08-01' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'xml'
    value: '''
<policies>
  <inbound>
      <base/>
      <set-backend-service backend-id="{{geolocation-active-backend}}" />
      <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" downstream-caching-type="none" />
      <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="JWT validation was unsuccessful" require-expiration-time="true" require-scheme="Bearer" require-signed-tokens="true">
          <openid-config url="{{tenant-login-url}}{{tenant-id}}/v2.0/.well-known/openid-configuration" />
          <audiences>
              <audience>{{geolocation-api-audience}}</audience>
          </audiences>
          <issuers>
              <issuer>https://sts.windows.net/{{tenant-id}}/</issuer>
          </issuers>
          <required-claims>
              <claim name="roles" match="any">
                <value>LookupApiUser</value>
              </claim>
          </required-claims>
      </validate-jwt>
  </inbound>
  <backend>
      <forward-request />
  </backend>
  <outbound>
      <base/>
      <cache-store duration="3600" />
  </outbound>
  <on-error />
</policies>'''
  }

  dependsOn: [
    apiActiveBackendNamedValue
    apiAudienceNamedValue
  ]
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2021-08-01' = {
  name: 'applicationinsights'
  parent: api

  properties: {
    alwaysLog: 'allErrors'

    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId('Microsoft.ApiManagement/service/loggers', apiManagement.name, appInsights.name)
    operationNameFormat: 'Name'

    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }

    verbosity: 'information'
  }
}
