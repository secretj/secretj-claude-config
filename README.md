# secretj-claude-config

개인용 Claude Code dotfiles.

새 컴퓨터에서 `git pull` 두 번 + `install.sh` 두 번이면 Claude Code 환경이 그대로 복원됩니다.

---

## 설계 원칙

1. **회사 설정을 깨지 않는다** — 회사 install이 점유하는 `settings.json`, `commands/`, `CLAUDE.md` 는 손대지 않음.
2. **충돌 없는 영역은 디렉토리 단위 symlink** — `~/.claude/skills/`, `~/.claude/hooks/`.
3. **`agents/`는 이름 충돌을 wrapper로 회피** — 회사 agent는 install 시점에 `mailplug-*.md` wrapper로 변환되어 mailplug 작업 영역 전용으로 격리. 개인 agent는 일반 이름(`planner.md` 등)으로 모든 프로젝트의 기본값.
4. **다른 프로젝트에 영향 없음** — 글로벌 `~/.claude/`만 다루고, 개별 repo의 `.claude/`는 건드리지 않음.
5. **개인 비밀 절대 커밋 금지** — `.gitignore`로 `*.local.json`, `*.token`, `.env` 등 차단.

---

## 디렉토리 구조

```
secretj-claude-config/
├── install.sh        # ~/.claude/{skills,hooks,agents} 세팅
├── uninstall.sh      # 우리가 만든 symlink/wrapper만 제거
├── skills/           # 개인 Claude Code skills
├── hooks/            # 개인 hook 스크립트 (chmod +x 필요)
└── agents/           # 개인 sub-agent (mailplug 외부 기본값)
    ├── planner.md
    ├── developer.md
    ├── designer.md
    ├── pm.md
    ├── lead.md
    ├── marketer.md
    ├── qa.md
    ├── security.md
    └── infra.md
```

회사 agent 파일은 이 repo에 포함되지 않습니다. install이 회사 source를 읽어 `~/.claude/agents/mailplug-*.md` wrapper로 생성합니다.

---

## 설치 순서

새 머신에서:

```bash
# 1) 회사 dotfiles 먼저
cd ~/Desktop/source
git clone git@github.com:bradykim7/cursor-setting.git mailplug/cursor-setting
cd mailplug/cursor-setting && ./install.sh

# 2) 개인 dotfiles 다음
cd ~/Desktop/source
git clone https://github.com/secretj/secretj-claude-config.git
cd secretj-claude-config && ./install.sh
```

순서 중요: **회사 → 개인**. 회사 install이 만든 `~/.claude/agents` dir-symlink을 우리 install이 풀어 wrapper 생성 + 개인 agent symlink 추가합니다.

> ⚠️ **회사 install을 다시 실행하면** `~/.claude/agents` 가 dir-symlink으로 덮입니다 — 그 직후 우리 `install.sh` 를 다시 실행해서 머지를 복원하세요.

---

## install.sh 동작

### `skills/`, `hooks/` (디렉토리 단위 symlink)
| 상황 | 동작 |
|---|---|
| 없음 | symlink 생성 |
| 일반 디렉토리 | `.bak.YYYYMMDD_HHMMSS` 백업 후 symlink |
| 이미 우리 repo로 symlink | skip (멱등) |
| 다른 곳으로 symlink | **에러로 멈춤** — 수동 확인 필요 |

### `agents/` (wrapper 생성 + per-file symlink)

회사 source 우선순위 (찾는 순서):
1. `$MAILPLUG_AGENTS_SRC` 환경변수
2. `~/.claude/agents` 가 dir-symlink 이면 그 target
3. `~/.claude/agents/.mailplug-source` marker symlink
4. 기본 `~/Desktop/source/mailplug/cursor-setting/agents/claude-code`

회사 source를 찾으면:
- 회사 *.md 마다 `mailplug-{원본이름}.md` wrapper 파일 생성 (awk로 `name`/`description` 변경)
- description에 `[mailplug 작업 영역 전용] CWD가 mailplug/ 하위일 때만 사용...` 식별자 주입
- `.mailplug-source` symlink로 source 경로를 영속화 (다음 install에서 같은 source 사용)

개인 *.md 는 일반 이름으로 symlink:
- 같은 이름 충돌 시 `.bak.YYYYMMDD_HHMMSS` 백업

---

## uninstall.sh 동작

- `skills/`, `hooks/` symlink 제거.
- `agents/` 안의 개인 *.md symlink 제거.
- `agents/` 안의 `mailplug-*.md` wrapper 제거.
- `agents/.mailplug-source` marker 제거.
- `.bak.*` 백업은 그대로.

회사 agents 를 다시 설정하려면 `cursor-setting/install.sh` 재실행.

---

## sub-agent 사용

개인 9명 팀 구성 (한국어 업무톤). **mailplug 외부 프로젝트의 기본값**.

| 이름 | 역할 | 자동 호출 트리거 |
|---|---|---|
| `planner` | 기획자 | "기획자한테", "스펙 검토", "요구사항 정리", "유저 플로우" |
| `developer` | 개발자 | "코드 구현", "리팩토링", "버그 수정", "성능 개선" |
| `designer` | 디자이너 | "UX 검토", "레이아웃", "디자인 피드백", "컬러/타이포" |
| `pm` | PM | "일정 검토", "진척 확인", "작업 내역 체크", "리스크" |
| `lead` | 팀장 | "결정", "방향", "리뷰 종합", "승인" |
| `marketer` | 마케터 | "마케팅", "카피", "타겟", "캠페인" |
| `qa` | QA | "테스트 케이스", "회귀 테스트", "스모크 테스트", "품질 검증" |
| `security` | 보안 | "보안 검토", "취약점", "OWASP", "토큰/세션" |
| `infra` | 인프라 | "배포", "nginx", "systemd", "모니터링", "스케일링" |

### 라우팅 전략

- **mailplug 외부 (일반 프로젝트)** → 일반 이름 agent (`planner`, `developer` 등)
- **CWD가 `mailplug/` 하위** → `mailplug-*` wrapper agent (회사 agent 원본)
- 각 agent의 `description` frontmatter에 라우팅 규칙이 명시되어 Claude가 CWD 기준으로 자동 선택
- 명시 호출도 가능: `@planner`, Task tool `subagent_type: "planner"` 또는 `subagent_type: "mailplug-planner"`

mailplug 측 에 동일 역할이 **없는** 개인 agent (`lead`, `marketer`, `security`)는 mailplug 영역에서도 그대로 사용됩니다.

---

## 무엇을 추가할 것인가

- **skills/** — 자주 쓰는 도메인 지식, 프롬프트 패턴, 커스텀 워크플로우.
- **hooks/** — 위험 명령 차단, secret 커밋 방지, pre-commit 자동 lint.
- **agents/** — 새 역할/도메인 전문가 추가. 회사 wrapper와 이름이 겹치지 않도록 mailplug-* 접두사는 피한다.

---

## 보안 체크리스트

- [ ] `settings.local.json` 같은 개인 토큰 파일은 절대 이 repo에 두지 않는다 (`.gitignore`로 차단됨).
- [ ] `hooks/` 안의 스크립트가 외부로 데이터를 보내지 않는지 매번 확인.
- [ ] 새 hook 추가 시 `chmod +x` 확인.
- [ ] agent 프롬프트에 사내 비밀/엔드포인트/계정 정보를 박지 않는다.

---

## 제거

```bash
cd ~/Desktop/source/secretj-claude-config
./uninstall.sh
```
