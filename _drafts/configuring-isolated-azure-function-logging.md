---
title: Configuring Isolated Azure Function Logging
category: Azure
tags:
 - .NET
 - Dotnet
 - Azure Function
 - Azure Functions Isolated
 - Logging
 - ILogger
---

Logging is a crucial aspect of any application for understanding and debugging the behaviour of an app in different circumstances as well as analysing how users interact with an app.

``` cs
public class SampleService
{
    private readonly ILogger _logger:

    public SampleService(ILogger<SampleService> logger)
    {
        _logger = logger;
    }

    public void Run()
    {
        logger.LogInformation("Starting run method")

        // Method logic

        logger.LogDebug("Debug logging")
        logger.LogTrace("Trace logging")

        // More method logic

        logger.LogInformation("Finishing run method successfully")
    }
}
```

`ILogger` has been common place in .NET apps since its introduction with .NET Core making logging a first-party experience in .NET along with many **[logging provider](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging-providers#third-party-logging-providers)** implementations.

Typically, events can be logged at a number of different levels ranging from **trace/debug** to **critical** to allowing gradually dialling up or down the logs produced from an app. The purpose of this post is to go through how to configure logging in **c# Isolated Azure Functions**.

## Logging in Isolated Azure Functions

As Isolated Azure Functions are based on .NET Core, the  

## Configuring using environment variables
