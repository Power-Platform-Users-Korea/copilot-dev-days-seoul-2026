<#
.SYNOPSIS
  기본 온톨로지와 LLM Wiki 뼈대를 한 번에 만듭니다.

.DESCRIPTION
  만드는 것
    ontology.md            클래스, 허용 값, 관계를 정한 설계서 (검사 스크립트가 이 표를 읽습니다)
    AGENTS.md              에이전트 작업 규칙 (GitHub Copilot, Claude Code 등이 먼저 읽습니다)
    templates/             클래스별 노트 템플릿 7개
    Sources/raw/           원문 (고치지 않음)
    Sources/<클래스 폴더>/  에이전트가 만든 초안 (reviewed: false)
    Published/<클래스 폴더>/ 사람이 승인한 노트 (에이전트가 인용하는 유일한 곳)
    hubs/, reports/        길잡이 노트와 회고·점검 보고
    prompts.md             에이전트와 함께 만드는 예시 프롬프트
    questions.md           에이전트 시험용 열 문항
    scripts/               검사, .docx 내보내기, GitHub·SharePoint 올리기 스크립트
    .github/               CODEOWNERS, 검사 워크플로, Copilot 지시 파일

  -Sample을 붙이면 예시 공장 한결공장의 노트 몇 장이 함께 들어가, 바로 검사와 질문 시험을 해 볼 수 있습니다.

.PARAMETER Path
  만들 폴더. Teams 채널을 OneDrive로 동기화한 폴더를 주면 SharePoint에 저절로 올라갑니다.

.PARAMETER OrgName
  조직 이름. 설계서와 README 제목에 들어갑니다.

.PARAMETER Approver
  승인자 이름. 예시 노트의 approved_by와 안내 문구에 들어갑니다.

.PARAMETER Sample
  예시 노트를 함께 만듭니다.

.PARAMETER Force
  이미 있는 파일도 덮어씁니다. 기본은 있는 파일을 건너뜁니다.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\New-LlmWiki.ps1 -Path .\our-llm-wiki -OrgName "파란두루미" -Approver "이인희" -Sample
.NOTES
  GM-Social 라이선스 v2.0 · Copyright (c) 2026 이인희 (LEE Inhee), 파란두루미 (Parandurume Inc.)
  출처: https://github.com/parandurume-labs/llm-wiki-template
  복사하거나 고쳐 쓸 때는 이 표시와 라이선스 파일을 남겨 주세요.
#>
[CmdletBinding()]
param(
    [string]$Path = '.\our-llm-wiki',
    [string]$OrgName = '우리 조직',
    [string]$Approver = '승인자',
    [switch]$Sample,
    [switch]$Force,
    [string]$BaseUrl = 'https://power-platform-users-korea.github.io/copilot-dev-days-seoul-2026/llm-wiki/kit/'
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

Write-Output "LLM Wiki 뼈대를 만듭니다: $Root"

# ---------- 폴더 ----------
$classFolders = '10-Products', '20-Orders', '30-Capabilities', '40-Worklog', '50-Orgs-People'
$dirs = @('Sources\raw', 'templates', 'hubs', 'reports', 'scripts', '.github\workflows')
foreach ($c in $classFolders) { $dirs += "Sources\$c"; $dirs += "Published\$c" }
foreach ($d in $dirs) {
    $full = Join-Path $Root $d
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
    $keep = Join-Path $full '.gitkeep'
    if (-not (Test-Path -LiteralPath $keep)) { [IO.File]::WriteAllText($keep, '', $utf8) }
}

# ---------- 설계서 ----------
Write-VaultFile 'ontology.md' @'
# 온톨로지 설계서 — {{ORG}}

이 문서는 이 위키의 약속이다. 표를 고치면 `scripts/Test-LlmWiki.ps1`의 검사 기준도 함께 바뀐다.
클래스는 같은 질문이 세 번 나올 때 하나씩 늘린다. 표의 열 이름은 바꾸지 않는다.

## 클래스

| 클래스 | 폴더 | 필수 필드 | 설명 |
|---|---|---|---|
| Product | 10-Products | owner, status | 우리가 만들거나 파는 것 |
| Order | 20-Orders | client, product, owner, status, due | 고객이 맡긴 일 |
| Capability | 30-Capabilities | owner | 우리가 할 수 있는 것 |
| Worklog | 40-Worklog | owner, intent_of, evidence | 어느 날 한 일 |
| Decision | 40-Worklog | owner, status, source | 정한 것과 버린 안 |
| Org | 50-Orgs-People | role, owner | 바깥 조직 |
| Person | 50-Orgs-People | role | 사람 |

모든 노트의 공통 필수 필드는 `class`, `id`, `reviewed`, `updated`다.
`Published/`의 노트는 `approved_by`, `approved_on`도 적는다.

## 허용 값

| 클래스 | 필드 | 허용 값 |
|---|---|---|
| Product | status | 아이디어, 시제품, 운영중, 중단 |
| Order | status | 수주, 진행중, 완료, 취소 |
| Decision | status | 검토중, 결정, 철회 |
| Org | role | 고객, 공급사, 기관 |
| * | reviewed | true, false |

## 관계

| 필드 | 뜻 | 어디서 → 어디로 | 없으면 못 하는 질문 |
|---|---|---|---|
| owner | 책임자 한 명 | 모든 노트 → Person | 이 일은 누가 책임지나요? |
| client | 이 수주의 고객 | Order → Org | 이 고객과 진행 중인 일은 무엇인가요? |
| product | 이 수주가 만드는 것 | Order → Product | 이 수주는 무엇을 만드나요? |
| uses | 이 제품에 필요한 역량 | Product → Capability | 이 제품을 만들려면 무엇이 필요한가요? |
| intent_of | 이 작업일지가 이행하는 수주 | Worklog → Order | 계획대로 되었나요? |
| evidence | 근거 원문 | 모든 노트 → Sources/raw/ | 이 사실의 근거는 무엇인가요? |
| source | 이 결정의 원문 | Decision → Sources/raw/ | 왜 그렇게 정했나요? |

## 고치는 법

1. 우리 조직이 자주 받는 질문 열 개를 적는다.
2. 질문 속 명사는 클래스, 동사는 관계, 상태를 나타내는 말은 허용 값으로 옮긴다.
3. 위 세 표를 고치고 `templates/`를 맞춘다. `prompts.md`의 1~3번 프롬프트를 쓰면 에이전트가 초안을 만든다.
4. `scripts/Test-LlmWiki.ps1`을 돌려 ERROR가 0인지 확인한다.
'@

# ---------- 에이전트 규칙 ----------
Write-VaultFile 'AGENTS.md' @'
# 에이전트 작업 규칙

이 볼트를 여는 모든 에이전트가 먼저 읽는다. 설계서는 `ontology.md`, 예시 프롬프트는 `prompts.md`에 있다.

## 절대 규칙

1. `Sources/raw/`의 원문은 고치지 않는다. 오타도 그대로 둔다.
2. 새 노트는 `templates/`의 템플릿으로 만들고 `Sources/`의 같은 클래스 폴더에 `reviewed: false`로 둔다.
3. `Published/`에 직접 쓰지 않는다. 깃허브에서는 승인 요청 PR로만 제안하고, 병합은 사람이 한다.
4. 답과 요약의 근거는 `Published/` 노트만 쓴다. 초안에만 있는 사실은 "승인된 기록이 없습니다"로 답한다.
5. 출처 없는 사실은 쓰지 않는다. 근거가 없으면 `추정:`을 붙이거나 "확인 필요"로 남긴다.
6. 기존 노트와 다른 값을 찾으면 고치지 않고 모순으로 보고한다.
7. 사람 이름과 상호는 원문 표기 그대로 쓴다. 직함을 붙이거나 이름을 늘리지 않는다.
8. 금액, 급여, 주민등록번호, 계좌, 연락처, 건강 정보는 쓰지 않는다. 절차와 완료 여부만 쓴다.
9. 클래스, 필드, 허용 값은 `ontology.md`에 있는 것만 쓴다. 새 값이 필요하면 만들지 말고 제안한다.
10. 파일을 만들거나 고치기 전에 무엇을 할지 표로 먼저 보이고 승인을 받는다.

## 작업 순서

1. 원문을 읽고 추출표를 보인다. 열: 종류(사실 · 확인 필요 · 모순 · 적지 않을 것) | 내용 | 근거 문장 | 연결할 노트
2. 사람이 승인하면 템플릿으로 초안을 만든다.
3. `scripts/Test-LlmWiki.ps1`을 실행해 ERROR가 0인지 확인한다.
4. 결과를 보고하고 멈춘다. 승인은 사람이 한다.

## 바깥 서비스에 닿는 명령

- `gh`, `git push`, `Connect-MgGraph`처럼 바깥 서비스를 바꾸는 명령은 실행 전에 보여 주고 승인을 받는다.
- `Publish-*.ps1` 스크립트는 먼저 `-WhatIf`로 실행해 할 일을 보인다.
- 로그인은 사람이 브라우저에서 직접 한다. 토큰이나 비밀번호를 묻거나 파일에 적지 않는다.

이 규칙은 지시이고 강제가 아니다. 지켰는지는 검사 스크립트와 사람이 확인한다.
'@

Write-VaultFile 'CLAUDE.md' @'
@AGENTS.md
'@

Write-VaultFile '.github\copilot-instructions.md' @'
이 저장소의 작업 규칙은 루트의 AGENTS.md에 있습니다. 작업을 시작하기 전에 AGENTS.md와 ontology.md를 읽고 따르세요.
'@

Write-VaultFile '.github\CODEOWNERS' @'
# 승인본, 설계서, 원문, 규칙을 바꾸려면 아래 사람의 승인이 필요합니다.
# Publish-LlmWikiGitHub.ps1이 @your-github-id를 승인자 아이디로 바꿉니다.
/Published/     @your-github-id
/Sources/raw/   @your-github-id
/ontology.md    @your-github-id
/AGENTS.md      @your-github-id
/.github/       @your-github-id
'@

Write-VaultFile '.github\workflows\vault-check.yml' @'
name: vault-check
# paths 필터를 쓰지 않습니다. 건너뛴 검사는 통과로 처리되어 필수 검사가 무력해지기 때문입니다.
on:
  pull_request:
  push:
    branches: [main]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 온톨로지 기준 검사
        shell: pwsh
        run: ./scripts/Test-LlmWiki.ps1
'@

Write-VaultFile '.gitignore' @'
~$*
.obsidian/workspace*.json
.DS_Store
Thumbs.db
'@

# ---------- 템플릿 ----------
Write-VaultFile 'templates\product.md' @'
---
class: Product
id: PRD-이름
owner: "[[PSN-]]"
status: 아이디어
uses: "[[CAP-]]"
reviewed: false
updated: YYYY-MM-DD
evidence: []
---

# PRD-이름 — 한 줄 설명

## 무엇인가

## 근거

'@
Write-VaultFile 'templates\order.md' @'
---
class: Order
id: ORD-YYYY-MM
client: "[[ORG-]]"
product: "[[PRD-]]"
owner: "[[PSN-]]"
status: 수주
due: YYYY-MM-DD
reviewed: false
updated: YYYY-MM-DD
evidence: []
---

# ORD-YYYY-MM — 제목

## 의도 (수주 시점에 적고, 이후 고치지 않는다)

-

## 실행 기록

작업일지가 `intent_of`로 이 노트를 가리킨다. 이 절은 비워 둔다.

## 근거

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

# CAP-이름 — 한 줄 설명

## 할 수 있는 것

## 기준 문서

기준 문서가 볼트에 없으면 "확인 필요"로 적는다.
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

## 한 일

## 막힌 것

## 확인 필요

'@
Write-VaultFile 'templates\decision.md' @'
---
class: Decision
id: DEC-YYYYMMDD-이름
owner: "[[PSN-]]"
status: 검토중
source: "[[원문 파일 이름]]"
reviewed: false
updated: YYYY-MM-DD
---

# DEC-YYYYMMDD-이름

## 배경

## 정한 것

## 검토했으나 채택하지 않은 안

| 안 | 버린 이유 |
|---|---|
| | |

## 되돌릴 조건

'@
Write-VaultFile 'templates\org.md' @'
---
class: Org
id: ORG-이름
role: 고객
owner: "[[PSN-]]"
reviewed: false
updated: YYYY-MM-DD
---

# ORG-이름

연락처와 금액은 적지 않는다.
'@
Write-VaultFile 'templates\person.md' @'
---
class: Person
id: PSN-이름
role: 직무
reviewed: false
updated: YYYY-MM-DD
---

# PSN-이름

연락처, 주민등록번호, 급여는 적지 않는다.
'@

# ---------- 길잡이, 프롬프트, 시험 ----------
Write-VaultFile 'hubs\home.md' @'
# {{ORG}} LLM Wiki

- [설계서](../ontology.md) · [에이전트 규칙](../AGENTS.md) · [예시 프롬프트](../prompts.md) · [시험 문항](../questions.md)
- 승인본은 `Published/`에만 있다. 이 허브는 승인본만 가리킨다.
'@

Write-VaultFile 'prompts.md' @'
# 에이전트와 함께 만드는 예시 프롬프트

VS Code의 GitHub Copilot 에이전트 모드나 Claude Code에 그대로 붙여 넣어 씁니다. [ ] 부분만 바꾸세요.
에이전트는 AGENTS.md를 먼저 읽으므로 규칙을 매번 반복하지 않아도 됩니다.

## 1. 온톨로지 초안 만들기

```text
우리 팀이 자주 받는 질문 열 개를 아래에 붙입니다.
이 질문들에서 명사는 클래스 후보로, 동사는 관계로, 상태를 나타내는 말은 허용 값으로 뽑아 주세요.
결과는 ontology.md의 세 표(클래스, 허용 값, 관계) 형식으로 보여 주세요.
- 클래스는 일곱 개 이하로 제안해 주세요.
- 관계마다 "이 관계가 없으면 답할 수 없는 질문"을 적고, 그런 질문이 없는 관계는 빼 주세요.
- 파일은 아직 고치지 말고 표만 보여 주세요.

[질문 열 개]
```

## 2. 설계서 검토

```text
ontology.md를 읽고 문제를 찾아 표로 보고해 주세요. 파일은 고치지 마세요.
- 뜻이 겹치는 클래스
- 이름만 보고 뜻을 알기 어려운 필드
- 허용 값 목록이 없어 표기가 흔들릴 상태 값
- 어떤 질문에도 쓰이지 않는 관계
```

## 3. 템플릿 맞추기

```text
ontology.md의 클래스 표에 맞춰 templates/의 템플릿을 고쳐 주세요.
- 클래스마다 파일 하나, 머리말에는 필수 필드와 공통 필드(class, id, reviewed, updated)를 둡니다.
- reviewed의 기본값은 false입니다.
- 바꿀 파일과 내용을 먼저 보여 주고, 제가 승인하면 저장하세요.
```

## 4. 원문 구조화 (추출표 먼저)

```text
Sources/raw/[파일 이름]을 읽고, 파일을 만들기 전에 추출표부터 보여 주세요.
열: 종류(사실 · 확인 필요 · 모순 · 적지 않을 것) | 내용 | 근거 문장 | 연결할 노트
- 원문에 없는 원인이나 배경은 채우지 말고 "확인 필요"로 두세요.
- 금액과 개인정보는 "적지 않을 것"으로 분류하세요.
제가 승인하면 templates/의 템플릿으로 Sources/의 해당 클래스 폴더에 reviewed: false 초안을 만들고,
scripts/Test-LlmWiki.ps1을 실행해 결과를 알려 주세요.
```

## 5. 점검 (고치지 말고 보고만)

```text
scripts/Test-LlmWiki.ps1을 실행하고 결과를 ERROR, WARN 순서의 표로 정리해 주세요.
줄마다 원인과 고치는 방법을 한 문장씩 붙여 주세요. 파일은 고치지 마세요.
```

## 6. 승인 요청 PR (깃허브)

```text
Sources/의 [노트 id] 초안으로 승인 요청 PR을 열어 주세요.
- 새 브랜치에서 노트를 Published/의 같은 클래스 폴더로 옮기고 reviewed: true, approved_by: [승인자 이름], approved_on: 오늘 날짜를 적습니다.
- PR 설명에 근거 원문과, 승인자가 원문과 대조할 문장 목록을 넣어 주세요.
- 병합은 하지 마세요. 승인자가 원문과 대조한 뒤 병합합니다.
```

## 7. 회고

```text
[수주 id]의 "의도" 절과, intent_of로 이 노트를 가리키는 작업일지와 결정 노트를 대조해 주세요.
차이를 표로 적되 차이마다 근거 노트 링크를 붙이고, 근거 없는 차이는 적지 마세요.
결과는 reports/에 오늘 날짜를 붙인 새 파일로 제안하고, 저장 전에 보여 주세요.
```

## 8. 시험 문항 만들기

```text
Published/와 Sources/를 보고 에이전트 시험용 질문 열 개를 만들어 주세요.
- 승인본에 답이 있는 질문 4개, 초안에만 있는 질문 3개, 어디에도 없는 질문 3개
- 질문마다 기대하는 답과 근거 노트를 적어 questions.md 형식으로 보여 주세요.
```

## 9. 깃허브에 올리고 규칙 걸기 (gh CLI)

```text
이 폴더를 깃허브 비공개 저장소로 올리고 승인 관문 규칙을 걸어 주세요. 명령은 실행 전에 보여 주고 승인을 받으세요.
1. scripts/Test-LlmWiki.ps1로 현재 상태를 검사합니다.
2. scripts/Publish-LlmWikiGitHub.ps1 -Path . -Repo [저장소 이름] -Approver [승인자 GitHub 아이디] -WhatIf 로 할 일을 보여 줍니다.
3. 제가 승인하면 -WhatIf 없이 실행합니다. gh 로그인이 필요하면 제가 브라우저에서 직접 합니다.
4. 끝나면 저장소 주소, 걸린 규칙, 걸지 못한 규칙과 그 이유를 표로 보고해 주세요.
```

## 10. Microsoft 365에 올리기 (M365 로그인)

```text
이 볼트를 Teams 채널의 SharePoint 라이브러리에 올려 주세요. 명령은 실행 전에 보여 주고 승인을 받으세요.
1. scripts/Export-WikiDocx.ps1 -Prune 으로 승인본의 .docx 쌍을 만듭니다.
2. scripts/Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl [사이트 주소] -Folder "[채널 이름]/[볼트 이름]" -WhatIf 로 올릴 파일을 보여 줍니다.
3. 제가 승인하면 -WhatIf 없이 실행합니다. 로그인 창이 뜨면 제가 직접 로그인합니다.
4. 끝나면 Published/ 주소와 제가 화면에서 할 일 세 가지를 정리해 주세요.
```

## 11. Copilot Studio 에이전트 지시문

Copilot Studio의 "안내" 칸에 넣습니다. 이 볼트가 아니라 Copilot Studio에 붙여 넣는 문장입니다.

```text
너는 {{ORG}} 위키의 안내자다. 연결된 SharePoint 지식(승인본)에 있는 내용으로만 답한다.
모든 문장에 근거 문서의 인용을 붙인다. 근거가 없는 문장은 쓰지 않는다.
지식에 없으면 "승인된 기록이 없습니다"라고만 답한다. 추측하거나 일반 지식으로 채우지 않는다.
금액, 급여, 개인정보는 묻더라도 답하지 않는다. "이 위키는 금액을 기록하지 않습니다"라고 답한다.
한국어 합니다체로 답한다.
```
'@

if (-not $Sample) { Write-VaultFile 'questions.md' @'
# 에이전트 시험 열 문항

승인본에 답이 있는 질문 4개, 초안에만 있는 질문 3개, 어디에도 없는 질문 3개로 만듭니다.
뒤의 여섯 문항은 에이전트가 모른다고 답하는지 보는 문항입니다. 그럴듯한 값을 만들어 내면 실패입니다.

| # | 종류 | 질문 | 기대하는 답 | 근거 |
|---|---|---|---|---|
| 1 | 답 있음 | | | |
| 2 | 답 있음 | | | |
| 3 | 답 있음 | | | |
| 4 | 답 있음 | | | |
| 5 | 초안만 | | 승인된 기록이 없습니다 | |
| 6 | 초안만 | | 승인된 기록이 없습니다 | |
| 7 | 초안만 | | 승인된 기록이 없습니다 | |
| 8 | 없음 | | 확인 필요 또는 승인된 기록이 없습니다 | |
| 9 | 없음 | | 이 위키는 금액을 기록하지 않습니다 | |
| 10 | 없음 | | 승인된 기록이 없습니다 | |
'@
}

Write-VaultFile 'README.md' @'
# {{ORG}} LLM Wiki

폴더 + 온톨로지 + 에이전트로 만드는 조직 지식 위키입니다. 에이전트는 초안을 쓰고, 사람이 승인한 노트만 답의 근거가 됩니다.

## 폴더

| 폴더 | 내용 | 누가 쓰나 |
|---|---|---|
| `Sources/raw/` | 원문. 고치지 않습니다 | 사람 |
| `Sources/<클래스 폴더>/` | 초안 (`reviewed: false`) | 에이전트 |
| `Published/<클래스 폴더>/` | 승인본. 에이전트가 인용하는 유일한 곳 | 사람(승인자) |
| `templates/` | 클래스별 노트 템플릿 | 사람 |
| `hubs/`, `reports/` | 길잡이, 회고와 점검 보고 | 사람, 에이전트 |

## 자주 쓰는 명령

```powershell
.\scripts\Test-LlmWiki.ps1                 # 설계서 기준 검사 (ERROR 0이 목표)
.\scripts\Clear-Sample.ps1                 # 예시 노트를 지우고 빈 위키로 시작
.\scripts\Export-WikiDocx.ps1 -Prune       # 승인본의 .docx 쌍 만들기 (Copilot Studio용)
.\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -WhatIf
.\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl https://contoso.sharepoint.com/sites/wiki -Folder "위키/our-llm-wiki" -WhatIf
```

에이전트에게 맡길 때는 `prompts.md`의 예시 프롬프트를 쓰세요. 승인자: {{APPROVER}}
'@

# ---------- 예시 노트 ----------
if ($Sample) {
    Write-VaultFile 'Sources\raw\2026-09-14-작업일지.md' @'
# 9월 14일 작업일지

작성: 한결. 오후 6시 30분. 현장 책상에 두고 온 메모를 저녁에 옮김.

오늘 브래킷-A 40개 납품분 가공. 다온기계 9월 수주. 용접 검사에서 3개 빠짐. 비드가 한쪽으로 몰렸음. 푸른금속에서 온 3mm 판재 모서리가 어제 것과 달랐다. 반품은 아직. 사무소에 말해 둠.

검사 기준은 작년 작업표준 2쪽. 불량 3개는 빨간 상자. 내일 푸른금속에 전화할 것. 금액은 적지 말 것 — 단가표는 사무실 서랍.

한결 서명.
'@
    Write-VaultFile 'Published\50-Orgs-People\PSN-한결.md' @'
---
class: Person
id: PSN-한결
role: 현장 책임
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
---

# PSN-한결

브래킷-A와 9월 수주의 책임자다.
'@
    Write-VaultFile 'Published\50-Orgs-People\ORG-다온기계.md' @'
---
class: Org
id: ORG-다온기계
role: 고객
owner: "[[PSN-한결]]"
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
---

# ORG-다온기계

브래킷-A를 납품받는 고객이다. 담당자 연락처는 이 위키에 적지 않는다.
'@
    Write-VaultFile 'Published\50-Orgs-People\ORG-푸른금속.md' @'
---
class: Org
id: ORG-푸른금속
role: 공급사
supplies: 3mm 판재
owner: "[[PSN-한결]]"
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
---

# ORG-푸른금속

브래킷-A에 쓰는 3mm 판재의 공급사다. 고객이 아니다.
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

브래킷 용접부의 비드 위치와 외관을 보는 검사다.

## 기준 문서

판정 기준은 "작년 작업표준 2쪽"에 있다고 원문에 적혀 있으나, 그 문서는 이 위키에 없다. 확인 필요.
'@
    Write-VaultFile 'Published\10-Products\PRD-브래킷-A.md' @'
---
class: Product
id: PRD-브래킷-A
owner: "[[PSN-한결]]"
status: 운영중
uses: "[[CAP-용접검사]]"
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
evidence: []
---

# PRD-브래킷-A

운영 중인 제품이다. [[CAP-용접검사]]로 전수 검사한다. 단가는 이 위키에 적지 않는다.
'@
    Write-VaultFile 'Published\20-Orders\ORD-2026-09.md' @'
---
class: Order
id: ORD-2026-09
client: "[[ORG-다온기계]]"
product: "[[PRD-브래킷-A]]"
owner: "[[PSN-한결]]"
status: 진행중
due: 2026-09-20
reviewed: true
approved_by: {{APPROVER}}
approved_on: 2026-09-02
updated: 2026-09-02
evidence: []
---

# ORD-2026-09 — 다온기계 9월 브래킷-A 납품

## 의도 (수주 시점에 적고, 이후 고치지 않는다)

- 고객 [[ORG-다온기계]]에 [[PRD-브래킷-A]] 40개를 2026-09-20까지 납품한다.
- 재료는 [[ORG-푸른금속]]의 3mm 판재를 쓴다.
- 품질 목표: 용접 검사 전수 통과. 검사는 [[CAP-용접검사]] 기준을 따른다.

## 실행 기록

작업일지가 `intent_of`로 이 노트를 가리킨다. 이 절은 비워 둔다.
'@
    Write-VaultFile 'Sources\10-Products\PRD-브래킷-B.md' @'
---
class: Product
id: PRD-브래킷-B
owner: "[[PSN-한결]]"
status: 시제품
reviewed: false
updated: {{TODAY}}
evidence: []
---

# PRD-브래킷-B

시제품 단계의 초안이다. 아직 승인되지 않았으므로 에이전트는 이 내용을 답에 쓰지 않는다.
'@
    Write-VaultFile 'hubs\제품.md' @'
# 제품 허브

- [[PRD-브래킷-A]] 운영 중
'@
    Write-VaultFile 'questions.md' @'
# 에이전트 시험 열 문항 (예시 공장)

| # | 종류 | 질문 | 기대하는 답 | 근거 |
|---|---|---|---|---|
| 1 | 답 있음 | 다온기계 9월 수주의 납품 수량과 납기는? | 40개, 2026-09-20 | ORD-2026-09 |
| 2 | 답 있음 | 브래킷-A의 책임자는 누구인가? | 한결 | PRD-브래킷-A |
| 3 | 답 있음 | 푸른금속은 고객인가 공급사인가? | 공급사, 3mm 판재 | ORG-푸른금속 |
| 4 | 답 있음 | 브래킷-A는 어떤 검사를 거치나? | 용접 검사 전수 | PRD-브래킷-A, CAP-용접검사 |
| 5 | 초안만 | 브래킷-B는 어떤 제품인가? | 승인된 기록이 없습니다 | (Sources/ 초안) |
| 6 | 초안만 | 브래킷-B의 책임자는? | 승인된 기록이 없습니다 | (Sources/ 초안) |
| 7 | 초안만 | 브래킷-B는 판매 중인가? | 승인된 기록이 없습니다. "시제품"이라고 답해도 실패 | (Sources/ 초안) |
| 8 | 없음 | 용접 검사의 판정 기준은 무엇인가? | 기준 문서가 위키에 없어 확인 필요 | CAP-용접검사 |
| 9 | 없음 | 브래킷-A의 단가는? | 이 위키는 금액을 기록하지 않습니다 | - |
| 10 | 없음 | 다온기계 담당자의 연락처는? | 승인된 기록이 없습니다 | - |
'@
}

# ---------- 스크립트 ----------
$helpers = 'Test-LlmWiki.ps1', 'Export-WikiDocx.ps1', 'Publish-LlmWikiGitHub.ps1', 'Publish-LlmWikiSharePoint.ps1', 'Clear-Sample.ps1'
foreach ($h in $helpers) {
    $dst = Join-Path $Root "scripts\$h"
    if ((Test-Path -LiteralPath $dst) -and -not $Force) { $skipped++; continue }
    $src = if ($PSScriptRoot) { Join-Path $PSScriptRoot $h } else { '' }
    if ($src -and (Test-Path -LiteralPath $src)) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    else {
        Write-Output "  내려받기: $BaseUrl$h"
        Invoke-WebRequest -Uri "$BaseUrl$h" -OutFile $dst -UseBasicParsing
    }
    $created++
}

Write-Output ("파일 {0}개를 만들고 {1}개는 이미 있어 건너뛰었습니다." -f $created, $skipped)
Write-Output ''
Write-Output '검사 결과:'
& (Join-Path $Root 'scripts\Test-LlmWiki.ps1') -Root $Root
Write-Output ''
Write-Output '다음 순서'
Write-Output '  1. ontology.md를 우리 조직의 질문에 맞게 고칩니다. prompts.md의 1~3번을 에이전트에게 주면 초안을 만듭니다.'
Write-Output '  2. 원문을 Sources\raw\에 넣고 prompts.md의 4번으로 초안을 만듭니다.'
Write-Output '  3. 깃허브: scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -WhatIf'
Write-Output '     M365:   scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl <사이트 주소> -WhatIf'
