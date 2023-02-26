---
header:
  image: '/images/deploying-azure-resources-using-bicep/header.png'
category: Azure
tags:
    - Bicep
    - ARM
---

# Deploying Azure Resources Using Bicep

Over the past couple of years I've been primarily developing and deploying applications to Azure. Typically these deployments comprise of 2 broad aspects:

1. Deploying code
2. Deploying infrastructure

For this post we're going to focus on the infrastructure side using **[Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)** to define our **Infrastructure as Code (IaC)** to deploy resources to Azure. To do this we'll firstly introduce what Bicep is and its benefits. We'll then look at a how to test our IaC and then how to deploy the tested template to an environment.

## What is Bicep?

Bicep is a **[Domain-Specific Language (DSL)](https://www.martinfowler.com/dsl.html#:~:text=A%20Domain%2DSpecific%20Language%20(DSL,as%20computing%20has%20been%20done.))** with a declarative syntax which builds upon the foundation of the existing **[Azure Resource Manager (ARM) templates](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/overview)** which is used to develop and automate the deployment of Azure resources. Both Bicep and ARM templates help with creating consistent and repeatable deployments of resources across different environment as well as forming part of your documentation. However, there are a number of benefits of using Bicep over ARM.

### Benefits of Bicep

Below are some of the main benefits of using Bicep over ARM templates.

#### Simplified Syntax

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

The template makes use of parameters to control the **location** and **tags** of the account as well as using the functions **replace, resourceGroup and contains** in variables to build a name for the storage account which adheres to a convention. The below example is the equivalent JSON ARM template generated using the **[AZ Bicep](https://learn.microsoft.com/en-us/cli/azure/bicep?view=azure-cli-latest)** cli tool with the command `az bicep build --file .\storageaccount.bicep`.

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

#### VS Code Extension

Microsoft provide a VS Code extension which greatly improves the development experience of Bicep templates over that of ARM templates. The VS Code language server provides intellisense for Bicep which will highlight syntax and typing issues as well as suggesting property and parameters for many of the features of Bicep including: **resources**, **variables** and **modules (I'll cover mode on modules in the next post)**.

![image1](/images/deploying-azure-resources-using-bicep/image1.png)

#### Idempotency

Idempotency in software engineering is defined as doing the same thing with the same parameters or inputs produces the same result. Idempotency is baked into Bicep which means that deploying a template multiple times will produce the same results.

#### Orchestration

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

In Bicep the orchestration is handled for you (in the vast majority of cases). The below samples shows the various ways in which we can define dependency in Bicep.

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
- **Container3** uses an output property of storage account to define dependency
- Lastly **container4** uses the explicit dependsOn syntax to define dependency

One thing to note is that, unlike in ARM, no messy **resourceId** functions are used and instead dependency is implied or definied by passing around resource objects.

## Testing Bicep

As with all code, it is important to test your Bicep templates to build confidence in deployments, ensure coding best practises and identify regressions quickly.

### ARM Template Toolkit (ARM-TTK)

The **[ARM Template Toolkit](https://github.com/Azure/arm-ttk)** is a **Powershell module** that was originally developed to ensure coding best practices when developing ARM templates and has since been bundled into Bicep. When the **[VS Code Bicep extension](#vs-code-extension)** is installed, it'll display warnings and errors in accordance with the rules in the toolkit.

![image2](/images/deploying-azure-resources-using-bicep/image2.png)

However, these tests can also be carried out as part of a build CI pipeline. For the past couple of years I've been using an Azure DevOps extension called **[]Run ARM TTK Tests](https://marketplace.visualstudio.com/items?itemName=Sam-Cogan.ARMTTKExtensionXPlatform)** which can take a Bicep template and return **NUnit** test results which can be published to Azure DevOps. The below is a sample Azure Pipeline:

``` yaml
steps:
  - task: Bash@3
    displayName: Print environment variables
    inputs:
      targetType: inline
      script: env | sort

  - task: RunARMTTKTestsXPlat@1
    displayName: Scan Bicep
    condition: succeeded()
    inputs:
      templatelocation: src/storageaccount.bicep
      resultLocation: '$(Agent.TempDirectory)/results/'
      allTemplatesMain: false
      cliOutputResults: true
      ignoreExitCode: true
      usePSCore: true

  - task: PublishTestResults@2
    displayName: Publish Scan Results
    condition: always()
    inputs:
      testResultsFormat: "NUnit"
      testResultsFiles: $(Agent.TempDirectory)/results/*-armttk.xml
```

The resulting pipeline run and tests are below:

![image3](/images/deploying-azure-resources-using-bicep/image3.png)

Although this example focuses on using Azure Pipelines, Microsoft do make the **[GitHub Action Run ARM-TTK](https://github.com/marketplace/actions/run-arm-ttk-with-reviewdog)** available to achieve the same functionality as what's been demonstrated. If you are unable to use either the Azure DevOps extension or the GitHub action, the PowerShell module can be downloaded and imported as part of a custom pipeline/workflow to perform the tests.

### Pull-Request Environments

## Deploying Bicep

Microsoft provide several methods to programmatically deploy Azure resources:

- VS Code
- Az Cli
- Az Powershell module
- Azure Cloud Shell

To demonstrate deploying Bicep I'm going to use Az Cli. The process of deploying an Azure template, either Bicep or ARM, is relatively straight forward. Microsoft provide the `az deployment group create` command in Az Cli which can be used like below:

``` powershell
az deployment group create `
  --name $deploymentName `
  --resource-group rg-sample-group `
  --template-file src/template.bicep
```

This will then create a deployment job in the specified resource group which contains the status of deploying each resource in the deployment template.

![image4](/images/deploying-azure-resources-using-bicep/image4.png)

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

In this step, notice that it makes use of some PowerShell to generate the deployment name from the file name with a timestamp so that deployments are uniquely named so that subsequent deployments of the same template don't overwrite the same deployment job log. This step can be be reused in multiple stages to progress the deployment of the Bicep through different environments.

### What-If Deployment

Before running the actual deployment, I like to make use of a **[what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-what-if)** deployment to firstly test all of the permissions are in place to deploy the template to the given environment as well as to summarise what changes the template will make. The command for this is `az deployment group what-if`.

``` powershell
az deployment group what-if `
  --name $deploymentName `
  --resource-group rg-sample-group `
  --template-file src/template.bicep
```

![image5](/images/deploying-azure-resources-using-bicep/image5.png)

Above is the pretty print version output of the command, however, it can also be formatted as **JSON objects** to be evaluated by a script for later use in a pipeline. To do this, add the `--no-pretty-print` argument to the command

``` json
{
  "changes": [
    {
      "after": null,
      "before": null,
      "changeType": "Create",
      "delta": null,
      "resourceId": "/subscriptions/subscriptionId/resourceGroups/rg-test-group/providers/Microsoft.Storage/storageAccounts/sttestgroup",
      "unsupportedReason": null
    }
  ],
  "error": null,
  "status": "Succeeded"
}
```

As mentioned, this functionality can then be included as a step in a pipeline to highlight any issues or unexpected results before the actual deployment takes please. Evaluating the changes from the **what-if** could then be used to potentially fail a pipeline or raise an approval gate if the changes involve a delete action.

``` yaml
- task: AzureCLI@2
  displayName: What If Template
  inputs:
    azureSubscription: azureSubscription
    scriptType: pscore
    scriptLocation: inlineScript
    inlineScript: |
      az deployment group what-if `
        --resource-group rg-sample-group `
        --template-file src/storageaccount.bicep
```

## Summary
