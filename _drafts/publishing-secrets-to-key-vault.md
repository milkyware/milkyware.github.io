---
title: Publishing Secrets to Key Vault
header:
  image: 'images/publishing-secrets-to-key-vault/header.svg'
category: DevOps
tags:
    - Azure
    - Azure Pipelines
    - DevOps
---

Most applications make use of configuration to allow an application or script to be used in different ways. A common scenario is when an application has a development lifecycle and is deployed to different environments for development, testing and ultimately production. Often, most of the configuration is not sensitive and can be stores as **plain text** alongside the code. However, some, such as credentials and keys, will be sensitive and need to be kept **secret**. Storing these **secrets** as plain text, such as in the code, should be avoided. So the question is, where can we store these secrets?

## The Problem

For this post I'm going to detail one solution for storing application **secrets** as well as how to deploy this config. Before going any further, lets layout the scenario:

1. The source control tool is **Azure DevOps**
2. Deployment pipelines are all written in **YAML (Azure Pipelines)**
3. The code is deployed to **Azure App Services**
4. **Azure Key Vault** is used to store secrets and referenced using **Key Vault references**

As mentioned, **non-sensitive** config is often kept near or alongside the code. I wanted to maintain this idea for the **secrets** to make managing the config more convenient as well as making it easier for other developers to pick and understand both the code and the config.

![image1](/images/publishing-secrets-to-key-vault/image1.svg)

In the past I've tried using a **seed Key Vault** where a central Key Vault is created either per app or collection of apps and a pipeline used to retrieve the secrets and publish them to the appropriate environment. However, this didn't keep the secrets near the rest of the config or the code and involved deploying and maintaining additional infrastructure. With the secrets also being help outside of Azure DevOps, the maintenance involved managing a separate access control model.

## DevOps variable groups

![image2](/images/publishing-secrets-to-key-vault/image2.png)

Azure DevOps offers a feature called **[variable groups](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml)** which allows for configuring blocks of variables which are then referenced in pipelines. Variable groups also offers the ability for particular variables to be marked as **secret** using the **padlock** which will hide the value of the variable once the group is saved and exited.

![image3](/images/publishing-secrets-to-key-vault/image3.png)

The group can also make use of the same access control model used across DevOps to allow users and groups to **read, use and administrate** the variables. There is also the ability to set if pipelines accessing the group need **approval** to read the variables and other checks.

### Pipeline Template

To help with publishing variables in a group to **Key Vault**, I've put together the below pipeline template:

<!-- {% raw %} -->
``` yaml
parameters:
  - name: environment
    displayName: The name of the DevOps environment to associate the deployment to
    type: string
  - name: azureSubscription
    displayName: The DevOps service connection to use for writing secrets to the key vault
    type: string
  - name: variableGroupName
    displayName: The name of the Azure DevOps variable group
    type: string
  - name: keyVaultName
    displayName: Name of the key vault to create secrets in
    type: string
  - name: secretNames
    displayName: An array of variables in the variable group to deploy as secrets to the key vault
    type: object
  - name: deploymentName
    displayName: Name of the deployment job, A-Z, a-z, 0-9, and underscore. Defaults to DeployTemplate
    type: string
    default: DeploySecrets

jobs:
  - deployment: ${{parameters.deploymentName}}
    environment: ${{parameters.environment}}
    variables:
      - group: ${{parameters.variableGroupName}}
    strategy:
      runOnce:
        deploy:
          steps:
            - task: Bash@3
              displayName: Print environment variables
              inputs:
                targetType: inline
                script: env | sort

            - ${{each sn in parameters.secretNames}}:
              - task: AzureCLI@2
                displayName: Deploying ${{sn}}
                inputs:
                  azureSubscription: ${{parameters.azureSubscription}}
                  scriptType: pscore
                  scriptLocation: inlineScript
                  inlineScript: |
                    $secretName = "${{sn}}".ToLower() -replace "[^0-9a-zA-Z-]+"
                    Write-Host "Setting secret $secretName in ${{parameters.keyVaultName}}"

                    $secretValue = $env:secretValue
                    az keyvault secret set --vault-name ${{parameters.keyVaultName}} --name $secretName --value $secretValue | Out-Null
                env:
                  secretValue: $(${{sn}})

```
<!-- {% endraw %} -->

Variables in Azure Pipelines are loaded as **environment variables** in the agent running the job, variable groups simply load sets of variables into the environment. This is achieved by referencing the group using the **variableGroupName** parameter.

The **array of secret names** is then looped over using the **[each keyword](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/expressions?view=azure-devops#each-keyword)** to run the ***Deploying*** step for each secret specified.

Secret variables are not only hidden in the **variable group UI** but also handled differently in Azure Pipelines, they aren't automatically loaded into the environment context so that the values aren't leaked. To deal with this the **env** property of the task is used to set an environment variable called **secretValue** using `$(${{sn}})`. This variable makes use of both **[compile time](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/runs?view=azure-devops#process-the-pipeline)** and **[run time](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/runs?view=azure-devops#run-each-step)** expressions.

1. Firstly, `${{sn}}` is resolved to an item in the **secretNames** parameter array. e.g. providing a secretNames array of ['password'] would resolve `$(${{sn}})` to `$(password)`
2. Secondly, the runtime expression is then resolved. Following the example, `$(password)` would then look for an Azure Pipeline variable with the name **password**. If the variable group has loaded in a variable with that name, the value will then be resolved set for the **secretValue** environment variable
3. The **secretValue** environment variable can then be access in PowerShell using `$env:secretValue`
4. If the pipeline cannot find a value for the variable, the Key Vault secret value will look like `$(ValueFound)` as the run time expression won't resolve and will be used verbatim.

### Refreshing the Key Vault references

Once the secrets from the variable group have been published to the Key Vault, the values can be referenced using **[Key Vault references](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references?tabs=azure-cli)**. One issue that can arise is that the references in App Services are **[cached](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references?tabs=azure-cli#rotation)** meaning that, when secrets are updated, they aren't immediately reflected. To *force* an update, a configuration update is required. To achieve this I've created a second template which updates a **_DUMMY_TIMESTAMP** config setting with a timestamp

<!-- {% raw %} -->
``` yaml
parameters:
  - name: environment
    displayName: The name of the DevOps environment to associate the deployment to
    type: string
  - name: azureSubscription
    displayName: The DevOps service connection to use for writing secrets to the key vault
    type: string
  - name: appServiceName
    displayName: Name of the app service resource to update key vault references for
    type: string
  - name: resourceGroupName
    displayName: Name of the resource group containing the app service
    type: string
  - name: deploymentName
    displayName: Name of the deployment job, A-Z, a-z, 0-9, and underscore. Defaults to DeployTemplate
    type: string
    default: RefreshKVReferences
  - name: dependsOn
    displayName: Array of stages to depend on, defaults to no dependencies
    type: object
    default: []

jobs:
  - deployment: ${{parameters.deploymentName}}
    dependsOn: ${{parameters.dependsOn}}
    environment: ${{parameters.environment}}
    strategy:
      runOnce:
        deploy:
          steps:
            - task: Bash@3
              displayName: Print environment variables
              inputs:
                targetType: inline
                script: env | sort

            - task: AzureCLI@2
              displayName: Refresh ${{parameters.appServiceName}} KV References
              inputs:
                azureSubscription: ${{parameters.azureSubscription}}
                scriptType: pscore
                scriptLocation: inlineScript
                inlineScript: |
                  az webapp config appsettings set `
                    --name ${{parameters.appServiceName}} `
                    --resource-group ${{parameters.resourceGroupName}} `
                    --settings _DUMMY_TIMESTAMP=$([datetime]::UtcNow.ToString("s"))
```
<!-- {% endraw %} -->

Combining the two templates together then looks like below. This pipeline will then take care of creating/updating the secrets in the specified Key Vault using the variable group as well as refresh the Key Vault references in the App Service.

``` yaml
jobs:
  - template: templates/PublishVariableGroupToKeyVault.azure-pipelines.yml
      parameters:
        azureSubscription: serviceConnection
        variableGroupName: variableGroupName
        keyVaultName: keyVaultResourceName
        secretNames:
          - variable1
          - variable2

  - template: templates/RefreshAppSettingsKVReferences.azure-pipelines.yml
        parameters:
          environment: Env
          azureSubscription: serviceConnection
          appServiceName: appServiceResourceName
          resourceGroupName: appServiceResourceGroup
          dependsOn:
            - DeploySecrets
```

## Summary

In this post we've looked at using variable groups to store and seed our secrets to address the following:

- [x] Sensitive and non-sensitive config can be kept close together in Azure DevOps
- [x] Use Azure DevOps as a unified access control to access code, pipelines and secrets
- [x] Refresh Key Vault references as part of the secret deployment pipeline
