//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// macOS/Lazarus port of SndCustm.pas + SndOut.pas.
//
// The original used the Windows waveOut API: it queued N (BufCount) PCM buffers
// to the sound card and, each time the card finished one, a worker thread posted
// an event that fired OnBufAvailable on the main thread; the handler responded
// with PutData(Tst.GetAudio) to render and queue the next block.  Because the
// card consumes buffers in real time, the simulation clock (Contest.BlockNumber)
// advanced at real time.
//
// This unit reproduces that contract exactly on top of PortAudio:
//   * A lock-protected ring buffer of 16-bit samples sits between the producer
//     (main thread, PutData) and the consumer (PortAudio's audio callback).
//   * A TTimer on the main thread keeps the ring topped up to BufCount blocks by
//     firing OnBufAvailable; since the callback drains the ring in real time, the
//     top-up — and therefore Tst.GetAudio and all the GUI work it does — happens
//     at real time, one block at a time, just like the waveOut version.
//
// The public interface (Enabled, BufCount, SamplesPerSec, OnBufAvailable,
// PutData, Purge) matches the original TAlSoundOut so Main.pas is unchanged.
//------------------------------------------------------------------------------
unit SndOut;

{$MODE Delphi}

interface

uses
  SysUtils, Classes, ExtCtrls, SyncObjs, ctypes, SndTypes, PortAudio;

type
  TAlSoundOut = class(TComponent)
  private
    FEnabled: boolean;
    FBufCount: LongWord;
    FSamplesPerSec: LongWord;
    FOnBufAvailable: TNotifyEvent;
    FCloseWhenDone: boolean;

    FStream: PPaStream;
    FPaReady: boolean;

    // ring buffer (SmallInt samples)
    FRing: array of SmallInt;
    FCap, FHead, FTail, FCount: integer;
    FMaxBlock: integer;
    FLock: TCriticalSection;

    // main-thread pump
    FTimer: TTimer;
    FBufsAdded: LongWord;
    FBufsDone: LongWord;

    procedure SetEnabled(AEnabled: boolean);
    procedure SetSamplesPerSec(const Value: LongWord);
    procedure SetBufCount(const Value: LongWord);
    procedure DoStart;
    procedure DoStop;
    procedure OnTimer(Sender: TObject);
    procedure Pump;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function PutData(Data: TSingleArray): boolean;
    procedure Purge;
    // called on the PortAudio thread; copies up to ACount samples out of the ring
    procedure ConsumeInto(Dest: PSmallInt; ACount: integer);
  published
    // NOTE: these must be *published* so the .lfm form streamer can read them
    // (the original TAlSoundOut published the same set).
    property Enabled: boolean read FEnabled write SetEnabled default false;
    property SamplesPerSec: LongWord read FSamplesPerSec write SetSamplesPerSec default 48000;
    property BufCount: LongWord read FBufCount write SetBufCount;
    property BufsAdded: LongWord read FBufsAdded;
    property BufsDone: LongWord read FBufsDone;
    property CloseWhenDone: boolean read FCloseWhenDone write FCloseWhenDone default false;
    property OnBufAvailable: TNotifyEvent read FOnBufAvailable write FOnBufAvailable;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Al', [TAlSoundOut]);
end;


//------------------------------------------------------------------------------
//                        PortAudio callback (audio thread)
//------------------------------------------------------------------------------
function PaCallback(input: pointer; output: pointer; frameCount: culong;
  timeInfo: PPaStreamCallbackTimeInfo; statusFlags: PaStreamCallbackFlags;
  userData: pointer): cint32; cdecl;
begin
  TAlSoundOut(userData).ConsumeInto(PSmallInt(output), integer(frameCount));
  Result := paContinue;
end;


//------------------------------------------------------------------------------
//                                 system
//------------------------------------------------------------------------------
constructor TAlSoundOut.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBufCount := 8;
  FSamplesPerSec := 48000;
  FLock := TCriticalSection.Create;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := false;
  FTimer.Interval := 5;
  FTimer.OnTimer := OnTimer;
end;


destructor TAlSoundOut.Destroy;
begin
  Enabled := false;
  FLock.Free;
  inherited;
end;


procedure TAlSoundOut.SetSamplesPerSec(const Value: LongWord);
begin
  Enabled := false;
  FSamplesPerSec := Value;
end;


procedure TAlSoundOut.SetBufCount(const Value: LongWord);
begin
  if FEnabled then
    raise Exception.Create('Cannot change the number of buffers for an open audio device');
  FBufCount := Value;
end;


//------------------------------------------------------------------------------
//                            enable / disable
//------------------------------------------------------------------------------
procedure TAlSoundOut.SetEnabled(AEnabled: boolean);
begin
  if AEnabled = FEnabled then Exit;
  if AEnabled then DoStart else DoStop;
  FEnabled := AEnabled;
end;


procedure TAlSoundOut.DoStart;
var
  err: PaError;
begin
  FBufsAdded := 0;
  FBufsDone := 0;
  FMaxBlock := 0;

  // ring capacity: generous headroom (a few seconds); safe for any BufSize/rate
  FCap := 1 shl 16;
  SetLength(FRing, FCap);
  FHead := 0; FTail := 0; FCount := 0;

  if not FPaReady then
    begin
    err := Pa_Initialize;
    if err <> paNoError then
      raise ESoundError.Create('Pa_Initialize: ' + Pa_GetErrorText(err));
    FPaReady := true;
    end;

  err := Pa_OpenDefaultStream(FStream, 0, 1, paInt16, FSamplesPerSec,
    paFramesPerBufferUnspecified, @PaCallback, Self);
  if err <> paNoError then
    raise ESoundError.Create('Pa_OpenDefaultStream: ' + Pa_GetErrorText(err));

  // prime the ring before the card starts pulling, then start playback + pump
  FEnabled := true;   // so PutData accepts data during priming
  Pump;

  err := Pa_StartStream(FStream);
  if err <> paNoError then
    begin
    Pa_CloseStream(FStream);
    FStream := nil;
    raise ESoundError.Create('Pa_StartStream: ' + Pa_GetErrorText(err));
    end;

  FTimer.Enabled := true;
end;


procedure TAlSoundOut.DoStop;
begin
  FTimer.Enabled := false;
  if FStream <> nil then
    begin
    Pa_AbortStream(FStream);
    Pa_CloseStream(FStream);
    FStream := nil;
    end;
  FLock.Enter;
  try
    FHead := 0; FTail := 0; FCount := 0;
  finally
    FLock.Leave;
  end;
end;


//------------------------------------------------------------------------------
//                          main-thread producer
//------------------------------------------------------------------------------
procedure TAlSoundOut.OnTimer(Sender: TObject);
begin
  if FEnabled then Pump;
end;


// Keep the ring filled to BufCount blocks by firing OnBufAvailable, exactly like
// the original queued BufCount waveOut buffers.  Capped so a non-draining ring
// can never spin forever.
procedure TAlSoundOut.Pump;
var
  target, guard, prevCount: integer;
begin
  if not Assigned(FOnBufAvailable) then Exit;

  guard := integer(FBufCount) + 2;
  repeat
    if FMaxBlock = 0 then
      target := 1                       // not primed yet: fetch at least one block
    else
      target := integer(FBufCount) * FMaxBlock;

    FLock.Enter; try prevCount := FCount; finally FLock.Leave; end;
    if prevCount >= target then Break;

    FOnBufAvailable(Self);              // -> PutData(Tst.GetAudio)

    FLock.Enter; try
      if FCount = prevCount then guard := 0;  // nothing added; stop
    finally FLock.Leave; end;

    Dec(guard);
  until guard <= 0;
end;


function TAlSoundOut.PutData(Data: TSingleArray): boolean;
var
  i, n: integer;
  v: integer;
begin
  Result := false;
  if not FEnabled then Exit;

  n := Length(Data);
  if n = 0 then begin Result := true; Exit; end;
  if n > FMaxBlock then FMaxBlock := n;

  FLock.Enter;
  try
    for i := 0 to n-1 do
      begin
      if FCount >= FCap then Break;     // ring full: drop (mirrors "buffers full")
      v := Round(Data[i]);
      if v > 32767 then v := 32767
      else if v < -32767 then v := -32767;
      FRing[FTail] := SmallInt(v);
      FTail := (FTail + 1) mod FCap;
      Inc(FCount);
      end;
  finally
    FLock.Leave;
  end;

  Inc(FBufsAdded);
  Result := true;
end;


//------------------------------------------------------------------------------
//                        audio-thread consumer
//------------------------------------------------------------------------------
procedure TAlSoundOut.ConsumeInto(Dest: PSmallInt; ACount: integer);
var
  i: integer;
begin
  FLock.Enter;
  try
    for i := 0 to ACount-1 do
      begin
      if FCount > 0 then
        begin
        Dest^ := FRing[FHead];
        FHead := (FHead + 1) mod FCap;
        Dec(FCount);
        end
      else
        Dest^ := 0;                     // underrun -> silence
      Inc(Dest);
      end;
  finally
    FLock.Leave;
  end;
  Inc(FBufsDone);
end;


procedure TAlSoundOut.Purge;
begin
  FLock.Enter;
  try
    FHead := 0; FTail := 0; FCount := 0;
  finally
    FLock.Leave;
  end;
end;


end.
