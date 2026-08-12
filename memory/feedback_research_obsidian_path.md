---
name: feedback-research-obsidian-path
description: 리서치 결과물은 Obsidian의 도메인 지식 폴더가 아니라 vault 루트의 Research/ 폴더에 저장한다.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 704f08a1-8560-49e0-89d2-065df0a8ce94
---

리서치 문서(`.research/YYYY-MM-DD-*.md` 형식의 코드베이스 리서치 결과)를 Obsidian에 올릴 때는 **vault 루트의 `Research/` 폴더**에 저장한다. `{프로젝트}/{저장소}/` 같은 도메인 지식 폴더 아래에 넣지 않는다.

**Why:** 리서치 문서와 도메인 지식([[distill]])은 성격이 다름. 리서치는 특정 시점·티켓 기준 스냅샷이고, 도메인 지식은 지속 누적되는 정책·규칙. 같은 폴더에 섞이면 두 종류가 혼재되어 둘 다 찾기 어려워짐. vault 구조상 이미 `Research/`, `PR Reviews/`, `{프로젝트}/` 로 성격별로 분리되어 있음.

**How to apply:**
- `/research` 결과물 (`.research/` 폴더의 산출물) → `Research/YYYY-MM-DD-<topic>.md` 로 업로드
- `/distill` 로 추출하는 도메인 지식 → `{프로젝트}/{저장소}/{도메인}.md` 유지
- 사용자가 "옵시디언에 올려"라고만 하더라도 문서 성격으로 판단해서 위치 결정. 헷갈리면 묻기.
- 이미 잘못된 위치에 올렸으면 [[mcp__obsidian__obsidian_delete_note]] 로 삭제 후 다시 업로드.
