---
title: Refreshing DevOps Service Connections
header:
  image: '/images/refresh-devops-service-connections/header.png'
category: DevOps
tags:
  - Azure
  - Azure Devops
  - PowerShell
---

A while back I put together an application provisioning process using **PowerShell and Azure Pipelines** to automate delivering Azure application environments including:

- Resource Groups
- AAD access groups
- Deployment App Registrations
- DevOps Service Connections

As ***manually*** created service connections (through the DevOps API) require a secret, these secrets come with an expiration date. In this post I'll share how I automated the process of refreshing these tokens.

## Why automate it?

Typically, my approach to automation is **why not?**

Automation helps to keep a process consistent both in how frequently it's down as well as how it's done. For this particular scenario, as App Regs were created **for each application**, and service connections are scoped to a **particular Azure subscription**, the number of connections that needed maintaining was quickly growing.

### Sample Project

For this post, I've prepared a sample **[GitHub repo](https://github.com/milkyware/blog-refresh-devops-service-connections)** with copies of all of the scripts I'll be referencing in this post

## The automation

### Getting expired/expiring App Regs

### Updating the credentials

## Sum Up
