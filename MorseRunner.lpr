program MorseRunner;

{$MODE Delphi}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces,           // LCL widgetset (cocoa on macOS)
  Forms,
  Main, ScoreDlg,
  // simulation + DSP core (logic identical to VE3NEA's original)
  Contest, RndFunc, Ini, Station, MorseKey, StnColl, DxStn, MyStn, CallLst,
  QrmStn, Log, Qsb, DxOper, QrnStn, Crc32, SndTypes, MorseTbl, QuickAvg,
  MovAvg, Mixers, VolumCtl,
  // ported platform layer
  VolmSldr, SndOut, WavFile, PortAudio,
  // SDR-server add-on (HPSDR device emulation + ground-truth feed)
  SdrIntf, HpsdrDevice, TruthServer,
  // test control API (HTTP+JSON automation endpoint)
  ControlApi;

begin
  Application.Initialize;
  Application.Title := 'Morse Runner';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TScoreDialog, ScoreDialog);
  Application.Run;
end.
