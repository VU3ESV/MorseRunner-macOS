# CLAUDE.md — Morse Runner (macOS / Lazarus port)

This file orients an AI agent (or a new developer) working in this repository.
It documents **what the app is, how it is architected, how to build it on macOS,
and — most importantly — which parts must never change** because they carry the
exact contest-simulation logic of the original.

---

## 1. What this is

**Morse Runner** is a CW (Morse code) contest *simulator* originally written by
**Alex Shovkoplyas, VE3NEA** in Delphi/VCL for Windows
(<https://www.dxatlas.com/MorseRunner/>, source:
<https://github.com/VE3NEA/MorseRunner>, version **1.68**, MPL-2.0).

It generates a realistic pileup of stations calling you in a radio contest,
synthesizes their Morse audio (with QRN/QRM/QSB/flutter/LID effects), and scores
your ability to copy callsigns and exchanges under contest rules
(Pile-Up, Single Calls, WPX Competition, HST Competition).

**This repository is a native macOS port.** The goal is that *functionality and
logic match the original exactly*. To guarantee that, the port **recompiles the
original Object Pascal source** with **Free Pascal (FPC) + Lazarus LCL** instead
of rewriting it in another language. Only the Windows-specific edges (audio
device, WAV file, one custom control, the GUI form definitions) were replaced.

---

## 2. Golden rule: do not touch the simulation math

The behavior of the simulator lives in a set of **portable units that were copied
verbatim** from the original (only their `uses` clauses were trimmed of Windows
units and a `{$MODE Delphi}` directive was added). **If you change the numbers,
constants, RNG calls, or control flow in these files, you change the simulation
and break parity with VE3NEA's Morse Runner.** Treat them as frozen:

| Unit | Role (unchanged logic) |
|------|------------------------|
| `src/Contest.pas`  | Master audio+event loop: `GetAudio` renders one block (noise → QRN/QRM → station BFOs → RIT → self-mon → LPF → modulate → AGC → WAV), advances the sim clock, spawns callers, ends the run. |
| `src/Station.pas`  | Base station: Morse envelope generation, BFO phase, message text macros (`<my>`,`<his>`,`<#>`), NR-with-error rendering (5NN/TTT/cut numbers). |
| `src/MyStn.pas`    | The operator (you): message piece queue, live callsign correction while sending. |
| `src/DxStn.pas`    | A calling DX station: amplitude/pitch/QSB draw, event handling, writes QSO to log when done. |
| `src/DxOper.pas`   | **The "brain":** DX operator state machine (`osNeedQso…osDone`), callsign fuzzy-match (edit-distance `IsMyCall`), patience, reply selection, WPM/NR/delay models. |
| `src/StnColl.pas`  | Station collection (callers, QRN, QRM). |
| `src/QrmStn.pas` / `src/QrnStn.pas` | Interfering-station and static-crash generators. |
| `src/Qsb.pas`      | Rayleigh-fading (QSB) gain envelope. |
| `src/CallLst.pas`  | Loads `Master.dta` supercheck-partial call database; `PickCall`. |
| `src/RndFunc.pas`  | Random distributions (normal, Rayleigh, Poisson, U-shaped) and blocks↔seconds. |
| `src/Log.pas`      | Scoring, dupe/NIL/RST/NR checking, WPX prefix extraction, rate & histogram. (GUI-coupled; see deviations.) |
| `src/Ini.pas`      | Settings + defaults (WPM, pitch, bandwidth, activity, durations, buffer size). |
| `src/MorseKey.pas` / `src/MorseTbl.pas` | Morse encoder + Blackman-Harris keying envelope + code table. |
| `src/Mixers.pas`   | Down-mixer / modulator (BFO → pitch). |
| `src/MovAvg.pas` / `src/QuickAvg.pas` | Moving-average FIR low-pass filters (the receiver bandwidth filter and QSB filter). |
| `src/VolumCtl.pas` | AGC (look-ahead, attack/hold, log-domain envelope). |
| `src/Crc32.pas`    | CRC-32 used to sign the WPX score string. |

Sample rate is **11025 Hz** (`Ini.DEFAULTRATE`); one processing *block* is
`BufSize` samples (default 512). `SecondsToBlocks`/`BlocksToSeconds` tie the sim
clock to real time.

---

## 3. The ported (platform) layer — this is where edits belong

Everything Windows-specific was replaced with a cross-platform equivalent. These
files are the port and are safe to modify:

| File | Replaces | Notes |
|------|----------|-------|
| `src/platform/PortAudio.pas` | — | Minimal FPC binding to `libportaudio` v19 (only the ~8 calls we use). |
| `src/platform/SndOut.pas` | `SndCustm.pas` + `SndOut.pas` (Windows `waveOut`/MMSystem) | `TAlSoundOut` with the **same public interface** (`Enabled`, `BufCount`, `SamplesPerSec`, `OnBufAvailable`, `PutData`, `Purge`). A lock-protected ring buffer sits between the main thread (producer, `PutData`) and the PortAudio callback (consumer). A `TTimer` refills the ring to `BufCount` blocks, firing `OnBufAvailable`; because the callback drains in real time, `Tst.GetAudio` (which touches the GUI) is still called **on the main thread at real-time rate**, exactly like the original waveOut buffer-done model. |
| `src/platform/WavFile.pas` | `WavFile.pas` (mmio) | `TAlWavFile` write-only mono 16-bit PCM WAV via `TFileStream`; identical on-disk format. |
| `src/VolmSldr.pas` | `VolmSldr.pas` + `PermHint.pas` | `TVolumeSlider` self-monitor slider redrawn with portable `TCanvas` primitives; dB math and 0.75 default unchanged. The custom floating hint window is replaced by the standard LCL tooltip. |
| `src/Main.pas` + `src/Main.lfm` | `Main.pas` + `Main.dfm` (VCL) | Line-for-line event-handler port; `uses` swapped to LCL; `ShellExecute`→`OpenURL`/`OpenDocument`; `RichEdit`→`TMemo`; toolbutton `WM_TBDOWN` trick → direct assignment; score `ListView` rows built in code. |
| `src/ScoreDlg.pas` + `src/ScoreDlg.lfm` | `ScoreDlg.pas` + `ScoreDlg.dfm` | "Contest is over" dialog. |
| `MorseRunner.lpr` / `MorseRunner.lpi` | `MorseRunner.dpr` | Lazarus program + project. |

### SDR-server add-on (optional)

MorseRunner can also present its pileup as a live **HPSDR network SDR** so a CW
Skimmer (SkimServerMac) can decode it, plus a timestamped **ground-truth** feed
for scoring. Fully isolated from the simulation; off unless toggled via
**File → SDR Server**. See **[docs/SDR_SERVER.md](docs/SDR_SERVER.md)**.

| File | Role |
|------|------|
| `src/platform/HpsdrDevice.pas` | HPSDR Protocol-1 device emulator (UDP :1024): discovery, EP2/start, EP6 IQ framing, 11025→rate resampler |
| `src/platform/TruthServer.pas` | ground-truth TCP/JSON feed (:7355) with replay-on-connect |
| `src/platform/SdrIntf.pas` | facade the sim/GUI call (`SdrStart/Stop/PushIq/Truth`) |
| taps | one guarded line each in `Contest.GetAudio` (IQ) and `DxStn.CreateStation` (truth) — no-ops unless the server runs |
| `tools/hpsdr_client.py` | reference client mirroring SkimServerMac's HPSDR parse; verifies discovery + IQ + truth |

### Control / automation API (optional)

An embedded **HTTP+JSON** endpoint (**File → Test Control API**, `:7300`) lets a
test app drive MorseRunner: `POST /scenario` runs a Pile-Up/Single/… for N
seconds and returns every generated callsign with timestamps; `POST /command`
invokes any UI action; `GET /state|/calls`. See
**[docs/CONTROL_API.md](docs/CONTROL_API.md)**.

| File | Role |
|------|------|
| `src/platform/ControlApi.pas` | `TFPHTTPServer` + in-memory call log + main-thread dispatch (`TThread.Synchronize`) |
| `Main.ApiDispatch` | maps action names → the same ops the UI uses; registered via `ApiRegisterDispatch` |
| hook | `DxStn.CreateStation` → `ApiRecordCall` (records + forwards to the SDR truth feed); `Main.Run` resets the log at run start |
| `tools/api_client.py` | reference client (`POST /scenario` → calls) |

`BaseComp.pas`, `SndCustm.pas`, `PermHint.pas`, and the VCL volume/wav components
from the original are **not used** in the port (the Windows originals are kept
under `_original_reference/` for comparison only).

---

## 4. Build & run (macOS, Apple Silicon or Intel)

### Prerequisites
```bash
brew install fpc portaudio           # compiler + audio library
```
The Lazarus **LCL** is needed for widgets. The Homebrew `lazarus` cask needs
`sudo`; to stay non-interactive this repo builds `lazbuild` from source instead:
```bash
git clone --depth 1 -b lazarus_3_6 https://gitlab.com/freepascal.org/lazarus/lazarus.git ../lazarus-src
cd ../lazarus-src && make lazbuild PP="$(which fpc)"
```

### Build
```bash
LAZ=../lazarus-src
"$LAZ/lazbuild" --lazarusdir="$LAZ" --ws=cocoa MorseRunner.lpi
```
The first build also compiles the LCL cocoa widgetset (several minutes); later
builds are fast. Output binary: `./MorseRunner` (and a `MorseRunner.app` bundle
when built with `UseAppBundle`). Or just run **`./build.sh`**, which wraps the
above and copies the real binary into the bundle.

**Linker note:** the `.lpi` passes `-k-ld_classic`. FPC 3.2.2 emits Objective-C
method-list metadata that the modern Xcode linker (`ld-prime`) rejects with
`malformed method list atom`; the classic linker handles it. Remove this once on
a toolchain where the default linker is fixed. The `.lpi` also adds
`-Fl/opt/homebrew/lib` so the PortAudio dylib is found, and `PortAudio.pas` has
`{$LINKLIB portaudio}`.

### Run
```bash
./MorseRunner
```

### Deploy to /Applications
```bash
./deploy.sh
```
`deploy.sh` embeds `libportaudio` into `MorseRunner.app/Contents/Frameworks`,
rewrites its load path to `@executable_path/../Frameworks/…` (so the installed
app does not depend on the Homebrew prefix), copies `readme.txt` next to the
executable, ad-hoc code-signs the bundle (prevents Gatekeeper app-translocation),
and copies it to `/Applications`.

**App icon.** `assets/gen_icon.py` renders `assets/icon_master.png` (a Morse-`CQ`
tile); `assets/MorseRunner.icns` is built from it with `sips`+`iconutil`.
`build.sh` copies the `.icns` into `Contents/Resources/` and sets
`CFBundleIconFile`, so every build carries the icon. To restyle, edit the script
and rebuild the `.icns` (see the commands in `assets/` history or re-run
`gen_icon.py` then `iconutil -c icns`).

**Writable files.** Because `/Applications/MorseRunner.app/Contents/MacOS/` is
read-only, the port stores its `MorseRunner.ini`, `.wav`, `.lst`, and
`HstResults.txt` under `~/.config/Morse Runner/` (via `Ini.AppFile` /
`GetAppConfigDir`). The Windows original kept them next to the `.exe`; that path
is read-only and Gatekeeper-translocated on macOS, so this redirection is
required for a working install. `Master.dta`/`readme.txt` are still read from
next to the executable (inside the bundle).

### Data file (callsign database)
`Master.dta` (the supercheck-partial call database) is **not** in the original
repo and is loaded from the executable's directory at startup. Without it,
`PickCall` falls back to the single call `P29SX` (exactly the original's
behavior). Drop a `Master.dta` next to the binary for a realistic pileup.

---

## 5. How the simulation works (behavioral reference)

**Run modes** (`TRunMode` in `Ini.pas`): `rmPileup`, `rmSingle`, `rmWpx`,
`rmHst`, `rmStop`. Start via the Run button/menu; **F1 / Enter sends CQ**.

**Audio pipeline per block** (`Contest.GetAudio`): complex white noise →
(optional QRN background specks + bursts) → (optional QRM station) → sum of each
sending station's Morse envelope mixed by its BFO offset (with RIT phase) →
optional self-monitor of your own sending (QSK full-break-in ducking) → two
swapped moving-average low-pass filters (receiver bandwidth) → modulate up to the
CW pitch → AGC → optional WAV record.

**DX operator state machine** (`DxOper.MsgReceived` / `GetReply`): each caller
has `Skills` (1–3), `Patience`, and progresses `osNeedQso → osNeedNr → osNeedEnd
→ osDone`, or fails. `IsMyCall` is a weighted edit-distance match (handles `?`
wildcards, partial calls, and LID mistakes). LIDs (when enabled) call out of
turn, send wrong RST/NR, and mis-copy your call.

**Scoring** (`Log.pas`): WPX = QSOs × distinct-prefix multiplier, shown Raw and
Verified (Verified compares your log to the DX stations' truth: `DUP`/`NIL`/`RST`/`NR`
markers). HST = sum of per-call "dit/dah" scores. Prefix extraction follows WPX
rules (`ExtractPrefix`).

**Keyboard** (from the original readme, preserved): F1–F8 = canned messages;
`\`=F1; `Esc`=abort; `Space`=advance field/auto-complete; `Ins`/`;` = his-call +
number; `+ . , [` = TU + log; `Enter` = context send / save; Up/Down = RIT;
Ctrl+Up/Down = bandwidth; PgUp/PgDn = WPM ±5.

---

## 6. Known deviations from the Windows original (all cosmetic)

1. **Log colors.** The original `TRichEdit` underlined the header and colored the
   `Chk` column red. The port uses a monospaced `TMemo`; **all log text/columns
   are identical**, only the color is gone (LCL has no RichEdit without the extra
   `richmemo` package). Reintroduce by swapping `RichEdit1` to `TRichMemo`.
2. **Self-monitor slider** is redrawn with canvas primitives and uses the normal
   tooltip instead of a floating always-on hint window. Values/behavior identical.
3. **Invalid-QSO beep.** LCL has no portable `Beep`; the invalid-save still just
   refuses to log (no sound). See `Log.SaveQso`.
4. **App/toolbar icons** and the "Run" toolbutton image (Windows resource blobs)
   were dropped from the `.lfm`; layout and captions are unchanged.
5. Pixel positions/fonts come straight from the Windows `.dfm` (96-DPI MS Sans
   Serif); on macOS the widgets are substituted and may be a few px off but fully
   functional.

Nothing above affects the audio, the callers' behavior, timing, or scoring.

---

## 7. Repo map

```
MorseRunner.lpr / .lpi     Lazarus program + project (build entry point)
CLAUDE.md                  this file
src/                       frozen simulation/DSP units (see §2) + ported GUI (Main, ScoreDlg, VolmSldr)
src/platform/              PortAudio binding, SndOut (audio), WavFile
_original_reference/       pristine copy of VE3NEA's Windows sources (do not build; compare against)
lib/<cpu>-<os>/            compiler output (generated)
```

## 8. Gotchas for future edits

- **64-bit.** The original nilled dynamic arrays with `Integer(Result) := 0`,
  which is unsafe on 64-bit; the port uses `Result := nil` (in `Mixers.pas`).
  Watch for similar pointer/integer casts if pulling in more original code.
- **Threading.** `Tst.GetAudio` mutates the GUI — it must run on the main thread.
  Keep it out of the PortAudio callback (the callback only copies PCM out of the
  ring buffer). See `src/platform/SndOut.pas`.
- **Sample rate is 11025 Hz**, not 48000. `TAlSoundOut.SamplesPerSec` is set from
  the `.lfm` (`11025`); `TAlWavFile` defaults to the same.
- Keep `{$MODE Delphi}` on any original unit you add so its Delphi-isms compile
  under FPC.
```
