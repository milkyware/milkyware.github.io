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

## Using the Factory Pattern with Dependency Injection

Typically, the factory handles the creation of objects, however, with modern .NET we have **dependency injection** available to us to handle that. So how can the factory pattern be combined with dependency injection?

``` cs
var host = new HostBuilder()
    .ConfigureServices(services => 
    {
        services.AddTransient<ServiceA>();
        services.AddTransient<ServiceB>()
    }).Build();

public class ServiceA(ServiceB serviceb)
{
    // Methods using dependency
}
```

The most common use of dependency injection is to **[register services](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection#service-registration-methods)**, as in the example above, and define a **constructor** which has parameters for any dependencies.

## Wrapping Up
