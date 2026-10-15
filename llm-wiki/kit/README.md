# LLM Wiki 시작 키트 (PowerShell)

GitHub Copilot Dev Days Seoul 2026 · 세션 02 "깃허브로 만드는 LLM Wiki"의 실습 키트입니다.
기본 온톨로지와 LLM Wiki 뼈대를 만들고, 검사하고, 깃허브나 Microsoft 365에 올리는 스크립트 여섯 개가 들어 있습니다.

| 스크립트 | 하는 일 |
|---|---|
| `New-LlmWiki.ps1` | 설계서(`ontology.md`), 에이전트 규칙(`AGENTS.md`), 템플릿 7개, 폴더, 예시 프롬프트, 시험 문항, 깃허브 설정 파일을 한 번에 만듭니다. `-Sample`을 붙이면 예시 노트도 들어갑니다 |
| `Test-LlmWiki.ps1` | `ontology.md`를 기준으로 클래스, 필수 필드, 허용 값, 승인 필드, 위키링크, 기밀 의심 단어를 검사합니다. ERROR가 있으면 종료 코드 1 |
| `Export-WikiDocx.ps1` | `Published/`의 노트마다 같은 이름의 .docx를 Word로 만듭니다. Copilot Studio가 .md 본문을 읽지 못해서 필요합니다 |
| `Publish-LlmWikiGitHub.ps1` | gh CLI로 비공개 저장소를 만들어 올리고, PR 필수·승인자·필수 검사·원문 보호 규칙을 겁니다 |
| `Publish-LlmWikiSharePoint.ps1` | Microsoft 365에 로그인해 SharePoint 문서 라이브러리(Teams 채널 파일)에 올리고 Copilot Studio에 넣을 주소를 알려 줍니다 |
| `Clear-Sample.ps1` | 예시 노트만 지워 빈 위키에서 시작하게 합니다. 직접 만든 노트는 그대로 둡니다 |

## 가장 빠른 시작: 템플릿 저장소

깃허브를 쓴다면 [parandurume-labs/llm-wiki-template](https://github.com/parandurume-labs/llm-wiki-template)에서 **Use this template**을 누르세요. 이 키트로 만든 뼈대에 예시 노트와 검사 워크플로까지 담긴 내 저장소가 바로 생깁니다.

```powershell
gh repo create my-org/our-llm-wiki --private --template parandurume-labs/llm-wiki-template --clone
```

## 빠른 시작: 키트로 직접 만들기

Windows PowerShell 5.1과 PowerShell 7에서 모두 돌아갑니다.

```powershell
# 1. 키트 내려받기 (또는 강의 페이지의 zip)
$kit = 'https://power-platform-users-korea.github.io/copilot-dev-days-seoul-2026/llm-wiki/kit'
Invoke-WebRequest "$kit/New-LlmWiki.ps1" -OutFile New-LlmWiki.ps1

# 2. 뼈대 만들기. 나머지 스크립트는 scripts/ 로 저절로 내려받습니다.
powershell -ExecutionPolicy Bypass -File .\New-LlmWiki.ps1 -Path .\our-llm-wiki -OrgName "우리 회사" -Approver "홍길동" -Sample

# 3. 검사
cd .\our-llm-wiki
.\scripts\Test-LlmWiki.ps1
```

브라우저로 zip을 받았다면 압축을 풀기 전에 `Unblock-File .\llm-wiki-kit.zip`을 실행하세요.

## 올리는 두 가지 길

**Microsoft 365**
- 가장 쉬운 길: Teams 채널 파일 탭에서 "동기화"를 누르고, `-Path`를 그 동기화 폴더로 주면 OneDrive가 SharePoint에 올립니다.
- 에이전트에게 맡기는 길: `.\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl <사이트 주소> -Folder "<채널 이름>/our-llm-wiki" -WhatIf`

**깃허브**
- `.\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -Approver <GitHub 아이디> -WhatIf`
- 비공개 저장소에 규칙을 걸려면 개인 계정은 GitHub Pro, 조직은 Team 이상이 필요합니다. 쓸 수 없으면 경고만 하고 넘어갑니다.

두 스크립트 모두 `-WhatIf`로 먼저 실행해 할 일을 확인한 뒤, `-WhatIf` 없이 다시 실행합니다. 로그인은 사람이 브라우저에서 직접 합니다.

## 에이전트와 함께 쓰기

볼트의 `prompts.md`에 단계별 예시 프롬프트 열한 개가 있습니다. VS Code의 GitHub Copilot 에이전트 모드나 Claude Code에 붙여 넣으세요. 에이전트는 `AGENTS.md`의 규칙을 먼저 읽습니다.

## 알아 둘 한계

- 검사 스크립트는 원문이 바뀌었는지, 승인자가 진짜인지, 문장이 원문에 있는지는 보지 못합니다. 그 확인은 사람이 합니다.
- `Export-WikiDocx.ps1`은 Word가 설치된 Windows에서만 돌아갑니다.
- 깃허브 규칙과 SharePoint 업로드는 계정, 요금제, 테넌트 정책에 따라 막힐 수 있습니다. 스크립트는 막힌 단계를 알려 주고 이유를 출력합니다.

더 깊이 배우려면: https://llm-wiki-lecture.paranduru.me/
