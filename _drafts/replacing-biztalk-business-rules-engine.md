---
title: Replacing BizTalk Business Rules Engine
category: Integration
tags:
  - BizTalk
  - BizTalk Server
  - Business Rules Engine
  - BRE
  - Microsoft Rules Engine
  - JSON Rules Engine
  - Rules Engine
  - Rule Engine
  - Rules
---

Having developed on **BizTalk Server** for a number of years, I've used the **[Business Rules Engine (BRE)](https://learn.microsoft.com/en-us/biztalk/core/business-rules-engine)** in numerous solutions via both **orchestration shapes** and the **[BREPipelineFramework](https://github.com/mbrimble/brepipelineframework)**.

![image1](/images/replacing-biztalk-business-rules-engine/image1.png)

The BRE offers fantastic flexibility in being able to **configure** basic business logic instead of having to redeploy the whole application. The configuration could then be quickly and easily deployed and/or rolled back.

However, with migrating away from BizTalk, I've needed to look at replacing the BRE. I opted for the **[Microsoft Rules Engine](https://github.com/microsoft/rulesengine)** and for this post I want to share my experience with it. For disclosure, Microsoft do offer some great documentation in both their **[wiki](https://github.com/microsoft/RulesEngine/wiki) and [GitHub Pages site](https://microsoft.github.io/RulesEngine/)**.

**N.B.** Microsoft have made a direct port of the BRE to the **[Azure Logic Apps Rules Engine](https://learn.microsoft.com/en-us/azure/logic-apps/rules-engine/rules-engine-overview)**. Although this is more of a direct migration path, it's tightly-coupled to Logic Apps, retains the need for XML and is still in preview and so I opted against this option.

## What is the Microsoft Rules Engine?

The Microsoft Rules Engine is an **open-source library [nuget package](https://www.nuget.org/packages/RulesEngine/)** for abstracting business rules and logic in a similar way to what is available in the **BizTalk BRE**. The key features of the library are:

- JSON based rules definition
- Multiple input support
- Dynamic object input support
- C# Expression support
- Extending expression via custom class/type injection
- Scoped parameters
- Post rule execution actions
- Standalone expression evaluator

### Installing

With being a nuget package, the installation is as simple as adding a package to you application/project like below:

``` bash
dotnet add package RulesEngine
```

With being an open source library, this offers great flexibility in how the rules engine can be used and hosted i.e. it can be used in any .NET app which supports .NET Standard 2.0

## Using the Rules Engine

The rules engine revolves around the definition of **workflows** to represent business rules and logic. The rules engine and workflows offer **[many great features and extensibility](#what-is-the-microsoft-rules-engine)**, however, I'm going to focus on a few key aspects:

- Writing Expressions
- Defining Workflows
- Creating Rule Stores
- Creating Custom Actions

### Writing Expressions

Before getting into defining workflows, we need to understand the expressions. Expressions are the foundation of the Microsoft Rules Engine for evaluating both rules and outputs. The core of the rules engine is the `RuleExpressionParser`.

``` csharp
var output = new RuleExpressionParser()
    .Evaluate<string>("3 + input1", new RuleParameter[]
    {
        new RuleParameter("input1", 5)
    }); // output equals 8
```

The `RuleExpressionParser` allows us to evaluate expressions **outside of the rules engine**. In the example above, the expression performs a simple addition with one value provided using a `RuleParameter`.

The syntax used by the expressions is **[Dynamic LINQ expressions](https://dynamic-linq.net/expression-language)** which supports many of the same concepts and features of C# as it's designed to be familiar to C# users.

``` csharp
[Fact]
public void SimpleParameterExpressionTest()
{
    // Act
    var actual = new RuleExpressionParser()
        .Evaluate<string>("\"Hello \" + input1",
        [
            new RuleParameter("input1", "World")
        ]);

    //Assert
    actual.Should()
        .Be("Hello World");
}
```

One use case I find the standalone `RuleExpressionParser` useful for is in unit testing expressions, particularly complex expressions, to help document expressions and highlight issues.

Now that we've looked at expressions, lets look at how they've used in workflows.

### Defining Workflows

A workflow is a **collection of rules** which are executed against 1 or more inputs.

``` json
{
    "WorkflowName": "SampleWorkflow",
    "Rules": [
        {
            "RuleName": "GeneralGrevious",
            "RuleExpressionType": "LambdaExpression",
            "Expression": "input1 == \"Hello there\"",
            "SuccessEvent": "General Kenobi"
        },
        {
            "RuleName": "Droids",
            "RuleExpressionType": "LambdaExpression",
            "Expression": "input1 != \"Hello there\"",
            "SuccessEvent": "These aren't the droids you're looking for"
        }
    ]
}
```

The above workflow compares the ***input1*** with a specified string in an expression. If the expression returns true, the associated `SuccessEvent` is raised. Notice that the string literals are escaped using `\\"`

``` cs
var workflowJson = // workflow definition
var rulesEngine = new RulesEngine.RulesEngine([workflowJson]);

var results = await rulesEngine.ExecuteAllRulesAsync("SampleWorkflow", "Hello there");

var output = string.Empty;
results.OnSuccess(eventName => output = eventName); // Sets output to "General Kenobi"
```

The previous workflow can now be passed into the constructor of `RulesEngine` as an array to load the workflow(s). Under the hood, the json definition(s) are deserialized using `Workflow` instance(s). The rules engine is then executed with the name of the workflow specified and any inputs provided in a **`params` array**. The results are then evaluated and the `.OnSuccess()` delegate used to extract the **SuccessEvent**.

#### Using the JSON Schema

One really useful feature of the rules engine is that the `Workflow` class also has an associated **JSON schema**.

![image2](/images/replacing-biztalk-business-rules-engine/image2.png)

In the above example of defining the **SampleWorkflow**, the `$schema` element is specified at the top of the file. In many code editors, including VS Code, this causes the editor to prompt with intellisense of the members available/expected in the schema definition to help take the guesswork out of defining workflows.

### Creating Rule Stores

In the examples so far, the workflow definitions have been passed directly into the `RulesEngine` constructor to then be executes. However, in a real-world scenario, these workflow definitions need to be persisted somewhere outside of the application.

![image3](/images/replacing-biztalk-business-rules-engine/image3.png)

Microsoft provide the above diagram to represent the recommended setup for using the **RulesEngine**. In essence, Microsoft provide the **RulesEngine** library, but we need to develop our own ***wrapper*** around the library as well as integration to the necessary ***rule stores***.

``` cs
public interface IRuleStore
{
    Task<IEnumerable<Workflow>> GetWorkflowsAsync();
}

public class SampleRuleStore(/* Inject Dependencies */) : IRuleStore
{
    public async Task<IEnumerable<Workflow>> GetWorkflowsAsync()
    {
        // Retrieve and deserialise workflows from storage
    }
}
```

For the rule stores, I decided to create a simple interface to make use of dependency injection. Multiple implementations of `IRuleStore` can then be registered with DI e.g. `builder.Services.AddTransient<IRuleStore, SampleRuleStore>()`.

``` cs
public class RulesEngineWrapper
{
    private readonly IEnumerable<IRuleStore> _ruleStores;

    public RulesEngineWrapper(IEnumerable<IRuleStore> ruleStores /* Other dependencies */)
    {
        _ruleStores = ruleStores;
    }

    public async Task LoadWorkflowsAsync()
    {
        var workflows = new List<Workflow>();
        foreach (var rs in _ruleStores)
        {
            workflows.AddRange(await rs.GetWorkflowsAsync())
        }
        
        // Load workflows into rules engine
    }

    // Other wrapper methods to execute rules
}
```

A collection of rule store implementations can then be injected (whether it be 1 or several), like in the sample ***wrapper service*** above, to allow greater flexibility in storing workflow definitions.

### Creating Custom Actions

## Sample Project

[![milkyware/blog-rules-engine - GitHub](https://gh-card.dev/repos/milkyware/blog-rules-engine.svg?fullname=)](https://github.com/milkyware/blog-rules-engine)

## Wrapping Up
