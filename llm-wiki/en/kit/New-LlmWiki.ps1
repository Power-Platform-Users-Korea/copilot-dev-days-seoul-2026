<#
.SYNOPSIS
  Creates a default ontology and an LLM Wiki skeleton.
.DESCRIPTION
  Creates:
    ontology.md            Classes, allowed values, and relationships read by the validator
    AGENTS.md              Agent rules for GitHub Copilot, Claude Code, and other agents
    templates/             Seven class-specific note templates
    Sources/raw/           Raw sources (never edited)
    Sources/<class folder>/ Agent drafts (reviewed: false)
    Published/<class folder>/ Human-approved notes (the only sources agents may cite)
    hubs/, reports/        Navigation notes, retrospectives, and validation reports
    prompts.md             Example prompts for working with an agent
    questions.md           Ten agent test questions
    scripts/               Validation, .docx export, and GitHub/SharePoint publishing scripts
    .github/               CODEOWNERS, validation workflow, and Copilot instructions
  With -Sample, includes notes for the fictional Hangyeol Factory for immediate testing.
.PARAMETER Path
  Destination folder. A Teams channel folder synchronized with OneDrive uploads to SharePoint automatically.
.PARAMETER OrgName
  Organization name used in the ontology and README titles.
.PARAMETER Approver
  Approver name used in sample approved_by fields and instructions.
.PARAMETER Sample
  Includes sample notes.
.PARAMETER Force
  Overwrites existing files. By default, existing files are skipped.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\New-LlmWiki.ps1 -Path .\our-llm-wiki -OrgName "Parandurume" -Approver "LEE Inhee" -Sample
.NOTES
  GM-Social License v2.0 · Copyright (c) 2026 LEE Inhee, Parandurume Inc.
  Source: https://github.com/parandurume-labs/llm-wiki-template
  Retain this notice and the license file when copying or modifying.
#>
[CmdletBinding()]
param(
    [string]$Path = '.\our-llm-wiki',
    [string]$OrgName = 'Our Organization',
    [string]$Approver = 'Approver',
    [switch]$Sample,
    [switch]$Force,
    [string]$BaseUrl = 'https://power-platform-users-korea.github.io/copilot-dev-days-seoul-2026/llm-wiki/en/kit/'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$today = (Get-Date).ToString('yyyy-MM-dd')

if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
$Root = (Resolve-Path -LiteralPath $Path).Path
$created = 0; $skipped = 0

function Write-VaultFile([string]$rel, [string]$content) {
    $full = Join-Path $Root $rel
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ((Test-Path -LiteralPath $full) -and -not $Force) { $script:skipped++; return }
    $text = $content.Replace('{{ORG}}', $OrgName).Replace('{{APPROVER}}', $Approver).Replace('{{TODAY}}', $today)
    $text = ($text -replace "`r`n", "`n").TrimStart("`n")
    [IO.File]::WriteAllText($full, $text, $utf8)
    $script:created++
}

Write-Output "Creating the LLM Wiki skeleton: $Root"

# ---------- Folders ----------
$classFolders = '10-Products', '20-Orders', '30-Capabilities', '40-Worklog', '50-Orgs-People'
$dirs = @('Sources\raw', 'templates', 'hubs', 'reports', 'scripts', '.github\workflows')
foreach ($c in $classFolders) { $dirs += "Sources\$c"; $dirs += "Published\$c" }
foreach ($d in $dirs) {
    $full = Join-Path $Root $d
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
    $keep = Join-Path $full '.gitkeep'
    if (-not (Test-Path -LiteralPath $keep)) { [IO.File]::WriteAllText($keep, '', $utf8) }
}

# ---------- Ontology ----------
Write-VaultFile 'ontology.md' @'
# Ontology — {{ORG}}

This document defines the wiki's conventions. Editing the tables also changes the rules used by `scripts/Test-LlmWiki.ps1`.
Add a class only when the same question has come up three times. Do not rename table columns.

## Classes

| Class | Folder | Required fields | Description |
|---|---|---|---|
| Product | 10-Products | owner, status | What we make or sell |
| Order | 20-Orders | client, product, owner, status, due | Work commissioned by a customer |
| Capability | 30-Capabilities | owner | What we can do |
| Worklog | 40-Worklog | owner, intent_of, evidence | Work performed on a particular day |
| Decision | 40-Worklog | owner, status, source | A decision and rejected alternatives |
| Org | 50-Orgs-People | role, owner | An external organization |
| Person | 50-Orgs-People | role | A person |

Every note requires `class`, `id`, `reviewed`, and `updated`.
Notes in `Published/` also require `approved_by` and `approved_on`.

## Allowed values

| Class | Field | Allowed values |
|---|---|---|
| Product | status | idea, prototype, active, discontinued |
| Order | status | received, in-progress, completed, cancelled |
| Decision | status | under-review, decided, withdrawn |
| Org | role | customer, supplier, institution |
| * | reviewed | true, false |

## Relationships

| Field | Meaning | From → To | Question this relationship enables |
|---|---|---|---|
| owner | One accountable person | Any note → Person | Who is responsible for this work? |
| client | Customer for this order | Order → Org | What work is in progress for this customer? |
| product | What this order produces | Order → Product | What does this order make? |
| uses | Capability needed by this product | Product → Capability | What do we need to make this product? |
| intent_of | Order fulfilled by this worklog | Worklog → Order | Did execution match the plan? |
| evidence | Supporting raw source | Any note → Sources/raw/ | What is the evidence for this fact? |
| source | Raw source for a decision | Decision → Sources/raw/ | Why was this decided? |

## How to adapt it

1. Write ten questions your organization is frequently asked.
2. Turn nouns into classes, verbs into relationships, and state descriptions into allowed values.
3. Update the three tables and align `templates/`. Prompts 1–3 in `prompts.md` help an agent draft these changes.
4. Run `scripts/Test-LlmWiki.ps1` and confirm there are zero ERRORs.
'@

# ---------- Agent rules ----------
Write-VaultFile 'AGENTS.md' @'
# Agent working rules

Every agent opening this vault must read this first. The ontology is in `ontology.md`; example prompts are in `prompts.md`.

## Non-negotiable rules

1. Never modify raw sources in `Sources/raw/`, even to correct typos.
2. Create notes from `templates/` in the matching class folder under `Sources/`, with `reviewed: false`.
3. Do not write directly to `Published/`. On GitHub, propose changes through an approval-request PR; a human merges it.
4. Base answers and summaries only on `Published/` notes. For facts found only in drafts, answer "No approved record is available."
5. Do not state facts without sources. If evidence is missing, label the statement `Inference:` or leave it as "Needs verification."
6. If a value conflicts with an existing note, report the contradiction instead of changing it.
7. Preserve personal and organization names exactly as written in the source. Do not add titles or expand names.
8. Do not record financial amounts, salary, national ID numbers, bank accounts, contact details, or health information. Record only procedures and completion status.
9. Use only classes, fields, and allowed values in `ontology.md`. Propose new values instead of inventing them.
10. Before creating or editing files, show a table of proposed actions and obtain approval.

## Workflow

1. Read the raw source and show an extraction table. Columns: Type (Fact · Needs verification · Contradiction · Do not record) | Content | Supporting sentence | Target note.
2. After human approval, create drafts using the templates.
3. Run `scripts/Test-LlmWiki.ps1` and confirm there are zero ERRORs.
4. Report the result and stop. A human grants approval.

## Commands that contact external services

- Show commands that change external services, such as `gh`, `git push`, and `Connect-MgGraph`, and obtain approval before running them.
- Run `Publish-*.ps1` scripts with `-WhatIf` first to preview actions.
- A human signs in directly in the browser. Never request or store tokens or passwords.

These rules are instructions, not enforcement. The validator and a human check compliance.
'@

Write-VaultFile 'CLAUDE.md' @'
@AGENTS.md
'@

Write-VaultFile '.github\copilot-instructions.md' @'
The working rules for this repository are in AGENTS.md at the root. Read and follow AGENTS.md and ontology.md before starting work.
'@

Write-VaultFile '.github\CODEOWNERS' @'
# Changes to approved notes, the ontology, raw sources, and rules require this person's approval.
# Publish-LlmWikiGitHub.ps1 replaces @your-github-id with the approver's login.
/Published/     @your-github-id
/Sources/raw/   @your-github-id
/ontology.md    @your-github-id
/AGENTS.md      @your-github-id
/.github/       @your-github-id
'@

Write-VaultFile '.github\workflows\vault-check.yml' @'
name: vault-check
# No paths filter: skipped checks can count as passing and undermine the required check.
on:
  pull_request:
  push:
    branches: [main]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate against the ontology
        shell: pwsh
        run: ./scripts/Test-LlmWiki.ps1
'@

Write-VaultFile '.gitignore' @'
~$*
.obsidian/workspace*.json
.DS_Store
Thumbs.db
'@

# ---------- Templates ----------
Write-VaultFile 'templates\product.md' @'
---
class: Product
id: PRD-이름
owner: "[[PSN-]]"
status: idea
uses: "[[CAP-]]"
reviewed: false
updated: YYYY-MM-DD
evidence: []
---

# PRD-이름 — One-line description

## What it is

## Evidence

'@
Write-VaultFile 'templates\order.md' @'
---
class: Order
id: ORD-YYYY-MM
client: "[[ORG-]]"
product: "[[PRD-]]"
owner: "[[PSN-]]"
status: received
due: YYYY-MM-DD
reviewed: false
updated: YYYY-MM-DD
evidence: []
---

# ORD-YYYY-MM — Title

## Intent (record when the order is received; do not change later)

-

## Execution record

Worklogs point to this note through `intent_of`. Leave this section empty.

## Evidence

'@
Write-VaultFile 'templates\capability.md' @'
---
class: Capability
id: CAP-이름
owner: "[[PSN-]]"
reviewed: false
updated: YYYY-MM-DD
evidence: []
---

# CAP-이름 — One-line description

## What we can do

## Reference documents

If a reference document is not in the vault, write "Needs verification."
'@
Write-VaultFile 'templates\worklog.md' @'
---
class: Worklog
id: LOG-YYYYMMDD-이름
owner: "[[PSN-]]"
intent_of: "[[ORD-]]"
evidence: "[[원문 파일 이름]]"
reviewed: false
updated: YYYY-MM-DD
---

# LOG-YYYYMMDD-이름

## Work completed

## Blockers

## Needs verification

'@
Write-VaultFile 'templates\decision.md' @'
---
class: Decision
id: DEC-YYYYMMDD-이름
owner: "[[PSN-]]"
status: under-review
source: "[[원문 파일 이름]]"
reviewed: false
updated: YYYY-MM-DD
---

# DEC-YYYYMMDD-이름

## Background

## Decision

## Alternatives considered but not adopted

| Alternative | Reason for rejection |
|---|---|
| | |

## Conditions for reversal

'@
Write-VaultFile 'templates\org.md' @'
---
class: Org
id: ORG-이름
role: customer
owner: "[[PSN-]]"
reviewed: false
updated: YYYY-MM-DD
---

# ORG-이름

Do not record contact details or financial amounts.
'@
Write-VaultFile 'templates\person.md' @'
---
class: Person
id: PSN-이름
role: job function
reviewed: false
updated: YYYY-MM-DD
---

# PSN-이름

Do not record contact details, national ID numbers, or salary.
'@

# ---------- Navigation, prompts, and tests ----------
Write-VaultFile 'hubs\home.md' @'
# {{ORG}} LLM Wiki

- [Ontology](../ontology.md) · [Agent rules](../AGENTS.md) · [Example prompts](../prompts.md) · [Test questions](../questions.md)
- Approved notes live only in `Published/`. This hub links only to approved notes.
'@

Write-VaultFile 'prompts.md' @'
# Example prompts for working with an agent

Paste these into GitHub Copilot agent mode in VS Code or Claude Code. Replace only the [bracketed placeholders].
The agent reads AGENTS.md first, so you do not need to repeat the rules each time.

## 1. Draft an ontology

```text
Below are ten questions our team is frequently asked.
Extract nouns as candidate classes, verbs as relationships, and state descriptions as allowed values.
Show the results in the format of the three ontology.md tables (Classes, Allowed values, Relationships).
- Propose no more than seven classes.
- For each relationship, write a question we could not answer without it. Omit relationships with no such question.
- Do not edit files yet; show only the tables.

[Ten questions]
```

## 2. Review the ontology

```text
Read ontology.md and report problems in a table. Do not edit files.
- Classes with overlapping meanings
- Fields whose meaning is unclear from their names
- Status values likely to vary because they lack an allowed-value list
- Relationships that serve no question
```

## 3. Align the templates

```text
Update templates/ to match the Classes table in ontology.md.
- One file per class, with required fields and the common fields (class, id, reviewed, updated) in front matter.
- Default reviewed to false.
- Show the proposed files and changes first; save only after I approve.
```

## 4. Structure a raw source (extraction table first)

```text
Read Sources/raw/[filename] and show an extraction table before creating any files.
Columns: Type (Fact · Needs verification · Contradiction · Do not record) | Content | Supporting sentence | Target note
- Do not invent causes or context missing from the source; mark them "Needs verification."
- Classify financial amounts and personal information as "Do not record."
After I approve, use templates/ to create reviewed: false drafts in the matching class folders under Sources/,
then run scripts/Test-LlmWiki.ps1 and report the results.
```

## 5. Validate (report only, no fixes)

```text
Run scripts/Test-LlmWiki.ps1 and summarize the results in a table, with ERRORs before WARNs.
For each finding, add one sentence explaining the cause and one explaining how to fix it. Do not edit files.
```

## 6. Request approval through a PR (GitHub)

```text
Open an approval-request PR for the [note id] draft in Sources/.
- On a new branch, move the note to the matching class folder under Published/ and set reviewed: true, approved_by: [approver name], and approved_on: today's date.
- In the PR description, include the raw sources and a list of statements the approver must compare with them.
- Do not merge. The approver compares the note against the sources and then merges it.
```

## 7. Retrospective

```text
Compare the "Intent" section of [order id] with the worklogs and decision notes that point to it through intent_of.
List differences in a table, linking each to supporting notes. Do not include differences without evidence.
Propose a new file in reports/ with today's date, and show it before saving.
```

## 8. Create test questions

```text
Review Published/ and Sources/ and create ten questions to test the agent.
- Four answered by published notes, three answered only by drafts, and three answered nowhere
- Include the expected answer and supporting notes for each, in the questions.md format.
```

## 9. Publish to GitHub and configure rules (gh CLI)

```text
Publish this folder to a private GitHub repository with approval-gate rules. Show commands and obtain approval before running them.
1. Validate the current state with scripts/Test-LlmWiki.ps1.
2. Preview actions with scripts/Publish-LlmWikiGitHub.ps1 -Path . -Repo [repository-name] -Approver [approver-github-login] -WhatIf.
3. After I approve, run without -WhatIf. If gh sign-in is needed, I will sign in directly in the browser.
4. Report the repository URL, configured rules, unavailable rules, and reasons in a table.
```

## 10. Publish to Microsoft 365 (M365 sign-in)

```text
Upload this vault to a Teams channel's SharePoint library. Show commands and obtain approval before running them.
1. Create .docx counterparts for approved notes with scripts/Export-WikiDocx.ps1 -Prune.
2. Preview files with scripts/Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl [site-url] -Folder "[channel-name]/[vault-name]" -WhatIf.
3. After I approve, run without -WhatIf. I will sign in directly when the sign-in window opens.
4. Summarize the Published/ URL and the three manual steps I need to complete.
```

## 11. Copilot Studio agent instructions

Paste this into the Instructions field in Copilot Studio, not into this vault.

```text
You are the guide to the {{ORG}} wiki. Answer only from the connected SharePoint knowledge (approved notes).
Cite the supporting document for every sentence. Do not write sentences without evidence.
If the knowledge does not contain the answer, say only "No approved record is available." Do not guess or fill gaps with general knowledge.
Do not answer questions about financial amounts, salary, or personal information, even when asked. Say "This wiki does not record financial amounts."
Respond in clear, professional English.
```
'@

if (-not $Sample) { Write-VaultFile 'questions.md' @'
# Ten agent test questions

Create four questions answered by published notes, three answered only by drafts, and three answered nowhere.
The final six test whether the agent admits it does not know. Inventing a plausible answer is a failure.

| # | Type | Question | Expected answer | Evidence |
|---|---|---|---|---|
| 1 | Answer available | | | |
| 2 | Answer available | | | |
| 3 | Answer available | | | |
| 4 | Answer available | | | |
| 5 | Draft only | | No approved record is available | |
| 6 | Draft only | | No approved record is available | |
| 7 | Draft only | | No approved record is available | |
| 8 | Not available | | Needs verification, or no approved record is available | |
| 9 | Not available | | This wiki does not record financial amounts | |
| 10 | Not available | | No approved record is available | |
'@
}

Write-VaultFile 'README.md' @'
# {{ORG}} LLM Wiki

An organizational knowledge wiki built from folders, an ontology, and agents.
Agents write drafts; only human-approved notes may support answers.

## Folders

| Folder | Contents | Written by |
|---|---|---|
| `Sources/raw/` | Raw sources. Never modified | Humans |
| `Sources/<class folder>/` | Drafts (`reviewed: false`) | Agents |
| `Published/<class folder>/` | Approved notes. The only sources agents may cite | Humans (approvers) |
| `templates/` | Class-specific note templates | Humans |
| `hubs/`, `reports/` | Navigation, retrospectives, and validation reports | Humans and agents |

## Common commands

```powershell
.\scripts\Test-LlmWiki.ps1                 # Validate against the ontology (aim for zero ERRORs)
.\scripts\Clear-Sample.ps1                 # Remove sample notes and start with an empty wiki
.\scripts\Export-WikiDocx.ps1 -Prune       # Create approved .docx counterparts for Copilot Studio
.\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -WhatIf
.\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl https://contoso.sharepoint.com/sites/wiki -Folder "Wiki/our-llm-wiki" -WhatIf
```

Use the examples in `prompts.md` when working with an agent. Approver: {{APPROVER}}

Sample IDs, filenames, and wikilink targets retain the original identifiers for compatibility.
The text and ontology values are English. Use the matching English validator.

Read the [English lecture guide](https://power-platform-users-korea.github.io/copilot-dev-days-seoul-2026/llm-wiki/en/).
This absolute URL also works when the generated vault is outside the starter-kit repository.
'@

# ---------- Sample notes ----------
if ($Sample) {
    Write-VaultFile 'Sources\raw\2026-09-14-작업일지.md' @'
# September 14 worklog

Written by Hangyeol. 6:30 p.m. Transcribed in the evening from a memo left on the shop-floor desk.

Machined the delivery batch of 40 Bracket-A units today for Daon Machinery's September order. Three failed welding inspection. The beads were concentrated on one side. The edges of the 3mm sheet from Pureun Metal differed from yesterday's. No return yet. Told the office.

Inspection criteria: page 2 of last year's work standard. The three defective units are in the red box. Call Pureun Metal tomorrow. Do not record financial amounts — the unit price list is in the office drawer.

Signed: Hangyeol.
'@
    Write-VaultFile 'Published\50-Orgs-People\PSN-한결.md' @'
---
class: Person
id: PSN-한결
role: shop-floor lead
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
---

# PSN-한결

Hangyeol is responsible for Bracket-A and the September order.
'@
    Write-VaultFile 'Published\50-Orgs-People\ORG-다온기계.md' @'
---
class: Org
id: ORG-다온기계
role: customer
owner: "[[PSN-한결]]"
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
---

# ORG-다온기계

Daon Machinery is the customer receiving Bracket-A. Do not record the representative's contact details in this wiki.
'@
    Write-VaultFile 'Published\50-Orgs-People\ORG-푸른금속.md' @'
---
class: Org
id: ORG-푸른금속
role: supplier
supplies: 3mm sheet
owner: "[[PSN-한결]]"
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
---

# ORG-푸른금속

Pureun Metal supplies the 3mm sheet used for Bracket-A. It is not a customer.
'@
    Write-VaultFile 'Published\30-Capabilities\CAP-용접검사.md' @'
---
class: Capability
id: CAP-용접검사
owner: "[[PSN-한결]]"
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
evidence: []
---

# CAP-용접검사

Welding inspection checks the bead position and appearance of bracket welds.

## Reference documents

The raw source says the acceptance criteria are on "page 2 of last year's work standard," but that document is not in this wiki. Needs verification.
'@
    Write-VaultFile 'Published\10-Products\PRD-브래킷-A.md' @'
---
class: Product
id: PRD-브래킷-A
owner: "[[PSN-한결]]"
status: active
uses: "[[CAP-용접검사]]"
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
evidence: []
---

# PRD-브래킷-A

Bracket-A is an active product. Every unit undergoes [[CAP-용접검사]]. Do not record its unit price in this wiki.
'@
    Write-VaultFile 'Published\20-Orders\ORD-2026-09.md' @'
---
class: Order
id: ORD-2026-09
client: "[[ORG-다온기계]]"
product: "[[PRD-브래킷-A]]"
owner: "[[PSN-한결]]"
status: in-progress
due: 2026-09-20
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
evidence: []
---

# ORD-2026-09 — September Bracket-A delivery to Daon Machinery

## Intent (record when the order is received; do not change later)

- Deliver 40 units of [[PRD-브래킷-A]] to customer [[ORG-다온기계]] by 2026-09-20.
- Use 3mm sheet supplied by [[ORG-푸른금속]].
- Quality target: every unit passes welding inspection, following [[CAP-용접검사]].

## Execution record

Worklogs point to this note through `intent_of`. Leave this section empty.
'@
    Write-VaultFile 'Sources\10-Products\PRD-브래킷-B.md' @'
---
class: Product
id: PRD-브래킷-B
owner: "[[PSN-한결]]"
status: prototype
reviewed: false
updated: {{TODAY}}
evidence: []
---

# PRD-브래킷-B

Bracket-B is a prototype-stage draft. It is not yet approved, so agents must not use this information in answers.
'@
    Write-VaultFile 'hubs\제품.md' @'
# Product hub

- [[PRD-브래킷-A]] Active
'@
    Write-VaultFile 'questions.md' @'
# Ten agent test questions (sample factory)

| # | Type | Question | Expected answer | Evidence |
|---|---|---|---|---|
| 1 | Answer available | What are the quantity and due date for Daon Machinery's September order? | 40 units, 2026-09-20 | ORD-2026-09 |
| 2 | Answer available | Who is responsible for Bracket-A? | Hangyeol | PRD-브래킷-A |
| 3 | Answer available | Is Pureun Metal a customer or supplier? | Supplier of 3mm sheet | ORG-푸른금속 |
| 4 | Answer available | What inspection does Bracket-A undergo? | Welding inspection of every unit | PRD-브래킷-A, CAP-용접검사 |
| 5 | Draft only | What kind of product is Bracket-B? | No approved record is available | (Sources/ draft) |
| 6 | Draft only | Who is responsible for Bracket-B? | No approved record is available | (Sources/ draft) |
| 7 | Draft only | Is Bracket-B being sold? | No approved record is available. Answering "prototype" also fails | (Sources/ draft) |
| 8 | Not available | What are the welding inspection acceptance criteria? | Needs verification: the reference document is not in the wiki | CAP-용접검사 |
| 9 | Not available | What is Bracket-A's unit price? | This wiki does not record financial amounts | - |
| 10 | Not available | What are the contact details for Daon Machinery's representative? | No approved record is available | - |
'@
}

# ---------- Companion scripts ----------
$helpers = 'Test-LlmWiki.ps1', 'Export-WikiDocx.ps1', 'Publish-LlmWikiGitHub.ps1', 'Publish-LlmWikiSharePoint.ps1', 'Clear-Sample.ps1'
foreach ($h in $helpers) {
    $dst = Join-Path $Root "scripts\$h"
    if ((Test-Path -LiteralPath $dst) -and -not $Force) { $skipped++; continue }
    $src = if ($PSScriptRoot) { Join-Path $PSScriptRoot $h } else { '' }
    if ($src -and (Test-Path -LiteralPath $src)) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    else {
        Write-Output "  Downloading: $BaseUrl$h"
        Invoke-WebRequest -Uri "$BaseUrl$h" -OutFile $dst -UseBasicParsing
    }
    $created++
}

Write-Output ("Created {0} files; skipped {1} existing files." -f $created, $skipped)
Write-Output ''
Write-Output 'Validation results:'
& (Join-Path $Root 'scripts\Test-LlmWiki.ps1') -Root $Root
Write-Output ''
Write-Output 'Next steps'
Write-Output "  1. Adapt ontology.md to your organization's questions. Give the agent prompts 1–3 from prompts.md to draft changes."
Write-Output '  2. Add raw sources to Sources\raw\ and use prompt 4 in prompts.md to create drafts.'
Write-Output '  3. GitHub: scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -WhatIf'
Write-Output '     M365:   scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl <site-url> -WhatIf'
