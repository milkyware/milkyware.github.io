---
title: Azure SQL Temporary Access from Azure-Hosted Pipelines
category: DevOps
tags:
  - Azure
  - Azure DevOps
  - Azure Pipelines
  - Azure SQL
  - Hosted Pipelines
---

Currently, I use Microsoft-hosted pipeline agents to handle my deployments due to their simplicity and minimal maintenance overhead. I've recently needed to start running SQL scripts against Azure SQL instances from these pipelines.