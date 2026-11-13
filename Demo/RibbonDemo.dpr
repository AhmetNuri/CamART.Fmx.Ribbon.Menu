program RibbonDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  CamART.Ribbon.DemoMain in 'CamART.Ribbon.DemoMain.pas',
  CamART.Ribbon.DemoStyles in 'CamART.Ribbon.DemoStyles.pas',
  CamART.Ribbon.DemoIcons in 'CamART.Ribbon.DemoIcons.pas',
  CamART.Ribbon.ThemeDemo in 'CamART.Ribbon.ThemeDemo.pas';

begin
  Application.Initialize;
  Application.CreateForm(TRibbonDemoForm, RibbonDemoForm);
  Application.Run;
end.
