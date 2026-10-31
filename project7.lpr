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
  Application.Run;

  DoneSettings;
end.

