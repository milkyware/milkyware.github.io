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
      "Default": "Trace",
      "System.Net.Http.HttpClient": "Trace"
    }
  }
  // Further appSettings
}
```

Following the same convention used in the **[previous section](#log-levels)**, the HttpClient log level can also be dialled up or down.

``` log
info: HttpClientLoggingDemo.SampleService[0]
      Executing PostRequestAsync
info: System.Net.Http.HttpClient.SampleService.LogicalHandler[100]
      Start processing HTTP request POST https://localhost:7139/sample
trce: System.Net.Http.HttpClient.SampleService.LogicalHandler[102]
      Request Headers:
      Content-Type: application/json; charset=utf-8
info: System.Net.Http.HttpClient.SampleService.ClientHandler[100]
      Sending HTTP request POST https://localhost:7139/sample
trce: System.Net.Http.HttpClient.SampleService.ClientHandler[102]
      Request Headers:
      Content-Type: application/json; charset=utf-8

info: Program[0]
      value=4be62e0c-5605-4163-a5c4-5ce564679e25
info: System.Net.Http.HttpClient.SampleService.ClientHandler[101]
      Received HTTP response headers after 2.0004ms - 200
trce: System.Net.Http.HttpClient.SampleService.ClientHandler[103]
      Response Headers:
      Date: Sun, 24 Mar 2024 10:33:34 GMT
      Server: Kestrel
      Transfer-Encoding: chunked
      Content-Type: application/json; charset=utf-8

info: System.Net.Http.HttpClient.SampleService.LogicalHandler[101]
      End processing HTTP request after 4.3948ms - 200
trce: System.Net.Http.HttpClient.SampleService.LogicalHandler[103]
      Response Headers:
      Date: Sun, 24 Mar 2024 10:33:34 GMT
      Server: Kestrel
      Transfer-Encoding: chunked
      Content-Type: application/json; charset=utf-8

info: HttpClientLoggingDemo.SampleService[0]
      Received PostRequestAsync response
```

Above is a sample section of the logs produced by an ASP.NET Core Web API being called by hosted service (all in the same project).

## Enabling the built-in logging

## Customising using DelegatingHandler

## Customising using IHttpClientLogger
