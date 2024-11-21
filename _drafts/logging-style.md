---
title: My Approach to Logging
category: .NET
tags:
  - Dotnet
  - .NET
  - Logging
  - Structure Logging
  - ILogger
---

Logging is an essential part of software development that provides a record of events and activities within an application. It allows both developers and support teams to track an application's behaviors, diagnose issues, monitor performance, and troubleshoot bugs. Detailed log data can give great visibility into how an application is running, this in turn makes it easier to maintain and improve. For this post, I want to share my personal approach to logging which I've found strikes a balance between having detailed logs without being unnecessarily chatty.

## Why Log?

There are many reasons to add logging to your code, 4 key reasons are:

1. **Debugging and Troubleshooting**: Captures events that can help pinpoint issues and understand what led to them
2. **Monitoring Application Health**: Offers real-time insight into the state of an application and enabling proactive monitoring of errors, crashes, and unusual patterns
3. **Audit and Compliance**: Provides a history of key activities which can be useful for security, auditing, and compliance purposes
4. **Performance Optimization**: Logging execution times and performance metrics, bottlenecks can be identified and resolved

## Using ILogger

In C#, the `ILogger` interface is a standard feature of modern .NET applications. It enables flexible logging as well as seamless integration with dependency injection and is available in most project templates to start logging **out-of-the-box**. Here’s an example of how to inject `ILogger` and utilize different log levels in a service class:

``` cs
using Microsoft.Extensions.Logging;
using System;

namespace LoggingExample
{
    public class MyService
    {
        private readonly ILogger<MyService> _logger;
        private readonly IThirdPartyLibrary _thirdPartyLibrary;

        // Inject ILogger and other dependencies via constructor
        public MyService(ILogger<MyService> logger, IThirdPartyLibrary thirdPartyLibrary)
        {
            _logger = logger;
            _thirdPartyLibrary = thirdPartyLibrary;
        }

        // Example of using logging in a method
        public void ProcessData()
        {
            // Log at the start of the method
            _logger.LogInformation("ProcessData started.");

            try
            {
                // Debug log before calling a third-party library
                _logger.LogDebug("Calling third-party library method GetData.");

                var data = _thirdPartyLibrary.GetData();

                // Trace log to capture the value of 'data'
                _logger.LogTrace("Data received from third-party library: {Data}", data);

                // Process the data and log key variables
                var processedData = ProcessReceivedData(data);

                // Trace log to capture processed data state
                _logger.LogTrace("Processed data: {ProcessedData}", processedData);

                // Log at the end of the method
                _logger.LogInformation("ProcessData completed successfully.");
            }
            catch (Exception ex)
            {
                // Error log with exception details
                _logger.LogError(ex, "An error occurred in ProcessData.");

                // Rethrow the exception to preserve the stack trace
                throw;
            }
        }

        private string ProcessReceivedData(object data)
        {
            // Example of processing the data (placeholder logic)
            _logger.LogDebug("Processing received data.");

            // Key variable (processedData) traced for debugging
            string processedData = data.ToString() + "_processed";
            _logger.LogTrace("Intermediate processed data: {ProcessedData}", processedData);

            return processedData;
        }
    }
}
```

A few key features to highlight are:

- **Information** logs are used at the start and end of `public` methods
- **Debug** logs are using ***during*** `public` methods as well as at the start of `private` methods. They are also used when calling out to external code, such as 3rd party libraries or APIs
- **Error** logs are used in catch blocks for unhandled exceptions with the full exception being passed to the log, as well as a message to give context
  - Although not shown, I've often used **Information or Warning** for handled exceptions
- **Trace** logs are used to record key data/state in the code

As mentioned, there are a number of logging levels available by default, the levels available are:

1. Critical
2. Error
3. Warning
4. Information
5. Debug
6. Trace

Using a variety of log levels allows us to categorise different events into different levels of importance. When logs of all levels are presented together, we can see a detail log of an application. These categories also allow us to ***dial up/down*** the level of logging and exclude less critical logs in different scenarios. For example, gathering logs of all levels would be particularly useful in a **development setting**, however, **in production** it may be better to limit the logs to **information or warning** to avoid overly chatty logs which could contain sensitive details or quickly balloon the storage for the logs.

``` json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "LoggingExample": "Trace",
      // Other logging category log levels
    }
  },
  // Other app settings
}
```

A typical ASP.NET Core application will often have a section in the **appsettings.json** similar to above. Rather than cover it here, Microsoft provide really detailed **[docs on how to configure logging](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging/?view=aspnetcore-9.0#configure-logging)**. In short, configuring logging through appsettings or environment variables allows us to ***dial up and down*** logging.

### Structured Logging

Another feature of the default implementation of `ILogger` is **structured logging**. In the code example you may have noticed logs such as `_logger.LogTrace("Data received from third-party library: {Data}", data);`. Notice that rather than building a string or using **[string interpolation](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/interpolated)**, a formatted string is provided as the message with a **placeholder**: `{Data}`. A value for the placeholder is then provided using the `data` variables in the params array.

### Using Scopes for Contextual Logging

I've also started to make greater use of logging scopes with `ILogger`. A scope enables logged events within a certain block to inherit shared context, making it easier to follow related events in the logs. This is particularly useful in tracing the flow of data through nested methods.

```csharp
public void ProcessOrder(int orderId)
{
    // Create a logging scope with contextual information
    using (_logger.BeginScope("OrderProcessing {OrderId}", orderId))
    {
        _logger.LogInformation("Starting order processing.");

        try
        {
            // Example of scoped logging context
            _logger.LogDebug("Loading order details.");
            var orderDetails = LoadOrder(orderId);

            _logger.LogDebug("Order details loaded: {OrderDetails}", orderDetails);

            // Pass the order to fulfillment
            FulfillOrder(orderDetails);
            _logger.LogInformation("Order processing completed successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred while processing order {OrderId}", orderId);
            throw;
        }
    }
}
```

With `BeginScope`, any log statements within the `ProcessOrder` method (and within methods it calls) will include `{OrderId}` as context, allowing you to trace logs related to this specific order processing session. This is especially beneficial in multi-threaded or high-volume environments where tracking specific workflows is critical.

### Structured Logging and Additional Logging Levels

1. **Structured Logging**: Structured logging allows you to log data in a structured format, making it easier to search, parse, and analyze logs. Using `{PropertyName}` syntax, you can capture variables and metadata in a way that is both human-readable and machine-parsable for log aggregation tools.

2. **Additional Log Levels**:
   - **Warning** (`LogWarning`): This level is used to flag potentially harmful situations, like deprecated APIs, which don’t cause immediate failure but might need attention.
   - **Critical** (`LogCritical`): Reserved for severe issues that require immediate attention, such as a system or application failure.

3. **Logging Standards as Principles**:
   - The standards outlined here provide guidance for structuring logging but are not rigid rules. While it's beneficial to use consistent logging levels, the main objective is to capture important points in the code where logging adds value.
   - The use of log levels (e.g., `Debug`, `Error`, `Information`) is a guideline; however, the critical focus should be on ensuring meaningful code points are logged.

### Conclusion

To summarize the key points:

- Use **Information** logs at the start and end of significant methods.
- Use **Debug** logs around third-party calls and helper methods.
- Use **Error** logs for exceptions, capturing details while rethrowing for higher-level handling.
- Use **Trace** logs to capture key variable values at critical stages.
- **Scopes** can enhance context for related log events, improving traceability.
- **Structured logging** and higher log levels (Warning, Critical) are available to add further detail and control over the logging flow.

The logging levels suggested here serve as a guideline rather than a strict rule; the essential takeaway is that critical points in the code should be logged for clarity, insight, and maintainability.