---
name: feedback_pr_review_verify_target
description: "PR URL로 리뷰 요청 시, 로컬 브랜치가 아니라 해당 PR의 diff인지 먼저 검증한다"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c33b7611-4a34-4422-ac50-c204e8d78c1a
  modified: 2026-08-07T00:33:51.392Z
---

PR URL을 받아 리뷰할 때는 작업 시작 전에 **PR head와 로컬 체크아웃 브랜치가 같은지 확인**한다.
`gh pr view <N> --json headRefName,baseRefName,changedFiles` 로 대상을 확정하고,
`gh pr diff <N>` 또는 `git diff origin/<base>...origin/<head>` 로 diff를 확보한 뒤 리뷰한다.

**Why:** 어느 저장소의 PR 리뷰를 요청받았을 때,
로컬이 전혀 무관한 다른 hotfix 브랜치에 있었고 리뷰가 그 브랜치 HEAD를 대상으로 진행됐다.
결과물 전체(4건 findings)가 다른 이슈에 대한 것이라 통째로 폐기됐다. 12분/84k 토큰 낭비.

**How to apply:**
- PR URL이 주어지면 첫 커맨드는 `gh pr view` — 로컬 `git log`가 아니다.
- head 브랜치명·changedFiles 개수를 리뷰 결과 서두에 명시해 대상이 맞는지 사용자가 바로 검증할 수 있게 한다.
- 로컬 브랜치가 다르면 `gh pr checkout <N>` 을 먼저 제안한다.
- `/code-review` 는 disable-model-invocation 이라 Skill 도구로 재호출 불가 — 사용자에게 직접 실행을 요청해야 한다.

관련: [[feedback_git_checkout_verify]]
