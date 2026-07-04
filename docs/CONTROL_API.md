# Control / Automation API

MorseRunner exposes an embedded **HTTP + JSON** endpoint so a test application can
drive it programmatically: hand it a **scenario** (e.g. a Pile-Up), MorseRunner
runs it while recording **every callsign it generates, with exact timestamps**,
and returns that ground-truth log when the run is over. Everything a user can do
from the UI (set call / WPM / pitch / bandwidth / band conditions, start & stop
the run modes, send the F-key messages, log a QSO, read the score) is also
reachable as an action.

This is the request/response companion to the streaming
[SDR-server ground-truth feed](SDR_SERVER.md): the SDR feed streams calls live
over TCP as IQ is decoded; this API lets a client *orchestrate* a run and collect
the results in one call.

## Turn it on

**File → Test Control API (:7300)** in MorseRunner. The server then listens on
`http://127.0.0.1:7300/`. (Bind is all-interfaces, so a client on the LAN can use
the Mac's IP.) Install a `Master.dta` supercheck-partial file next to the
executable for diverse real callsigns; without it every generated caller is the
fallback `P29SX`.

## Endpoints

| Method & path | Purpose |
|---------------|---------|
| `GET  /`         | plain-text help |
| `GET  /state`    | current settings + score + run status + `callCount` |
| `GET  /calls`    | the recorded ground-truth calls for the current/last run |
| `POST /reset`    | clear the recorded calls |
| `POST /command`  | `{"action":"…", …}` — invoke one UI action |
| `POST /scenario` | `{"mode":"pileup","durationSec":30, …}` — run a scenario, block, return the calls |

### `POST /scenario` — the main entry point

Body (all fields optional except `mode`):

```json
{
  "mode": "pileup",        // pileup | single | wpx | hst
  "durationSec": 30,       // 1..600; how long to run before stopping
  "call": "AB1TEST",       // your (running-station) callsign
  "wpm": 28,               // your keying speed; callers key near this
  "activity": 8,           // 1..9, how many callers answer each CQ
  "pitchHz": 600, "bandwidthHz": 500, "spreadHz": 300, "qsk": true, "rit": 0,
  "qrn": false, "qrm": false, "qsb": true, "flutter": true, "lids": true,
  "muteLocal": true        // silence the Mac speakers; sim/SDR/truth keep running
}
```

> `muteLocal` (also **Settings → Mute Local Audio** in the UI) silences the local
> speaker output while the simulation keeps running at full real-time rate — so
> the SDR IQ stream and the ground-truth calls are unaffected. Ideal when driving
> MorseRunner purely as a test SDR source.

> `spreadHz` (0..3000, default 300) is the **standard deviation of the Gaussian
> frequency scatter** of the pileup callers around `pitchHz`. The original tight
> pile (300) can overlap callers in the same audio bin; widen it so an SDR
> skimmer resolves callers into separate frequencies for cleaner decode tests.
> The value it maps to (each caller's true offset) is reported per call as
> `freq_hz`.

> **Range validation.** Numeric settings are bounds-checked, not silently
> clamped: `wpm` 10..120, `pitchHz` 300..900, `bandwidthHz` 100..600 (50 Hz
> grid), `activity` 1..9, `rit` -500..500, `spreadHz` 0..3000. An out-of-range
> value makes `POST /command` (`set`) and `POST /scenario` return **HTTP 400**
> with `{"ok":false,"error":"…out of range…"}` and changes nothing — so a test
> harness sees the bad input instead of a quietly coerced run.

Behaviour: applies those settings, **resets** the call log, starts the run, sends
CQ (and keeps re-CQing for `pileup`/`wpx` so the pileup stays fed), waits
`durationSec`, stops, and responds:

```json
{
  "mode": "pileup", "durationSec": 14, "count": 10,
  "calls": [
    {"t_ms": 5433, "call": "DL3RC", "freq_hz":  47, "wpm": 22, "msg": "DL3RC"},
    {"t_ms": 5433, "call": "G3TXF", "freq_hz": -51, "wpm": 23, "msg": "G3TXF"},
    ...
  ],
  "score": { "call": "...", "running": false, "score": {"rawScore":0, ...}, ... }
}
```

Each `calls` entry is one caller as it became active:

| field | meaning |
|-------|---------|
| `t_ms` | ms since the run started (simulation clock — exact) |
| `call` | the caller's true callsign |
| `freq_hz` | audio offset from the receiver centre (the caller's pitch) — correlates with the IQ spectral position when the [SDR server](SDR_SERVER.md) is also on |
| `wpm` | keying speed |
| `msg` | text keyed |

> The HTTP request blocks for `durationSec`; set your client timeout above that.

### `POST /command` — individual UI actions

`{"action": "<name>", ...params}`:

| action | params | does |
|--------|--------|------|
| `set` | any of `call, wpm, pitchHz, bandwidthHz, spreadHz, qsk, activity, rit, qrn, qrm, qsb, flutter, lids, muteLocal` | set those controls; returns full state |
| `run` | `mode` = `stop\|pileup\|single\|wpx\|hst` | start/stop a run mode |
| `stop` | — | stop the run |
| `send` | `msg` = `cq\|nr\|tu\|mycall\|hiscall\|b4\|qm\|nil\|agn` | send an F-key message |
| `enter` | `call, rst, nr` | fill the QSO entry fields |
| `saveQso` | — | log the current QSO |
| `wipe` | — | clear the entry fields |

Example: `curl -s localhost:7300/command -d '{"action":"set","wpm":40,"activity":6}'`

## Example client

`tools/api_client.py` runs a scenario and prints the returned calls, then shows a
couple of `/command` + `/state` calls. Quick check with `curl`:

```bash
# run a 20 s pileup and pretty-print the generated calls
curl -s localhost:7300/scenario \
     -d '{"mode":"pileup","durationSec":20,"activity":8}' | python3 -m json.tool
```

## Notes & design

- **Threading.** The HTTP server runs on background threads; every action is
  marshaled to the **main thread** via `TThread.Synchronize` because the
  simulation/GUI are not thread-safe. A `/scenario` request sleeps on its own
  connection thread while the run executes on the main thread.
- **Ground-truth source.** Each caller is recorded by `DxStn.CreateStation` →
  `ApiRecordCall`, which also forwards to the live SDR truth feed. The log is
  reset at the start of every run (UI- or API-initiated).
- **Isolation.** All code is in `src/platform/ControlApi.pas` plus one dispatch
  method (`TMainForm.ApiDispatch`) and a menu toggle in `Main.pas`. Nothing runs
  unless the API is toggled on; the simulation math is untouched.
- **Combine with the SDR server** (both toggles on): a test app can `POST
  /scenario` to generate a known pileup *and* have a CW Skimmer decode the IQ
  MorseRunner streams, then score decoded spots against the `calls` returned here.
