program RibbonSkiaDemo;

{ Usage:
    RibbonSkiaDemo.exe                       interactive demo
    RibbonSkiaDemo.exe --verify[=report.txt] [--screenshot=ribbon.png]
      loads ribbon.skia.json, checks TSkLabel/TSkSvg presentation, exits 0/1 }

uses
  System.StartUpCopy,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  FMX.Forms,
  FMX.Graphics,
  CamART.Ribbon.SkiaDemo in 'CamART.Ribbon.SkiaDemo.pas';

{$R *.res}

function OptionValue(const AName: string; out AValue: string): Boolean;
var
  I: Integer;
  Arg: string;
begin
  Result := False;
  AValue := '';
  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);
    if SameText(Arg, '--' + AName) then Exit(True);
    if Arg.StartsWith('--' + AName + '=', True) then
    begin
      AValue := Arg.Substring(Length(AName) + 3);
      Exit(True);
    end;
  end;
end;

procedure RunVerification;
var
  ReportPath, ShotPath, Errors: string;
  Shot: TBitmap;
  Report: TStringList;
begin
  OptionValue('verify', ReportPath);
  RibbonSkiaDemoForm.Show;
  Application.ProcessMessages;
  RibbonSkiaDemoForm.Ribbon.Refresh;
  Application.ProcessMessages;
  try
    Errors := RibbonSkiaDemoForm.VerifyPresentation;
  except
    on E: Exception do Errors := E.ClassName + ': ' + E.Message;
  end;
  if OptionValue('screenshot', ShotPath) and (ShotPath <> '') then
  begin
    Shot := RibbonSkiaDemoForm.Ribbon.MakeScreenshot;
    try
      Shot.SaveToFile(ShotPath);
    finally
      Shot.Free;
    end;
  end;
  Report := TStringList.Create;
  try
    Report.Add('json=' + RibbonSkiaDemoForm.JsonPath);
    if Errors = '' then Report.Add('PASS: TSkLabel + TSkSvg Ribbon demo')
    else Report.Add('FAIL:' + sLineBreak + Errors);
    if ReportPath <> '' then Report.SaveToFile(ReportPath, TEncoding.UTF8);
  finally
    Report.Free;
  end;
  if Errors = '' then ExitCode := 0 else ExitCode := 1;
end;

var
  Dummy: string;

begin
  Application.Initialize;
  if OptionValue('verify', Dummy) then
  begin
    try
      { FMX defers CreateForm until Application.Run; verification needs the
        form immediately. }
      RibbonSkiaDemoForm := TRibbonSkiaDemoForm.Create(Application);
      RunVerification;
    except
      on E: Exception do
      begin
        if Dummy <> '' then
          TFile.WriteAllText(Dummy, 'FAIL: ' + E.ClassName + ': ' + E.Message, TEncoding.UTF8);
        ExitCode := 1;
      end;
    end;
    Application.Terminate;
  end
  else
  begin
    Application.CreateForm(TRibbonSkiaDemoForm, RibbonSkiaDemoForm);
    Application.Run;
  end;
end.
