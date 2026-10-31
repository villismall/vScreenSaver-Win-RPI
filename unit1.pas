unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, uBaseForm, uSettings;

type

  { TForm1 }

  TForm1 = class(TForm)
  private
    Memo1: TMemo;
    Memo2: TMemo;
    Button1: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Timer1: TTimer;
    Timer2: TTimer;
    FStarForms: array of TBaseForm;
    procedure Button1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
    procedure FormCloseEvent(Sender: TObject; var CloseAction: TCloseAction);
    procedure FreeStarForms;
    procedure LoadIniToMemo;
    procedure LoadCalcToMemo;
  public
    procedure DoCreate; override;
    // === НОВЫЙ МЕТОД: обновляет Memo2 данными текущей сетки ===
    procedure UpdateMemo2WithGrid(const FormName: String; COLS, ROWS, IMG_W, IMG_H: Integer);
  end;

var
  Form1: TForm1;

implementation

procedure TForm1.DoCreate;
begin
  Name := 'Form1';
  Caption := 'Панель управления — project7';
  Width := 820;
  Height := 640;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;

  inherited DoCreate;

  Label1 := TLabel.Create(Self);
  Label1.Parent := Self;
  Label1.Caption := 'INI файл:';
  Label1.Left := 10;
  Label1.Top := 50;

  Label2 := TLabel.Create(Self);
  Label2.Parent := self;
  Label2.Caption := 'Расчёт:';
  Label2.Left := 425;
  Label2.Top := 50;

  Button1 := TButton.Create(Self);
  Button1.Parent := Self;
  Button1.Caption := 'Расчёт и запуск';
  Button1.Left := 10;
  Button1.Top := 10;
  Button1.Width := 200;
  Button1.Height := 30;
  Button1.OnClick := @Button1Click;

  Memo1 := TMemo.Create(Self);
  Memo1.Parent := Self;
  Memo1.Left := 10;
  Memo1.Top := 70;
  Memo1.Width := 400;
  Memo1.Height := 520;
  Memo1.ScrollBars := ssBoth;
  Memo1.ReadOnly := True;
  Memo1.Font.Name := 'Courier New';
  Memo1.Font.Size := 9;
  Memo1.Anchors := [akLeft, akTop, akBottom];

  Memo2 := TMemo.Create(Self);
  Memo2.Parent := Self;
  Memo2.Left := 425;
  Memo2.Top := 70;
  Memo2.Width := 380;
  Memo2.Height := 520;
  Memo2.ScrollBars := ssBoth;
  Memo2.ReadOnly := True;
  Memo2.Font.Name := 'Courier New';
  Memo2.Font.Size := 9;
  Memo2.Anchors := [akTop, akRight, akBottom];

  Timer1 := TTimer.Create(Self);
  Timer1.Interval := 50;
  Timer1.Enabled := False;
  Timer1.OnTimer := @Timer1Timer;

  Timer2 := TTimer.Create(Self);
  Timer2.Interval := 1000;
  Timer2.Enabled := True;
  Timer2.OnTimer := @Timer2Timer;

  OnClose := @FormCloseEvent;

  SetLength(FStarForms, 0);
end;

// ==============================================================================
// НОВЫЙ МЕТОД: обновляет Memo2 строкой с текущими COLS/ROWS/IMG_W/IMG_H
// ==============================================================================
procedure TForm1.UpdateMemo2WithGrid(const FormName: String; COLS, ROWS, IMG_W, IMG_H: Integer);
var
  Lines: TStringList;
  i: Integer;
  Found: Boolean;
begin
  // Ищем строку с этим FormName и обновляем её, если есть, иначе добавляем
  Lines := TStringList.Create;
  try
    Lines.Text := Memo2.Text;

    Found := False;
    for i := 0 to Lines.Count - 1 do
    begin
      if Pos(FormName + ':', Lines[i]) = 1 then
      begin
        Lines[i] := FormName + ': COLS=' + IntToStr(COLS) +
                    ', ROWS=' + IntToStr(ROWS) +
                    ', IMG_W=' + IntToStr(IMG_W) +
                    ', IMG_H=' + IntToStr(IMG_H);
        Found := True;
        Break;
      end;
    end;

    if not Found then
    begin
      Lines.Add(FormName + ': COLS=' + IntToStr(COLS) +
                ', ROWS=' + IntToStr(ROWS) +
                ', IMG_W=' + IntToStr(IMG_W) +
                ', IMG_H=' + IntToStr(IMG_H));
    end;

    Memo2.Text := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TForm1.FormCloseEvent(Sender: TObject; var CloseAction: TCloseAction);
begin
  Timer1.Enabled := False;
  Timer2.Enabled := False;
  FreeStarForms;
  CloseAction := caFree;
end;

procedure TForm1.FreeStarForms;
var
  i: Integer;
begin
  for i := 0 to High(FStarForms) do
  begin
    if Assigned(FStarForms[i]) then
    begin
      FStarForms[i].Free;
      FStarForms[i] := nil;
    end;
  end;
  SetLength(FStarForms, 0);
end;

procedure TForm1.LoadIniToMemo;
var
  NewText: String;
begin
  NewText := GetIniText;
  if Memo1.Text <> NewText then
    Memo1.Text := NewText;
end;

procedure TForm1.LoadCalcToMemo;
var
  i, Count: Integer;
  SI: TScreenInfo;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Count := GetMonitorsCount;
    Lines.Add('=== Расчёт ===');
    Lines.Add('');
    Lines.Add('Мониторов: ' + IntToStr(Count));
    Lines.Add('DOT_D = ' + IntToStr(DOT_D));
    Lines.Add('');

    for i := 0 to Count - 1 do
    begin
      SI := GetScreenInfo(i);
      Lines.Add('[Screen' + IntToStr(i) + '] -> ' + SI.FormName);
      Lines.Add('  Resolution : ' + IntToStr(SI.Width) + ' x ' + IntToStr(SI.Height));
      Lines.Add('  COLS       : ' + IntToStr(SI.COLS));
      Lines.Add('  ROWS       : ' + IntToStr(SI.ROWS));
      Lines.Add('  IMG_W      : ' + IntToStr(SI.COLS * DOT_D));
      Lines.Add('  IMG_H      : ' + IntToStr(SI.ROWS * DOT_D));
      Lines.Add('');
    end;

    Memo2.Text := Lines.Text;
  finally
    Lines.Free;
  end;
end;

// 1. Сначала — сама процедура-помощник (до любых методов, которые её используют)
procedure UpdateMemo2Helper(const FormName: String; COLS, ROWS, IMG_W, IMG_H: Integer);
var
  Lines: TStringList;
  i: Integer;
  Found: Boolean;
begin
  if not Assigned(Form1) or not Assigned(Form1.Memo2) then Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := Form1.Memo2.Text;

    Found := False;
    for i := 0 to Lines.Count - 1 do
    begin
      if Pos(FormName + ':', Lines[i]) = 1 then
      begin
        Lines[i] := FormName + ': COLS=' + IntToStr(COLS) +
                    ', ROWS=' + IntToStr(ROWS) +
                    ', IMG_W=' + IntToStr(IMG_W) +
                    ', IMG_H=' + IntToStr(IMG_H);
        Found := True;
        Break;
      end;
    end;

    if not Found then
    begin
      Lines.Add(FormName + ': COLS=' + IntToStr(COLS) +
                ', ROWS=' + IntToStr(ROWS) +
                ', IMG_W=' + IntToStr(IMG_W) +
                ', IMG_H=' + IntToStr(IMG_H));
    end;

    Form1.Memo2.Text := Lines.Text;
  finally
    Lines.Free;
  end;
end;

// 2. Теперь можно безопасно использовать её в Button1Click
procedure TForm1.Button1Click(Sender: TObject);
var
  i, Count: Integer;
  SI: TScreenInfo;
  F: TBaseForm;
begin
  Timer1.Enabled := False;
  FreeStarForms;

  WriteMonitorInfo;
  LoadIniToMemo;
  LoadCalcToMemo;

  Count := GetMonitorsCount;
  if Count < 1 then
  begin
    Memo2.Lines.Add('Нет мониторов!');
    Exit;
  end;

  SetLength(FStarForms, Count);
  for i := 0 to Count - 1 do
  begin
    SI := GetScreenInfo(i);
    // Обязательно с @ — передаём адрес процедуры
    F := TBaseForm.CreateForMonitor(nil, i, SI.FormName, @UpdateMemo2Helper);
    F.Show;
    FStarForms[i] := F;
  end;

  Timer1.Enabled := True;
  LoadIniToMemo;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to High(FStarForms) do
  begin
    if Assigned(FStarForms[i]) and FStarForms[i].Visible then
      FStarForms[i].UpdateBands;
  end;
end;

procedure TForm1.Timer2Timer(Sender: TObject);
begin
  LoadIniToMemo;
end;

end.

