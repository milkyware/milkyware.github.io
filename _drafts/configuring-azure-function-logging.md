---
title: Configuring Azure Function Logging
category: Azure
tags:
 - .NET
 - Dotnet
 - Azure Function
 - Azure Functions Isolated
 - Logging
---

Logging is a crucial aspect of any application for understanding and debugging the behaviour of an app in different scenarios as well as analysing how users interact with the app.

``` cs
public class SampleService(ILogger<SampleService> logger)
{
    public void Run()
    {
        logger.LogInformation("Starting run method")

        // Method logic

        logger.LogDebug("Method milestone")

        // More method logic

        logger.LogInformation("Finishing run method successfully")
    }
}
```

`ILogger` has been common place in .NET apps since its introduction with .NET Core making logging a first-party experience in .NET along with many **[logging provider](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging-providers#third-party-logging-providers)** implementations.

## Configuring using environment variables

## What changed in Isolated Azure Functions
