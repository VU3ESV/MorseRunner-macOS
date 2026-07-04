#!/usr/bin/env python3
# Exercise the MorseRunner control API: run a scenario and get the recorded
# ground-truth calls back, plus a couple of /command + /state calls.
import json, urllib.request

BASE = "http://127.0.0.1:7300"

def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

# 1) initial state
st = call("GET", "/state")
print("STATE:", {k: st[k] for k in ("call","wpm","pitchHz","bandwidthHz","activity","running")})

# 2) run a Single-Calls scenario for 6 s with a chosen call/wpm/activity
print("\nPOST /scenario (single, 6s) ...")
res = call("POST", "/scenario", {
    "mode": "single", "durationSec": 6,
    "call": "AB1TEST", "wpm": 28, "activity": 6,
    "qrn": False, "qrm": False, "qsb": True, "lids": True,
})
calls = res["calls"]
print(f"  returned {res['count']} generated calls")
for c in calls[:8]:
    print(f"    t={c['t_ms']:>6}ms  {c['call']:<8} {c['freq_hz']:+4d}Hz  {c['wpm']}wpm  msg={c['msg']!r}")
print("  score:", res["score"].get("score"))

# 3) generic /command examples (invoke UI actions)
print("\nPOST /command set wpm=40 ...")
print("  ->", call("POST", "/command", {"action": "set", "wpm": 40})["wpm"])
print("POST /command run single, then stop ...")
call("POST", "/command", {"action": "run", "mode": "single"})
import time; time.sleep(2)
n = call("GET", "/calls")["count"]
call("POST", "/command", {"action": "stop"})
print(f"  generated {n} calls during 2s manual run")

print("\nVERDICT:", "CONTROL API OK — scenario ran and returned timestamped calls"
      if res["count"] > 0 else "no calls returned")
