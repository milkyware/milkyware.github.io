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
  - Rules
---

Having developed on **BizTalk Server** for a number of years, I've used the **[Business Rules Engine (BRE)](https://learn.microsoft.com/en-us/biztalk/core/business-rules-engine)** in numerous solutions via both **orchestration shapes** and the **[BREPipelineFramework](https://github.com/mbrimble/brepipelineframework)**.

![image1](/images/replacing-biztalk-business-rules-engine/image1.png)

The BRE offers fantastic flexibility in being able to **configure** basic business logic instead of having to redeploy the whole application. The configuration could then be quickly and easily deployed and/or rolled back.

However, with migrating away from BizTalk, I've needed to look at replacing the BRE. I opted for the **[Microsoft Rule Engine](https://github.com/microsoft/rulesengine)** and for this post I want to share my experience with it.

**N.B.** Microsoft have made a direct port of the BRE to the **[Azure Logic Apps Rules Engine](https://learn.microsoft.com/en-us/azure/logic-apps/rules-engine/rules-engine-overview)**. Although this is more of a direct migration path, it retains the need for XML and is still in preview at the time of writing.

## Introducing Microsoft Rules Engine

### Creating Custom Actions

### Creating Rule Stores

## Wrapping Up