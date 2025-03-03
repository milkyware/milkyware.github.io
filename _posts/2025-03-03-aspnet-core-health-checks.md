---
title: ASP.NET Core Health Checks
category: .NET
tags:
  - .NET
  - Dotnet
  - ASPNET
  - ASP.NET
  - ASP.NET Core
  - Health Checks
  - Monitoring
  - Probe
---

Modern applications are often complex, integrating and depending on multiple backend components including databases, APIs and cloud infrastructure. Ensuring these applications remain reliable and available is vital especially as outages of any of these underlying components can impact the availability and performance of applications.

There are many tools available that all contribute to monitoring the health of an application such as logging practices and platform/infrastructure diagnostics. However, the tool I want to focus on for this post is the **[ASP.NET Core Health Checks framework](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)**.

## What is ASP.NET Health Checks?

**Health probes** are a common feature of container orchestrators and cloud PaaS where a simple endpoint is polled with the response used to indicate the health of an application. Typically HTTP 2XX codes indicate healthy with any other code indicating unhealthy.

The Health Checks library is an optional middleware service provided by ASP.NET to allow defining a ***pool of health checks*** which are exposed via an endpoint to integrate with health probes. The component approach of the library offers a standardised way to create granular health checks to:

- Detect failures in individual components and dependencies
- Automate alerting on unhealthy applications
- Allow load balancers and orchestrators to automate restarting or diverting traffic (**good ol' turn it off and on again**)

## Getting Started with Health Checks

Getting the basic health check service setup is as simple as a **[Nuget package](https://www.nuget.org/packages?q=Microsoft.Extensions.Diagnostics.HealthChecks)** and registering a couple of components in the **Program.cs**. The package can be installed with the command below:

``` bash
dotnet add package Microsoft.Extensions.Diagnostics.HealthChecks
```

Once the package is installed, the Program.cs needs to be updated like below:

``` cs
using AspNetCoreHealthChecks;
using Microsoft.Extensions.Azure;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();
var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.MapHealthChecks("/healthz");

await app.RunAsync();
```

The key additions are `builder.Services.AddHealthChecks()` and `app.MapHealthChecks("/healthz")` which register the core middleware and an endpoint to evaluate the health of the middleware respectively. With the basic functionality registered, we can now call the endpoint:

``` http
GET /healthz HTTP/1.1
Host: localhost:7176

HTTP/1.1 200 OK
Content-Type: text/plain

Healthy
```

The response should look similar to the above. As, by default, no health checks have been registered the response currently should always be `Healthy` with a **200 OK**.

### Creating a Health Check

To start adding value to the health checks, we need to start developing components. To do this we use the `IHealthCheck` interface:

``` cs
public class FakerHealthCheck(ILogger<FakerHealthCheck> logger, IFakerClient client) : IHealthCheck
{
    private readonly IFakerClient _client = client;
    private readonly ILogger<FakerHealthCheck> _logger = logger;

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await _client.AddressesAsync();
            return HealthCheckResult.Healthy();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FakerHealthCheck failed");
            return HealthCheckResult.Unhealthy();
        }
    }
}
```

The interface requires the `CheckHealthAsync()` method to be implemented, returning a `HealthCheckResult`. The result can be `Healthy`, `Degraded` or `Unhealthy`. The component above checks that an API client can retrieve data, notice that the client and logger are injected using typical Dependency Injection practices meaning we can inject any of our services into health check components.

``` cs
builder.Services.AddHealthChecks()
    .AddCheck<FakerHealthCheck>("faker");
```

The registration of the custom health check can be done like above. The `AddHealthChecks()` extension uses the **fluent builder pattern** to register health checks with DI and the health checks middleware.

### Sample Project

All of the samples in this post are included in the below sample project.

[![milkyware/blog-aspnet-core-health-checks - GitHub](https://gh-card.dev/repos/milkyware/blog-aspnet-core-health-checks.svg)](https://github.com/milkyware/blog-aspnet-core-health-checks)

## Special Mention

By default, the Health Checks framework is a bit of a blank canvas. However, a special mention is needed for the **Xabaril/AspNetCore.Diagnostics.HealthChecks** project.

[![Xabaril/AspNetCore.Diagnostics.HealthChecks - GitHub](https://gh-card.dev/repos/Xabaril/AspNetCore.Diagnostics.HealthChecks.svg)](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks)

The project contains a **huge collection of ready-made community health check components!** I've used these components in numerous projects as they make configuring a robust health check incredibly easy.

``` cs
builder.Services.AddHealthChecks()
    .AddSqlServer(Configuration["Data:ConnectionStrings:Sql"])
    .AddRedis(Configuration["Data:ConnectionStrings:Redis"]);
```

The project also offers an extra UI component to visualise a history of health check events.

## Wrapping Up

The Health Checks framework is a simple yet powerful way to monitor the health of your applications detect failures in dependencies quickly. The health probe endpoint can then integrate with various hosting environments, including cloud and container environments, to automate scaling and self-healing.

The framework can also easily be extended with custom health checks to monitor your own components and dependencies, but there are also community projects such as **Xabaril/AspNetCore.Diagnostics.HealthChecks** to help set up robust monitoring. Whether for a single app or a microservices architecture, health checks are essential for ensuring reliability and resilience.
