---
title: Adding OpenAPI Service References
header:
  image: '/images/integrating-with-flat-files/header.svg'
category: Integration
---

As an integration developer, one of the most common requirements I deal with is **consuming APIs** to integrate with different systems. There is still a wide variety of API types from older **SOAP** services to modern **[GraphQL](https://graphql.org/) and [gRPC](https://grpc.io/)** services. The most common style of API is use currently is **RESTful HTTP** APIs documented using **Swagger/OpenAPI documents**.

## What is OpenAPI?

As a brief history of **OpenAPI**, it began as an open-source project known as **Swagger** in 2010. This project was eventually taken over by **SmartBear** in 2015 with the **specification** of the Swagger project split out into a new open-source initiative known as **OpenAPI** backed by various tech organisations. Today, both Swagger and OpenAPI are used synonymously to refer to the documentation of RESTful APIs.

**OpenAPI** is a specification for defining the functionality of a **RESTful API** including:

- operations available
- data structures schemas
- authentication
- versioning
- etc

All of this is to make developing and consuming these APIs easier. An OpenAPI document is the equivalent of a **[WSDL](https://www.soapui.org/docs/soap-and-wsdl/working-with-wsdls/)** for documenting the operations and data structures of a SOAP API.

## Adding a Service Reference

This post is focused on consuming an API using the **service references** functionality in Visual Studio to generate a **proxy client** as it is my preferred option and works great in most cases. However, there are other ways of consuming APIs such as using the **HttpClient** manually or **[RestSharp](https://restsharp.dev/)** which I use if an OpenAPI document is unavailable or if some operations are particularly complex.

## Injecting the Proxy Client

## Sum up
