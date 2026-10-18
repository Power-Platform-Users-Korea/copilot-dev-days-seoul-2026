# LLM Wiki Starter Kit (PowerShell)

The English hands-on kit for GitHub Copilot Dev Days Seoul 2026, Session 02, "Building an LLM Wiki with GitHub."
Six scripts create an ontology and wiki skeleton, validate notes, and publish to GitHub or Microsoft 365.

| Script | Purpose |
|---|---|
| `New-LlmWiki.ps1` | Creates `ontology.md`, `AGENTS.md`, seven templates, folders, example prompts, test questions, and GitHub configuration. Add `-Sample` to include sample notes |
| `Test-LlmWiki.ps1` | Checks classes, required fields, allowed values, approval fields, wikilinks, and potentially confidential terms against `ontology.md`. Exits with code 1 if there are ERRORs |
| `Export-WikiDocx.ps1` | Uses Word to create a matching .docx for each note in `Published/`, for Copilot Studio ingestion |
| `Publish-LlmWikiGitHub.ps1` | Uses gh CLI to create a private repository and configure required PRs, reviewers, checks, and raw-source protection |
| `Publish-LlmWikiSharePoint.ps1` | Signs in to Microsoft 365, uploads to a SharePoint document library (Teams channel files), and provides the URL for Copilot Studio |
| `Clear-Sample.ps1` | Removes only the predefined sample notes so you can start with an empty wiki. Leaves your own notes untouched |

## Quickest start: template repository

Select **Use this template** at [parandurume-labs/llm-wiki-template](https://github.com/parandurume-labs/llm-wiki-template) to create a repository with sample notes and a validation workflow.
That upstream template may contain Korean content. To generate English content, use this English kit instead.

```powershell
gh repo create my-org/our-llm-wiki --private --template parandurume-labs/llm-wiki-template --clone
```

## Quick start: generate your own wiki

Supports Windows PowerShell 5.1 and PowerShell 7.

```powershell
# 1. Download the English generator (or download and extract the English kit zip).
$kit = 'https://power-platform-users-korea.github.io/copilot-dev-days-seoul-2026/llm-wiki/en/kit'
Invoke-WebRequest "$kit/New-LlmWiki.ps1" -OutFile New-LlmWiki.ps1

# 2. Create the skeleton. Companion English scripts download into scripts/ automatically.
powershell -ExecutionPolicy Bypass -File .\New-LlmWiki.ps1 -Path .\our-llm-wiki -OrgName "Our Company" -Approver "Alex" -Sample

# 3. Validate.
cd .\our-llm-wiki
.\scripts\Test-LlmWiki.ps1
```

If you downloaded the zip in a browser, run `Unblock-File .\llm-wiki-kit.zip` before extracting it.
When the six scripts are together, the generator copies its local companions instead of downloading them.

## Two publishing routes

**Microsoft 365**
- Simplest: select **Sync** in the Teams channel's Files tab and use that synchronized folder as `-Path`. OneDrive uploads it to SharePoint.
- Agent-assisted: `.\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl <site-url> -Folder "<channel-name>/our-llm-wiki" -WhatIf`

**GitHub**
- `.\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -Approver <github-login> -WhatIf`
- Rules for private repositories require GitHub Pro for personal accounts or Team or higher for organizations. Unavailable rules produce warnings rather than stopping publication.

Preview both publishing scripts with `-WhatIf` before running without it. A human signs in directly in the browser.

## Working with an agent

The generated `prompts.md` contains eleven step-by-step prompts for GitHub Copilot agent mode in VS Code or Claude Code.
Agents read `AGENTS.md` first.

## Limits and localization

- Validation cannot establish whether raw sources changed, an approver is genuine, or a statement matches its source. A human must verify these.
- `Export-WikiDocx.ps1` requires Windows with Microsoft Word installed.
- GitHub rules and SharePoint uploads depend on account, plan, and tenant policies. Scripts report unavailable steps and their reasons.
- Sample IDs, filenames, and wikilink targets retain their original Korean identifiers for compatibility; the surrounding prose is English. Names in source records are transliterated in prose.
- Ontology table headings and allowed values are English and match the English validator. Keep the generator, validator, and cleanup script together; do not substitute their Korean counterparts.
- The existing bilingual license is reused without translation. Downloading only the generator does not copy a license into the generated vault; retain the kit's license and attribution when redistributing.

## License

This kit and the lecture pages use the [GM-Social License v2.0](../../LICENSE).
The license is bilingual; the Korean original prevails if the two versions differ. The zip includes the same unmodified `LICENSE`.

- You may use, modify, and redistribute the work, including commercially.
- Keep the license file and copyright notices, and credit the original author, LEE Inhee / Parandurume, and the source.
- Distributed derivative works, including your additions, must use the same license.
- Within 90 days of production deployment, publish a thank-you message to Gwangmyeong City, Gyeonggi Province, and a post introducing Gwangmyeong. Educational/learning use and nonprofit public-interest use are exempt from this obligation.

Copyright (c) 2026 LEE Inhee, Parandurume Inc.
Source: https://github.com/parandurume-labs/llm-wiki-template

Read the [English lecture guide](../index.html) or visit https://llm-wiki-lecture.paranduru.me/en/.
