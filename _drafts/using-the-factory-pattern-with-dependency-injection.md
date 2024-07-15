---
title: Using the Factory Pattern with Dependency Injection
category: Azure
tags:
  - .NET
  - Dotnet
  - Design Patterns
  - Factory Pattern
  - Dependency Injection
---

The **Factory Pattern** is a coding design pattern for creating objects by replacing the need to directly **construct** an object using the `new` operator. Instead, a ***creator*** method is used to handle the creation of instances.

The purpose of this post is to share how I used the factory pattern in a recent project to integrate with several ***partner* APIs** and abstract the integration business logic to allow partners to be added or removed without impacting the business logic.

## Why use the Factory Pattern?

The factory pattern is incredibly useful in scenarios where the **type of an object** is determined at runtime and offers the benefits of:

- Encapsulating the creation logic so that users of the factory don't need to know the logic behind creation
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
    // Service implementation
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

Dependency injection also allows for multiple dependency implementations to be injected into a service using `IEnumerable<T>`. The `ProductFactory` can then be refactored to look like above to avoid the need to directly construct the products along with any dependencies they have.

## Wrapping Up
