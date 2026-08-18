#!/usr/bin/env bash
# secretj-claude-config — 개인 Claude Code 환경 설치
#
#   ./install.sh          전체 설치
#   ./install.sh --mcp    MCP 서버 등록까지 포함 (mcp/mcp-servers.json 필요)
#   ./install.sh --dry    무엇을 할지만 출력
#
# 멱등하다. 이미 우리 저장소로 걸린 symlink 는 건너뛴다.
# 기존 파일/디렉토리는 .bak.YYYYMMDD_HHMMSS 로 백업한 뒤 교체한다.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
STAMP="$(date +%Y%m%d_%H%M%S)"
DRY=0
DO_MCP=0

for arg in "$@"; do
  case "$arg" in
    --dry) DRY=1 ;;
    --mcp) DO_MCP=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "알 수 없는 옵션: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*"; }
run()  { if [ "$DRY" = 1 ]; then printf '  [dry] %s\n' "$*"; else eval "$@"; fi; }

mkdir -p "$CLAUDE_DIR"

# ── 1. 디렉토리 단위 symlink (skills, hooks) ─────────────────────
link_dir() {
  local name="$1" src="$REPO/$1" dst="$CLAUDE_DIR/$1"
  if [ -L "$dst" ]; then
    local target; target="$(readlink "$dst")"
    if [ "$target" = "$src" ]; then ok "$name/ — 이미 연결됨"; return 0; fi
    warn "$name/ 이 다른 곳으로 symlink 되어 있음 → $target"
    warn "     수동 확인 필요. 건너뜀."
    return 0
  fi
  if [ -e "$dst" ]; then
    run "mv '$dst' '$dst.bak.$STAMP'"
    ok "$name/ — 기존 디렉토리를 .bak.$STAMP 로 백업"
  fi
  run "ln -s '$src' '$dst'"
  ok "$name/ → $src"
}

say "[1/6] 디렉토리 symlink"
link_dir skills
link_dir hooks
link_dir templates
run "chmod +x '$REPO/hooks/'*.sh 2>/dev/null || true"

# ── 2. 파일 단위 symlink (CLAUDE.md, settings.json) ───────────────
link_file() {
  local name="$1" src="$REPO/$1" dst="$CLAUDE_DIR/$1"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then ok "$name — 이미 연결됨"; return 0; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    run "mv '$dst' '$dst.bak.$STAMP'"
    ok "$name — 기존 파일을 .bak.$STAMP 로 백업"
  fi
  run "ln -s '$src' '$dst'"
  ok "$name → $src"
}

say ""
say "[2/6] 전역 설정 파일"
link_file CLAUDE.md
link_file settings.json

# ── 3. agents / commands — 파일 단위 symlink ─────────────────────
link_each() {
  local name="$1" src="$REPO/$1" dst="$CLAUDE_DIR/$1"
  if [ -L "$dst" ]; then
    warn "$name/ 이 dir-symlink 이라 개별 파일을 넣을 수 없음 → $(readlink "$dst")"
    warn "     다른 도구가 점유 중. 건너뜀."
    return 0
  fi
  run "mkdir -p '$dst'"
  local n=0
  for f in "$src"/*.md; do
    [ -e "$f" ] || continue
    local base; base="$(basename "$f")"
    local target="$dst/$base"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then continue; fi
    if [ -e "$target" ] || [ -L "$target" ]; then run "mv '$target' '$target.bak.$STAMP'"; fi
    run "ln -s '$f' '$target'"
    n=$((n+1))
  done
  ok "$name/ — ${n}개 신규 연결 ($(ls -1 "$src"/*.md 2>/dev/null | wc -l | tr -d ' ')개 중)"
}

say ""
say "[3/6] agents / commands"
link_each agents
link_each commands

# ── 4. memory — 복사 (symlink 아님) ──────────────────────────────
# 새로 쌓이는 memory 가 공개 저장소로 흘러들지 않도록 일부러 복사한다.
# 이미 있는 파일은 덮어쓰지 않는다.
say ""
say "[4/6] memory (복사 — 기존 파일 보존)"
MEM_KEY="$(printf '%s' "$HOME" | sed 's|/|-|g')"
MEM_DIR="$CLAUDE_DIR/projects/$MEM_KEY/memory"
run "mkdir -p '$MEM_DIR'"
copied=0; skipped=0
for f in "$REPO/memory"/*.md; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue
  if [ -e "$MEM_DIR/$base" ]; then skipped=$((skipped+1)); continue; fi
  run "cp '$f' '$MEM_DIR/$base'"
  copied=$((copied+1))
done
ok "memory — 신규 ${copied}개 복사, 기존 ${skipped}개 보존 ($MEM_DIR)"

# MEMORY.md 인덱스: 없는 줄만 덧붙인다
if [ "$DRY" = 0 ]; then
  touch "$MEM_DIR/MEMORY.md"
  added=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! grep -Fqx "$line" "$MEM_DIR/MEMORY.md"; then
      printf '%s\n' "$line" >> "$MEM_DIR/MEMORY.md"
      added=$((added+1))
    fi
  done < "$REPO/memory/MEMORY.md"
  ok "MEMORY.md — ${added}줄 추가"
else
  say "  [dry] MEMORY.md 인덱스 병합"
fi

# ── 5. MCP 서버 (옵션) ───────────────────────────────────────────
say ""
say "[5/6] MCP 서버"
if [ "$DO_MCP" = 0 ]; then
  say "  건너뜀 (--mcp 로 활성화)"
elif [ ! -f "$REPO/mcp/mcp-servers.json" ]; then
  warn "mcp/mcp-servers.json 이 없음."
  warn "     cp mcp/mcp-servers.example.json mcp/mcp-servers.json 후 토큰을 채워 다시 실행."
elif ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI 를 찾을 수 없어 MCP 등록을 건너뜀."
else
  names="$(/usr/bin/python3 -c "import json,sys;print(' '.join(json.load(open('$REPO/mcp/mcp-servers.json'))['mcpServers']))")"
  for n in $names; do
    cfg="$(/usr/bin/python3 -c "import json;print(json.dumps(json.load(open('$REPO/mcp/mcp-servers.json'))['mcpServers']['$n']))")"
    run "claude mcp add-json --scope user '$n' '$cfg' >/dev/null 2>&1 || true"
    ok "mcp: $n"
  done
fi

# ── 6. 검증 ─────────────────────────────────────────────────────
say ""
say "[6/6] 결과"
if [ "$DRY" = 1 ]; then
  say "  dry-run 이라 아무것도 바꾸지 않았습니다."
else
  printf '  skills   : %s\n' "$(readlink "$CLAUDE_DIR/skills" 2>/dev/null || echo '(미설치)')"
  printf '  hooks    : %s\n' "$(readlink "$CLAUDE_DIR/hooks" 2>/dev/null || echo '(미설치)')"
  printf '  CLAUDE.md: %s\n' "$(readlink "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null || echo '(미설치)')"
  printf '  agents   : %s개\n' "$(ls -1 "$CLAUDE_DIR/agents" 2>/dev/null | wc -l | tr -d ' ')"
  printf '  commands : %s개\n' "$(ls -1 "$CLAUDE_DIR/commands" 2>/dev/null | wc -l | tr -d ' ')"
  printf '  memory   : %s개\n' "$(ls -1 "$MEM_DIR" 2>/dev/null | wc -l | tr -d ' ')"
fi
say ""
say "완료. Claude Code 를 재시작하면 반영됩니다."
