# Morse Runner — macOS port

A native macOS port of **Morse Runner 1.68**, the CW contest simulator by
**Alex Shovkoplyas, VE3NEA** (<https://www.dxatlas.com/MorseRunner/>,
source <https://github.com/VE3NEA/MorseRunner>, MPL-2.0).

The port recompiles VE3NEA's original **Object Pascal** with **Free Pascal +
Lazarus (LCL)** so the contest simulation, DSP and scoring are byte-for-byte the
same as the Windows version. Only the platform edges were replaced:

* **Audio** — Windows `waveOut`/MMSystem → **PortAudio** (CoreAudio).
* **WAV recording** — Windows `mmio` → a portable `TFileStream` writer.
* **GUI** — VCL forms (`.dfm`) → LCL forms (`.lfm`); Cocoa widgetset.

See **[CLAUDE.md](CLAUDE.md)** for the full architecture, the list of frozen
simulation units, behavioral reference, and known (cosmetic-only) deviations.

## Quick start

```bash
# 1. Toolchain
brew install fpc portaudio

# 2. Lazarus LCL / lazbuild (built from source; no sudo needed)
git clone --depth 1 -b lazarus_3_6 \
    https://gitlab.com/freepascal.org/lazarus/lazarus.git ../lazarus-src
( cd ../lazarus-src && make lazbuild PP="$(which fpc)" )

# 3. Build Morse Runner
./build.sh

# 4. Run
open MorseRunner.app
```

For a realistic pileup with diverse callsigns, load a `Master.dta`
supercheck-partial call database via **File → Import Master.dta…** (it is copied
to `~/.config/Morse Runner/` and reloaded immediately). Without it the app falls
back to a single call, exactly as the original does.

## Status

Builds to a native arm64 (or x86-64) `.app`. Verified end-to-end on macOS 26:
the form loads, a Pile-Up run renders correct 11025 Hz CW audio through the
ported pipeline in real time, WAV recording produces a valid file, and settings
persist via `MorseRunner.ini`.

## License

Mozilla Public License 2.0 (same as the original). See `LICENSE`.
