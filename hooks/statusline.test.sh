#!/bin/bash
# statusline.sh 장부 회귀 시험. 격리된 TMPDIR 에서 돈다.
SCRIPT=${1:-"$(cd "$(dirname "$0")" && pwd)/statusline.sh"}
export TMPDIR=$(mktemp -d)
R=$(( $(date +%s) + 3600 ))
run() { # sid cost pct
  printf '{"session_id":"%s","cost":{"total_cost_usd":%s},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s}}}' "$1" "$2" "$3" "$R" | "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g'
}
sum() { /usr/bin/python3 -c "import json,glob;d=json.load(open(glob.glob('$TMPDIR/claude-statusline-*/ledger-*.json')[0]));print(round(sum(c['share'] for c in d['convs'].values()),2), d['last_pct'])"; }
fail=0
check() { if [ "$1" = "$2" ]; then echo "  ok   $3 ($1)"; else echo "  FAIL $3: got '$1' want '$2'"; fail=1; fi; }

echo "[정상] 두 대화가 3:1 로 쓰고 0→8% 오르면 6:2 로 나눈다"
run A 0 0 >/dev/null; run B 0 0 >/dev/null
run A 3 0 >/dev/null; run B 1 0 >/dev/null
check "$(run A 3 8 | grep -o '이 대화 [0-9]*%')" "이 대화 75%" "A 비중"
check "$(run B 1 8 | grep -o '이 대화 [0-9]*%')" "이 대화 25%" "B 비중"

echo "[경계] 멈춘 대화가 옛 사용률(5%)을 계속 보내도 다시 배정하지 않는다"
run S 0 5 >/dev/null
for i in 1 2 3 4 5; do run S 0 5 >/dev/null; run A $((3+i)) 8 >/dev/null; run A $((3+i)) 12 >/dev/null; done
check "$(sum)" "12.0 12" "배정 합 = 사용률"

echo "[실패] 이미 부풀어 있는 장부는 사용률에 맞게 줄인다"
F=$(ls $TMPDIR/claude-statusline-*/ledger-*.json)
/usr/bin/python3 -c "import json;d=json.load(open('$F'));d['convs']['A']['share']=30;json.dump(d,open('$F','w'))"
run B 1 12 >/dev/null
check "$(/usr/bin/python3 -c "import json;d=json.load(open('$F'));print(round(sum(c['share'] for c in d['convs'].values()),2) <= 12)")" "True" "합이 사용률 이하"
rm -rf "$TMPDIR"; exit $fail
