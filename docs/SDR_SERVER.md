# SDR-Server mode — MorseRunner as a live HPSDR receiver for CW-Skimmer testing

This macOS port can present its contest pileup to a CW Skimmer (e.g.
**SkimServerMac**) as if MorseRunner were a real network SDR. The skimmer tunes
it, receives the pileup as IQ, and decodes the CW; a separate **ground-truth**
feed publishes exactly which callsigns were keyed and when, so the decoder can be
scored precision/recall against the truth.

Why HPSDR and not QS1R: the QS1R is a USB device (emulating its HID/FX2 USB
transport is impractical). HPSDR "Protocol 1" (Metis/Hermes) is **IP/UDP-based**,
so MorseRunner emulates that.

## Turn it on

1. **File → SDR Server (HPSDR :1024)** — toggles the servers (a message box shows
   status). Leave it on. The toggle is **remembered across restarts** (v0.1.6+):
   once enabled it auto-starts on the next launch, so a skimmer/test rig can rely
   on the device being present without a human re-toggling the menu.
2. Start a contest run as usual — **Run → Single Calls** (a steady stream of known
   callers, best for decoder scoring) or **Pile-Up** (press F1/Enter to CQ; a
   burst of callers answers). IQ streams only while a run is active.
3. Point your skimmer at the Mac:
   - Same machine: HPSDR device IP `127.0.0.1`.
   - Another machine on the LAN: this Mac's LAN IP (the emulator also answers
     UDP broadcast discovery).

Install a `Master.dta` supercheck-partial file next to the executable for diverse
real callsigns; without it every caller is the fallback `P29SX`.

## What it emulates (HPSDR Protocol 1)

Verified against SkimServerMac's `HPSDRConnection` / `HPSDRDiscovery`:

| Aspect | Value |
|--------|-------|
| Transport | UDP, port **1024** |
| Discovery | reply to `EF FE 02` with `EF FE 02` + MAC + FW(33) + boardID(1=Hermes), 60 B |
| Start / rate | begins on `EF FE 04 01` or first EP2 config frame (`EF FE 01 02`); sample rate read from C1 speed bits (48/96/192/384 kHz) |
| Stop | `EF FE 04 00` |
| IQ data (EP6) | 1032-B frames `EF FE 01 06` + seq(4) + two 512-B Ozy buffers (`7F 7F 7F` + 5 status + 504 payload); per group `[I(3) Q(3) mic(2)]`, **24-bit big-endian signed**, `/8388607` |
| Receivers | 1 (Protocol 1 supports up to 8) |
| Default rate | 48 kHz (what SkimServerMac's CW front-end uses) |

The streamed IQ is the **wideband received baseband** from `Contest.GetAudio` —
band noise + QRN/QRM + every caller — *before* the operator's narrow CW filter and
*without* your own transmit signal. (Because the tap is ahead of the CW filter,
the operator's **bandwidth** setting does not change the IQ a skimmer receives.)
By default the callers scatter within ~±300 Hz of the receiver centre, each at its
audio offset (its "pitch"); widen that scatter with the control-API `spreadHz`
parameter (0..3000 Hz, see [CONTROL_API.md](CONTROL_API.md)) so a skimmer can
resolve overlapping callers into separate frequencies. The complex 11025 Hz
baseband is fractionally resampled up to the requested rate.

## Ground-truth feed (TCP :7355, newline-delimited JSON)

Connect a TCP client to port **7355**. On connect you get a `hello`, then the full
history is replayed and new events stream live (attach any time — before, during,
or after the run):

```json
{"event":"hello","source":"MorseRunner","format":"ndjson"}
{"t_ms":279,"call":"P29SX","freq_hz":163,"wpm":25,"msg":"P29SX"}
```

| field | meaning |
|-------|---------|
| `t_ms` | ms since the run started (the simulation clock — exact) |
| `call` | the caller's true callsign |
| `freq_hz` | audio offset from the receiver centre = the caller's pitch (correlates with the IQ spectral peak) |
| `wpm` | keying speed |
| `msg` | the text keyed |

One event is emitted per caller when it becomes active (`DxStn.CreateStation`).

## Reference / test client

`tools/hpsdr_client.py` mimics SkimServerMac's HPSDR client end-to-end: it runs
discovery, starts streaming, parses the EP6 IQ (frames/samples/energy + a coarse
spectrum), and reads the ground-truth feed. Use it to sanity-check the emulator
without the full skimmer:

```bash
# enable SDR Server in MorseRunner, start Run → Single Calls, then:
python3 tools/hpsdr_client.py
```

Expected: `DISCOVERY: OK`, ~48000 samples/s of IQ with a spectral peak matching a
ground-truth `freq_hz`, and JSON caller events.

## Implementation

All add-on code is isolated from the frozen simulation units:

- `src/platform/HpsdrDevice.pas` — HPSDR UDP device emulator (discovery, EP2/start
  handling, EP6 framing) + IQ ring + fractional 11025→rate resampler.
- `src/platform/TruthServer.pas` — ground-truth TCP/JSON server with replay-on-connect.
- `src/platform/SdrIntf.pas` — thin facade (`SdrStart/Stop/PushIq/Truth`); the
  only symbols the simulation/GUI touch.
- Taps: one guarded line in `Contest.GetAudio` (`SdrPushIq`) and one in
  `DxStn.CreateStation` (`SdrTruth`). Both are no-ops unless the server is running,
  so normal MorseRunner behaviour is unchanged.

## Scoring against SkimServerMac (next step)

SkimServerMac already has an *offline* pileup test (`TestHarness/CWPileupTest`
feeding `mr_gen.c` IQ straight into `cdsp_cw_skimsrv`). The *live* path is:

1. Connect a scorer to MorseRunner's truth feed (:7355) → the set of true calls +
   times.
2. Read SkimServerMac's decoded spots (its telnet/RBN/TSV output) over the same run.
3. Compute precision/recall (call match; optional ±freq / ±time tolerance).

A small standalone scorer (or a `CWLiveScore` target inside SkimServerMac that
consumes :7355) is the natural next addition.
