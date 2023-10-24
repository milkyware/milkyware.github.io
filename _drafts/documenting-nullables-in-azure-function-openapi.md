---
title: Documenting Nullables in Azure Function OpenAPI
header:
  image: '/images/documenting-nullables-in-azure-function-openapi/header.png'
category: Integration
tags:
  - Azure Function
  - OpenAPI
---

This post is about an issue me and a colleague encountered recently whilst developing a series of **layered APIs**. The issue was that nullable properties weren't being documented correctly resulting in deserialization errors in the proxy clients and I wanted to share how we fixed it as well as the resources used.

## The scenario

As a brief description of what layered APIs are, it's a methodology known as **[API-Led Connectivity (ALC)](https://www.salesforce.com/blog/api-led-connectivity/)** of creating reusable APIs in 3 broad categories:

- Accessing system data
- Composing processes
- Delivering user experiences

In this scenario a number of ***system APIs*** were developed to wrap around backend databases and datasets with a ***process API*** orchestrating these to represent the business processes. All of these APIs are documented using **[Azure Function OpenAPI Extensions](https://github.com/Azure/azure-functions-openapi-extension)** which would then be fronted by an APIM instance and consumed as a proxy client.

## The issue with nullables

## Summing up
