---
title: Automating Scanning For Secrets
category: DevOps
tags:
 - Azure Pipeline
 - Pipeline
 - Pipeline Template
 - GitLeaks
 - DevOps
 - Automation
 - CICD
---

Source control is the foundation of software development for many reasons including tracking changes, collaboration, and backup/recovery. One of the most popular source control tools is **Git**. However, due to the often rapid nature of software development, sometimes sensitive information, such as API keys, credentials, tokens, and other secrets, may unintentionally get committed to the repository.

Keeping secrets out of source code is important for several key reasons:

1. **Prevent Unauthorized Access:**
 Exposing credentials in a repository gives attackers an easy path to access private infrastructure, databases, cloud services, or APIs. Once access is gained, they can steal, modify, or even delete valuable data.

2. **Comply with Security Regulations:**
 Many organizations are bound by stringent regulations, like GDPR, PCI DSS, or HIPAA, that require strict data handling and security measures. Exposing secrets can lead to non-compliance and hefty fines.

3. **Avoid Long-Term Impact:**
 Even after a secret is removed from a repository, Git's version history retains every commit unless it's purged. This means that secrets can still be retrieved if not properly cleaned up, prolonging the exposure risk.

4. **Scale and Automate Security Practices:**
 Regular, manual checks for secrets are tedious and error-prone. Automating this process ensures that every commit and pull request is scanned for potential vulnerabilities, reducing human oversight and improving overall security hygiene.

As mentioned, there are limits to scanning source code and history manually to ensure it remains secret-free. Therefore, automating this process is crucial in allowing Git repos to scale and identify leaks quickly.

## Introducing GitLeaks

There are several tools available to automate this process from open-source such as **[GitLeaks](https://github.com/gitleaks/gitleaks)**, to paid services such as **[SpectralOps](https://spectralops.io/features/)** and even built-in to some developer platforms such as **[Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml)**.

For this post, I will demonstrate integrating **GitLeaks with Azure Pipelines** to automate scanning for secrets. GitLeaks is a fantastic open-source tool, actively maintained by many contributors, and is designed to detect hardcoded secrets like API keys and credentials in your Git repositories.

``` bash
docker run --rm -v /local/path/to/repo:/mnt zricethezav/gitleaks:latest git /mnt
```

GitLeaks is available as the Docker image **[zricethezav/gitleaks](https://hub.docker.com/r/zricethezav/gitleaks)** to simplify and make the installation process cross-platform. The above command mounts a repo to the volume **/mnt** and uses the **git** command to scan the history of the mounted /mnt volume.

``` bash
    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

11:39AM INF 189 commits scanned.
11:39AM INF scan completed in 8.23s
11:39AM INF no leaks found
```

Running the Docker command will result in something similar to the above showing no leaks have been found.

``` bash
    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

11:54AM INF 55 commits scanned.
11:54AM INF scan completed in 6.56s
11:54AM WRN leaks found: 1
```

Conversely, if leaks are found, the above output is displayed. GitLeaks also offers a `--verbose` flag which will list the violations, however, this should be used with caution as the secrets will be listed along with some context of where/when in the repo they are.

## Automating Scanning with GitLeaks in an Azure Pipeline

Let's now look at how GitLeaks can be integrated with Azure Pipelines to automate the detection of secrets during every push, pull request or scheduled run.

``` yml
trigger:
  branches:
    include:
 - '*'

schedules:
 - cron: 0 3 * * *
    displayName: Every day at 3 AM
    branches:
      include:
 - main

steps:
 - task: PowerShell@2
    displayName: GitLeaks Scan
    inputs:
      pwsh: true
      targetType: inline
      script: |
        docker run --rm `
          -v .:/mnt `
          zricethezav/gitleaks:latest git /mnt
      informationPreference: continue
```

The above pipeline defines a trigger on any commit to the repo and a schedule for every day at 3 AM. The functionality of the pipeline is just a wrapper around the command we used earlier to scan the repo.

``` yml
parameters:
 - name: warnOnLeaks
    displayName: Toggle to warn on leaks being detected instead of failing the build
    type: boolean
    default: false
 - name: verbose
    displayName: Toggle to show verbose GitLeaks logs
    type: boolean
    default: false

jobs:
 - job: GitLeaksScan
    displayName: GitLeaks Scan
    variables:
      image: 'zricethezav/gitleaks:latest'
      image_cache_path: $(Agent.TempDirectory)/.cache/docker
      image_cache_tar: ${{variables.image_cache_path}}/gitleaks.tar
    steps:
      - task: PowerShell@2
        displayName: Build Cache Key
        inputs:
          pwsh: true
          targetType: inline
          script: |
            if ($env:SYSTEM_DEBUG)
            {
              $DebugPreference = 'Continue'
              $VerbosePreference = 'Continue'
            }

            $timestamp = [datetime]::UtcNow.ToString("yyyy-MM-dd")
            $cacheKey = "docker | $(Agent.OS) | $timestamp"
            Write-Verbose "cacheKey=$cacheKey"

            Write-Host "##vso[task.setvariable variable=CacheKey;]$cacheKey"

      - task: Cache@2
        displayName: Setup Docker Image Cache
        inputs:
          key: $(CacheKey)
          path: ${{variables.image_cache_path}}

      - task: PowerShell@2
        displayName: Load GitLeaks Image
        inputs:
          pwsh: true
          targetType: inline
          script: |
            if ($env:SYSTEM_DEBUG)
            {
              $DebugPreference = 'Continue'
              $VerbosePreference = 'Continue'
            }

            $tarPath = "${{variables.image_cache_tar}}"
            Write-Verbose "tarPath=$tarPath"

            if (Test-Path $tarPath) 
            {
              Write-Debug "Loading cached gitleaks image"
              docker load -i $tarPath
              Write-Information "Loaded cached gitleaks image"
              return
            }
            Write-Debug "Pulling gitleaks docker image"
            docker pull ${{variables.image}}
            Write-Information "Pulled gitleaks docker image"

            $cachePath = "${{variables.image_cache_path}}"
            Write-Verbose "cachePath=$cachePath"

            New-Item -Path $cachePath -ItemType Directory -Force | Out-Null
            
            Write-Debug "Saving gitleaks image to cache"
            docker save ${{variables.image}} -o $tarPath
            Write-Information "Saved gitleaks image to cache"
          informationPreference: continue

      - task: PowerShell@2
        displayName: GitLeaks Scan
        inputs:
          pwsh: true
          targetType: inline
          script: |
            if ($env:SYSTEM_DEBUG)
            {
              $DebugPreference = 'Continue'
              $VerbosePreference = 'Continue'
            }

            Write-Debug "Building command"
            $sb = [System.Text.StringBuilder]::new()
            $sb.Append("docker run --rm -v .:/mnt ${{variables.image}} git /mnt") | Out-Null

            if ([bool]::Parse("${{parameters.verbose}}"))
            {
              Write-Debug "Adding verbose flag"
              $sb.Append(" --verbose")
            }

            $command = $sb.ToString()
            Write-Verbose "command=$command"

            Invoke-Expression $command
            if ($LASTEXITCODE -eq 1 -and [bool]::Parse("${{parameters.warnOnLeaks}}"))
            {
              Write-Host "##vso[task.complete result=SucceededWithIssues;]"
              exit 0
            }
          informationPreference: continue
```

To improve the reusability of the pipeline, I decided to convert it to a **pipeline template** and implement **[Docker image caching](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/caching?view=azure-devops#docker-images)** to improve performance and avoid hitting Docker pull quotas. This template can then be referenced as a template by multiple individual pipelines. I also added the following parameters:

- **warnOnLeaks** - By default, GitLeaks returns exit code 1 when leaks are detected which will fail the pipeline. This parameter allows handling the exit code to return the pipeline as **succeeded with issues** of failing
- **verbose** - Toggles the `--verbose` flag in GitLeaks to display verbose logs. **WARNING** This may display the values of detected secrets and should be used cautiously.

### Benefits of Using GitLeaks in Azure Pipelines

1. **Continuous Monitoring:**
 Automating the secret scanning process through GitLeaks ensures that repositories are continuously monitored for sensitive data, catching leaks before they become serious threats.

2. **Scalable and Configurable:**
 GitLeaks is flexible and can be configured to scan different branches, repositories, or directories within the repo. This adaptability makes it an excellent fit for scaling across various teams and projects.

3. **Fast Detection and Prevention:**
 By integrating with Azure Pipelines, any leaked secrets are detected early in the development process, allowing teams to remediate the issue before it progresses further through the CI/CD pipeline.

4. **Easy Setup with Docker:**
 Leveraging the GitLeaks Docker image makes the setup process seamless. Docker containers ensure consistent results across environments, reducing configuration complexity.

## Wrapping Up

Automating secret scanning with GitLeaks in an Azure DevOps pipeline is a vital step in strengthening your software's security posture. By continuously monitoring your Git repositories for sensitive data, you can catch vulnerabilities early, avoid costly breaches, and ensure compliance with security regulations. This proactive approach helps mitigate the risk of secret leaks and reinforces a culture of secure coding practices across the development team. As always, I hope you find this post useful and thanks for reading.
