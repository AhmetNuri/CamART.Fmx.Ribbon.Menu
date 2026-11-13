unit CamART.Ribbon.JsonDemo;

interface

uses
  System.Classes,
  FMX.Forms,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Memo,
  CamART.Ribbon.Control;

type
  TRibbonJsonDemoForm = class(TForm)
  private
    FRibbon: TCamARTRibbon;
    FEditor: TMemo;
    FStatus: TLabel;
    FLocalBook: TStyleBook;
    FExecutions: Integer;
    procedure ApplyClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure LegacyClick(Sender: TObject);
    procedure InvalidClick(Sender: TObject);
    procedure StyleBookClick(Sender: TObject);
    procedure CommandExecuted(Sender: TObject);
    procedure ShowStatus(const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  RibbonJsonDemoForm: TRibbonJsonDemoForm;

implementation

uses
  System.SysUtils,
  System.Types,
  FMX.Types,
  FMX.Layouts,
  FMX.ScrollBox,
  CamART.Ribbon.Commands,
  CamART.Ribbon.Themes,
  CamART.Ribbon.ThemeStyles,
  CamART.Ribbon.Json,
  CamART.Ribbon.Json.FMX,
  CamART.Ribbon.DemoIcons;

const
  DemoJson =
    '{"schemaVersion":2,"theme":"ModernLight","activeTabId":"home","applicationCaption":"Dosya","expanded' +
    'Height":220,"tabs":[{"id":"home","caption":"Giriş","groups":[{"id":"clipboard","caption":"Pano","ite' +
    'ms":[{"id":"paste","type":"button","caption":"Yapıştır","command":"paste","icon":"paste","style":"la' +
    'rge"},{"id":"copy","type":"button","caption":"Kopyala","command":"copy","icon":"copy","style":"small' +
    '"},{"id":"clip-separator","type":"separator"},{"id":"menu","type":"dropdownmenu","caption":"Seçenekl' +
    'er","style":"small","menu":[{"id":"menu-paste","command":"paste","caption":"Yapıştır"},{"id":"menu-c' +
    'opy","command":"copy","caption":"Kopyala"}]}]},{"id":"format","caption":"Biçim","items":[{"id":"bold' +
    '","type":"checkbox","caption":"Kalın","command":"bold","icon":"bold","checked":false},{"id":"left","' +
    'type":"radio","caption":"Sola","groupName":"alignment","checked":true},{"id":"right","type":"radio",' +
    '"caption":"Sağa","groupName":"alignment","checked":false},{"id":"font","type":"fontpicker","caption"' +
    ':"Yazı tipi","choices":["Arial","Courier New","Times New Roman"],"itemIndex":0},{"id":"font-size","t' +
    'ype":"fontsizepicker","caption":"Punto","choices":["9","11","14","18","24"],"itemIndex":1},{"id":"co' +
    'lor","type":"colorpicker","caption":"Renk","color":"#FF2479B8"}]},{"id":"values","caption":"Değerler' +
    '","items":[{"id":"label","type":"label","caption":"Belge bilgisi"},{"id":"name","type":"edit","capti' +
    'on":"Ad","text":"Örnek — İğüşçö"},{"id":"mode","type":"combo","caption":"Görünüm","choices":["Normal' +
    '","Baskı","Web"],"itemIndex":0},{"id":"progress","type":"progress","caption":"İlerleme","min":0,"max' +
    '":100,"value":35}]},{"id":"styles","caption":"Stiller","items":[{"id":"gallery","type":"gallery","ca' +
    'ption":"Renk stili","entries":[{"id":"blue","caption":"Mavi","icon":"style.blue","command":"style.bl' +
    'ue"},{"id":"green","caption":"Yeşil","icon":"style.green","command":"style.green"},{"id":"gold","cap' +
    'tion":"Altın","icon":"style.gold","command":"style.gold"}],"selectedId":"blue"}]}]},{"id":"view","ca' +
    'ption":"Görünüm","groups":[{"id":"view-info","caption":"Açıklama","items":[{"id":"view-label","type"' +
    ':"label","caption":"JSON, aynı Ribbon modelini kullanır."}]}]}],"quickAccess":[{"id":"qat-copy","ite' +
    'm":"copy"},{"id":"qat-bold","item":"bold"}],"applicationMenu":[{"id":"app-paste","command":"paste","' +
    'caption":"Yapıştır","icon":"paste"},{"id":"app-copy","command":"copy","caption":"Kopyala","icon":"co' +
    'py"}]}';

  LegacyJson =
    '{"theme":"Silver","tabs":[{"name":"Home","groups":[{"name":"Clipboard","buttons":[{"name":"Paste","s' +
    'tyle":"Large","command":"paste","icon":"paste"},{"name":"Copy","style":"Small","command":"copy","ico' +
    'n":"copy"}]}]}]}';

type
  TJsonDemoCommand = class(TInterfacedObject, IRibbonCommand, IRibbonCheckState)
  private
    FId: string;
    FChecked, FCheckable: Boolean;
    FOnExecute: TNotifyEvent;
  public
    constructor Create(const AId: string; ACheckable: Boolean;
      const AOnExecute: TNotifyEvent);
    function CanExecute: Boolean;
    procedure Execute;
    function GetChecked: Boolean;
    property Id: string read FId;
  end;

constructor TJsonDemoCommand.Create(const AId: string; ACheckable: Boolean;
  const AOnExecute: TNotifyEvent);
begin
  inherited Create;
  FId := AId;
  FCheckable := ACheckable;
  FOnExecute := AOnExecute;
end;

function TJsonDemoCommand.CanExecute: Boolean;
begin
  Result := True;
end;

procedure TJsonDemoCommand.Execute;
var
  Handler: TNotifyEvent;
begin
  if FCheckable then FChecked := not FChecked;
  Handler := FOnExecute;
  if Assigned(Handler) then Handler(Self);
end;

function TJsonDemoCommand.GetChecked: Boolean;
begin
  Result := FChecked;
end;

constructor TRibbonJsonDemoForm.Create(AOwner: TComponent);
var
  Intro: TLabel;
  Tools: TFlowLayout;
  Key: string;
  procedure AddButton(const AText: string; const AHandler: TNotifyEvent);
  var
    Button: TButton;
  begin
    Button := TButton.Create(Self);
    Button.Parent := Tools;
    Button.Width := 168;
    Button.Height := 36;
    Button.Margins.Rect := TRectF.Create(4, 4, 4, 4);
    Button.Text := AText;
    Button.OnClick := AHandler;
  end;
begin
  inherited CreateNew(AOwner);
  Caption := 'CamART Ribbon — JSON ve aynı native model';
  Width := 1280;
  Height := 850;

  Intro := TLabel.Create(Self);
  Intro.Parent := Self;
  Intro.Position.Y := 0;
  Intro.Align := TAlignLayout.Top;
  Intro.Height := 48;
  Intro.Margins.Left := 12;
  Intro.Text := 'JSON metnini düzenleyip Uygula seçin. Hatalı yükleme mevcut Ribbon’u korur. ' +
    'Bileşene StyleBook seçilirse o kitap; seçim kaldırılırsa formun kitabı kullanılır.';
  Intro.WordWrap := True;

  StyleBook := CreateRibbonThemeStyleBook(Self, rtOffice2010Blue);
  FLocalBook := CreateRibbonThemeStyleBook(Self, rtOfficeBlack);
  FRibbon := TCamARTRibbon.Create(Self);
  FRibbon.Parent := Self;
  FRibbon.Position.Y := 48;
  FRibbon.Align := TAlignLayout.Top;
  FRibbon.Height := 220;
  for Key in TArray<string>.Create('paste', 'copy', 'bold', 'style.blue', 'style.green', 'style.gold') do
    FRibbon.Commands.RegisterCommand(Key,
      TJsonDemoCommand.Create(Key, Key = 'bold', CommandExecuted));
  RegisterRibbonDemoIcons(FRibbon.Icons);

  Tools := TFlowLayout.Create(Self);
  Tools.Parent := Self;
  Tools.Position.Y := 268;
  Tools.Align := TAlignLayout.Top;
  Tools.Height := 88;
  AddButton('JSON uygula', ApplyClick);
  AddButton('JSON dışa aktar', ExportClick);
  AddButton('v2 örneğini getir', ResetClick);
  AddButton('Eski biçimi getir', LegacyClick);
  AddButton('Hatalı yüklemeyi dene', InvalidClick);
  AddButton('Bileşen StyleBook', StyleBookClick);

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := TAlignLayout.Bottom;
  FStatus.Height := 76;
  FStatus.WordWrap := True;
  FStatus.Margins.Left := 12;
  FStatus.Margins.Right := 12;

  FEditor := TMemo.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := TAlignLayout.Client;
  FEditor.WordWrap := False;
  FEditor.Lines.Text := DemoJson;
  ApplyClick(nil);
end;

procedure TRibbonJsonDemoForm.ShowStatus(const AMessage: string);
var
  BookSource: string;
begin
  if FRibbon.StyleBook <> nil then BookSource := 'Bileşenin StyleBook’u'
  else BookSource := 'Formun StyleBook’u';
  FStatus.Text := AMessage + sLineBreak + BookSource +
    ' • Etkin sekme: ' + FRibbon.ActiveTabId +
    ' • Yürütülen komut: ' + IntToStr(FExecutions);
end;

procedure TRibbonJsonDemoForm.ApplyClick(Sender: TObject);
var
  Diagnostic: string;
begin
  try
    Diagnostic := TRibbonJsonFMX.Load(FRibbon, FEditor.Lines.Text);
    if Diagnostic = '' then ShowStatus('Yapılandırma uygulandı.')
    else ShowStatus('Yapılandırma uygulandı. ' + Diagnostic);
  except
    on E: ERibbonConfigurationCommittedError do
      ShowStatus('Yapılandırma değişti; görünüm veya olay bildirimi hata verdi. ' + E.Message);
    on E: Exception do ShowStatus('Yükleme reddedildi. ' + E.Message);
  end;
end;

procedure TRibbonJsonDemoForm.ExportClick(Sender: TObject);
begin
  try
    FEditor.Lines.Text := TRibbonJsonFMX.Save(FRibbon);
    ShowStatus('Güncel model, kalıcı kimlikleri ve sırasıyla dışa aktarıldı.');
  except
    on E: Exception do ShowStatus('Dışa aktarma başarısız. ' + E.Message);
  end;
end;

procedure TRibbonJsonDemoForm.ResetClick(Sender: TObject);
begin
  FEditor.Lines.Text := DemoJson;
  ShowStatus('v2 örneği hazır; uygulamak için JSON uygula seçin.');
end;

procedure TRibbonJsonDemoForm.LegacyClick(Sender: TObject);
begin
  FEditor.Lines.Text := LegacyJson;
  ShowStatus('Eski buttons/style biçimi hazır; uyguladıktan sonra dışa aktararak v2 dönüşümünü inceleyin.');
end;

procedure TRibbonJsonDemoForm.InvalidClick(Sender: TObject);
var
  Before, Diagnostic: string;
begin
  Before := TRibbonJsonFMX.Save(FRibbon);
  try
    Diagnostic := TRibbonJsonFMX.Load(FRibbon,
      '{"schemaVersion":2,"tabs":[{"id":"broken","groups":[{"id":"g",' +
      '"items":[{"id":"b","type":"button","command":"not-registered"}]}]}]}');
    ShowStatus('Beklenmeyen sonuç: hatalı örnek kabul edildi. ' + Diagnostic);
  except
    on E: ERibbonJsonError do
      if TRibbonJsonFMX.Save(FRibbon) = Before then
        ShowStatus('Hatalı komut reddedildi; mevcut yapılandırma korundu. ' + E.Message)
      else ShowStatus('Doğrulama hatası: başarısız yükleme modeli değiştirdi.');
    on E: Exception do ShowStatus('Beklenmeyen hata. ' + E.Message);
  end;
end;

procedure TRibbonJsonDemoForm.StyleBookClick(Sender: TObject);
begin
  if FRibbon.StyleBook = nil then FRibbon.StyleBook := FLocalBook
  else FRibbon.StyleBook := nil;
  ShowStatus('StyleBook önceliği değiştirildi; JSON bu seçimi değiştirmez.');
end;

procedure TRibbonJsonDemoForm.CommandExecuted(Sender: TObject);
begin
  Inc(FExecutions);
  ShowStatus('Komut yürütüldü: ' + TJsonDemoCommand(Sender).Id);
end;

end.
