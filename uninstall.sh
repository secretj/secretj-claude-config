#!/usr/bin/env bash
# secretj-claude-config — 우리가 만든 symlink 만 제거한다.
# .bak.* 백업과 memory 로 복사된 파일은 건드리지 않는다.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

ok()   { printf '  ✓ %s\n' "$*"; }
skip() { printf '  – %s\n' "$*"; }

unlink_if_ours() {
  local dst="$1" src="$2" label="$3"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    rm "$dst"; ok "$label 제거"
  else
    skip "$label — 우리 symlink 아님, 유지"
  fi
}

echo "[1/3] 디렉토리·파일 symlink"
unlink_if_ours "$CLAUDE_DIR/skills"       "$REPO/skills"        "skills/"
unlink_if_ours "$CLAUDE_DIR/hooks"        "$REPO/hooks"         "hooks/"
unlink_if_ours "$CLAUDE_DIR/CLAUDE.md"    "$REPO/CLAUDE.md"     "CLAUDE.md"
unlink_if_ours "$CLAUDE_DIR/settings.json" "$REPO/settings.json" "settings.json"

echo ""
echo "[2/3] agents / commands 개별 symlink"
for name in agents commands; do
  dst="$CLAUDE_DIR/$name"
  [ -d "$dst" ] && [ ! -L "$dst" ] || { skip "$name/ — 디렉토리 아님, 건너뜀"; continue; }
  n=0
  for f in "$REPO/$name"/*.md; do
    [ -e "$f" ] || continue
    t="$dst/$(basename "$f")"
    if [ -L "$t" ] && [ "$(readlink "$t")" = "$f" ]; then rm "$t"; n=$((n+1)); fi
  done
  ok "$name/ — ${n}개 제거"
  rmdir "$dst" 2>/dev/null && ok "$name/ — 빈 디렉토리 제거" || true
done

echo ""
echo "[3/3] 남은 것"
echo "  · .bak.* 백업은 그대로 둡니다. 복원하려면 직접 mv 하세요."
echo "  · memory 로 복사된 파일은 그대로 둡니다 (~/.claude/projects/*/memory/)."
echo "  · MCP 서버 등록은 'claude mcp remove <name>' 으로 직접 지우세요."
echo ""
echo "완료."
