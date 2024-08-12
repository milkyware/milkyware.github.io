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

        logger.LogInformation("Finishing run method successfully")
 }
}
```

`ILogger` has been commonplace in .NET apps since its introduction with .NET Core making logging a first-party experience along with many **[logging provider](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging-providers#third-party-logging-providers)** implementations.

Typically, events can be logged at several levels ranging from **trace/debug** to **critical** to allow gradual dialling up or down the logs produced from an app. The purpose of this post is to go through how to configure logging in **C# Isolated Azure Functions**.

## Logging in Isolated Azure Functions

.NET Core Isolated Azure Functions have the same dependency injection and logging available as the rest of the .NET Core family.

``` cs
public class TimerFunction
{
    private readonly ILogger<TimerFunction> _logger;

    public TimerFunction(ILogger<TimerFunction> logger)
 {
        _logger = logger;
 }

 [Function(nameof(TimerFunction))]
    public async Task Run([TimerTrigger("0 0 * * *", RunOnStartup = true)] TimerInfo timerInfo)
 {
        _logger.LogInformation($"C# Timer trigger function executed at: {DateTime.Now}");
        _logger.LogDebug("Func debug message");
        _logger.LogTrace("Func trace message");
 }
}
```

In the above example, the `ILogger` instance is injected into the function class and is used to log information, debug and trace events.

``` bash
[2024-08-12T09:31:42.679Z] Worker process started and initialized.

Functions:

        TimerFunction: timerTrigger

For detailed output, run func with --verbose flag.
[2024-08-12T09:31:42.873Z] Executing 'Functions.TimerFunction' (Reason='Timer fired at 2024-08-12T10:31:42.8543941+01:00', Id=15cf5011-978a-4d8c-ab41-0679249326fc)
[2024-08-12T09:31:42.874Z] Trigger Details: UnscheduledInvocationReason: RunOnStartup
[2024-08-12T09:31:42.937Z] Running sample service
[2024-08-12T09:31:42.937Z] C# Timer trigger function executed at: 12/08/2024 10:31:42
[2024-08-12T09:31:43.977Z] Executed 'Functions.TimerFunction' (Succeeded, Id=15cf5011-978a-4d8c-ab41-0679249326fc, Duration=1115ms)
```

Running the function will produce a console output similar to the above. Notice that only the information log is displayed. By default, the minimum logging level in Azure Functions is information, so how do we control displaying the debug and trace logs?

``` json
{
  "version": "2.0",
  "logging": {
    // Other host logging config
    "logLevel": {
      "Function": "Trace",
 }
 }
}
```

The nature of Isolated Azure Functions is that the **[host and worker are separate](https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide?tabs=windows#managing-log-levels)**. Azure Functions use **[special categories](https://learn.microsoft.com/en-us/azure/azure-functions/configure-monitoring?tabs=v2#configure-categories)** which are based on **where the logs come from** instead of generic class names. Therefore, we first need to configure the minimum log level for logs coming from **function definitions**. This is done by setting the **Function** level in **host.json** like above.

``` cs
.ConfigureLogging((context, logging) =>
{
 // Other logging configuration

    logging.AddFilter("ConfigureAzFuncLogging", LogLevel.Trace);
})
```

With the host log level configured, we can now configure the logging of the worker. The above configures logs with the category **ConfigureAzFuncLogging** to have a minimum log level of **Trace**.

``` bash
[2024-08-12T10:23:34.141Z] Worker process started and initialized.

Functions:

        TimerFunction: timerTrigger

For detailed output, run func with --verbose flag.
[2024-08-12T10:23:34.358Z] Executing 'Functions.TimerFunction' (Reason='Timer fired at 2024-08-12T11:23:34.3354849+01:00', Id=81715cb9-b8bc-4ff2-8aed-64654536b89c)
[2024-08-12T10:23:34.360Z] Trigger Details: UnscheduledInvocationReason: RunOnStartup
[2024-08-12T10:23:34.436Z] C# Timer trigger function executed at: 12/08/2024 11:23:34
[2024-08-12T10:23:34.436Z] Func trace message
[2024-08-12T10:23:34.436Z] Func debug message
[2024-08-12T10:23:35.476Z] Executed 'Functions.TimerFunction' (Succeeded, Id=81715cb9-b8bc-4ff2-8aed-64654536b89c, Duration=1133ms)
```

Re-running the function now produces logs like the above with the debug and trace events included. So how can we improve the configurability to dial up and down the logging levels?

## Configuring using environment variables

So far we've looked at how we can use the **host.json file** and the `.ConfigureLogging()` extensions method can be used to set logging levels.

``` json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",

    "AZUREFUNCTIONSJOBHOST__LOGGING__LOGLEVEL__FUNCTION": "Trace"
 }
}
```

Azure Functions offer the ability to **[override host.json values](https://learn.microsoft.com/en-us/azure/azure-functions/functions-host-json#override-hostjson-values)** with environment variables. The above **local.settings.json** config is equivalent to what we configured in the **host.json** earlier. How can we use environment variables to configure the worker logging?

``` cs
.ConfigureLogging((context, logging) =>
{
 // Other logging configuration

    var section = context.Configuration.GetSection("Logging");
    logging.AddConfiguration(section);
})
```

In `.ConfigureLogging()` we can replace explicitly adding a filter with `.AddConfiguration()` to set up logging in a similar way to what is available in ASP.NET Core by default.

``` json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",

    "AZUREFUNCTIONSJOBHOST__LOGGING__LOGLEVEL__FUNCTION": "Trace",
    "LOGGING__LOGLEVEL__CONFIGUREAZFUNCLOGGING": "Trace"
 }
}
```

The **local.settings.json** can in turn be updated to look like the above. These environment variables can then be configured in various places such as **Bicep templates, Azure Pipelines etc** to set the logging levels in different environments e.g. trace/debug in dev or info/warn in prod.
