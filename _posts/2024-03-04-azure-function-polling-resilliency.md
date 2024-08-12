---
title: Azure Function Polling Resiliency
category: Integration
tags:
  - Azure Function
  - Resiliency
  - Retries
  - Error Handling
---

Polling is a common integration pattern for extracting data from one system to integrate it into another. Azure Functions makes implementing the scheduling incredibly easy with the **TimerTrigger** binding.

``` cs
[Function(nameof(TimerFunction))]
public async Task RunAsync([TimerTrigger("0 */5 * * * *")] TimerInfo timerInfo)
{
    // Polling logic
}
```

If a poll fails, particularly infrequent polling, it can cause added strain on subsequent polls as well as delays in data integration. The purpose of this post is to highlight an Azure Function feature I recently came across to improve resiliency whilst polling.

## Azure Function Retry Policies

There are already many ways to improve code resiliency in .NET from **[Polly](https://github.com/App-vNext/Polly)** to in-built retry logic in many SDKs such as **[Azure Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-retry-policy)** and **[SQL Client](https://learn.microsoft.com/en-us/sql/connect/ado-net/configurable-retry-logic-sqlclient-introduction?view=sql-server-ver16)** and many more. However, Azure Functions includes a feature called **[Retry Policies](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-error-pages?tabs=fixed-delay%2Cisolated-process&pivots=programming-language-csharp#retry-policies)** which provides a simple way, at the function-level, to configure a retry policy.

``` cs
[Function(nameof(TimerFunction))]
[FixedDelayRetry(5, "00:00:10")]
public async Task RunFixedAsync([TimerTrigger("0 */5 * * * *")] TimerInfo timerInfo)
{
    // Polling logic
}

[Function(nameof(TimerFunction))]
[ExponentialBackoffRetry(5, "00:00:04", "00:15:00")]
public async Task RunExpoAsync([TimerTrigger("0 */5 * * * *")] TimerInfo timerInfo)
{
    // Polling logic
}
```

There are 2 flavours of retry policy, **FixedDelayRetry** and **ExponentialBackoffRetry** which do what they say on the tin. What I particularly like is that with a single line of code, a simple and effective retry policy can be configured which spans all of the logic in the timer function. As with any retry policy, idempotency needs to be considered to ensure data isn't duplicated.

### Something to note

One thing to note about retry policies is that were are [known circumstances](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-error-pages?tabs=fixed-delay%2Cisolated-process&pivots=programming-language-csharp#max-retry-counts) where the retries attempted could be more or less, if at all. Microsoft provides this retry behaviour as **best efforts**.

## Wrapping up

Although Azure Function retry policies are best efforts, their sheer simplicity makes them a worthwhile consideration in future polling integrations. When coupled with other retry and resiliency patterns such as those mentioned at the outset and including persistence, this can result in a very resilient integration solution.
