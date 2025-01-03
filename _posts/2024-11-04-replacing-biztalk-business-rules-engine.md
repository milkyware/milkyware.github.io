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

Having developed on **BizTalk Server** for many years, I've used the **[Business Rules Engine (BRE)](https://learn.microsoft.com/en-us/biztalk/core/business-rules-engine)** in numerous solutions via both **orchestration shapes** and the **[BREPipelineFramework](https://github.com/mbrimble/brepipelineframework)**.

![image1](/images/replacing-biztalk-business-rules-engine/image1.png)

The BRE offers fantastic flexibility in configuring basic business logic instead of redeploying the whole application. The configuration can then be quickly and easily deployed and/or rolled back.

However, with migrating away from BizTalk, I've needed to look at replacing the BRE. I opted for the **[Microsoft Rules Engine](https://github.com/microsoft/rulesengine)**, and for this post, I want to share my experience with it. For disclosure, Microsoft offers some great documentation in both their **[wiki](https://github.com/microsoft/RulesEngine/wiki) and [GitHub Pages site](https://microsoft.github.io/RulesEngine/)**.

**N.B.** Microsoft has made a direct port of the BRE to the **[Azure Logic Apps Rules Engine](https://learn.microsoft.com/en-us/azure/logic-apps/rules-engine/rules-engine-overview)**. Although this is more of a direct migration path, it's tightly coupled to Logic Apps, retains the need for XML and is still in preview so I opted against this option.

## What is the Microsoft Rules Engine?

The Microsoft Rules Engine is an **open-source library [nuget package](https://www.nuget.org/packages/RulesEngine/)** for abstracting business rules and logic in a similar way to what is available in the **BizTalk BRE**. The key features of the library are:

- JSON-based rules definition
- Multiple input support
- Dynamic object input support
- C# Expression support
- Extending expression via custom class/type injection
- Scoped parameters
- Post-rule execution actions
- Standalone expression evaluator

### Installing

With being a Nuget package, the installation is as simple as adding a package to your application/project like below:

``` bash
dotnet add package RulesEngine
```

Being an open-source library, this offers great flexibility in how the rules engine can be used and hosted i.e. it can be used in any .NET app which supports .NET Standard 2.0

## Using the Rules Engine

The rules engine revolves around the definition of **workflows** to represent business rules and logic. The rules engine and workflows offer **[many great features and extensibility](#what-is-the-microsoft-rules-engine)**, however, I'm going to focus on a few key aspects:

- Writing Expressions
- Defining Workflows
- Creating Rule Stores
- Creating Custom Actions

### Writing Expressions

Before getting into defining workflows, we need to understand the expressions. Expressions are the foundation of the Microsoft Rules Engine to evaluate both rules and outputs. The core of the rules engine is the `RuleExpressionParser`.

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

Now that we've looked at expressions, let's look at how they've been used in workflows.

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

The previous workflow can now be passed into the constructor of `RulesEngine` as an array to load the workflow(s). Under the hood, the JSON definition(s) is deserialized using `Workflow` instance(s). The rules engine is then executed with the name of the workflow specified and any inputs provided in a **`params` array**. The results are then evaluated and the `.OnSuccess()` delegate is used to extract the **SuccessEvent**.

### Defining Post-Rule Actions

In the **[previous workflow example](#defining-workflows)** we looked at defining a basic workflow with a **success event** which we can then access using the `.OnSuccess()` extension (the inverse be achieved with the `.OnFail()` extension).

``` json
{
    "WorkflowName": "SampleWorkflow",
    "Rules": [
        {
            "RuleName": "GeneralGrevious",
            "RuleExpressionType": "LambdaExpression",
            "Expression": "input1 == \"Hello there\"",
            "Actions": {
                "OnSuccess": {
                    "Name": "OutputExpression",
                    "Context": {
                        "Expression": "input1 + \" General Kenobi\""
                    }
                },
            }
        }
        // Additional rule definitions
    ]
}
```

However, the success/fail delegate extensions require the delegate to be defined in code. A more flexible alternative is to define **actions** for **OnSuccess/OnFailure** where we can use the inbuilt **OutputExpression** to define a LINQ expression, with access to the same inputs and C# tooling used in the defining rules, to execute on either success or failure. In the above example, if the input is **Hello there** the workflow returns a concatenated string.

#### Using the JSON Schema

One really useful feature of the rules engine is that the `Workflow` class also has an associated **JSON schema**.

![image2](/images/replacing-biztalk-business-rules-engine/image2.png)

In the above example of defining the **SampleWorkflow**, the `$schema` element is specified at the top of the file. In many code editors, including VS Code, this causes the editor to prompt with the intellisense of the members available/expected in the schema definition to help take the guesswork out of defining workflows.

### Creating Rule Stores

In the examples so far, the workflow definitions have been passed directly to the `RulesEngine` constructor and are in turn executed. However, in a real-world scenario, these workflow definitions need to be persisted somewhere outside of the application.

![image3](/images/replacing-biztalk-business-rules-engine/image3.png)

Microsoft provides the above diagram to represent the recommended setup for using the **RulesEngine**. In essence, Microsoft provides the **RulesEngine** library, but we need to develop our own ***wrapper*** around the library as well as integration to the necessary ***rule stores***.

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

Another powerful feature of the Rules Engine is the ability to extend the workflows with **[custom actions](https://microsoft.github.io/RulesEngine/#custom-actions)**.

``` cs
public class OutputExpressionAction : ActionBase
{
    private readonly RuleExpressionParser _ruleExpressionParser;

    public OutputExpressionAction(RuleExpressionParser ruleExpressionParser)
    {
        _ruleExpressionParser = ruleExpressionParser;
    }

    public override ValueTask<object> Run(ActionContext context, RuleParameter[] ruleParameters)
    {
        var expression = context.GetContext<string>("expression");
        return new ValueTask<object>(_ruleExpressionParser.Evaluate<object>(expression, ruleParameters));
    }
}
```

The **[OutputExpression](https://github.com/microsoft/RulesEngine/blob/4ca3cc2b0a5d7af209404ab8767718d0df7ea960/src/RulesEngine/Actions/ExpressionOutputAction.cs)** we used **[earlier](#defining-post-rule-actions)** is actually an inbuilt example of a custom action.

``` cs
public class SampleAction : ActionBase
{
    private const string ContextKeyName = "Name";
    private readonly ILogger<SampleAction> _logger;

    public SampleAction(ILogger<SampleAction> logger)
    {
        _logger = logger;
    }

    public override ValueTask<object> Run(ActionContext context, RuleParameter[] ruleParameters)
    {
        _logger.LogInformation("Executing sample action");
        var name = context.GetContext<string>(ContextKeyName);
        return new ValueTask<object>($"Hello {name}");
    }
}
```

Defining a custom action is as simple as creating a new class and implementing the abstract class `ActionBase`. The above action looks for a value in the context called `Name` and uses it to format a string. Multiple context properties can be configured to act as arguments in more complex actions. Also, notice that `ILogger` is provided to the constructor, like with the rule stores, as we can combine this with dependency injection.

``` cs
builder.Services.AddTransient<SampleAction>();

builder.Services.AddSingleton<Tuple<string, Func<ActionBase>>>(sp => new("SampleAction", () => sp.GetRequiredService<T>()));

builder.Services.AddTransient<IRulesEngine, RulesEngine>(sp => {
    var customActions = sp.GetServices<Tuple<string, Func<ActionBase>>>();
    var settings = new ReSettings()
    {
        CustomActions = customActions.ToDictionary(ca => ca.Item1, ca => ca.Item2)
    };

    var rulesEngine = new RulesEngine.RulesEngine(settings);
    return rulesEngine;
})
```

To integrate the custom actions with dependency injection there is a little bit more involved, so let's break down what the above is doing:

1. Register the custom action type with the service collection (along with any other necessary dependencies)
2. Register a **reference tuple** of the name of the action (referenced in workflow definitions) and a delegate to retrieve an action instance from DI
3. As part of registering the rules engine with DI, retrieve the collection of tuples and map to a dictionary to configure `ReSettings.CustomActions` in the engine

``` json
{
    "$schema": "https://raw.githubusercontent.com/microsoft/RulesEngine/main/schema/workflow-schema.json",
    "WorkflowName": "SampleActionWorkflow",
    "Rules": [
        {
            "RuleName": "Sample",
            "RuleExpressionType": "LambdaExpression",
            "Expression": "true",
            "Actions": {
                "OnSuccess": {
                    "Name": "SampleAction",
                    "Context": {
                        "Name": "Fred"
                    }
                }
            }
        }
    ]
}
```

The custom action can then be referenced like above, notice that `$.Rules[0].Actions.OnSuccess.Name` element is set to **SampleAction**, the same as what is configured in the DI in the previous sample.

## Sample Project

I've put together the below sample project to demonstrate the concepts and features we've discussed through this post.

[![milkyware/blog-rules-engine - GitHub](https://gh-card.dev/repos/milkyware/blog-rules-engine.svg?fullname=)](https://github.com/milkyware/blog-rules-engine)

The sample exposes the rules engine through a generic swagger documented WebAPI endpoint to make it easier to interact with.

**N.B.** Due to the generic ***post object body*** of the WebAPI endpoint, the request body is handled as a `JsonNode` which results in the expressions in the workflow using functions such as `string()` to handle typing correctly or indexers to access child members on a JSON object.

In addition, I've also added a basic **[builder pattern](https://refactoring.guru/design-patterns/builder)** to improve the setup of the rules engine as well as some unit tests to demonstrate automating the testing of more complex expressions.

## Wrapping Up

This has been a bit of a longer post and one I've been meaning to do for a while as, having used the BizTalk rules engine, having a configurable rules engine is an incredibly powerful tool to have at your disposal. In this post we've introduced some of the key features of the JSON-based Microsoft Rules Engine as well as how we can extend the library through rule stores and custom actions to create a solution comparable to the BizTalk Business Rules Engine. I hope you find this article useful and thanks for reading.
