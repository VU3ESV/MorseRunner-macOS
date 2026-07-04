#!/usr/bin/env python3
# Mimics SkimServerMac's HPSDRConnection: discover MorseRunner as an HPSDR
# device, start streaming (EP2 config, C1=0 -> 48 kHz), receive EP6 IQ frames,
# parse 24-bit big-endian I/Q, and report frames/samples/energy + a coarse
# spectrum peak. Also reads the ground-truth TCP feed.
import socket, struct, threading, time, math, sys

DEV = ("127.0.0.1", 1024)

def s24(b):  # 24-bit big-endian signed -> int
    v = (b[0] << 16) | (b[1] << 8) | b[2]
    return v - (1 << 24) if v & 0x800000 else v

# ---- UDP: discovery + start + receive -------------------------------------
u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
u.bind(("0.0.0.0", 0))
u.settimeout(2.0)

# discovery: EF FE 02 padded to 63 bytes
disc = bytes([0xEF, 0xFE, 0x02]) + bytes(60)
u.sendto(disc, DEV)
try:
    data, src = u.recvfrom(1500)
    ok = len(data) >= 60 and data[0] == 0xEF and data[1] == 0xFE and data[2] == 0x02
    mac = ":".join("%02X" % x for x in data[3:9])
    print(f"DISCOVERY: {'OK' if ok else 'BAD'} reply {len(data)}B from {src}  MAC={mac} FW={data[9]} board={data[10]}")
except socket.timeout:
    print("DISCOVERY: no reply (device not running?)"); sys.exit(1)

# start: EF FE 04 01, then EP2 config frames (C1=0 -> 48k) like the real client
u.sendto(bytes([0xEF, 0xFE, 0x04, 0x01]) + bytes(60), DEV)

stop = threading.Event()
def ep2_loop():
    seq = 0
    while not stop.is_set():
        f = bytearray(1032)
        f[0], f[1], f[2], f[3] = 0xEF, 0xFE, 0x01, 0x02
        struct.pack_into(">I", f, 4, seq); seq += 1
        f[8] = f[9] = f[10] = 0x7F
        f[11] = 0x00           # C0 addr 0
        f[12] = 0x00           # C1 speed = 48k
        f[15] = 0x00           # C4 rxcount-1=0
        f[520] = f[521] = f[522] = 0x7F
        u.sendto(bytes(f), DEV)
        time.sleep(0.01)
threading.Thread(target=ep2_loop, daemon=True).start()

# receive EP6 frames for a while
I = []; Q = []
frames = 0
t_end = time.time() + 8.0
u.settimeout(1.0)
while time.time() < t_end:
    try:
        data, _ = u.recvfrom(2048)
    except socket.timeout:
        continue
    if len(data) != 1032 or data[0] != 0xEF or data[1] != 0xFE or data[2] != 0x01 or data[3] != 0x06:
        continue
    frames += 1
    for off in (8, 520):
        if data[off] != 0x7F: continue
        p = off + 8
        for g in range(63):
            I.append(s24(data[p:p+3]) / 8388607.0)
            Q.append(s24(data[p+3:p+6]) / 8388607.0)
            p += 8
stop.set()

n = len(I)
if n == 0:
    print("IQ: NO frames received"); sys.exit(1)
peak = max(max(abs(x) for x in I), max(abs(x) for x in Q))
rms = math.sqrt(sum(i*i + q*q for i, q in zip(I, Q)) / n)
# coarse magnitude spectrum (DFT on a 4096 window) to find dominant offset Hz
W = min(4096, n)
mags = []
for k in range(-40, 41):        # ±~470 Hz around center at 48k/4096≈11.7 Hz/bin
    re = im = 0.0
    for t in range(W):
        ph = -2*math.pi*k*t/4096
        re += I[t]*math.cos(ph) - Q[t]*math.sin(ph)
        im += I[t]*math.sin(ph) + Q[t]*math.cos(ph)
    mags.append((math.hypot(re, im), k*48000/4096))
mags.sort(reverse=True)
print(f"IQ: {frames} EP6 frames, {n} samples ({n/48000:.2f}s @48k)  peak={peak:.3f} rms={rms:.4f}")
print(f"IQ: top spectral offsets (Hz): " + ", ".join(f"{hz:+.0f}({m:.1f})" for m, hz in mags[:5]))
print("IQ: VERDICT:", "REAL pileup IQ streaming" if rms > 1e-3 else "silent/zero")

# ---- TCP: ground-truth feed ------------------------------------------------
print("\nGROUND TRUTH (127.0.0.1:7355):")
try:
    t = socket.create_connection(("127.0.0.1", 7355), timeout=2.0)
    t.settimeout(3.0)
    buf = b""; lines = 0
    t0 = time.time()
    while time.time() - t0 < 3.0 and lines < 12:
        try: chunk = t.recv(4096)
        except socket.timeout: break
        if not chunk: break
        buf += chunk
        while b"\n" in buf and lines < 12:
            line, buf = buf.split(b"\n", 1)
            print("  " + line.decode(errors="replace")); lines += 1
    t.close()
    if lines == 0: print("  (connected, no events yet — callers may not have keyed)")
except OSError as e:
    print(f"  connect failed: {e}")
