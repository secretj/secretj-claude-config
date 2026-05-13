#!/bin/bash
# Stop hook: append a <=20-line session block to rolling sessions log.
# Output: ~/.reports/sessions.log  (blocks separated by a line "---")
# Schema (YAML-ish, parseable line-by-line):
#   session_id, ts_start, ts_end, repo, branch, head, tools, messages,
#   tokens_in/out/cache_create/cache_read, commits (csv), lines_added,
#   lines_deleted, issues (csv), summary (one line)

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")
TRANSCRIPT=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || pwd)

[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

REPORT_DIR="$HOME/.reports"
mkdir -p "$REPORT_DIR"
FILE="$REPORT_DIR/sessions.log"

BRANCH=$(cd "$CWD" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")
HEAD=$(cd "$CWD" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "-")
REPO=$(basename "$CWD")

# Aggregate from transcript
STATS=$(/usr/bin/python3 - "$TRANSCRIPT" <<'PY'
import json, sys, re
path = sys.argv[1]
inp=out=cc=cr=tools=msgs=0
ts_start=ts_end=""
issues=set()
try:
    with open(path) as f:
        for line in f:
            try: d=json.loads(line)
            except: continue
            t=d.get("timestamp") or d.get("ts") or ""
            if t:
                ts_start = ts_start or t
                ts_end = t
            msg=d.get("message") or {}
            u=msg.get("usage") or d.get("usage") or {}
            if u:
                inp += u.get("input_tokens",0) or 0
                out += u.get("output_tokens",0) or 0
                cc  += u.get("cache_creation_input_tokens",0) or 0
                cr  += u.get("cache_read_input_tokens",0) or 0
                msgs += 1
            content = msg.get("content")
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict):
                        if c.get("type")=="tool_use": tools += 1
                        txt = c.get("text") or ""
                        for m in re.findall(r'\b(WM|LA|BB|LS|MO|CR)-\d+', txt):
                            pass
                        for m in re.findall(r'\b(?:WM|LA|BB|LS|MO|CR)-\d+', txt):
                            issues.add(m)
            elif isinstance(content, str):
                for m in re.findall(r'\b(?:WM|LA|BB|LS|MO|CR)-\d+', content):
                    issues.add(m)
except: pass
print(f"{ts_start}|{ts_end}|{inp}|{out}|{cc}|{cr}|{tools}|{msgs}|{','.join(sorted(issues))}")
PY
)

IFS='|' read -r TS_START TS_END INP OUT CC CR TOOLS MSGS ISSUES <<< "$STATS"
TS_END=${TS_END:-$(date -Iseconds)}
TS_START=${TS_START:-$TS_END}

# Git stats since session start
COMMITS="-"; LINES_ADD=0; LINES_DEL=0
if cd "$CWD" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  SINCE="${TS_START}"
  COMMITS=$(git log --since="$SINCE" --pretty=format:%h 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  [ -z "$COMMITS" ] && COMMITS="-"
  if [ "$COMMITS" != "-" ]; then
    DIFFSTAT=$(git log --since="$SINCE" --numstat --pretty=format: 2>/dev/null \
      | awk 'NF==3 && $1 ~ /^[0-9]+$/ {a+=$1; d+=$2} END {print a"|"d}')
    IFS='|' read -r LINES_ADD LINES_DEL <<< "$DIFFSTAT"
    LINES_ADD=${LINES_ADD:-0}; LINES_DEL=${LINES_DEL:-0}
  fi
fi

# Summary: last user message first line (sanitized, <=120 chars)
SUMMARY=$(/usr/bin/python3 - "$TRANSCRIPT" <<'PY'
import json,sys
last=""
try:
    with open(sys.argv[1]) as f:
        for line in f:
            try: d=json.loads(line)
            except: continue
            m=d.get("message") or {}
            if m.get("role")=="user":
                c=m.get("content")
                if isinstance(c,str): last=c
                elif isinstance(c,list):
                    for x in c:
                        if isinstance(x,dict) and x.get("type")=="text":
                            last=x.get("text","")
except: pass
s=last.splitlines()[0] if last else ""
s=s.replace('"',"'").strip()[:120]
print(s)
PY
)

{
  echo "---"
  echo "session_id: ${SESSION_ID:0:8}"
  echo "ts_start: $TS_START"
  echo "ts_end: $TS_END"
  echo "repo: $REPO"
  echo "branch: $BRANCH"
  echo "head: $HEAD"
  echo "tools: $TOOLS"
  echo "messages: $MSGS"
  echo "tokens_in: $INP"
  echo "tokens_out: $OUT"
  echo "cache_create: $CC"
  echo "cache_read: $CR"
  echo "commits: $COMMITS"
  echo "lines_added: $LINES_ADD"
  echo "lines_deleted: $LINES_DEL"
  echo "issues: $ISSUES"
  echo "summary: \"$SUMMARY\""
} >> "$FILE"

exit 0
