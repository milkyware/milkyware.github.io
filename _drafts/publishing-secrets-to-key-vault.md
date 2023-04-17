---
title: Publishing Secrets to Key Vault
header:
  image: 'images/publishing-secrets-to-key-vault/header.svg'
category: DevOps
tags:
    - Azure
    - Azure Pipelines
    - DevOps
---

Most applications make use of configuration to allow an application or script to be used in different ways. A common scenario is when an application has a development lifecycle and is deployed to different environments for development, testing and ultimately production. Often, most of the configuration is not sensitive and can be stores as **plain text** alongside the code. However, some, such as credentials and keys, will be sensitive and need to be kept **secret**. Storing these **secrets** as plain text, such as in the code, should be avoided. So the question is, where can we store these secrets?

## The Problem

For this post I'm going to detail where I've decided to store **secret configuration** for applications as well as how I'm deploying this config to my applications. Before going any further, lets layout the scenario:

1. The source control tool is **Azure DevOps**
2. Deployment pipelines are all written in **YAML (Azure Pipelines)**
3. The code is deployed to **Azure App Services**
4. **Azure Key Vault** is used to store secrets and referenced using **Key Vault references**

As mentioned, **non-sensitive** config is often kept near or alongside the code. I wanted to maintain this idea for the **secrets** to make managing the config more convenient as well as making it easier for other developers to pick and understand both the code and the config.

![image1](/images/publishing-secrets-to-key-vault/image1.png)

In the past I've tried using a **seed Key Vault** where a central Key Vault is created either per app or collection of apps and a pipeline used to retrieve the secrets and publish them to the appropriate environment. However, this didn't keep the secrets near the rest of the config or the code.

## DevOps variable groups

### Refreshing the Key Vault references

## Summary
