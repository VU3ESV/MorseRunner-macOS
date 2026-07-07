#!/usr/bin/env python3
# Exercise the MorseRunner control API: run a scenario and get the recorded
# ground-truth calls back, plus a couple of /command + /state calls.
import json, urllib.request, urllib.error

BASE = "http://127.0.0.1:7300"

def call(method, path, body=None):
    """Returns (status_code, parsed_json). Out-of-range numeric params make the
    API return HTTP 400 with {"ok":false,"error":...}; we surface that instead of
    raising, so a client can branch on the status."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:                 # e.g. 400 validation error
        return e.code, json.loads(e.read().decode())

# 1) initial state — /state echoes back every settable parameter
_, st = call("GET", "/state")
print("STATE:", {k: st[k] for k in ("call","wpm","pitchHz","bandwidthHz","spreadHz","activity","running")})

# 2) run a Single-Calls scenario for 6 s. spreadHz=800 widens the pile so an SDR
#    skimmer can resolve callers into separate frequencies (freq_hz below).
print("\nPOST /scenario (single, 6s, spreadHz=800) ...")
_, res = call("POST", "/scenario", {
    "mode": "single", "durationSec": 6,
    "call": "AB1TEST", "wpm": 28, "activity": 6, "spreadHz": 800,
    "qrn": False, "qrm": False, "qsb": True, "lids": True,
})
calls = res["calls"]
print(f"  returned {res['count']} generated calls")
for c in calls[:8]:
    print(f"    t={c['t_ms']:>6}ms  {c['call']:<8} {c['freq_hz']:+4d}Hz  {c['wpm']}wpm  msg={c['msg']!r}")
print("  score:", res["score"].get("score"))

# 3) generic /command examples (invoke UI actions)
print("\nPOST /command set wpm=40 ...")
print("  ->", call("POST", "/command", {"action": "set", "wpm": 40})[1]["wpm"])
print("POST /command run single, then stop ...")
call("POST", "/command", {"action": "run", "mode": "single"})
import time; time.sleep(2)
n = call("GET", "/calls")[1]["count"]
call("POST", "/command", {"action": "stop"})
print(f"  generated {n} calls during 2s manual run")

# 4) range validation: an out-of-range value is REJECTED with HTTP 400 (v0.1.5+),
#    not silently clamped. A client should check the status and read .error.
print("\nPOST /command set pitchHz=1200 (out of range) ...")
code, err = call("POST", "/command", {"action": "set", "pitchHz": 1200})
print(f"  -> HTTP {code}: {err.get('error')}")

print("\nVERDICT:", "CONTROL API OK — scenario ran and returned timestamped calls"
      if res["count"] > 0 else "no calls returned")
