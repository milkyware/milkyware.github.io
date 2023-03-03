---
title: Testing Azure Resource Templates
header:
  image: 'images/testing-azure-resource-templates/header.png'
category: Azure
tags:
    - Bicep
    - ARM
    - Azure
    - Testing
---

In the **[previous post](/azure/introduction-to-azure-bicep)** we introduced Bicep, it's benefits and how to deploy a template to a Azure (specifically a resource group). In this post we're going to build on this and introduce testing to developing **IaC** templates.

## Why test your Bicep?

As with all code, it is important to test Bicep templates for many reasons:

- Highlight bugs and regressions early on
- Ensure best practices are adhered to
- Improve security compliance

Where possible, it is also useful to automate these tests so that the results can be communicated to developers quicker as well incorporated into **deployment pipelines** and **pull-request** processes to allow developers to focus on development instead of manually testing. There are several styles of testing designed to address the reasons above.

![image1](/images/testing-azure-resource-templates/image1.png)

Below is a couple of methods of testing Bicep templates I have used.

## Methods of Testing

### ARM Template Toolkit (ARM-TTK)

The **[ARM Template Toolkit](https://github.com/Azure/arm-ttk)** is a **Powershell module** that was originally developed to ensure coding best practices when developing ARM templates and has since been bundled into Bicep. When the **[VS Code Bicep extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)** is installed, it'll display warnings and errors in accordance with the rules in the toolkit.

![image2](/images/testing-azure-resource-templates/image2.png)

However, these tests can also be carried out as part of a build CI pipeline. For the past couple of years I've been using an Azure DevOps extension called **[Run ARM-TTK Tests](https://marketplace.visualstudio.com/items?itemName=Sam-Cogan.ARMTTKExtensionXPlatform)** to evaluate a Bicep template against the **ARM-TTK policies**. The below is a sample Azure Pipeline:

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

![image3](/images/testing-azure-resource-templates/image3.png)

Notice in the pipeline task **RunARMTTKTestsXPlat@1** the parameter **resultLocation** and the following task **PublishTestResults@2**. The **ARM-TTK** DevOps extension produces **NUunit** test results for the Bicep template which can then be published to Azure DevOps to easily identify which policies are failing as well as monitor code coverage.

![image4](/images/testing-azure-resource-templates/image4.png)

Although this example focuses on automation using Azure Pipelines, Microsoft do make the **[GitHub Action Run ARM-TTK](https://github.com/marketplace/actions/run-arm-ttk-with-reviewdog)** available to achieve the same functionality as what's been demonstrated. If you are unable to use either the Azure DevOps extension or the GitHub action, the PowerShell module can be downloaded and imported as part of a custom pipeline/workflow to perform the tests.

### What-If Deployments

In the first post we looked at creating deployments using `az deployment resource create`. **Az Cli** offers another command in the same group called **[what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-what-if)**. Typically, I use this command before running an actual deployment to firstly test all of the permissions are in place to deploy the template to the given environment as well as to summarise what changes the template will make. The command testing a resource group deployment is `az deployment group what-if`.

``` powershell
az deployment group what-if `
  --name $deploymentName `
  --resource-group rg-sample-group `
  --template-file src/template.bicep
```

![image5](/images/introduction-to-azure-bicep/image5.png)

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

To incorporate this **what-if** testing as standard practise in pipelines, a **pipeline template** could be created to wrap around the `az deployment scope what-if` and `az deployment scope create` commands:

<!-- {% raw %} -->
``` yaml
parameters:
  - name: environment
    type: string
  - name: azureSubscription
    type: string
  - name: resourceGroupName
    type: string
  - name: templatePath
    type: string

jobs: 
  - deployment: DeployTemplate
    displayName: Deploy Template
    environment: ${{parameters.environment}}
    strategy:
      runOnce:
        deploy:
          steps:
            - task: AzureCLI@2
              displayName: What If Template
              inputs:
                azureSubscription: ${{parameters.azureSubscription}}
                scriptType: pscore
                scriptLocation: inlineScript
                inlineScript: |
                  write-host $parameters
                  az deployment group what-if `
                    --resource-group ${{parameters.resourceGroupName}} `
                    --template-file ${{parameters.templatePath}}

            - task: AzureCLI@2
              displayName: Deploy Template
              inputs:
                azureSubscription: ${{parameters.azureSubscription}}
                scriptType: pscore
                scriptLocation: inlineScript
                inlineScript: |
                  $templateName = [System.IO.FileInfo]::new("${{parameters.templatePath}}").BaseName.ToLower()
                  $deploymentName = "$templateName-$([datetime]::UtcNow.ToString("yyMMddhhmmssfff"))"
                  az deployment group create `
                    --name $deploymentName `
                    --resource-group ${{parameters.resourceGroupName}} `
                    --template-file ${{parameters.templatePath}}
```
<!-- {% endraw %} -->

### Pull-Request Environments

In my research for this post I came across a few discussions of developers suggesting a throw away ***Pull-Request environment*** to perform a dry run of the new/changed template before being accepted into the **main branch**. Before going any further, I'd like to acknowledge a **[fantastic post](https://samlearnsazure.blog/2021/09/27/dynamic-pr-environments-in-github/)** 

## Summary
