#!/bin/bash
# statusLine 스크립트 — 플랜 사용 한도와 이 대화의 비중을 상태줄에 한 줄로 보여 준다.
#
# 출력 예: Opus 5.5 · 이 대화 24% · 세션 50% ↻17:30 · 주간 35% ↻10/08 09:00
#
#   세션    5시간 한도 사용률 (rate_limits.five_hour). /usage 의 "Current session" 과 같다
#   주간    7일 한도 사용률 (rate_limits.seven_day)
#   이 대화 세션 사용량 중 이 대화의 비중. 입력 JSON 에 없는 값이라 아래 장부로 센다
#
# 장부 — 세션 창마다 파일 하나(ledger-<resets_at>.json)를 이 컴퓨터의 모든 대화가 공유한다.
#   1. 대화마다 이번 창에서 쓴 비용(cost.total_cost_usd 의 증가분)을 장부에 쌓는다
#   2. 세션 사용률이 오르면, 오른 만큼을 그사이 각 대화가 쓴 비용 비율로 나눠 배정한다
#   3. 그사이 아무 대화도 비용을 쓰지 않았으면 다른 곳(claude.ai·다른 컴퓨터)의 몫으로 둔다
#   그래서 이 컴퓨터의 모든 대화를 합쳐도 100% 를 넘지 않는다.
#   새 창이 열리면 새 장부를 쓰고 지난 장부는 지운다. 크론은 쓰지 않는다.
#
# API 키 사용자는 rate_limits 가 없어 한도 칸이 빠진다.
# 무엇이 실패하든 상태줄에 에러를 띄우지 않는다. 아는 것만 찍는다.

/usr/bin/python3 -c '
import fcntl, glob, json, os, re, sys, tempfile, time

NEW_WINDOW_GAP = 600       # resets_at 이 이만큼(초) 넘게 달라야 다른 창으로 본다. 작은 흔들림은 같은 창이다

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}

sid = data.get("session_id")
sid = sid if isinstance(sid, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", sid) else "unknown"
cost = (data.get("cost") or {}).get("total_cost_usd")
cost = cost if isinstance(cost, (int, float)) and cost == cost and cost >= 0 else None
cache_dir = os.path.join(tempfile.gettempdir(), f"claude-statusline-{os.getuid()}")

def limit(key):
    """(사용률 정수, resets_at) 또는 None."""
    w = (data.get("rate_limits") or {}).get(key) or {}
    pct = w.get("used_percentage")
    if not isinstance(pct, (int, float)) or pct != pct:          # NaN 거름
        return None
    resets_at = w.get("resets_at")
    if not isinstance(resets_at, (int, float)) or not 0 < resets_at < time.time() + 8 * 86400:
        resets_at = None                                         # 초 단위 epoch 가 아니면 버린다
    return round(pct), resets_at                                 # 보이는 숫자와 색 기준을 맞춘다

class Stale(Exception):
    """이전 창의 늦게 온 값."""

def ledger_path(resets_at):
    """이 창의 장부 경로. 이전 창의 늦은 값이면 Stale. 지난 창의 장부는 여기서 지운다."""
    known = []
    for path in glob.glob(os.path.join(cache_dir, "ledger-*.json")):
        m = re.fullmatch(r"ledger-(\d+)\.json", os.path.basename(path))
        if m:
            known.append((int(m.group(1)), path))
    if any(r > resets_at + NEW_WINDOW_GAP for r, _ in known):
        raise Stale
    mine = None
    for r, path in known:
        if abs(r - resets_at) <= NEW_WINDOW_GAP:
            mine = path                                          # 흔들린 resets_at 도 같은 장부를 쓴다
        else:
            os.remove(path)                                      # 지난 창
    for path in glob.glob(os.path.join(cache_dir, "*.json")):    # 장부 이전 버전이 대화마다 남긴 캐시
        if not os.path.basename(path).startswith("ledger-"):
            os.remove(path)
    return mine or os.path.join(cache_dir, f"ledger-{int(resets_at)}.json")

def update(ledger, pct):
    """장부를 갱신하고 이 대화가 배정받은 양(한도 대비 %p)을 돌려준다."""
    if "last_pct" not in ledger:
        ledger.update(last_pct=pct, convs={})                    # 장부가 생기기 전 사용량은 누구 몫인지 모른다
    convs = ledger["convs"]
    me = convs.setdefault(sid, {"cost": cost, "pending": 0.0, "share": 0.0})
    if cost is not None:
        last = me.get("cost")
        if last is not None:
            me["pending"] += cost - last if cost >= last else cost   # 줄었으면 프로세스가 새로 떴다
        me["cost"] = cost
    rise = pct - ledger["last_pct"]
    if rise > 0:
        total = sum(c["pending"] for c in convs.values())
        if total > 0:
            for c in convs.values():
                c["share"] += rise * c["pending"] / total
        # total 이 0 이면 그사이 이 컴퓨터는 아무것도 안 썼다 → 다른 곳의 몫
        for c in convs.values():
            c["pending"] = 0.0
        ledger["last_pct"] = pct
    # rise < 0 은 무시한다. 한 창 안에서 사용률은 내려가지 않는다. 낮은 값은 한동안 API 를 안 부른
    # 대화가 들고 있는 옛 값이다. 기준점을 내리면 같은 상승분을 다시 배정해 합이 부푼다
    total_share = sum(c["share"] for c in convs.values())
    if total_share > ledger["last_pct"] > 0:                    # 이전 버전이 부풀린 장부를 사용률에 맞춰 줄인다
        for c in convs.values():
            c["share"] *= ledger["last_pct"] / total_share
    return me["share"]

def conversation_share(pct, resets_at):
    """세션 사용량 중 이 대화의 비중(%). 계산할 수 없으면 None."""
    if resets_at is None:
        return None
    os.makedirs(cache_dir, exist_ok=True)
    with open(os.path.join(cache_dir, "ledger.lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)                         # 여러 대화가 동시에 장부를 고친다
        path = ledger_path(resets_at)
        try:
            ledger = json.load(open(path))
            ledger = ledger if isinstance(ledger, dict) and isinstance(ledger.get("convs"), dict) else {}
        except Exception:
            ledger = {}
        share = update(ledger, pct)
        tmp = f"{path}.{os.getpid()}.tmp"
        with open(tmp, "w") as f:
            json.dump(ledger, f)
        os.replace(tmp, path)
    return min(100, round(share * 100 / pct)) if pct > 0 else 0

def show(label, pct, resets_at, fmt):
    color = "31" if pct >= 90 else "33" if pct >= 70 else "32"
    text = f"{label} \033[{color}m{pct}%\033[0m"
    if resets_at is not None:
        text += " ↻" + time.strftime(fmt, time.localtime(resets_at))
    return text

def model_part():
    name = (data.get("model") or {}).get("display_name")
    return [name.split(" (")[0]] if isinstance(name, str) and name else []

def five_part():
    five = limit("five_hour")
    if not five:
        return []
    try:
        share = conversation_share(*five)
    except Stale:
        return []                                                # 두 칸이 어긋나지 않게 이번 갱신은 건너뛴다
    except Exception:
        share = None                                             # 장부를 못 쓰면 이 대화 칸만 뺀다
    head = [f"이 대화 {share}%"] if share is not None else []
    return head + [show("세션", *five, "%H:%M")]

def seven_part():
    seven = limit("seven_day")
    return [show("주간", *seven, "%m/%d %H:%M")] if seven else []

# 칸마다 따로 감싼다. 한 칸이 실패해도 나머지는 찍는다.
parts = []
for part in (model_part, five_part, seven_part):
    try:
        parts += part()
    except Exception:
        pass

print(" · ".join(parts))
' 2>/dev/null || true
