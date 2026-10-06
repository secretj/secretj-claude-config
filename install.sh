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
# CLAUDE.md 가 다른 저장소로 걸려 있으면 백업 후 이 저장소로 회수한다.
prev_claude="$(readlink "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null || true)"
if [ -n "$prev_claude" ] && [ "$prev_claude" != "$REPO/CLAUDE.md" ]; then
  warn "CLAUDE.md 가 다른 곳으로 걸려 있었음 → $prev_claude"
  warn "     백업 후 이 저장소로 회수한다. 그쪽 규칙이 필요하면 rules/ 로 옮긴다."
fi
link_file CLAUDE.md

# settings.json 은 symlink 하지 않는다 — Claude Code 가 이 파일에 자기 생성 블록
# (autoMode.environment 등 머신·조직 정보)을 직접 써 넣는다. symlink 면 그게 공개
# 저장소로 흘러든다. 그래서 "저장소 키만 덮어쓰고 나머지는 보존하는" 머지 복사를 쓴다.
merge_settings() {
  local src="$REPO/settings.json" dst="$CLAUDE_DIR/settings.json"
  if [ "$DRY" = 1 ]; then say "  [dry] settings.json 머지 (저장소 키만 덮어쓰기)"; return 0; fi
  # dst 가 symlink 면 파이썬 쓰기가 링크를 따라가 "남의 저장소 파일"을 덮어쓴다.
  # 다른 설정 저장소가 여기를 symlink 로 점유했을 수 있다. 내용만 가져와 실제 파일로 바꾼다.
  if [ -L "$dst" ]; then
    warn "settings.json 이 symlink 였음 → $(readlink "$dst")"
    warn "     그 저장소에 써 버리지 않도록 내용만 복사해 실제 파일로 바꾼다."
    cp "$(readlink "$dst")" "$dst.link-was.$STAMP" 2>/dev/null || true
    cp "$dst" "$dst.tmp.$STAMP" && rm "$dst" && mv "$dst.tmp.$STAMP" "$dst"
  fi
  [ -f "$dst" ] && cp "$dst" "$dst.bak.$STAMP"
  /usr/bin/python3 - "$src" "$dst" <<'PYMERGE'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
repo = json.load(open(src, encoding='utf-8'))
live = {}
if os.path.exists(dst):
    try:
        live = json.load(open(dst, encoding='utf-8'))
    except ValueError:
        live = {}
def ours(entry):
    # 이 저장소가 설치한 훅인가. 명령이 ~/.claude/hooks 를 가리키면 우리 것이다.
    for h in (entry.get('hooks') or []):
        if '/.claude/hooks/' in (h.get('command') or ''):
            return True
    return False

def merge_hooks(live_h, repo_h):
    # 이벤트 단위로 병합한다. 통째로 덮으면 다른 도구가 등록한 훅이 조용히 사라진다.
    # 우리 훅은 저장소를 정본으로 교체하고, 남의 훅은 그대로 보존한다.
    out = dict(live_h)
    for ev in set(live_h) | set(repo_h):
        keep = [e for e in (live_h.get(ev) or []) if not ours(e)]
        out[ev] = keep + list(repo_h.get(ev) or [])
        if not out[ev]:
            del out[ev]
    return out

merged = dict(live)
for k, v in repo.items():
    if k == 'permissions' and isinstance(live.get(k), dict):
        pm = dict(live[k])
        for pk, pv in v.items():
            if isinstance(pv, list):
                seen = pm.get(pk, []) or []
                pm[pk] = seen + [x for x in pv if x not in seen]
            else:
                pm[pk] = pv
        merged[k] = pm
    elif k == 'hooks' and isinstance(live.get(k), dict) and isinstance(v, dict):
        merged[k] = merge_hooks(live[k], v)
    else:
        merged[k] = v
json.dump(merged, open(dst, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
open(dst, 'a', encoding='utf-8').write('\n')
kept = sorted(set(live) - set(repo))
print('  보존한 로컬 키: ' + (', '.join(kept) if kept else '없음'))
foreign = sorted(ev for ev, es in (merged.get('hooks') or {}).items()
                 if any(not ours(e) for e in es))
print('  보존한 외부 훅 이벤트: ' + (', '.join(foreign) if foreign else '없음'))
PYMERGE
  ok "settings.json — 머지 완료 (기존 파일은 .bak.$STAMP)"
}
merge_settings

# 로컬 전용 파일 — 추적하지 않는다. CLAUDE.md 가 import 하므로 비어 있어도 만들어 둔다.
if [ ! -e "$CLAUDE_DIR/CLAUDE.private.md" ]; then
  if [ "$DRY" = 1 ]; then say "  [dry] CLAUDE.private.md 생성"; else
    printf '%s\n' '# 로컬 전용 지침' '' '공개 저장소에 두면 안 되는 규칙만 둔다(소속·이름·사내 경로). 비어 있어도 된다.' > "$CLAUDE_DIR/CLAUDE.private.md"
  fi
  ok "CLAUDE.private.md — 생성 (추적 안 함)"
fi
if [ ! -e "$CLAUDE_DIR/git-gate-dirs" ]; then
  if [ "$DRY" = 1 ]; then say "  [dry] git-gate-dirs 생성"; else
    printf '%s\n' '# git 쓰기 명령(commit/push/merge/reset --hard)을 사람 승인으로 돌릴 디렉터리.' '# 한 줄에 한 경로. 비워 두면 아무것도 막지 않는다.' > "$CLAUDE_DIR/git-gate-dirs"
  fi
  ok "git-gate-dirs — 생성 (추적 안 함, 경로는 직접 채운다)"
fi

# ── 3. agents / rules — 파일 단위 symlink ───────────────────────
link_each() {
  local name="$1" src="$REPO/$1" dst="$CLAUDE_DIR/$1"
  if [ -L "$dst" ]; then
    warn "$name/ 이 dir-symlink 이라 개별 파일을 넣을 수 없음 → $(readlink "$dst")"
    warn "     다른 설정 저장소가 점유했다. 자동으로 걷어내지 않는다 — 남의 자산일 수 있다."
    warn "     이 저장소를 $name/ 의 정본으로 되돌리려면:"
    warn "       1) ls -la '$dst'  로 대상을 확인한다"
    warn "       2) rm '$dst'      (심링크만 지운다. 가리키던 저장소는 그대로 남는다)"
    warn "       3) 직전 백업이 있으면 되살린다: mv '$dst.bak' '$dst'"
    warn "       4) ./install.sh 를 다시 돌린다"
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
say "[3/6] agents / rules"
# 저장소에서 사라진 파일을 가리키는 끊긴 symlink 를 지운다.
# link_each 는 저장소에 "있는" 파일만 순회하므로, 삭제된 agent/rule 의 링크는
# 이 단계가 없으면 ~/.claude 에 영구히 남아 Claude Code 가 깨진 항목을 읽는다.
prune_dangling() {
  local name="$1" dst="$CLAUDE_DIR/$1"
  [ -d "$dst" ] && [ ! -L "$dst" ] || return 0
  local n=0
  for t in "$dst"/*.md; do
    [ -L "$t" ] || continue          # 심링크만 대상. 남의 실제 파일은 손대지 않는다
    [ -e "$t" ] && continue          # 가리키는 대상이 살아 있으면 통과
    case "$(readlink "$t")" in
      "$REPO"/*) run "rm '$t'"; n=$((n+1)) ;;   # 우리 저장소를 가리켰던 것만
    esac
  done
  [ "$n" -gt 0 ] && ok "$name/ — 끊긴 symlink ${n}개 정리" || true
}

link_each agents
link_each rules
prune_dangling agents
prune_dangling rules

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
  # 줄 전체가 아니라 링크 대상 파일(`](foo.md)`)로 중복을 판단한다.
  # 같은 memory 를 가리키는 줄이 이미 있으면 문구가 달라도 덧붙이지 않는다.
  /usr/bin/python3 - "$REPO/memory/MEMORY.md" "$MEM_DIR/MEMORY.md" <<'PYIDX'
import io, re, sys
src, dst = sys.argv[1], sys.argv[2]
target = re.compile(r'\]\(([^)]+\.md)\)')
def key(line):
    m = target.search(line)
    return m.group(1) if m else line.strip()
dst_lines = io.open(dst, encoding='utf-8').read().split('\n')
have = {key(l) for l in dst_lines if l.strip()}
add = []
for l in io.open(src, encoding='utf-8').read().split('\n'):
    if not l.strip() or key(l) in have:
        continue
    have.add(key(l))
    add.append(l)
if add:
    body = '\n'.join([l for l in dst_lines if l.strip()] + add) + '\n'
    io.open(dst, 'w', encoding='utf-8').write(body)
print('  ✓ MEMORY.md — %d줄 추가' % len(add))
PYIDX
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
  printf '  settings : %s\n' "$([ -L "$CLAUDE_DIR/settings.json" ] && echo 'symlink(권장 아님)' || echo '머지 복사')"
  printf '  agents   : %s개\n' "$(ls -1 "$CLAUDE_DIR/agents" 2>/dev/null | wc -l | tr -d ' ')"
  printf '  rules    : %s개\n' "$(ls -1 "$CLAUDE_DIR/rules" 2>/dev/null | wc -l | tr -d ' ')"
  printf '  skills   : %s개%s\n' \
    "$(ls -1d "$REPO/skills"/*/ 2>/dev/null | grep -vc '/synced/$' | tr -d ' ')" \
    "$([ -d "$REPO/skills/synced" ] && printf ' (+ claude.ai 동기화 번들)')"
  printf '  memory   : %s개\n' "$(ls -1 "$MEM_DIR" 2>/dev/null | wc -l | tr -d ' ')"
fi
say ""
say "완료. Claude Code 를 재시작하면 반영됩니다."
