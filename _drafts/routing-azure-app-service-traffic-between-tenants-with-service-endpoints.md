---
title: Routing Azure App Service Traffic Between Tenants With Service Endpoints Enabled
category: Azure
tags:
  - Azure
  - Bicep
  - Private EndPoint
  - Private DNS
---

![image1](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image1.png)

In a recent project, I've needed to develop integration to an API which was **coincidentally hosted in an Azure App Service**. The diagram above is intended to give a brief overview of the cloud architecture with the following key features:

- In the home tenant
  - Multiple app services share the same subnet
  - **Microsoft.Web** service endpoint enabled to restrict access to certain subnets
  - A **NAT Gateway** is attached to the home tenant subnet
- In the external tenant
  - API hosted on app service
  - The API endpoint host was the native **azurewebsites.net**

## The Problem

Initially the **external API** had no access restrictions for development purposes. However, once access restrictions were added to the external API, the **process API** started to receive 403 errors (understandably). The problem, therefore, is how to restore connectivity whilst retaining the access restrictions on the API?

![image2](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image2.png)

My first thought was to a **NAT Gateway** to route the traffic out, over the internet from a known public IP to allow the IP to be added as an **allow rule** on the external API.

``` bash
2024-05-24T16:43:20Z   [Verbose]   Received HTTP response headers after 39.9287ms - 403
2024-05-24T16:43:20Z   [Verbose]   Response Headers: Connection: close Date: Wed, 22 May 2024 16:43:20 GMT x-ms-forbidden-ip: [fd00::1002:fc01:3000:2000:1000] Content-Length: 1892 Content-Type: text/html
```

However, the **trace logs of the HttpClient** showed that I was continuing to get 403 errors from the API and that the source IP was a **private IPv6 ULA**.

After some research it seems that the **Microsoft.Web service endpoint** routes all traffic to an Azure App Service over the Azure backbone, not just local to the current tenant. I came across a few **[stackoverflow posts](https://stackoverflow.com/questions/71075973/any-reason-azure-app-service-outbound-ip-showing-ipv6-when-integrated-with-vnet)** which suggested removing the Microsoft.Web service endpoint, however, this needed to remain enabled to continue restricting other App Services in the home tenant using Azure VNets.

In addition, I also tried repointing the **Process API/client** at a **custom domain** for the API. However, as this was also **configured on the App Service itself**, the traffic was routed over the Azure backbone from an IPv6 address.

## The Solution

The solution I opted for was to deploy a **[Private Endpoint](https://learn.microsoft.com/en-us/azure/app-service/overview-private-endpoint)** which referenced the **external App Service resource**.

![image3](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image3.png)

The Private Endpoint is assigned a **private IPv4 address** from the Azure virtual network using an associated network interface (NIC) resource. Traffic passed to the private endpoint is then routed over the Azure backbone to the **targeted App Service**.

### Creating the Private Endpoint

Firstly, define the names of the Private Endpoint resource and associated NIC along with the resource group and location to place the resources in.

![image4](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image4.png)

On the next page we can specify the targeted resource. As our targeted resource is in an external tenant, select **Connect to an Azure resource by Resource ID or alias** and provide the full resource Id in the format **/subscriptions/*subscriptionId*/resourceGroups/*resourceGroupName*/providers/microsoft.web/sites/*resourceName***.

Also, provide the sub-resource of **sites** as per the **[MS Docs](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource)**.

![image5](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image5.png)

Next, specify the subnet to attach the Private Endpoint to. **N.B.** The subnet needs to not be delegated.

![image6](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image6.png)

As previously mentioned, Private Endpoints expose a private IP in the Azure VNet to route traffic over the backbone to a specific resource. The Private Endpoint will also trigger a **CNAME record** to be added to Azure DNS to the **equivalent [private DNS zone](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#commercial)**. Unfortunately, as we're creating a Private Endpoint to an external resource, this page doesn't allow us to specify the private DNS zone.

![image7](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image7.png)

Once the Private Endpoint has been created, it will go into ***approval***, similar to below, before it can be used.

![image8](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image8.png)

In the **target resource** tenant, the Private Link Center will have an entry like below which will need approving. In my case, it was the owner of the external API.

![image9](/images/routing-azure-app-service-traffic-between-tenants-with-service-endpoints/image9.png)

**N.B.** This manual creation process hasn't allowed the automated integration with private DNS zones, so the DNS records would need to be manually created. However, I've prepared a Bicep template to package and automate the creation of the Private Endpoint, NIC and integrate with private DNS.

### Templating the solution

``` typescript
@description('Required. The name of the private endpoint, following the naming convention e.g. pe-')
param privateEndpointName string

@description('Required. The id of the resource e.g. sqlserver_resource.id')
param resourceId string

@description('Required. Subnet resource Id')
param subnetId string

@description('Required. The type of service')
@allowed([
  'sql'
  'file'
  'blob'
  'table'
  'queue'
  'vault'
  'sites'
])
param resourceType string

@description('Optional. Subscription Id for the resource group of the private DNS resource. Defaults to current subscription')
param privateDnsSubscriptionId string = subscription().subscriptionId

@description('Optional. Resource group name of the private DNS resource. Defaults to current resource group')
param privateDnsResourceGroup string = resourceGroup().name

@description('Optional. Specify if the destination resource is external. Defaults to false')
param isExternalResource bool = false

@description('Optional. Location of the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location

@description('Optional. Tags for the resource. Defaults to the tags of the resource group.')
param tags object = contains(resourceGroup(), 'tags') ? resourceGroup().tags : {}

var settings = {
  sql : {
    privateDnsZoneName: 'privatelink${environment().suffixes.sqlServerHostname}'
    privateEndpointGroupName: 'sqlServer'
  }
  sites : {
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    privateEndpointGroupName: 'sites'
  }
  file : {
    privateDnsZoneName: 'privatelink.file.${environment().suffixes.storage}'
    privateEndpointGroupName: 'file'
  }
  queue : {
    privateDnsZoneName: 'privatelink.queue.${environment().suffixes.storage}'
    privateEndpointGroupName: 'queue'
  }
  blob : {
    privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpointGroupName: 'blob'
  }
  table : {
    privateDnsZoneName: 'privatelink.table.${environment().suffixes.storage}'
    privateEndpointGroupName: 'table'
  }
  vault : {
    privateDnsZoneName: 'privatelink.vaultcore.azure.net' //Do not use environment.suffix as it give the wrong dns zone.
    privateEndpointGroupName: 'vault'
  }
}

// e.g. privatelink.file.core.windows.net
var privateDnsZoneName = settings[resourceType].privateDnsZoneName
// e.g. file or sqlServer
var privateEndpointGroupName = settings[resourceType].privateEndpointGroupName

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
  scope: resourceGroup(privateDnsSubscriptionId, privateDnsResourceGroup)
}

var privateLinkServiceConnection = {
  name: privateEndpointName
  properties: {
    privateLinkServiceId:  resourceId
    groupIds: [
      privateEndpointGroupName
    ]
  }
}
resource pe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${privateEndpointName}-nic'
    manualPrivateLinkServiceConnections: isExternalResource ? [privateLinkServiceConnection] : []
    privateLinkServiceConnections: !isExternalResource ? [privateLinkServiceConnection] : []
    subnet: {
      #disable-next-line use-resource-id-functions
      id: subnetId
    }
  }

  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: privateDnsZone.name
          properties: {
            privateDnsZoneId: privateDnsZone.id
          }
        }
      ]
    }
  }
}

output privateEndpointId string = pe.id
output privateDnsZoneName string = privateDnsZone.name
```

The above template ensures that the naming convention for the Private Endpoint and NIC are kept consistent. Also, the **sub-resource and private DNS zone** are calculated using the **resourceType** parameter.

The template also handles the private DNS zone integration with the nested **privateDnsZoneGroups** resource. When the Private Endpoint is approved, the host names of the target app service (including Kudu) are resolved and automatically added to the private DNS zone. Should the Private Endpoint be removed, the records are also automatically cleaned up.

One last feature to note is the **isExternalResource** parameter. Under the hood, this controls whether to use **manualPrivateLinkServiceConnections** or **privateLinkServiceConnections**. The former makes use of the **approval** process, whereas the later will attempt an **auto-approval** process.

``` typescript
module peDummy './privateendpoint.bicep' = {
  name: 'peDummy'
  params: {
    privateEndpointName: 'pe-test-dummy'
    resourceId: resourceId(
      'subscriptionId',
      'resourceGroupName',
      'microsoft.web/sites',
      'appServiceName'
    )
    subnetId: resourceId('resourceGroupName', 'Microsoft.Network/virtualNetworks/subnets', 'vnetName', 'subnetName')
    privateDnsResourceGroup: 'rg-dns'
    resourceType: 'sites'
    isExternalResource: true
  }
}
```

Above is an example of using the template to create a **pe-test-dummy** and associated NIC. The targeted resource is an App Services and the relevant private DNS resource is in **rg-dns** is updated with DNS records.

## Wrapping Up