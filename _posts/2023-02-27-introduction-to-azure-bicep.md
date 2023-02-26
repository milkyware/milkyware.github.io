---
title: Introduction to Azure Bicep
header:
  image: '/images/introduction-to-azure-bicep/header.png'
category: Azure
tags:
    - Bicep
    - ARM
---

Over the past couple of years, I've been primarily developing and deploying applications to Azure. Typically these deployments comprise 2 broad aspects:

1. Deploying code
2. Deploying infrastructure

This post will be the first in a short series where we're going to focus on the infrastructure side using **[Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)** to define our **Infrastructure as Code (IaC)** in Azure. In this post, I'll introduce what Bicep is and its benefits. We'll then look at how to deploy a template to an environment. In the following posts, we'll dig into how to test infrastructure templates as well as how to modularise templates to improve readability as well for reuse.

## What is Bicep?

Bicep is a **[Domain-Specific Language (DSL)](https://www.martinfowler.com/dsl.html#:~:text=A%20Domain%2DSpecific%20Language%20(DSL,as%20computing%20has%20been%20done.))** with a declarative syntax which builds upon the foundation of the existing **[Azure Resource Manager (ARM) templates](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/overview)** which is used to develop and automate the deployment of Azure resources. Both Bicep and ARM templates help with creating consistent and repeatable deployments of resources across different environments as well as forming part of your documentation. However, there are many benefits of using Bicep over ARM.

## Benefits of Bicep

There are many benefits to using Bicep over traditional JSON ARM templates. Below are some of the key benefits. This isn't an exhaustive list but Microsoft provides their own documentation on **[benefits of Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep#benefits-of-bicep)**.

### Simplified Syntax

Bicep is a lot more concise than the equivalent JSON ARM template. For example, the below Bicep is a basic template to deploy a **Storage Account** to Azure.

``` typescript
param location string = resourceGroup().location
param tags object = contains(resourceGroup(), 'tags') ? resourceGroup().tags : {}

var baseResourceName = replace(resourceGroup().name, 'rg-', '')
var baseResourceNameAlpha = replace(baseResourceName, '-', '')

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
    name: 'st${baseResourceNameAlpha}'
    location: location
    tags: tags
    identity: {
        type: 'SystemAssigned'
    }
    sku: {
        name: 'Premium_LRS'
    }
}
```

The template makes use of parameters to control the **location** and **tags** of the account as well as using the functions **replace, resourceGroup and contains** in variables to build a name for the storage account which adheres to a convention. The below example is the equivalent JSON ARM template generated using the **[AZ Bicep](https://learn.microsoft.com/en-us/cli/azure/bicep?view=azure-cli-latest)** CLI tool with the command `az bicep build --file .\storageaccount.bicep`.

``` json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "bicep",
      "version": "0.14.85.62628",
      "templateHash": "1986767459097307481"
    }
  },
  "parameters": {
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    },
    "tags": {
      "type": "object",
      "defaultValue": "[if(contains(resourceGroup(), 'tags'), resourceGroup().tags, createObject())]"
    }
  },
  "variables": {
    "baseResourceName": "[replace(resourceGroup().name, 'rg-', '')]",
    "baseResourceNameAlpha": "[replace(variables('baseResourceName'), '-', '')]"
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2022-09-01",
      "name": "[format('st{0}', variables('baseResourceNameAlpha'))]",
      "location": "[parameters('location')]",
      "tags": "[parameters('tags')]",
      "identity": {
        "type": "SystemAssigned"
      },
      "sku": {
        "name": "Premium_LRS"
      }
    }
  ]
}
```

As you can see this is over twice the size and when scaled up for multiple resources in a template the file can quickly become difficult to navigate and maintain.

### VS Code Extension

Microsoft provides a **[VS Code extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)** which greatly improves the development experience of Bicep templates over that of ARM templates. The VS Code language server provides intellisense for Bicep which will highlight syntax and typing issues as well as suggest properties and parameters for many of the features of Bicep including **resources**, **variables** and **modules (I'll cover more on modules in a separate post)**.

![image1](/images/introduction-to-azure-bicep/image1.png)

The intellisense also takes into consideration the different schema versions of Azure resources. Below is a pair of screenshots to show how the intellisense changes for a storage account resource between versions 2015-05-01 and 2022-09-01.

![image2](/images/introduction-to-azure-bicep/image2.png)
![image3](/images/introduction-to-azure-bicep/image3.png)

One thing to note, although the VS Code extension does do a great job at being up-to-date, I have stumbled across a few examples where the intellisense documentation is out-of-date and results in warnings/errors being highlighted in your Bicep, particularly for very new Azure resources. If you encounter any of these, have a look at the **[Bicep GitHub issues](https://github.com/Azure/bicep/issues)** area. One example of this **logic app standard connection access policies**.

![image4](/images/introduction-to-azure-bicep/image4.png)

The warnings can be hidden by adding `#disable-next-line BCP081` to the line above.

### Idempotency

Idempotency in software engineering is defined as doing the same thing with the same parameters or inputs produces the same result. Idempotency is baked into Bicep which gives us the ability to develop a **template** of our infrastructure in almost a *desired-state* style so that properties of a resource can be restored to what's defined in the template, if there are no changes, no changes will be deployed. This ultimately allows CI pipelines to be used for deploying **IaC** so that developers can get much quicker feedback on if their templates work or not.

### Orchestration and Dependency

In ARM templates, it was generally the responsibility of the developer to ensure that resources were deployed in the correct order to deploy the resources successfully. Extending the sample in **[simplified syntax](#simplified-syntax)**, the below JSON could be added to deploy a **blob container** called **container1** which will tell the Azure Resource Manager to wait for the storage account to finish deploying before creating the container.

``` json
{
  "type": "Microsoft.Storage/storageAccounts/blobServices/containers",
  "apiVersion": "2022-09-01",
  "name": "[format('{0}/{1}/{2}', variables('storageAccountName'), 'default', 'container1')]",
  "dependsOn": [
    "[resourceId('Microsoft.Storage/storageAccounts/blobServices', variables('storageAccountName'))]"
  ]
}
```

In Bicep the orchestration is handled for you (in the vast majority of cases). The below samples show the various ways in which we can define dependency in Bicep.

``` typescript
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
    name: storageAccountName
    location: location
    tags: tags
    kind: 'BlobStorage'
    identity: {
        type: 'SystemAssigned'
    }
    sku: {
        name: 'Premium_LRS'
    }
    properties: {

    }

    resource storageAccountBlob 'blobServices' = {
        name: 'default'

        resource storageAccountContainer 'containers' = {
            name: 'container1'
        }
    }
}

resource storageAccountContainer2 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
    name: 'container2'
    parent: storageAccount::storageAccountBlob
}

resource storageAccountContainer3 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
    name: '${storageAccount.name}/default/container3'
}

resource storageAccountContainer4 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
    name: '${storageAccountName}/default/container4'
    dependsOn: [
        storageAccount
    ]
}
```

- **Container1** makes use of the implied parent syntax by nesting resources within each other
- **Container2** explicitly defines the parent as being the default blob services resource
- **Container3** uses an output property of the storage account to define dependency
- Lastly **container4** uses the explicit dependsOn syntax to define dependency

One thing to note is that, unlike in ARM, no messy **resourceId** functions are used and instead dependency is implied or defined by passing around resource objects.

### Modular Templates and What-If Deployments

I'll cover these two features in subsequent posts.

## Deploying Bicep

Microsoft provides several methods to programmatically deploy Azure resources:

- VS Code
- Az CLI
- Az Powershell module
- Azure Cloud Shell

To demonstrate deploying Bicep I'm going to use Az Cli. The process of deploying an Azure template, either Bicep or ARM, is relatively straightforward. Microsoft provide the `az deployment create` and `az deployment scope create` commands in Az Cli which can be used like below:

``` powershell
az deployment group create `
  --name $deploymentName `
  --resource-group rg-sample-group `
  --template-file src/template.bicep
```

This will then create a deployment job in the specified resource group which contains the status of deploying each resource in the deployment template.

![image5](/images/introduction-to-azure-bicep/image5.png)

This process can then be incorporated into a pipeline:

``` yaml
- task: AzureCLI@2
    displayName: Deploy Template
    inputs:
      azureSubscription: azureSubscription
      scriptType: pscore
      scriptLocation: inlineScript
      inlineScript: |
        $templateName = [System.IO.FileInfo]::new("${{parameters.templatePath}}").BaseName.ToLower()
        $deploymentName = "$templateName-$([datetime]::UtcNow.ToString("yyMMddhhmmssfff"))"
        az deployment group create `
          --name $deploymentName `
          --resource-group rg-sample-group `
          --template-file src/storageaccount.bicep
```

In this step, notice that it makes use of some PowerShell to generate the deployment name from the file name with a timestamp so that deployments are uniquely named so that subsequent deployments of the same template don't overwrite the same deployment job log. This step can be reused in multiple stages to progress the deployment of the Bicep through different environments.

## Summary

In summary, we've looked at what Bicep is and how it can improve the development of Azure infrastructure by making it easier to understand what as resource can do using intellisense as well being easier to read and maintain. We've also briefly looked at how we can deploy bicep templates to Azure both manually and as part of an automated pipeline. In the next post we'll discuss various ways to test Bicep templates to ensure best practises as well as highlighting potential issues and regressions early on.
