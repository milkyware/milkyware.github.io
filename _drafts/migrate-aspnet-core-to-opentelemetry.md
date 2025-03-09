---
title: Migrate ASP.NET Core App Insights to OpenTelemetry
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

The App Insights integration with ASP.NET Core has been a common feature of many applications since the release of ASP.NET Core back in 2016. However, with the rise of the open-standard **[OpenTelemetry](https://opentelemetry.io/)** and it's wide adoption by multiple platforms and monitoring tools, Microsoft has been working on adopting OpenTelemetry as the telemetry middleware fo ASP.NET Core.

As part of Microsoft recently **[starting to caution against using the legacy App Insights integration](https://learn.microsoft.com/en-us/azure/azure-monitor/app/asp-net-core)**, I've started migrating my projects to use the OpenTelemetry integration. For this post I want to share how I've gone about the migration as well as a couple of obstacles I encountered.

## The Current App Insights Integration

To set the scene, let's have a quick look at how the legacy App Insights integration is setup and how it looks. Firstly, the App Insights Nuget package needs to be installed:

``` bash
dotnet add package Microsoft.ApplicationInsights.AspNetCore
```

Once installed, the the `.AddApplicationInsightsTelemetry()` extension is then added to register the logging provider:

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

1. Remove the `Microsoft.ApplicationInsights.AspNetCore` package needs removing projects.
2. Remove the `builder.Services.AddApplicationInsightsTelemetry()` integration
3. Remove references to App Insights components and clean the solution

With the legacy App Insights integration removed, we can now start to **add the OpenTelemetry integration**. Firstly, the ASP.NET Core OpenTelemetry packages needs to be installed:

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

So, we can see the basic logged message and the values of the formatted message, however, the **customDimensions** contains a lot less detail. So how can we get this details back?

### Including Scopes

One of the great features of the .NET Core `ILogger` is its **[scoping capability]({% post_url 2024-12-02-my-approach-to-logging%})** allowing contextual values to be attached to all logged events in a scope. However, after **[digging around in the Azure.Monitor.OpenTelemetry.AspNetCore packge](https://github.com/Azure/azure-sdk-for-net/blob/b04b7e05f7a7002f8dec9d897d0400777874c3b4/sdk/monitor/Azure.Monitor.OpenTelemetry.AspNetCore/src/OpenTelemetryBuilderExtensions.cs#L155)** I found that including the scoped values wasn't enabled by default:

``` cs
var otelBuilder = services.AddOpenTelemetry()
    .WithLogging(o => { }, configureOptions =>
    {
        configureOptions.IncludeScopes = true;
        configureOptions.IncludeFormattedMessage = true;
        configureOptions.ParseStateValues = true;
    })
```

There is a few ways to configure enabling including scopes, I've opted for the approach above of using the `.WithLogging()` extension on the `OpenTelemetryBuilder` to keep the configuration all under the `IServiceCollection` extension. Below, we can now see **more customDimensions data included**.

![image4](/images/migrating-aspnet-core-to-opentelemetry/image4.png)

### Enriching the Logs

### Sample Project

## Wrapping Up
