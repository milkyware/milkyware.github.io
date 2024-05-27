---
title: Allow Temp Access to Azure SQL from Microsoft-Hosted Agents
category: DevOps
tags:
  - Azure
  - Azure DevOps
  - Azure Pipelines
  - Azure SQL
  - Microsoft-Hosted Agents
  - Pipeline Template
---

Currently, I use Microsoft-hosted pipeline agents to handle my deployments due to their simplicity and minimal maintenance overhead. I've recently needed to start running SQL scripts against Azure SQL instances from these pipelines. However, the connection from the pipeline agent was timing out and failing. So what is the problem?

``` powershell
Invoke-SqlCmd : Connection Timeout Expired.  The timeout period elapsed during the post-login phase.  The connection could have timed out while waiting for the server to complete the login process and respond; Or it could have timed out while attempting to create multiple active connections.  The duration spent while attempting to connect to this server was - [Pre-Login] initialization=49; handshake=43; [Login] initialization=1; authentication=3; [Post-Login] complete=14012; 
At /home/vsts/work/_temp/azureclitaskscript1715466301814_inlinescript.ps1:18 char:1
+ Invoke-SqlCmd -ServerInstance $sqlServerInstance `
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
+ CategoryInfo          : InvalidOperation: (:) [Invoke-Sqlcmd], SqlException
+ FullyQualifiedErrorId : SqlExceptionError,Microsoft.SqlServer.Management.PowerShell.GetScriptCommand
```

## The Problem

In short, the issue is that **[by default Azure SQL has public access disabled](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml#networking)** which blocks connections from Microsoft-hosted agents accessing over the public internet. So how can SQL be executed from an Azure Pipeline against Azure SQL?

From a security standpoint, using **self-hosted or [VM scale-set](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) agents** would resolve this by being part of the private Azure network. However, they take time to provision and require additional maintenance to retain an **[equivalent toolset](https://github.com/actions/runner-images)** to the Microsoft-hosted agents. The quickest option is to automate allowing Microsoft-hosted agents temporary access.

## Allowing Access from Microsoft-Hosted Agents

The networking for Microsoft-hosted agents is changeable in that the **[public IP addresses vary over time](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml#networking)**. There is also an added complication that the public IPs are shared with **all Microsoft-hosted agent users** and therefore any access given to an agent should be for as limited duration as possible.

### Granting the temp access

To automate allowing temporary access from the agent, I developed the below Az Cli task.

``` yaml
- task: AzureCLI@2
  name: AllowPipelineIP
  displayName: Allow Pipeline IP
  inputs:
    azureSubscription: ${{parameters.azureSubscription}}
    scriptType: pscore
    scriptLocation: inlineScript
    inlineScript: |
      $sqlServer = az sql server show -g "${{parameters.resourceGroupName}}" -n "${{parameters.sqlServerName}}" | ConvertFrom-Json
      $tempPublicAccess = $sqlServer.publicNetworkAccess -ieq "Disabled"
      Write-Host "##vso[task.setvariable variable=TempPublicAccess]$tempPublicAccess"

      if ($tempPublicAccess)
      {
        az sql server update -g "${{parameters.resourceGroupName}}" -n "${{parameters.sqlServerName}}" --set publicNetworkAccess="Enabled" | Out-Null
      }

      $ip = Invoke-RestMethod -Uri "https://ifconfig.me"
      Write-Host "##vso[task.setvariable variable=IP]$ip"

      az sql server firewall-rule create -g "${{parameters.resourceGroupName}}" -s "${{parameters.sqlServerName}}" -n $ip --start-ip-address $ip --end-ip-address $ip | Out-Null
```

The script firstly assesses whether **public access** has already been enabled for the Azure SQL Server instance. If not already enabled, it is enabled and a **pipeline variable** used to persist this flag for later use. To resolve the public IP I've used **ifconfig.me** and then created a firewall rule to allow the agent access.

### Removing the temp access

To remove the access the inverse steps are run in reverse.

``` yaml
- task: AzureCLI@2
  name: RemovePipelineIP
  displayName: Remove Pipeline IP
  condition: succeededOrFailed()
  inputs:
    azureSubscription: ${{parameters.azureSubscription}}
    scriptType: pscore
    scriptLocation: inlineScript
    inlineScript: |
      $InformationPreference = "Continue"
      if ($env:SYSTEM_DEBUG)
      {
          $DebugPreference = 'Continue'
          $VerbosePreference = 'Continue'
      }

      $ip = "$(IP)"
      Write-Verbose "ip=$ip"

      Write-Information "Removing firewall rule for $ip"
      az sql server firewall-rule delete -g "${{parameters.resourceGroupName}}" -s "${{parameters.sqlServerName}}" -n $ip

      $tempPublicAccess = "$(TempPublicAccess)"
      Write-Verbose "tempPublicAccess=$tempPublicAccess"
      if ($tempPublicAccess -eq $True)
      {
        Write-Information "Disabling temp public access"
        az sql server update -g "${{parameters.resourceGroupName}}" -n "${{parameters.sqlServerName}}" --set publicNetworkAccess="Disabled" | Out-Null
      }
```

One key aspect to note is the **$tempPublicAccess** variable. This is set using the **pipeline variable** created in the allow task. This is to ensure that access to the SQL Server isn't left more restrictive than when the pipeline started.

### An Azure Pipeline Template to Automate Access

Below is the complete Azure Pipeline template I've prepared:

``` yaml
parameters:
  - name: environment
    displayName: The name of the DevOps environment to associate the deployment to
    type: string
  - name: azureSubscription
    displayName: The DevOps service connection to use for writing secrets to the key vault
    type: string
  - name: resourceGroupName
    displayName: Resource group name to deploy the template to
    type: string
  - name: sqlServerName
    displayName: Azure SQL Server name
    type: string
  - name: steps
    displayName: Steps to run with the temporary access
    type: stepList
    default: []
  - name: deploymentName
    displayName: Name of the deployment job, A-Z, a-z, 0-9, and underscore. Defaults to DeployTemplate
    type: string
    default: DeployAzureSQL
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
            - template: PrintEnvironmentVariables.azure-pipelines.yml

            - task: AzureCLI@2
              name: AllowPipelineIP
              displayName: Allow Pipeline IP
              inputs:
                azureSubscription: ${{parameters.azureSubscription}}
                scriptType: pscore
                scriptLocation: inlineScript
                inlineScript: |
                  $InformationPreference = "Continue"
                  if ($env:SYSTEM_DEBUG)
                  {
                      $DebugPreference = 'Continue'
                      $VerbosePreference = 'Continue'
                  }

                  Write-Debug "Checking SQL public access"
                  $sqlServer = az sql server show -g "${{parameters.resourceGroupName}}" -n "${{parameters.sqlServerName}}" | ConvertFrom-Json
                  $tempPublicAccess = $sqlServer.publicNetworkAccess -ieq "Disabled"
                  Write-Verbose "tempPublicAccess=$tempPublicAccess"
                  Write-Host "##vso[task.setvariable variable=TempPublicAccess]$tempPublicAccess"

                  if ($tempPublicAccess)
                  {
                    Write-Information "Temp enable public access"
                    az sql server update -g "${{parameters.resourceGroupName}}" -n "${{parameters.sqlServerName}}" --set publicNetworkAccess="Enabled" | Out-Null
                  }

                  Write-Debug "Getting public IP"
                  $ip = Invoke-RestMethod -Uri "https://ifconfig.me"
                  Write-Verbose "ip=$ip"
                  Write-Host "##vso[task.setvariable variable=IP]$ip"

                  Write-Information "Adding firewall rule for $ip"
                  az sql server firewall-rule create -g "${{parameters.resourceGroupName}}" -s "${{parameters.sqlServerName}}" -n $ip --start-ip-address $ip --end-ip-address $ip | Out-Null
            
            - ${{parameters.steps}}

            - task: AzureCLI@2
              name: RemovePipelineIP
              displayName: Remove Pipeline IP
              condition: succeededOrFailed()
              inputs:
                azureSubscription: ${{parameters.azureSubscription}}
                scriptType: pscore
                scriptLocation: inlineScript
                inlineScript: |
                  $InformationPreference = "Continue"
                  if ($env:SYSTEM_DEBUG)
                  {
                      $DebugPreference = 'Continue'
                      $VerbosePreference = 'Continue'
                  }

                  $ip = "$(IP)"
                  Write-Verbose "ip=$ip"

                  Write-Information "Removing firewall rule for $ip"
                  az sql server firewall-rule delete -g "${{parameters.resourceGroupName}}" -s "${{parameters.sqlServerName}}" -n $ip

                  $tempPublicAccess = "$(TempPublicAccess)"
                  Write-Verbose "tempPublicAccess=$tempPublicAccess"
                  if ($tempPublicAccess -eq $True)
                  {
                    Write-Information "Disabling temp public access"
                    az sql server update -g "${{parameters.resourceGroupName}}" -n "${{parameters.sqlServerName}}" --set publicNetworkAccess="Disabled" | Out-Null
                  }

```

One final feature of the pipeline template to note is the **steps** parameter. This is of type **[stepList](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/runtime-parameters?view=azure-devops&tabs=script#parameter-data-types)** which allows the allowing/removal of temp access to be wrapped around any task(s) you wish to define for great flexibility.

### Using the pipeline template

Below is an example of the pipeline template being called with a dummy **Query SQL** step:

``` yaml
name: $(Date:yy.MM.dd)$(Rev:.rr)

jobs:
  - template: templates/RunAzureSQL.azure-pipelines.yml
    parameters:
      environment: MSDN
      azureSubscription: devops-service-connection
      resourceGroupName: resource-group-name
      sqlServerName: sql-server-name
      steps:
        - task: AzureCLI@2
          displayName: Query SQL
          inputs:
            azureSubscription: devops-service-connection
            scriptType: pscore
            scriptLocation: inlineScript
            inlineScript: |
              $InformationPreference = "Continue"
              if ($env:SYSTEM_DEBUG)
              {
                  $DebugPreference = 'Continue'
                  $VerbosePreference = 'Continue'
              }

              Write-Debug "Installing SQLServer module"
              Install-Module -Name SQLServer -Scope CurrentUser -Force

              Write-Debug "Getting access token for Azure SQL"
              $accessToken = az account get-access-token --resource "https://database.windows.net" | ConvertFrom-Json
              $token = $accessToken.accessToken

              $sqlServerInstance = "sql-server-name.database.windows.net"
              Write-Verbose "sqlServerInstance=$sqlServerInstance"

              Invoke-SqlCmd -ServerInstance $sqlServerInstance `
                -Database sql-database-name `
                -AccessToken $token `
                -Query "SELECT TOP 10 * FROM sys.all_objects"
```

The resulting pipeline run for the above example will look similar to below.

![image1](/images/allow-temp-access-to-azure-sql-from-microsoft-hosted-agents//image1.png)

## Wrapping up

In this post, we've looked at automating allowing temporary access from a Microsoft-hosted agent to an Azure SQL instance to retain the simplicity of using these agents whilst keeping the impact on security to a minimum. We've also looked at wrapping this automation in a pipeline template using a stepList parameter to maximise the flexibility and reusability of the template.
