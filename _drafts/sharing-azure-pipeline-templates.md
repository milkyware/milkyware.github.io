---
title: Sharing Azure Pipeline Templates
header:
  image: 'images/sharing-azure-pipeline-templates/header.webp'
category: DevOps
tags:
  - Azure
  - Azure Pipelines
  - DevOps
---

## Sharing Azure Pipeline Templates

I have been developing build and release pipelines since **Team Foundation Server 2015** to deploy ASP.NET and BizTalk Server applications. Over the past couple of years, I've migrated to using **[Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/user-guide/what-is-azure-devops?view=azure-devops)** source control and pipelines. As the number of pipelines has grown, I've started to develop **[Azure Pipeline Templates](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops)** to make reusable blocks of automation to simplify and improve the consistency across the pipelines. In this post, I'll give an introduction to **Azure Pipeline Templates** as well as how to share these between multiple repos.

## What are Azure Pipelines?

**Azure Pipelines** automate the building, testing and delivery of code. Pipelines are typically used for **Continuous Integration (CI)** to run tests automatically when code is committed and pushed, and **Continuous Delivery (CD)** to deploy code through different environments to allow users to test delivered code quicker.

![image1](/images/sharing-azure-pipeline-templates/image1.png)

In recent years there has been a shift to defining pipelines using **YAML** to allow these pipelines to be included in source control to benefit from tracking changes in the definition as well as using your existing **Pull Request (PR)** process. Below is the YAML definition for the above pipeline summary.

<!-- {% raw %} -->
``` yaml
name: $(Date:yy.MM.dd)$(Rev:.rr)

stages:
  - stage: Build
    jobs:
      - job: 
        steps:
          - bash: echo 'Bulding'

          - task: Bash@3
            displayName: Print environment variables
            inputs:
              script: env | sort
              targetType: inline

  - stage: DeployCodeDev
    jobs:
      - job: 
        steps:
          - bash: echo 'DeployCodeDev'

  - stage: DeployCodeInt
    jobs:
      - job: 
        steps:
          - bash: echo 'DeployCodeInt'

  - stage: DeployNetworkDev
    dependsOn: Build
    jobs:
      - job: 
        steps:
          - bash: echo 'DeployNetworkDev'

  - stage: DeployNetworkInt
    jobs:
      - job: 
        steps:
          - bash: echo 'DeployNetworkInt'
```
<!-- {% endraw %} -->

Some key features of pipelines are:

- **[Stages](https://learn.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#stage)** - Defines a series of **Jobs**. If more than one stage is defined, these typically run in sequence
- **[Jobs](https://learn.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#job)** - Define a series of **Tasks** which run in sequence. If more than one job is defined, these typically run in parallel
- **[Deployment Jobs](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/deployment-jobs?view=azure-devops)** - This is a special type of **Job** specifically intended for deploying code
- **[Steps/Tasks](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/tasks?view=azure-devops)** - Defines an action in your pipeline

Together, these features can create blocks of logically grouped functionality to handle building, testing and deploying code. Often, however, many pipelines end up using the same steps resulting in duplication. To avoid this we can make use of **Azure Pipeline Templates**.

## Creating Pipeline Templates

Any pipeline can be called as a template. When creating pipeline templates locally in a repository, I create them alongside the pipelines utilising them to keep the code together. An sample folder structure is below.

![image2](/images/sharing-azure-pipeline-templates/image2.png)

The template **[TemplateWithoutParams.azure-pipelines.yml](https://github.com/milkyware/blog-sharing-azure-pipeline-templates/blob/52946497ccf23460f97e72ae9649f47bf011e412/.azure-pipelines/templates/TemplateWithoutParams.azure-pipelines.yml)** can be called from a pipeline like below:

``` yaml
stages:
  - template: templates/TemplateWithoutParams.azure-pipelines.yml
```

Inside the template looks like below:

``` yaml
stages:
  - stage:
    jobs:
      - job: 
        steps:
          - task: Bash@3
            displayName: Print environment variables
            inputs:
              script: env | sort
              targetType: inline
```

In the example we have a templated **stage**, the same can be done using **jobs** and **tasks**.

### Adding parameters to templates

Templates can also make use of **[parameters](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops#parameters)** to further improve their reusability and flexibility. The below sample echos the values of **testParam** and **defaultParam**.

<!-- {% raw %} -->
``` yaml
parameters:
  - name: testParam
    type: string
  - name: defaultParam
    type: string
    default: 'World'

stages:
  - stage:
    jobs:
      - job: 
        steps:
          - task: Bash@3
            displayName: Print environment variables
            inputs:
              script: env | sort
              targetType: inline

          - bash: echo '${{parameters.testParam}}'

          - bash: echo '${{parameters.defaultParam}}'
```
<!-- {% endraw %} -->

The above template can be called as below to demonstrate that **defaultParam** is optional. Using parameters with default values allows for lots of configuration within a pipeline template whilst keeping pipelines easy to use for basic usage. Common use cases I've had is for setting default filemasks for building and testing code e.g. `/src/**/*.csproj` to encourage consistent folder structures but allowing for alternate config to be provided.

``` yaml
stages:
  - template: templates/TemplateWithoutParams.azure-pipelines.yml
    parameters:
      testParam: Hello
```

## Sharing Templates Centrally

## Pipeline Template Versioning

## Summary
