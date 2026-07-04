//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// macOS/Lazarus port of Main.pas.  The event handlers and program logic are a
// line-for-line port of the original VCL form; only the platform surface changed:
//   * uses: Windows/Messages/ShellApi/ToolWin/ImgList/jpeg  ->  LCLIntf/LCLType
//     and the LCL RTL units.
//   * RichEdit1 is a TMemo (see Log.pas) instead of TRichEdit.
//   * ShellExecute(...'open'...)  ->  OpenURL / OpenDocument.
//   * The WM_TBDOWN PostMessage trick that deferred setting the toolbutton Down
//     state is replaced by a direct assignment (LCL has no re-entrancy issue).
//   * The score ListView rows are built in code (the original streamed them as a
//     binary blob in the DFM).
// GetKeyState, Application.MessageBox, InputBox and the simulation calls are
// unchanged, so behaviour matches the original.
//------------------------------------------------------------------------------
unit Main;

{$MODE Delphi}{$H+}

interface

uses
  LCLIntf, LCLType, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Buttons, StdCtrls, Menus, ExtCtrls, ComCtrls, Spin, Math,
  SndOut, Contest, Ini, MorseKey, CallLst, VolmSldr, VolumCtl, Station, Log,
  SndTypes, Crc32, WavFile, IniFiles, SdrIntf, ControlApi, fpjson, RndFunc;

type
  TMainForm = class(TForm)
    AlSoundOut1: TAlSoundOut;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Send1: TMenuItem;
    CQ1: TMenuItem;
    Number1: TMenuItem;
    TU1: TMenuItem;
    MyCall1: TMenuItem;
    HisCall1: TMenuItem;
    QSOB41: TMenuItem;
    N1: TMenuItem;
    AGN1: TMenuItem;
    Bevel1: TBevel;
    Panel1: TPanel;
    Label1: TLabel;
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    SpeedButton6: TSpeedButton;
    SpeedButton7: TSpeedButton;
    SpeedButton8: TSpeedButton;
    SpeedButton9: TSpeedButton;
    SpeedButton10: TSpeedButton;
    SpeedButton11: TSpeedButton;
    Edit1: TEdit;
    Label2: TLabel;
    Edit2: TEdit;
    Label3: TLabel;
    Edit3: TEdit;
    Bevel2: TBevel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Help1: TMenuItem;
    Readme1: TMenuItem;
    About1: TMenuItem;
    N2: TMenuItem;
    PaintBox1: TPaintBox;
    Panel5: TPanel;
    Exit1: TMenuItem;
    Panel6: TPanel;
    RichEdit1: TMemo;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Shape1: TShape;
    PopupMenu1: TPopupMenu;
    PileupMNU: TMenuItem;
    SingleCallsMNU: TMenuItem;
    CompetitionMNU: TMenuItem;
    N3: TMenuItem;
    StopMNU: TMenuItem;
    Run1: TMenuItem;
    PileUp1: TMenuItem;
    SingleCalls1: TMenuItem;
    Competition1: TMenuItem;
    N4: TMenuItem;
    Stop1MNU: TMenuItem;
    ViewScoreBoardMNU: TMenuItem;
    ViewScoreTable1: TMenuItem;
    N5: TMenuItem;
    Panel7: TPanel;
    Label16: TLabel;
    Panel8: TPanel;
    Shape2: TShape;
    AlWavFile1: TAlWavFile;
    Panel9: TPanel;
    GroupBox3: TGroupBox;
    Label11: TLabel;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    CheckBox4: TCheckBox;
    CheckBox5: TCheckBox;
    CheckBox6: TCheckBox;
    SpinEdit3: TSpinEdit;
    GroupBox1: TGroupBox;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label9: TLabel;
    Edit4: TEdit;
    SpinEdit1: TSpinEdit;
    CheckBox1: TCheckBox;
    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    Panel10: TPanel;
    Label8: TLabel;
    SpinEdit2: TSpinEdit;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    Label10: TLabel;
    VolumeSlider1: TVolumeSlider;
    Label18: TLabel;
    WebPage1: TMenuItem;
    Settings1: TMenuItem;
    Call1: TMenuItem;
    QSK1: TMenuItem;
    CWSpeed1: TMenuItem;
    N10WPM1: TMenuItem;
    N15WPM1: TMenuItem;
    N20WPM1: TMenuItem;
    N25WPM1: TMenuItem;
    N30WPM1: TMenuItem;
    N35WPM1: TMenuItem;
    N40WPM1: TMenuItem;
    N45WPM1: TMenuItem;
    N50WPM1: TMenuItem;
    N55WPM1: TMenuItem;
    N60WPM1: TMenuItem;
    CWBandwidth1: TMenuItem;
    CWBandwidth2: TMenuItem;
    N300Hz1: TMenuItem;
    N350Hz1: TMenuItem;
    N400Hz1: TMenuItem;
    N450Hz1: TMenuItem;
    N500Hz1: TMenuItem;
    N550Hz1: TMenuItem;
    N600Hz1: TMenuItem;
    N650Hz1: TMenuItem;
    N700Hz1: TMenuItem;
    N750Hz1: TMenuItem;
    N800Hz1: TMenuItem;
    N850Hz1: TMenuItem;
    N900Hz1: TMenuItem;
    N100Hz1: TMenuItem;
    N150Hz1: TMenuItem;
    N200Hz1: TMenuItem;
    N250Hz1: TMenuItem;
    N300Hz2: TMenuItem;
    N350Hz2: TMenuItem;
    N400Hz2: TMenuItem;
    N450Hz2: TMenuItem;
    N500Hz2: TMenuItem;
    N550Hz2: TMenuItem;
    N600Hz2: TMenuItem;
    MonLevel1: TMenuItem;
    N30dB1: TMenuItem;
    N20dB1: TMenuItem;
    N10dB1: TMenuItem;
    N0dB1: TMenuItem;
    N10dB2: TMenuItem;
    N6: TMenuItem;
    QRN1: TMenuItem;
    QRM1: TMenuItem;
    QSB1: TMenuItem;
    Flutter1: TMenuItem;
    LIDS1: TMenuItem;
    Activity1: TMenuItem;
    N11: TMenuItem;
    N21: TMenuItem;
    N31: TMenuItem;
    N41: TMenuItem;
    N51: TMenuItem;
    N61: TMenuItem;
    N71: TMenuItem;
    N81: TMenuItem;
    N91: TMenuItem;
    N7: TMenuItem;
    Duration1: TMenuItem;
    N5min1: TMenuItem;
    N10min1: TMenuItem;
    N15min1: TMenuItem;
    N30min1: TMenuItem;
    N60min1: TMenuItem;
    N90min1: TMenuItem;
    N120min1: TMenuItem;
    PlayRecordedAudio1: TMenuItem;
    N8: TMenuItem;
    AudioRecordingEnabled1: TMenuItem;
    HSTCompetition1: TMenuItem;
    HSTCompetition2: TMenuItem;
    Panel11: TPanel;
    ListView1: TListView;
    Operator1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure AlSoundOut1BufAvailable(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: Char);
    procedure Edit2KeyPress(Sender: TObject; var Key: Char);
    procedure Edit3KeyPress(Sender: TObject; var Key: Char);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit1Enter(Sender: TObject);
    procedure SendClick(Sender: TObject);
    procedure Edit4Change(Sender: TObject);
    procedure ComboBox2Change(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SpinEdit1Change(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure CheckBoxClick(Sender: TObject);
    procedure SpinEdit2Change(Sender: TObject);
    procedure SpinEdit3Change(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure Readme1Click(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure RunMNUClick(Sender: TObject);
    procedure RunBtnClick(Sender: TObject);
    procedure ViewScoreBoardMNUClick(Sender: TObject);
    procedure ViewScoreTable1Click(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Panel8MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Shape2MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Edit2Enter(Sender: TObject);
    procedure VolumeSliderDblClick(Sender: TObject);
    procedure VolumeSlider1Change(Sender: TObject);
    procedure WebPage1Click(Sender: TObject);
    procedure Call1Click(Sender: TObject);
    procedure QSK1Click(Sender: TObject);
    procedure NWPMClick(Sender: TObject);
    procedure Pitch1Click(Sender: TObject);
    procedure Bw1Click(Sender: TObject);
    procedure File1Click(Sender: TObject);
    procedure PlayRecordedAudio1Click(Sender: TObject);
    procedure AudioRecordingEnabled1Click(Sender: TObject);
    procedure SelfMonClick(Sender: TObject);
    procedure Settings1Click(Sender: TObject);
    procedure LIDS1Click(Sender: TObject);
    procedure Activity1Click(Sender: TObject);
    procedure Duration1Click(Sender: TObject);
    procedure Operator1Click(Sender: TObject);
    procedure StopMNUClick(Sender: TObject);
  private
    MustAdvance: boolean;
    procedure ProcessSpace;
    procedure SendMsg(Msg: TStationMessage);
    procedure ProcessEnter;
    procedure EnableCtl(Ctl: TWinControl; AEnable: boolean);
    procedure SetToolbuttonDown(Toolbutton: TToolbutton; ADown: boolean);
    procedure IncRit(dF: integer);
    procedure UpdateRitIndicator;
    procedure DecSpeed;
    procedure IncSpeed;
    procedure BuildScoreView;
    procedure SdrServerClick(Sender: TObject);
  private
    SdrMenu, SdrSep: TMenuItem;
    ApiMenu, MasterMenu, MuteMenu: TMenuItem;
    FControl: TControlApi;
    FApiCq: TTimer;
    procedure ImportMasterClick(Sender: TObject);
    procedure MuteLocalClick(Sender: TObject);
    procedure ControlApiClick(Sender: TObject);
    procedure ApiCqTimer(Sender: TObject);
    function ApiDispatch(const Action: string; Params: TJSONObject): TJSONObject;
  public
    CompetitionMode: boolean;
    procedure Run(Value: TRunMode);
    procedure WipeBoxes;
    procedure PopupScoreWpx;
    procedure PopupScoreHst;
    procedure Advance;

    procedure SetQsk(Value: boolean);
    procedure SetMyCall(ACall: string);
    procedure SetPitch(PitchNo: integer);
    procedure SetBw(BwNo: integer);
    procedure ReadCheckboxes;
  end;

var
  MainForm: TMainForm;

implementation

uses ScoreDlg;

{$R *.lfm}

// (port) The original streamed three ListView rows (Pts / Mult / Score), each
// with two sub-items, as a binary blob in the DFM. Build them in code instead.
procedure TMainForm.BuildScoreView;
const
  Names: array[0..2] of string = ('Pts', 'Mult', 'Score');
var
  i: integer;
  It: TListItem;
begin
  ListView1.Items.Clear;
  for i := 0 to 2 do
    begin
    It := ListView1.Items.Add;
    It.Caption := Names[i];
    It.SubItems.Add('0');
    It.SubItems.Add('0');
    end;
end;


procedure TMainForm.FormCreate(Sender: TObject);
begin
  Randomize;
  Tst := TContest.Create;
  LoadCallList;
  BuildScoreView;

  AlSoundOut1.BufCount := 4;
  FromIni;

  MakeKeyer;
  Keyer.Rate := DEFAULTRATE;
  Keyer.BufSize := Ini.BufSize;

  Panel2.DoubleBuffered := true;
  RichEdit1.Align := alClient;

  // (port add-on) SDR-server toggle, created in code so the .lfm is untouched.
  SdrSep := TMenuItem.Create(Self);
  SdrSep.Caption := '-';
  File1.Insert(File1.IndexOf(Exit1), SdrSep);
  SdrMenu := TMenuItem.Create(Self);
  SdrMenu.Caption := 'SDR Server (HPSDR :1024)';
  SdrMenu.OnClick := SdrServerClick;
  File1.Insert(File1.IndexOf(Exit1), SdrMenu);

  ApiMenu := TMenuItem.Create(Self);
  ApiMenu.Caption := 'Test Control API (:7300)';
  ApiMenu.OnClick := ControlApiClick;
  File1.Insert(File1.IndexOf(Exit1), ApiMenu);

  MasterMenu := TMenuItem.Create(Self);
  MasterMenu.Caption := 'Import Master.dta call database...';
  MasterMenu.OnClick := ImportMasterClick;
  File1.Insert(File1.IndexOf(SdrSep), MasterMenu);   // above the SDR/API toggles

  // Settings -> Mute Local Audio (keeps the sim/SDR/API running, speakers silent)
  MuteMenu := TMenuItem.Create(Self);
  MuteMenu.Caption := 'Mute Local Audio';
  MuteMenu.OnClick := MuteLocalClick;
  MuteMenu.Checked := Ini.MuteLocal;
  Settings1.Insert(Settings1.IndexOf(MonLevel1) + 1, MuteMenu);

  // re-CQ pump used by the /scenario endpoint for pileup/wpx modes
  FApiCq := TTimer.Create(Self);
  FApiCq.Interval := 7000;
  FApiCq.Enabled := false;
  FApiCq.OnTimer := ApiCqTimer;

  ApiRegisterDispatch(ApiDispatch);
end;


procedure TMainForm.MuteLocalClick(Sender: TObject);
begin
  Ini.MuteLocal := not Ini.MuteLocal;
  MuteMenu.Checked := Ini.MuteLocal;
  AlSoundOut1.Muted := Ini.MuteLocal;   // takes effect immediately, even mid-run
end;


procedure TMainForm.ImportMasterClick(Sender: TObject);
var
  dlg: TOpenDialog;
  dst: string;
begin
  dlg := TOpenDialog.Create(Self);
  try
    dlg.Title := 'Import Master.dta call database';
    dlg.Filter := 'Call database|*.dta;MASTER.DTA;Master.dta|All files|*.*';
    if not dlg.Execute then Exit;
    dst := AppFile('Master.dta');                 // ~/.config/Morse Runner/Master.dta
    with TMemoryStream.Create do
      try LoadFromFile(dlg.FileName); SaveToFile(dst); finally Free; end;
    LoadCallList;                                 // reload from the imported file
    Application.MessageBox(PChar(Format(
      'Imported %d callsigns.'#13#13'From: %s'#13'Saved to: %s',
      [Calls.Count, dlg.FileName, dst])),
      'Import Master.dta', MB_OK or MB_ICONINFORMATION);
  finally
    dlg.Free;
  end;
end;


procedure TMainForm.ControlApiClick(Sender: TObject);
begin
  if FControl = nil then
    begin
    FControl := TControlApi.Create(7300);
    FControl.Start;
    ApiMenu.Checked := true;
    end
  else
    begin
    FreeAndNil(FControl);
    ApiMenu.Checked := false;
    end;
  Application.MessageBox(PChar('Test Control API ' +
    BoolToStr(FControl <> nil, 'ON  http://127.0.0.1:7300/', 'OFF')),
    'Control API', MB_OK or MB_ICONINFORMATION);
end;


procedure TMainForm.ApiCqTimer(Sender: TObject);
begin
  if RunMode <> rmStop then SendMsg(msgCq);   // keep the pileup fed with callers
end;


procedure TMainForm.SdrServerClick(Sender: TObject);
begin
  if SdrActive then SdrStop else SdrStart;
  SdrMenu.Checked := SdrActive;
  Application.MessageBox(PChar(SdrStatus), 'SDR Server', MB_OK or MB_ICONINFORMATION);
end;


procedure TMainForm.FormDestroy(Sender: TObject);
begin
  ToIni;
  Tst.Free;
  DestroyKeyer;
end;



procedure TMainForm.AlSoundOut1BufAvailable(Sender: TObject);
begin
  if AlSoundOut1.Enabled then
    try AlSoundOut1.PutData(Tst.GetAudio); except end;
end;


procedure TMainForm.SendClick(Sender: TObject);
var
  Msg: TStationMessage;
begin
  Msg := TStationMessage((Sender as TComponent).Tag);

  SendMsg(Msg);

  case Msg of
    msgHisCall: CallSent:= true;
    msgNR: NrSent:= true;
    end;
end;



procedure TMainForm.SendMsg(Msg: TStationMessage);
begin
  if Msg = msgHisCall then
    begin
    if Edit1.Text <> '' then Tst.Me.HisCall := Edit1.Text;
    CallSent := true;
    end;

  if Msg = msgNR then  NrSent := true;

  Tst.Me.SendMsg(Msg);
end;


procedure TMainForm.Edit1KeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['A'..'Z', 'a'..'z', '0'..'9', '/', '?', #8]) then Key := #0;
end;

procedure TMainForm.Edit2KeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['0'..'9', #8]) then Key := #0;
end;

procedure TMainForm.Edit3KeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['0'..'9', #8]) then Key := #0;
end;


procedure TMainForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #23: //^W  = Wipe
      WipeBoxes;

    #25: //^Y  = Edit
      ;

    #27: //Esc = Abort send
      begin
      if msgHisCall in Tst.Me.Msg then CallSent := false;
      if msgNR in Tst.Me.Msg then NrSent := false;
      Tst.Me.AbortSend;
      end;

    ';': //<his> <#>
      begin
      SendMsg(msgHisCall);
      SendMsg(msgNr);
      end;

    '.', '+', '[', ',': //TU & Save
      begin
      if not CallSent then SendMsg(msgHisCall);
      SendMsg(msgTU);
      Log.SaveQso;
      end;

    ' ': //next field
      ProcessSpace;

    '\': // = F1
      SendMsg(msgCQ);

    else Exit;
  end;

  Key := #0;
end;


procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_INSERT: //<his> <#>
      begin
      SendMsg(msgHisCall);
      SendMsg(msgNr);
      Key := 0;
      end;

    VK_RETURN: //Save
      ProcessEnter;

    VK_F11:
      WipeBoxes;

    87, 119: //Alt-W  = Wipe
      if GetKeyState(VK_MENU) < 0 then WipeBoxes else Exit;

    VK_UP:
      if GetKeyState(VK_CONTROL) >= 0 then IncRit(1)
      else if RunMode <> rmHst then SetBw(ComboBox2.ItemIndex+1);

    VK_DOWN:
      if GetKeyState(VK_CONTROL) >= 0  then IncRit(-1)
      else if RunMode <> rmHst then SetBw(ComboBox2.ItemIndex-1);

    VK_PRIOR: //PgUp
      IncSpeed;

    VK_NEXT: //PgDn
      DecSpeed;


     VK_F9:
       if (ssAlt in Shift) or  (ssCtrl in Shift) then DecSpeed;

     VK_F10:
       if (ssAlt in Shift) or  (ssCtrl in Shift) then IncSpeed;

    else Exit;
    end;

  Key := 0;
end;


procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_INSERT, VK_RETURN: Key := 0;
    end;
end;


procedure TMainForm.ProcessSpace;
begin
  MustAdvance := false;

  if ActiveControl = Edit1 then
    begin
    if Edit2.Text = '' then Edit2.Text := '599';
    ActiveControl := Edit3;
    end
  else if ActiveControl = Edit2 then
    begin
    if Edit2.Text = '' then Edit2.Text := '599';
    ActiveControl := Edit3;
    end
  else
    ActiveControl := Edit1;
end;


procedure TMainForm.ProcessEnter;
var
  C, N, R: boolean;
begin
  MustAdvance := false;

  if (GetKeyState(VK_CONTROL) or GetKeyState(VK_SHIFT) or GetKeyState(VK_MENU)) < 0
    then begin Log.SaveQso; Exit; end;

  //no QSO in progress, send CQ
  if Edit1.Text = '' then begin SendMsg(msgCq); Exit; end;

  //current state
  C := CallSent;
  N := NrSent;
  R := Edit3.Text <> '';

  //send his call if did not send before, or if call changed
  if (not C) or ((not N) and (not R)) then SendMsg(msgHisCall);
  if not N then SendMsg(msgNR);
  if N and not R then SendMsg(msgQm);

  if R and (C or N)
    then
      begin
      SendMsg(msgTU);
      Log.SaveQso;
      end
    else
      MustAdvance := true;
end;


procedure TMainForm.Edit1Enter(Sender: TObject);
var
  P: integer;
begin
  P := Pos('?', Edit1.Text);
  if P > 1 then
    begin Edit1.SelStart := P-1; Edit1.SelLength := 1; end;
end;


procedure TMainForm.IncSpeed;
begin
  Wpm := Trunc(Wpm / 5) * 5 + 5;
  Wpm := Max(10, Min(120, Wpm));
  SpinEdit1.Value := Wpm;
  Tst.Me.Wpm := Wpm;
end;


procedure TMainForm.DecSpeed;
begin
  Wpm := Ceil(Wpm / 5) * 5 - 5;
  Wpm := Max(10, Min(120, Wpm));
  SpinEdit1.Value := Wpm;
  Tst.Me.Wpm := Wpm;
end;


procedure TMainForm.Edit4Change(Sender: TObject);
begin
  SetMyCall(Trim(Edit4.Text));
end;

procedure TMainForm.SetMyCall(ACall: string);
begin
  Ini.Call := ACall;
  Edit4.Text := ACall;
  Tst.Me.MyCall := ACall;
end;

procedure TMainForm.SetPitch(PitchNo: integer);
begin
  Ini.Pitch := 300 + PitchNo * 50;
  ComboBox1.ItemIndex := PitchNo;
  Tst.Modul.CarrierFreq := Ini.Pitch;
end;


procedure TMainForm.SetBw(BwNo: integer);
begin
  if (BwNo < 0) or (BwNo >= ComboBox2.Items.Count) then Exit;

  Ini.Bandwidth := 100 + BwNo * 50;
  ComboBox2.ItemIndex := BwNo;

  Tst.Filt.Points := Round(0.7 * DEFAULTRATE / Ini.BandWidth);
  Tst.Filt.GainDb := 10 * Log10(500/Ini.Bandwidth);
  Tst.Filt2.Points := Tst.Filt.Points;
  Tst.Filt2.GainDb := Tst.Filt.GainDb;

  UpdateRitIndicator;
end;




procedure TMainForm.ComboBox2Change(Sender: TObject);
begin
  SetBw(ComboBox2.ItemIndex);
end;

procedure TMainForm.ComboBox1Change(Sender: TObject);
begin
  SetPitch(ComboBox1.ItemIndex);
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AlSoundOut1.Enabled := false;
  if AlWavFile1.IsOpen then AlWavFile1.Close;
  if FControl <> nil then FreeAndNil(FControl);
  SdrStop;
end;

procedure TMainForm.SpinEdit1Change(Sender: TObject);
begin
  Ini.Wpm := SpinEdit1.Value;
  Tst.Me.Wpm := Ini.Wpm;
end;

procedure TMainForm.CheckBox1Click(Sender: TObject);
begin
  SetQsk(CheckBox1.Checked);
  ActiveControl := Edit1;
end;

procedure TMainForm.CheckBoxClick(Sender: TObject);
begin
  ReadCheckboxes;
  ActiveControl := Edit1;
end;


procedure TMainForm.ReadCheckboxes;
begin
  Ini.Qrn := CheckBox4.Checked;
  Ini.Qrm := CheckBox3.Checked;
  Ini.Qsb := CheckBox2.Checked;
  Ini.Flutter := CheckBox5.Checked;
  Ini.Lids := CheckBox6.Checked;
end;


procedure TMainForm.SpinEdit2Change(Sender: TObject);
begin
  Ini.Duration := SpinEdit2.Value;
end;

procedure TMainForm.SpinEdit3Change(Sender: TObject);
begin
  Ini.Activity := SpinEdit3.Value;
end;

procedure TMainForm.PaintBox1Paint(Sender: TObject);
begin
  Log.PaintHisto;
end;

procedure TMainForm.Exit1Click(Sender: TObject);
begin
  Close;
end;


procedure TMainForm.WipeBoxes;
begin
  Edit1.Text := '';
  Edit2.Text := '';
  Edit3.Text := '';
  ActiveControl := Edit1;

  CallSent := false;
  NrSent := false;
end;


procedure TMainForm.About1Click(Sender: TObject);
const
  Msg = 'CW CONTEST SIMULATOR'#13#13 +
        'Copyright (C) 2004-2006 Alex Shovkoplyas, VE3NEA'#13#13 +
        've3nea@dxatlas.com'#13;
begin
  Application.MessageBox(Msg, 'Morse Runner 1.68', MB_OK or MB_ICONINFORMATION);
end;


procedure TMainForm.Readme1Click(Sender: TObject);
var
  FileName: string;
begin
  FileName := ExtractFilePath(ParamStr(0)) + 'readme.txt';
  OpenDocument(FileName);
end;


procedure TMainForm.Edit1Change(Sender: TObject);
begin
  if Edit1.Text = '' then NrSent := false;
  if not Tst.Me.UpdateCallInMessage(Edit1.Text)
    then CallSent := false;
end;


procedure TMainForm.RunMNUClick(Sender: TObject);
begin
  Run(TRunMode((Sender as TComponent).Tag));
end;


procedure TMainForm.Edit2Enter(Sender: TObject);
begin
  if Length(Edit2.Text) = 3 then
    begin Edit2.SelStart := 1; Edit2.SelLength := 1; end;
end;



procedure TMainForm.EnableCtl(Ctl: TWinControl; AEnable: boolean);
const
  Clr: array[boolean] of TColor = (clBtnFace, clWindow);
begin
  Ctl.Enabled := AEnable;
  if Ctl is TSpinEdit then (Ctl as TSpinEdit).Color := Clr[AEnable]
  else if Ctl is TEdit then (Ctl as TEdit).Color := Clr[AEnable];
end;


procedure TMainForm.Run(Value: TRunMode);
const
  Title: array[TRunMode] of string =
    ('', 'Pile-Up', 'Single Calls', 'COMPETITION', 'H S T');
var
  BCompet, BStop: boolean;
begin
  if Value = Ini.RunMode then Exit;

  BStop := Value = rmStop;
  BCompet := Value in [rmWpx, rmHst];
  RunMode := Value;

  //main ctls
  EnableCtl(Edit4,  BStop);
  EnableCtl(SpinEdit2, BStop);
  SetToolbuttonDown(ToolButton1, not BStop);

  //condition checkboxes
  EnableCtl(CheckBox2, not BCompet);
  EnableCtl(CheckBox3, not BCompet);
  EnableCtl(CheckBox4, not BCompet);
  EnableCtl(CheckBox5, not BCompet);
  EnableCtl(CheckBox6, not BCompet);
  if RunMode = rmWpx then
    begin
    CheckBox2.Checked := true;
    CheckBox3.Checked := true;
    CheckBox4.Checked := true;
    CheckBox5.Checked := true;
    CheckBox6.Checked := true;
    SpinEdit2.Value := CompDuration;
    end
  else if RunMode = rmHst then
    begin
    CheckBox2.Checked := false;
    CheckBox3.Checked := false;
    CheckBox4.Checked := false;
    CheckBox5.Checked := false;
    CheckBox6.Checked := false;
    SpinEdit2.Value := CompDuration;
    end;

  //button menu
  PileupMNU.Enabled := BStop;
  SingleCallsMNU.Enabled := BStop;
  CompetitionMNU.Enabled := BStop;
  HSTCompetition1.Enabled := BStop;
  StopMNU.Enabled := not BStop;

  //main menu
  PileUp1.Enabled := BStop;
  SingleCalls1.Enabled := BStop;
  Competition1.Enabled := BStop;
  HSTCompetition2.Enabled := BStop;
  Stop1MNU.Enabled := not BStop;

  Call1.Enabled := BStop;
  Duration1.Enabled := BStop;
  QRN1.Enabled := not BCompet;
  QRM1.Enabled := not BCompet;
  QSB1.Enabled := not BCompet;
  Flutter1.Enabled := not BCompet;
  Lids1.Enabled := not BCompet;



  //hst specific
  Activity1.Enabled := Value <> rmHst;
  CWBandwidth2.Enabled := Value <> rmHst;

  EnableCtl(SpinEdit3, RunMode <> rmHst);
  if RunMode = rmHst then SpinEdit3.Value := 4;

  EnableCtl(ComboBox2, RunMode <> rmHst);
  if RunMode = rmHst then begin ComboBox2.ItemIndex :=10; SetBw(10); end;

  if RunMode = rmHst then ListView1.Visible := false
  else if RunMode <> rmStop then ListView1.Visible := true;


  //mode caption
  Panel4.Caption := Title[Value];
  if BCompet
    then Panel4.Font.Color := clRed else Panel4.Font.Color := clGreen;

  if not BStop then
    begin
    Tst.Me.AbortSend;
    Tst.BlockNumber := 0;
    Tst.Me.Nr := 1;
    Log.Clear;
    ApiResetLog;                  // fresh ground-truth call log for this run
    WipeBoxes;
    RichEdit1.Visible := true;
    {! ?}Panel5.Update;
    end;

  if not BStop then IncRit(0);



  if BStop
    then
      begin
      if AlWavFile1.IsOpen then AlWavFile1.Close;
      end
    else
      begin
      AlWavFile1.FileName := AppFile('MorseRunner.wav');
      if SaveWav then AlWavFile1.OpenWrite;
      end;

  AlSoundOut1.Enabled := not BStop;
end;



procedure TMainForm.RunBtnClick(Sender: TObject);
begin
  if RunMode = rmStop
    then Run(rmPileUp)
    else Tst.FStopPressed := true;
end;


procedure TMainForm.SetToolbuttonDown(Toolbutton: TToolbutton; ADown: boolean);
begin
  // (port) the original posted WM_TBDOWN to defer this assignment; LCL has no
  // such re-entrancy problem so we set it directly.
  Toolbutton.Down := ADown;
end;



procedure TMainForm.PopupScoreWpx;
var
  S, FName: string;
  Score: integer;
begin
  S := Format('%s %s %s %s ', [
    FormatDateTime('yyyy-mm-dd', Now),
    Ini.Call,
    ListView1.Items[0].SubItems[1],
    ListView1.Items[1].SubItems[1]]);

  S := S + '[' + IntToHex(CalculateCRC32(S, $C90C2086), 8) + ']';


  FName := AppFile('MorseRunner.lst');
  with TStringList.Create do
    try
      if FileExists(FName) then LoadFromFile(FName);
      Add(S);
      SaveToFile(FName);
    finally Free; end;

  ScoreDialog.Edit1.Text := S;


  Score := StrToIntDef(ListView1.Items[2].SubItems[1], 0);
  if Score > HiScore
    then ScoreDialog.Height := 192
    else ScoreDialog.Height := 129;
  HiScore := Max(HiScore, Score);
  ScoreDialog.ShowModal;
end;


procedure TMainForm.PopupScoreHst;
var
  S: string;
  FName: TFileName;
begin
  S := Format('%s'#9'%s'#9'%s'#9'%s', [
    FormatDateTime('yyyy-mm-dd hh:nn', Now),
    Ini.Call,
    Ini.HamName,
    Panel11.Caption]);

  FName := AppFile('HstResults.txt');
  with TStringList.Create do
    try
      if FileExists(FName) then LoadFromFile(FName);
      Add(S);
      SaveToFile(FName);
    finally Free; end;

  ShowMessage('HST Score: ' + ListView1.Items[2].SubItems[1]);
end;


procedure OpenWebPage(Url: string);
begin
  OpenURL(Url);
end;


procedure TMainForm.ViewScoreBoardMNUClick(Sender: TObject);
begin
  OpenWebPage('http://www.dxatlas.com/MorseRunner/MrScore.asp');
end;

procedure TMainForm.ViewScoreTable1Click(Sender: TObject);
var
  FName: string;
begin
  RichEdit1.Clear;
  FName := AppFile('MorseRunner.lst');
  if FileExists(FName)
    then RichEdit1.Lines.LoadFromFile(FName)
    else RichEdit1.Lines.Add('Your score table is empty');
  RichEdit1.Visible := true;
end;


procedure TMainForm.Panel8MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if X < Shape2.Left then IncRit(-1)
  else if X > (Shape2.Left + Shape2.Width) then IncRit(1);
end;


procedure TMainForm.Shape2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  IncRit(0);
end;


procedure TMainForm.IncRit(dF: integer);
begin
  case dF of
   -1: Inc(Ini.Rit, -50);
    0: Ini.Rit := 0;
    1: Inc(Ini.Rit, 50);
    end;

  Ini.Rit := Min(500, Max(-500, Ini.Rit));
  UpdateRitIndicator;
end;


procedure TMainForm.UpdateRitIndicator;
begin
  Shape2.Width := Ini.Bandwidth div 9;
  Shape2.Left := ((Panel8.Width - Shape2.Width) div 2) + (Ini.Rit div 9);
end;


procedure TMainForm.Advance;
begin
  if not MustAdvance then Exit;

  if Edit2.Text = '' then Edit2.Text := '599';

  if Pos('?', Edit1.Text) = 0 then ActiveControl := Edit3
  else if ActiveControl = Edit1 then Edit1Enter(nil)
  else ActiveControl := Edit1;

  MustAdvance := false;
end;



procedure TMainForm.VolumeSliderDblClick(Sender: TObject);
begin
  with Sender as TVolumeSlider do
    begin
    Value := 0.75;
    OnChange(Sender);
    end;
end;

procedure TMainForm.VolumeSlider1Change(Sender: TObject);
begin
  with VolumeSlider1 do
    begin
    //-60..+20 dB
    Db := 80 * (Value - 0.75);
    if dB > 0
      then Hint := Format('+%.0f dB', [dB])
      else Hint := Format( '%.0f dB', [dB]);
    end;
end;


procedure TMainForm.WebPage1Click(Sender: TObject);
begin
  OpenWebPage('http://www.dxatlas.com/MorseRunner');
end;




//------------------------------------------------------------------------------
//                              accessibility
//------------------------------------------------------------------------------
procedure TMainForm.Call1Click(Sender: TObject);
begin
  SetMyCall(Trim(InputBox('Callsign', 'Callsign', Edit4.Text)));
end;


procedure TMainForm.SetQsk(Value: boolean);
begin
  Qsk := Value;
  CheckBox1.Checked := Qsk;
end;


procedure TMainForm.QSK1Click(Sender: TObject);
begin
  SetQsk(not QSK1.Checked);
end;


procedure TMainForm.NWPMClick(Sender: TObject);
begin
  Wpm := (Sender as TMenuItem).Tag;
  Wpm := Max(10, Min(120, Wpm));
  SpinEdit1.Value := Wpm;
  Tst.Me.Wpm := Wpm;
end;



procedure TMainForm.Pitch1Click(Sender: TObject);
begin
  SetPitch((Sender as TMenuItem).Tag);

end;

procedure TMainForm.Bw1Click(Sender: TObject);
begin
  SetBw((Sender as TMenuItem).Tag);
end;

procedure TMainForm.File1Click(Sender: TObject);
var
  Stp: boolean;
begin
  Stp := RunMode = rmStop;

  AudioRecordingEnabled1.Enabled := Stp;
  PlayRecordedAudio1.Enabled := Stp and FileExists(AppFile('MorseRunner.wav'));

  AudioRecordingEnabled1.Checked := Ini.SaveWav;
end;

procedure TMainForm.PlayRecordedAudio1Click(Sender: TObject);
var
  FileName: string;
begin
  FileName := AppFile('MorseRunner.wav');
  OpenDocument(FileName);
end;


procedure TMainForm.AudioRecordingEnabled1Click(Sender: TObject);
begin
  Ini.SaveWav := not Ini.SaveWav;
end;



procedure TMainForm.SelfMonClick(Sender: TObject);
begin
  VolumeSlider1.Value := (Sender as TMenuItem).Tag / 80 + 0.75;
  VolumeSlider1.OnChange(Sender);
end;

procedure TMainForm.Settings1Click(Sender: TObject);
begin
  QSK1.Checked := Ini.Qsk;
  QRN1.Checked := Ini.Qrn;
  QRM1.Checked := Ini.Qrm;
  QSB1.Checked := Ini.Qsb;
  Flutter1.Checked := Ini.Flutter;
  LIDS1.Checked := Ini.Lids;
end;

//ALL checkboxes
procedure TMainForm.LIDS1Click(Sender: TObject);
begin
  with Sender as TMenuItem do Checked := not Checked;

  CheckBox4.Checked := QRN1.Checked;
  CheckBox3.Checked := QRM1.Checked;
  CheckBox2.Checked := QSB1.Checked;
  CheckBox5.Checked := Flutter1.Checked;
  CheckBox6.Checked := LIDS1.Checked;

  ReadCheckboxes;
end;



procedure TMainForm.Activity1Click(Sender: TObject);
begin
  Ini.Activity := (Sender as TMenuItem).Tag;
  SpinEdit3.Value := Ini.Activity;
end;


procedure TMainForm.Duration1Click(Sender: TObject);
begin
  Ini.Duration := (Sender as TMenuItem).Tag;
  SpinEdit2.Value := Ini.Duration;
end;


procedure TMainForm.Operator1Click(Sender: TObject);
begin
  HamName := InputBox('HST Operator', 'Enter operator''s name', HamName);

  if HamName <> ''
    then Caption := 'Morse Runner:  ' + HamName
    else Caption := 'Morse Runner';

  with TIniFile.Create(AppFile('MorseRunner.ini')) do
    try WriteString(SEC_STN, 'Name', HamName);
    finally Free; end;
end;

procedure TMainForm.StopMNUClick(Sender: TObject);
begin
  Tst.FStopPressed := true;
end;


//------------------------------------------------------------------------------
//        control API — maps action names to the same operations the UI uses.
//        Runs on the main thread (invoked via TThread.Synchronize).
//------------------------------------------------------------------------------
function TMainForm.ApiDispatch(const Action: string; Params: TJSONObject): TJSONObject;
var
  vErr: string;

  function OkObj: TJSONObject;
  begin Result := TJSONObject.Create; Result.Add('ok', true); end;

  function ErrObj(const Msg: string): TJSONObject;
  begin Result := TJSONObject.Create; Result.Add('ok', false); Result.Add('error', Msg); end;

  // Bounds-check every provided setting. Returns '' if all in range, else a
  // message naming the offending param and its valid range. Unlike the old
  // silent clamp, out-of-range values are REJECTED — ControlApi turns a
  // non-empty error into HTTP 400.
  function ValidateSettings(P: TJSONObject): string;
    function Chk(const Name: string; Lo, Hi: integer): string;
    var v: integer;
    begin
      Result := '';
      if P.Find(Name) <> nil then
        begin
        v := P.Get(Name, Lo);
        if (v < Lo) or (v > Hi) then
          Result := Format('%s=%d out of range [%d..%d]', [Name, v, Lo, Hi]);
        end;
    end;
  begin
    Result := '';
    if P = nil then Exit;
    Result := Chk('wpm', 10, 120);          if Result <> '' then Exit;
    Result := Chk('pitchHz', 300, 900);     if Result <> '' then Exit;
    Result := Chk('bandwidthHz', 100, 600); if Result <> '' then Exit;
    Result := Chk('activity', 1, 9);        if Result <> '' then Exit;
    Result := Chk('rit', -500, 500);        if Result <> '' then Exit;
    Result := Chk('spreadHz', 0, 3000);     if Result <> '' then Exit;
  end;

  function ModeFromStr(const s: string): TRunMode;
  begin
    if s = 'pileup' then Result := rmPileup
    else if s = 'single' then Result := rmSingle
    else if s = 'wpx' then Result := rmWpx
    else if s = 'hst' then Result := rmHst
    else Result := rmStop;
  end;

  function ModeStr: string;
  begin
    case RunMode of
      rmPileup: Result := 'pileup';
      rmSingle: Result := 'single';
      rmWpx: Result := 'wpx';
      rmHst: Result := 'hst';
    else Result := 'stop';
    end;
  end;

  function MsgFromStr(const s: string): TStationMessage;
  begin
    if s = 'nr' then Result := msgNR
    else if s = 'tu' then Result := msgTU
    else if s = 'mycall' then Result := msgMyCall
    else if s = 'hiscall' then Result := msgHisCall
    else if s = 'b4' then Result := msgB4
    else if s = 'qm' then Result := msgQm
    else if s = 'nil' then Result := msgNil
    else if s = 'agn' then Result := msgAgn
    else Result := msgCQ;
  end;

  procedure ApplySettings(P: TJSONObject);
  begin
    if P = nil then Exit;
    if P.Find('call') <> nil then SetMyCall(UpperCase(Trim(P.Get('call', Ini.Call))));
    if P.Find('wpm') <> nil then
      begin
      Wpm := Max(10, Min(120, P.Get('wpm', Wpm)));
      SpinEdit1.Value := Wpm; Ini.Wpm := Wpm; Tst.Me.Wpm := Wpm;
      end;
    if P.Find('pitchHz') <> nil then SetPitch(Max(0, Min(12, (P.Get('pitchHz', 600) - 300) div 50)));
    if P.Find('bandwidthHz') <> nil then SetBw(Max(0, Min(10, (P.Get('bandwidthHz', 500) - 100) div 50)));
    if P.Find('spreadHz') <> nil then Ini.PitchSpread := P.Get('spreadHz', Ini.PitchSpread);
    if P.Find('qsk') <> nil then SetQsk(P.Get('qsk', Qsk));
    if P.Find('activity') <> nil then
      begin Ini.Activity := Max(1, Min(9, P.Get('activity', Activity))); SpinEdit3.Value := Ini.Activity; end;
    if P.Find('rit') <> nil then begin Ini.Rit := Max(-500, Min(500, P.Get('rit', 0))); UpdateRitIndicator; end;
    if P.Find('qrn') <> nil then CheckBox4.Checked := P.Get('qrn', Ini.Qrn);
    if P.Find('qrm') <> nil then CheckBox3.Checked := P.Get('qrm', Ini.Qrm);
    if P.Find('qsb') <> nil then CheckBox2.Checked := P.Get('qsb', Ini.Qsb);
    if P.Find('flutter') <> nil then CheckBox5.Checked := P.Get('flutter', Ini.Flutter);
    if P.Find('lids') <> nil then CheckBox6.Checked := P.Get('lids', Ini.Lids);
    if P.Find('muteLocal') <> nil then
      begin
      Ini.MuteLocal := P.Get('muteLocal', Ini.MuteLocal);
      MuteMenu.Checked := Ini.MuteLocal;
      AlSoundOut1.Muted := Ini.MuteLocal;
      end;
    ReadCheckboxes;
  end;

  function BuildState: TJSONObject;
  var sc: TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.Add('call', Ini.Call);
    Result.Add('wpm', Ini.Wpm);
    Result.Add('pitchHz', Ini.Pitch);
    Result.Add('bandwidthHz', Ini.Bandwidth);
    Result.Add('spreadHz', Ini.PitchSpread);
    Result.Add('activity', Ini.Activity);
    Result.Add('rit', Ini.Rit);
    Result.Add('qrn', Ini.Qrn);   Result.Add('qrm', Ini.Qrm);
    Result.Add('qsb', Ini.Qsb);   Result.Add('flutter', Ini.Flutter);
    Result.Add('lids', Ini.Lids);
    Result.Add('muteLocal', Ini.MuteLocal);
    Result.Add('runMode', ModeStr);
    Result.Add('running', RunMode <> rmStop);
    Result.Add('timeSec', BlocksToSeconds(Tst.BlockNumber));
    Result.Add('callCount', ApiCallCount);
    sc := TJSONObject.Create;
    sc.Add('rawPts',   StrToIntDef(ListView1.Items[0].SubItems[0], 0));
    sc.Add('rawMult',  StrToIntDef(ListView1.Items[1].SubItems[0], 0));
    sc.Add('rawScore', StrToIntDef(ListView1.Items[2].SubItems[0], 0));
    sc.Add('verPts',   StrToIntDef(ListView1.Items[0].SubItems[1], 0));
    sc.Add('verMult',  StrToIntDef(ListView1.Items[1].SubItems[1], 0));
    sc.Add('verScore', StrToIntDef(ListView1.Items[2].SubItems[1], 0));
    Result.Add('score', sc);
  end;

begin
  if Action = 'state' then
    Result := BuildState
  else if Action = 'set' then
    begin
    vErr := ValidateSettings(Params);
    if vErr <> '' then Result := ErrObj(vErr)
    else begin ApplySettings(Params); Result := BuildState; end;
    end
  else if Action = 'run' then
    begin
    if (Params <> nil) and (ModeFromStr(Params.Get('mode', 'stop')) = rmStop) then FApiCq.Enabled := false;
    if Params <> nil then Run(ModeFromStr(Params.Get('mode', 'stop'))) else Run(rmStop);
    Result := OkObj;
    end
  else if Action = 'stop' then
    begin FApiCq.Enabled := false; Run(rmStop); Result := OkObj; end
  else if Action = 'send' then
    begin
    if Params <> nil then SendMsg(MsgFromStr(Params.Get('msg', 'cq'))) else SendMsg(msgCQ);
    Result := OkObj;
    end
  else if Action = 'enter' then
    begin
    if Params <> nil then
      begin
      if Params.Find('call') <> nil then Edit1.Text := UpperCase(Params.Find('call').AsString);
      if Params.Find('rst') <> nil then Edit2.Text := Params.Find('rst').AsString;
      if Params.Find('nr') <> nil then Edit3.Text := Params.Find('nr').AsString;
      end;
    Result := OkObj;
    end
  else if Action = 'saveQso' then
    begin Log.SaveQso; Result := OkObj; end
  else if Action = 'wipe' then
    begin WipeBoxes; Result := OkObj; end
  else if Action = 'scenario_start' then
    begin
    vErr := ValidateSettings(Params);
    if vErr <> '' then begin Result := ErrObj(vErr); Exit; end;
    ApplySettings(Params);
    Run(rmStop);                                       // clean slate
    Run(ModeFromStr(Params.Get('mode', 'single')));    // resets the call log
    if RunMode in [rmPileup, rmWpx] then
      begin SendMsg(msgCQ); FApiCq.Enabled := true; end
    else
      FApiCq.Enabled := false;
    Result := OkObj;
    end
  else
    begin Result := TJSONObject.Create; Result.Add('error', 'unknown action: ' + Action); end;
end;

end.
