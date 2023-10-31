---
title: Documenting Nullables in Azure Function OpenAPI
header:
  image: '/images/documenting-nullables-in-azure-function-openapi/header.png'
category: Integration
tags:
  - Azure Function
  - OpenAPI
  - Swagger
---

This post is about an issue a colleague and I encountered recently whilst developing a series of **layered APIs**. The issue was that nullable properties weren't being documented correctly resulting in deserialization errors in the clients and I wanted to share how we fixed it as well as the resources used.

## The scenario

![image1](/images/documenting-nullables-in-azure-function-openapi/image1.png)

As a brief description of what layered APIs are, it's a methodology known as **[API-Led Connectivity (ALC)](https://www.salesforce.com/blog/api-led-connectivity/)** of creating reusable APIs in 3 broad categories:

- Accessing system data
- Composing processes
- Delivering user experiences

In this scenario, several ***system APIs*** were developed to wrap around backend databases and datasets with a ***process API*** orchestrating these to represent the business processes. All of these APIs are documented using **[Azure Function OpenAPI Extensions](https://github.com/Azure/azure-functions-openapi-extension)** which would then be fronted by an APIM instance and consumed as a client.

## The issue with nullables

By default, the Azure Function Open API extensions use **[Swagger v2](https://github.com/Azure/azure-functions-openapi-extension/blob/ab184cbf3c8ff16378cfa00fa1cb23cb58ac1727/docs/openapi.md#configure-openapi-information)** which **[DOES NOT support null](https://dev.to/frolovdev/openapi-spec-swagger-v2-vs-v3-4o7c)**.

``` cs
public class Address
{
    public string UPRN { get; set; }
    public string DisplayAddress { get; set; }
    public string Postcode { get; set; }
    public int? Floor { get; set; }
}
```

Some of the models in the **system APIs** contain **nullable properties** which aren't documented properly in the **auto-generated clients**. In the example model above, **Floor** would be documented as non-nullable, which for auto-generated clients, will cause deserialization exceptions if a null is received.

``` json
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet",

        "OPENAPI__VERSION": "v3"
    }
}
```

After some research, we came across the limitations of **Swagger v2** with nullables and the defaults of the OpenAPI extensions. The config for these extensions can be modified using environment variables, however, these are typically defined in **local.settings.json** which often are ignored in Git repos resulting in the config being reset when being cloned.

``` cs
public class Startup : FunctionsStartup
{
    public override void Configure(IFunctionsHostBuilder builder)
    {
            builder.Services.AddSingleton<IOpenApiConfigurationOptions>(new DefaultOpenApiConfigurationOptions
            {
                OpenApiVersion = OpenApiVersionType.V3
            });
    }
}
```

The OpenAPI options can also be **[overridden using code]((https://github.com/Azure/azure-functions-openapi-extension/blob/ab184cbf3c8ff16378cfa00fa1cb23cb58ac1727/docs/openapi.md#configure-openapi-information))** to ensure that the OpenAPI version config is committed and remains fixed.

``` yaml
components:
  schemas:
    address:
      type: object
      properties:
        uprn:
          type: string
        displayAddress:
          type: string
        postcode:
          type: string
        floor:
          type: integer
          format: int32
          nullable: true
```

Above is the resulting OpenAPI model with **OpenAPI v3** enabled. For our **system APIs**, this resulted in the auto-generated clients being corrected and the **process API** not throwing serialization exceptions.

## Summing up

Although the actual config to fix this issue wasn't big, it was the result  of several factors including:

- OpenAPI extension defaults
- Limitations of Swagger v2
- Auto-generated clients

Due to this it took some research to get to the bottom of the issue and wanted this post to bring together our findings and some references.
