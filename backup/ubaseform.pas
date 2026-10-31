unit uBaseForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, Graphics, uSettings, Math;

const
  DOT_D         = 16;
  SpawnChance   = 65;
  FadeInStep    = 40;
  FadeOutStep   = 6;
  MAX_BANDS     = 10;
  BAND_SIZE_MIN = 5;   { в ячейках сетки }
  BAND_SIZE_MAX = 60;
  BAND_FADE_STEP = 25;

type
  TUpdateGridProc = procedure(const FormName: String; COLS, ROWS, IMG_W, IMG_H: Integer);

  TStarColor = record
    R, G, B: Byte;
  end;

  { Лента: движется по сетке COLS x ROWS, одноцветная с градиентом от головы до хвоста }
  { Direction: 0 = вправо, 1 = вниз, 2 = влево, 3 = вверх }
  TBandData = record
    CellX1, CellY1: Integer;   { начало в сетке }
    CellW, CellH: Integer;     { размер в ячейках }
    SpeedX, SpeedY: Integer;   { скорость в ячейках/кадр }
    Direction: Integer;        { 0=вправо, 1=вниз, 2=влево, 3=вверх }
    Fade: Integer;             { 0..255 fade-in при появлении }
    BandR, BandG, BandB: Byte; { единый цвет ленты }
  end;

  TBaseForm = class(TForm)
  private
    FReady: Boolean;
    FIsFullScreen: Boolean;
    FPendingName: String;
    FPendingMonitor: Integer;
    FSavedState: TFormState;
    Image: TImage;
    StarColor:  array of array of TStarColor;
    StarBright: array of array of Integer;
    StarState:  array of array of Integer;
    IMG_W, IMG_H: Integer;
    CELL_W, CELL_H: Integer;
    COLS, ROWS: Integer;
    FOldBorderStyle: TFormBorderStyle;
    FOldLeft, FOldTop, FOldWidth, FOldHeight: Integer;
    FUpdateGrid: TUpdateGridProc;
    Bands: array of TBandData;
    BandsCount: Integer;
    function GetCenteredIndex(MaxVal: Integer): Integer;
    procedure InitStarArrays;
    procedure RecalcGrid;
    procedure TrySpawnBand;
    procedure SpawnBand(var B: TBandData);
    procedure DrawBand(const Bmp: TBitmap; const B: TBandData);
    procedure DoImageDblClick(Sender: TObject);
    procedure DoResizeEvent(Sender: TObject);
    procedure DoChangeBounds(Sender: TObject);
    procedure DoClose(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor CreateForMonitor(AOwner: TComponent; AMonitorIndex: Integer;
      const AFormName: String; AUpdateGrid: TUpdateGridProc);
    destructor Destroy; override;
    procedure UpdateBands;
    procedure DoCreate; override;
  end;

implementation

constructor TBaseForm.CreateForMonitor(AOwner: TComponent;
  AMonitorIndex: Integer; const AFormName: String; AUpdateGrid: TUpdateGridProc);
begin
  FPendingName := AFormName;
  FPendingMonitor := AMonitorIndex;
  FUpdateGrid := AUpdateGrid;
  FReady := False;
  BandsCount := 0;
  inherited CreateNew(nil);
end;

destructor TBaseForm.Destroy;
begin
  if FReady then
  begin
    FSavedState.saveIsFullScreen := FIsFullScreen;
    if (WindowState = wsNormal) and not FIsFullScreen then
    begin
      FSavedState.saveLeft := Left;
      FSavedState.saveTop := Top;
      FSavedState.saveWidth := Width;
      FSavedState.saveHeight := Height;
    end;
    SaveFormState(Name, FSavedState);
  end;
  inherited;
end;

procedure TBaseForm.InitStarArrays;
var
  y, x: Integer;
begin
  for y := 0 to High(StarColor) do
    for x := 0 to High(StarColor[y]) do
    begin
      StarState[y, x]  := 0;
      StarBright[y, x] := 0;
      StarColor[y, x].R := 0;
      StarColor[y, x].G := 0;
      StarColor[y, x].B := 0;
    end;
end;

procedure TBaseForm.RecalcGrid;
begin
  COLS := Image.Width div DOT_D;
  ROWS := Image.Height div DOT_D;
  if COLS < 1 then COLS := 1;
  if ROWS < 1 then ROWS := 1;
  CELL_W := DOT_D;
  CELL_H := DOT_D;
  IMG_W := COLS * DOT_D;
  IMG_H := ROWS * DOT_D;
  SetLength(StarColor, ROWS, COLS);
  SetLength(StarBright, ROWS, COLS);
  SetLength(StarState, ROWS, COLS);
  InitStarArrays;
  Image.Picture.Bitmap.Width  := IMG_W;
  Image.Picture.Bitmap.Height := IMG_H;
  with Image.Picture.Bitmap.Canvas do
  begin
    Brush.Color := clBlack;
    FillRect(0, 0, IMG_W, IMG_H);
  end;
  SetLength(Bands, 0);
  BandsCount := 0;
  if Assigned(FUpdateGrid) then
    FUpdateGrid(Name, COLS, ROWS, IMG_W, IMG_H);
end;

function TBaseForm.GetCenteredIndex(MaxVal: Integer): Integer;
var
  r1, r2: Integer;
begin
  r1 := Random(MaxVal);
  r2 := Random(MaxVal);
  Result := (r1 + r2) div 2;
  if Result < 0 then Result := 0;
  if Result >= MaxVal then Result := MaxVal - 1;
end;

{ Спавн / рециклинг ленты. 4 направления: вправо/вниз/влево/вверх }
procedure TBaseForm.SpawnBand(var B: TBandData);
begin
  B.Direction := Random(4);
  B.Fade := 0;
  B.CellW := BAND_SIZE_MIN + Random(BAND_SIZE_MAX - BAND_SIZE_MIN + 1);
  B.CellH := B.CellW;
  B.SpeedX := 1;
  B.SpeedY := 1;
  B.BandR := 100 + Random(156);
  B.BandG := 100 + Random(156);
  B.BandB := 100 + Random(156);
  case B.Direction of
    0: begin { Вправо } B.CellY1 := Random(ROWS); B.CellX1 := -B.CellW; end;
    1: begin { Вниз }   B.CellX1 := Random(COLS); B.CellY1 := -B.CellH; end;
    2: begin { Влево }  B.CellY1 := Random(ROWS); B.CellX1 := COLS;     end;
    3: begin { Вверх }  B.CellX1 := Random(COLS); B.CellY1 := ROWS;     end;
  end;
end;

procedure TBaseForm.TrySpawnBand;
begin
  if BandsCount >= MAX_BANDS then Exit;
  SetLength(Bands, BandsCount + 1);
  SpawnBand(Bands[BandsCount]);
  Inc(BandsCount);
end;

{ Рисуем ленту: 4 направления движения.
  Голова (яркая) всегда в сторону движения, хвост (тусклый) — сзади }
procedure TBaseForm.DrawBand(const Bmp: TBitmap; const B: TBandData);
var
  i, head, tail, lo, hi: Integer;
  t: Single;
  intensity: Single;
  cR, cG, cB: Integer;
begin
  { Определяем голову (яркую) и хвост (тусклый) }
  case B.Direction of
    0: begin { Вправо } head := B.CellX1 + B.CellW - 1; tail := B.CellX1; end;
    2: begin { Влево }  head := B.CellX1;             tail := B.CellX1 + B.CellW - 1; end;
    1: begin { Вниз }   head := B.CellY1 + B.CellH - 1; tail := B.CellY1; end;
    else begin { Вверх } head := B.CellY1;               tail := B.CellY1 + B.CellH - 1; end;
  end;

  lo := Min(head, tail);
  hi := Max(head, tail);

  case B.Direction of
    0, 2: { Горизонтальная полоска }
      begin
        for i := lo to hi do
        begin
          if (i < 0) or (i >= COLS) then Continue;
          if hi > lo then t := Abs(i - head) / (hi - lo) else t := 0;
          intensity := B.Fade * (1.0 - t) / 255.0;
          cR := Round(B.BandR * intensity);
          cG := Round(B.BandG * intensity);
          cB := Round(B.BandB * intensity);
          Bmp.Canvas.Brush.Color := RGBToColor(cR, cG, cB);
          Bmp.Canvas.FillRect(
            i * CELL_W, B.CellY1 * CELL_H,
            i * CELL_W + CELL_W, (B.CellY1 + 1) * CELL_H);
        end;
      end;
    else { Вертикальная полоска }
      begin
        for i := lo to hi do
        begin
          if (i < 0) or (i >= ROWS) then Continue;
          if hi > lo then t := Abs(i - head) / (hi - lo) else t := 0;
          intensity := B.Fade * (1.0 - t) / 255.0;
          cR := Round(B.BandR * intensity);
          cG := Round(B.BandG * intensity);
          cB := Round(B.BandB * intensity);
          Bmp.Canvas.Brush.Color := RGBToColor(cR, cG, cB);
          Bmp.Canvas.FillRect(
            B.CellX1 * CELL_W, i * CELL_H,
            (B.CellX1 + 1) * CELL_W, i * CELL_H + CELL_H);
        end;
      end;
  end;
end;

procedure TBaseForm.DoCreate;
var
  MonIdx: Integer;
  SI: TScreenInfo;
  St: TFormState;
  Mon: TMonitor;
begin
  if FPendingName <> '' then
    Name := FPendingName;
  BorderStyle := bsSizeable;
  Position := poDesigned;
  Color := clBlack;
  FIsFullScreen := False;
  inherited DoCreate;
  MonIdx := FPendingMonitor;
  if (MonIdx < 0) or (MonIdx >= Screen.MonitorCount) then
    MonIdx := 0;
  Mon := Screen.Monitors[MonIdx];
  SI := GetScreenInfo(MonIdx);
  Width  := 800;
  Height := 480;
  Left := Mon.Left + (Mon.Width - Width) div 2;
  Top  := Mon.Top  + (Mon.Height - Height) div 2;
  St := GetFormState(Name);
  if (St.saveLeft >= 0) and (St.saveTop >= 0) and
     (St.saveWidth > 0) and (St.saveHeight > 0) then
  begin
    Left   := St.saveLeft;
    Top    := St.saveTop;
    Width  := St.saveWidth;
    Height := St.saveHeight;
  end;
  FOldLeft   := Left;
  FOldTop    := Top;
  FOldWidth  := Width;
  FOldHeight := Height;
  FOldBorderStyle := BorderStyle;
  FSavedState := St;
  FSavedState.saveMonitor := MonIdx;
  if St.saveIsFullScreen then
  begin
    FIsFullScreen := True;
    BorderStyle := bsNone;
    WindowState := wsMaximized;
  end;
  Image := TImage.Create(Self);
  Image.Parent := Self;
  Image.Align := alClient;
  Image.Stretch := True;
  Image.OnDblClick := @DoImageDblClick;
  OnResize := @DoResizeEvent;
  OnChangeBounds := @DoChangeBounds;
  OnClose := @DoClose;
  RecalcGrid;
  FReady := True;
end;

procedure TBaseForm.DoResizeEvent(Sender: TObject);
begin
  if not FReady then Exit;
  RecalcGrid;
end;

procedure TBaseForm.DoImageDblClick(Sender: TObject);
begin
  if FIsFullScreen then
  begin
    FIsFullScreen := False;
    WindowState := wsNormal;
    BorderStyle := FOldBorderStyle;
    Left   := FOldLeft;
    Top    := FOldTop;
    Width  := FOldWidth;
    Height := FOldHeight;
    FSavedState.saveLeft := Left;
    FSavedState.saveTop := Top;
    FSavedState.saveWidth := Width;
    FSavedState.saveHeight := Height;
    FSavedState.saveIsFullScreen := False;
  end
  else
  begin
    FIsFullScreen := True;
    FOldLeft   := Left;
    FOldTop    := Top;
    FOldWidth  := Width;
    FOldHeight := Height;
    FOldBorderStyle := BorderStyle;
    BorderStyle := bsNone;
    WindowState := wsMaximized;
    FSavedState.saveIsFullScreen := True;
  end;
  SaveFormState(Name, FSavedState);
end;

procedure TBaseForm.DoChangeBounds(Sender: TObject);
begin
  if not FReady then Exit;
  if (WindowState = wsNormal) and not FIsFullScreen then
  begin
    FSavedState.saveLeft := Left;
    FSavedState.saveTop := Top;
    FSavedState.saveWidth := Width;
    FSavedState.saveHeight := Height;
    FSavedState.saveIsFullScreen := False;
    SaveFormState(Name, FSavedState);
  end;
end;

procedure TBaseForm.DoClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
  FSavedState.saveIsFullScreen := FIsFullScreen;
  if (WindowState = wsNormal) and not FIsFullScreen then
  begin
    FSavedState.saveLeft := Left;
    FSavedState.saveTop := Top;
    FSavedState.saveWidth := Width;
    FSavedState.saveHeight := Height;
  end;
  SaveFormState(Name, FSavedState);
end;

{ Главный цикл: звёзды (фон) + движущиеся по сетке одноцветные ленты с градиентом }
procedure TBaseForm.UpdateBands;
var
  count, x, y: Integer;
  cR, cG, cB: Integer;
  cx, cy, xL, yT, xR, yB: Integer;
  i: Integer;
  Bmp: TBitmap;
begin
  if not FReady then Exit;
  if not Assigned(Image) then Exit;
  Bmp := Image.Picture.Bitmap;

  with Bmp.Canvas do
  begin
    Brush.Color := clBlack;
    FillRect(0, 0, IMG_W, IMG_H);
  end;

  // --- Звёзды (фон) ---
  for count := 1 to 5 do
  begin
    if Random(100) < SpawnChance then
    begin
      y := Random(ROWS);
      x := Random(COLS);
      if StarState[y, x] = 0 then
      begin
        StarColor[y, x].R := Random(256);
        StarColor[y, x].G := Random(256);
        StarColor[y, x].B := Random(256);
        StarBright[y, x] := 0;
        StarState[y, x]  := 1;
      end;
    end;
  end;

  for y := 0 to High(StarColor) do
    for x := 0 to High(StarColor[y]) do
    begin
      case StarState[y, x] of
        1: begin
             Inc(StarBright[y, x], FadeInStep);
             if StarBright[y, x] >= 255 then
             begin
               StarBright[y, x] := 255;
               StarState[y, x]  := 2;
             end;
           end;
        2: begin
             Dec(StarBright[y, x], FadeOutStep);
             if StarBright[y, x] <= 0 then
             begin
               StarBright[y, x] := 0;
               StarState[y, x]  := 0;
             end;
           end;
      end;
      if StarState[y, x] = 0 then Continue;
      cR := (StarColor[y, x].R * StarBright[y, x]) div 255;
      cG := (StarColor[y, x].G * StarBright[y, x]) div 255;
      cB := (StarColor[y, x].B * StarBright[y, x]) div 255;
      if (cR = 0) and (cG = 0) and (cB = 0) then Continue;
      cx := x * CELL_W + CELL_W div 2;
      cy := y * CELL_H + CELL_H div 2;
      xL := cx - DOT_D div 2;
      yT := cy - DOT_D div 2;
      xR := xL + DOT_D;
      yB := yT + DOT_D;
      Bmp.Canvas.Brush.Color := RGBToColor(cR, cG, cB);
      Bmp.Canvas.Ellipse(xL, yT, xR, yB);
    end;

  // --- Движущиеся по сетке одноцветные ленты (4 направления) ---
  TrySpawnBand;
  i := 0;
  while i < BandsCount do
  begin
    // Fade-in при появлении
    if Bands[i].Fade < 255 then
      Inc(Bands[i].Fade, BAND_FADE_STEP);

    // Движение ленты в своём направлении
    case Bands[i].Direction of
      0: begin { Вправо }
            Bands[i].CellX1 := Bands[i].CellX1 + Bands[i].SpeedX;
            if Bands[i].CellX1 > COLS then SpawnBand(Bands[i]);
          end;
      1: begin { Вниз }
            Bands[i].CellY1 := Bands[i].CellY1 + Bands[i].SpeedY;
            if Bands[i].CellY1 > ROWS then SpawnBand(Bands[i]);
          end;
      2: begin { Влево }
            Bands[i].CellX1 := Bands[i].CellX1 - Bands[i].SpeedX;
            if Bands[i].CellX1 < -Bands[i].CellW then SpawnBand(Bands[i]);
          end;
      3: begin { Вверх }
            Bands[i].CellY1 := Bands[i].CellY1 - Bands[i].SpeedY;
            if Bands[i].CellY1 < -Bands[i].CellH then SpawnBand(Bands[i]);
          end;
    end;

    DrawBand(Bmp, Bands[i]);
    Inc(i);
  end;

  Image.Repaint;
end;

end.
