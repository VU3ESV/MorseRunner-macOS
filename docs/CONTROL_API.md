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

> **The toggle is remembered (v0.1.6+).** Once you enable the API it is saved to
> the settings file and **auto-started on the next launch** — so a client can rely
> on `:7300` being up after a restart without a human re-toggling the menu. (Same
> for **File → SDR Server** and **Settings → Mute Local Audio**.) Turn it off from
> the same menu item to stop persisting it.

## Recent changes (client-visible)

What a client integrator needs to know since v0.1.4, newest first
(full notes in [`RELEASE_NOTES.md`](../RELEASE_NOTES.md)):

| Version | Change | Impact on a client |
|---------|--------|--------------------|
| **v0.1.7** | Fixed a hang where MorseRunner would not quit while the API was on | The server now shuts down cleanly; no behavioural change to requests |
| **v0.1.6** | API / SDR / Mute-Local toggles persist and auto-start on launch | `:7300` stays available across restarts — no need to re-enable the menu |
| **v0.1.5** | New `spreadHz` parameter; **numeric params are range-validated** | Set caller frequency scatter; out-of-range values now return **HTTP 400** instead of being silently clamped |

The parameter table below is the authoritative reference for names, ranges and
defaults.

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

#### Parameter reference

The same fields are accepted by `POST /scenario` and by `POST /command`
`{"action":"set",…}`. All are optional (except `mode` on `/scenario`); omitted
fields keep their current value. `GET /state` echoes every one of them back, so a
client can read the effective value after setting it.

| param | type | range | default | meaning |
|-------|------|-------|---------|---------|
| `mode` | string | `pileup\|single\|wpx\|hst` | — (required on `/scenario`) | contest run mode to start |
| `durationSec` | int | 1..600 | 30 | *(scenario only)* seconds to run before auto-stop |
| `call` | string | valid callsign | `VE3NEA` | your (running-station) callsign |
| `wpm` | int | 10..120 | 30 | your keying speed; callers key near this |
| `pitchHz` | int | 300..900 (50 Hz grid) | 600 | receiver centre / your CW pitch; snapped to nearest 50 Hz |
| `bandwidthHz` | int | 100..600 (50 Hz grid) | 500 | **local monitor** CW filter width — **does not** affect the SDR IQ (see note) |
| `spreadHz` | int | 0..3000 | 300 | std-dev of caller frequency scatter around `pitchHz` (see note) |
| `activity` | int | 1..9 | 2 | how many callers answer each CQ (Poisson mean = `activity/2` per CQ) |
| `rit` | int | -500..500 | 0 | receiver incremental tuning offset (Hz) |
| `qsk` | bool | — | true | full break-in (hear callers between your dits) |
| `qrn` | bool | — | true | atmospheric static crashes |
| `qrm` | bool | — | true | interfering station |
| `qsb` | bool | — | true | Rayleigh fading |
| `flutter` | bool | — | true | auroral/polar flutter on some callers |
| `lids` | bool | — | true | poorly-operating stations (call out of turn, wrong RST/NR) |
| `muteLocal` | bool | — | false | silence the Mac speakers; sim + SDR IQ + ground-truth keep running |

Notes on the parameters that trip clients up:

- **`muteLocal`** (also **Settings → Mute Local Audio**) silences local speaker
  output while the simulation runs at full real-time rate — the SDR IQ stream and
  ground-truth calls are unaffected. Ideal when driving MorseRunner purely as a
  test SDR source.
- **`spreadHz`** is the standard deviation of the Gaussian frequency scatter of
  the pileup callers around `pitchHz`. The original tight pile (300) can overlap
  callers in one audio bin; widen it so an SDR skimmer resolves callers into
  separate frequencies for cleaner decode tests. Each caller's resulting offset is
  reported as `freq_hz` in the returned `calls`.
- **`bandwidthHz`** narrows only the **local monitor audio**. The SDR IQ is tapped
  wideband *before* the CW filter, so this setting has **no effect on what a CW
  Skimmer receives** — do not use it to try to widen the skimmer's passband.

**Range validation (v0.1.5+).** Numeric params are bounds-checked, **not silently
clamped**. An out-of-range value makes `POST /command` (`set`) and `POST /scenario`
return **HTTP 400** with body `{"ok":false,"error":"pitchHz=1200 out of range
[300..900]"}` and changes nothing — so a test harness catches bad input instead of
running with a quietly coerced value. `pitchHz`/`bandwidthHz` are additionally
snapped to their 50 Hz grid (floored) once in range.

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
