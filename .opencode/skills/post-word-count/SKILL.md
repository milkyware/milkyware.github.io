---
name: Post Word Count
description: Measure a Jekyll post's word count and read time the way the Minimal Mistakes theme does, and judge the result against the house length budget
---

Count length the way the published site will, not the way an editor reports it.
The two disagree by enough to matter at the ceiling.

## Why the theme's number is the only number that matters

Minimal Mistakes prints the read time itself, in `_includes/page__meta.html` of
`mmistakes/minimal-mistakes`, whose version is pinned by `remote_theme` in
`_config.yml`:

```liquid
{% assign words_per_minute = document.words_per_minute | default: site.words_per_minute | default: 200 %}
{% assign words = document.content | strip_html | number_of_words %}
```

Three consequences:

1. **Code counts.** `strip_html` removes tags but keeps the text inside
   `<pre><code>`, so every word in a code block is part of the total.
2. **Markdown syntax does not.** Link targets and image paths become HTML
   attributes, so `[label](url)` contributes only `label`, and `![alt](path)`
   contributes nothing at all.
3. **It rounds down.** `divided_by` on integers truncates, so 1,599 words prints
   "7 minute read". Under 200 words prints "less than 1 minute read"; exactly
   200 prints "1 minute read".

`words_per_minute` is 200 in the theme's own `_config.yml`, and this repository
does not override it, so there is no per-post tuning to look for.

## Measuring

Run the bundled script from the repository root. Do not estimate by reading, and
do not use an editor's word count; both drift from the theme.

```powershell
pwsh .opencode/skills/post-word-count/scripts/WordCount.ps1 <path>
```

`<path>` may be one file, several, or a wildcard. It prints the word count, the
read time the theme will show, and the path it measured.

If you ever have to count without the script, replicate its logic rather than
inventing your own: drop the frontmatter, HTML comments, image syntax and link
targets; keep code-block bodies but drop the fence lines; strip markdown
markers; then count whitespace-separated tokens.

## Judging

| Words | Read time | Verdict |
| --- | --- | --- |
| under 600 | 1–2 min | ask whether this is a section of an existing post instead |
| 900–1,300 | 4–6 min | the target band |
| 1,301–1,600 | 6–7 min | acceptable, but name what you would cut |
| over 1,600 | 8 min or more | blocking — split the post or cut it |

Report the word count **and** the read time, because the read time is what the
reader sees. When a draft is over target, report how many words would have to go,
not merely that it is long.

## Known limits

The script approximates the rendered page rather than templating it. It counts
markdown that produces visible text and ignores markdown that produces only
attributes, which is the same trade the theme makes, but inline HTML and unusual
constructs can shift the total slightly. Treat a result sitting right on a
threshold as being at that threshold, and say that is what you did.
