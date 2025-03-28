---
title: Migrating ASP.NET Core to OpenTelemetry
category: .NET
tags:
  - .NET
  - Dotnet
  - ASPNET
  - ASP.NET
  - ASP.NET Core
  - Migration
  - Logging
  - Monitoring
  - App Insights
  - OpenTelemetry
---

App Insights integration with ASP.NET Core has been a common feature of many applications since its release in 2016. However, with the rise of the open-standard **[OpenTelemetry](https://opentelemetry.io/)** and its wide adoption by multiple platforms and monitoring tools, Microsoft has been working on adopting OpenTelemetry as the telemetry middleware for ASP.NET Core.

As part of Microsoft recently **[starting to caution against using the legacy App Insights integration](https://learn.microsoft.com/en-us/azure/azure-monitor/app/asp-net-core)**, I've started migrating my projects to use the OpenTelemetry integration. For this post, I want to share how I've gone about the migration as well as a couple of obstacles I encountered.

## The Current App Insights Integration

To set the scene, let's have a quick look at how the legacy App Insights integration is set up and how it looks. Firstly, the App Insights Nuget package needs to be installed:

``` bash
dotnet add package Microsoft.ApplicationInsights.AspNetCore
```

Once installed, the `.AddApplicationInsightsTelemetry()` extension is then added to register the logging provider:

``` cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddApplicationInsightsTelemetry();

// Add other services

var app = builder.Build();
await app.RunAsync();
```

Lastly, the App Insights connection string needs to be configured by configuring `APPLICATIONINSIGHTS_CONNECTION_STRING`.

![image1](/images/migrating-aspnet-core-to-opentelemetry/image1.png)

Logging events using `ILogger` will then create logs in App Insights similar to above. The key thing to note is the inclusion of various values under **customDimensions** such as **RequestPath and CategoryName** which can help filter and group logs without needing to deconstruct a log message.

## What is OpenTelemetry?

OpenTelemetry is an **open-source observability framework** which has been widely adopted by the industry. The framework is intended to function as a middleware in generating, collecting and exporting telemetry from solution components (including software and platform components) to observability tools.

![image2](/images/migrating-aspnet-core-to-opentelemetry/image2.png)

So why use OpenTelemetry? Just as cloud computing has resulted in more decoupled and microservice-style solutions, OpenTelemetry addresses these needs through its open standard. This open standard therefore allows decoupling the generation and collection of telemetry from exporting that telemetry. The **[OpenTelemetry docs](https://opentelemetry.io/docs/what-is-opentelemetry/)** are incredibly detailed if you want to dig deeper.

### Migrating to OpenTelemetry with App Insights

So how can we migrate to using OpenTelemetry to integrate with App Insights? Microsoft do offer a **[guide for migration](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-dotnet-migrate)** but lets start by summarising the removal steps:

1. Remove the `Microsoft.ApplicationInsights.AspNetCore` package from projects.
2. Remove the `builder.Services.AddApplicationInsightsTelemetry()` integration
3. Remove references to App Insights components and clean the solution

With the legacy App Insights integration removed, we can now start to **add the OpenTelemetry integration**. Firstly, the ASP.NET Core OpenTelemetry packages need to be installed:

``` bash
dotnet add package Azure.Monitor.OpenTelemetry.AspNetCore
```

The basic OpenTelemetry and App Insights can then be enabled by adding `builder.Services.AddOpenTelemetry().UseAzureMonitor()`

``` cs
var builder = WebApplication.CreateBuilder(args);

var otelBuilder = builder.Services.AddOpenTelemetry();
if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
    otelBuilder.UseAzureMonitor();

// Add other services

var app = builder.Build();
await app.RunAsync();
```

Above is a basic example of enabling the OpenTelemetry integration. However, the first difference with the legacy App Insights integration is that the connection string **is now mandatory** either by reusing the `APPLICATIONINSIGHTS_CONNECTION_STRING` environment variable or configuring in an options delegate in `.UseAzureMonitor()`. To maintain the previous optional configuration (for scenarios such as running locally where App Insights isn't needed) we can check the environment variable is set before configuring the builder returned by `.AddOpenTelemetry()`.

Let's have a look at the logs this integration produces:

![image3](/images/migrating-aspnet-core-to-opentelemetry/image3.png)

So, we can see the basic logged message and the values of the formatted message, however, the **custom dimensions** contain a lot less detail. So how can we get these details back?

### Including Scopes

One of the great features of the .NET Core `ILogger` is its **[scoping capability]({% post_url 2024-12-02-my-approach-to-logging%})** allowing contextual values to be attached to all logged events in a scope. However, after **[digging around in the Azure.Monitor.OpenTelemetry.AspNetCore packge](https://github.com/Azure/azure-sdk-for-net/blob/b04b7e05f7a7002f8dec9d897d0400777874c3b4/sdk/monitor/Azure.Monitor.OpenTelemetry.AspNetCore/src/OpenTelemetryBuilderExtensions.cs#L155)** I found that including the scoped values weren't enabled by default:

``` cs
var otelBuilder = services.AddOpenTelemetry()
    .WithLogging(configureBuilder => { }, configureOptions =>
    {
        configureOptions.IncludeScopes = true;
        configureOptions.IncludeFormattedMessage = true;
        configureOptions.ParseStateValues = true;
    })
```

There are a few ways to configure enabling including scopes, I've opted for the approach above of using the `.WithLogging()` extension on the `OpenTelemetryBuilder` to keep the configuration all under the `IServiceCollection` extension. Below, we can now see **more customDimensions data included**.

![image4](/images/migrating-aspnet-core-to-opentelemetry/image4.png)

### Enriching the Logs

Two values that are still missing are **CategoryName and OriginalFormat** which I find can be useful for filtering logs specific to the namespace of your application and looking for logs using the message straight out of your code.

These values are available as properties on the OpenTelemetry `LogRecord` model, however, the **Azure Monitor exporter** populates the customDimensions using the `LogRecord.Attributes` property.

``` cs
public class LogEnrichmentProcessor : BaseProcessor<LogRecord>
{
    private const string CategoryNameKey = nameof(LogRecord.CategoryName);
    private const string LogLevelKey = nameof(LogRecord.LogLevel);
    private const string OriginalFormatKey = "OriginalFormat";

    public override void OnEnd(LogRecord data)
    {
        var attributes = data.Attributes is not null
            ? new List<KeyValuePair<string, object?>>(data.Attributes)
            : [];

        if (data.Attributes is not null && data.Attributes.Any())
            attributes.AddRange(data.Attributes);

        if (!attributes.Any(a => a.Key == LogLevelKey))
            attributes.Add(new(LogLevelKey, data.LogLevel.ToString()));

        if (!attributes.Any(a => a.Key == CategoryNameKey) && !string.IsNullOrWhiteSpace(data.CategoryName))
            attributes.Add(new(CategoryNameKey, data.CategoryName));

        if (!attributes.Any(a => a.Key == OriginalFormatKey) && !string.IsNullOrWhiteSpace(data.Body))
            attributes.Add(new(OriginalFormatKey, data.Body));

        data.Attributes = attributes;
        base.OnEnd(data);
    }
}
```

OpenTelemetry offers the ability to **[enrich telemetry through processors](https://github.com/open-telemetry/opentelemetry-dotnet/blob/main/docs/trace/extending-the-sdk/README.md#enriching-processor)**. The documentation and samples for creating processors for `LogRecord` can be **[found here](https://github.com/open-telemetry/opentelemetry-dotnet/blob/main/docs/logs/extending-the-sdk/README.md#processor)**. Above is the processor I put together to enrich logs with **LogLevel, CategoryName and OriginalFormat**.

``` cs
var otelBuilder = services.AddOpenTelemetry()
    .WithLogging(configureBuilder =>
    {
        configureBuilder.AddProcessor<LogEnrichmentProcessor>();
    }, configureOptions =>
    {
        configureOptions.IncludeScopes = true;
        configureOptions.IncludeFormattedMessage = true;
        configureOptions.ParseStateValues = true;
    });
```

The processor can then be registered with our existing `.WithLogging()` setup.

![image5](/images/migrating-aspnet-core-to-opentelemetry/image5.png)

The logs created in Azure Monitor should now look similar to above with the **LogLevel, CategoryName and OriginalFormat** included.

## Sample Project

As always, the samples in this post are taken from the sample project I've prepared.

[![milkyware/blog-migrate-aspnetcore-appinsights-to-otel - GitHub](https://gh-card.dev/repos/milkyware/blog-migrate-aspnetcore-appinsights-to-otel.svg)](https://github.com/milkyware/blog-migrate-aspnetcore-appinsights-to-otel)

## Wrapping Up

With the direction of travel from Microsoft being to adopt OpenTelemetry, I've wanted to share how I've migrated my projects to use OpenTelemetry. As a framework, OpenTelemetry is a fantastic tool that offers decoupling and flexibility such as swapping out exporters and, although not covered in this post, supports distributed tracing for developing observability in solutions using microservice components.

I've also highlighted some of the differences in functionality between the legacy App Insights integration and the default OpenTelemetry setup, but this can be configured to a similar level and retain support for any existing Azure Monitor KQL queries we may be using. I hope you find this useful and please feel free to try it out.
