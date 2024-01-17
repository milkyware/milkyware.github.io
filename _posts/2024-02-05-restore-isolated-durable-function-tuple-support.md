---
title: Restore Isolated Durable Function Tuple Support
category: Integration
tags:
  - Azure Function
  - Durable Function
  - Tuple
  - DotNet Isolated
---

With the release of **[Azure Functions on .NET 8](https://techcommunity.microsoft.com/t5/apps-on-azure-blog/net-on-azure-functions-august-2023-roadmap-update/ba-p/3910098)** and feature parity of the **in-process to the isolated model**, I've started to migrate existing **in-process functions** to the **isolated model**. The existing function apps are a mixture of standard functions and durable functions.

## What are Tuples?

**[Tuples](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/value-tuples)** are a mathematical concept of an **ordered list of elements**. In programming, Tuples are a feature which allows for multiple values/objects to be passed around as a single object.

``` csharp
var tuple = ("Hello", "World");
Console.WriteLine($"{tuple.Item1} {tuple.Item2}");
// "Hello World"
```

In the above example, the two strings of **"Hello" and "World"** are used to create a Tuple which is then printed. Tuples can also be created from multiple complex objects.

## Sample Project

Below going any further, **[here](https://github.com/milkyware/blog-refresh-devops-service-connections)** is a sample project of a .NET 8 isolated durable function using Tuples.

## Using Tuples in Durable Functions

Durable Functions are comprised of **activities** to perform functional tasks and **orchestrations** to manage the flow of activities. Both can take an input of a **JSON-serializable object**. In many of the existing Durable Functions I was migrating, multiple objects were being built up from several activities and then mapped.

``` csharp
[Function(nameof(Orchestrator))]
public async Task RunAsync([OrchestrationTrigger] TaskOrchestrationContext context)
{
    var object1 = await context.CallActivityAsync<Model1>(nameof(Activity1));
    var object2 = await context.CallActivityAsync<Model2>(nameof(Activity2));
    var object3 = await context.CallActivityAsync<Model3>(nameof(Activity3));

    await context.CallActivityAsync(nameof(ActivityMapper), (object1, object2, object3));
}
```

As per **[Microsoft docs](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-types-features-overview#activity-functions)**, Tuples can be used to pass multiple inputs to a durable function without having to create a wrapper complex object.

``` csharp
[Function(nameof(ActivityMapper))]
public string RunAsync([ActivityTrigger] (Model1, Model2, Model3) input)
{
    var target = Map(input);
    ...
}
```

If the above examples are run in a new **DotNet isolated** project, the ***item* members** of the input tuple will all be **null**. After some research, one of the changes from the in-process to isolated model is that the JSON serializer has been swapped **[from Newtonsoft to System.Text.Json](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-dotnet-isolated-overview#behavioral-changes)**. By default Newtonsoft serializes **[all public fields and properties](https://www.newtonsoft.com/json/help/html/serializationguide.htm)**, however, by default System.Text.Json **[doesn't include fields](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/fields)**. As shorthand Tuples (ValueTuples) such as in the example use **fields** for the items, these aren't serialized when used as an input for a durable function.

``` csharp
var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.Configure<JsonSerializerOptions>(configure => configure.IncludeFields = true);
    })
    .Build();

host.Run();
```

To restore the ability to use Tuples as inputs, the **JsonSerializerOptions** can be configured in the **Program.cs** to toggle to inclusion of fields in the System.Text.Json (de)serialization process. Although this is a simple fix, the impact of the serializer change isn't particularly mentioned in the docs and thought it would be useful to document the impact on using Tuples.
