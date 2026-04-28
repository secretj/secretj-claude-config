#!/bin/bash
# secretj-claude-config uninstaller
#
# install.sh가 만든 symlink만 제거합니다. .bak 백업은 그대로 둡니다 (수동 복원).

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

echo ""
echo "백업(.bak.*)은 그대로 두었습니다. 필요시 수동 복원하세요."
