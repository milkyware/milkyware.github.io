---
title: Customising HttpClient Logging
category: Integration
tags:
  - HttpClient
  - Logging
  - Dotnet Core
---

In Integration development, having sufficient logs is key to being able to debug issues. .NET has the well-established **[ILogger](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging?tabs=command-line)** pattern which is available by default in several application types including **ASP.NET Core and Worker Services**.

## Introducing ILogger

To understand logging in HttpClient, we first need to introduce ILogger. ILogger has some amazing features, but 2 key features we'll focus on are **log categories and log levels**.

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

ILogger also offers **6 log levels** (Critical, Error, Warning, Information, Debug, Trace) which allows the volume and severity of the gathered logs to be dialled up/down. When combined with **[log categories](#log-categories)**, this can produce a fine-grain control over the logs produced by the various ***components*** which make up an application.

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

Above is a sample section of the logs produced by an ASP.NET Core Web API being called by a hosted service (all in the same project). With the **System.Net.Http.HttpClient** category set to **Trace** notice the logs for the categories:

- System.Net.Http.HttpClient.SampleService.ClientHandler
- System.Net.Http.HttpClient.SampleService.LogicalHandler

The configured category log level uses a **[prefix match matching algorithm](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging/?view=aspnetcore-8.0#how-filtering-rules-are-applied)** meaning the sample appSettings will include all trace logs for all HttpClient instances.

``` cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient<SampleService>();
builder.Services.AddHttpClient("SampleHttpClient");
```

However, the category also includes the **name of the HttpClient**. This can be an arbitrary string or, with the generic builder method, this will be the name of the service the HttpClient is injected into, meaning that the logs can be further fine-tuned to specific HttpClient instances.

## Customising the logs

### How does the default logging work?

From the sample logs above you'll notice that the HttpClient includes some information logs of the API resource being hit and the verb being used as well as some trace logs of the request and response headers. Let's have a look at how this is implemented.

``` cs
namespace Microsoft.Extensions.DependencyInjection
{
    public static class HttpClientFactoryServiceCollectionExtensions
    {
        public static IServiceCollection AddHttpClient(this IServiceCollection services)
        {
            services.TryAddEnumerable(ServiceDescriptor.Singleton<IHttpMessageHandlerBuilderFilter, LoggingHttpMessageHandlerBuilderFilter>());

            // omitted for brevity
        }

        // omitted for brevity
    }
}
```

When adding a HttpClient using the **[dependency injection extensions](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Http/src/DependencyInjection/HttpClientFactoryServiceCollectionExtensions.cs)**, a **[LoggingHttpMessageHandlerBuilderFilter](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Http/src/Logging/LoggingHttpMessageHandlerBuilderFilter.cs)** service is registered.

``` cs
string loggerName = !string.IsNullOrEmpty(builder.Name) ? builder.Name : "Default";

ILogger outerLogger = LoggerFactory.CreateLogger($"System.Net.Http.HttpClient.{loggerName}.LogicalHandler");
ILogger innerLogger = LoggerFactory.CreateLogger($"System.Net.Http.HttpClient.{loggerName}.ClientHandler");

builder.AdditionalHandlers.Insert(0, new LoggingScopeHttpMessageHandler(outerLogger, options));

builder.AdditionalHandlers.Add(new LoggingHttpMessageHandler(innerLogger, options));
```

Inside the filter class, the **ILoggerFactory** is injected and used to create 2 ILogger objects with categories based on the **name of the HttpClient**. These 2 loggers are then used to construct 2 custom **DelegatingHandler** derived objects.

![image1](/images/customising-httpclient-logging/image1.png)

The delegating handlers form a pipeline of processing HTTP requests with the **HttpClientHandler** at the bottom handling passing the request to the endpoint. The handlers are then run in reverse to handle the response.

In the logging handlers, the injected ILogger is then used to log the headers of the request and response as well as the response duration.

### Customising using DelegatingHandler

Using the same pattern as the default logging handlers, we can customise the logging by creating our own DelegatingHandler.

``` cs
public class LoggingHttpBodyHandler(ILogger logger) : DelegatingHandler
{
    protected override HttpResponseMessage Send(HttpRequestMessage request, CancellationToken cancellationToken)
        => SendCoreAsync(request, false, cancellationToken).GetAwaiter().GetResult();

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        => SendCoreAsync(request, true, cancellationToken);

    private async Task<HttpResponseMessage> SendCoreAsync(HttpRequestMessage request, bool useAsync, CancellationToken cancellationToken)
    {
        if (request.Content is not null)
        {
            logger.LogTrace($"Request Body:{Environment.NewLine}{await request.Content.ReadAsStringAsync()}");
        }

        HttpResponseMessage response = useAsync
            ? await base.SendAsync(request, cancellationToken).ConfigureAwait(false)
            : base.Send(request, cancellationToken);

        if (response.Content is not null)
        {
            var content = await response.Content.ReadAsStringAsync();
            logger.LogTrace($"Response Body:{Environment.NewLine}{await response.Content.ReadAsStringAsync()}");
        }

        return response;
    }
}
```

For demo purposes, the above handler writes the body of the request and response to the logs. However, other scenarios could be recording warnings if the endpoint performance is slow or logging based on a custom header etc.

**N.B.** In a real-world scenario, logging the payload would have to be handled carefully to avoid sensitive data being logged as well as performance issues with large payloads. Typically, logging the body would only be used in development environments.

``` cs
var httpBuilder = builder.Services.AddHttpClient<SampleService>();
httpBuilder.AddHttpMessageHandler(sp =>
{
    var loggerFactory = sp.GetRequiredService<ILoggerFactory>();
    string loggerName = !string.IsNullOrEmpty(httpBuilder.Name) ? httpBuilder.Name : "Default";
    var logger = loggerFactory.CreateLogger($"System.Net.Http.HttpClient.{loggerName}.ClientBodyHandler");
    var handler = new LoggingHttpBodyHandler(logger);
    return handler;
});
```

To register the custom handler, the `.AddHttpMessageHandler()` builder can be used to add the handler to the **top of the handler pipeline**. This means that if multiple handlers are added using this method, the **last handler will run first**.

### Customising using IHttpClientLogger

Custom handlers are incredibly versatile and can be used for more than just logging (e.g. customising resiliency and authentication). However, due to being directly part of the handler pipeline, developers are responsible for ensuring requests and responses are passed to the next handler. To simplify the task of customising logging, Microsoft has added the **[IHttpClientLogger](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Http/src/Logging/IHttpClientLogger.cs)** interface.

``` cs
public class SampleHttpClientLogger(ILogger logger) : IHttpClientLogger
{
    public void LogRequestFailed(object? context, HttpRequestMessage request, HttpResponseMessage? response, Exception exception, TimeSpan elapsed)
    {
        // Logging
    }

    public object? LogRequestStart(HttpRequestMessage request)
    {
        // Logging
    }

    public void LogRequestStop(object? context, HttpRequestMessage request, HttpResponseMessage response, TimeSpan elapsed)
    {
        // Logging
    }
}
```

For logging, rather than developing a custom handler, Microsoft already have a dedicated logging handler in the pipeline, **[HttpClientLoggerHandler](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Http/src/Logging/HttpClientLoggerHandler.cs)**. This handler uses the interface above to provide 3 points of logging:

- RequestStart
- RequestStop
- RequestFailed

Using this interface avoids the need for ensuring subsequent handlers are honoured as well as provides more consistency and clarity of when the logging is performed. An async interface **[IHttpClientAsyncLogger](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Http/src/Logging/IHttpClientAsyncLogger.cs)** is also provided. This interface inherits from the synchronous one, however, only the async methods need implementing as the handler checks if the logger implements the async interface and calls the relevant logging point.

``` cs
var httpBuilder = builder.Services.AddHttpClient<SampleService>();
httpBuilder.AddLogger(sp =>
    {
        string loggerName = !string.IsNullOrEmpty(httpBuilder.Name) ? httpBuilder.Name : "Default";
        var category = $"System.Net.Http.HttpClient.{loggerName}.ClientBodyHandler2";
        var loggerFactory = sp.GetRequiredService<ILoggerFactory>();
        var logger = loggerFactory.CreateLogger(category);
        return new HttpClientBodyLogger(logger);
    }, false);
```

To register the logger there is the `.AddLogger()` builder method. The extension method can use standard dependency injection to construct the logger, however, an **IServiceProvider delegate** can be used to customise the injection such as dynamically setting the logger category.

The builder method also offers a **wrapHandlersPipeline** boolean parameter which controls whether the custom logger(s) are called either before or after any **added custom handlers**.

## Sample project

The code snippets used throughout are taken from **[this sample project](https://github.com/milkyware/blog-customising-httpclient-logging)** to run and try out a working project.

## Wrapping up

In this post, we've introduced ILogger and how appSettings can be used to dial up or down the logging levels of different categories. We've then looked at how we can use this configuration to control the built-in HttpClient logging. Lastly, we've looked at 2 options for customising and extending the logging available in the HttpClient.
