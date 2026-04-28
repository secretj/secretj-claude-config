#!/bin/bash
# secretj-claude-config installer
#
# 회사용 dotfiles (cursor-setting)와 충돌하지 않는 영역만 symlink:
#   ~/.claude/skills/  → ./skills/
#   ~/.claude/hooks/   → ./hooks/
#
# 회사 install.sh가 점유하는 영역(settings.json, agents/, commands/, CLAUDE.md)은
# 건드리지 않습니다. 회사 install 후에 실행해도 안전합니다.

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
#   - target이 일반 디렉토리면 .bak로 백업
#   - target이 이미 우리 source로의 symlink면 skip
#   - target이 다른 곳으로의 symlink면 에러로 멈춤 (사용자 확인 필요)
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
            echo "[=] $NAME 이미 올바르게 symlink됨 → $SRC"
            return 0
        else
            echo "[✗] $NAME 가 다른 곳으로 symlink되어 있습니다:"
            echo "    현재: $CURRENT"
            echo "    원하는 것: $SRC"
            echo "    → 수동으로 확인 후 'rm $DST' 하고 다시 실행하세요."
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

link_dir "$DOTFILES_DIR/skills" "$CLAUDE_DIR/skills"
link_dir "$DOTFILES_DIR/hooks"  "$CLAUDE_DIR/hooks"

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "Symlinks:"
ls -la "$CLAUDE_DIR/skills" "$CLAUDE_DIR/hooks"
echo ""
echo "다음 단계:"
echo "  - 백업된 .bak.* 디렉토리 안의 파일을 secretj-claude-config/ 로 옮기고 싶으면 수동 이동"
echo "  - hooks/ 디렉토리에 hook 스크립트 추가 후 chmod +x"
