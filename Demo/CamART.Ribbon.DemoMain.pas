unit CamART.Ribbon.DemoMain;

{$B-}

interface

uses
  System.Classes, System.SysUtils, System.Types, System.UITypes,
  FMX.Types, FMX.Forms, FMX.Controls, FMX.StdCtrls, FMX.Layouts,
  FMX.Memo, FMX.ScrollBox, FMX.Objects, FMX.ActnList,
  CamART.Ribbon.Types, CamART.Ribbon.Model, CamART.Ribbon.Commands,
  CamART.Ribbon.References, CamART.Ribbon.Control;

type
  TRibbonDemoForm = class(TForm)
  private
    FRibbon: TCamARTRibbon;
    FThemeDemo: TForm;
    FLog: TMemo;
    FToolbarScroll: THorzScrollBox;
    FToolbar: TLayout;
    FTelemetry: TLabel;
    FTelemetryTimer: TTimer;
    FDensityTool, FPinTool, FCollapsePolicyTool: TButton;
    FLongCaptionTool, FMotionTool, FStressTool: TButton;
    FReady, FLongCaptions, FAllowCollapse: Boolean;
    FPrimaryGroup: TRibbonGroup;
    FPrimaryButton: TRibbonButton;
    FStressTab: TRibbonTab;
    FPreview: TLabel;
    FPreviewPanel: TRectangle;
    FHoverStatus: TLabel;
    FBookA, FBookB: TStyleBook;
    FStyleIndex: Integer;
    FHome: TRibbonTab;
    FText: TRibbonEdit;
    FMode: TRibbonComboBox;
    FColor: TRibbonColorPicker;
    FFont: TRibbonFontPicker;
    FSize: TRibbonFontSizePicker;
    FGallery: TRibbonGallery;
    FProgress: TRibbonProgressBar;
    FBoldAction: TAction;
    function AddTool(const ACaption: string; AHandler: TNotifyEvent): TButton;
    procedure ArrangeTools;
    procedure ConfigureDemoInput;
    procedure UpdateToolStates;
    procedure UpdateTelemetry;
    procedure TelemetryTick(Sender: TObject);
    procedure ReportLayout(const AReason: string);
    procedure DensityClick(Sender: TObject);
    procedure PinClick(Sender: TObject);
    procedure CollapsePolicyClick(Sender: TObject);
    procedure LongCaptionClick(Sender: TObject);
    procedure MotionClick(Sender: TObject);
    procedure StressClick(Sender: TObject);
    procedure MeasureRefreshClick(Sender: TObject);
    procedure BuildRibbon;
    procedure Log(const AText: string);
    procedure UpdatePreview;
    procedure ValueChanged(Sender: TObject);
    procedure ButtonChanged(Sender: TObject);
    procedure LocalClick(Sender: TObject);
    procedure CommandFinished(Sender: TObject);
    procedure NativeBoldExecute(Sender: TObject);
    procedure AdvanceProgress(Sender: TObject);
    procedure HoverEnter(Sender: TObject);
    procedure HoverLeave(Sender: TObject);
    procedure CollapseClick(Sender: TObject);
    procedure StyleClick(Sender: TObject);
    procedure ThemeDemoClick(Sender: TObject);
    procedure QATPositionClick(Sender: TObject);
    procedure QATVisibleClick(Sender: TObject);
    procedure HideSourceClick(Sender: TObject);
    procedure ResetProgressClick(Sender: TObject);
    procedure SelectionChanged(Sender: TObject);
    procedure Diagnostic(Sender: TObject; const AMessage: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ExecuteDemoCommand(const AId: string);
  end;

var
  RibbonDemoForm: TRibbonDemoForm;

implementation

uses
  System.Math,
  System.Diagnostics,
  FMX.InertialMovement,
  FMX.BehaviorManager,
  CamART.Ribbon.Views,
  CamART.Ribbon.Interaction,
  CamART.Ribbon.Style,
  CamART.Ribbon.DemoStyles,
  CamART.Ribbon.DemoIcons,
  CamART.Ribbon.ThemeDemo;

type
  TDemoToolButton = class(TRibbonInputButton)
  private
    FOnAction: TNotifyEvent;
    procedure Activate(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    property OnAction: TNotifyEvent read FOnAction write FOnAction;
  end;

  TDemoCommand = class(TInterfacedObject, IRibbonCommand)
  private
    FForm: TRibbonDemoForm;
    FId: string;
  public
    constructor Create(AForm: TRibbonDemoForm; const AId: string);
    function CanExecute: Boolean;
    procedure Execute;
  end;

constructor TDemoToolButton.Create(AOwner: TComponent);
begin
  inherited;
  OnClick := Activate;
end;

procedure TDemoToolButton.Activate(Sender: TObject);
var
  Handler: TNotifyEvent;
begin
  if not RibbonActivationAllowed(Self) then Exit;
  Handler := FOnAction;
  if Assigned(Handler) then Handler(Self);
end;

constructor TDemoCommand.Create(AForm: TRibbonDemoForm; const AId: string);
begin
  inherited Create;
  FForm := AForm;
  FId := AId;
end;

function TDemoCommand.CanExecute: Boolean;
begin
  Result := not (csDestroying in FForm.ComponentState);
end;

procedure TDemoCommand.Execute;
begin
  FForm.ExecuteDemoCommand(FId);
end;

constructor TRibbonDemoForm.Create(AOwner: TComponent);
var
  Header, PreviewTitle: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := 'CamART FMX Ribbon — Aşama 5 tema sistemi';
  FAllowCollapse := True;
  Width := 1260;
  Height := 800;

  Header := TLabel.Create(Self);
  Header.Parent := Self;
  Header.Align := TAlignLayout.Top;
  Header.Height := 36;
  Header.Margins.Left := 12;
  Header.Text := 'CamART Ribbon | Pencereyi daraltın; grup menülerini ve dokunma kipini deneyin';
  Header.TextSettings.WordWrap := True;
  Header.Height := 44;

  FRibbon := TCamARTRibbon.Create(Self);
  FRibbon.Name := 'Ribbon1';
  FRibbon.Parent := Self;
  FRibbon.Align := TAlignLayout.Top;
  FRibbon.Height := 250;
  FRibbon.StyleLookup := RibbonRootStyleName;

  FPreviewPanel := TRectangle.Create(Self);
  FPreviewPanel.Parent := Self;
  FPreviewPanel.Align := TAlignLayout.Top;
  FPreviewPanel.Height := 170;
  FPreviewPanel.Margins.Rect := RectF(12, 12, 12, 8);
  FPreviewPanel.Fill.Color := $FFF2F6FC;
  FPreviewPanel.Stroke.Color := $FFD2DAE5;
  FPreviewPanel.XRadius := 6;
  FPreviewPanel.YRadius := 6;
  FPreviewPanel.HitTest := False;
  PreviewTitle := TLabel.Create(Self);
  PreviewTitle.Parent := FPreviewPanel;
  PreviewTitle.Align := TAlignLayout.Top;
  PreviewTitle.Height := 34;
  PreviewTitle.Margins.Left := 16;
  PreviewTitle.Text := 'CANLI ÖNİZLEME — Biçim ve Galeri sekmelerini deneyin';
  FPreview := TLabel.Create(Self);
  FPreview.Parent := FPreviewPanel;
  FPreview.Align := TAlignLayout.Client;
  FPreview.Margins.Rect := RectF(16, 8, 16, 12);
  FPreview.StyledSettings := [];
  FPreview.TextSettings.Font.Size := 24;
  FPreview.TextSettings.WordWrap := True;

  FToolbarScroll := THorzScrollBox.Create(Self);
  FToolbarScroll.Parent := Self;
  FToolbarScroll.Align := TAlignLayout.Bottom;
  FToolbarScroll.Height := 64;
  FToolbarScroll.ShowScrollBars := True;
  FToolbar := TLayout.Create(Self);
  { Public parenting routes the toolbar through the scroll content. }
  FToolbar.Parent := FToolbarScroll;
  FToolbar.Height := 56;
  FDensityTool := AddTool('Girdi: fare', DensityClick);
  FPinTool := AddTool('Pano sabitle: kapalı', PinClick);
  FCollapsePolicyTool := AddTool('Grup menüsü: açık', CollapsePolicyClick);
  FLongCaptionTool := AddTool('Uzun başlık: kapalı', LongCaptionClick);
  FMotionTool := AddTool('Azaltılmış hareket: açık', MotionClick);
  FStressTool := AddTool('Yük oluştur: 50 × 12', StressClick);
  AddTool('Yenilemeyi ölç', MeasureRefreshClick);
  AddTool('Daralt / aç', CollapseClick);
  AddTool('QAT üst / alt', QATPositionClick);
  AddTool('QAT göster / gizle', QATVisibleClick);
  AddTool('Kaynak sekmeyi gizle', HideSourceClick);
  AddTool('StyleBook değiştir', StyleClick);
  AddTool('Tema ve StyleBook örneği', ThemeDemoClick);
  AddTool('İlerlemeyi sıfırla', ResetProgressClick);
  ArrangeTools;
  ConfigureDemoInput;

  FTelemetry := TLabel.Create(Self);
  FTelemetry.Parent := Self;
  FTelemetry.Align := TAlignLayout.Bottom;
  FTelemetry.Height := 56;
  FTelemetry.Margins.Left := 12;
  FTelemetry.Margins.Right := 12;
  FTelemetry.TextSettings.WordWrap := True;
  FTelemetry.HitTest := False;

  FHoverStatus := TLabel.Create(Self);
  FHoverStatus.Parent := Self;
  FHoverStatus.Align := TAlignLayout.Bottom;
  FHoverStatus.Height := 28;
  FHoverStatus.Margins.Left := 12;
  FHoverStatus.Text := 'Büyük/küçük/ikon düğmeleri ve açılır oklar gerçek FMX kontrolleridir.';
  FLog := TMemo.Create(Self);
  FLog.Parent := Self;
  FLog.Align := TAlignLayout.Client;
  FLog.Margins.Rect := RectF(12, 4, 12, 4);
  FLog.ReadOnly := True;

  FBoldAction := TAction.Create(Self);
  FBoldAction.Text := 'Kalın';
  FBoldAction.AutoCheck := True;
  FBoldAction.OnExecute := NativeBoldExecute;
  RegisterRibbonDemoIcons(FRibbon.Icons);
  RegisterRibbonDemoSvgIcons(FRibbon.SvgIcons);
  BuildRibbon;
  FBookA := CreateRibbonDemoStyleBook(Self, $FFE8F0FB);
  FBookB := CreateRibbonDemoStyleBook(Self, $FFEEE9F6);
  FRibbon.OnDiagnostic := Diagnostic;
  FRibbon.OnActiveTabChanged := SelectionChanged;
  UpdatePreview;
  FReady := True;
  UpdateToolStates;
  UpdateTelemetry;
  FTelemetryTimer := TTimer.Create(Self);
  FTelemetryTimer.Enabled := False;
  FTelemetryTimer.Interval := 300;
  FTelemetryTimer.OnTimer := TelemetryTick;
  FTelemetryTimer.Enabled := True;
  Log('Aşama 4: 13 öğe türü ve altı düğme davranışı korunur; yerleşim içeriğe göre küçülür.');
  Log('Daraltılan grubu açarak düzenleyicileri ve galeri seçimini deneyin; Esc ile geri dönün.');
  Log('Grup menüsünü kapatmak veya Pano grubunu sabitlemek, dar alanda kaydırma yolunu gösterir.');
  Log('Yük sekmesi istek üzerine 50 grup / 600 komut oluşturur; aynı düğme etkin yükü kaldırır.');
  Log('Sayaçlar bu çalıştırmadan gelir. Yenileme süresi çizim ve GPU sunum süresini içermez.');
  Log('Kaydet/Aç/Dışa aktar örnekleri yalnız bu günlüğe yazar; kullanıcı dosyalarını değiştirmez.');
  Log('Yazı tipi listesi yapılandırılmış bir katalogdur; işletim sistemindeki fontların tarandığı iddia edilmez.');
  Log('Native derleme ve platform kabul testleri ayrı test uygulamalarında çalıştırılmalıdır.');
end;

destructor TRibbonDemoForm.Destroy;
begin
  FReady := False;
  if FTelemetryTimer <> nil then FTelemetryTimer.Enabled := False;
  inherited;
end;

function TRibbonDemoForm.AddTool(const ACaption: string;
  AHandler: TNotifyEvent): TButton;
var
  Button: TDemoToolButton;
begin
  Button := TDemoToolButton.Create(Self);
  Button.Parent := FToolbar;
  Button.Text := ACaption;
  Button.OnAction := AHandler;
  Button.TabOrder := FToolbar.ControlsCount - 1;
  Button.Height := 44;
  AttachRibbonInput(Button, FRibbon.InputDensity);
  Result := Button;
end;

procedure TRibbonDemoForm.ArrangeTools;
var
  Child: TFmxObject;
  Button: TButton;
  Measure: TRibbonTextMeasure;
  Size: TSizeF;
  X, W, H: Single;
begin
  if FToolbar = nil then Exit;
  Measure := TRibbonTextMeasure.Create;
  try
    X := 8;
    H := 44;
    for Child in FToolbar.Children do
      if Child is TButton then
      begin
        Button := TButton(Child);
        Button.ApplyStyleLookup;
        Size := Measure.Measure(Button.Text, Button.ResultingTextSettings.Font);
        W := Max(144, Size.Width + 32);
        H := Max(H, Size.Height + 16);
        Button.SetBounds(X, 6, W, Max(44, Size.Height + 16));
        X := X + W + 8;
      end;
    FToolbar.Width := X;
    FToolbar.Height := H + 12;
    FToolbarScroll.Height := FToolbar.Height + 8;
  finally
    Measure.Free;
  end;
end;

procedure TRibbonDemoForm.ConfigureDemoInput;
var
  Child: TFmxObject;
begin
  AttachRibbonInput(FToolbarScroll, FRibbon.InputDensity);
  FToolbarScroll.TouchTracking := TBehaviorBoolean.True;
  if FToolbarScroll.AniCalculations <> nil then
  begin
    FToolbarScroll.AniCalculations.TouchTracking := [ttHorizontal];
    FToolbarScroll.AniCalculations.Animation := not FRibbon.ReduceMotion;
    FToolbarScroll.AniCalculations.BoundsAnimation := not FRibbon.ReduceMotion;
  end;
  if FRibbon.ReduceMotion then
  begin
    FToolbarScroll.ScrollAnimation := TBehaviorBoolean.False;
    FToolbarScroll.Bounces := TBehaviorBoolean.False;
  end
  else
  begin
    FToolbarScroll.ScrollAnimation := TBehaviorBoolean.PlatformDefault;
    FToolbarScroll.Bounces := TBehaviorBoolean.PlatformDefault;
  end;
  for Child in FToolbar.Children do
    if Child is TButton then AttachRibbonInput(TButton(Child), FRibbon.InputDensity);
end;

procedure TRibbonDemoForm.UpdateToolStates;
const
  StateNames: array[Boolean] of string = ('kapalı', 'açık');
begin
  if not FReady then Exit;
  if FRibbon.InputDensity = ridTouch then FDensityTool.Text := 'Girdi: dokunma'
  else FDensityTool.Text := 'Girdi: fare';
  FPinTool.Text := 'Pano sabitle: ' + StateNames[FPrimaryGroup.Pinned];
  FCollapsePolicyTool.Text := 'Grup menüsü: ' + StateNames[FAllowCollapse];
  FLongCaptionTool.Text := 'Uzun başlık: ' + StateNames[FLongCaptions];
  FMotionTool.Text := 'Azaltılmış hareket: ' + StateNames[FRibbon.ReduceMotion];
  if FStressTab = nil then FStressTool.Text := 'Yük oluştur: 50 × 12'
  else if FRibbon.ActiveTabId = FStressTab.Id then FStressTool.Text := 'Yükü kaldır: 600 komut'
  else FStressTool.Text := 'Yük sekmesini aç';
  ArrangeTools;
end;

procedure TRibbonDemoForm.UpdateTelemetry;
var
  Mode, MessageText: string;
begin
  if not FReady then Exit;
  if FRibbon.LayoutMode = rlmCompactMenu then Mode := 'Kompakt menü'
  else Mode := 'Gruplar';
  MessageText := Format('%s | %.0f birim | Yerleşim %d | Ölçüm %d | Önbellek %d | Etkin görünüm %d',
    [Mode, FRibbon.Width, FRibbon.LayoutPassCount, FRibbon.MeasurementPassCount,
     FRibbon.MeasurementCacheHitCount, FRibbon.VisualItemCount]);
  if FTelemetry.Text <> MessageText then FTelemetry.Text := MessageText;
end;

procedure TRibbonDemoForm.TelemetryTick(Sender: TObject);
begin
  UpdateTelemetry;
end;

procedure TRibbonDemoForm.ReportLayout(const AReason: string);
begin
  UpdateTelemetry;
  Log(AReason + ' | ' + FTelemetry.Text);
end;

procedure TRibbonDemoForm.DensityClick(Sender: TObject);
begin
  if FRibbon.InputDensity = ridPointer then FRibbon.InputDensity := ridTouch
  else FRibbon.InputDensity := ridPointer;
  ConfigureDemoInput;
  UpdateToolStates;
  ReportLayout(FDensityTool.Text);
end;

procedure TRibbonDemoForm.PinClick(Sender: TObject);
begin
  FRibbon.BeginUpdate;
  try
    FPrimaryGroup.Pinned := not FPrimaryGroup.Pinned;
    FHome.Visible := True;
  finally
    FRibbon.EndUpdate;
  end;
  FRibbon.ActiveTabId := FHome.Id;
  UpdateToolStates;
  ReportLayout(FPinTool.Text);
end;

procedure TRibbonDemoForm.CollapsePolicyClick(Sender: TObject);
var
  Tab: TRibbonTab;
  Group: TRibbonGroup;
begin
  FAllowCollapse := not FAllowCollapse;
  FRibbon.BeginUpdate;
  try
    for Tab in FRibbon.Model.Tabs do
      for Group in Tab.Groups do Group.AllowCollapse := FAllowCollapse;
  finally
    FRibbon.EndUpdate;
  end;
  UpdateToolStates;
  ReportLayout(FCollapsePolicyTool.Text);
end;

procedure TRibbonDemoForm.LongCaptionClick(Sender: TObject);
begin
  FLongCaptions := not FLongCaptions;
  FRibbon.BeginUpdate;
  try
    if FLongCaptions then
    begin
      FHome.Caption := 'Düzenleme, belge üretimi ve ortak çalışma araçları';
      FPrimaryGroup.Caption := 'Pano işlemleri ve gelişmiş yapıştırma seçenekleri';
      FPrimaryButton.Caption := 'Yapıştır — özgün biçimlendirmeyi koru';
    end
    else
    begin
      FHome.Caption := 'Giriş';
      FPrimaryGroup.Caption := 'Pano ve boyutlar';
      FPrimaryButton.Caption := 'Yapıştır';
    end;
    FHome.Visible := True;
  finally
    FRibbon.EndUpdate;
  end;
  FRibbon.ActiveTabId := FHome.Id;
  UpdateToolStates;
  ReportLayout(FLongCaptionTool.Text);
end;

procedure TRibbonDemoForm.MotionClick(Sender: TObject);
begin
  FRibbon.ReduceMotion := not FRibbon.ReduceMotion;
  ConfigureDemoInput;
  UpdateToolStates;
  ReportLayout(FMotionTool.Text);
end;

procedure TRibbonDemoForm.StressClick(Sender: TObject);
const
  GroupCount = 50;
  ButtonsPerGroup = 12;
var
  Timer: TStopwatch;
  Group: TRibbonGroup;
  Button: TRibbonButton;
  OldTab: TRibbonTab;
  I, J: Integer;
begin
  if FStressTab <> nil then
  begin
    if FRibbon.ActiveTabId = FStressTab.Id then
    begin
      FRibbon.ClosePopup;
      OldTab := FStressTab;
      FStressTab := nil;
      FRibbon.RemoveTab(OldTab);
      UpdateToolStates;
      ReportLayout('Yük sekmesi ve komut modeli kaldırıldı');
    end
    else
    begin
      FRibbon.ActiveTabId := FStressTab.Id;
      UpdateToolStates;
      ReportLayout('Mevcut yük sekmesi yeniden etkinleştirildi');
    end;
    Exit;
  end;
  Timer := TStopwatch.StartNew;
  FRibbon.BeginUpdate;
  try
    FStressTab := FRibbon.AddTab('Yük deneyi — 600 komut');
    for I := 1 to GroupCount do
    begin
      Group := FStressTab.AddGroup(Format('Yük grubu %.2d', [I]));
      Group.AllowCollapse := FAllowCollapse;
      Group.CollapsePriority := I mod 5;
      for J := 1 to ButtonsPerGroup do
      begin
        Button := Group.AddButton(Format('Komut %.2d.%.2d', [I, J]));
        Button.ButtonStyle := rbsLarge;
        if J mod 3 = 0 then Button.IconKey := 'copy';
        Button.OnClick := LocalClick;
        Button.Hint := 'Yük örneği; tıklama yalnız günlüğe yazılır.';
      end;
    end;
  finally
    FRibbon.EndUpdate;
  end;
  FRibbon.ActiveTabId := FStressTab.Id;
  Timer.Stop;
  UpdateToolStates;
  ReportLayout(Format('50 grup / 600 komut oluşturma ve etkinleştirme: %.3f ms',
    [Timer.Elapsed.TotalMilliseconds]));
end;

procedure TRibbonDemoForm.MeasureRefreshClick(Sender: TObject);
var
  Timer: TStopwatch;
  BeforeLayout, BeforeMeasure: Integer;
begin
  BeforeLayout := FRibbon.LayoutPassCount;
  BeforeMeasure := FRibbon.MeasurementPassCount;
  Timer := TStopwatch.StartNew;
  FRibbon.Refresh;
  Timer.Stop;
  ReportLayout(Format('Bu çalıştırmada bir Refresh: %.3f ms; yerleşim +%d, ölçüm +%d',
    [Timer.Elapsed.TotalMilliseconds, FRibbon.LayoutPassCount - BeforeLayout,
     FRibbon.MeasurementPassCount - BeforeMeasure]));
end;

procedure TRibbonDemoForm.BuildRibbon;
const
  CommandIds: array[0..13] of string = (
    'demo.new', 'demo.open', 'demo.save', 'demo.copy', 'demo.paste',
    'demo.export', 'demo.export.pdf', 'demo.export.image',
    'style.blue', 'style.green', 'style.gold', 'style.plum',
    'style.slate', 'style.coral');
  StyleCaptions: array[0..5] of string =
    ('Mavi', 'Yeşil', 'Altın', 'Mor', 'Arduvaz', 'Mercan');
  StyleKeys: array[0..5] of string =
    ('style.blue', 'style.green', 'style.gold', 'style.plum', 'style.slate', 'style.coral');
var
  Id: string;
  FormatTab, GalleryTab, SvgTab: TRibbonTab;
  Group: TRibbonGroup;
  PasteButton, SaveButton, BoldButton, Button, GalleryButton: TRibbonButton;
  NativeCheck: TRibbonCheckBox;
  Radio: TRibbonRadioButton;
  Menu: TRibbonDropDownMenu;
  Link: TRibbonCommandLink;
  I: Integer;
begin
  for Id in CommandIds do
    FRibbon.Commands.RegisterCommand(Id, TDemoCommand.Create(Self, Id));
  FRibbon.BindAction('format.bold', FBoldAction);

  FRibbon.BeginUpdate;
  try
    FHome := FRibbon.AddTab('Giriş');
    FormatTab := FRibbon.AddTab('Biçim ve değerler');
    GalleryTab := FRibbon.AddTab('Galeri ve seçim');
    SvgTab := FRibbon.AddTab('SVG ikonlar');
    Group := SvgTab.AddGroup('Vektör ve bitmap birlikte');
    Button := Group.AddButton('Renkli belge');
    Button.IconKey := 'svg.document';
    Button.OnClick := LocalClick;
    Button.Hint := 'TSkSvg: özgün renkler ve geçişli dolgu';
    FRibbon.QuickAccess.AddItem(Button.Id);
    FRibbon.ApplicationMenu.AddItem(Button.Id);
    Button := Group.AddButton('Yeşil belge');
    Button.IconKey := 'svg.green';
    Button.ButtonStyle := rbsSmall;
    Button.OnClick := LocalClick;
    Button := Group.AddButton('Gri belge');
    Button.IconKey := 'svg.gray';
    Button.ButtonStyle := rbsIcon;
    Button.OnClick := LocalClick;
    Button := Group.AddButton('Mevcut bitmap');
    Button.IconKey := 'save';
    Button.OnClick := LocalClick;

    Group := GalleryTab.AddGroup('Stil galerisi — gerçek seçim');
    FGallery := Group.AddGallery('Belge stilleri');
    for I := 0 to High(StyleKeys) do
      FGallery.Entries.AddEntry(StyleCaptions[I], StyleKeys[I], StyleKeys[I]);
    FGallery.SelectedId := FGallery.Entries[0].Id;
    FGallery.OnChange := ValueChanged;

    Group := FHome.AddGroup('Pano ve boyutlar');
    FPrimaryGroup := Group;
    Group.CollapsePriority := 100;
    PasteButton := Group.AddButton('Yapıştır');
    FPrimaryButton := PasteButton;
    PasteButton.IconKey := 'paste';
    PasteButton.CommandId := 'demo.paste';
    PasteButton.Hint := 'Büyük düğme: ikon üstte, açıklama altta';
    PasteButton.OnMouseEnter := HoverEnter;
    PasteButton.OnMouseLeave := HoverLeave;
    Button := Group.AddButton('Kopyala');
    Button.IconKey := 'copy';
    Button.ButtonStyle := rbsSmall;
    Button.CommandId := 'demo.copy';
    Button.Hint := 'Küçük düğme: ikon ile metin yan yana';
    Group.AddSeparator;
    SaveButton := Group.AddButton('Kaydet');
    SaveButton.IconKey := 'save';
    SaveButton.ButtonStyle := rbsIcon;
    SaveButton.CommandId := 'demo.save';
    SaveButton.Hint := 'Yalnız ikon; kaydetme bu demoda günlüğe yazılır';
    Button := Group.AddButton('Eksik ikon');
    Button.ButtonStyle := rbsIcon;
    Button.IconKey := 'intentionally-missing';
    Button.OnClick := LocalClick;
    Button.Hint := 'Bilinmeyen ikon anahtarı açıklamayı görünür bırakır';

    Group := FHome.AddGroup('Düğme davranışları');
    BoldButton := Group.AddButton('Kalın');
    BoldButton.IconKey := 'bold';
    BoldButton.ButtonStyle := rbsSmall;
    BoldButton.ButtonKind := rbkToggle;
    BoldButton.CommandId := 'format.bold';
    BoldButton.OnExecuted := CommandFinished;
    BoldButton.Hint := 'Native TAction.AutoCheck, aynı durumu QAT ile paylaşır';
    Button := Group.AddButton('İzleme');
    Button.IconKey := 'check';
    Button.ButtonStyle := rbsSmall;
    Button.ButtonKind := rbkCheck;
    Button.OnClick := LocalClick;
    Button.OnChange := ButtonChanged;
    Button := Group.AddButton('Aç');
    Button.IconKey := 'open';
    Button.ButtonKind := rbkDropDown;
    Button.MenuItems.AddCommand('demo.new', 'Yeni örnek', 'new');
    Button.MenuItems.AddCommand('demo.open', 'Örnek aç', 'open');
    Button := Group.AddButton('Dışa aktar');
    Button.IconKey := 'export';
    Button.ButtonKind := rbkSplit;
    Button.CommandId := 'demo.export';
    Button.MenuItems.AddCommand('demo.export.pdf', 'PDF örneği', 'export');
    Button.MenuItems.AddCommand('demo.export.image', 'Görsel örneği', 'gallery');
    Button.Hint := 'Ana alan komutu çalıştırır; ayrı ok yalnız menüyü açar';
    GalleryButton := Group.AddButton('Stiller');
    GalleryButton.IconKey := 'gallery';
    GalleryButton.ButtonKind := rbkGallery;
    GalleryButton.GalleryId := FGallery.Id;
    Menu := Group.AddDropDownMenu('İşlemler');
    Menu.IconKey := 'open';
    Menu.ButtonStyle := rbsSmall;
    Menu.MenuItems.AddItem(SaveButton.Id);
    Menu.MenuItems.AddItem(PasteButton.Id);
    Menu.MenuItems.AddSeparator;
    Menu.MenuItems.AddCommand('demo.new', 'Yeni örnek', 'new');

    Group := FormatTab.AddGroup('Metin ve seçenek');
    Group.AddLabel('Yazı ve görünüm');
    FText := Group.AddEdit('Önizleme metni');
    FText.Text := 'Ribbon ile daha üretken uygulamalar';
    FText.OnChange := ValueChanged;
    FMode := Group.AddComboBox('Görünüm');
    FMode.Items.Add('Normal metin');
    FMode.Items.Add('Başlık');
    FMode.Items.Add('Alt başlık');
    FMode.ItemIndex := 0;
    FMode.OnChange := ValueChanged;

    Group := FormatTab.AddGroup('Yazı tipi ve renk');
    FFont := Group.AddFontPicker('Yazı tipi kataloğu');
    FRibbon.PopulateFonts(FFont);
    if FFont.Items.Count > 0 then FFont.ItemIndex := 0;
    FFont.OnChange := ValueChanged;
    FSize := Group.AddFontSizePicker('Boyut');
    FSize.FontSize := 24;
    FSize.OnChange := ValueChanged;
    FColor := Group.AddColorPicker('Metin rengi');
    FColor.Color := $FF285A91;
    FColor.OnChange := ValueChanged;

    Group := FormatTab.AddGroup('Yerel seçim kontrolleri');
    NativeCheck := Group.AddCheckBox('Canlı denetim');
    NativeCheck.ButtonStyle := rbsSmall;
    NativeCheck.IconKey := 'check';
    NativeCheck.OnClick := LocalClick;
    NativeCheck.OnChange := ButtonChanged;
    Radio := Group.AddRadioButton('Normal');
    Radio.ButtonStyle := rbsSmall;
    Radio.GroupName := 'demo.mode';
    Radio.Checked := True;
    Radio.OnClick := LocalClick;
    Radio.OnChange := ButtonChanged;
    Radio := Group.AddRadioButton('Odak');
    Radio.ButtonStyle := rbsSmall;
    Radio.GroupName := 'demo.mode';
    Radio.OnClick := LocalClick;
    Radio.OnChange := ButtonChanged;

    Group := GalleryTab.AddGroup('İlerleme');
    Group.AddLabel('Gerçek TProgressBar');
    FProgress := Group.AddProgressBar('İşlem');
    FProgress.SetRange(0, 100);
    FProgress.Value := 20;
    Button := Group.AddButton('İlerle +10');
    Button.IconKey := 'progress';
    Button.ButtonStyle := rbsSmall;
    Button.OnClick := AdvanceProgress;

    FRibbon.QuickAccess.AddItem(SaveButton.Id);
    FRibbon.QuickAccess.AddItem(BoldButton.Id);
    Link := FRibbon.QuickAccess.AddItem(NativeCheck.Id);
    Link.OverrideHint := True;
    Link.Hint := 'Kaynak sekme kapalı olsa da aynı seçim durumu';
    FRibbon.QuickAccess.AddItem(GalleryButton.Id);
    FRibbon.ApplicationMenu.AddCommand('demo.new', 'Yeni örnek', 'new');
    FRibbon.ApplicationMenu.AddCommand('demo.open', 'Örnek aç', 'open');
    FRibbon.ApplicationMenu.AddItem(SaveButton.Id);
    FRibbon.ApplicationMenu.AddSeparator;
    FRibbon.ApplicationMenu.AddItem(BoldButton.Id);
    FRibbon.ApplicationCaption := 'Dosya';
    FRibbon.ApplicationButtonVisible := True;
    FRibbon.QuickAccessVisible := True;
    FRibbon.QuickAccessPosition := rqpAbove;
  finally
    FRibbon.EndUpdate;
  end;
  FRibbon.ActiveTabId := FHome.Id;
end;

procedure TRibbonDemoForm.Log(const AText: string);
begin
  if FLog <> nil then
  begin
    FLog.Lines.Add(AText);
    while FLog.Lines.Count > 500 do FLog.Lines.Delete(0);
  end;
end;

procedure TRibbonDemoForm.ExecuteDemoCommand(const AId: string);
begin
  Log('Komut çalıştı: ' + AId);
  if AId = 'demo.new' then FText.Text := 'Yeni örnek metin';
  if AId = 'demo.paste' then FText.Text := 'Yapıştırılan örnek — İı Şş Ğğ';
  UpdatePreview;
end;

procedure TRibbonDemoForm.UpdatePreview;
const
  CardColors: array[0..5] of TAlphaColor =
    ($FFEAF2FC, $FFEAF5EF, $FFFFF6DF, $FFF2ECF8, $FFECF0F5, $FFFCECE7);
var
  Entry: TRibbonGalleryEntry;
  Prefix: string;
begin
  if (FText = nil) or (FFont = nil) or (FSize = nil) or
     (FColor = nil) or (FGallery = nil) then Exit;
  Prefix := '';
  if FMode.ItemIndex = 1 then Prefix := 'BAŞLIK  |  ';
  if FMode.ItemIndex = 2 then Prefix := 'Alt başlık  |  ';
  FPreview.Text := Prefix + FText.Text;
  if FFont.FontName <> '' then FPreview.TextSettings.Font.Family := FFont.FontName;
  if FSize.FontSize > 0 then FPreview.TextSettings.Font.Size := FSize.FontSize;
  FPreview.TextSettings.FontColor := FColor.Color;
  if FBoldAction.Checked then FPreview.TextSettings.Font.Style := [TFontStyle.fsBold]
  else FPreview.TextSettings.Font.Style := [];
  Entry := FGallery.Entries.FindById(FGallery.SelectedId);
  if (Entry <> nil) and (Entry.Index <= High(CardColors)) then
    FPreviewPanel.Fill.Color := CardColors[Entry.Index];
end;

procedure TRibbonDemoForm.ValueChanged(Sender: TObject);
begin
  if Sender is TRibbonNode then Log('Değer değişti: ' + TRibbonNode(Sender).Caption);
  UpdatePreview;
end;

procedure TRibbonDemoForm.ButtonChanged(Sender: TObject);
begin
  if Sender is TRibbonButton then
    Log(TRibbonButton(Sender).Caption + ' Checked=' +
      BoolToStr(TRibbonButton(Sender).Checked, True));
  UpdatePreview;
end;

procedure TRibbonDemoForm.LocalClick(Sender: TObject);
begin
  if Sender is TRibbonNode then Log('OnClick: ' + TRibbonNode(Sender).Caption);
end;

procedure TRibbonDemoForm.CommandFinished(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TRibbonDemoForm.NativeBoldExecute(Sender: TObject);
begin
  Log('Native TAction.Execute: Kalın (AutoCheck tek durum kaynağı)');
  UpdatePreview;
end;

procedure TRibbonDemoForm.AdvanceProgress(Sender: TObject);
begin
  if FProgress.Value >= FProgress.Max then FProgress.Value := FProgress.Min
  else FProgress.Value := FProgress.Value + 10;
  Log('İlerleme: ' + FloatToStr(FProgress.Value));
end;

procedure TRibbonDemoForm.HoverEnter(Sender: TObject);
begin
  if Sender is TRibbonNode then FHoverStatus.Text := 'OnMouseEnter: ' + TRibbonNode(Sender).Caption;
end;

procedure TRibbonDemoForm.HoverLeave(Sender: TObject);
begin
  FHoverStatus.Text := 'OnMouseLeave: imleç düğmeden ayrıldı.';
end;

procedure TRibbonDemoForm.CollapseClick(Sender: TObject);
begin
  FRibbon.Collapsed := not FRibbon.Collapsed;
end;

procedure TRibbonDemoForm.ThemeDemoClick(Sender: TObject);
begin
  if FThemeDemo = nil then FThemeDemo := TRibbonThemeDemoForm.Create(Self);
  FThemeDemo.Show;
end;

procedure TRibbonDemoForm.StyleClick(Sender: TObject);
begin
  FRibbon.ClosePopup;
  FStyleIndex := (FStyleIndex + 1) mod 3;
  case FStyleIndex of
    0: StyleBook := nil;
    1: StyleBook := FBookA;
    2: StyleBook := FBookB;
  end;
  FRibbon.Refresh;
  UpdatePreview;
  ArrangeTools;
  ReportLayout('StyleBook seçimi: ' + IntToStr(FStyleIndex) + '; model ve seçim korunur.');
end;

procedure TRibbonDemoForm.QATPositionClick(Sender: TObject);
begin
  if FRibbon.QuickAccessPosition = rqpAbove then FRibbon.QuickAccessPosition := rqpBelow
  else FRibbon.QuickAccessPosition := rqpAbove;
end;

procedure TRibbonDemoForm.QATVisibleClick(Sender: TObject);
begin
  FRibbon.QuickAccessVisible := not FRibbon.QuickAccessVisible;
end;

procedure TRibbonDemoForm.HideSourceClick(Sender: TObject);
begin
  FHome.Visible := not FHome.Visible;
  Log('Giriş sekmesi Visible=' + BoolToStr(FHome.Visible, True) +
    '; QAT kaynak komutları bağımsız yüzeyde kullanılabilir.');
end;

procedure TRibbonDemoForm.ResetProgressClick(Sender: TObject);
begin
  FProgress.Value := FProgress.Min;
  Log('İlerleme sıfırlandı.');
end;

procedure TRibbonDemoForm.SelectionChanged(Sender: TObject);
begin
  UpdateToolStates;
  ReportLayout('Aktif sekme kimliği: ' + FRibbon.ActiveTabId);
end;

procedure TRibbonDemoForm.Diagnostic(Sender: TObject; const AMessage: string);
begin
  Log('Tanılama: ' + AMessage);
end;

end.
