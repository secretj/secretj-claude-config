#!/bin/bash
# secretj-claude-config uninstaller
#
# install.sh가 만든 것들을 제거합니다:
#   - skills/, hooks/ symlink
#   - agents/ 안의 우리 개인 *.md symlink (planner.md, developer.md 등)
#   - agents/ 안의 mailplug-*.md wrapper (회사 source에서 install이 만든 사본)
#   - agents/.mailplug-source marker symlink
#
# .bak 백업은 그대로 둡니다 (수동 복원).
#
# 회사 dir-symlink 형태로 되돌리려면:
#   rm -rf ~/.claude/agents
#   (cd ~/Desktop/source/mailplug/cursor-setting && ./install.sh)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

unlink_if_ours() {
    local DST="$1"
    local EXPECTED_SRC="$2"
    local NAME
    NAME="$(basename "$DST")"

    if [ ! -L "$DST" ]; then
        echo "[=] $NAME : symlink 아님 (skip)"
        return 0
    fi

    local CURRENT
    CURRENT="$(readlink "$DST")"
    if [ "$CURRENT" != "$EXPECTED_SRC" ]; then
        echo "[!] $NAME : 우리 symlink가 아님 (skip) — 현재: $CURRENT"
        return 0
    fi

    rm "$DST"
    echo "[✓] $NAME 제거됨"
}

unlink_if_ours "$CLAUDE_DIR/skills" "$DOTFILES_DIR/skills"
unlink_if_ours "$CLAUDE_DIR/hooks"  "$DOTFILES_DIR/hooks"

# agents/ 정리
PERSONAL_AGENTS_SRC="$DOTFILES_DIR/agents"
AGENTS_DST="$CLAUDE_DIR/agents"
SOURCE_MARKER="$AGENTS_DST/.mailplug-source"

if [ -d "$AGENTS_DST" ] && [ ! -L "$AGENTS_DST" ]; then
    # 1) 우리 개인 *.md symlink 제거
    REMOVED_PERSONAL=0
    if [ -d "$PERSONAL_AGENTS_SRC" ]; then
        shopt -s nullglob
        for f in "$PERSONAL_AGENTS_SRC"/*.md; do
            NAME="$(basename "$f")"
            DST="$AGENTS_DST/$NAME"
            if [ -L "$DST" ] && [ "$(readlink "$DST")" = "$f" ]; then
                rm "$DST"
                REMOVED_PERSONAL=$((REMOVED_PERSONAL + 1))
            fi
        done
        shopt -u nullglob
    fi
    echo "[✓] agents/ : 개인 symlink ${REMOVED_PERSONAL}개 제거"

    # 2) mailplug-*.md wrapper 제거 (install이 만든 사본)
    REMOVED_WRAPPER=0
    shopt -s nullglob
    for f in "$AGENTS_DST"/mailplug-*.md; do
        rm "$f"
        REMOVED_WRAPPER=$((REMOVED_WRAPPER + 1))
    done
    shopt -u nullglob
    echo "[✓] agents/ : mailplug-* wrapper ${REMOVED_WRAPPER}개 제거"

    # 3) .mailplug-source marker 제거
    if [ -L "$SOURCE_MARKER" ]; then
        rm "$SOURCE_MARKER"
        echo "[✓] agents/.mailplug-source marker 제거"
    fi
fi

echo ""
echo "백업(.bak.*)은 그대로 두었습니다. 필요시 수동 복원하세요."
echo "회사 agents를 다시 설정하려면 cursor-setting/install.sh 재실행."
