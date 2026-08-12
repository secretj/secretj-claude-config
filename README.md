# secretj-claude-config

개인용 Claude Code dotfiles. **이 저장소 하나만 받으면 다른 컴퓨터에서 같은 환경으로 이어서 작업**할 수 있다.

```bash
git clone https://github.com/secretj/secretj-claude-config.git ~/Desktop/source/secretj-claude-config
cd ~/Desktop/source/secretj-claude-config && ./install.sh
```

무엇이 바뀌는지 먼저 보려면 `./install.sh --dry`.

---

## 무엇이 들어 있나

| 경로 | 설치 위치 | 방식 |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | symlink |
| `settings.json` | `~/.claude/settings.json` | symlink |
| `agents/` (16) | `~/.claude/agents/*.md` | 파일 단위 symlink |
| `commands/` (9) | `~/.claude/commands/*.md` | 파일 단위 symlink |
| `skills/` | `~/.claude/skills` | 디렉토리 symlink |
| `hooks/` | `~/.claude/hooks` | 디렉토리 symlink |
| `memory/` (19) | `~/.claude/projects/<home>/memory/` | **복사** |
| `mcp/mcp-servers.example.json` | `~/.claude.json` 의 `mcpServers` | `--mcp` 옵션 |

symlink 로 걸린 것들은 로컬에서 고치면 저장소에 바로 반영된다 — `git diff` 로 확인하고 커밋하면 다른 머신으로 넘어간다.

**memory 만 복사인 이유**: Claude 가 대화 중 새 memory 를 그 디렉토리에 계속 쓴다. symlink 였다면 앞으로 쌓이는 개인 메모가 전부 이 공개 저장소로 흘러든다. 그래서 설치는 단방향 복사(기존 파일 보존)이고, 공유하고 싶은 memory 만 손으로 `memory/` 에 넣어 커밋한다.

---

## agents — 역할별 sub-agent

**팀 역할 (10)** — 한국어 업무톤. 이름으로 직접 호출하거나(`@planner`) description 의 키워드로 자동 선택된다.

| 이름 | 역할 | 호출 트리거 |
|---|---|---|
| `planner` | 기획자 | "요구사항 정리", "PRD", "MVP", "유저 플로우" |
| `architect` | 아키텍트 | "구조 설계", "DDD", "ADR", "API 설계", "마이그레이션 계획" |
| `developer` | 개발자 | "구현", "리팩토링", "버그 수정", "성능 개선" |
| `designer` | 디자이너 | "UX", "레이아웃", "컬러/타이포", "접근성" |
| `qa` | QA | "테스트 케이스", "회귀", "스모크", "릴리스 게이트" |
| `security` | 보안 | "OWASP", "취약점", "XSS", "위협 모델" |
| `infra` | 인프라 | "배포", "CI/CD", "모니터링", "비용" |
| `pm` | PM | "일정", "진척", "리스크", "회고", "오케스트레이션" |
| `lead` | 팀장 | "결정", "방향", "리뷰 종합", "승인" |
| `marketer` | 마케터 | "마케팅", "카피", "타겟", "캠페인" |

**탐색 agent (6)** — `commands/` 가 내부적으로 호출한다. 직접 부를 일은 드물다.
`codebase-locator` · `codebase-analyzer` · `codebase-pattern-finder` · `docs-locator` · `docs-analyzer` · `web-search-researcher`

`pm` 은 `Agent` 도구로 다른 agent 를 직접 spawn 하는 오케스트레이터 모드를 갖는다.

---

## commands — 워크플로 슬래시 커맨드

| 커맨드 | 용도 |
|---|---|
| `/research` | 병렬 에이전트로 코드베이스 조사 → `.research/` 문서 |
| `/create-plan` | 조사 → 설계 → 단계별 구현 계획 → `.plans/` |
| `/implement-plan` | 계획서 Phase 별 구현 + 자동 검증 |
| `/iterate-plan` | 피드백 반영해 계획서 갱신 |
| `/validate-plan` | 구현 결과가 성공 기준을 만족하는지 검증 |
| `/debug` | 로그·git·파일 상태 병렬 조사로 원인 분석 |
| `/handoff` | 세션 인수인계 문서 작성 → `.handoffs/` |
| `/resume-handoff` | 인수인계 문서에서 컨텍스트 복원 후 재개 |
| `/commit-suggest` | staged 변경 + 히스토리 기반 커밋 메시지 추천 |

흐름: `/research` → `/create-plan` → `/implement-plan` → `/validate-plan`, 세션이 끊기면 `/handoff` → `/resume-handoff`.

---

## skills

| 스킬 | 용도 |
|---|---|
| `build-service` | 7개 subagent 를 PM 오케스트레이션으로 묶어 신규 서비스를 0에서 구축하는 8 Phase 워크플로 |
| `distill` | 세션에서 발견한 비자명한 도메인 지식을 Obsidian 에 구조화해 축적 |
| `sync-knowledge` | Obsidian 지식을 저장소 `CLAUDE.md` 의 "도메인 지식" 섹션으로 내보내 팀 공유 |

`distill` / `sync-knowledge` 는 Obsidian vault(`~/Documents/Obsidian Vault`)와 obsidian MCP 를 전제로 한다.

---

## hooks

`log-session.sh` — Stop hook. 세션이 끝날 때마다 `~/.reports/sessions.log` 에 20줄짜리 블록을 덧붙인다
(토큰 수, 도구 호출 수, 커밋, 변경 라인, 티켓 ID, 한 줄 요약).

티켓 ID 수집 패턴은 환경변수로 조절한다:

```bash
export TICKET_PREFIXES="ABC,DEF"   # ABC-123 / DEF-45 만 수집
```

미지정이면 대문자 프로젝트 키 일반형(`[A-Z][A-Z0-9]{1,9}-\d+`)을 쓴다.

---

## MCP 서버

`mcp/mcp-servers.example.json` 이 템플릿이다. **토큰은 절대 커밋하지 않는다.**

```bash
cp mcp/mcp-servers.example.json mcp/mcp-servers.json   # .gitignore 처리됨
$EDITOR mcp/mcp-servers.json                            # <...> 자리를 채운다
./install.sh --mcp
```

토큰이 필요 없는 것들은 그냥 이렇게 등록해도 된다:

```bash
claude mcp add-json --scope user codegraph  '{"type":"stdio","command":"codegraph","args":["serve","--mcp"]}'
claude mcp add-json --scope user playwright '{"type":"stdio","command":"npx","args":["-y","@playwright/mcp@latest"]}'
claude mcp add-json --scope user notion     '{"type":"http","url":"https://mcp.notion.com/mcp"}'
```

`obsidian` 은 Obsidian Local REST API 플러그인 키, `Neon` 은 Neon API 키가 필요하다.

---

## 설치 동작

| 상황 | 동작 |
|---|---|
| 대상이 없음 | symlink 생성 |
| 일반 파일/디렉토리 | `.bak.YYYYMMDD_HHMMSS` 로 백업 후 symlink |
| 이미 우리 저장소로 symlink | 건너뜀 (멱등) |
| 다른 곳으로 symlink | **건드리지 않고 경고만** — 다른 도구가 점유 중일 수 있음 |

`agents/`, `commands/` 는 파일 단위라 다른 출처의 파일과 한 디렉토리에서 공존한다.
단 그 디렉토리 자체가 dir-symlink 이면 개별 파일을 넣을 수 없어 건너뛴다.

제거: `./uninstall.sh` — 우리가 만든 symlink 만 지운다. `.bak.*` 와 복사된 memory 는 남는다.

---

## 이 저장소에 넣지 않는 것

- **소속 조직의 자산** — 사내 저장소 구조, 내부 호스트명, Jira/Confluence pageId, 티켓 ID, 조직 전용 MCP 패키지. `.gitignore` 로 `docs/`, `skills/wiki-report*/`, `private/` 를 차단해 둔다 (파일은 디스크에 남고 추적만 안 된다).
- **토큰·키** — `*.local.json`, `mcp-servers.json`, `.env`, `*.token`, `*.pem`, `*.key`.
- **새로 쌓이는 memory** — 위 "memory 만 복사인 이유" 참고.

커밋 전 확인:

```bash
git diff --cached | grep -niE "token|secret|api[_-]?key|Bearer |password"
```
