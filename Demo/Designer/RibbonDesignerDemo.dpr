program RibbonDesignerDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  CamART.Ribbon.DesignerDemo in 'CamART.Ribbon.DesignerDemo.pas' {RibbonDesignerDemoForm};

begin
  Application.Initialize;
  Application.CreateForm(TRibbonDesignerDemoForm, RibbonDesignerDemoForm);
  Application.Run;
end.
