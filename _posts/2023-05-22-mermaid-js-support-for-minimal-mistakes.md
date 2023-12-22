---
title: Mermaid JS Support for Minimal Mistakes
last_modified_at: 2023-12-21
header:
  image: '/images/mermaid-js-support-for-minimal-mistakes/header.webp'
tags:
  - Markdown
  - Mermaid
  - Mermaid JS
  - GitHub Pages
  - Minimal Mistakes
  - Theme
  - Skin
---

In the last 6 months I've started to use **Mermaid JS** to draft integration designs as well as document implemented integration applications. There is a lot of support for this tool, however, it's not supported natively as part of **GitHub Pages**. In this post I'll introduce what Mermaid is, some of the benefits and how to add support for GitHub Pages, specifically the **Minimal Mistakes** theme.

## What is Mermaid JS?

**[Mermaid JS](https://mermaid.js.org)** is a **JavaScript based** tool for rendering a variety of diagrams styles using a **Markdown-style** syntax. Some of the supported diagrams include:

- [Flow Chart](https://mermaid.js.org/syntax/flowchart.html)
- [Sequence Diagram](https://mermaid.js.org/syntax/sequenceDiagram.html)
- [Gantt Chart](https://mermaid.js.org/syntax/gantt.html)

An example sequence diagram could be defined using:

``` text
sequenceDiagram
autoNumber
  Alice->>John: Hello John, how are you?
  John-->>Alice: Great!
  Alice-)John: See you later!
```

This produces the below diagram:

``` mermaid
sequenceDiagram
autoNumber
  Alice->>John: Hello John, how are you?
  John-->>Alice: Great!
  Alice-)John: See you later!
```

With being **test-based**, Mermaid diagrams benefit from being able to quickly and easily design simple and beautiful diagrams. These diagrams can also be updated far quicker than typical diagramming tools, such as **[Draw.IO](https://www.drawio.com/)** and **[MS Visio](https://www.microsoft.com/en-gb/microsoft-365/visio/flowchart-software)** (These are still great tools and useful for long-term documentation), without needing to export an updated copy of the diagram and can evolve as a project design iterates. Also, being text-based, **source control** can be used to collaborate and version-control these diagrams.

This tool has been widely accepted and embraced, so much so that the number of tools that has **[integrated Mermaid JS](https://mermaid.js.org/ecosystem/integrations.html)** either natively, or 3rd party extensions is very extensive.

## Adding Mermaid Support

There are 2 main aspects to adding support for Mermaid to Minimal Mistakes:

1. Adding the Mermaid asset
2. Customising the rendered HTML blocks

Minimal Mistakes is a highly configurable **[GitHub Pages remote theme](https://mmistakes.github.io/minimal-mistakes/docs/quick-start-guide)** which provides great templates and functionality for static sites, such as this blog, allowing me to focus on the content not UI design. One customisation feature is the ability to **[include your own scripts](https://mmistakes.github.io/minimal-mistakes/docs/javascript/#customizing)**, such as Mermaid.

``` yaml
after_footer_scripts:
  - https://cdn.jsdelivr.net/npm/mermaid@9.4.3/dist/mermaid.js
```

This adds the CDN packaged version of Mermaid JS to the generated Jekyll site. Typically, Mermaid Diagrams are added to Markdown files using the **[fenced code block](https://www.markdownguide.org/extended-syntax/#fenced-code-blocks)** syntax ` ``` mermaid` which, when rendered, produces the below HTML:

``` html
<pre>
  <code class="language-mermaid">
    ...
  </code>
</pre>
```

This HTML is **[not the default format that Mermaid expects](https://mermaid.js.org/intro/n00b-gettingStarted.html#requirements-for-the-mermaid-api)** the diagram to be contained in. Therefore, an additional script has been added to customise where Mermaid looks for the diagram definition. A **[mermaid.js](/assets/js/mermaid.js)** script has been added to initialise Mermaid JS:

``` js
---
---
$(document).ready(function () {
    var mmSkin = "{{ site.minimal_mistakes_skin }}"
    var mjsTheme = {
      "air": "default",
      "aqua": "default",
      "contrast": "default",
      "dark": "dark",
      "default": "default",
      "dirt": "default",
      "mint": "mint",
      "neon": "dark",
      "plum": "dark",
      "sunrise": "default"
    }[mmSkin]
    mermaid.initialize({
      startOnLoad: false,
      theme: mjsTheme
    })
    mermaid.init({
      theme: mjsTheme
    }, '.language-mermaid');
  });
```

This scripts has a blank **front matter** to allow the Minimal Mistakes skin to be resolved. The skin is then mapped to a **Mermaid theme**.

To include this script in the static content, it is included **after** the Mermaid JS CDN package:

``` yaml
after_footer_scripts:
  - https://cdn.jsdelivr.net/npm/mermaid@9.4.3/dist/mermaid.js
  - assets/js/mermaid.js
```

## Summary

Mermaid JS is an incredibly useful tool for planning and diagramming. In this post we've add support for Mermaid in Minimal Mistakes without the need for 3rd party extensions or plugins.

## Update

The sample **mermaid.js** script has been updated to make use of liquid templates to resolve the currently configured **Minimal Mistakes skin** so that if the skin is changed, the **MermaidJS theme** will change to a complementing schema.