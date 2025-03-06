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

Logging events using `ILogger` will then create events in App Insights similar to above. The key thing to note is the inclusion of various values under **customDimensions** such as **RequestPath and CategoryName** which can help group related logs together.

## What is OpenTelemetry?

## Integrating OpenTelemetry with App Insights

## Enriching the Logs

## Wrapping Up
