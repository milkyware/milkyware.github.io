---
title: Automating Dependency Updates
tags:
    - Automation
    - Dependency
    - Dependencies
    - Packages
    - Dependabot
    - Renovate
---

Over the years, I've been involved with various software development projects. Once an application shifts into a production, maintenance becomes essential - not just fixing bugs or shipping features, but ensuring the software remains secure, performant, and compatible with its evolving ecosystem.

One key aspect of maintenance is ensuring dependencies remain up-to-date. Outdated dependencies can **miss bug fixes, improvements and introduce security vulnerabilities**. However, as applications grow or additional applications need support, the task of manually tracking and updating dependencies can become increasingly error-prone and time-consuming.

Automating dependency updates is therefore key to ensuring bug fixes, improvements and security fixes are applied swiftly whilst limiting the growth of manual involvement from developers. In this post I'll share how I setup **Dependabot** initially before later adopting **Renovate** to handle my automation of updates.

## Getting Started with Dependabot

GitHub is one of the largest and most popular source code platforms and comes with built-in support for automated dependency updates via
**[Dependabot](https://docs.github.com/en/code-security/getting-started/dependabot-quickstart-guide)**. Dependabot has support for **[numerous package ecosystems](https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories)** and works by scanning repositories for dependency updates, raising pull requests (PR) when updates are found.

Dependabot has 2 main features:

1. Security Updates - Scanning and proposing updates for vulnerable dependencies
2. Version Updates - General purpose dependency updates

Let's start by look at security updates.

### Dependabot Security Updates

As mentioned, the **[security updates](https://docs.github.com/en/code-security/dependabot/dependabot-security-updates/configuring-dependabot-security-updates)** feature scans for vulnerable dependencies and raises PRs updating dependencies to a secure version.

Enabling the security updates feature can be found in the **Settings** of a repo. In **Security > Advanced Security** can be found the **Dependabot** section.

![image1](/images/automating-dependency-updates/image1.png)

Enabling either **Dependabot security updates** or **Grouped security updates** will enable scanning the repo.

Any vulnerabilities that are found will start to be listed in **Security > Dependeabot** area of the repo, complete severity details and a brief description.

![image2](/images/automating-dependency-updates/image2.png)

Notice that on the far right of these alerts is a reference to the same PR, #1. This is due to, in this case, all of the alerts being addressed by the same PR. We can then review the details of the PR and merge it.

![image3](/images/automating-dependency-updates/image3.png)

These PRs would be subject to the same checks the repo has configured such as peer reviews and automated CI builds to ensure code continues to work.

### Configuring Version Updates

Dependabot

### Auto-Merging Update PRs

## Introducing Renovate
