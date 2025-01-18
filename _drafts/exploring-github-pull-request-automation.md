---
title: Exploring GitHub Pull Requests Automation
category: Automation
tags:
  - GitHub
  - GitHub Workflows
  - Pull Requests
  - Automation
  - Productivity
---

As development teams grow and projects become more complex, automating processes becomes critical to maintaining productivity and code quality. I'm a big fan of using Azure Pipelines to automate builds, testing and general code quality, however, recently I've started exploring GitHub Workflows to automate managing pull requests to make it easier to identify what it relates to.

In this post, I want to share my experience setting up some of my initial workflows to handle tagging pull requests. Whether you're new to GitHub Actions or looking for ideas to enhance your current CI/CD pipeline, this guide offers practical insights and tips to help you get started.

## Automating GitHub

The majority of my CI/CD pipeline experience has centred around **Azure DevOps and Azure Pipeline** which I've used for CI/CD pipelines in many projects. However, GitHub has a **[CLI available](https://cli.github.com/)** to easily integrate with the GitHub API which I've wanted to have a play with to automate processes.

``` bash
gh pr view 1 --repo owner/scratchpad
```

As the example the above command will retrieve and display details about **PR #1 in the specified repo**.

``` bash
gh pr view 1 --repo owner/scratchpad --json id,title,body
```

In addition the `--json` argument can be added to many commands to return a JSON object to allow handling the responses in a programmatic way, such as using `ConvertFrom-Json` **in PowerShell**.

## Assigning Reviewers

The first workflow I wanted to create was to automate assigning a configurable list of reviewers to pull requests.

``` yaml
name: Assign Reviewers

on:
  pull_request:
    types:
      - opened
      - ready_for_review
      - reopened

jobs:
  assign-reviewers:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Print Environment Variables
        shell: pwsh
        run: |
          Get-ChildItem Env: | ForEach-Object {Write-Host "$($_.Name)=$($_.Value)"}

      - name: Assign Reviewers
        shell: pwsh
        env:
          GH_TOKEN: ${{ github.token }}
          REVIEWERS: |
            [
              "github-user1",
              "github-user2"
            ]
        run: |
          $InformationPreference = 'Continue'
          if ($env:ACTIONS_RUNNER_DEBUG)
          {
            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'
          }

          $prNumber = "${{ github.event.number }}"
          Write-Debug "prNumber=$prNumber"

          Write-Debug "Parsing reviewers"
          $reviewers = '${{ env.REVIEWERS }}' | ConvertFrom-Json

          Write-Debug "Getting PR"
          $pr = gh pr view $prNumber --json author | ConvertFrom-Json
          $author = $pr.author.login
          Write-Verbose "author=$author"

          Write-Debug "Filtering out author"
          $reviewers = $reviewers | Where-Object {$_ -ine $author}

          $reviewersStr = $reviewers | ConvertTo-Json -Compress
          Write-Verbose "reviewersStr=$reviewersStr"

          foreach ($r in $reviewers)
          {
            gh api --method POST `
              -H "Accept: application/vnd.github+json" `
              -H "X-GitHub-Api-Version: 2022-11-28" `
              /repos/${{ github.repository }}/pulls/$prNumber/requested_reviewers `
              -f "reviewers[]=$r"
          }

          Write-Information "Assigned reviewers"
```

The above workflow is triggered when a pull request is opened (including re-opened and published after drafting) and used the GitHub CLI in combination with Powershell set set reviewers.

To authenticate the CLI, the `GH_TOKEN` environment variable is set using the `${{ github.token }}` workflow variable. A **JSON array of GitHub usernames** is also provided as an environment variable. The script then deserializes the reviewer array, removes the author and adds reviewers using the GitHub API.

**N.B.** The GitHub API is currently used to add the reviewers due to a **[bug in the handling of workflow permissions](https://github.com/cli/cli/issues/4844)**.
