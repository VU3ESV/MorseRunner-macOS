//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// Ground-truth feed — macOS port add-on.
//
// A tiny TCP server that streams newline-delimited JSON, one object per pileup
// caller, so a CW-Skimmer test harness can score decoded callsigns against
// exactly what MorseRunner keyed and WHEN:
//
//   {"t_ms":12345,"call":"DL3RC","freq_hz":128,"wpm":29,"msg":"DL3RC"}
//
//   t_ms    milliseconds since the run started (simulation clock, exact)
//   call    the caller's true callsign
//   freq_hz its audio offset from the receiver centre (station pitch)
//   wpm     keying speed
//   msg     the text keyed
//
// Events are kept in a history buffer and REPLAYED in full to every client on
// connect, so a harness can attach before, during, or after the run and still
// receive the complete ground truth. Writes never raise SIGPIPE (SO_NOSIGPIPE).
//------------------------------------------------------------------------------
unit TruthServer;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, Classes, SyncObjs;

type
  TTruthServer = class
  private
    FPort: word;
    FListen: longint;
    FThread: TThread;
    FTerminating: boolean;
    FLock: TCriticalSection;
    FHistory: TStringList;                 // every event, for replay-on-connect
    FClients: array of longint;
    FClientSent: array of integer;         // per-client next history index
    FClientCount: integer;
    procedure ThreadRun;
  public
    constructor Create(APort: word);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure Emit(const ACall: string; AFreqHz, AWpm: integer;
      const AMsg: string; ATimeMs: Int64);
    function StatusText: string;
  end;

implementation

uses
  ctypes, BaseUnix, Sockets;

const
  MR_AF_INET      = 2;
  MR_SOCK_STREAM  = 1;
  MR_SOL_SOCKET   = $FFFF;
  MR_SO_REUSEADDR = $0004;
  MR_SO_NOSIGPIPE = $1022;    // darwin: don't raise SIGPIPE on dead-peer write

type
  TSockAddrIn = packed record
    sin_len: byte;
    sin_family: byte;
    sin_port: word;
    sin_addr: cardinal;
    sin_zero: array[0..7] of byte;
  end;

  TTruthThread = class(TThread)
  private
    FSrv: TTruthServer;
  protected
    procedure Execute; override;
  public
    constructor Create(ASrv: TTruthServer);
  end;

function htons16(v: word): word; inline;
begin
  Result := ((v shr 8) or (v shl 8)) and $FFFF;
end;

function JsonEsc(const S: string): string;
var i: integer; c: char;
begin
  Result := '';
  for i := 1 to Length(S) do
    begin
    c := S[i];
    case c of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #10: Result := Result + '\n';
      #13: ;
    else Result := Result + c;
    end;
    end;
end;


{ TTruthServer }

constructor TTruthServer.Create(APort: word);
begin
  inherited Create;
  FPort := APort;
  FListen := -1;
  FLock := TCriticalSection.Create;
  FHistory := TStringList.Create;
  SetLength(FClients, 16);
  SetLength(FClientSent, 16);
end;

destructor TTruthServer.Destroy;
begin
  Stop;
  FHistory.Free;
  FLock.Free;
  inherited;
end;

procedure TTruthServer.Start;
var
  addr: TSockAddrIn;
  one, flags: cint;
begin
  FListen := fpSocket(MR_AF_INET, MR_SOCK_STREAM, 0);
  if FListen < 0 then Exit;
  one := 1;
  fpSetSockOpt(FListen, MR_SOL_SOCKET, MR_SO_REUSEADDR, @one, sizeof(one));

  FillChar(addr, sizeof(addr), 0);
  addr.sin_len := sizeof(addr);
  addr.sin_family := MR_AF_INET;
  addr.sin_port := htons16(FPort);
  addr.sin_addr := 0;
  if fpBind(FListen, psockaddr(@addr), sizeof(addr)) < 0 then
    begin CloseSocket(FListen); FListen := -1; Exit; end;
  fpListen(FListen, 4);

  flags := fpFcntl(FListen, F_GETFL, 0);       // non-blocking accept
  fpFcntl(FListen, F_SETFL, flags or O_NONBLOCK);

  FThread := TTruthThread.Create(Self);
end;

procedure TTruthServer.Stop;
var i: integer;
begin
  FTerminating := true;
  if FThread <> nil then begin FThread.WaitFor; FreeAndNil(FThread); end;
  for i := 0 to FClientCount-1 do CloseSocket(FClients[i]);
  FClientCount := 0;
  if FListen >= 0 then begin CloseSocket(FListen); FListen := -1; end;
end;

procedure TTruthServer.Emit(const ACall: string; AFreqHz, AWpm: integer;
  const AMsg: string; ATimeMs: Int64);
var line: string;
begin
  line := Format('{"t_ms":%d,"call":"%s","freq_hz":%d,"wpm":%d,"msg":"%s"}',
    [ATimeMs, JsonEsc(ACall), AFreqHz, AWpm, JsonEsc(AMsg)]);
  FLock.Enter;
  try
    FHistory.Add(line);
  finally
    FLock.Leave;
  end;
end;

function TTruthServer.StatusText: string;
begin
  Result := Format('truth:%d (%d client, %d events)',
    [FPort, FClientCount, FHistory.Count]);
end;


{ TTruthThread }

constructor TTruthThread.Create(ASrv: TTruthServer);
begin
  FSrv := ASrv;
  inherited Create(False);
end;

procedure TTruthThread.Execute;
begin
  FSrv.ThreadRun;
end;

procedure TTruthServer.ThreadRun;
var
  cli: longint;
  ca: TSockAddrIn;
  clen: tsocklen;
  one: cint;
  i, j, minSent, count: integer;
  snap: TStringList;
  s: string;
  hello: string;
begin
  snap := TStringList.Create;
  try
    while not FTerminating do
      begin
      // accept any waiting client (non-blocking); replay history from index 0
      clen := sizeof(ca);
      cli := fpAccept(FListen, psockaddr(@ca), @clen);
      if cli >= 0 then
        begin
        one := 1;
        fpSetSockOpt(cli, MR_SOL_SOCKET, MR_SO_NOSIGPIPE, @one, sizeof(one));
        if FClientCount >= Length(FClients) then
          begin
          SetLength(FClients, Length(FClients)*2);
          SetLength(FClientSent, Length(FClientSent)*2);
          end;
        FClients[FClientCount] := cli;
        FClientSent[FClientCount] := 0;      // 0 => full replay
        Inc(FClientCount);
        hello := '{"event":"hello","source":"MorseRunner","format":"ndjson"}'#10;
        fpSend(cli, @hello[1], Length(hello), 0);
        end;

      if FClientCount > 0 then
        begin
        // snapshot the history slice all clients still need
        minSent := MaxInt;
        for i := 0 to FClientCount-1 do
          if FClientSent[i] < minSent then minSent := FClientSent[i];
        FLock.Enter;
        try
          count := FHistory.Count;
          snap.Clear;
          for j := minSent to count-1 do snap.Add(FHistory[j]);
        finally
          FLock.Leave;
        end;

        // per-client catch-up
        i := 0;
        while i < FClientCount do
          begin
          j := FClientSent[i];
          while j < count do
            begin
            s := snap[j - minSent] + #10;
            if fpSend(FClients[i], @s[1], Length(s), 0) < 0 then
              begin j := -1; Break; end;     // dead client
            Inc(j);
            end;
          if j < 0 then
            begin
            CloseSocket(FClients[i]);
            FClients[i] := FClients[FClientCount-1];
            FClientSent[i] := FClientSent[FClientCount-1];
            Dec(FClientCount);                // swap-remove; re-check this slot
            end
          else
            begin FClientSent[i] := count; Inc(i); end;
          end;
        end;

      Sleep(20);
      end;
  finally
    snap.Free;
  end;
end;


end.
