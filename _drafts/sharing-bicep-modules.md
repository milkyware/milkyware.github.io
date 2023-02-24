---
category: DevOps
tags:
    - Bicep
    - ARM
---

# Sharing Bicep Templates

Over the past couple of years I've been primarily developing and deploying applications to Azure. Typically these deployments comprise of 2 broad categories:

1. Deploying code
2. Deploying infrastructure

For this post we're going to focus on the infrastructure side using **[Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)** to deploy resources to Azure. To do this we'll firstly introduce what Bicep is and its benefits. We'll then look at how to create **modules** to both organise and reuse infrastructure. Lastly, we'll look at how to share those modules across your organisation.

## What is Bicep?

Bicep is a declarative language which builds upon the foundation of the existing **[Azure Resource Manager (ARM) templates](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/overview)** which is used to develop and automate the deployment of Azure resources. 