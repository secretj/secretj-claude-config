# secretj-claude-config

개인용 Claude Code dotfiles. 회사용 dotfiles(`bradykim7/cursor-setting`) 위에 **레이어드** 되도록 설계되었습니다.

새 컴퓨터에서 `git pull` 두 번 + `install.sh` 두 번이면 Claude Code 환경이 그대로 복원됩니다.

---

## 설계 원칙

1. **회사 설정을 건드리지 않는다** — 회사 install이 점유하는 영역(`settings.json`, `agents/`, `commands/`, `CLAUDE.md`)은 손대지 않음.
2. **충돌 없는 영역만 관리** — `~/.claude/skills/`, `~/.claude/hooks/` 두 개만 symlink.
3. **다른 프로젝트에 영향 없음** — 글로벌 `~/.claude/`만 다루고, 개별 repo의 `.claude/`는 건드리지 않음.
4. **개인 비밀 절대 커밋 금지** — `.gitignore`로 `*.local.json`, `*.token`, `.env` 등 차단.

---

## 디렉토리 구조

```
secretj-claude-config/
├── install.sh        # ~/.claude/skills, hooks 를 이 repo로 symlink
├── uninstall.sh      # symlink 제거 (.bak.* 백업은 그대로 둠)
├── skills/           # 개인 Claude Code skills
└── hooks/            # 개인 hook 스크립트 (chmod +x 필요)
```

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
git clone <this-repo-url> secretj-claude-config
cd secretj-claude-config && ./install.sh
```

순서 중요: 회사 → 개인. 회사 install이 점유하는 영역과 겹치지 않으므로 안전하게 추가됨.

---

## install.sh 동작

| 상황 | 동작 |
|---|---|
| `~/.claude/skills` 없음 | symlink 생성 |
| `~/.claude/skills` 가 일반 디렉토리 | `.bak.YYYYMMDD_HHMMSS` 로 백업 후 symlink |
| `~/.claude/skills` 가 이미 이 repo로 symlink | skip (멱등) |
| `~/.claude/skills` 가 다른 곳으로 symlink | **에러로 멈춤** — 사용자가 수동 확인 필요 |

`hooks/`도 동일.

---

## uninstall.sh 동작

- 이 repo가 만든 symlink만 제거.
- `.bak.*` 백업은 손대지 않음 (수동 복원).
- 다른 곳으로 향한 symlink는 건드리지 않음.

---

## 무엇을 추가할 것인가

- **skills/** — 자주 쓰는 도메인 지식, 프롬프트 패턴, 커스텀 워크플로우.
- **hooks/** — 위험 명령 차단, secret 커밋 방지, pre-commit 자동 lint 등.

> 회사 repo가 이미 제공하는 슬래시 커맨드/에이전트와 중복되지 않도록 주의.

---

## 보안 체크리스트

- [ ] `settings.local.json` 같은 개인 토큰 파일은 절대 이 repo에 두지 않는다 (`.gitignore`로 차단됨).
- [ ] `hooks/` 안의 스크립트가 외부로 데이터를 보내지 않는지 매번 확인.
- [ ] 새 hook 추가 시 `chmod +x` 확인.

---

## 제거

```bash
cd ~/Desktop/source/secretj-claude-config
./uninstall.sh
# 필요하면 .bak.* 디렉토리 수동 복원
```
