unit uSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, Forms;

const
  DOT_D = 16;

type
  TFormState = record
    saveMonitor: Integer;
    saveLeft: Integer;
    saveTop: Integer;
    saveWidth: Integer;
    saveHeight: Integer;
    saveIsFullScreen: Boolean;
  end;

  TScreenInfo = record
    Width: Integer;
    Height: Integer;
    FormName: String;
    COLS: Integer;
    ROWS: Integer;
  end;

procedure InitSettings;
procedure DoneSettings;
procedure WriteMonitorInfo;
function GetScreenInfo(ScreenIdx: Integer): TScreenInfo;
function GetFormState(const FormName: String): TFormState;
procedure SaveFormState(const FormName: String; const AState: TFormState);
function GetIniPath: String;
function GetIniText: String;
function GetMonitorsCount: Integer;

implementation

var
  GIni: TIniFile;
  GIniPath: String;

function GetIniPath: String;
begin
  Result := GIniPath;
end;

function GetMonitorsCount: Integer;
begin
  Result := GIni.ReadInteger('Monitors', 'Count', 0);
end;

function GetIniText: String;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    if FileExists(GIniPath) then
      SL.LoadFromFile(GIniPath)
    else
      SL.Text := 'INI не найден: ' + GIniPath;
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure InitSettings;
begin
  GIniPath := ExtractFilePath(ParamStr(0)) + 'form_settings.ini';
  GIni := TIniFile.Create(GIniPath);
end;

procedure DoneSettings;
begin
  if Assigned(GIni) then
  begin
    GIni.UpdateFile;
    GIni.Free;
    GIni := nil;
  end;
end;

procedure WriteMonitorInfo;
var
  i, Count: Integer;
  FormName: String;
  COLS, ROWS: Integer;
begin
  Count := Screen.MonitorCount;
  GIni.WriteInteger('Monitors', 'Count', Count);

  for i := 0 to Count - 1 do
  begin
    FormName := 'Form' + IntToStr(i + 2); // Form2, Form3, Form4...

    GIni.WriteInteger('Screen' + IntToStr(i), 'Width',    Screen.Monitors[i].Width);
    GIni.WriteInteger('Screen' + IntToStr(i), 'Height',   Screen.Monitors[i].Height);
    GIni.WriteString ('Screen' + IntToStr(i), 'FormName', FormName);

    COLS := Screen.Monitors[i].Width  div DOT_D;
    ROWS := Screen.Monitors[i].Height div DOT_D;

    GIni.WriteInteger('Screen' + IntToStr(i), 'COLS', COLS);
    GIni.WriteInteger('Screen' + IntToStr(i), 'ROWS', ROWS);

    // Привязка формы к монитору
    GIni.WriteInteger(FormName, 'Monitor', i);

    // FullScreen = True по умолчанию (только при первом создании)
    if not GIni.ValueExists(FormName, 'FullScreen') then
      GIni.WriteBool(FormName, 'FullScreen', True);
  end;

  GIni.UpdateFile;
end;

function GetScreenInfo(ScreenIdx: Integer): TScreenInfo;
var
  S: String;
begin
  S := 'Screen' + IntToStr(ScreenIdx);
  Result.Width    := GIni.ReadInteger(S, 'Width',    0);
  Result.Height   := GIni.ReadInteger(S, 'Height',   0);
  Result.FormName := GIni.ReadString (S, 'FormName', '');
  Result.COLS     := GIni.ReadInteger(S, 'COLS',     0);
  Result.ROWS     := GIni.ReadInteger(S, 'ROWS',     0);
end;

function GetFormState(const FormName: String): TFormState;
begin
  Result.saveMonitor      := GIni.ReadInteger(FormName, 'Monitor',    0);
  Result.saveLeft         := GIni.ReadInteger(FormName, 'Left',       -1);
  Result.saveTop          := GIni.ReadInteger(FormName, 'Top',        -1);
  Result.saveWidth        := GIni.ReadInteger(FormName, 'Width',     800);
  Result.saveHeight       := GIni.ReadInteger(FormName, 'Height',    480);
  Result.saveIsFullScreen := GIni.ReadBool   (FormName, 'FullScreen', True);
end;

procedure SaveFormState(const FormName: String; const AState: TFormState);
begin
  if not Assigned(GIni) then Exit;   // ← защита
  GIni.WriteInteger(FormName, 'Monitor',    AState.saveMonitor);
  GIni.WriteInteger(FormName, 'Left',       AState.saveLeft);
  GIni.WriteInteger(FormName, 'Top',        AState.saveTop);
  GIni.WriteInteger(FormName, 'Width',      AState.saveWidth);
  GIni.WriteInteger(FormName, 'Height',     AState.saveHeight);
  GIni.WriteBool   (FormName, 'FullScreen', AState.saveIsFullScreen);
  GIni.UpdateFile;
end;

end.

