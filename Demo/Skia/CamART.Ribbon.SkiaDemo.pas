unit CamART.Ribbon.SkiaDemo;

{ TSkLabel + TSkSvg Ribbon demo. The menu structure comes from
  ribbon.skia.json; the application registers the visual resources (SVG icons
  and TSkLabel templates) and the commands that the JSON refers to by key. }

interface

uses
  System.Classes,
  FMX.Forms,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Memo,
  FMX.Skia,
  CamART.Ribbon.Control;

type
  TRibbonSkiaDemoForm = class(TForm)
  private
    FRibbon: TCamARTRibbon;
    FEditor: TMemo;
    FStatus: TLabel;
    FJsonPath: string;
    FExecutions: Integer;
    FAlternate: Boolean;
    { Design-time style TSkLabel/TSkSvg components. Their snapshots are
      registered; the Ribbon never borrows these controls. }
    FTitleLabel, FRichLabel, FStatusLabel, FAccentLabel, FNoteLabel: TSkLabel;
    FChartSvg: TSkSvg;
    procedure CreateSkiaSources;
    procedure RegisterResources;
    procedure RegisterCommands;
    procedure LoadFileClick(Sender: TObject);
    procedure ApplyEditorClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure SwapTemplatesClick(Sender: TObject);
    procedure ThemeClick(Sender: TObject);
    procedure CommandExecuted(Sender: TObject);
    procedure ShowStatus(const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
    function LoadJson(const AText: string): Boolean;
    { Self-check used by --verify. Returns an empty string on success. }
    function VerifyPresentation: string;
    property Ribbon: TCamARTRibbon read FRibbon;
    property JsonPath: string read FJsonPath;
  end;

var
  RibbonSkiaDemoForm: TRibbonSkiaDemoForm;

function FindDemoJson: string;

implementation

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.IOUtils,
  System.Skia,
  FMX.Types,
  FMX.Graphics,
  FMX.Layouts,
  FMX.ScrollBox,
  CamART.Ribbon.Types,
  CamART.Ribbon.Model,
  CamART.Ribbon.Commands,
  CamART.Ribbon.Views,
  CamART.Ribbon.Themes,
  CamART.Ribbon.SkLabels,
  CamART.Ribbon.Json,
  CamART.Ribbon.Json.FMX;

const
  DemoJsonName = 'ribbon.skia.json';

  { Original vector artwork for this demo (simple geometric shapes). }
  DocumentSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<path fill="#2f6fb7" d="M7 2h13l7 7v21H7z"/><path fill="#9cc3ee" d="M20 2v7h7z"/>' +
    '<path fill="#ffffff" d="M11 14h12v2H11zm0 5h12v2H11zm0 5h8v2h-8z"/></svg>';
  SaveSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<path fill="#3a8f5c" d="M4 4h20l4 4v20H4z"/><path fill="#e8f4ec" d="M9 4h13v8H9z"/>' +
    '<path fill="#1f5c39" d="M18 6h3v4h-3z"/><path fill="#ffffff" d="M8 17h16v9H8z"/></svg>';
  ShareSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<path stroke="#8a4fc4" stroke-width="3" fill="none" d="M9 16L23 8M9 16l14 8"/>' +
    '<circle cx="8" cy="16" r="5" fill="#8a4fc4"/><circle cx="24" cy="7" r="5" fill="#c08be8"/>' +
    '<circle cx="24" cy="25" r="5" fill="#c08be8"/></svg>';
  ChartSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<defs><linearGradient id="g" x1="0" y1="1" x2="0" y2="0">' +
    '<stop offset="0" stop-color="#f08a24"/><stop offset="1" stop-color="#ffd166"/></linearGradient></defs>' +
    '<path fill="#5a6475" d="M3 28h27v2H3z"/><path fill="url(#g)" d="M5 18h5v10H5z"/>' +
    '<path fill="#e4572e" d="M13 10h5v18h-5z"/><path fill="#2f6fb7" d="M21 4h5v24h-5z"/></svg>';
  AlertSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<path fill="#e8a317" d="M16 2l15 27H1z"/><path fill="#3b2a00" d="M14.5 11h3v10h-3zm0 12h3v3h-3z"/></svg>';

  AccentAlternate: array[Boolean] of TAlphaColor = (TAlphaColors.Crimson, TAlphaColors.Teal);

type
  TSkiaDemoCommand = class(TInterfacedObject, IRibbonCommand)
  private
    FId: string;
    FOnExecute: TNotifyEvent;
  public
    constructor Create(const AId: string; const AOnExecute: TNotifyEvent);
    function CanExecute: Boolean;
    procedure Execute;
    property Id: string read FId;
  end;

constructor TSkiaDemoCommand.Create(const AId: string; const AOnExecute: TNotifyEvent);
begin
  inherited Create;
  FId := AId;
  FOnExecute := AOnExecute;
end;

function TSkiaDemoCommand.CanExecute: Boolean;
begin
  Result := True;
end;

procedure TSkiaDemoCommand.Execute;
var
  Handler: TNotifyEvent;
begin
  Handler := FOnExecute;
  if Assigned(Handler) then Handler(Self);
end;

function FindDemoJson: string;
var
  Dir: string;
  I: Integer;
begin
  { Next to the executable (copied by the project), otherwise walk up to the
    source tree so the IDE/debug output directory also works. }
  Dir := ExtractFilePath(ParamStr(0));
  for I := 0 to 6 do
  begin
    Result := TPath.Combine(Dir, DemoJsonName);
    if TFile.Exists(Result) then Exit;
    Result := TPath.Combine(TPath.Combine(TPath.Combine(Dir, 'Demo'), 'Skia'), DemoJsonName);
    if TFile.Exists(Result) then Exit;
    Dir := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
    if Dir = '' then Break;
  end;
  Result := '';
end;

constructor TRibbonSkiaDemoForm.Create(AOwner: TComponent);
var
  Intro: TLabel;
  Tools: TFlowLayout;
  procedure AddButton(const AText: string; const AHandler: TNotifyEvent);
  var
    Button: TButton;
  begin
    Button := TButton.Create(Self);
    Button.Parent := Tools;
    Button.Width := 190;
    Button.Height := 34;
    Button.Margins.Rect := TRectF.Create(4, 4, 4, 4);
    Button.Text := AText;
    Button.OnClick := AHandler;
  end;
begin
  inherited CreateNew(AOwner);
  Caption := 'CamART Ribbon — TSkLabel + TSkSvg (JSON yapılandırması)';
  Width := 1280;
  Height := 820;

  Intro := TLabel.Create(Self);
  Intro.Parent := Self;
  Intro.Align := TAlignLayout.Top;
  Intro.Height := 40;
  Intro.Margins.Left := 12;
  Intro.WordWrap := True;
  Intro.Text := 'Menü ' + DemoJsonName + ' dosyasından yüklenir. İkonlar TSkSvg, ' +
    '"sklabel" öğeleri TSkLabel şablonlarıyla çizilir; JSON yalnız anahtarları taşır.';

  CreateSkiaSources;
  FRibbon := TCamARTRibbon.Create(Self);
  FRibbon.Parent := Self;
  FRibbon.Position.Y := 40;
  FRibbon.Align := TAlignLayout.Top;
  FRibbon.Height := 250;
  RegisterCommands;
  RegisterResources;

  Tools := TFlowLayout.Create(Self);
  Tools.Parent := Self;
  Tools.Position.Y := 300;
  Tools.Align := TAlignLayout.Top;
  Tools.Height := 46;
  AddButton('JSON dosyasını yükle', LoadFileClick);
  AddButton('Düzenleyicideki JSON''u uygula', ApplyEditorClick);
  AddButton('Modeli JSON''a aktar', ExportClick);
  AddButton('TSkLabel şablonlarını değiştir', SwapTemplatesClick);
  AddButton('Tema değiştir', ThemeClick);

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := TAlignLayout.Bottom;
  FStatus.Height := 60;
  FStatus.WordWrap := True;
  FStatus.Margins.Left := 12;
  FStatus.Margins.Right := 12;

  FEditor := TMemo.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := TAlignLayout.Client;
  FEditor.WordWrap := False;

  FJsonPath := FindDemoJson;
  LoadFileClick(nil);
end;

procedure TRibbonSkiaDemoForm.CreateSkiaSources;
begin
  { Normally these would be dropped on the form at design time. }
  FTitleLabel := TSkLabel.Create(Self);
  FTitleLabel.StyledSettings := [];
  FTitleLabel.TextSettings.Font.Size := 20;
  FTitleLabel.TextSettings.Font.Weight := TFontWeight.Bold;
  FTitleLabel.TextSettings.FontColor := $FF1F4E8C;

  FRichLabel := TSkLabel.Create(Self);
  FRichLabel.Words.Add('Skia ', $FF2F6FB7, 15, TFontWeight.Bold);
  FRichLabel.Words.Add('zengin ', $FFE4572E, 15, TFontWeight.Regular, TFontSlant.Italic);
  FRichLabel.Words.Add('metin', $FF3A8F5C, 15, TFontWeight.Semibold);
  FRichLabel.Words[2].Decorations.Decorations := [TSkTextDecoration.Underline];
  FRichLabel.Words[2].Decorations.Color := $FF3A8F5C;

  FStatusLabel := TSkLabel.Create(Self);
  FStatusLabel.StyledSettings := [TStyledSetting.Family];
  FStatusLabel.TextSettings.Font.Size := 12;
  FStatusLabel.TextSettings.Font.Slant := TFontSlant.Italic;
  FStatusLabel.TextSettings.FontColor := $FF6B7280;

  FAccentLabel := TSkLabel.Create(Self);
  FAccentLabel.StyledSettings := [TStyledSetting.Family];
  FAccentLabel.TextSettings.Font.Size := 14;
  FAccentLabel.TextSettings.Font.Weight := TFontWeight.Bold;
  FAccentLabel.TextSettings.FontColor := AccentAlternate[False];

  FNoteLabel := TSkLabel.Create(Self);
  FNoteLabel.Words.Add('Not: ', $FF8A4FC4, 14, TFontWeight.Bold);
  FNoteLabel.Words.Add('bu sekme JSON''dan yüklendi.', $FF374151, 14);

  { A TSkSvg control (not only an XML string) is also a valid icon source. }
  FChartSvg := TSkSvg.Create(Self);
  FChartSvg.SetBounds(0, 0, 32, 32);
  FChartSvg.Svg.Source := ChartSvg;
end;

procedure TRibbonSkiaDemoForm.RegisterResources;
begin
  FRibbon.SvgIcons.RegisterSvgSource('svg.document', DocumentSvg);
  FRibbon.SvgIcons.RegisterSvgSource('svg.save', SaveSvg);
  FRibbon.SvgIcons.RegisterSvgSource('svg.share', ShareSvg);
  FRibbon.SvgIcons.RegisterSvgSource('svg.alert', AlertSvg);
  FRibbon.SvgIcons.RegisterSvg('svg.chart', FChartSvg);
  FChartSvg.Svg.GrayScale := True;
  FRibbon.SvgIcons.RegisterSvg('svg.chart.gray', FChartSvg);
  FChartSvg.Svg.GrayScale := False;

  FRibbon.SkLabels.RegisterLabel('title', FTitleLabel);
  FRibbon.SkLabels.RegisterLabel('rich', FRichLabel);
  FRibbon.SkLabels.RegisterLabel('status', FStatusLabel);
  FRibbon.SkLabels.RegisterLabel('accent', FAccentLabel);
  FRibbon.SkLabels.RegisterLabel('rich.note', FNoteLabel);
end;

procedure TRibbonSkiaDemoForm.RegisterCommands;
var
  Key: string;
begin
  for Key in TArray<string>.Create('new', 'save', 'share', 'chart', 'alert') do
    FRibbon.Commands.RegisterCommand(Key, TSkiaDemoCommand.Create(Key, CommandExecuted));
end;

function TRibbonSkiaDemoForm.LoadJson(const AText: string): Boolean;
var
  Diagnostic: string;
begin
  Result := False;
  try
    Diagnostic := TRibbonJsonFMX.Load(FRibbon, AText);
    Result := True;
    if Diagnostic = '' then ShowStatus('JSON yapılandırması uygulandı.')
    else ShowStatus('JSON yapılandırması uygulandı. ' + Diagnostic);
  except
    on E: ERibbonConfigurationCommittedError do
    begin
      Result := True;
      ShowStatus('Yapılandırma uygulandı; bir bildirim hata verdi. ' + E.Message);
    end;
    on E: Exception do ShowStatus('JSON reddedildi; mevcut Ribbon korundu. ' + E.Message);
  end;
end;

procedure TRibbonSkiaDemoForm.LoadFileClick(Sender: TObject);
begin
  if (FJsonPath = '') or not TFile.Exists(FJsonPath) then
  begin
    ShowStatus(DemoJsonName + ' bulunamadı.');
    Exit;
  end;
  FEditor.Lines.Text := TFile.ReadAllText(FJsonPath, TEncoding.UTF8);
  if LoadJson(FEditor.Lines.Text) then
    ShowStatus('Yüklendi: ' + FJsonPath);
end;

procedure TRibbonSkiaDemoForm.ApplyEditorClick(Sender: TObject);
begin
  LoadJson(FEditor.Lines.Text);
end;

procedure TRibbonSkiaDemoForm.ExportClick(Sender: TObject);
begin
  try
    FEditor.Lines.Text := TRibbonJsonFMX.Save(FRibbon);
    ShowStatus('Model dışa aktarıldı; sklabel öğeleri "template" anahtarını taşır.');
  except
    on E: Exception do ShowStatus('Dışa aktarma başarısız. ' + E.Message);
  end;
end;

procedure TRibbonSkiaDemoForm.SwapTemplatesClick(Sender: TObject);
begin
  FAlternate := not FAlternate;
  FAccentLabel.TextSettings.FontColor := AccentAlternate[FAlternate];
  FRichLabel.Words[1].Text := 'canlı ';
  if not FAlternate then FRichLabel.Words[1].Text := 'zengin ';
  { Registrations are snapshots: re-register, the Ribbon refreshes itself. }
  FRibbon.SkLabels.RegisterLabel('accent', FAccentLabel);
  FRibbon.SkLabels.RegisterLabel('rich', FRichLabel);
  FRibbon.Refresh;
  ShowStatus('TSkLabel şablonları yeniden kaydedildi; JSON değişmedi.');
end;

procedure TRibbonSkiaDemoForm.ThemeClick(Sender: TObject);
begin
  if FRibbon.Theme = High(TRibbonTheme) then FRibbon.Theme := Low(TRibbonTheme)
  else FRibbon.Theme := Succ(FRibbon.Theme);
  ShowStatus('Tema değişti. Şablonsuz TSkLabel ve stil alanları temayı izler.');
end;

procedure TRibbonSkiaDemoForm.CommandExecuted(Sender: TObject);
begin
  Inc(FExecutions);
  ShowStatus('Komut yürütüldü: ' + TSkiaDemoCommand(Sender).Id);
end;

procedure TRibbonSkiaDemoForm.ShowStatus(const AMessage: string);
begin
  if FStatus = nil then Exit;
  FStatus.Text := AMessage + sLineBreak + 'Etkin sekme: ' + FRibbon.ActiveTabId +
    ' • Yürütülen komut: ' + IntToStr(FExecutions) +
    ' • TSkLabel şablonu: ' + IntToStr(FRibbon.SkLabels.GetCount);
end;

function TRibbonSkiaDemoForm.VerifyPresentation: string;
var
  Errors: TStringList;
  procedure Need(ACondition: Boolean; const AMessage: string);
  begin
    if not ACondition then Errors.Add(AMessage);
  end;
  procedure NeedSkLabel(const AId, AText: string; AResolved: Boolean);
  var
    Control: TControl;
  begin
    Control := FRibbon.FindItemView(AId);
    Need(Control is TRibbonSkLabelControl, AId + ': TSkLabel görünümü yok');
    if not (Control is TRibbonSkLabelControl) then Exit;
    Need(TRibbonSkLabelItemView(Control.Owner).TemplateResolved = AResolved,
      AId + ': şablon çözümleme durumu beklenmiyor');
    Need(TSkLabel(Control).Text = AText, AId + ': metin "' + TSkLabel(Control).Text + '"');
    Need(Control.Visible and (Control.Width > 1) and (Control.Height > 1),
      AId + ': görünür boyut yok');
  end;
  procedure NeedSvg(const AId: string);
  var
    Button: TRibbonCommandButton;
  begin
    Button := FRibbon.FindButtonView(AId);
    Need((Button <> nil) and Button.HasIcon, AId + ': SVG ikonu çözümlenmedi');
  end;
begin
  Errors := TStringList.Create;
  try
    FRibbon.Refresh;
    Need(FRibbon.ActiveTabId = 'home', 'etkin sekme home değil');
    NeedSvg('new');
    NeedSvg('save');
    NeedSvg('share');
    NeedSvg('chart');
    NeedSvg('badge');
    Need(TRibbonCommandButton(FRibbon.FindQuickAccessView('qat-save')).HasIcon,
      'QAT SVG ikonu çözümlenmedi');
    NeedSkLabel('title', 'Proje Raporu', True);
    NeedSkLabel('rich', 'Skia zengin metin', True);
    NeedSkLabel('status', 'Son kayıt: bugün 18:40', True);
    NeedSkLabel('mixed-label', 'TSkSvg + TSkLabel', True);
    NeedSkLabel('fallback', 'Şablonsuz TSkLabel', False);
    Need((FRibbon.FindItemView('classic') is TLabel) and
      not (FRibbon.FindItemView('classic') is TSkLabel), 'klasik etiket TLabel değil');
    Need(FRibbon.ExecuteButtonById('save') = rdrExecuted, 'Kaydet komutu yürütülmedi');
    Need(FExecutions = 1, 'komut sayısı 1 değil');
    Result := Errors.Text.Trim;
  finally
    Errors.Free;
  end;
end;

end.
