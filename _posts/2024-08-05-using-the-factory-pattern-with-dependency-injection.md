---
title: Using the Factory Pattern with Dependency Injection
category: .NET
tags:
 - .NET
 - Dotnet
 - Design Patterns
 - Factory Pattern
 - Dependency Injection
 - Durable Functions
---

The **Factory Pattern** is a coding design pattern for creating objects by replacing the need to directly **construct** an object with a ***creator*** method. The purpose of this post is to share a recent experience of using the factory pattern in a recent project to integrate **a central system with several external APIs** and abstract the integration business logic to allow services to be added or removed without impacting the business logic.

## Why use the Factory Pattern?

The factory pattern is instrumental in scenarios where the **type of an object** is determined at runtime and offers the benefits of:

- Encapsulating the creation logic so that users of the factory don't need to know the logic behind the creation
- Improving flexibility to add new types to the factory
- Simplifying and centralising the creation logic

For more detail on the factory pattern, **[Refactoring Guru](https://refactoring.guru/design-patterns/factory-method)** has a great article.

``` cs
public interface IProduct
{
    string GetName();
}

// Concrete Product A
public class ProductA : IProduct
{
    public string GetName() => "Product A";
}

// Concrete Product B
public class ProductB : IProduct
{
    public string GetName() => "Product B";
}

// Factory Class
public class ProductFactory
{
    public static IProduct CreateProduct(string type)
    {
        switch(type)
        {
            case "A": return new ProductA();
            case "B": return new ProductB();
            default: throw new ArgumentException("Invalid type");
        }
    }
}
```

In the code above, each **concrete product class** implements `IProduct`. The `ProductFactory` then offers a `CreateProduct()` which constructs and returns an instance of `IProduct` using a parameter to control which implementation is returned.

## Brief overview of Dependency Injection

Typically, the factory handles the creation of objects, however, with modern .NET we have **dependency injection** available to us to handle that. So let's have a brief overview of dependency injection.

``` cs
var sp = new ServiceCollection()
 .AddTransient<ServiceA>()
 .AddTransient<IServiceB, ServiceB>()
 .BuildServiceProvider();
var service = sp.GetService<ServiceA>();
service.Run();

public class ServiceA(IServiceB serviceb)
{
    public void Run()
    {
        // Use dependency
    }
}

public interface IServiceB
{
    // Service contract
}

public class ServiceB : IServiceB
{
    // Service Implementation
}
```

The most common use of dependency injection is to **[register services](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection#service-registration-methods)**, as in the example above, and define a **constructor** which has parameters for any dependencies. When a service is retrieved using dependency injection, such as from the `ServiceProvider` directly, the dependencies are resolved and ***injected***.

``` cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddTransient<ServiceA>()
    .AddTransient<IServiceB, ServiceB>()
var app = builder.Build();

app.MapGet("/test", (ServiceA service) =>
{
    service.Run();
});

await app.RunAsync();
```

In a .NET Core hosted app, such as Web API or Worker Service, the setup is similar to previously where services are registered in the `IServiceCollection` in the application builder. In the example above, when the minimal API endpoint is hit, `ServiceA` is constructed and injected.

## Using the Factory Pattern with Dependency Injection

Dependency injection is a fantastic tool for centrally building up an application with its dependencies as well as managing the lifecycle of those. So let's now look at how we can apply this to the factory pattern.

``` cs
public class ProductFactory(IEnumerable<IProduct> products)
{
    public static IProduct CreateProduct(string type)
    {
        switch(type)
        {
            case "A": return products.OfType<ProductA>()
                .First();
            case "B": return products.OfType<ProductB>()
                .First();
            default: throw new ArgumentException("Invalid type");
        }
    }
}
```

Dependency injection also allows multiple dependency implementations to be injected into a service using `IEnumerable<T>`. The `ProductFactory` can then be refactored to look like the above to avoid the need to construct the products along with any dependencies they have directly.

``` cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddTransient<IProduct, ProductA>()
 .AddSingleton<IProduct, ProductB>()
 .AddTransient<ProductFactory>();
var app = builder.Build();
app.MapGet("/test", (ProductFactory factory) =>
{
    factory.CreateProduct("A")
});
await app.RunAsync();

public class ProductFactory(IEnumerable<IProduct> products)
{
    public static IProduct CreateProduct(string type)
    {
        switch(type)
        {
            case "A": return products.OfType<ProductA>()
                .First();
            case "B": return products.OfType<ProductB>()
                .First();
            default: throw new ArgumentException("Invalid type");
        }
    }
}
```

Above is a more complete sample of the factory being used in a Web API. There are a few features here so let's break those down:

- Three different `IProduct` implementations are registered with the app, `ProductA` and `ProductB`
- The `ProductFactory` has a constructor parameter of `IEnumerable<IProduct>`. As the products are registered as **implementations** of **service**, when the factory is constructed both of the product implementations are injected
- The `ProductFactory` is registered as a **Transient** service. Typically, factories are regarded as **singletons**. However, as DI is managing the lifetime of the products to be ***created*** we want the factory to pick up whatever products are available at the time
  - **N.B.** Notice `ProductB` is a singleton, the factory would receive the same instance each time, but new instances for `ProductA`. If the factory was a singleton **both products would always be the same**.

### Using the Factory Pattern with DI in the real world

As mentioned at the start, the purpose of this post is to share a recent experience of using the factory pattern. The solution used **[Durable Functions](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-overview?tabs=in-process%2Cnodejs-v3%2Cv1-model&pivots=csharp)** to define the business logic and a factory to handle creating service implementations for the different external APIs.

``` cs
public enum External
{
    ExternalX,
    ExternalY
}

public interface IExternalService
{
    public External External { get; }
    // External operation contract
}

public class ExternalXService(ExternalXSoapApiClient client) : IExternalService
{ 
    public External External => External.ExternalX;

    // Implementation
}

public class ExternalYService(ExternalYRestApiClient client) : IExternalService
{ 
    public External External => External.ExternalY;

    // Implementation
}
```

Each external service needed to support certain processes which I represented with the `IExternalService`. Each service then get their own implementation using whatever authentication and operations are needed to fulfil that process. To help distinguish the different implementations, I added a `External` **enum**.

``` cs
public class ExternalFactory(IEnumerable<IExternalService> externalServices)
{
    public IExternalService GetExternalService(External external)
    {
        var service = externalServices.FirstOrDefault(ps => ps.External == external);
        if (service is null)
            throw new InvalidOperationException();

        return service;
    }
}
```

The `ExternalFactory` then has all the available implementations injected with `GetExternalService` returning the relevant implementation for the specified external.

``` cs
public class Functions(ExternalFactory factory)
{
    private readonly ExternalFactory _factory = factory;

    [Function("HttpCreate")]
    public async Task<IActionResult> RunHttpAsync([HttpTrigger(AuthorizationLevel.Function, "post", Route = "create")] HttpRequest request, [DurableClient] DurableTaskClient durableTaskClient)
    {
        // Deserialize model
        var instanceId = await durableTaskClient.ScheduleNewOrchestrationInstanceAsync("OrchCreate", model);
        return new AcceptedResult();
    }

    [Function("OrchCreate")]
    public async Task RunOrchAsync([OrchestrationTrigger] TaskOrchestrationContext context)
    {
        var model = context.GetInput<CreateModel>();
        try 
        {
            await context.CallActivityAsync("ActivityCreate", model);
        }
        catch (Exception ex)
        {
            // Handle exception from activity
        }
    }

    [Function("ActivityCreate")]
    public async Task RunActivityAsync([ActivityTrigger] CreateModel model)
    {
        var externalService = _externalFactory.GetExternalService(model.External)
        // Call method on externalService
    }
}
```

Above is an abbreviated sample of the factory being used in **Durable Functions**. By using the factory pattern I was able to abstract the business logic of the **orchestrations and activities** from the specific implementations for each external service. It has also given great flexibility to onboard new implementations, without needing to change the business logic.

## Wrapping Up

In this post we've introduced the concepts of the factory pattern as well as some of the benefits. We then had a brief overview of dependency injection and how it can be used with the factory pattern. Using DI can simplify our factory and maintain consistency with the general .NET approach to dependency handling. Lastly, I've shared a few highlights from a recent experience with the factory pattern. I hope this has been of benefit and happy coding!
