//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// HPSDR "Protocol 1" (Metis/Hermes) receiver EMULATOR — macOS port add-on.
//
// Makes MorseRunner look like a network SDR on UDP :1024 so a CW Skimmer can
// tune it and decode the live pileup. Implements exactly the subset that
// SkimServerMac's HPSDRConnection/HPSDRDiscovery drive:
//   * Discovery:  reply to  EF FE 02        with  EF FE 02 + MAC + FW + boardID
//   * Start/stop: EF FE 04 01 / 00, and EP2 config frames EF FE 01 02 (C1 = rate)
//   * IQ data:    EF FE 01 06 + seq(4) + two 512-byte Ozy buffers; per group
//                 [I(3) Q(3) mic(2)], 24-bit big-endian signed, /8388607.
//
// The pileup arrives as an 11025 Hz complex baseband (PushIq, from the main
// thread) and is fractionally resampled up to the rate the host requested
// (48/96/192/384 kHz) before framing. Input-paced: we only emit as much IQ as
// the simulation produces in real time, so the stream runs at true real time.
//------------------------------------------------------------------------------
unit HpsdrDevice;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, Classes, SyncObjs, SndTypes;

type
  THpsdrDevice = class
  private
    FPort: word;
    FSock: longint;
    FThread: TThread;
    FTerminating: boolean;
    FLock: TCriticalSection;

    // IQ input ring (normalized complex, 11025 Hz)
    FRingRe, FRingIm: array of Single;
    FCap, FHead, FTail, FCount: integer;

    // streaming state (device thread)
    FStreaming: boolean;
    FRate: integer;
    FHaveHost: boolean;
    FFramesSent: int64;
    FPeak: Single;          // pre-limit peak magnitude of the last block (diag)

    procedure ThreadRun;
  public
    constructor Create(APort: word);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure PushIq(const Re, Im: TSingleArray; N: integer);
    function StatusText: string;
  end;

implementation

uses
  ctypes, BaseUnix, Sockets, Math;

const
  // BSD/darwin socket constants (hard-coded — target is macOS)
  MR_AF_INET     = 2;
  MR_SOCK_DGRAM  = 2;
  MR_SOL_SOCKET  = $FFFF;
  MR_SO_REUSEADDR= $0004;
  MR_SO_RCVTIMEO = $1006;

  // Raw MorseRunner complex -> normalized [-1,1]. Chosen so the steady pileup +
  // noise floor sit well below full scale (noise ~-30 dBFS, a caller ~-21 dBFS,
  // a dense pileup ~-7 dBFS) with headroom for QRN. Combined with the magnitude
  // soft-limiter in PushIq this keeps a narrowband pileup from hard-clipping —
  // hard-clipping an impulse splatters broadband and smears the pileup across
  // the whole span (the bug: peak pinned at 1.0, energy spread, garbage decode).
  IQ_SCALE   = 400000.0;
  DEFRATE    = 48000;
  INRATE     = 11025;
  RING_CAP   = 1 shl 16;
  GROUPS_PER_OZY = 63;       // N=1: 504 / (6+2)
  SAMPS_PER_FRAME = 126;     // 2 ozy * 63 groups

type
  TSockAddrIn = packed record   // darwin sockaddr_in, filled byte-exact
    sin_len: byte;
    sin_family: byte;
    sin_port: word;             // network order
    sin_addr: cardinal;         // network order
    sin_zero: array[0..7] of byte;
  end;

  TMRTimeVal = record           // darwin struct timeval (16 bytes)
    tv_sec: Int64;
    tv_usec: Int32;
  end;

  THpsdrThread = class(TThread)
  private
    FDev: THpsdrDevice;
  protected
    procedure Execute; override;
  public
    constructor Create(ADev: THpsdrDevice);
  end;


function htons16(v: word): word; inline;
begin
  Result := ((v shr 8) or (v shl 8)) and $FFFF;
end;


{ THpsdrDevice }

constructor THpsdrDevice.Create(APort: word);
begin
  inherited Create;
  FPort := APort;
  FSock := -1;
  FRate := DEFRATE;
  FLock := TCriticalSection.Create;
  FCap := RING_CAP;
  SetLength(FRingRe, FCap);
  SetLength(FRingIm, FCap);
end;


destructor THpsdrDevice.Destroy;
begin
  Stop;
  FLock.Free;
  inherited;
end;


procedure THpsdrDevice.Start;
var
  addr: TSockAddrIn;
  one: cint;
  tv: TMRTimeVal;
begin
  FSock := fpSocket(MR_AF_INET, MR_SOCK_DGRAM, 0);
  if FSock < 0 then
    raise ESoundError.Create('HPSDR: socket() failed');

  one := 1;
  fpSetSockOpt(FSock, MR_SOL_SOCKET, MR_SO_REUSEADDR, @one, sizeof(one));
  tv.tv_sec := 0; tv.tv_usec := 5000;   // 5 ms recv timeout -> ~200 Hz send tick
  fpSetSockOpt(FSock, MR_SOL_SOCKET, MR_SO_RCVTIMEO, @tv, sizeof(tv));

  FillChar(addr, sizeof(addr), 0);
  addr.sin_len := sizeof(addr);
  addr.sin_family := MR_AF_INET;
  addr.sin_port := htons16(FPort);
  addr.sin_addr := 0;                    // INADDR_ANY
  if fpBind(FSock, psockaddr(@addr), sizeof(addr)) < 0 then
    raise ESoundError.CreateFmt('HPSDR: bind(:%d) failed', [FPort]);

  FThread := THpsdrThread.Create(Self);
end;


procedure THpsdrDevice.Stop;
begin
  FTerminating := true;              // ThreadRun exits within one recv timeout (5 ms)
  if FThread <> nil then
    begin
    FThread.WaitFor;
    FreeAndNil(FThread);
    end;
  if FSock >= 0 then begin CloseSocket(FSock); FSock := -1; end;
end;


procedure THpsdrDevice.PushIq(const Re, Im: TSingleArray; N: integer);
var
  i: integer;
  vr, vi, mag, g, blockPeak: Single;
begin
  blockPeak := 0;
  FLock.Enter;
  try
    for i := 0 to N-1 do
      begin
      if FCount >= FCap then Break;      // ring full: drop
      vr := Re[i] / IQ_SCALE;
      vi := Im[i] / IQ_SCALE;

      // phase-preserving soft limiter: compress the complex MAGNITUDE with tanh
      // (not each channel independently — that would distort the quadrature).
      // Near-linear for the steady signal; QRN impulses saturate smoothly at 1
      // instead of hard-clipping and splattering across the band.
      mag := Sqrt(vr*vr + vi*vi);
      if mag > blockPeak then blockPeak := mag;
      if mag > 1e-9 then
        begin
        g := Tanh(mag) / mag;
        vr := vr * g;
        vi := vi * g;
        end;

      FRingRe[FTail] := vr;
      FRingIm[FTail] := vi;
      FTail := (FTail + 1) mod FCap;
      Inc(FCount);
      end;
  finally
    FLock.Leave;
  end;
  FPeak := blockPeak;                     // >1 means the limiter is engaging
end;


function THpsdrDevice.StatusText: string;
begin
  if FStreaming then
    Result := Format('HPSDR streaming %d kHz, %d frames, peak %.2f',
      [FRate div 1000, FFramesSent, FPeak])
  else
    Result := 'HPSDR idle (waiting for skimmer)';
end;


//------------------------------------------------------------------------------
//                              device thread
//------------------------------------------------------------------------------
constructor THpsdrThread.Create(ADev: THpsdrDevice);
begin
  FDev := ADev;
  inherited Create(False);
end;

procedure THpsdrThread.Execute;
begin
  FDev.ThreadRun;
end;


procedure THpsdrDevice.ThreadRun;
var
  rbuf: array[0..2047] of byte;
  host: TSockAddrIn;
  from: TSockAddrIn;
  fromlen: tsocklen;
  n: ssize_t;
  seq: cardinal;
  // resampler
  frac, step: double;
  prevRe, prevIm: Single;
  havePrev: boolean;
  // frame accumulation
  outI, outQ: array[0..SAMPS_PER_FRAME-1] of Single;
  outN: integer;

  procedure SendDiscoveryReply(const dst: TSockAddrIn);
  var
    reply: array[0..59] of byte;
  begin
    FillChar(reply, sizeof(reply), 0);
    reply[0] := $EF; reply[1] := $FE; reply[2] := $02;
    // MAC 00:1C:C0:A2:13:7D (a plausible Metis-range MAC)
    reply[3] := $00; reply[4] := $1C; reply[5] := $C0;
    reply[6] := $A2; reply[7] := $13; reply[8] := $7D;
    reply[9] := 33;          // firmware version
    reply[10] := $01;        // board id: 1 = Hermes
    fpSendTo(FSock, @reply, sizeof(reply), 0, psockaddr(@dst), sizeof(dst));
  end;

  procedure Write24BE(var buf: array of byte; pos: integer; v: Single);
  var
    iv: integer;
  begin
    iv := Round(v * 8388607);
    if iv > 8388607 then iv := 8388607
    else if iv < -8388607 then iv := -8388607;
    buf[pos]   := (iv shr 16) and $FF;
    buf[pos+1] := (iv shr 8) and $FF;
    buf[pos+2] := iv and $FF;
  end;

  procedure EmitFrame;
  var
    frame: array[0..1031] of byte;
    o, g, si, p: integer;
  begin
    FillChar(frame, sizeof(frame), 0);
    frame[0] := $EF; frame[1] := $FE; frame[2] := $01; frame[3] := $06;
    frame[4] := (seq shr 24) and $FF;
    frame[5] := (seq shr 16) and $FF;
    frame[6] := (seq shr 8) and $FF;
    frame[7] := seq and $FF;
    Inc(seq);
    // two Ozy buffers at offsets 8 and 520
    for o := 0 to 1 do
      begin
      frame[8 + o*512]     := $7F;
      frame[8 + o*512 + 1] := $7F;
      frame[8 + o*512 + 2] := $7F;
      // C0..C4 (5 status bytes) left 0
      p := 8 + o*512 + 8;                        // payload start
      for g := 0 to GROUPS_PER_OZY-1 do
        begin
        si := o*GROUPS_PER_OZY + g;
        Write24BE(frame, p, outI[si]);
        Write24BE(frame, p+3, outQ[si]);
        // mic bytes p+6,p+7 = 0
        Inc(p, 8);
        end;
      end;
    fpSendTo(FSock, @frame, sizeof(frame), 0, psockaddr(@host), sizeof(host));
    Inc(FFramesSent);
  end;

  procedure PushOut(re, im: Single);
  begin
    outI[outN] := re; outQ[outN] := im; Inc(outN);
    if outN = SAMPS_PER_FRAME then begin EmitFrame; outN := 0; end;
  end;

  procedure ResampleAvailable;
  var
    lre, lim: array[0..4095] of Single;
    avail, i: integer;
    curRe, curIm: Single;
  begin
    FLock.Enter;
    try
      avail := FCount;
      if avail > 4096 then avail := 4096;
      for i := 0 to avail-1 do
        begin
        lre[i] := FRingRe[FHead]; lim[i] := FRingIm[FHead];
        FHead := (FHead + 1) mod FCap;
        end;
      Dec(FCount, avail);
    finally
      FLock.Leave;
    end;

    for i := 0 to avail-1 do
      begin
      curRe := lre[i]; curIm := lim[i];
      if not havePrev then begin prevRe := curRe; prevIm := curIm; havePrev := true; end;
      // emit output samples that fall in [prev, cur)
      while frac < 1.0 do
        begin
        PushOut(prevRe + (curRe-prevRe)*frac, prevIm + (curIm-prevIm)*frac);
        frac := frac + step;
        end;
      frac := frac - 1.0;
      prevRe := curRe; prevIm := curIm;
      end;
  end;

begin
  seq := 0;
  frac := 0; havePrev := false; outN := 0;
  step := INRATE / FRate;
  FillChar(host, sizeof(host), 0);

  while not FTerminating do
    begin
    fromlen := sizeof(from);
    n := fpRecvFrom(FSock, @rbuf, sizeof(rbuf), 0, psockaddr(@from), @fromlen);

    if n >= 3 then
      if (rbuf[0] = $EF) and (rbuf[1] = $FE) then
        case rbuf[2] of
          $02: SendDiscoveryReply(from);           // discovery
          $04:
            begin                                   // start/stop
            host := from; FHaveHost := true;
            FStreaming := (n >= 4) and ((rbuf[3] and 1) <> 0);
            end;
          $01:
            if (n >= 13) and (rbuf[3] = $02) then   // EP2 config frame
              begin
              host := from; FHaveHost := true;
              FStreaming := true;
              // C1 speed bits at frame[12] -> sample rate
              case rbuf[12] and 3 of
                0: FRate := 48000;
                1: FRate := 96000;
                2: FRate := 192000;
                3: FRate := 384000;
              end;
              step := INRATE / FRate;
              end;
        end;

    if FStreaming and FHaveHost then
      ResampleAvailable
    else
      begin
      // drain stale input so we don't backlog while idle
      FLock.Enter; try FHead := FTail; FCount := 0; finally FLock.Leave; end;
      end;
    end;
end;


end.
