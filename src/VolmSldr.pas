//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// macOS/Lazarus port of VolmSldr.pas (the self-monitor volume slider).
//
// The original drew the thumb/bezel with the Windows GDI helpers DrawEdge and
// DrawFrameControl and floated a custom TPermanentHintWindow (PermHint.pas) to
// keep the dB readout visible while dragging.  Neither is portable, so this port
// paints the same layout (ramp lines + overload box + raised thumb) with plain
// TCanvas primitives and shows the dB value through the standard LCL tooltip
// (Hint/ShowHint).  The value<->dB mapping, drag math and the 0.75 default are
// unchanged, so the self-monitor level behaves exactly as before.
//------------------------------------------------------------------------------
unit VolmSldr;

{$MODE Delphi}{$H+}

interface

uses
  Types, SysUtils, Classes, Graphics, Controls, Math;

type
  TVolumeSlider = class(TGraphicControl)
  private
    FMargin: integer;
    FValue: Single;
    FOnChange: TNotifyEvent;

    FDownValue: Single;
    FDownX: integer;
    FOverloaded: boolean;
    FDbMax: Single;
    FDbScale: Single;

    procedure SetMargin(const Value: integer);
    procedure SetValue(const Value: Single);
    function ThumbRect: TRect;
    procedure SetOverloaded(const Value: boolean);
    procedure SetDbMax(const Value: Single);
    procedure SetDbScale(const Value: Single);
    function GetDb: Single;
    procedure UpdateHint;
    procedure SetDb(const AdB: Single);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Margin: integer read FMargin write SetMargin;
    property Value: Single read FValue write SetValue;
    property Enabled;
    property ShowHint;
    property Overloaded: boolean read FOverloaded write SetOverloaded;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDblClick;

    property DbMax: Single read FDbMax write SetDbMax;
    property DbScale: Single read FDbScale write SetDbScale;
    property Db: Single read GetDb write SetDb;
  end;

procedure Register;

implementation

const
  VMargin = 6;


procedure Register;
begin
  RegisterComponents('Snd', [TVolumeSlider]);
end;

{ TVolumeSlider }

constructor TVolumeSlider.Create(AOwner: TComponent);
begin
  inherited;
  FMargin := 5;
  FValue := 0.75;
  Width := 60;
  Height := 20;
  ControlStyle := [csCaptureMouse, csClickEvents, csDoubleClicks, csOpaque];

  FDbMax := 0;
  FDbScale := 60;
  UpdateHint;
end;


function TVolumeSlider.ThumbRect: TRect;
var
  x: integer;
begin
  x := FMargin + Round((Width - 2 * FMargin) * FValue);
  Result := Rect(x-4, VMargin div 2, x+5, Height - (VMargin div 2) + 1);
end;


procedure TVolumeSlider.Paint;
var
  R: TRect;
begin
  with Canvas do
    begin
    //background
    Brush.Color := clBtnFace;
    Brush.Style := bsSolid;
    FillRect(Rect(0, 0, Width, Height));

    //triangle / ramp (raised look)
    Pen.Color := clWhite;
    MoveTo(FMargin, Height-VMargin);
    LineTo(Width-FMargin, Height-VMargin);
    LineTo(Width-FMargin, VMargin);
    Pen.Color := clBtnShadow;
    LineTo(FMargin-1, Height-VMargin-1);

    //overload indicator box (sunken)
    R := Bounds(FMargin+1, VMargin-2, 7, 5);
    Pen.Color := clBtnShadow;
    Rectangle(R.Left, R.Top, R.Right, R.Bottom);
    if FOverloaded then
      begin
      Brush.Color := clRed;
      InflateRect(R, -1, -1);
      FillRect(R);
      Brush.Color := clBtnFace;
      end;

    //thumb (raised push-button look)
    R := ThumbRect;
    Brush.Color := clBtnFace;
    FillRect(R);
    if Enabled then
      begin
      Pen.Color := clBtnHighlight;
      MoveTo(R.Left, R.Bottom-1); LineTo(R.Left, R.Top); LineTo(R.Right-1, R.Top);
      Pen.Color := clBtnShadow;
      LineTo(R.Right-1, R.Bottom-1); LineTo(R.Left, R.Bottom-1);
      end
    else
      begin
      Pen.Color := clBtnShadow;
      Rectangle(R.Left, R.Top, R.Right, R.Bottom);
      end;
    end;
end;


procedure TVolumeSlider.SetMargin(const Value: integer);
begin
  FMargin := Max(5, Min((Width div 2) - 5, Value));
  Invalidate;
end;


procedure TVolumeSlider.SetValue(const Value: Single);
begin
  FValue := Max(0, Min(1, Value));
  UpdateHint;
  Invalidate;
end;


procedure TVolumeSlider.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if (Button = mbLeft) and PtInRect(ThumbRect, Point(X,Y))
    then begin FDownValue := FValue; FDownX := X; end
    else ControlState := ControlState - [csClicked];
end;


procedure TVolumeSlider.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  if not (ssLeft in Shift) then
    begin
    ControlState := ControlState - [csClicked];
    MouseCapture := false;
    end;

  if not (csClicked in ControlState) then Exit;

  Value := FDownValue + (X - FDownX) / (Width - 2 * FMargin);
  Repaint;
  if Assigned(FOnChange) then FOnChange(Self);
end;


procedure TVolumeSlider.SetOverloaded(const Value: boolean);
begin
  if FOverloaded = Value then Exit;
  FOverloaded := Value;
  Repaint;
end;


procedure TVolumeSlider.SetDbMax(const Value: Single);
begin
  FDbMax := Value;
  UpdateHint;
end;


procedure TVolumeSlider.SetDbScale(const Value: Single);
begin
  FDbScale := Value;
  UpdateHint;
end;


function TVolumeSlider.GetDb: Single;
begin
  Result := FDbMax + (FValue - 1) * FDbScale;
end;


procedure TVolumeSlider.UpdateHint;
begin
  Hint := Format('%.1f dB', [Db]);
end;


procedure TVolumeSlider.SetDb(const AdB: Single);
begin
  Value := (AdB - FDbMax) / FDbScale + 1;
end;


end.
