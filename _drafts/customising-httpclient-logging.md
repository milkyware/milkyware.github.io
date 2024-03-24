---
title: Customising HttpClient Logging
category: Integration
tags:
  - HttpClient
  - Logging
  - Dotnet Core
---

In Integration development, having sufficient logs is key to being able to debug issues. .NET has the well established **[ILogger](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging?tabs=command-line)** pattern which is available by default in a number of application types including **ASP.NET Core and Worker Services**.

## Introducing ILogger

To understand logging in a HttpClient, we firstly need to introduce ILogger. ILogger has some amazing features, but 2 key feature we'll focus on are **log categories and log levels**.

### Log categories

The purpose of the log category is to distinguish groups of logs by the **source ILogger object**. The category is a simple string, however, typically it follows the convention of the **full name of a class (namespace + class name)**.

``` cs
namespace namespace HttpClientLoggingDemo
{
    public class SampleService(ILogger<SampleService> logger)
    {
        public async Task RunAsync()
        {
            // Method logic
        }
    }
}
```

In the above example, the category of the injected ILogger would be **HttpClientLoggingDemo.SampleService**. This value is then recorded alongside any logs recorded using the ILogger object such as written to the console or as metadata in a telemetry service.

### Log Levels

ILogger also offers **6 log levels** (Critical, Error, Warning, Information, Debug, Trace) which allows the volume and severity of the gathered logs to be dialled up/down. When combined with **[log categories](#log-categories)**, this can produce a fine-grain control over the logs produced by the various ***components*** which make up an application..

``` json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "HttpClientLoggingDemo.SampleService": "Warning"
    }
  }
  // Further appSettings
}
```

The sample section of **appsettings** above will configure the application to do 2 things:

1. The **default** log level for all categories will be information and above
2. The **HttpClientLoggingDemo.SampleService** category will only produce logs of warning or above.

**N.B.** The default log level only applies to categories where the developer/vendor hasn't specifically configured a log level for it.

### Configuring the HttpClient built-in logging

``` json
{
  "Logging": {
    "LogLevel": {
      "System.Net.Http.HttpClient": "Trace"
    }
  }
  // Further appSettings
}
```

Following the same convention used in the **[previous section](#log-levels)**, the HttpClient log level can also be dialled up or down.

## Enabling the built-in logging

## Customising using DelegatingHandler

## Customising using IHttpClientLogger
