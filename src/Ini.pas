//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Ini;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, IniFiles, SndTypes, Math;

const
  SEC_STN = 'Station';
  SEC_BND = 'Band';
  SEC_TST = 'Contest';
  SEC_SYS = 'System';

  DEFAULTBUFCOUNT = 8;
  DEFAULTBUFSIZE = 512;
  DEFAULTRATE = 11025;


type
  TRunMode = (rmStop, rmPileup, rmSingle, rmWpx, rmHst);
  
var
  Call: string = 'VE3NEA';
  HamName: string;
  Wpm: integer = 30;
  BandWidth: integer = 500;
  Pitch: integer = 600;
  // Std-dev of the Gaussian frequency spread of pileup callers (Hz): how far
  // callers scatter around the RX pitch. Default 300 keeps the original tight
  // pile; larger values spread the pile so an SDR skimmer can resolve callers
  // into separate bins. Settable via the control API (spreadHz).
  PitchSpread: integer = 300;
  Qsk: boolean = true;
  Rit: integer = 0;
  BufSize: integer = DEFAULTBUFSIZE;

  Activity: integer = 2;
  Qrn: boolean = true;
  Qrm: boolean = true;
  Qsb: boolean = true;
  Flutter: boolean = true;
  Lids: boolean = true;

  Duration: integer = 30;
  RunMode: TRunMode = rmStop;
  HiScore: integer;
  CompDuration: integer = 60;

  SaveWav: boolean = false;
  CallsFromKeyer: boolean = false;
  MuteLocal: boolean = false;   // (port) silence the speakers while running
  SdrServer: boolean = false;   // (port) HPSDR SDR server on; restored at startup
  ApiServer: boolean = false;   // (port) control API on; restored at startup


procedure FromIni;
procedure ToIni;

// (macOS port) The original stored MorseRunner.ini/.wav/.lst next to the .exe.
// Inside /Applications that directory is read-only, so writable files go to a
// per-user data directory instead: GetAppConfigDir(False), which resolves to
// ~/.config/Morse Runner/ (named after Application.Title).
function AppDataDir: string;
function AppFile(const AName: string): string;



implementation

uses
  Main, Contest;

function AppDataDir: string;
begin
  Result := GetAppConfigDir(False);
  if Result = '' then Result := GetTempDir;
  ForceDirectories(Result);
  if (Result <> '') and (Result[Length(Result)] <> PathDelim) then
    Result := Result + PathDelim;
end;

function AppFile(const AName: string): string;
begin
  Result := AppDataDir + AName;
end;

procedure FromIni;
var
  V: integer;
begin
  with TIniFile.Create(AppFile('MorseRunner.ini')) do
    try
      MainForm.SetMyCall(ReadString(SEC_STN, 'Call', Call));
      MainForm.SetPitch(ReadInteger(SEC_STN, 'Pitch', 3));
      MainForm.SetBw(ReadInteger(SEC_STN, 'BandWidth', 9));

      HamName := ReadString(SEC_STN, 'Name', '');
      if HamName <> '' then
        MainForm.Caption := MainForm.Caption + ':  ' + HamName;

      Wpm := ReadInteger(SEC_STN, 'Wpm', Wpm);
      Wpm := Max(10, Min(120, Wpm));
      MainForm.SpinEdit1.Value := Wpm;
      Tst.Me.Wpm := Wpm;

      MainForm.SetQsk(ReadBool(SEC_STN, 'Qsk', Qsk));
      CallsFromKeyer := ReadBool(SEC_STN, 'CallsFromKeyer', CallsFromKeyer);

      Activity := ReadInteger(SEC_BND, 'Activity', Activity);
      MainForm.SpinEdit3.Value := Activity;

      MainForm.CheckBox4.Checked := ReadBool(SEC_BND, 'Qrn', Qrn);
      MainForm.CheckBox3.Checked := ReadBool(SEC_BND, 'Qrm', Qrm);
      MainForm.CheckBox2.Checked := ReadBool(SEC_BND, 'Qsb', Qsb);
      MainForm.CheckBox5.Checked := ReadBool(SEC_BND, 'Flutter', Flutter);
      MainForm.CheckBox6.Checked := ReadBool(SEC_BND, 'Lids', Lids);
      MainForm.ReadCheckBoxes;

      Duration := ReadInteger(SEC_TST, 'Duration', Duration);
      MainForm.SpinEdit2.Value := Duration;
      HiScore := ReadInteger(SEC_TST, 'HiScore', HiScore);
      CompDuration := Max(1, Min(60, ReadInteger(SEC_TST, 'CompetitionDuration', CompDuration)));

      //buffer size
      V := ReadInteger(SEC_SYS, 'BufSize', 0);
      if V = 0 then
        begin V := 3; WriteInteger(SEC_SYS, 'BufSize', V); end;
      V := Max(1, Min(5, V));
      BufSize := 64 shl V;
      Tst.Filt.SamplesInInput := BufSize;
      Tst.Filt2.SamplesInInput := BufSize;

      V := ReadInteger(SEC_STN, 'SelfMonVolume', 0);
      MainForm.VolumeSlider1.Value := V / 80 + 0.75;

      SaveWav := ReadBool(SEC_STN, 'SaveWav', SaveWav);

      MuteLocal := ReadBool(SEC_STN, 'MuteLocalAudio', MuteLocal);
      MainForm.AlSoundOut1.Muted := MuteLocal;

      // (port) SDR-server / control-API toggles: loaded here, actually started
      // (and their menu checkmarks set) at the end of TMainForm.FormCreate,
      // once those code-created menu items exist.
      SdrServer := ReadBool(SEC_SYS, 'SdrServer', SdrServer);
      ApiServer := ReadBool(SEC_SYS, 'ControlApi', ApiServer);
    finally
      Free;
    end;
end;


procedure ToIni;
var
  V: integer;
begin
  with TIniFile.Create(AppFile('MorseRunner.ini')) do
    try
      WriteString(SEC_STN, 'Call', Call);
      WriteInteger(SEC_STN, 'Pitch', MainForm.ComboBox1.ItemIndex);
      WriteInteger(SEC_STN, 'BandWidth', MainForm.ComboBox2.ItemIndex);
      WriteInteger(SEC_STN, 'Wpm', Wpm);
      WriteBool(SEC_STN, 'Qsk', Qsk);

      WriteInteger(SEC_BND, 'Activity', Activity);
      WriteBool(SEC_BND, 'Qrn', Qrn);
      WriteBool(SEC_BND, 'Qrm', Qrm);
      WriteBool(SEC_BND, 'Qsb', Qsb);
      WriteBool(SEC_BND, 'Flutter', Flutter);
      WriteBool(SEC_BND, 'Lids', Lids);

      WriteInteger(SEC_TST, 'Duration', Duration);
      WriteInteger(SEC_TST, 'HiScore', HiScore);
      WriteInteger(SEC_TST, 'CompetitionDuration', CompDuration);

      V := Round(80 * (MainForm.VolumeSlider1.Value - 0.75));
      WriteInteger(SEC_STN, 'SelfMonVolume', V);

      WriteBool(SEC_STN, 'SaveWav', SaveWav);
      WriteBool(SEC_STN, 'MuteLocalAudio', MuteLocal);
      WriteBool(SEC_SYS, 'SdrServer', SdrServer);
      WriteBool(SEC_SYS, 'ControlApi', ApiServer);
    finally
      Free;
    end;
end;




end.

