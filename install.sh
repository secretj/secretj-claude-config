#!/bin/bash
# secretj-claude-config installer
#
# 회사용 dotfiles (cursor-setting)와 충돌하지 않는 영역:
#   ~/.claude/skills/  → ./skills/   (디렉토리 전체 symlink)
#   ~/.claude/hooks/   → ./hooks/    (디렉토리 전체 symlink)
#
# 회사용 dotfiles와 영역이 겹치는 곳 (per-file 머지로 공존):
#   ~/.claude/agents/  ← 회사 agents/claude-code/*.md 를 읽어 `mailplug-*.md` wrapper 생성 (name 변경 + description에 'mailplug 전용' 식별자 주입)
#                        + secretj-claude-config/agents/*.md 를 일반 이름으로 symlink
#                        (회사 wrapper는 mailplug 작업 영역에서만 사용, 우리 agent는 기본값)
#
# 회사 source 위치 우선순위:
#   1. $MAILPLUG_AGENTS_SRC env
#   2. ~/.claude/agents 가 dir-symlink면 그 target
#   3. ~/.claude/agents/.mailplug-source marker
#   4. 기본 $HOME/Desktop/source/mailplug/cursor-setting/agents/claude-code

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== secretj-claude-config Installer ==="
echo "Source: $DOTFILES_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

if [ ! -d "$CLAUDE_DIR" ]; then
    echo "[*] $CLAUDE_DIR 가 없습니다. 생성합니다."
    mkdir -p "$CLAUDE_DIR"
fi

# ─────────────────────────────────────────────
# link_dir <source> <target>
# ─────────────────────────────────────────────
link_dir() {
    local SRC="$1"
    local DST="$2"
    local NAME
    NAME="$(basename "$DST")"

    if [ -L "$DST" ]; then
        local CURRENT
        CURRENT="$(readlink "$DST")"
        if [ "$CURRENT" = "$SRC" ]; then
            echo "[=] $NAME 이미 올바르게 symlink됨"
            return 0
        else
            echo "[✗] $NAME 가 다른 곳으로 symlink됨: $CURRENT"
            return 1
        fi
    fi

    if [ -e "$DST" ]; then
        local BAK="${DST}.bak.$(date +%Y%m%d_%H%M%S)"
        echo "[!] 기존 $NAME 백업 → $(basename "$BAK")"
        mv "$DST" "$BAK"
    fi

    ln -s "$SRC" "$DST"
    echo "[✓] $NAME → $SRC"
}

# ─────────────────────────────────────────────
# merge_agents
# ─────────────────────────────────────────────
merge_agents() {
    local AGENTS_DST="$CLAUDE_DIR/agents"
    local PERSONAL_AGENTS_SRC="$DOTFILES_DIR/agents"
    local SOURCE_MARKER="$AGENTS_DST/.mailplug-source"
    local DEFAULT_COMPANY_PATH="$HOME/Desktop/source/mailplug/cursor-setting/agents/claude-code"
    local COMPANY_AGENTS_SRC=""

    # Step 1: 회사 source 결정
    if [ -n "${MAILPLUG_AGENTS_SRC:-}" ]; then
        COMPANY_AGENTS_SRC="$MAILPLUG_AGENTS_SRC"
        echo "[*] agents/ : 회사 source = \$MAILPLUG_AGENTS_SRC"
    elif [ -L "$AGENTS_DST" ]; then
        COMPANY_AGENTS_SRC="$(readlink "$AGENTS_DST")"
        echo "[*] agents/ : dir-symlink 감지 → 회사 source = $COMPANY_AGENTS_SRC"
        rm "$AGENTS_DST"
    elif [ -L "$SOURCE_MARKER" ]; then
        COMPANY_AGENTS_SRC="$(readlink "$SOURCE_MARKER")"
        echo "[*] agents/ : 기존 marker 사용 → 회사 source = $COMPANY_AGENTS_SRC"
    elif [ -d "$DEFAULT_COMPANY_PATH" ]; then
        COMPANY_AGENTS_SRC="$DEFAULT_COMPANY_PATH"
        echo "[*] agents/ : 기본 경로 사용 = $COMPANY_AGENTS_SRC"
    else
        echo "[!] agents/ : 회사 source 못 찾음 (mailplug-* wrapper 생성 skip)"
    fi

    # Step 2: 디렉토리 보장
    if [ ! -d "$AGENTS_DST" ]; then
        mkdir -p "$AGENTS_DST"
    fi

    # Step 3: 잔재 정리 — 회사 source 로 향하는 일반 symlink 제거 (구버전 install로 생긴 것)
    if [ -n "$COMPANY_AGENTS_SRC" ]; then
        shopt -s nullglob
        for f in "$AGENTS_DST"/*.md; do
            case "$(basename "$f")" in
                mailplug-*) continue ;;
            esac
            if [ -L "$f" ]; then
                local TGT
                TGT="$(readlink "$f")"
                case "$TGT" in
                    "$COMPANY_AGENTS_SRC"/*) rm "$f" ;;
                esac
            fi
        done
        # 구버전 secretj-* symlink도 정리 (이름 변경 마이그레이션)
        for f in "$AGENTS_DST"/secretj-*.md; do
            [ -L "$f" ] && rm "$f"
        done
        shopt -u nullglob
    fi

    # Step 4: 회사 wrapper 재생성
    if [ -n "$COMPANY_AGENTS_SRC" ] && [ -d "$COMPANY_AGENTS_SRC" ]; then
        ln -sfn "$COMPANY_AGENTS_SRC" "$SOURCE_MARKER"
        find "$AGENTS_DST" -maxdepth 1 -name 'mailplug-*.md' -delete 2>/dev/null || true
        local CCOUNT=0
        shopt -s nullglob
        for f in "$COMPANY_AGENTS_SRC"/*.md; do
            local BASE OUT
            BASE="$(basename "$f" .md)"
            OUT="$AGENTS_DST/mailplug-${BASE}.md"
            awk -v new_name="mailplug-${BASE}" '
                BEGIN { in_fm = 0 }
                /^---$/ { in_fm = !in_fm; print; next }
                in_fm && /^name:/ { print "name: " new_name; next }
                in_fm && /^description:/ {
                    line = $0
                    sub(/^description: */, "", line)
                    gsub(/^"|"$/, "", line)
                    print "description: \"[mailplug 작업 영역 전용] CWD가 `mailplug/` 하위일 때만 사용. mailplug 외 프로젝트에서는 동일 역할의 일반 agent(예: planner, developer 등) 사용. 원본: " line "\""
                    next
                }
                { print }
            ' "$f" > "$OUT"
            CCOUNT=$((CCOUNT + 1))
        done
        shopt -u nullglob
        echo "[✓] agents/ : 회사 wrapper mailplug-*.md ${CCOUNT}개 생성"
    fi

    # Step 5: 우리 agent symlink 추가
    local ADDED=0 SKIPPED=0
    shopt -s nullglob
    for f in "$PERSONAL_AGENTS_SRC"/*.md; do
        local NAME DST
        NAME="$(basename "$f")"
        DST="$AGENTS_DST/$NAME"
        if [ -L "$DST" ] && [ "$(readlink "$DST")" = "$f" ]; then
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
        if [ -e "$DST" ]; then
            mv "$DST" "$DST.bak.$(date +%Y%m%d_%H%M%S)"
        fi
        ln -s "$f" "$DST"
        ADDED=$((ADDED + 1))
    done
    shopt -u nullglob
    echo "[✓] agents/ : 개인 +${ADDED} 추가, ${SKIPPED} 동일"
}

link_dir "$DOTFILES_DIR/skills" "$CLAUDE_DIR/skills"
link_dir "$DOTFILES_DIR/hooks"  "$CLAUDE_DIR/hooks"
merge_agents

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "Symlinks:"
ls -la "$CLAUDE_DIR/skills" "$CLAUDE_DIR/hooks"
echo ""
echo "Agents 구조:"
echo "  - 일반: $(find "$CLAUDE_DIR/agents" -maxdepth 1 -type l -name '*.md' -not -name 'mailplug-*' 2>/dev/null | wc -l | tr -d ' ')개 (mailplug 외부 기본)"
echo "  - mailplug-*: $(find "$CLAUDE_DIR/agents" -maxdepth 1 -name 'mailplug-*.md' -not -type l 2>/dev/null | wc -l | tr -d ' ')개 (mailplug/ 하위 전용)"
echo ""
echo "다음 단계:"
echo "  - 회사 cursor-setting 업데이트 후 → ./install.sh 재실행 (mailplug-* wrapper 갱신)"
echo "  - 회사 install 재실행 시 agents가 dir-symlink로 덮입니다 → 이 install.sh 재실행 필요"
