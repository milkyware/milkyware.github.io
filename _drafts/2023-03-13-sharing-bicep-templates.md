---
title: Sharing Bicep Templates
header:
  image: 'images/sharing-bicep-templates/header.png'
category: Azure
tags:
    - Bicep
    - Bicep Modules
    - ARM
    - Azure
---

This is the third in a short series of posts focused on **Azure Bicep**. In the first we **[introduced Bicep](/azure/introduction-to-azure-bicep)** by highlighting some of it's benefits as well as how to deploy templates. The second looked into how we can **[test resource templates](/azure/testing-azure-resource-templates)** along with how to automate the testing techniques. In this post we're going to look **into sharing and reusing Bicep templates**.

## What is a Bicep module?

**[Bicep modules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules)** are effectively Bicep templates **called by another Bicep template**. This is one of the benefits of Bicep, creating modules to break large templates into smaller blocks to improve readability and reusability. Below is a basic example of creating a storage account in Bicep:

``` typescript
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
    name: 'sttest'
    location: 'uksouth'
    kind: 'StorageV2'
    identity: {
        type: 'SystemAssigned'
    }
    sku: {
        name: 'Premium_LRS'
    }
}

output storageAccountName string = storageAccount.name 
```

This template can then be referenced from another file using the `module` syntax:

``` typescript
module storageAccountSymbolicName 'storageaccount.bicep' = {
    name: 'storageAccountStaticName'
}
```

There's a few details to take note of here

- **storageAccountSymbolicName** - This represents the module as an object. This could be used to add explicit dependency on the module for another resource using the syntax `dependsOn: [storageAccountSymbolicName]`. Another usage could be to access **outputs** of the module. To retrieve the **storageAccountName** output of the example module, the syntax would be `storageAccount.outputs.storageAccountName`
- **storageaccount.bicep** - This is the **relative file path** to the module
- **storageAccountStaticName** - When a module is called in a Bicep template, it creates its own deployment instance in Azure. Deploying the above examples would result in something similar to below. Notice **storageAccountStaticName** is the name of the deployment. Keep in mind that if a static name is used more than once, it can cause conflicts.

![image1](/images/sharing-bicep-templates/image1.png)

When resource templates are deployed, they're deployed in a **scope**. Generally speaking the scope is a **resource group** (but could be a subscription or management group). As modules create their own deployments, they also get **their own scope**. The same module can be deployed like below to create a storage account in a separate resource group.

``` typescript
module storageAccount 'storageAccountModule.bicep' = {
    name: 'storageAccountStaticName'
    scope: resourceGroup('anotherResourceGroup')
}
```

I have often used this for deploying **RBAC role assignments** for granting a managed identity in one resource group access to a shared resource in a separate group.

### Parametrising modules

Where Bicep modules really start to gain in value is when they are parametrised. **[All Bicep templates can be parametrised](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters)** and when a parametrised template is called as a module, the parameters are passed in using the `params` syntax. To demonstrate this, I've added parameters to the storage account sample module.

``` typescript
param name string
@allowed(['test', 'live'])
param environment string = 'test'
param location string = resourceGroup().location
param tags object = contains(resourceGroup(), 'tags') ? resourceGroup().tags : {}

var sku = {
    test: 'Standard_LRS'
    live: 'Premium_RAGRS'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
    name: name
    location: location
    tags: tags
    kind: 'StorageV2'
    identity: {
        type: 'SystemAssigned'
    }
    sku: {
        name: sku[environment]
    }
}

output storageAccountName string = storageAccount.name
```

The mandatory **name** parameter can then be passed in like below.

``` typescript
module storageAccount 'storageAccountModule.bicep' = {
    name: 'storageAccount'
    params: {
        name: 'sttest'
    }
}
```

This allows each use of the storage account module to create a resource with a different name. Notice as well that **location, tags and environment** are also parameters with default values. This allows modules to be designed to adhere to conventions by default, but also gives flexibility for the developer to deviate from the defaults where necessary. In the example, **location** defaults to the location of the current resource group, **tags** use the tags of the current resource group and **environment** defaults to a cheaper sku but allows for a more expensive, resilient sku for live scenarios.

## Referencing module files

## Bicep Registry

## Summary
