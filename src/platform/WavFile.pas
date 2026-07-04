//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// macOS/Lazarus port of WavFile.pas.
//
// The original TAlWavFile was a full mmio-based WAV reader/writer tied to the
// Windows multimedia API.  MorseRunner only ever uses the mono 16-bit *write*
// path (Main.Run opens it, Contest.GetAudio streams the AGC output through
// WriteFrom, Main closes it), so this port implements exactly that on top of a
// plain TFileStream.  The on-disk format is identical: a canonical 44-byte
// PCM/RIFF header followed by little-endian 16-bit mono samples at
// SamplesPerSec (11025 Hz, matching Contest's DEFAULTRATE).
//------------------------------------------------------------------------------
unit WavFile;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, Classes, SndTypes;

const
  WAV_DEFAULT_RATE = 11025;

type
  TAlWavFile = class(TComponent)
  private
    FStream: TFileStream;
    FFileName: string;
    FIsOpen: boolean;
    FSamplesPerSec: LongWord;
    FDataBytes: LongWord;
    procedure WriteHeader(ADataBytes: LongWord);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenWrite;
    procedure Close;
    // Mono when ARBuf = nil; ARBuf is accepted for signature compatibility but,
    // as in the original MorseRunner usage, only the left channel is recorded.
    procedure WriteFrom(ALBuf: PSingle; ARBuf: PSingle; ACount: integer);
    property FileName: string read FFileName write FFileName;
    property IsOpen: boolean read FIsOpen;
    property SamplesPerSec: LongWord read FSamplesPerSec write FSamplesPerSec;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Al', [TAlWavFile]);
end;


constructor TAlWavFile.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSamplesPerSec := WAV_DEFAULT_RATE;
end;


destructor TAlWavFile.Destroy;
begin
  if FIsOpen then Close;
  inherited;
end;


procedure TAlWavFile.WriteHeader(ADataBytes: LongWord);
const
  Channels: Word = 1;
  BitsPerSample: Word = 16;
var
  BlockAlign: Word;
  AvgBytesPerSec, D: LongWord;
  Fmt: Word;
begin
  BlockAlign := Channels * (BitsPerSample div 8);
  AvgBytesPerSec := FSamplesPerSec * BlockAlign;
  Fmt := 1; // PCM

  FStream.Position := 0;
  FStream.Write('RIFF', 4);
  D := 36 + ADataBytes;              FStream.Write(D, 4);   // RIFF chunk size
  FStream.Write('WAVE', 4);
  FStream.Write('fmt ', 4);
  D := 16;                           FStream.Write(D, 4);   // fmt chunk size
  FStream.Write(Fmt, 2);
  FStream.Write(Channels, 2);
  FStream.Write(FSamplesPerSec, 4);
  FStream.Write(AvgBytesPerSec, 4);
  FStream.Write(BlockAlign, 2);
  FStream.Write(BitsPerSample, 2);
  FStream.Write('data', 4);
  FStream.Write(ADataBytes, 4);       // data chunk size
end;


procedure TAlWavFile.OpenWrite;
begin
  if FIsOpen then Close;
  FStream := TFileStream.Create(FFileName, fmCreate);
  FDataBytes := 0;
  WriteHeader(0);                     // placeholder; patched in Close
  FIsOpen := true;
end;


procedure TAlWavFile.WriteFrom(ALBuf: PSingle; ARBuf: PSingle; ACount: integer);
var
  i, v: integer;
  s: SmallInt;
begin
  if not FIsOpen then Exit;
  for i := 0 to ACount-1 do
    begin
    v := Round(ALBuf^);
    if v > 32767 then v := 32767
    else if v < -32767 then v := -32767;
    s := SmallInt(v);
    FStream.Write(s, 2);
    Inc(ALBuf);
    end;
  Inc(FDataBytes, LongWord(ACount) * 2);
end;


procedure TAlWavFile.Close;
begin
  if not FIsOpen then Exit;
  WriteHeader(FDataBytes);            // patch RIFF/data sizes now that we know them
  FreeAndNil(FStream);
  FIsOpen := false;
end;


end.
