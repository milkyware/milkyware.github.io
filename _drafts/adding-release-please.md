---
title: Adding Release Please
tags:
  - Release Please
  - GitHub Actions
  - DevOps
  - Release
---

I've been using the **[Microsoft Graph SDK](https://github.com/microsoftgraph/msgraph-sdk-dotnet)** in various projects for a while now and stumbled across **[Release Please](https://github.com/googleapis/release-please)** being used to release the library. Preparing releases and ensuring they're accurate for what is included takes time and is often made difficult due to different styles of commit messages, so automating my release process and ensuring consistency is something I've wanted to look into for a while.

For this post, I'll introduce Release Please and how i've implemented it in my projects as well as how I've added validation to ensure pull request commits remain consistent and conform to Release Please conventions.

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

### Setting Up Release Please

With the repo prepared, we can now setup Release Please. To do this, we start with creating the configuration. This comprises of `release-please-config.json` and `.release-please-manifest.json` which are use to configure Release Please and track versions respectively.

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

The output of the command should look similar to above with a pull request being created which initialises.

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

```json
{
  ".": "0.0.0"
}
```

To monitor the commits on a repo, Release Please is made available as a **[GitHub Action](https://github.com/googleapis/release-please-action)**. However, before creating the GitHub Workflow, there are some pre-requisites.

## Validating PR Titles

```bash
npm i release-please -g
```

[![milkyware/blog-release-please - GitHub](https://gh-card.dev/repos/milkyware/blog-release-please.svg)](https://github.com/milkyware/blog-release-please)

 My preferred release strategy has long been using Git tagging (particularly GitHub releases), however, preparing releases and ensuring they're accurate for what is included takes time and is often made difficult due to different styles of commit titles.
