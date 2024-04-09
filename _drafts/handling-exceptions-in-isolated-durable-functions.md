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

In in-process Durable Functions, any exceptions which occurred in activity functions are passed back to the parent orchestration wrapped in a `FunctionFailedException`. However, in isolated Durable Functions this has changed.

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

In traditional exception handling, the catch block would be customised to catch types of exception e.g. `(catch InvalidOperationException ex) {}`

``` cs
try
{
    // Call activity which throws exception
}
catch (TaskFailedException ex) when (ex.FailureDetails.IsCausedBy<InvalidOperationException>())
{
    // Handle invalid operation
}
```

In traditional exception handling, the catch block would be customised to catch certain exception types. As `TaskFailedException` doesn't contain the inner exception, the `.IsCausedBy<T>()` method is available on the `FailureDetails` property.

**N.B.** `.IsCausedBy<T>()` should not be confused with `.IsCausedByException<T>()` on TaskFailedException as this method is not deprecated.

### FailureDetails formatting issues

Whilst working with the `TaskFailedException`, one issue I've noticed is that `FailureDetails.ErrorMessage`

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
