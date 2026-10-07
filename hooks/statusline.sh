#!/bin/bash
# statusLine 스크립트 — 플랜 사용 한도와 이 대화가 쓴 몫을 상태줄에 한 줄로 보여 준다.
#
# 출력 예: Opus 5.5 · 이 대화 24% · 세션 50% ↻17:30 · 주간 35% ↻10/08 09:00
#
#   세션    5시간 한도 사용률 (rate_limits.five_hour). /usage 의 "Current session" 과 같다
#   주간    7일 한도 사용률 (rate_limits.seven_day)
#   이 대화 세션 사용량 중 이 대화의 비중. 세션 8% 중 2%p 를 썼으면 25%. 입력 JSON 에 없는 값이라 직접 센다 — 아래 session_share
#
# API 키 사용자는 rate_limits 가 없어 한도 칸이 빠진다.
# 무엇이 실패하든 상태줄에 에러를 띄우지 않는다. 아는 것만 찍는다.

/usr/bin/python3 -c '
import json, os, re, sys, tempfile, time

NEW_WINDOW_GAP = 600       # resets_at 이 이만큼(초) 이상 뒤로 가야 새 창으로 본다. 작은 흔들림은 같은 창이다

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}

sid = data.get("session_id")
sid = sid if isinstance(sid, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", sid) else "unknown"   # 경로 탈출 차단
cache_dir = os.path.join(tempfile.gettempdir(), f"claude-statusline-{os.getuid()}")
cache_file = os.path.join(cache_dir, sid + ".json")
try:
    cache = json.load(open(cache_file))
    cache = cache if isinstance(cache, dict) else {}
except Exception:
    cache = {}

def session_share(pct, resets_at):
    """이 대화가 지금 세션 창에서 쓴 양(한도 대비 %p). 이전 창의 늦은 값이면 None.
    대화의 첫 상태줄 갱신 때 사용률을 기준점으로 잡고, 늘어난 만큼을 센다.
    새 창이 열리면 그 창에서 처음 본 사용률을 기준점으로 다시 잡는다. 쉬는 동안 다른 대화가 쓴 양을 떠안지 않는다.
    한도는 계정 단위라 같은 시각에 돈 다른 대화의 사용량도 섞인다."""
    st = cache.get("five_hour")
    old = st.get("resets_at") if isinstance(st, dict) else None
    if not isinstance(st, dict):
        st = {"resets_at": resets_at, "base": pct, "last": pct}
    elif resets_at is not None and old is not None and resets_at < old - NEW_WINDOW_GAP:
        return None
    elif resets_at is not None and old is not None and resets_at > old + NEW_WINDOW_GAP:
        st = {"resets_at": resets_at, "base": pct, "last": pct}
    else:
        st["last"] = pct
        if old is None:
            st["resets_at"] = resets_at                 # 없던 리셋 시각이 생긴 것은 새 창이 아니다
    cache["five_hour"] = st
    return max(0, st["last"] - st["base"])

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
    share = session_share(*five)
    if share is None:
        return []                                                # 늦게 온 값으로 두 칸이 어긋나지 않게 이번 갱신은 건너뛴다
    pct = five[0]
    ratio = min(100, round(share * 100 / pct)) if pct > 0 else 0   # 세션 사용량을 100 으로 본 이 대화의 비중
    return [f"이 대화 {ratio}%", show("세션", *five, "%H:%M")]

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

try:
    os.makedirs(cache_dir, exist_ok=True)
    tmp = f"{cache_file}.{os.getpid()}.tmp"                      # 동시 실행이 같은 임시 파일을 덮지 않게
    with open(tmp, "w") as f:
        json.dump(cache, f)
    os.replace(tmp, cache_file)
except Exception:
    pass

print(" · ".join(parts))
' 2>/dev/null || true
