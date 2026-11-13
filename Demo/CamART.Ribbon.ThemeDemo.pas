unit CamART.Ribbon.ThemeDemo;

{$B-}

interface

uses
  System.Classes, System.SysUtils, System.Types, System.UITypes,
  FMX.Types, FMX.Forms, FMX.Controls, FMX.Layouts, FMX.StdCtrls,
  FMX.ListBox, FMX.Memo,
  CamART.Ribbon.Types, CamART.Ribbon.Model, CamART.Ribbon.Control,
  CamART.Ribbon.Themes;

type
  { Native demonstration of the public component/form StyleBook contract.
    No application-wide style is installed and no shared template is edited. }
  TRibbonThemeDemoForm = class(TForm)
  private
    FBooks: array[TRibbonTheme] of TStyleBook;
    FCustomBook: TStyleBook;
    FRibbonA, FRibbonB: TCamARTRibbon;
    FFormChoice, FAChoice, FBChoice: TComboBox;
    FStatus: TLabel;
    FLog: TMemo;
    FReady, FUpdating: Boolean;
    function AddChoice(AParent: TFmxObject; const ACaption,
      AFirstChoice: string; AY: Single): TComboBox;
    function BookForChoice(AIndex: Integer): TStyleBook;
    function BookName(ABook: TStyleBook): string;
    procedure BuildSample(ARibbon: TCamARTRibbon);
    procedure ChoiceChanged(Sender: TObject);
    procedure ClearLocalBook(Sender: TObject);
    procedure DeleteCustomBook(Sender: TObject);
    procedure ToggleEnabled(Sender: TObject);
    procedure ModelClick(Sender: TObject);
    procedure ValueChanged(Sender: TObject);
    procedure Diagnostic(Sender: TObject; const AMessage: string);
    procedure UpdateStatus;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  FMX.ScrollBox,
  CamART.Ribbon.ThemeStyles,
  CamART.Ribbon.DemoIcons;

constructor TRibbonThemeDemoForm.Create(AOwner: TComponent);
var
  Theme: TRibbonTheme;
  Scroll: TScrollBox;
  Body, Choices, Tools: TLayout;
  Header, CaptionLabel: TLabel;
  Button: TButton;

  procedure AddAction(const AText: string; AHandler: TNotifyEvent; AX, AW: Single);
  begin
    Button := TButton.Create(Self);
    Button.Parent := Tools;
    Button.SetBounds(AX, 4, AW, 40);
    Button.Text := AText;
    Button.OnClick := AHandler;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CamART Ribbon — Aşama 5 tema ve StyleBook örneği';
  Width := 1220;
  Height := 920;
  for Theme := Low(TRibbonTheme) to High(TRibbonTheme) do
  begin
    FBooks[Theme] := CreateRibbonThemeStyleBook(Self, Theme);
    FBooks[Theme].Name := 'ThemeBook' + IntToStr(Ord(Theme));
  end;

  Scroll := TScrollBox.Create(Self);
  Scroll.Parent := Self;
  Scroll.Align := TAlignLayout.Client;
  Body := TLayout.Create(Self);
  Body.Parent := Scroll;
  Body.Align := TAlignLayout.Top;
  Body.Height := 1030;

  Header := TLabel.Create(Self);
  Header.Parent := Body;
  Header.Align := TAlignLayout.Top;
  Header.Height := 70;
  Header.Margins.Left := 12;
  Header.Margins.Right := 12;
  Header.TextSettings.WordWrap := True;
  Header.Text := 'Öncelik: Ribbon.StyleBook atanmışsa o kitap; nil ise formun kitabı. ' +
    'Her listeden altı temayı seçin. Üst Ribbon başlangıçta formdan devralır; ' +
    'alt Ribbon kendi koyu kitabını kullanır. Metin ve seçimleri değiştirip kitap değişimini deneyin.';

  Choices := TLayout.Create(Self);
  Choices.Parent := Body;
  Choices.Align := TAlignLayout.Top;
  Choices.Height := 144;
  FFormChoice := AddChoice(Choices, 'Form.StyleBook', 'Kitap yok / platform', 0);
  FAChoice := AddChoice(Choices, 'Üst Ribbon.StyleBook', 'Formdan devral (nil)', 48);
  FBChoice := AddChoice(Choices, 'Alt Ribbon.StyleBook', 'Formdan devral (nil)', 96);

  Tools := TLayout.Create(Self);
  Tools.Parent := Body;
  Tools.Align := TAlignLayout.Top;
  Tools.Height := 48;
  AddAction('Üst: formdan devral', ClearLocalBook, 12, 190);
  AddAction('Özel kitabı serbest bırak', DeleteCustomBook, 210, 230);
  AddAction('Üst: etkin / devre dışı', ToggleEnabled, 448, 220);

  CaptionLabel := TLabel.Create(Self);
  CaptionLabel.Parent := Body;
  CaptionLabel.Align := TAlignLayout.Top;
  CaptionLabel.Height := 30;
  CaptionLabel.Margins.Left := 12;
  CaptionLabel.Text := 'ÜST RIBBON — fallback Theme = Modern Light';
  FRibbonA := TCamARTRibbon.Create(Self);
  FRibbonA.Name := 'ThemeRibbonA';
  FRibbonA.Parent := Body;
  FRibbonA.Align := TAlignLayout.Top;
  FRibbonA.Height := 220;
  FRibbonA.Theme := rtModernLight;
  FRibbonA.OnDiagnostic := Diagnostic;
  BuildSample(FRibbonA);

  CaptionLabel := TLabel.Create(Self);
  CaptionLabel.Parent := Body;
  CaptionLabel.Align := TAlignLayout.Top;
  CaptionLabel.Height := 30;
  CaptionLabel.Margins.Left := 12;
  CaptionLabel.Text := 'ALT RIBBON — fallback Theme = Modern Dark';
  FRibbonB := TCamARTRibbon.Create(Self);
  FRibbonB.Name := 'ThemeRibbonB';
  FRibbonB.Parent := Body;
  FRibbonB.Align := TAlignLayout.Top;
  FRibbonB.Height := 220;
  FRibbonB.Theme := rtModernDark;
  FRibbonB.OnDiagnostic := Diagnostic;
  BuildSample(FRibbonB);

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Body;
  FStatus.Align := TAlignLayout.Top;
  FStatus.Height := 90;
  FStatus.Margins.Left := 12;
  FStatus.Margins.Right := 12;
  FStatus.TextSettings.WordWrap := True;
  FLog := TMemo.Create(Self);
  FLog.Parent := Body;
  FLog.Align := TAlignLayout.Client;
  FLog.Margins.Rect := RectF(12, 8, 12, 8);
  FLog.ReadOnly := True;
  FLog.WordWrap := True;

  FFormChoice.ItemIndex := Ord(rtOffice2007Blue) + 1;
  FAChoice.ItemIndex := 0;
  FBChoice.ItemIndex := Ord(rtModernDark) + 1;
  FReady := True;
  ChoiceChanged(nil);
  FLog.Lines.Add('Bu pencere native FMX demosudur. Kaynak teslim ortamında çalıştırılmadı.');
  FLog.Lines.Add('Seçici ve günlük standart form kontrolleridir; Ribbon kitapları bunlara atanmaz.');
end;

function TRibbonThemeDemoForm.AddChoice(AParent: TFmxObject;
  const ACaption, AFirstChoice: string; AY: Single): TComboBox;
var
  Row: TLayout;
  LabelControl: TLabel;
  Theme: TRibbonTheme;
begin
  Row := TLayout.Create(Self);
  Row.Parent := AParent;
  Row.SetBounds(12, AY, 1100, 44);
  Row.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop, TAnchorKind.akRight];
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := Row;
  LabelControl.Align := TAlignLayout.Left;
  LabelControl.Width := 220;
  LabelControl.Text := ACaption;
  Result := TComboBox.Create(Self);
  Result.Parent := Row;
  Result.Align := TAlignLayout.Client;
  Result.Items.Add(AFirstChoice);
  for Theme := Low(TRibbonTheme) to High(TRibbonTheme) do
    Result.Items.Add(RibbonThemeName(Theme));
  Result.Items.Add('Özel tema — token örneği');
  Result.OnChange := ChoiceChanged;
end;

function TRibbonThemeDemoForm.BookForChoice(AIndex: Integer): TStyleBook;
var
  Tokens: TRibbonThemeTokens;
begin
  Result := nil;
  if (AIndex >= 1) and (AIndex <= Ord(High(TRibbonTheme)) + 1) then
    Exit(FBooks[TRibbonTheme(AIndex - 1)]);
  if AIndex <> Ord(High(TRibbonTheme)) + 2 then Exit;
  if FCustomBook = nil then
  begin
    Tokens := RibbonThemeTokens(rtModernLight);
    Tokens.Surface := $FFF5F0FC;
    Tokens.SurfaceTop := $FFF5F0FC;
    Tokens.GroupSurface := $FFFDFBFF;
    Tokens.Accent := $FF6937A0;
    Tokens.Focus := $FF6937A0;
    Tokens.FontSize := 15;
    Tokens.PaddingX := 12;
    Tokens.GroupPadding := 10;
    Tokens.ButtonCornerRadius := 7;
    FCustomBook := CreateRibbonThemeStyleBook(Self, Tokens);
    FCustomBook.Name := 'CustomTokenBook';
  end;
  Result := FCustomBook;
end;

function TRibbonThemeDemoForm.BookName(ABook: TStyleBook): string;
begin
  if ABook = nil then Result := 'nil'
  else if ABook.Name <> '' then Result := ABook.Name
  else Result := ABook.ClassName;
end;

procedure TRibbonThemeDemoForm.BuildSample(ARibbon: TCamARTRibbon);
var
  Home, Values: TRibbonTab;
  Group: TRibbonGroup;
  Save, Button: TRibbonButton;
  Check: TRibbonCheckBox;
  Radio: TRibbonRadioButton;
  Edit: TRibbonEdit;
  Combo: TRibbonComboBox;
  Gallery: TRibbonGallery;
begin
  RegisterRibbonDemoIcons(ARibbon.Icons);
  ARibbon.BeginUpdate;
  try
    Home := ARibbon.AddTab('Giriş');
    Values := ARibbon.AddTab('Değerler ve galeri');
    Group := Home.AddGroup('Komut ve durum');
    Save := Group.AddButton('Kaydet');
    Save.IconKey := 'save';
    Save.OnClick := ModelClick;
    Button := Group.AddButton('Seçili düğme');
    Button.ButtonStyle := rbsSmall;
    Button.ButtonKind := rbkToggle;
    Button.Checked := True;
    Button.OnClick := ModelClick;
    Button := Group.AddButton('Devre dışı');
    Button.ButtonStyle := rbsSmall;
    Button.Enabled := False;
    Button := Group.AddButton('İşlemler');
    Button.ButtonKind := rbkSplit;
    Button.IconKey := 'open';
    Button.OnClick := ModelClick;
    Button.MenuItems.AddItem(Save.Id);
    Button.MenuItems.AddSeparator;
    Button.MenuItems.AddItem(Save.Id);
    Group.AddSeparator;
    Check := Group.AddCheckBox('İşaretli seçenek');
    Check.Checked := True;
    Check.ButtonStyle := rbsSmall;
    Radio := Group.AddRadioButton('Birinci');
    Radio.GroupName := 'theme.sample';
    Radio.Checked := True;
    Radio.ButtonStyle := rbsSmall;
    Radio := Group.AddRadioButton('İkinci');
    Radio.GroupName := 'theme.sample';
    Radio.ButtonStyle := rbsSmall;

    Group := Home.AddGroup('Native edit ve seçim');
    Group.AddLabel('Türkçe: İ ı Ş ş Ğ ğ');
    Edit := Group.AddEdit('Başlık');
    Edit.Text := 'Tema değişince korunur';
    Edit.OnChange := ValueChanged;
    Combo := Group.AddComboBox('Görünüm');
    Combo.Items.Add('Normal');
    Combo.Items.Add('Ayrıntılı');
    Combo.ItemIndex := 0;
    Combo.OnChange := ValueChanged;
    Group.AddColorPicker('Renk').Color := $FF6937A0;

    Group := Values.AddGroup('Galeri');
    Gallery := Group.AddGallery('Örnekler');
    Gallery.Entries.AddEntry('Mavi', '', 'style.blue');
    Gallery.Entries.AddEntry('Yeşil', '', 'style.green');
    Gallery.Entries.AddEntry('Mor', '', 'style.plum');
    Gallery.SelectedId := Gallery.Entries[0].Id;
    Gallery.OnChange := ValueChanged;
    Group := Values.AddGroup('İlerleme');
    Group.AddProgressBar('Örnek ilerleme').Value := 65;
    Group.AddLabel('Pencereyi daraltarak grup popup stilini de inceleyin.');
    Button := Group.AddButton('Galeri aç');
    Button.ButtonKind := rbkGallery;
    Button.GalleryId := Gallery.Id;
    Button.IconKey := 'gallery';

    ARibbon.QuickAccess.AddItem(Save.Id);
    ARibbon.QuickAccess.AddItem(Check.Id);
    ARibbon.ApplicationMenu.AddItem(Save.Id);
    ARibbon.ApplicationCaption := 'Dosya';
    ARibbon.ActiveTabId := Home.Id;
  finally
    ARibbon.EndUpdate;
  end;
end;

procedure TRibbonThemeDemoForm.ChoiceChanged(Sender: TObject);
begin
  if not FReady or FUpdating then Exit;
  FUpdating := True;
  try
    StyleBook := BookForChoice(FFormChoice.ItemIndex);
    FRibbonA.StyleBook := BookForChoice(FAChoice.ItemIndex);
    FRibbonB.StyleBook := BookForChoice(FBChoice.ItemIndex);
    FRibbonA.RefreshTheme;
    FRibbonB.RefreshTheme;
    UpdateStatus;
  finally
    FUpdating := False;
  end;
end;

procedure TRibbonThemeDemoForm.ClearLocalBook(Sender: TObject);
begin
  FAChoice.ItemIndex := 0;
  ChoiceChanged(Sender);
end;

procedure TRibbonThemeDemoForm.DeleteCustomBook(Sender: TObject);
const
  CustomIndex = Ord(High(TRibbonTheme)) + 2;
begin
  FUpdating := True;
  try
    { Native free notifications clear component and form references. The
      selectors are updated after destruction, without assigning replacement
      books to the Ribbons. A later choice recreates a fresh custom book. }
    FreeAndNil(FCustomBook);
    if FFormChoice.ItemIndex = CustomIndex then FFormChoice.ItemIndex := 0;
    if FAChoice.ItemIndex = CustomIndex then FAChoice.ItemIndex := 0;
    if FBChoice.ItemIndex = CustomIndex then FBChoice.ItemIndex := 0;
    FRibbonA.RefreshTheme;
    FRibbonB.RefreshTheme;
    UpdateStatus;
  finally
    FUpdating := False;
  end;
end;

procedure TRibbonThemeDemoForm.ToggleEnabled(Sender: TObject);
begin
  FRibbonA.Enabled := not FRibbonA.Enabled;
  UpdateStatus;
end;

procedure TRibbonThemeDemoForm.ModelClick(Sender: TObject);
begin
  if (FLog <> nil) and (Sender is TRibbonNode) then
    FLog.Lines.Add('Komut: ' + TRibbonNode(Sender).Caption);
end;

procedure TRibbonThemeDemoForm.ValueChanged(Sender: TObject);
begin
  if (FLog <> nil) and (Sender is TRibbonNode) then
    FLog.Lines.Add('Değer değişti: ' + TRibbonNode(Sender).Caption);
end;

procedure TRibbonThemeDemoForm.Diagnostic(Sender: TObject; const AMessage: string);
begin
  if FLog <> nil then FLog.Lines.Add(AMessage);
end;

procedure TRibbonThemeDemoForm.UpdateStatus;
begin
  FStatus.Text := Format('Form kitabı: %s' + sLineBreak +
    'Üst: yerel=%s, etkin=%s, Enabled=%s | Alt: yerel=%s, etkin=%s' + sLineBreak +
    'Ribbon kaynağı bulunmazsa Theme fallback kullanılır; native edit/combo için tam FMX stil ağacı korunur.',
    [BookName(StyleBook), BookName(FRibbonA.StyleBook),
     BookName(FRibbonA.EffectiveStyleBook), BoolToStr(FRibbonA.Enabled, True),
     BookName(FRibbonB.StyleBook), BookName(FRibbonB.EffectiveStyleBook)]);
end;

end.
