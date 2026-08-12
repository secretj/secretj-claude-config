---
name: reference_obsidian_vault_path
description: Obsidian vault 파일시스템 경로와 obsidian MCP 미등록 시 fallback 카운트 방법
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1226fea6-a5c5-437c-861f-10222341645a
---

Obsidian vault 경로는 `~/Documents/Obsidian Vault/` 이고, 도메인 자산은 그 아래 `{프로젝트}/` 폴더(하위: 저장소별 폴더 + `_common`)에 쌓인다.

obsidian MCP 서버가 `~/.claude.json` mcpServers 에 등록돼 있어도 **세션에서 도구가 deferred 목록·ToolSearch 에 등장하지 않는 경우가 잦다** (4주 연속 발생한 적 있음). 이때는 MCP 재연결을 기다리지 말고 **vault 경로 직접 카운트로 fallback**:

```bash
find "$HOME/Documents/Obsidian Vault/{프로젝트}" -name "*.md" | wc -l   # 도메인 자산 수
```

주간 리포트의 "Obsidian 도메인 자산" 수치를 이 방식으로 센다. [[feedback_research_obsidian_path.md]] 의 저장 경로 컨벤션과 연결.
