---
title: Adding Release Please
tags:
  - Release Please
  - GitHub Actions
  - DevOps
  - Release
---

I've been using the **[Microsoft Graph SDK](https://github.com/microsoftgraph/msgraph-sdk-dotnet)** in various projects for a while now and stumbled across **[Release Please](https://github.com/googleapis/release-please)** being used to release the library. Preparing releases and ensuring they're accurate for what is included takes time and is often made difficult due to different styles of commit messages, so automating my release process and ensuring consistency is something I've wanted to look into for a while.

For this post, I'll introduce Release Please and how I've implemented it in my projects as well as how I've added validation to ensure pull request commits remain consistent and conform to Release Please conventions.

## Introducing Release Please

Release Please is a Google project which monitors the commits of a GitHub repo and automates:

- CHANGELOG generation
- Creation of GitHub releases
- Calculation of version numbers

To do this, Release Please looks for commit messages conforming to the **[Conventional Commits spec](https://www.conventionalcommits.org/)**. This is a set of rules on how to structure messages to create an explicit git history and indicate the type of change on the project. The general structure of Conventional Commits is:

```txt
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Often, just the top part of the message is needed and generally the most common *types* will be `fix:` and `feat:` corresponding to **patch** and **minor** version changes respectively. In addition, suffixing a *type* with `!` (e.g. `feat!:`) indicates a breaking change which corresponds to a **major** version change.

![image1](/images/adding-release-please/image1.png)

Conventional Commits will then trigger Release Please to create a ***release Pull Request*** containing a summary of the changes made since the last release along with calculating the next version number based on the types of changes made. As part of the release PR, a `CHANGELOG.md` will be created/updated containing the same details as PR description to create a single history of the changes.

![image2](/images/adding-release-please/image2.png)

Merging this PR then triggers a GitHub release to be created along with the associated Git tag. So let's have a look at how to set it up.

### Preparing the Repo

Before setting up Release Please, there are some pre-requisites. Firstly, it is recommended to use **squash merges** when merging PRs to make a linear Git history.

![image3](/images/adding-release-please/image3.png)

To ensure squash merges are enables, go to `General -> Pull Requests` of the **repo settings**. Also, ensure that the default commit message is set to at least `Pull request title` so that the Conventional Commit can be set as the PR title, which we can validate later on.

![image4](/images/adding-release-please/image4.png)

Secondly, to allow Release Please to create and manage **Release PRs**, GitHub Actions need permission to create PRs. Enabling this can be found in the **repo settings** as `Actions -> General -> Workflow permissions`.

### Configuring Release Please

With the repo prepared, we can now configure Release Please. To do this, we start with creating the configuration. This comprises of `release-please-config.json` and `.release-please-manifest.json` which are use to configure Release Please and track versions respectively.

```bash
npm i release-please -g
```

Although these can be created manually using samples such as from MS Graph, the **[release-please CLI](https://github.com/googleapis/release-please/blob/main/docs/cli.md)** has been provided to help with this. Let's install the package.

```powershell
$ghToken = "contents-pr-read-write-pat-token"
release-please bootstrap --token $ghToken `
  --repo-url=username/repo-name `
  --bump-minor-pre-major=true `
  --bump-patch-for-minor-pre-major=true
```

Once installed, we can then run the CLI. You'll need a PAT token, which can be created under your **[GitHub account settings](https://github.com/settings/personal-access-tokens)**, which has **read/write access to `Contents` and `Pull requests`**.

```bash
> Fetching .release-please-manifest.json from branch main
> Fetching release-please-config.json from branch main
√ Starting GitHub PR workflow...
√ Successfully found branch HEAD sha "6bf1cb2d415637b225b54cfb73a1f1bbb7a22567".
√ Successfully created branch at https://api.github.com/repos/milkyware/blog-release-please/git/refs/heads/release-please/bootstrap/default
√ Got the latest commit tree
√ Successfully created a tree with the desired changes with SHA 95f20137c7cdc3c31510182e16230a692180d94a
√ Successfully created commit. See commit at https://api.github.com/repos/milkyware/blog-release-please/git/commits/b1af4e0fbebd80fd67b0492beaec0f67518dd9b4
√ Updating reference heads/release-please/bootstrap/default to b1af4e0fbebd80fd67b0492beaec0f67518dd9b4
√ Successfully updated reference release-please/bootstrap/default to b1af4e0fbebd80fd67b0492beaec0f67518dd9b4
√ Successfully opened pull request available at url: https://api.github.com/repos/milkyware/blog-release-please/pulls/1.
√ Successfully opened pull request: 1.
{
  headBranchName: 'release-please/bootstrap/default',
  baseBranchName: 'main',
  number: 1,
  title: 'chore: bootstrap releases for path: .',
  body: 'Configuring release-please for path: .',
  files: [],
  labels: []
}
```

The output of the command should look similar to above with a pull request being created which initialises the config and manifest files.

```json
{
  "packages": {
    ".": {
      "changelog-path": "CHANGELOG.md",
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": true,
      "draft": false,
      "prerelease": false
    }
  },
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

The config file in the PR should look similar to above. Notice that the arguments specified in the command come under the `.` object under `packages`, this is due to Release Please supporting both the **monorepo and polyrepo architectures** where `.` indicates that the component being versioned is the entire repo. In a monorepo setup, the `--path` argument can be used on the CLI to configure additional components in the same repo, by specifying the path of the component within the repo such as `--path=lib/my-versioned-component`. The JSON schema is also referenced to support intellisense when editing the config.

```json
{
  ".": "0.0.0"
}
```

The manifest file should look similar to above. The **key(s)** should match those under `packages` in the config file (in our case this is `.`). The version on the right tracks the **current version** for that component, typically this should match the Git tags.

> **N.B.** If the current version doesn't have a corresponding tag, Release Please will fallback to **1.0.0**. This is particularly of note when working with **0.x.x** versions as, without a tag matching the manifest, Release Please will jump to **1.0.0**. If onboarding a repo without any tags, create the initial tag (e.g. 0.0.0) and update the manifest or use the `--initial-version` argument.

### Automating Releases

With the repo prepared and Release Please configured, we can now setup the automation. Release Please is made available as a **[GitHub Action](https://github.com/googleapis/release-please-action)** and so the automation just involves setting up a Github Workflow.

```yaml
name: Release Please

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - uses: googleapis/release-please-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

This workflow is very similar to the one documented by the GitHub Action, with the additional inclusion of the `actions/checkout@6` step. This is so that the config and manifest are available to the Release Please action.

![image1](/images/adding-release-please/image1.png)

As **Conventional Commits** are added to main, via PRs, Release Please will automatically prepare the release PR like the one shown earlier. Once you're happy with the release, it can be merged in to trigger the actual GitHub release. However, how can you ensure that PRs do follow the **Conventional Commits** syntax?

## Validating PR Titles

As we **[setup the repo earlier](#preparing-the-repo)** to use squash merges and for PR commits to default to the PR title, we can validate that.

```yaml
name: Validate PR Title

on:
  pull_request_target:
    types: 
      - opened
      - edited
      - reopened
      - synchronize

jobs:
  job:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - name: Semantic PR Title Check
        uses: amannn/action-semantic-pull-request@v6
        id: semantic-pr
        env: 
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

There are a few GitHub Actions available which can validate a PR title against the Conventional Commit, however, the one I've opted for is **[action-semantic-pull-request](https://github.com/marketplace/actions/semantic-pull-request)**.

![image5](/images/adding-release-please/image5.png)

The basic setup for the action is really simple, but has plenty of customisation available if needed. When it the step runs it will either run successfully, indicating valid, or throw an error similar to above.

```yaml
- name: Label PR
  if: always()
  shell: pwsh
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    $InformationPreference = 'Continue'
    if ($env:RUNNER_DEBUG)
    {
        $DebugPreference = 'Continue'
        $VerbosePreference = 'Continue'
    }

    $label = "invalid-pr-title"
    $prNumber = ${{ github.event.pull_request.number }}

    $errorMessage = @"
    ${{ steps.semantic-pr.outputs.error_message }}
    "@
    Write-Verbose "errorMessage: $errorMessage"

    if ([string]::IsNullOrEmpty($errorMessage))
    {
        gh pr edit $prNumber --remove-label $label --repo ${{ github.repository }} | Out-Null
        Write-Information "PR title is valid. No label applied."
        return
    }

    $labels = gh label list --repo ${{ github.repository }} --json name | ConvertFrom-Json | Select-Object -ExpandProperty name

    $exists = $labels -contains $Label
    if (-not $exists)
    {
        gh label create $Label --repo ${{ github.repository }} | Out-Null
    }

    gh pr edit $prNumber --add-label $Label --repo ${{ github.repository }} | Out-Null
    Write-Information "PR title is invalid. Applied label '$label'."
```

In addition, I've also added a custom script which will check the out of the title check step and add/clear a `invalid-pr-title` label to/from the PR depending on whether the PR title is valid or invalid. This is to make it clear from the PR overview screen if any PRs need addressing.

## Sample Repo

I've prepared a small, sample repo with my setup of Release Please.

[![milkyware/blog-release-please - GitHub](https://gh-card.dev/repos/milkyware/blog-release-please.svg)](https://github.com/milkyware/blog-release-please)

## Wrapping Up

In this post, we've explored how to automate releases using Release Please and integrate it into your workflow with GitHub Actions. By setting up Release Please, you can streamline the release process, reduce manual effort, and ensure consistency across your projects. We've looked at configuring the tool, preparing your repository, and automating releases with a simple workflow. I hope this guide has been helpful and encourages you to try out Release Please in your own projects. As always, feel free to share your experiences or questions in the comments below.
