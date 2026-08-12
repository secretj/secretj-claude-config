---
name: 브랜치 체크아웃 직후 working tree 상태 검증
description: git checkout/pull 직후 바로 Edit/commit 진입 금지 — 반드시 working tree 상태를 검증한 뒤 작업
type: feedback
originSessionId: 1128d66c-26ad-462b-ab9d-06581c0e4786
modified: 2026-08-03T05:29:27.387Z
---
`git checkout <branch>` 또는 `git pull` 직후, 바로 Edit/commit으로 넘어가지 말고 다음을 먼저 실행한다:

1. `git log --oneline -3` — HEAD가 기대한 커밋에 있는지 확인
2. `git status --short` — 예상 외 modified/staged 파일이 없는지 확인
3. 작업 대상 파일을 `Read`로 실제 내용 재확인 (예상한 리팩토링/상태가 반영되어 있는지)

**Why:** 어느 hotfix PR 작업 중, `git checkout <hotfix 브랜치> && git pull`에서 "Already up to date"가 떴음에도 working tree가 PR 이전 상태에 있었던 사고 발생. 그대로 Edit + commit + push했더니 **46개 파일이 PR 이전 상태로 되돌아간 커밋**이 origin에 올라감 → 사용자가 `git reset --hard` + `git push --force-with-lease`로 수동 복구. 원인은 이전 브랜치의 working tree 잔여가 따라왔거나, 유사한 git 상태 불일치로 추정.

**How to apply:** 브랜치 전환 직후 + PR 리뷰/수정 작업 시작 시점에 **항상** 위 3단계 체크. 특히 PR 브랜치에 push 권한이 있는 작업일수록 철저히. 상태가 조금이라도 의심스러우면 사용자에게 먼저 확인 요청.

**추가 (2026-08-03):** 내가 checkout 하지 않아도 브랜치는 바뀐다. 사용자가 세션 도중 배포용으로 `pre-production` 을 체크아웃해 `hotfix/*` 를 머지해둔 상태였는데, 그걸 모르고 커밋해서 **feature 커밋이 배포 브랜치에 올라갔다**(`git push origin hotfix/...` 가 "Everything up-to-date" 를 뱉어서 발견). 복구는 `git reset --soft HEAD~1` → 대상 브랜치 checkout(스테이징된 변경 자동 이동) → 재커밋.

→ **`git commit` 직전에도 `git branch --show-current` 로 확인**한다. checkout 직후만이 아니다. 특히 대화가 길어져 여러 턴 만에 커밋할 때. 그리고 `push` 결과가 "Everything up-to-date" 면 정상이 아니라 **HEAD 가 딴 브랜치에 있다는 신호**로 읽는다.
