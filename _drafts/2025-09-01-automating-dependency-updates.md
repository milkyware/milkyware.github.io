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

#### Enabling by Default

GitHub also offers the ability for this feature to be enabled by default and configured en masse for all repos **for a user or an organisation**. This can be found in **Settings > Code Security > Dependabot** under the same 2 settings as in the repo, **Dependabot security updates** and **Grouped security updates**.

![image4](/images/automating-dependency-updates/image4.png)

Enabling this feature by default will help ensure that all your future project remain secure with no additional setup effort required.

### Configuring Version Updates

While security updates are triggered by the discovery of vulnerabilities, version updates allow you to keep all your dependencies up-to-date as soon as new versions are released. With version updates enabled, Dependabot will automatically raise pull requests whenever it detects a new version of a dependency in your configured package ecosystems.

To enable this, you add a `dependabot.yml` file to your repository (typically under `.github/dependabot.yml`). Below is a sample configuration and a breakdown of its options:

<!-- {% raw %} -->
```yaml
version: 2
updates:
  - package-ecosystem: nuget
    directories:
      - /apps/app1
      - /apps/app2
    schedule:
      interval: daily
    labels:
      - nuget
    ignore:
      - dependency-name: FluentAssertions
        versions:
          - ">=8.0.0"

  - package-ecosystem: terraform
    directory: /terraform
    schedule:
      interval: daily
    labels:
      - terraform

  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: daily
    labels:
      - github-actions
```
<!-- {% endraw %} -->

Let's review the key aspects:

- `package-ecosystem`: Specifies the type of dependencies to monitor (e.g., `nuget`, `npm`, `terraform`, `github-actions`).
- `directory` or `directories`: The path(s) in your repo where the manifest or lock files are located. For some ecosystems, you can specify multiple directories.
- `schedule`: Controls how often Dependabot checks for updates. Common intervals are `daily`, `weekly`, or `monthly`.
- `labels`: Adds custom labels to PRs for easier filtering and triage.
- `ignore`: Lets you exclude specific dependencies or versions from automatic updates. In the example above, updates for `FluentAssertions` version 8.0.0 and above are ignored.

This configuration allows you to tailor Dependabot to your team's workflow. For example, you might want daily updates for critical dependencies, but only weekly updates for less critical ones. You can also combine security and version updates for comprehensive coverage.

For further reading, GitHub provide a **[sample repo](https://github.com/dependabot/demo)** for setting up both security updates and version updates.

### Bonus: Auto-Merge Dependabot PRs

So far, all of the PRs we've discussed for updating dependencies have required a manual review and merge. Whilst doing some research on some GitHub repos, I stumbled across a **[GitHub Workflow](https://github.com/microsoftgraph/msgraph-sdk-dotnet/blob/main/.github/workflows/auto-merge-dependabot.yml)** which automatically marks **non-major** Dependabot update PRs as **auto-merged**.

<!-- {% raw %} -->
```yaml
name: Auto-merge dependabot updates

on:
  pull_request:
    branches: [ main ]

permissions:
  pull-requests: write
  contents: write

jobs:
  dependabot-merge:
    runs-on: ubuntu-latest
    if: ${{ github.actor == 'dependabot[bot]' }}
    steps:
      - name: Dependabot metadata
        id: metadata
        uses: dependabot/fetch-metadata@v2.4.0
        with:
          github-token: "${{ secrets.GITHUB_TOKEN }}"

      - name: Enable auto-merge for Dependabot PRs
        # Only if version bump is not a major version change
        if: ${{steps.metadata.outputs.update-type != 'version-update:semver-major'}}
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{github.event.pull_request.html_url}}
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
```
<!-- {% endraw %} -->

The workflow is triggered by new PRs to main, checking that the PR has been raised by Dependabot. If raised by Dependabot, the metadata is retrieved to determine whether the package is a major change. Lastly, if not a major update, the **GitHub CLI** is used to set the PR to auto-merge (once all checks have passed) as well as to **squash merge**.

### Auto-Merging Update PRs

## Introducing Renovate
