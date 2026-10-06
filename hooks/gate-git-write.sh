#!/bin/bash
# PreToolUse 훅 — 지정한 워크스페이스 안에서 git 쓰기 명령을 사람 승인으로 되돌린다.
#
# 왜 훅인가 — permissions 로는 못 막는다. 전역 settings.local.json 의 allow 목록에
# Bash(git commit:*) / Bash(git push:*) 가 있으면 프로젝트 설정을 지워도 다시 허용된다.
# CLAUDE.md 에 "커밋하지 말라"고 쓰는 것은 권고다. 훅은 결정적이다.
#
# 차단(deny)이 아니라 확인(ask) 이다. 사용자가 요청한 커밋은 그대로 통과하고,
# 에이전트의 임의 실행만 멈춘다.
#
# 대상 게이트: git commit, git push, git merge, git reset --hard
#
# 대상 디렉터리 설정 — 둘 중 하나로 준다. 비어 있으면 아무것도 막지 않는다.
#   1) 환경변수 CLAUDE_GIT_GATE_DIRS — 콜론(:) 구분 절대 경로
#   2) ~/.claude/git-gate-dirs      — 한 줄에 한 경로. '#' 주석과 빈 줄 허용
# 경로는 공개 저장소에 넣지 않는다. 설정 파일은 추적하지 않는다.

set -uo pipefail

CONFIG="${CLAUDE_GIT_GATE_CONFIG:-$HOME/.claude/git-gate-dirs}"

GATE_DIRS=()
if [ -n "${CLAUDE_GIT_GATE_DIRS:-}" ]; then
  IFS=':' read -r -a GATE_DIRS <<<"$CLAUDE_GIT_GATE_DIRS"
elif [ -f "$CONFIG" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    GATE_DIRS+=("${line/#\~/$HOME}")
  done <"$CONFIG"
fi

# 게이트 대상이 없으면 통과
[ "${#GATE_DIRS[@]}" -eq 0 ] && exit 0

INPUT=$(cat)

PARSED=$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool = d.get("tool_name", "")
cwd = d.get("cwd", "")
cmd = " ".join(((d.get("tool_input") or {}).get("command", "")).split())
print(tool)
print(cwd)
print(cmd)
' 2>/dev/null) || exit 0

TOOL=$(printf '%s' "$PARSED" | sed -n '1p')
CWD=$(printf '%s' "$PARSED" | sed -n '2p')
FULL=$(printf '%s' "$PARSED" | sed -n '3p')

# Bash 외 도구는 통과
[ "$TOOL" = "Bash" ] || exit 0

# 지정 디렉터리 밖은 통과 — 다른 프로젝트 작업에 영향 없게
IN_SCOPE=0
for dir in "${GATE_DIRS[@]}"; do
  case "$CWD" in
    "$dir"|"$dir"/*) IN_SCOPE=1; break ;;
  esac
done
[ "$IN_SCOPE" -eq 1 ] || exit 0

git_verb() {
  printf '%s' "$FULL" | grep -Eq "(^|[;&|]|[[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+$1([[:space:]]|$)"
}

GATE=""
if   git_verb commit; then GATE="git-commit"
elif git_verb push;   then GATE="git-push"
elif git_verb merge;  then GATE="git-merge"
elif git_verb reset && printf '%s' "$FULL" | grep -Eq -- '--hard'; then GATE="git-reset-hard"
fi

[ -z "$GATE" ] && exit 0

REASON="사람 승인 지점 [$GATE] — 게이트 대상 워크스페이스. 에이전트는 준비까지만 하고 실행은 사용자가 결정한다."

/usr/bin/python3 -c '
import json, sys
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": sys.argv[1],
  }
}, ensure_ascii=False))
' "$REASON"

exit 0
