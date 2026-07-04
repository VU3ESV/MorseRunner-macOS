# MorseRunner (macOS) v0.1.3

**New in v0.1.3:** **Settings → Mute Local Audio** — silence the Mac speakers
while a run keeps generating IQ + ground truth (ideal when driving MorseRunner as
a test SDR source; also settable via the control API `muteLocal` field).


A native macOS port of **Morse Runner 1.68** (the CW contest simulator by Alex
Shovkoplyas, VE3NEA), recompiled from the original Object Pascal with Free
Pascal + Lazarus (LCL/Cocoa) so the contest simulation, DSP and scoring are
identical to the Windows original. Adds two integrations for CW-decoder testing:

- **HPSDR SDR-server** — MorseRunner presents its pileup as a live network SDR
  (HPSDR Protocol 1, UDP :1024) so a CW Skimmer (e.g. SkimServerMac) can decode
  it, plus a streaming ground-truth feed (TCP :7355). See `docs/SDR_SERVER.md`.
- **Control / automation API** — an HTTP+JSON endpoint (:7300): `POST /scenario`
  runs a Pile-Up/Single/… and returns every generated callsign with timestamps;
  `POST /command` invokes any UI action. See `docs/CONTROL_API.md`.

## Download & install

1. Download **`MorseRunner-macos-arm64.dmg`** below and open it.
2. In the window that appears, **drag `MorseRunner.app` onto the `Applications`
   folder**.
3. Eject the disk image.

(A plain `.zip` of the app is also attached if you prefer.)

**Apple Silicon only** (arm64). PortAudio is bundled inside the app — no Homebrew
needed on the target Mac.

## ⚠️ Running on another Mac — clear the quarantine flag

This build is **ad-hoc code-signed but NOT notarized**. When you download the zip
on a *different* Mac, macOS attaches a `com.apple.quarantine` attribute and
Gatekeeper will refuse to open it ("MorseRunner is damaged / cannot be opened
because Apple cannot check it for malicious software"). Remove the quarantine
attribute once, then it opens normally:

```bash
# after moving the app into /Applications (adjust the path if elsewhere)
xattr -dr com.apple.quarantine /Applications/MorseRunner.app
open /Applications/MorseRunner.app
```

- `-d` deletes the attribute, `-r` recurses into the bundle.
- To inspect first: `xattr -r /Applications/MorseRunner.app` (look for
  `com.apple.quarantine`).
- Alternative (no Terminal): **right-click the app → Open**, then confirm **Open**
  in the dialog — this whitelists that specific copy.

The Mac where the app was *built* doesn't need this (local builds aren't
quarantined).

## Using it

- Launch, press **F1 / Enter** to send CQ and start a pileup.
- **File → SDR Server (HPSDR :1024)** to stream IQ to a CW Skimmer.
- **File → Test Control API (:7300)** to drive it from a test app.
- For a realistic pileup with diverse callsigns, load a `Master.dta`
  supercheck-partial file via **File → Import Master.dta…** (copied to
  `~/.config/Morse Runner/`); without it every caller is `P29SX`.

## Build from source

`brew install fpc portaudio`, build `lazbuild` from Lazarus 3.6, then `./build.sh`
(local run) or `./package.sh` (produces the distributable zip). See `CLAUDE.md §4`.
CI builds every push and attaches the artifact to tagged releases
(`.github/workflows/build.yml`).

## Known deviations from the Windows original (cosmetic only)

Log text keeps the DUP/NIL/RST/NR markers but not RichEdit colour; the self-mon
slider uses the standard tooltip; no invalid-save beep. None affect audio, timing
or scoring. Details in `CLAUDE.md §6`.
