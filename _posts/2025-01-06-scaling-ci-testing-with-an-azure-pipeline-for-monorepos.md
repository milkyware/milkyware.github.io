---
title: Scaling CI Testing with an Azure Pipeline for Monorepos
category: DevOps
tags:
  - Dotnet
  - .NET
  - Azure DevOps
  - Azure Pipelines
  - Tests
  - Testing
  - CI
  - Monorepos
---

Continuous Integration (CI) in monorepos often presents challenges as the codebase scales. Running all tests on every commit is inefficient, particularly for large repositories with multiple solutions and test projects, whereas defining a CI pipeline per solution is repetitive and doesn't scale easily. To address this, I've implemented an Azure Pipeline that dynamically identifies and runs only the relevant test projects affected by code changes. This pipeline simplifies CI operations and scales efficiently as more test projects are added.

## The Pipeline Template

Below is the complete Azure Pipeline template. For the remainder of the post, I want to break down some of the pipeline's key features and benefits.

<!-- {% raw %} -->
``` yaml
parameters:
  - name: comparisonBranch
    displayName: Comparison Branch. The branch to compare against to evaluate changes. Defaults to main
    type: string
    default: main
  - name: comparisonDepth
    displayName: Comparison Depth. Compares the top x folders to evaluate test projects to rerun
    type: number
    default: 2
  - name: buildConfiguration
    displayName: Build Configuration
    type: string
    default: debug
  - name: dotnetVersions
    displayName: Array of .NET versions required to run the tests. This should include all possible versions
    type: object
    default:
      - 8.0.x
  - name: excludedTestProjects
    displayName: Array of test projects to be excluded
    type: object
    default: []

steps:
  - checkout: self
    fetchDepth: 0

  - template: PrintEnvironmentVariables.azure-pipelines.yml

  - ${{each dv in parameters.dotnetVersions}}:
    - task: UseDotNet@2
      displayName: Install .NET ${{dv}}
      inputs:
        version: ${{dv}}

  - task: PowerShell@2
    displayName: Run affected tests
    inputs:
      pwsh: true
      targetType: inline
      informationPreference: continue
      script: |
        $InformationPreference = 'Continue'
        if ($env:SYSTEM_DEBUG)
        {
            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'
        }

        $comparisonBranch = "${{parameters.comparisonBranch}}"
        Write-Verbose "comparisonBranch=$comparisonBranch"

        $currentDirPrefix = ".$([System.IO.Path]::DirectorySeparatorChar)"
        Write-Verbose "currentDirPrefix=$currentDirPrefix"
        
        Write-Debug "Getting changed files"
        $fileChanges = git diff --name-only "origin/$comparisonBranch..." |
          ForEach-Object {[System.IO.Path]::GetRelativePath(".", $_)}
        Write-Information "Found $($fileChanges.Count) changed files"
        Write-Verbose "fileChanges"
        $fileChanges | Write-Verbose

        $depthIndex = ${{parameters.comparisonDepth}} - 1 
        Write-Verbose "depthIndex=$depthIndex"

        Write-Debug "Getting changed directories"
        $dirChanges = $fileChanges | ForEach-Object {
            $split = $_.Split([System.IO.Path]::DirectorySeparatorChar)
            $dir = $split[0..$depthIndex] -join [System.IO.Path]::DirectorySeparatorChar
            return $dir
          } |
          Select-Object -Unique
        Write-Information "Found $($dirChanges.Count) changed directories"
        Write-Verbose "dirChanges"
        $dirChanges | Write-Verbose

        $xpathIsTestProject = "/Project/PropertyGroup/IsTestProject/text()"
        Write-Verbose "xpathIsTestProject=$xpathIsTestProject"

        function IsTestProject ([string]$Path) {
          $csproj = [xml](Get-Content -Path $Path)
          $IsTestProject = $csproj.SelectSingleNode("/Project/PropertyGroup/IsTestProject/text()").Value
          $HasTestSdk = $csproj.Project.ItemGroup.PackageReference.Include -icontains "Microsoft.NET.Test.Sdk"
          $HasMSTest = $csproj.Project.ItemGroup.PackageReference.Include -icontains "Microsoft.NET.Test.Sdk"
          $HasNUnit = $csproj.Project.ItemGroup.PackageReference.Include -icontains "NUnit"
          $HasXUnit = $csproj.Project.ItemGroup.PackageReference.Include -icontains "XUnit"

          return $IsTestProject -or $HasTestSdk -or $HasMSTest -or $HasNUnit -or $HasXUnit
        }
        
        Write-Debug "Getting all test projects"
        $testProjects = Get-ChildItem -Include "*.csproj" -Recurse |
          ForEach-Object {[System.IO.Path]::GetRelativePath(".", $_)} |
          Where-Object {IsTestProject -Path $_}
        Write-Verbose "allTestProjects"
        $testProjects | Write-Verbose

        function StartsWithAny ([string]$StringToCheck, [string[]] $Prefixes) {
            foreach ($prefix in $Prefixes) {
                if ($StringToCheck.StartsWith($prefix)) {
                    return $true
                }
            }
            return $false
        }
          
        Write-Debug "Filtering test projects to changed directories"
        $testProjects = $testProjects | Where-Object { StartsWithAny -StringToCheck $_ -Prefixes $dirChanges }

        $excludedTestProjectsJson = '${{ convertToJson(parameters.excludedTestProjects) }}'
        Write-Verbose "excludedTestProjectsJson=$excludedTestProjectsJson"

        Write-Debug "Resolving excluded tests"
        $excludedTestProjects = $excludedTestProjectsJson | 
          ConvertFrom-Json |
          ForEach-Object {[System.IO.Path]::GetRelativePath(".", $_)} |
          ForEach-Object {$_.Substring(2)}
        Write-Verbose "excludedTestProjects"
        $excludedTestProjects | Write-Verbose

        Write-Debug "Removing excluded test projects"
        $testProjects = $testProjects | Where-Object {$excludedTestProjects -notcontains $_}

        Write-Verbose "testProjects"
        $testProjects | Write-Verbose

        Write-Information "Running $($testProjects.Count) test projects"
        $testProjects | ForEach-Object {
          Write-Information "Running tests in $_"
          dotnet test $_ --configuration ${{parameters.buildConfiguration}} --collect "Code coverage" --logger trx --results-directory "$(Agent.TempDirectory)"
        }

  - task: PublishTestResults@2
    displayName: Publish Test Results
    inputs:
      buildConfiguration: ${{parameters.buildConfiguration}}
      testResultsFormat: VSTest
      testResultsFiles: $(Agent.TempDirectory)/**/*.trx
```
<!-- {% endraw %} -->

### Running the Pipeline Template

Defining an Azure Pipeline which consumes the template would look similar to below. Note that the template is being referenced as a file, however, the template could just as easily be referenced from a remote repo as covered in **[this article]({% post_url 2023-02-20-sharing-azure-pipeline-templates%})**.

<!-- {% raw %} -->
``` yaml
name: $(Date:yy.MM.dd)$(Rev:.rr)

trigger:
  batch: true
  branches:
    include:
      - main
  paths:
    include:
      - apps

extends:
  template: templates/RunAffectedTests.azure-pipelines.yml
  parameters:
    dotnetVersions:
      - 8.0.x
      - 6.0.x
    excludedTestProjects:
      - apps/app2/tests/IntegrationTests/IntegrationTests.csproj
```
<!-- {% endraw %} -->

An example of the pipeline running has been included below. The logs of the pipeline detail which test projects have been run.

![image2](/images/scaling-ci-testing-with-an-azure-pipeline-for-monorepos/image2.png)

The test results are then uploaded to the Azure Pipeline for easy reviewing.

![image3](/images/scaling-ci-testing-with-an-azure-pipeline-for-monorepos/image3.png).

## Key Features of the Pipeline

### Dynamic Test Discovery

The pipeline identifies changes in a branch compared to a base branch (e.g., `main`) using the `git diff` command. It uses a configurable depth parameter to map changes to specific directories and locate affected test projects.

![image1](/images/scaling-ci-testing-with-an-azure-pipeline-for-monorepos/image1.png)

This is intended to work with a folder structure which adheres to convention across the monorepo. For example, with the default `comparisonDepth` parameter of **2** for the above folder structure, updating the file **apps/app1/src/ConsoleApp1/Program.cs** would run test projects under **apps/app1**. This approach ensures that only impacted tests are executed, saving test execution time and pipeline resources.

### Modular Configuration

A number of parameters are available to customise the usage of the pipeline to fit different project structures and team requirements:

- **comparisonBranch:** The base branch for evaluating changes.
- **comparisonDepth:** Determines how deeply the directory structure is analyzed for changes.
- **buildConfiguration:** Specifies the build configuration (e.g., Debug or Release).
- **dotnetVersions:** Lists .NET versions required to run the tests.
- **excludedTestProjects:** Allows exclusion of specific test projects, such as integration tests.

As the script is written entirely with PowerShell, additional script changes can be easily made.

### Intelligent Test Identification

The pipeline uses the following heuristics to identify test projects:

- Checks if the `IsTestProject` property is defined in the `.csproj` file.
- Verifies if testing frameworks like MSTest, NUnit, or xUnit are referenced in the project file.

This logic ensures that only genuine test projects are included in the test run.

### Exclusion Handling

By specifying test projects to exclude, tests can be skipped that are irrelevant (such as scripted manual test or integration tests) to the current changes or temporarily disabled. This enhances control of what tests are run and reduces unnecessary processing.

### Multi-Version .NET Support

The pipeline is capable of installing multiple .NET versions as specified in the `dotnetVersions` parameter, ensuring compatibility with various test projects in scenarios where a variety of .NET versions are used (e.g. during a migration to a new .NET version).

### Test Result Publishing

Test results are collected and published in the VSTest format, as is standard practice in CI pipelines, integrating seamlessly with Azure DevOps’ reporting tools.

## What are the Benefits?

As touched on already, there are a number of benefits:

- As the monorepo grows with new apps, providing the folder structured is adhered to, the test projects will automatically be evaluated and run if considered relevant, without the need to define a new CI pipeline.
- With the pipeline being templated and parametrised, it can easily be included in or referenced from various repos for great reuse.
- By targeting only impacted tests, the pipeline reduces compute costs and accelerates feedback loops, enabling faster delivery cycles and more efficient use of build agent resources.
- The pipeline makes use of PowerShell to perform the evaluation of the affected test. This script makes heavy use of standard PowerShell logging practices and integrates with the **[Azure Pipeline debug flag](https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml#systemdebug)** to toggle enhanced logging output to easily identity what tests have been selected.
- With the pipeline being entirely written in PowerShell, should some changes or extra logic be needed, this can be easily incorporated into the pipeline.

## Conclusion

This Azure Pipeline streamlines CI testing for monorepos by focusing only on what's impacted, reducing unnecessary overhead, and keeping workflows efficient. It's flexible, scalable, and integrates easily into existing processes, making it a powerful tool for managing complex repositories.

I hope this has been of use and give it a try. Happy coding!
