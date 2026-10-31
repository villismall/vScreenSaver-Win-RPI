program project7;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, Forms, SysUtils, uSettings, uBaseForm, Unit1;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;

  InitSettings;

  Application.CreateForm(TForm1, Form1);

  // === НОВОЕ: Принудительный FullScreen для Form1 на Raspberry Pi ===
  {$IFDEF UNIX}
  Form1.BorderStyle := bsNone;
  Form1.WindowState := wsMaximized;
  // Если хочешь, чтобы Form1 всё равно оставалась «панелью» и не перекрывала весь рабочий стол,
  // можно вместо wsMaximized поставить просто большие размеры:
  // Form1.Width  := Screen.Width;
  // Form1.Height := Screen.Height;
  {$ENDIF}
  // =================================================================

  Application.Run;

  DoneSettings;
end.

