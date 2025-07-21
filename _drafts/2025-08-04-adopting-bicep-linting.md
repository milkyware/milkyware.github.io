---
title: Adopting Bicep Linting
category: Azure
tags:
    - Bicep
    - Bicep Modules
    - ARM
    - Azure
    - IaC
    - Linting
    - Dotnet Too
    - Spectre Console
---

In **[one of my earlier posts]({% post_url 2023-03-13-sharing-bicep-templates %})**, I covered using **[ARM-TTK](https://github.com/Azure/arm-ttk)** via an **[Azure DevOps extension](https://marketplace.visualstudio.com/items?itemName=Sam-Cogan.ARMTTKExtensionXPlatform)** to analyse and test my Bicep modules automatically as part of my pipelines. Since then, Microsoft now offers a 1st party solution for **[Bicep linting](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter)** which aligns more directly with Bicep and opens the possibility for the linting to be easily adapted to other CI/CD platforms.

My goal was to replace using the DevOps Extension with the Bicep linter. For this post, I want to share my approach to this. As a sneak peak, this project turned out to be an opportunity to use library I've wanted to use for a while....**[Spectre.Console](https://spectreconsole.net/)**!

## What Does Linting Look Like?

The **[VS Code Bicep extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)** offers great intellisense for developing Bicep templates, giving clear warning in the code.

![image1](/images/adopting-bicep-linting/image1.png)

However, the addition of the **[`az bicep lint`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#lint)** command, allows verifying Bicep templates against the same rules used in the IDE. Running the command against the Bicep in the earlier screenshot produces the results below:

```bash
> az bicep lint --file main.bicep
WARNING: D:\Git\milkyware\azure-bicep\.tmp\storageaccount.bicep(22,35) : Warning outputs-should-not-contain-secrets: Outputs should not contain secrets. Found possible secret: function 'listKeys' [https://aka.ms/bicep/linter-diagnostics#outputs-should-not-contain-secrets]
```

The default console shows the same violation as before, but the format doesn't help from an automation perspective. To deal with that, there is the `--diagnostics-format` which currently supports **Static Analysis Results Interchange Format (SARIF)**.

```json
> az bicep lint --file main.bicep --diagnostics-format sarif
{
  "$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.6.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "bicep"
        }
      },
      "results": [
        {
          "ruleId": "outputs-should-not-contain-secrets",
          "message": {
            "text": "Outputs should not contain secrets. Found possible secret: function 'listKeys' [https://aka.ms/bicep/linter-diagnostics#outputs-should-not-contain-secrets]"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "file:///D:/Git/.tmp/main.bicep"
                },
                "region": {
                  "startLine": 22,
                  "charOffset": 35
                }
              }
            }
          ]
        }
      ],
      "columnKind": "utf16CodeUnits"
    }
  ]
}
```

SARIF is a widely used, standardised format for sharing static code analysis results. Let's have a look at how we can integrate that with a pipeline.

## Replacing ARM-TTK in my Pipelines

Previously, I've been using the **Sam-Cogan.ARMTTKExtensionXPlatform** DevOps Extension, which is a wrapper around **ARM-TTK**. This extension performs the code analysis and then outputs the results as **NUnit 2** which can then be published to DevOps. When the results are published, if they include any failures, this fails the pipeline which raises awareness of violations.

However, currently, the `PublishTestResults@2` task doesn't support publishing SARIF results, so the next step is to reformat the results.

### Developing a SARIF Converter

In a few blog posts, I'd seen suggestions of using the **[sarif-junit npm package](https://www.npmjs.com/package/sarif-junit)**, however, I found that the resulting format wasn't quite

### Integrating the Tool into the Pipelines

## Wrapping Up
