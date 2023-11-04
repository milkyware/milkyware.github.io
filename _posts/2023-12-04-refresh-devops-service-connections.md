---
title: Refreshing DevOps Service Connections
header:
  image: '/images/refresh-devops-service-connections/header.png'
category: DevOps
tags:
  - Azure
  - Azure Devops
  - PowerShell
---

A while back I put together an application provisioning process using **PowerShell and Azure Pipelines** to automate delivering Azure application environments including:

- Resource Groups
- AAD access groups
- Deployment App Registrations
- DevOps Service Connections

As ***manually*** created service connections (through the DevOps API) require a secret, these secrets come with an expiration date. In this post, I'll share how I automated the process of refreshing these tokens.

## Why automate it?

Typically, my approach to automation is **why not?**

Automation helps to keep a process consistent both in how frequently it's down as well as how it's done. For this particular scenario, as App Regs were created **for each application**, and service connections were scoped to a **particular Azure subscription**, the number of connections that needed maintenance was quickly growing.

### Sample Project

For this post, I've prepared a sample **[GitHub repo](https://github.com/milkyware/blog-refresh-devops-service-connections)** with copies of all of the scripts I'll be referencing in this post

## The automation

For the automation I've used **[Az CLI](https://github.com/Azure/azure-cli)** and **[PowerShell (Core)](https://github.com/PowerShell/PowerShell)**.

``` powershell
$appRegs = az ad app list --all | ConvertFrom-Json
```

I tend to use Az CLI for interacting with Azure due to it being very terse in terms of usage and typically better supported for the services I use. I then use PowerShell for orchestrating the logic and `ConvertFrom-Json` to access the JSON responses from Az CLI.

The automation is composed of 3 scripts:

- GetExpiringAppRegs.ps1
- DeployDevOpsConnections.ps1
- RefreshDevOpsConnections.ps1 - This is a wrapper around the first 2 scripts

### Getting expired/expiring App Regs

Although **GetExpiringAppRegs.ps1** is used as part of refreshing service connections, it is designed to be generic to report on **expired/expiring Azure App Registrations**.

``` cmd
PS C:\> .\GetExpiringAppRegs.ps1

Name      : expiring-appreg1
ObjectId  : objectId1
AppId     : appId1
Notes     : 
ExpiresOn : 10/11/2023 00:00:00

Name      : expiring-appreg2
ObjectId  : objectId2
AppId     : appId2
Notes     : 
ExpiresOn : 28/10/2023 23:00:00
```

This is effectively a wrapper around the `az ad app list --all` command which then processes the response based on some optional regex and a ***warning window*** on the expiration of secrets.

### Updating the credentials

Once the **RefreshDevOpsConnections.ps1** has a list of expiring app regs, these are looped through to evaluate and trigger the refresh process.

``` powershell
$existingServiceConnections = az devops service-endpoint list --organization $Organisation --project $Project | ConvertFrom-Json

foreach ($ar in $appRegs)
{
    $serviceConnections = $existingServiceConnections | Where-Object {$_.authorization.parameters.serviceprincipalid -eq $ar.AppId}

    if ($serviceConnections.Count -eq 0)
    {
        continue;
    }
    $subscriptions = $serviceConnections.data.subscriptionName

    $deployDevOpsConnectionParams = @{
        Organisation = $Organisation
        Project = $Project
        Token = $Token
        AppReg = $($ar.Name)
        Subscriptions = $subscriptions
    }
    ...
}
```

Above is an abbreviated version of the sample script. For each app reg, the **appId** is compared against the list of existing DevOps service connections. Where service connections are found, an array of Azure subscriptions is retrieved as typically service connection sessions are scoped to the subscription level. The **DeployDevOpsConnections.ps1** script is triggered with the app reg and subscription details.

``` powershell
Write-Debug "Resetting secret for $AppReg"
if ($PSCmdlet.ShouldProcess("$AppReg password reset"))
{
    $appRegCreds = az ad app credential reset --id $appRegObj.id | ConvertFrom-Json
    Write-Verbose "secret=$($appRegCreds.password)"
}
```

Similar to the **[GetExpiringAppRegs.ps1](#getting-expiredexpiring-app-regs)** script, **DeployDevOpsConnections.ps1** is also intended to be a generic script to **upsert** service connections to Azure DevOps. The first task of this script is to generate a **secret** for the app reg.

``` powershell
Write-Debug "Checking for existing service connection for $AppRegName to $SubscriptionName"
$serviceConnection = az devops service-endpoint list --organization $Organisation --project $Project | ConvertFrom-Json | Where-Object {$_.authorization.parameters.serviceprincipalid -match "$AppRegId" -and $_.data.subscriptionName -eq $SubscriptionName}
if ($serviceConnection) 
{
    $serviceConnectionFile = [System.IO.Path]::GetTempFileName()
    Write-Verbose "serviceConnectionFile=$serviceConnectionFile"
    try {
        Write-Debug "Adding updated secret to service connection definition"
        $serviceConnection.authorization.parameters | Add-Member -MemberType NoteProperty -Name "serviceprincipalkey" -Value $AppRegSecret

        Write-Debug "Temp exporting service connection definition"
        $serviceConnection | ConvertTo-Json -Depth 10 | Set-Content -Path $serviceConnectionFile

        Write-Debug "Updating service connection $($serviceConnection.name)"
        if ($PSCmdlet.ShouldProcess("Updated service connection $($serviceConnection.name)"))
        {
            az devops invoke --org $Organisation --http-method PUT --area serviceendpoint --resource endpoints --route-parameters "project=$Project" "endpointId=$($serviceConnection.id)" -o json --in-file $serviceConnectionFile | Out-Null
            Write-Information "Updated service connection $($serviceConnection.name) successfully"
        }
    }
    finally {
        Write-Debug "Removing service connection update file"
        Remove-Item -Path $serviceConnectionFile -Force -WhatIf:$false
    }
    return
}
```

The bulk of the logic is in the private function **UpsertServiceConnection**. The **[azurerm create](https://github.com/Azure/azure-devops-cli-extension/blob/4c3ef2366f8b7d0758c0d64574b8f96d0b894c78/azure-devops/azext_devops/dev/team/service_endpoint.py#L90)** command is a wrapper around the **[DevOps service endpoint create API](https://learn.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpoints/create?view=azure-devops-rest-7.2&tabs=HTTP)**. There is currently no native Az CLI command for updating the credentials for an AzureRM connection, however, it does provide a generic `az devops invoke` command. The above part of the function is based on the Az CLI logic where the JSON of each service connection is exported to a temporary file and updated with the new secret. The generic **invoke** command is then used to update the service connection credentials.

## Final Thoughts

The scripts discussed in the sample repo have been used to automate the refresh of credentials, however, they have also been designed to be generic and reusable such as:

- reporting and alerting on expired/expiring app regs
- triggering other credential refresh processes
- deploying new Azure DevOps service connections
