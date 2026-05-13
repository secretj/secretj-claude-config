---
name: sync-knowledge
description: Obsidian의 mailplug 도메인 지식을 현재 저장소의 CLAUDE.md에 동기화한다. 저장소별 지식(`mailplug/{repo}/`)과 공통 지식(`mailplug/_common/`)을 읽어 CLAUDE.md의 "## 도메인 지식" 섹션을 업데이트. 팀원이 저장소를 체크아웃하면 별도 Obsidian 없이도 도메인 지식을 Claude가 인지. "/sync-knowledge", "claude.md 동기화", "도메인 지식 공유", "공통 정책 반영" 요청에 사용.
---

# Sync Knowledge — Obsidian → 저장소 CLAUDE.md 동기화

Obsidian `mailplug/{repo}/` + `mailplug/_common/` 내용을 현재 저장소 CLAUDE.md에 반영한다.

## 입력
- 현재 CWD에서 저장소명 자동 감지 (디렉토리명 또는 git remote 기준)
- 선택: `--repo gw-member` 로 명시 가능

## 저장소명 감지 순서
1. `git remote get-url origin` 에서 마지막 경로 세그먼트 추출
2. 실패 시 현재 디렉토리명 사용
3. 알 수 없으면 사용자에게 질의

---

## 실행 절차

### 1. 저장소명 감지
```bash
git remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git//'
```
→ `gw-member` / `gw-bbs` / `wm70-api` / `wm60` 중 하나

### 2. Obsidian에서 내용 읽기 (병렬)
```
obsidian_list_notes "mailplug/{repo}"   → 해당 저장소 도메인 파일 목록
obsidian_list_notes "mailplug/_common"  → 공통 파일 목록
```
각 파일 `obsidian_get_note`로 내용 읽기.

### 3. CLAUDE.md 위치 확인
```
{repo루트}/CLAUDE.md         (우선)
{repo루트}/.claude/CLAUDE.md (없으면)
```
없으면 `{repo루트}/CLAUDE.md` 신규 생성.

### 4. CLAUDE.md 업데이트

**`## 도메인 지식` 섹션을 찾아 전체 교체** (없으면 파일 끝에 추가).

섹션 내용 구조:
```markdown
## 도메인 지식

> Obsidian `mailplug/{repo}/` + `mailplug/_common/` 에서 동기화됨.
> 직접 수정 금지 — `/sync-knowledge` 스킬로 갱신.
> 마지막 동기화: YYYY-MM-DD

### 이 저장소 ({repo})

#### {도메인파일명} (예: token)
- 항목 내용 (날짜, 티켓)
- 항목 내용 (날짜)

#### {도메인파일명2}
- ...

### 공통 (_common)

#### deploy
- 항목 내용 (날짜)

#### datetime
- 항목 내용 (날짜)

#### convention
- 항목 내용 (날짜)
```

### 5. 완료 보고
```
[sync-knowledge] CLAUDE.md 업데이트 완료
저장소: gw-member
저장소 도메인 파일: token.md, member.md (N항목)
공통 파일: deploy.md, datetime.md, convention.md (N항목)
경로: /path/to/repo/CLAUDE.md

→ git add CLAUDE.md 후 커밋하면 팀원과 공유됩니다.
```

---

## 규칙

- **`## 도메인 지식` 섹션만 교체** — 나머지 CLAUDE.md 내용 건드리지 않음
- Obsidian에 내용 없으면 섹션 생성하되 "아직 축적된 지식 없음" 명시
- 섹션 상단에 "직접 수정 금지" + 마지막 동기화 날짜 기재
- `/distill`로 Obsidian 업데이트 후 `/sync-knowledge`로 CLAUDE.md에 반영하는 흐름

## 흐름 요약
```
작업 중 발견한 지식
  → /distill 로 Obsidian 저장
  → /sync-knowledge 로 저장소 CLAUDE.md 반영
  → git commit/push 로 팀 공유
```
