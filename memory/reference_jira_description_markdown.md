---
name: reference_jira_description_markdown
description: Jira/Confluence MCP의 본문은 마크다운, 댓글은 wiki markup — 도구마다 문법이 다름
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4e342455-bd99-47bc-818f-c4f77dc885f2
  modified: 2026-08-10T02:01:01.457Z
---

**도구마다 다르다. 하나로 뭉뚱그리면 깨진다.**

| 도구 | 입력 문법 |
|---|---|
| `jira_update_issue` / `jira_create_issue` 의 `description` | **마크다운** (서버가 wiki로 변환) |
| Confluence `confluence_create_page` / `confluence_update_page` | **마크다운** |
| **`jira_add_comment` 의 `comment`** | **Jira wiki markup** — 변환 안 함, 원문 그대로 저장 |

`jira_add_comment` 에 마크다운을 쓰면 깨진다 (2026-08-10 실측):
- `###`/`####` 헤딩 → Jira가 `#`을 numbered list로 읽어 `1. 1. 1.` 중첩 리스트로 렌더
- 백틱·`|` 표·`**굵게**` 도 그대로 노출됨
- wiki와 마크다운을 섞으면 최악 — 양쪽 다 깨진다

댓글은 `h3.` / `{{인라인코드}}` / `{code:java}` / `*굵게*` / `* 불릿` / `# 번호` / `||헤더||` 표를 쓴다.
단, 줄머리 `*`(불릿) 안에서 인라인 `*굵게*`를 쓰면 충돌하니 불릿 줄엔 굵게를 넣지 말 것.

**기존 댓글은 수정·삭제할 수 없다.** MCP에 `jira_add_comment` 만 있고 update/delete가 없으며, OAuth 기반 MCP 서버라 curl로 REST를 칠 토큰도 없다. **깨뜨려도 정정 댓글을 덧붙이지 말 것** — 티켓만 지저분해진다. 사용자에게 본문을 파일로 전달하고 UI에서 붙여넣게 한다. 애초에 올리기 전에 문법을 확인하는 게 맞다. [[feedback_jira_comment_no_append]]

**마크다운으로 쓰면 정상 변환:**
- `## 제목` → `h2.`, `- 항목` → `*`, `` `코드` `` → `{{}}`, ` ```php ` 펜스 → `{code:php}`, 마크다운 표(`| --- |`) → `|| ... ||`

[[reference_obsidian_vault_path]] (obsidian MCP)와 달리 이쪽은 마크다운 입력이 정답.
