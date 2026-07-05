//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// Control / automation API — macOS port add-on.
//
// An embedded HTTP+JSON server that lets a test application drive MorseRunner
// remotely: hand it a scenario (e.g. a Pile-Up), it runs it while recording
// every callsign it generates WITH TIMESTAMPS, and returns that ground-truth
// log when the run is over. Anything a user can do from the UI (set call/WPM/
// pitch/bandwidth/conditions, start/stop the run modes, send the F-key
// messages, log a QSO, read the score) is also reachable as an action.
//
// Endpoints (default port 7300):
//   GET  /            human-readable API description
//   GET  /state       current settings + score + run status + #calls
//   GET  /calls       the recorded ground-truth calls for the current/last run
//   POST /reset       clear the recorded calls
//   POST /command     {"action":"...", ...}  invoke one UI action
//   POST /scenario    {"mode":"pileup","durationSec":30, ...} run + return calls
//
// The API touches the simulation ONLY through a dispatch callback that Main
// registers (ApiRegisterDispatch); every dispatch runs on the main thread via
// TThread.Synchronize, because the sim/GUI are not thread-safe. Nothing here
// runs unless ApiStart has been called from the GUI toggle.
//------------------------------------------------------------------------------
unit ControlApi;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, Classes, SyncObjs, fpjson, jsonparser, fphttpserver, httpdefs;

type
  // Main registers this; it runs on the MAIN thread. Returns a JSON object the
  // caller (HTTP handler) owns and frees. Params may be nil.
  TApiDispatch = function(const Action: string; Params: TJSONObject): TJSONObject of object;

  TControlApi = class
  private
    FPort: word;
    FServer: TFPHTTPServer;
    FThread: TThread;
    procedure HandleRequest(Sender: TObject;
      var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  public
    constructor Create(APort: word);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function StatusText: string;
  end;

// dispatch registration (called by Main)
procedure ApiRegisterDispatch(D: TApiDispatch);

// ground-truth log (called by the simulation via DxStn)
procedure ApiRecordCall(const ACall: string; AFreqHz, AWpm: integer;
  const AMsg: string; ATimeMs: Int64);
procedure ApiResetLog;
function  ApiCallsArray: TJSONArray;   // caller owns/frees
function  ApiCallCount: integer;

implementation

uses
  BaseUnix, Sockets,       // self-connect poke to unblock the accept loop on Stop
  HpsdrDevice, SdrIntf;    // ApiRecordCall also forwards to the SDR truth feed

type
  TCallRec = record
    TMs: Int64;
    Call, Msg: string;
    Freq, Wpm: integer;
  end;

var
  GDispatch: TApiDispatch = nil;
  GLock: TCriticalSection = nil;
  GLog: array of TCallRec;
  GLogCount: integer = 0;


procedure ApiRegisterDispatch(D: TApiDispatch);
begin
  GDispatch := D;
end;

procedure ApiRecordCall(const ACall: string; AFreqHz, AWpm: integer;
  const AMsg: string; ATimeMs: Int64);
begin
  GLock.Enter;
  try
    if GLogCount >= Length(GLog) then
      SetLength(GLog, (Length(GLog) + 64) * 2);
    GLog[GLogCount].TMs := ATimeMs;
    GLog[GLogCount].Call := ACall;
    GLog[GLogCount].Msg := AMsg;
    GLog[GLogCount].Freq := AFreqHz;
    GLog[GLogCount].Wpm := AWpm;
    Inc(GLogCount);
  finally
    GLock.Leave;
  end;
  // forward to the live SDR ground-truth stream (no-op unless SDR server is up)
  SdrTruth(ACall, AFreqHz, AWpm, AMsg, ATimeMs);
end;

procedure ApiResetLog;
begin
  GLock.Enter;
  try GLogCount := 0; finally GLock.Leave; end;
end;

function ApiCallCount: integer;
begin
  GLock.Enter; try Result := GLogCount; finally GLock.Leave; end;
end;

function ApiCallsArray: TJSONArray;
var
  i: integer;
  o: TJSONObject;
begin
  Result := TJSONArray.Create;
  GLock.Enter;
  try
    for i := 0 to GLogCount-1 do
      begin
      o := TJSONObject.Create;
      o.Add('t_ms', GLog[i].TMs);
      o.Add('call', GLog[i].Call);
      o.Add('freq_hz', GLog[i].Freq);
      o.Add('wpm', GLog[i].Wpm);
      o.Add('msg', GLog[i].Msg);
      Result.Add(o);
      end;
  finally
    GLock.Leave;
  end;
end;


//------------------------------------------------------------------------------
//                  main-thread marshaling of a dispatch call
//------------------------------------------------------------------------------
type
  TMainInvoker = class
    FAction: string;
    FParams: TJSONObject;
    FResult: TJSONObject;
    procedure DoIt;    // runs on the main thread
  end;

procedure TMainInvoker.DoIt;
begin
  if Assigned(GDispatch) then FResult := GDispatch(FAction, FParams)
  else FResult := TJSONObject.Create;
end;

// Blocks the calling (HTTP) thread until the action has run on the main thread.
function CallMain(const Action: string; Params: TJSONObject): TJSONObject;
var
  inv: TMainInvoker;
begin
  inv := TMainInvoker.Create;
  try
    inv.FAction := Action;
    inv.FParams := Params;
    TThread.Synchronize(nil, inv.DoIt);
    Result := inv.FResult;
    if Result = nil then Result := TJSONObject.Create;
  finally
    inv.Free;
  end;
end;


//------------------------------------------------------------------------------
//                              HTTP server
//------------------------------------------------------------------------------
type
  THttpThread = class(TThread)
  private
    FSrv: TFPHTTPServer;
  protected
    procedure Execute; override;
  public
    constructor Create(ASrv: TFPHTTPServer);
  end;

constructor THttpThread.Create(ASrv: TFPHTTPServer);
begin
  FSrv := ASrv;
  inherited Create(False);
end;

procedure THttpThread.Execute;
begin
  try FSrv.Active := True;    // blocks in the accept loop until Active:=False
  except end;
end;


const
  HELP =
    'MorseRunner Control API' + LineEnding + LineEnding +
    'GET  /state                 settings + score + run status + #calls' + LineEnding +
    'GET  /calls                 recorded ground-truth calls (current/last run)' + LineEnding +
    'POST /reset                 clear recorded calls' + LineEnding +
    'POST /command  {action,...} invoke one UI action' + LineEnding +
    'POST /scenario {mode,durationSec,...}  run a scenario, return calls' + LineEnding +
    LineEnding +
    'command actions: set | run | stop | send | enter | saveQso | wipe' + LineEnding +
    '  set   {call,wpm,pitchHz,bandwidthHz,spreadHz,qsk,activity,rit,qrn,qrm,qsb,flutter,lids}' + LineEnding +
    '         (out-of-range numeric params -> HTTP 400; spreadHz 0..3000, caller freq scatter)' + LineEnding +
    '  run   {mode: stop|pileup|single|wpx|hst}' + LineEnding +
    '  send  {msg: cq|nr|tu|mycall|hiscall|b4|qm|nil|agn}' + LineEnding +
    '  enter {call,rst,nr}' + LineEnding +
    'scenario: applies the same fields as set, resets the call log, starts the' + LineEnding +
    '  run (auto-CQ for pileup/wpx), waits durationSec, stops, and returns' + LineEnding +
    '  {mode,durationSec,count,calls:[{t_ms,call,freq_hz,wpm,msg}],score}.' + LineEnding;


constructor TControlApi.Create(APort: word);
begin
  inherited Create;
  FPort := APort;
end;

destructor TControlApi.Destroy;
begin
  Stop;
  inherited;
end;

procedure TControlApi.Start;
begin
  FServer := TFPHTTPServer.Create(nil);
  FServer.Port := FPort;
  FServer.Threaded := True;
  FServer.OnRequest := HandleRequest;
  FThread := THttpThread.Create(FServer);
end;

procedure TControlApi.Stop;
var
  poke: longint;
  addr: TInetSockAddr;
begin
  if FServer <> nil then
    begin
    // TFPHTTPServer's worker thread is parked in a blocking Accept(); setting
    // Active:=False only flips a flag and does NOT wake it, so a plain WaitFor
    // hangs forever (the app never quits). Flip the flag, then make one
    // throwaway localhost connection to wake the Accept — the loop then sees
    // Active=False and the thread exits, so WaitFor returns.
    try FServer.Active := False; except end;
    poke := fpSocket(AF_INET, SOCK_STREAM, 0);
    if poke >= 0 then
      begin
      addr.sin_family := AF_INET;
      addr.sin_port := htons(FPort);
      addr.sin_addr.s_addr := htonl($7F000001);   // 127.0.0.1
      fpConnect(poke, @addr, sizeof(addr));         // best-effort; ignore result
      CloseSocket(poke);
      end;
    if FThread <> nil then begin FThread.WaitFor; FreeAndNil(FThread); end;
    FreeAndNil(FServer);
    end;
end;

function TControlApi.StatusText: string;
begin
  Result := Format('control:%d (%d calls)', [FPort, ApiCallCount]);
end;


procedure SendJson(var AResponse: TFPHTTPConnectionResponse; Obj: TJSONData; Code: integer = 200);
begin
  AResponse.Code := Code;
  AResponse.ContentType := 'application/json';
  AResponse.Content := Obj.AsJSON;
  Obj.Free;
end;

function ParseBody(const S: string): TJSONObject;
var d: TJSONData;
begin
  Result := nil;
  if Trim(S) = '' then Exit;
  try
    d := GetJSON(S);
    if d is TJSONObject then Result := TJSONObject(d) else d.Free;
  except
    Result := nil;
  end;
end;


procedure TControlApi.HandleRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  path, mode: string;
  body, res: TJSONObject;
  durSec, i: integer;
begin
  path := ARequest.PathInfo;

  if (path = '/state') then
    begin SendJson(AResponse, CallMain('state', nil)); Exit; end;

  if (path = '/calls') or (path = '/truth') then
    begin
    res := TJSONObject.Create;
    res.Add('count', ApiCallCount);
    res.Add('calls', ApiCallsArray);
    SendJson(AResponse, res);
    Exit;
    end;

  if (path = '/reset') then
    begin
    ApiResetLog;
    res := TJSONObject.Create; res.Add('ok', true); SendJson(AResponse, res);
    Exit;
    end;

  if (path = '/command') then
    begin
    body := ParseBody(ARequest.Content);
    if (body = nil) or (body.Find('action') = nil) then
      begin
      res := TJSONObject.Create; res.Add('error', 'missing action');
      AResponse.Code := 400; SendJson(AResponse, res);
      if body <> nil then body.Free; Exit;
      end;
    res := CallMain(body.Get('action', ''), body);
    if res.Find('error') <> nil then SendJson(AResponse, res, 400)
    else SendJson(AResponse, res);
    body.Free;
    Exit;
    end;

  if (path = '/scenario') then
    begin
    body := ParseBody(ARequest.Content);
    if body = nil then body := TJSONObject.Create;
    mode := body.Get('mode', 'single');
    durSec := body.Get('durationSec', 30);
    if durSec < 1 then durSec := 1;
    if durSec > 600 then durSec := 600;

    res := CallMain('scenario_start', body);      // apply + reset log + start
    if res.Find('error') <> nil then
      begin SendJson(AResponse, res, 400); body.Free; Exit; end;
    res.Free;
    Sleep(durSec * 1000);                         // let the run generate calls
    (CallMain('stop', nil)).Free;

    res := TJSONObject.Create;
    res.Add('mode', mode);
    res.Add('durationSec', durSec);
    res.Add('count', ApiCallCount);
    res.Add('calls', ApiCallsArray);
    res.Add('score', CallMain('state', nil));     // full state incl. score
    SendJson(AResponse, res);
    body.Free;
    Exit;
    end;

  // default: help
  AResponse.Code := 200;
  AResponse.ContentType := 'text/plain; charset=utf-8';
  AResponse.Content := HELP;
end;


initialization
  GLock := TCriticalSection.Create;
finalization
  GLock.Free;
end.
