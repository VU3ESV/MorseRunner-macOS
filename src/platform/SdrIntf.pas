//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// SDR-server integration facade (macOS port add-on, NOT part of VE3NEA's
// original). Lets MorseRunner act as a network SDR receiver so a CW Skimmer
// (e.g. SkimServerMac) can decode the live pileup, plus a timestamped
// ground-truth feed for scoring the decoder.
//
// The simulation/GUI touch ONLY these thin globals; all the socket/DSP work
// lives in HpsdrDevice.pas (HPSDR Protocol-1 device) and TruthServer.pas
// (ground-truth TCP feed). Everything is inert unless SdrStart has run, so the
// one-line taps in Contest.pas / DxStn.pas have zero effect on normal use.
//------------------------------------------------------------------------------
unit SdrIntf;

{$MODE Delphi}{$H+}

interface

uses
  SndTypes;

const
  SDR_HPSDR_PORT = 1024;   // HPSDR Protocol 1 discovery/command/data UDP port
  SDR_TRUTH_PORT = 7355;   // ground-truth JSON-over-TCP feed

// lifecycle (called from the GUI)
procedure SdrStart;
procedure SdrStop;
function  SdrActive: boolean;
function  SdrStatus: string;

// taps (called from the simulation; no-ops when inactive)
procedure SdrPushIq(const Re, Im: TSingleArray; N: integer);
procedure SdrTruth(const ACall: string; AFreqHz, AWpm: integer;
  const AMsg: string; ATimeMs: Int64);

implementation

uses
  SysUtils, HpsdrDevice, TruthServer;

var
  FDevice: THpsdrDevice = nil;
  FTruth: TTruthServer = nil;
  FActive: boolean = false;


procedure SdrStart;
begin
  if FActive then Exit;
  FDevice := THpsdrDevice.Create(SDR_HPSDR_PORT);
  FTruth := TTruthServer.Create(SDR_TRUTH_PORT);
  FDevice.Start;
  FTruth.Start;
  FActive := true;
end;


procedure SdrStop;
begin
  if not FActive then Exit;
  FActive := false;
  if FDevice <> nil then begin FDevice.Stop; FreeAndNil(FDevice); end;
  if FTruth <> nil then begin FTruth.Stop; FreeAndNil(FTruth); end;
end;


function SdrActive: boolean;
begin
  Result := FActive;
end;


function SdrStatus: string;
begin
  if not FActive then Exit('SDR server off');
  Result := FDevice.StatusText + ' | ' + FTruth.StatusText;
end;


procedure SdrPushIq(const Re, Im: TSingleArray; N: integer);
begin
  if FActive and (FDevice <> nil) then FDevice.PushIq(Re, Im, N);
end;


procedure SdrTruth(const ACall: string; AFreqHz, AWpm: integer;
  const AMsg: string; ATimeMs: Int64);
begin
  if FActive and (FTruth <> nil) then
    FTruth.Emit(ACall, AFreqHz, AWpm, AMsg, ATimeMs);
end;


initialization
finalization
  SdrStop;
end.
