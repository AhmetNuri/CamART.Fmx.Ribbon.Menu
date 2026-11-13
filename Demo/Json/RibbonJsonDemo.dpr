program RibbonJsonDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  CamART.Ribbon.JsonDemo in 'CamART.Ribbon.JsonDemo.pas',
  CamART.Ribbon.DemoIcons in '..\CamART.Ribbon.DemoIcons.pas';

begin
  Application.Initialize;
  Application.CreateForm(TRibbonJsonDemoForm, RibbonJsonDemoForm);
  Application.Run;
end.
