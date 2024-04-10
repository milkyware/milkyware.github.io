---
title: Handling Exceptions in Isolated Durable Functions
category: Integration
tags:
  - Azure Function
  - Durable Functions
  - Isolated Durable Functions
  - Exception Handling
  - Error Handling
---

Exception handling is common place to attempt some functionality and, should exceptions occur, carry out some remedial function. Typically this might be to do things such as logging or rolling back.

## Understanding the TaskFailedException

In in-process Durable Functions, any exceptions which occur when executing an activity function or sub-orchestration are passed back to the parent orchestration wrapped in a `FunctionFailedException`. However, in isolated Durable Functions this has changed.

``` cs
[Function(nameof(OrchSample))]
public async Task RunAsync([OrchestrationTrigger] TaskOrchestrationContext context)
{
    try
    {
        await context.CallActivityAsync(nameof(ActivityThrowInvalidOperation));
    }
    catch (TaskFailedException ex)
    {
        // Handle exception
    }
}
```

Due to issues with serializing, `FunctionFailedException` was replaced with [`TaskFailedException`](https://learn.microsoft.com/en-us/dotnet/api/microsoft.durabletask.taskfailedexception?view=durabletask-dotnet-1.x) in the newer isolated Durable Functions. A key feature of the new exception is the inclusion of the `FailureDetails` property which gives a representation of the underlying exception including:

- ErrorMessage
- ErrorType (Fully-Qualified name as a string)
- StackTrace

## Handling Exceptions in Isolated Durable Functions

In traditional exception handling, the catch block could be customised to catch different types of exception e.g. `(catch InvalidOperationException ex) {}`

``` cs
try
{
    // Call activity which throws exception
}
catch (TaskFailedException ex) when (ex.FailureDetails.IsCausedBy<InvalidOperationException>())
{
    // Handle invalid operation
}
catch (TaskFailedException ex) when (ex.FailureDetails.IsCausedBy<TimeoutException>())
{
    // Handle timeout
}
```

As `TaskFailedException` effectively represents all exceptions from activities or sub-orchestrations we need to handle the exceptions differently. The `.IsCausedBy<T>()` method is available on the `FailureDetails` property to replicate the functionality of handling different exception types. When this is combined with **[exception filters](https://learn.microsoft.com/en-us/dotnet/standard/exceptions/using-user-filtered-exception-handlers)**, this results in exception handling which is similar to the traditional approach.

**N.B.** `.IsCausedBy<T>()` should not be confused with `.IsCausedByException<T>()` on the TaskFailedException itself as this method is now deprecated.

### FailureDetails formatting issues

Whilst working with the `TaskFailedException`, one issue I've noticed is that `FailureDetails.ErrorMessage` only contains the first line of an exception message.

``` cs
[Function(nameof(RunOrch))]
public async Task RunOrch([OrchestrationTrigger] TaskOrchestrationContext context)
{
    try
    {
        await context.CallActivityAsync(nameof(RunActivity));
    }
    catch (TaskFailedException ex)
    {
        _logger.LogInformation("ErrorMessage: {message}", ex.FailureDetails.ErrorMessage);
    }
}

[Function(nameof(RunActivity))]
public void RunActivity([ActivityTrigger] TaskActivityContext context)
{
    throw new InvalidOperationException($"A really bad error{Environment.NewLine}More detail you can't see");
}
```

For example, given the example above where an exception is thrown with 2 lines in the message, the log will look like below:

``` cmd
[2024-04-10T21:57:50.215Z] ErrorMessage: A really bad error
```

From my troubleshooting, this seems to be related to how isolated Azure Functions **[throw exceptions](https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide?tabs=windows#logging)** and may wrap them in an `RpcException`.

``` cs
var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureServices(services =>
    {
        services.Configure<WorkerOptions>(configure =>
        {
            configure.EnableUserCodeException = true;
        });
    })
    .Build();
```

To remove the additional wrapping of exceptions, you can enable the **EnableUserCodeException**. The example uses the **IOptions .Configure() extension method** as this works for both the default isolated Azure Functions as well as the ASP.NET Core integrated.

``` cmd
[2024-04-10T22:21:36.256Z] ErrorMessage: A really bad error
[2024-04-10T22:21:36.258Z] More detail you can't see
```

With this setting enabled, rerunning the sample orchestration will produce logs similar to above.

**WARNING:** Enabling user code exceptions, although fixing multi-line exceptions messages, does seem to have the side-effect of causing `FailureDetails.ErrorType` to always return **(unknown)** which does cause the `IsCausedBy<T>()` functionality to break.

## BONUS: Workaround to include properties from custom exceptions

In a recent project I created a custom exception to represent errors in business logic. This exception included properties to hold values relating to the error. However, when this exception was summarised in a `TaskFailedException`, the message was retained but the properties were lost.

``` cs
public class CustomException : Exception
{
    // Constructors

    public string? CustomString { get; }

    public int? CustomInt { get; set; }

    public override string Message
    {
        get
        {
            var sb = new StringBuilder();

            if (!string.IsNullOrWhiteSpace(base.Message))
                sb.AppendLine(base.Message);

            if (!string.IsNullOrWhiteSpace(CustomString))
                sb.AppendLine($"{nameof(CustomString)}={CustomString}");

            if (CustomInt is not null)
                sb.AppendLine($"{nameof(CustomInt)}={CustomInt}");

            return sb.ToString();
        }
    }
}
```

As only the message is retained, my workaround to retain the properties was to override the `Message` property of the exception and reformat it to include the extra values. Overriding the message instead of `.ToString()` retains the native formatting of exceptions which is what's used to build the FailureDetails of TaskFailedException.

## Wrapping Up
