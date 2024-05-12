---
title: Allow Temp Access to Azure SQL from Microsoft-Hosted Agents
category: DevOps
tags:
  - Azure
  - Azure DevOps
  - Azure Pipelines
  - Azure SQL
  - Microsoft-Hosted Agents
---

Currently, I use Microsoft-hosted pipeline agents to handle my deployments due to their simplicity and minimal maintenance overhead. I've recently needed to start running SQL scripts against Azure SQL instances from these pipelines. However, the connection from the pipeline agent was timing out and failing. So what the problem?

``` powershell
Invoke-SqlCmd : Connection Timeout Expired.  The timeout period elapsed during the post-login phase.  The connection could have timed out while waiting for server to complete the login process and respond; Or it could have timed out while attempting to create multiple active connections.  The duration spent while attempting to connect to this server was - [Pre-Login] initialization=49; handshake=43; [Login] initialization=1; authentication=3; [Post-Login] complete=14012; 
At /home/vsts/work/_temp/azureclitaskscript1715466301814_inlinescript.ps1:18 char:1
+ Invoke-SqlCmd -ServerInstance $sqlServerInstance `
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
+ CategoryInfo          : InvalidOperation: (:) [Invoke-Sqlcmd], SqlException
+ FullyQualifiedErrorId : SqlExceptionError,Microsoft.SqlServer.Management.PowerShell.GetScriptCommand
```

## The Problem

In short, the issue is that **[by default Azure SQL has public access disabled](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml#networking)** which blocks connections from Microsoft-hosted agents accessing over the public internet. So how can SQL be executed from an Azure Pipeline against Azure SQL?

From a security standpoint, using **self-hosted or [VM scale-set](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) agents** would resolve this by being part of the private Azure network. However, they take time to provision and require additional maintenance to retain an **[equivalent toolset](https://github.com/actions/runner-images)** to the Microsoft-hosted agents. The quickest option is to automate allowing Microsoft-hosted agents temporary access.

## Allowing Access from Microsoft-Hosted Agents

The networking for Microsoft-hosted agents is changeable in that the **[public IP addresses vary over time](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml#networking)**. There is also an added complication that the public IPs are shared with **all Microsoft-hosted agent users** and therefore any access given to an agent should be as limited as possible.

The solution I'd reached was to automate resolving the **public IP** of the agent running the pipeline and wrapping the ***SQL tasks*** in script to add and remove the resolved public IP.

### An Azure Pipeline Template to Automate Access

Below is an Azure Pipeline template I've prepared which:

- Resolves the public IP of the agent
- Check if public access is already enabled
  - Enables public access if not already
- Adds temp firewall rule for the public IP
- Runs a parametrised set of **steps/tasks**
- Removes temp firewall rule
- Disables public access if enabled by this pipeline

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
                  $sqlServer = az sql server show -g ${{parameters.resourceGroupName}} -n ${{parameters.sqlServerName}} | ConvertFrom-Json
                  $tempPublicAccess = $sqlServer.publicNetworkAccess -ieq "Disabled"
                  Write-Verbose "tempPublicAccess=$tempPublicAccess"
                  Write-Host "##vso[task.setvariable variable=TempPublicAccess]$tempPublicAccess"

                  if ($tempPublicAccess)
                  {
                    Write-Information "Temp enable public access"
                    az sql server update -g ${{parameters.resourceGroupName}} -n ${{parameters.sqlServerName}} --set publicNetworkAccess="Enabled" | Out-Null
                  }

                  Write-Debug "Getting public IP"
                  $ip = Invoke-RestMethod -Uri "https://ifconfig.me"
                  Write-Verbose "ip=$ip"
                  Write-Host "##vso[task.setvariable variable=IP]$ip"

                  Write-Information "Adding firewall rule for $ip"
                  az sql server firewall-rule create -g ${{parameters.resourceGroupName}} -s ${{parameters.sqlServerName}} -n $ip --start-ip-address $ip --end-ip-address $ip | Out-Null
            
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
                  az sql server firewall-rule delete -g ${{parameters.resourceGroupName}} -s ${{parameters.sqlServerName}} -n $ip

                  $tempPublicAccess = "$(TempPublicAccess)"
                  Write-Verbose "tempPublicAccess=$tempPublicAccess"
                  if ($tempPublicAccess -eq $True)
                  {
                    Write-Information "Disabling temp public access"
                    az sql server update -g ${{parameters.resourceGroupName}} -n ${{parameters.sqlServerName}} --set publicNetworkAccess="Disabled" | Out-Null
                  }

```

### Using the template

## Wrapping up
