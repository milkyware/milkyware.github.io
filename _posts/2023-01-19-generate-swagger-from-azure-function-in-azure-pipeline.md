---
title: Generate Swagger from Azure Functions in Azure Pipelines
header:
  image: '/images/generate-swagger-from-azure-function-in-azure-pipeline/header.png'
category: DevOps
tags:
  - Azure
  - Azure Function
  - Azure Pipelines
  - DevOps
  - APIM
  - API Management
---

## Generating Swagger from Azure Functions in Azure Pipelines

I've recently started to work more with Azure API Management to create a one-stop shop for my APIs. In the last couple of years, Microsoft has added the **[Microsoft.Azure.WebJobs.Extensions.OpenApi](https://github.com/azure/azure-functions-openapi-extension)** package which takes care of documenting your HTTP Trigger operations and exposing a Swagger endpoint as well as a Swagger UI. This is great for testing locally, however Azure API Management has its own Developer Portal for displaying API definitions.  Azure API Management offers the option to import an API using a Swagger/OpenAPI definition so the challenge is to automate this process in an Azure Pipeline.

![image1](/images/generate-swagger-from-azure-function-in-azure-pipeline/image1.png)

Through this post I'm going to go through not only how to extract the Swagger and import into APIM, but also provide a sample Azure Pipeline template to streamline publishing Azure Functions to APIM. Before getting into the detail, I'd like to acknowledge the massive help of a post from **[Justin Yoo](https://devkimchi.com/2022/02/23/generating-openapi-document-from-azure-functions-within-cicd-pipeline/)** which is the basis of this discussion.

## Azure Pipeline Template

### Complete Example

For those wanting to jump straight to the pipeline template, it can be found below. The remainder of this article will go through what the pipeline does and why.

<!-- {% raw %} -->
``` yaml
parameters:
  - name: projectPath
    displayName: Azure Function project directory path
    type: string
  - name: swaggerEndpoint
    type: string
    default: /swagger.json
  - name: dependsOn
    displayName: Array of stages to depend on, defaults to no dependencies
    type: object
    default: []
  - name: artifactName
    displayName: Name if the artifact to publish
    type: string
    default: swagger

stages:
  - stage: Swagger
    dependsOn: ${{parameters.dependsOn}}
    jobs:
      - job: Job
        variables:
          ASPNETCORE_URLS: https://localhost:7032;http://localhost:5032
          ASPNETCORE_ENVIRONMENT: devops
        steps:
          - task: Bash@3
            displayName: Print environment variables
            inputs:
              targetType: inline
              script: env | sort

          - task: Npm@1
            displayName: Install Azurite
            inputs:
              command: custom
              customCommand: |
                install -g azurite

          - task: Npm@1
            displayName: Install Azure Function Tools
            inputs:
              command: custom
              customCommand: |
                install -g azure-functions-core-tools@4

          - task: PowerShell@2
            name: DownloadSwagger
            displayName: Download Swagger
            inputs:
              pwsh: true
              workingDirectory: ${{parameters.projectPath}}
              targetType: inline
              script: |
                $output = "$(build.artifactstagingdirectory)/swagger.json"
                $swaggerEndpoint = "${{parameters.swaggerEndpoint}}"

                if (-not (Test-Path local.settings.json))
                {
                  Write-Host "Creating default local.settings.json"
                  $json = '{"IsEncrypted": false,"Values": {"AzureWebJobsStorage": "UseDevelopmentStorage=true", "FUNCTIONS_WORKER_RUNTIME": "dotnet"}}'
                  Set-Content -Path local.settings.json -Value $json
                }

                Write-Host "Starting Azurite"
                $azuriteJob = Start-Job -ScriptBlock {azurite}
                
                Write-Host "Starting function host"
                $job = Start-Job -ScriptBlock {func start --port 5000}
            
                Start-Sleep -Seconds 5

                $timeout = 0
                do {
                    [string[]]$jobConsole = $job | Receive-Job -ErrorAction SilentlyContinue

                    if ($jobConsole)
                    {
                      $funcStarted = $jobConsole -match "Host lock lease acquired by instance ID*"
                    }
                    $jobConsole

                    Start-Sleep -Seconds 5
                    $timeout++
                    if ($timeout -gt 20) {
                      throw "Timeout waiting for function to start"
                    }

                } until ($funcStarted)

                Write-Host "Web host started successfully"
                
                Write-Host "Download Swagger"
                $swagger = Invoke-RestMethod -Method Get -Uri "http://localhost:5000$swaggerEndpoint"

                Write-Host "Removing localhost from swagger definition"
                $swagger.PSObject.Properties.Remove("host")

                $compressed = $swagger | ConvertTo-Json -Depth 100 -Compress
                Write-Host "##vso[task.setvariable variable=SwaggerCompressed;isOutput=true;]$compressed"

                $compressedString = $compressed | ConvertTo-Json -Depth 100 -Compress
                $escaped = $compressedString.SubString(1, $compressedString.Length - 2)
                Write-Host "##vso[task.setvariable variable=SwaggerEscaped;isOutput=true;]$escaped"

                Write-Host "Stopping web host"
                $job | Stop-Job
                $job | Remove-Job -Force

                Write-Host "Stopping Azurite"
                $azuriteJob | Stop-Job
                $azuriteJob | Remove-Job -Force
            
                if ($output) {
                    Set-Content -Path $output -Value $compressed
                }
                return $compressed

          - task: PublishBuildArtifacts@1
            displayName: Publish to DevOps
            inputs:
              PathtoPublish: '$(Build.ArtifactStagingDirectory)'
              ArtifactName: ${{parameters.artifactName}}
              publishLocation: Container
```
<!-- {% endraw %} -->

### Installing the Tools

To run an Azure Function the **[Azure Functions Core Tools](https://learn.microsoft.com/en-gb/azure/azure-functions/functions-run-local?WT.mc_id=dotnet-58527-juyoo&tabs=v4%2Cwindows%2Ccsharp%2Cportal%2Cbash)** are required. These are not natively available as part of Azure Pipelines and therefore need installing. This is handled by the **Install Azure Function Tools** step.

``` yaml
- task: Npm@1
  displayName: Install Azure Function Tools
  inputs:
    command: custom
    customCommand: |
      install -g azure-functions-core-tools@4
```

An additional tool I've installed as part of the pipeline is **[Azurite](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=visual-studio)**. This is not required to start a function only using HTTP Triggers, however, if your function makes use of other storage based triggers (such as BlobTrigger and QueueTrigger) this will be needed.

``` yaml
- task: Npm@1
  displayName: Install Azurite
  inputs:
    command: custom
    customCommand: |
      install -g azurite
```

### Starting the function host

The first thing to note is that the pipeline step sets the **workingDirectory** to the Azure Function project directory as the tools below lack the capability to specify a context path.

<!-- {% raw %} -->
``` yaml
- task: PowerShell@2
  name: DownloadSwagger
  displayName: Download Swagger
  inputs:
    pwsh: true
    workingDirectory: ${{parameters.projectPath}}
    targetType: inline
```
<!-- {% endraw %} -->

The first part of the script deals with **local.settings.json**. Typically I try to avoid committing this and often specify it in gitignore to avoid committing passwords and other sensitive config. However, this file is needed by the Azure Function tools to set the function runtime so the script firstly checks if it exists locally, if not it creates a basic copy.

<!-- {% raw %} -->
``` PowerShell
$output = "$(build.artifactstagingdirectory)/swagger.json"
$swaggerEndpoint = "${{parameters.swaggerEndpoint}}"

if (-not (Test-Path local.settings.json))
{
  Write-Host "Creating default local.settings.json"
  $json = '{"IsEncrypted": false,"Values": {"AzureWebJobsStorage": "UseDevelopmentStorage=true", "FUNCTIONS_WORKER_RUNTIME": "dotnet"}}'
  Set-Content -Path local.settings.json -Value $json
}
```
<!-- {% endraw %} -->

Next, Azurite and the Azure Function are started in PowerShell jobs. The reason behind this is I originally used `Start-Process -PassThru` to manage the lifetime of the processes, however this seemed to prevent the pipeline from exiting.

<!-- {% raw %} -->
``` PowerShell
Write-Host "Starting Azurite"
$azuriteJob = Start-Job -ScriptBlock {azurite}

Write-Host "Starting function host"
$job = Start-Job -ScriptBlock {func start --port 5000}
```
<!-- {% endraw %} -->

The next stage monitors the Azure Function process and waits for the Swagger endpoint to be available.

``` Powershell
Start-Sleep -Seconds 5

$timeout = 0
do {
    [string[]]$jobConsole = $job | Receive-Job -ErrorAction SilentlyContinue

    if ($jobConsole)
    {
      $funcStarted = $jobConsole -match "Host lock lease acquired by instance ID*"
    }
    $jobConsole

    Start-Sleep -Seconds 5
    $timeout++
    if ($timeout -gt 20) {
      throw "Timeout waiting for function to start"
    }

} until ($funcStarted)
```

### Download Swagger Definition

The Swagger definition is then downloaded from localhost and manipulated. Due to being downloaded from localhost, there is a **host** property in the definition that, when imported into APIM, sets the **Web Service URL** in the API to localhost which will result in failures when calling the APIM hosted API.

``` PowerShell
Write-Host "Download Swagger"
$swagger = Invoke-RestMethod -Method Get -Uri "http://localhost:5000$swaggerEndpoint"

Write-Host "Removing localhost from swagger definition"
$swagger.PSObject.Properties.Remove("host")
```

The Swagger object is then compressed to a single line as well as escaped, both of these are set as output variables to be used in later stages/jobs/steps in the pipeline.

``` PowerShell
$compressed = $swagger | ConvertTo-Json -Depth 100 -Compress
Write-Host "##vso[task.setvariable variable=SwaggerCompressed;isOutput=true;]$compressed"

$compressedString = $compressed | ConvertTo-Json -Depth 100 -Compress
$escaped = $compressedString.SubString(1, $compressedString.Length - 2)
Write-Host "##vso[task.setvariable variable=SwaggerEscaped;isOutput=true;]$escaped"
```

The end of the script performs a cleanup by terminating the Azurite and Azure Function processes as well as outputting the **compressed** Swagger JSON to be published as a pipeline artifact.

``` Powershell
Write-Host "Stopping web host"
$job | Stop-Job
$job | Remove-Job -Force

Write-Host "Stopping Azurite"
$azuriteJob | Stop-Job
$azuriteJob | Remove-Job -Force

if ($output) {
    Set-Content -Path $output -Value $compressed
}
return $compressed
```

## Publishing to API Management

### Bicep Template

Now that the Swagger is an artifact in the pipeline, it can be deployed in later stages. For consistency, I publish an API to API Management using Bicep. Below is a basic sample of deploying an API **resource** with the swagger definition being passed in as a string parameter.

``` terraform
param swaggerDefinition string

resource apim 'Microsoft.ApiManagement/service@2021-08-01' existing = {
    name: 'apim'

    resource api 'apis' = {
        name: 'azurefunction'
        properties: {
            displayName: 'Azure Function'
            path: 'azurefunction'
            format: 'openapi'
            subscriptionRequired: true
            value: swaggerDefinition
        }
    }
}
```

The format specified is **openapi** and the swaggerDefinition parameter is the **entire Swagger definition, not the link to the Swagger endpoint**. When using the link format (e.g. `openapi-link`), the server deploying the Bicep template needs to be able to reach the Swagger endpoint. If the Azure Function uses VNet integration and the deploying server isn't IP whitelisted, this method will fail. When using Azure-Hosted Pipelines, the public IPs of these are effectively shared amongst all DevOps users and so whitelisting these could be a security risk which is one of the key reason

### Deploying the Bicep

Below is a cut down version of an Azure Pipeline which uses the pipeline template as well as passes the Swagger to the above Bicep to deploy it. In the example below, the **SwaggerEscaped** output variable passes the **entire Swagger definition** to the Bicep template to publish the API to API Management.

<!-- {% raw %} -->
``` yaml
name: $(Date:yy.MM.dd)$(Rev:.rr)

resources:
  repositories:
    - repository: AzurePipelines
      type: git
      name: Azure.Pipelines

stages:
  - template: templates/DownloadAzFuncSwagger.azure-pipelines.yml@AzurePipelines
    parameters:
      projectPath: src/AzureFunctionProj

  - stage: Deploy
    dependsOn:
      - Swagger
    variables:
      swaggerEscaped: $[ stageDependencies.Swagger.Job.outputs['DownloadSwagger.SwaggerEscaped'] ]
    jobs:
      - task: AzureCLI@2
        displayName: Deploy Template
        inputs:
          azureSubscription: azureSubscription
          scriptType: pscore
          scriptLocation: inlineScript
          inlineScript: |
            az deployment group create `
              --resource-group rg-apim `
              --template-file deploy/template.bicep
              --parameters swaggerDefinition=$(swaggerEscaped)
```
<!-- {% endraw %} -->

The resulting pipeline flow will look similar to below with a **Swagger** publishing an artifact being the dependency for the **Deploy** stage.

![image2](/images//generate-swagger-from-azure-function-in-azure-pipeline/image2.png)

## Summary

Through this post we've stepped through the following:

1. How to run an Azure Function in a pipeline to extract the Swagger definition
2. Wrapping the above step in an Azure Pipeline template for reuse
3. Using Bicep to deploy the downloaded Swagger definition to avoid security holes
4. An example pipeline bringing together downloading the Swagger as well as deploying it

By doing the above we can keep track of what is being published through pipeline artifact as well reducing the overhead of deploying and publishing Azure Function APIs.

This is my first post, I hope you've enjoyed my take on this and been of use.
