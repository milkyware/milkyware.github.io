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

The rules engine has **[many great features](#what-is-the-microsoft-rules-engine)**, however, I'm going to focus on a few key area

### Writing Expressions

### Writing Workflow Definitions

### Creating Rule Stores

### Creating Custom Actions

## Sample Project

[![milkyware/blog-rules-engine - GitHub](https://gh-card.dev/repos/milkyware/blog-rules-engine.svg?fullname=)](https://github.com/milkyware/blog-rules-engine)

## Wrapping Up
