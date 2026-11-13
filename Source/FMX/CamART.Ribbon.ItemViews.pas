unit CamART.Ribbon.ItemViews;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.ListBox,
  FMX.Colors,
  FMX.Objects,
  CamART.Ribbon.Types,
  CamART.Ribbon.ViewData,
  CamART.Ribbon.Views,
  CamART.Ribbon.Icons,
  CamART.Ribbon.Interaction,
  CamART.Ribbon.StyledControls;

type
  ERibbonItemViewError = class(Exception);

  { One adapter owns one native FMX control. Model mutation and command policy
    stay in the root. Apply suppresses native change events, including those
    generated while assigning Items, ItemIndex, Color or IsChecked. }
  TRibbonItemView = class(TComponent)
  private
    FControl: TControl;
    FItemId, FTypeKey: string;
    FIconProvider: IRibbonIconProvider;
    FOnInput: TRibbonItemInputEvent;
    FMeasureFont: TFont;
    FPresentationStyle: TRibbonButtonStyle;
    FInputDensity: TRibbonInputDensity;
    FInputGuard: TRibbonInputGuard;
    procedure NativePanFinished(Sender: TObject);
    procedure SetInputDensity(const AValue: TRibbonInputDensity);
    procedure SetIconProvider(const AValue: IRibbonIconProvider);
  protected
    FData: TRibbonItemViewData;
    FUpdating: Integer;
    FTextMeasure: TRibbonTextMeasure;
    procedure SetControl(AControl: TControl);
    procedure DoApply; virtual;
    procedure ApplyPresentationStyle; virtual;
    procedure DensityChanged; virtual;
    function MeasurementFont: TFont; virtual;
    procedure Emit(const AInput: TRibbonItemInput);
    function Input(AKind: TRibbonItemInputKind): TRibbonItemInput;
    function InputAllowed: Boolean;
    function AcceptValueInput: Boolean;
    procedure RestoreValue;
    function MeasureStyledText(AControl: TStyledControl;
      const AText: string): TSizeF;
    procedure MouseEntered(Sender: TObject);
    procedure MouseLeft(Sender: TObject);
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Apply(const AData: TRibbonItemViewData);
    function DesiredSize: TSizeF; virtual;
    function DesiredSizeForStyle(AStyle: TRibbonButtonStyle): TSizeF; virtual;
    function CanCompact: Boolean; virtual;
    function IsInteractive: Boolean; virtual;
    function MeasurementKey: string; virtual;
    function ContainsFocus: Boolean;
    procedure SetPresentationStyle(AStyle: TRibbonButtonStyle);
    function CommandButton: TRibbonCommandButton; virtual;
    property Control: TControl read FControl;
    property ItemId: string read FItemId;
    property TypeKey: string read FTypeKey;
    property PresentationStyle: TRibbonButtonStyle read FPresentationStyle;
    property InputDensity: TRibbonInputDensity read FInputDensity write SetInputDensity;
    property IconProvider: IRibbonIconProvider read FIconProvider
      write SetIconProvider;
    property OnInput: TRibbonItemInputEvent read FOnInput write FOnInput;
  end;

  TRibbonItemViewClass = class of TRibbonItemView;

  TRibbonButtonItemView = class(TRibbonItemView)
  private
    FButton: TRibbonCommandButton;
    procedure MainClick(Sender: TObject);
    procedure DropDownClick(Sender: TObject);
  protected
    procedure DoApply; override;
    procedure ApplyPresentationStyle; override;
    procedure DensityChanged; override;
    function MeasurementFont: TFont; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
    function DesiredSizeForStyle(AStyle: TRibbonButtonStyle): TSizeF; override;
    function CanCompact: Boolean; override;
    function CommandButton: TRibbonCommandButton; override;
  end;

  TRibbonSeparatorItemView = class(TRibbonItemView)
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  TRibbonLabelItemView = class(TRibbonItemView)
  private
    FLabel: TLabel;
  protected
    procedure DoApply; override;
    function MeasurementFont: TFont; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  TRibbonEditItemView = class(TRibbonItemView)
  private
    FEdit: TEdit;
    procedure TextChanged(Sender: TObject);
  protected
    procedure DoApply; override;
    function MeasurementFont: TFont; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  { Combo, fontpicker and fontsizepicker share native selection mechanics.
    Font discovery belongs to the configured provider, never this view. }
  TRibbonComboItemView = class(TRibbonItemView)
  private
    FCombo: TComboBox;
    procedure SelectionChanged(Sender: TObject);
  protected
    procedure DoApply; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  TRibbonColorItemView = class(TRibbonItemView)
  private
    FColor: TColorComboBox;
    procedure ColorChanged(Sender: TObject);
  protected
    procedure DoApply; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  TRibbonCheckItemView = class(TRibbonItemView)
  private
    FCheck: TCheckBox;
    procedure CheckedChanged(Sender: TObject);
  protected
    procedure DoApply; override;
    function MeasurementFont: TFont; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  TRibbonRadioItemView = class(TRibbonItemView)
  private
    FRadio: TRadioButton;
    procedure CheckedChanged(Sender: TObject);
  protected
    procedure DoApply; override;
    function MeasurementFont: TFont; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  TRibbonProgressItemView = class(TRibbonItemView)
  private
    FProgress: TProgressBar;
  protected
    procedure DoApply; override;
  public
    constructor Create(AOwner: TComponent); override;
    function DesiredSize: TSizeF; override;
  end;

  TRibbonGalleryCell = class(TRibbonStyledListBoxItem)
  private
    FIcon: TRibbonIconBinding;
    FIconKey: string;
    FStyleText: TText;
    FArranging: Boolean;
    FNativeDisabledOpacity: Single;
    FStyleReady: Boolean;
    procedure IconChanged(Sender: TObject);
    procedure ArrangeContent;
  protected
    function GetDefaultStyleLookupName: string; override;
    procedure ApplyStyle; override;
    procedure FreeStyle; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; override;
    procedure RecalcEnabled; override;
    procedure Configure(const AEntry: TRibbonGalleryEntryViewData;
      const AProvider: IRibbonIconProvider);
  end;

  TRibbonGalleryReleaseEvent = procedure(Sender: TObject; ACommit: Boolean) of object;

  { Native selection during a pointer gesture is a preview. Only one eligible
    release after the inherited native stack commits the selected identity. }
  TRibbonGalleryListBox = class(TRibbonStyledListBox)
  private
    FLifetime: IRibbonInputLifetime;
    FReleasing: Boolean;
    FOnPointerBeginning: TNotifyEvent;
    FOnPointerReleased: TRibbonGalleryReleaseEvent;
    function GetPreviewActive: Boolean;
  protected
    function GetDefaultStyleLookupName: string; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    property PreviewActive: Boolean read GetPreviewActive;
    property OnPointerBeginning: TNotifyEvent read FOnPointerBeginning
      write FOnPointerBeginning;
    property OnPointerReleased: TRibbonGalleryReleaseEvent read FOnPointerReleased
      write FOnPointerReleased;
  end;

  TRibbonGalleryItemView = class(TRibbonItemView)
  private
    FList: TRibbonGalleryListBox;
    FCells: TList<TRibbonGalleryCell>;
    FEntries: TArray<TRibbonGalleryEntryViewData>;
    procedure SelectionChanged(Sender: TObject);
    procedure PointerReleased(Sender: TObject; ACommit: Boolean);
    procedure PointerBeginning(Sender: TObject);
    procedure RestoreSelection;
    procedure SyncEntries;
  protected
    procedure DoApply; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DesiredSize: TSizeF; override;
    function MeasurementKey: string; override;
  end;

implementation

uses
  System.Math,
  CamART.Ribbon.Themes,
  CamART.Ribbon.ThemeStyles,
  CamART.Ribbon.StyleScope,
  CamART.Ribbon.StyleContext;

type
  TRibbonSeparatorControl = class(TStyledControl, IRibbonStyleSource)
  private
    FDefaultTemplate: TFmxObject;
  protected
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    destructor Destroy; override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  { ParentShowHint is protected on the FMX base TControl. }
  TRibbonHintControlAccess = class(TControl)
  public
    property ParentShowHint;
  end;

function IncludeControlPadding(AControl: TControl; const ASize: TSizeF): TSizeF;
var
  Insets: TRectF;
begin
  Insets := RibbonControlPadding(AControl);
  Result := ASize;
  Result.Width := Result.Width + Insets.Left + Insets.Right;
  Result.Height := Result.Height + Insets.Top + Insets.Bottom;
end;

destructor TRibbonSeparatorControl.Destroy;
begin
  FDefaultTemplate.Free;
  inherited;
end;

function TRibbonSeparatorControl.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Exit(Context.ResolveRibbonStyle(Self, rsrSeparator, AClone));
  Result := TStyledControl.LookupStyleObject(Self, Self, Scene, StyleLookup,
    RibbonThemeStyleName(rsrSeparator), ParentClassStyleLookupName, AClone, True);
  if Result <> nil then Exit;
  if FDefaultTemplate = nil then
    FDefaultTemplate := CreateRibbonThemeStyle(rsrSeparator, rtOffice2010Blue);
  if AClone then Result := FDefaultTemplate.Clone(nil)
  else Result := FDefaultTemplate;
end;

function TRibbonSeparatorControl.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonSeparatorControl.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

constructor TRibbonGalleryListBox.Create(AOwner: TComponent);
begin
  inherited;
  FLifetime := EnsureRibbonInput(Self, ridPointer).Lifetime;
end;

function TRibbonGalleryListBox.GetDefaultStyleLookupName: string;
begin
  Result := 'listboxstyle';
end;

function TRibbonGalleryListBox.GetPreviewActive: Boolean;
begin
  Result := FReleasing or RibbonPointerIsDown(Self);
end;

procedure TRibbonGalleryListBox.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  Token: IRibbonInputLifetime;
  Handler: TNotifyEvent;
begin
  Token := FLifetime;
  Handler := FOnPointerBeginning;
  { A new session supersedes any queued pan restoration. Restore the last
    canonical selection before allowing native pointer preview to begin. }
  if (Button = TMouseButton.mbLeft) and Assigned(Handler) then Handler(Self);
  if not Token.IsAlive then Exit;
  RibbonBeginPointer(Self, Button, X, Y);
  if not Token.IsAlive then Exit;
  inherited;
end;

procedure TRibbonGalleryListBox.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  Token: IRibbonInputLifetime;
  Session: UInt64;
  WasPointer, Commit: Boolean;
  Target: TListBoxItem;
  Handler: TRibbonGalleryReleaseEvent;
begin
  Token := FLifetime;
  Session := Token.GetSession;
  WasPointer := (Button = TMouseButton.mbLeft) and RibbonPointerIsDown(Self);
  FReleasing := True;
  try
    if Button = TMouseButton.mbLeft then RibbonEndPointer(Self, X, Y);
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
    inherited;
  finally
    if Token.IsAlive then FReleasing := False;
  end;
  if not Token.IsAlive or (Token.GetSession <> Session) or not WasPointer then Exit;
  Target := nil;
  if (X >= 0) and (Y >= 0) and (X < Width) and (Y < Height) then
    Target := ItemByPoint(X, Y);
  Commit := RibbonActivationAllowed(Self) and
    (Target <> nil) and (Target = Selected) and Target.Enabled and Target.Visible;
  Handler := FOnPointerReleased;
  if Assigned(Handler) then Handler(Self, Commit);
  { No native/list/adapter access after the semantic release callback. }
end;

procedure TRibbonGalleryListBox.KeyDown(var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  RibbonKeyboardInput(Self);
  inherited;
end;

constructor TRibbonItemView.Create(AOwner: TComponent);
begin
  inherited;
  FTextMeasure := TRibbonTextMeasure.Create;
  FMeasureFont := TFont.Create;
end;

destructor TRibbonItemView.Destroy;
begin
  Inc(FUpdating);
  FOnInput := nil;
  if FInputGuard <> nil then
  begin
    FInputGuard.OnPanFinished := nil;
    FInputGuard.RemoveFreeNotification(Self);
    FInputGuard := nil;
  end;
  FControl := nil;
  FIconProvider := nil;
  FTextMeasure.Free;
  FMeasureFont.Free;
  inherited;
end;

procedure TRibbonItemView.SetControl(AControl: TControl);
begin
  if AControl = nil then
    raise EArgumentNilException.Create('A Ribbon item view requires a control.');
  if FControl <> nil then
    raise ERibbonItemViewError.Create('The item control is already initialized.');
  FControl := AControl;
  FControl.Stored := False;
  TComponent(FControl).FreeNotification(Self);
  FControl.OnMouseEnter := MouseEntered;
  FControl.OnMouseLeave := MouseLeft;
  if (FControl is TButton) or (FControl is TCheckBox) or
     (FControl is TRadioButton) or (FControl is TRibbonGalleryListBox) then
  begin
    FInputGuard := EnsureRibbonInput(FControl, FInputDensity);
    FInputGuard.FreeNotification(Self);
    FInputGuard.OnPanFinished := NativePanFinished;
  end;
end;

procedure TRibbonItemView.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if Operation = opRemove then
  begin
    if AComponent = FControl then FControl := nil;
    if AComponent = FInputGuard then FInputGuard := nil;
  end;
  inherited;
end;

procedure TRibbonItemView.SetIconProvider(const AValue: IRibbonIconProvider);
begin
  if FIconProvider = AValue then Exit;
  FIconProvider := AValue;
  if (FControl <> nil) and (FItemId <> '') then Apply(FData);
end;

procedure TRibbonItemView.Apply(const AData: TRibbonItemViewData);
begin
  if FControl = nil then
    raise ERibbonItemViewError.Create('The native Ribbon item control was destroyed.');
  if (AData.Id = '') or (AData.TypeKey = '') then
    raise EArgumentException.Create('An item view needs an Id and TypeKey.');
  Inc(FUpdating);
  try
    if (FItemId = '') or (FData.ButtonStyle <> AData.ButtonStyle) then
      FPresentationStyle := AData.ButtonStyle;
    FItemId := AData.Id;
    FTypeKey := AData.TypeKey;
    FData := AData;
    FData.Choices := Copy(AData.Choices);
    FData.GalleryEntries := Copy(AData.GalleryEntries);
    FControl.Enabled := AData.Enabled;
    FControl.Visible := AData.Visible;
    FControl.Hint := AData.Hint;
    TRibbonHintControlAccess(FControl).ParentShowHint := False;
    FControl.ShowHint := FControl.Hint <> '';
    DoApply;
  finally
    Dec(FUpdating);
  end;
end;

procedure TRibbonItemView.DoApply;
begin
end;

procedure TRibbonItemView.SetInputDensity(const AValue: TRibbonInputDensity);
begin
  if (Ord(AValue) < Ord(Low(TRibbonInputDensity))) or
     (Ord(AValue) > Ord(High(TRibbonInputDensity))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon input density.');
  if FInputDensity = AValue then Exit;
  FInputDensity := AValue;
  DensityChanged;
end;

procedure TRibbonItemView.DensityChanged;
begin
  if FInputGuard <> nil then FInputGuard.Density := FInputDensity;
end;

procedure TRibbonItemView.NativePanFinished(Sender: TObject);
begin
  RestoreValue;
end;

procedure TRibbonItemView.ApplyPresentationStyle;
begin
end;

procedure TRibbonItemView.SetPresentationStyle(AStyle: TRibbonButtonStyle);
begin
  if FPresentationStyle = AStyle then Exit;
  FPresentationStyle := AStyle;
  Inc(FUpdating);
  try
    ApplyPresentationStyle;
  finally
    Dec(FUpdating);
  end;
end;

function TRibbonItemView.MeasurementFont: TFont;
var
  Part: TFmxObject;
begin
  Result := FMeasureFont;
  if not (FControl is TStyledControl) then Exit;
  TStyledControl(FControl).ApplyStyleLookup;
  Part := TStyledControl(FControl).FindStyleResource('text');
  if not (Part is TText) then
    Part := TStyledControl(FControl).FindStyleResource('content');
  if Part is TText then Result := TText(Part).TextSettings.Font;
end;

function TRibbonItemView.MeasurementKey: string;
begin
  Result := RibbonControlMeasureKey(FControl) + ':' +
    RibbonFontMeasureKey(MeasurementFont);
end;

function TRibbonItemView.ContainsFocus: Boolean;
  function FocusedWithin(AObject: TFmxObject): Boolean;
  var
    Child: TFmxObject;
  begin
    Result := False;
    if (AObject is TControl) and TControl(AObject).IsFocused then Exit(True);
    if AObject.Children = nil then Exit;
    for Child in AObject.Children do
      if FocusedWithin(Child) then Exit(True);
  end;
begin
  Result := (FControl <> nil) and FControl.Visible and
    FControl.ParentedVisible and FocusedWithin(FControl);
end;

function TRibbonItemView.IsInteractive: Boolean;
begin
  Result := (FControl <> nil) and FControl.HitTest and FControl.CanFocus;
end;

function TRibbonItemView.CanCompact: Boolean;
begin
  Result := False;
end;

function TRibbonItemView.DesiredSizeForStyle(AStyle: TRibbonButtonStyle): TSizeF;
begin
  Result := DesiredSize;
end;

function TRibbonItemView.InputAllowed: Boolean;
begin
  Result := False;
  if FUpdating <> 0 then Exit;
  if FControl = nil then Exit;
  Result := FControl.AbsoluteEnabled and FControl.Visible and
    FControl.ParentedVisible and RibbonActivationAllowed(FControl);
end;

procedure TRibbonItemView.RestoreValue;
begin
  if FControl = nil then Exit;
  Inc(FUpdating);
  try
    DoApply;
  finally
    Dec(FUpdating);
  end;
end;

function TRibbonItemView.AcceptValueInput: Boolean;
begin
  Result := False;
  { An Apply-generated notification must never undo the snapshot in progress.
    A separate, ineligible native transition must return to the last snapshot. }
  if (FUpdating <> 0) or (FControl = nil) then Exit;
  Result := InputAllowed;
  if not Result then RestoreValue;
end;

function TRibbonItemView.Input(AKind: TRibbonItemInputKind): TRibbonItemInput;
begin
  Result := Default(TRibbonItemInput);
  Result.Kind := AKind;
  Result.Id := FItemId;
  Result.Index := -1;
end;

procedure TRibbonItemView.Emit(const AInput: TRibbonItemInput);
var
  Handler: TRibbonItemInputEvent;
  EventData: TRibbonItemInput;
begin
  if not InputAllowed then Exit;
  EventData := AInput;
  EventData.Id := FItemId;
  Handler := FOnInput;
  if Assigned(Handler) then Handler(Self, EventData);
  { A handler may destroy this adapter or its Ribbon. No member access follows. }
end;

procedure TRibbonItemView.MouseEntered(Sender: TObject);
begin
  Emit(Input(rikMouseEnter));
end;

procedure TRibbonItemView.MouseLeft(Sender: TObject);
begin
  Emit(Input(rikMouseLeave));
end;

function TRibbonItemView.MeasureStyledText(AControl: TStyledControl;
  const AText: string): TSizeF;
var
  Part: TFmxObject;
begin
  AControl.ApplyStyleLookup;
  Part := AControl.FindStyleResource('text');
  if not (Part is TText) then Part := AControl.FindStyleResource('content');
  if Part is TText then
    Result := FTextMeasure.Measure(AText, TText(Part).TextSettings.Font)
  else
    Result := FTextMeasure.Measure(AText, FMeasureFont);
end;

function TRibbonItemView.DesiredSize: TSizeF;
begin
  Result := TSizeF.Create(120, 28);
end;

function TRibbonItemView.CommandButton: TRibbonCommandButton;
begin
  Result := nil;
end;

constructor TRibbonButtonItemView.Create(AOwner: TComponent);
begin
  inherited;
  FButton := TRibbonCommandButton.Create(Self);
  SetControl(FButton);
  FButton.OnClick := MainClick;
  FButton.OnDropDown := DropDownClick;
end;

procedure TRibbonButtonItemView.DoApply;
begin
  FButton.ItemId := ItemId;
  if FButton.Text <> FData.Caption then FButton.Text := FData.Caption;
  FButton.Configure(PresentationStyle, FData.ButtonKind, FData.IconKey,
    IconProvider, FData.Checked);
end;

procedure TRibbonButtonItemView.ApplyPresentationStyle;
begin
  FButton.Configure(PresentationStyle, FData.ButtonKind, FData.IconKey,
    IconProvider, FData.Checked);
end;

procedure TRibbonButtonItemView.DensityChanged;
begin
  inherited;
  AttachRibbonInput(FButton.ArrowButton, InputDensity);
  if InputDensity = ridTouch then FButton.MinimumTargetSize := 44
  else FButton.MinimumTargetSize := 28;
end;

function TRibbonButtonItemView.MeasurementFont: TFont;
begin
  FButton.ApplyStyleLookup;
  Result := FButton.ResultingTextSettings.Font;
end;

procedure TRibbonButtonItemView.MainClick(Sender: TObject);
var
  EventData: TRibbonItemInput;
begin
  if not AcceptValueInput then Exit;
  { Native StaysPressed is a visual aid only. The root/command owns state. }
  FButton.IsPressed := FData.Checked;
  if FData.ButtonKind in [rbkDropDown, rbkGallery] then
    EventData := Input(rikDropDown)
  else
    EventData := Input(rikExecute);
  Emit(EventData);
end;

procedure TRibbonButtonItemView.DropDownClick(Sender: TObject);
begin
  Emit(Input(rikDropDown));
end;

function TRibbonButtonItemView.DesiredSize: TSizeF;
begin
  Result := FButton.DesiredSize(FData.ButtonStyle);
end;

function TRibbonButtonItemView.DesiredSizeForStyle(AStyle: TRibbonButtonStyle): TSizeF;
begin
  Result := FButton.DesiredSize(AStyle);
end;

function TRibbonButtonItemView.CanCompact: Boolean;
begin
  Result := FData.ButtonStyle = rbsLarge;
end;

function TRibbonButtonItemView.CommandButton: TRibbonCommandButton;
begin
  Result := nil;
  if Control <> nil then Result := FButton;
end;

constructor TRibbonSeparatorItemView.Create(AOwner: TComponent);
var
  Separator: TRibbonSeparatorControl;
begin
  inherited;
  Separator := TRibbonSeparatorControl.Create(Self);
  Separator.HitTest := False;
  Separator.CanFocus := False;
  SetControl(Separator);
end;

function TRibbonSeparatorItemView.DesiredSize: TSizeF;
begin
  TStyledControl(Control).ApplyStyleLookup;
  if FData.ButtonStyle = rbsLarge then
    Result := TSizeF.Create(1, 72)
  else
    Result := TSizeF.Create(1, 24);
  Result := IncludeControlPadding(Control, Result);
end;

constructor TRibbonLabelItemView.Create(AOwner: TComponent);
begin
  inherited;
  FLabel := TRibbonStyledLabel.Create(Self);
  FLabel.CanFocus := False;
  FLabel.HitTest := False;
  SetControl(FLabel);
end;

procedure TRibbonLabelItemView.DoApply;
begin
  if FLabel.Text <> FData.Caption then FLabel.Text := FData.Caption;
end;

function TRibbonLabelItemView.MeasurementFont: TFont;
begin
  FLabel.ApplyStyleLookup;
  Result := FLabel.ResultingTextSettings.Font;
end;

function TRibbonLabelItemView.DesiredSize: TSizeF;
var
  Size: TSizeF;
begin
  FLabel.ApplyStyleLookup;
  Size := FTextMeasure.Measure(FLabel.Text, FLabel.ResultingTextSettings.Font);
  Result := IncludeControlPadding(FLabel,
    TSizeF.Create(Max(20, Size.Width + 8), Max(24, Size.Height + 6)));
end;

constructor TRibbonEditItemView.Create(AOwner: TComponent);
begin
  inherited;
  FEdit := TRibbonStyledEdit.Create(Self);
  SetControl(FEdit);
  FEdit.OnChangeTracking := TextChanged;
end;

procedure TRibbonEditItemView.DoApply;
begin
  FEdit.TextPrompt := FData.Caption;
  { Do not reset caret, selection or an active IME composition on unrelated
    command/state refreshes. Native text is assigned only when it differs. }
  if FEdit.Text <> FData.Text then FEdit.Text := FData.Text;
end;

procedure TRibbonEditItemView.TextChanged(Sender: TObject);
var
  EventData: TRibbonItemInput;
begin
  if not AcceptValueInput then Exit;
  EventData := Input(rikText);
  EventData.Text := FEdit.Text;
  Emit(EventData);
end;

function TRibbonEditItemView.MeasurementFont: TFont;
begin
  FEdit.ApplyStyleLookup;
  Result := FEdit.ResultingTextSettings.Font;
end;

function TRibbonEditItemView.DesiredSize: TSizeF;
var
  Size, TextSize: TSizeF;
begin
  FEdit.ApplyStyleLookup;
  Size := FTextMeasure.Measure(FData.Caption, FEdit.ResultingTextSettings.Font);
  TextSize := FTextMeasure.Measure(FData.Text, FEdit.ResultingTextSettings.Font);
  Size.Width := Max(Size.Width, TextSize.Width);
  Size.Height := Max(Size.Height, TextSize.Height);
  Result := IncludeControlPadding(FEdit,
    TSizeF.Create(Max(140, Size.Width + 24), Max(30, Size.Height + 12)));
end;

constructor TRibbonComboItemView.Create(AOwner: TComponent);
begin
  inherited;
  FCombo := TRibbonStyledComboBox.Create(Self);
  SetControl(FCombo);
  FCombo.OnChange := SelectionChanged;
end;

procedure TRibbonComboItemView.DoApply;
var
  Same: Boolean;
  I, Index: Integer;
begin
  Same := FCombo.Items.Count = Length(FData.Choices);
  if Same then
    for I := 0 to High(FData.Choices) do
      if FCombo.Items[I] <> FData.Choices[I] then
      begin
        Same := False;
        Break;
      end;
  if not Same then
  begin
    FCombo.Items.BeginUpdate;
    try
      FCombo.Items.Clear;
      for I := 0 to High(FData.Choices) do FCombo.Items.Add(FData.Choices[I]);
    finally
      FCombo.Items.EndUpdate;
    end;
  end;
  Index := FData.ItemIndex;
  if (Index < -1) or (Index >= FCombo.Items.Count) then Index := -1;
  if FCombo.ItemIndex <> Index then FCombo.ItemIndex := Index;
end;

procedure TRibbonComboItemView.SelectionChanged(Sender: TObject);
var
  EventData: TRibbonItemInput;
begin
  if not AcceptValueInput then Exit;
  EventData := Input(rikIndex);
  EventData.Index := FCombo.ItemIndex;
  if (EventData.Index >= 0) and (EventData.Index < FCombo.Items.Count) then
    EventData.Text := FCombo.Items[EventData.Index];
  Emit(EventData);
end;

function TRibbonComboItemView.DesiredSize: TSizeF;
var
  Size, Candidate: TSizeF;
  S: string;
begin
  Size := MeasureStyledText(FCombo, FData.Caption);
  for S in FData.Choices do
  begin
    Candidate := MeasureStyledText(FCombo, S);
    Size.Width := Max(Size.Width, Candidate.Width);
    Size.Height := Max(Size.Height, Candidate.Height);
  end;
  Result := IncludeControlPadding(FCombo,
    TSizeF.Create(Max(100, Size.Width + 34), Max(30, Size.Height + 12)));
end;

constructor TRibbonColorItemView.Create(AOwner: TComponent);
begin
  inherited;
  FColor := TRibbonStyledColorComboBox.Create(Self);
  SetControl(FColor);
  FColor.OnChange := ColorChanged;
end;

procedure TRibbonColorItemView.DoApply;
begin
  if FColor.Color <> FData.Color then FColor.Color := FData.Color;
end;

procedure TRibbonColorItemView.ColorChanged(Sender: TObject);
var
  EventData: TRibbonItemInput;
begin
  if not AcceptValueInput then Exit;
  EventData := Input(rikColor);
  EventData.Color := FColor.Color;
  Emit(EventData);
end;

function TRibbonColorItemView.DesiredSize: TSizeF;
var
  Size: TSizeF;
begin
  Size := MeasureStyledText(FColor, FData.Caption);
  Result := IncludeControlPadding(FColor,
    TSizeF.Create(Max(120, Size.Width + 36), Max(30, Size.Height + 12)));
end;

constructor TRibbonCheckItemView.Create(AOwner: TComponent);
begin
  inherited;
  FCheck := TRibbonInputCheckBox.Create(Self);
  SetControl(FCheck);
  FCheck.OnChange := CheckedChanged;
end;

procedure TRibbonCheckItemView.DoApply;
begin
  if FCheck.Text <> FData.Caption then FCheck.Text := FData.Caption;
  if FCheck.IsChecked <> FData.Checked then FCheck.IsChecked := FData.Checked;
end;

procedure TRibbonCheckItemView.CheckedChanged(Sender: TObject);
var
  EventData: TRibbonItemInput;
begin
  if not AcceptValueInput then Exit;
  EventData := Input(rikCheck);
  EventData.Checked := FCheck.IsChecked;
  Inc(FUpdating);
  try
    FCheck.IsChecked := FData.Checked;
  finally
    Dec(FUpdating);
  end;
  Emit(EventData);
end;

function TRibbonCheckItemView.MeasurementFont: TFont;
begin
  FCheck.ApplyStyleLookup;
  Result := FCheck.ResultingTextSettings.Font;
end;

function TRibbonCheckItemView.DesiredSize: TSizeF;
var
  Size: TSizeF;
  Indicator: Single;
begin
  FCheck.ApplyStyleLookup;
  Indicator := RibbonThemeStyleMetric(FCheck, RibbonThemeSmallIconPart, 18) + 12;
  Size := FTextMeasure.Measure(FCheck.Text, FCheck.ResultingTextSettings.Font);
  Result := IncludeControlPadding(FCheck,
    TSizeF.Create(Max(40, Size.Width + Indicator),
      Max(Max(28, Indicator), Size.Height + 10)));
end;

constructor TRibbonRadioItemView.Create(AOwner: TComponent);
begin
  inherited;
  FRadio := TRibbonInputRadioButton.Create(Self);
  FRadio.GroupName := 'CamARTRibbonView_' +
    IntToHex(NativeUInt(Self), SizeOf(Pointer) * 2);
  SetControl(FRadio);
  FRadio.OnChange := CheckedChanged;
end;

procedure TRibbonRadioItemView.DoApply;
begin
  { Source-model groups can have several presentations (Ribbon/QAT/popups).
    Native peers must not mutate each other's business state. The root applies
    the selected source state to all presentations after one selection input. }
  if FRadio.Text <> FData.Caption then FRadio.Text := FData.Caption;
  if FRadio.IsChecked <> FData.Checked then FRadio.IsChecked := FData.Checked;
end;

procedure TRibbonRadioItemView.CheckedChanged(Sender: TObject);
var
  EventData: TRibbonItemInput;
begin
  if not AcceptValueInput then Exit;
  if not FRadio.IsChecked then
  begin
    { Native grouping or a direct native assignment cannot clear the selected
      model radio. Selecting another model peer is the canonical transition. }
    RestoreValue;
    Exit;
  end;
  EventData := Input(rikCheck);
  EventData.Checked := True;
  Inc(FUpdating);
  try
    FRadio.IsChecked := FData.Checked;
  finally
    Dec(FUpdating);
  end;
  Emit(EventData);
end;

function TRibbonRadioItemView.MeasurementFont: TFont;
begin
  FRadio.ApplyStyleLookup;
  Result := FRadio.ResultingTextSettings.Font;
end;

function TRibbonRadioItemView.DesiredSize: TSizeF;
var
  Size: TSizeF;
  Indicator: Single;
begin
  FRadio.ApplyStyleLookup;
  Indicator := RibbonThemeStyleMetric(FRadio, RibbonThemeSmallIconPart, 18) + 12;
  Size := FTextMeasure.Measure(FRadio.Text, FRadio.ResultingTextSettings.Font);
  Result := IncludeControlPadding(FRadio,
    TSizeF.Create(Max(40, Size.Width + Indicator),
      Max(Max(28, Indicator), Size.Height + 10)));
end;

constructor TRibbonProgressItemView.Create(AOwner: TComponent);
begin
  inherited;
  FProgress := TRibbonStyledProgressBar.Create(Self);
  FProgress.CanFocus := False;
  SetControl(FProgress);
end;

procedure TRibbonProgressItemView.DoApply;
begin
  { Widen the current range before installing the new endpoints, avoiding a
    temporary inverted range when both endpoints move past the old range. }
  FProgress.Min := Min(FProgress.Min, FData.Minimum);
  FProgress.Max := Max(FProgress.Max, FData.Maximum);
  FProgress.Min := FData.Minimum;
  FProgress.Max := FData.Maximum;
  FProgress.Value := FData.Value;
end;

function TRibbonProgressItemView.DesiredSize: TSizeF;
begin
  FProgress.ApplyStyleLookup;
  Result := IncludeControlPadding(FProgress, TSizeF.Create(140, 22));
end;

constructor TRibbonGalleryCell.Create(AOwner: TComponent);
begin
  inherited;
  FNativeDisabledOpacity := DisabledOpacity;
  Stored := False;
  FIcon := TRibbonIconBinding.Create(Self, Self, nil);
  FIcon.OnChanged := IconChanged;
  FStyleReady := True;
end;

destructor TRibbonGalleryCell.Destroy;
begin
  FArranging := True;
  if FIcon <> nil then FIcon.OnChanged := nil;
  FIcon := nil;
  FStyleText := nil;
  inherited;
end;

function TRibbonGalleryCell.GetDefaultStyleLookupName: string;
begin
  Result := 'listboxitemstyle';
end;

function TRibbonGalleryCell.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Result := Context.ResolveRibbonStyle(Self, rsrGalleryItem, AClone)
  else
    Result := inherited GetRibbonStyle(AClone);
end;

procedure TRibbonGalleryCell.RecalcEnabled;
var
  Watch: TRibbonStyleWatch;
begin
  if not FStyleReady or (csDestroying in ComponentState) then
  begin
    inherited;
    Exit;
  end;
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control <> nil then ApplyRibbonThemeEnabled(Self, AbsoluteEnabled);
  finally
    Watch.Free;
  end;
end;

procedure TRibbonGalleryCell.ApplyStyle;
var
  Part: TFmxObject;
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control = nil then Exit;
    FStyleText := nil;
    Part := FindStyleResource('text');
    if Part is TText then FStyleText := TText(Part);
    if FStyleReady then
    begin
      if FindStyleResource(RibbonThemeMarkerPart) <> nil then DisabledOpacity := 1
      else DisabledOpacity := FNativeDisabledOpacity;
      ApplyRibbonThemeEnabled(Self, AbsoluteEnabled);
    end;
    ArrangeContent;
  finally
    Watch.Free;
  end;
end;

procedure TRibbonGalleryCell.FreeStyle;
begin
  FStyleText := nil;
  inherited;
end;

procedure TRibbonGalleryCell.Resize;
begin
  inherited;
  ArrangeContent;
end;

procedure TRibbonGalleryCell.IconChanged(Sender: TObject);
begin
  ArrangeContent;
end;

procedure TRibbonGalleryCell.Configure(const AEntry: TRibbonGalleryEntryViewData;
  const AProvider: IRibbonIconProvider);
begin
  TagString := AEntry.Id;
  if Text <> AEntry.Caption then Text := AEntry.Caption;
  Enabled := AEntry.Enabled;
  Visible := AEntry.Visible;
  FIcon.Provider := AProvider;
  FIconKey := AEntry.IconKey;
  ApplyStyleLookup;
  ArrangeContent;
end;

procedure TRibbonGalleryCell.ArrangeContent;
var
  HasImage: Boolean;
  R, Insets: TRectF;
  Side: Single;
begin
  if FArranging or (FIcon = nil) then Exit;
  FArranging := True;
  try
    Side := RibbonThemeStyleMetric(Self, RibbonThemeLargeIconPart, 32);
    HasImage := FIcon.SetIcon(FIconKey, Side, RibbonControlScale(Self));
    HasImage := HasImage and (FStyleText <> nil);
    FIcon.Visible := HasImage;
    Insets := RibbonControlPadding(Self);
    R := RectF(Insets.Left + 6, Insets.Top + 4,
      Max(Insets.Left + 6, Width - Insets.Right - 6),
      Max(Insets.Top + 4, Height - Insets.Bottom - 4));
    if HasImage then
    begin
      FIcon.SetBounds(R.Left + Max(0, (R.Width - Side) / 2), R.Top, Side, Side);
      R.Top := Min(R.Bottom, R.Top + Side + 6);
    end;
    if FStyleText <> nil then PlaceRibbonStylePart(Self, FStyleText, R);
  finally
    FArranging := False;
  end;
end;

constructor TRibbonGalleryItemView.Create(AOwner: TComponent);
begin
  inherited;
  FCells := TList<TRibbonGalleryCell>.Create;
  FList := TRibbonGalleryListBox.Create(Self);
  FList.AutoCapture := True;
  FList.Columns := 3;
  FList.ItemHeight := 68;
  SetControl(FList);
  FList.OnChange := SelectionChanged;
  FList.OnPointerReleased := PointerReleased;
  FList.OnPointerBeginning := PointerBeginning;
end;

destructor TRibbonGalleryItemView.Destroy;
begin
  Inc(FUpdating);
  if Control <> nil then
  begin
    FList.OnPointerReleased := nil;
    FList.OnPointerBeginning := nil;
  end;
  FCells.Free;
  inherited;
end;

procedure TRibbonGalleryItemView.SyncEntries;
var
  VisibleEntries: TList<TRibbonGalleryEntryViewData>;
  Next: TArray<TRibbonGalleryEntryViewData>;
  Entry: TRibbonGalleryEntryViewData;
  Cell: TRibbonGalleryCell;
  Same: Boolean;
  I: Integer;
begin
  VisibleEntries := TList<TRibbonGalleryEntryViewData>.Create;
  try
    for Entry in FData.GalleryEntries do
      if Entry.Visible then VisibleEntries.Add(Entry);
    Next := VisibleEntries.ToArray;
  finally
    VisibleEntries.Free;
  end;
  Same := Length(Next) = Length(FEntries);
  if Same then
    for I := 0 to High(Next) do
      if Next[I].Id <> FEntries[I].Id then
      begin
        Same := False;
        Break;
      end;
  if not Same then
  begin
    FCells.Clear;
    FList.Clear;
    for I := 0 to High(Next) do
    begin
      Cell := TRibbonGalleryCell.Create(FList);
      Cell.Parent := FList;
      FCells.Add(Cell);
    end;
  end;
  FEntries := Next;
  for I := 0 to High(FEntries) do
    FCells[I].Configure(FEntries[I], IconProvider);
end;

procedure TRibbonGalleryItemView.RestoreSelection;
var
  I, Selected: Integer;
begin
  Selected := -1;
  for I := 0 to High(FEntries) do
    if FEntries[I].Id = FData.SelectedId then
    begin
      Selected := I;
      Break;
    end;
  if FList.ItemIndex <> Selected then FList.ItemIndex := Selected;
end;

procedure TRibbonGalleryItemView.DoApply;
begin
  SyncEntries;
  RestoreSelection;
end;

procedure TRibbonGalleryItemView.PointerBeginning(Sender: TObject);
begin
  RestoreValue;
end;

procedure TRibbonGalleryItemView.PointerReleased(Sender: TObject; ACommit: Boolean);
begin
  if not ACommit then RestoreValue
  else SelectionChanged(Sender);
end;

procedure TRibbonGalleryItemView.SelectionChanged(Sender: TObject);
var
  I: Integer;
  EventData: TRibbonItemInput;
begin
  if (FUpdating <> 0) or (Control = nil) then Exit;
  if FList.PreviewActive then Exit;
  if not AcceptValueInput then Exit;
  I := FList.ItemIndex;
  if (I < 0) or (I >= Length(FEntries)) or not FEntries[I].Enabled then
  begin
    Inc(FUpdating);
    try
      RestoreSelection;
    finally
      Dec(FUpdating);
    end;
    Exit;
  end;
  EventData := Input(rikGallerySelect);
  EventData.SelectedId := FEntries[I].Id;
  EventData.Index := I;
  Emit(EventData);
end;

function TRibbonGalleryItemView.MeasurementKey: string;
var
  Cell: TRibbonGalleryCell;
begin
  Result := inherited MeasurementKey;
  for Cell in FCells do
  begin
    Cell.ApplyStyleLookup;
    Result := Result + '|' + RibbonControlMeasureKey(Cell) + ':' +
      RibbonFontMeasureKey(Cell.ResultingTextSettings.Font);
  end;
end;

function TRibbonGalleryItemView.DesiredSize: TSizeF;
var
  Cell: TRibbonGalleryCell;
  Size: TSizeF;
  CellWidth, CellHeight, Side: Single;
  Columns: Integer;
begin
  CellWidth := 80;
  CellHeight := 68;
  for Cell in FCells do
  begin
    Cell.ApplyStyleLookup;
    Size := IncludeControlPadding(Cell,
      FTextMeasure.Measure(Cell.Text, Cell.ResultingTextSettings.Font));
    Side := RibbonThemeStyleMetric(Cell, RibbonThemeLargeIconPart, 32);
    CellWidth := Max(CellWidth, Max(Size.Width + 16, Side + 16));
    CellHeight := Max(CellHeight, Size.Height + Side + 14);
  end;
  Columns := Min(3, Max(1, FCells.Count));
  Inc(FUpdating);
  try
    FList.Columns := Columns;
    FList.ItemHeight := CellHeight;
  finally
    Dec(FUpdating);
  end;
  Result := IncludeControlPadding(FList,
    TSizeF.Create(Columns * CellWidth + 20, CellHeight + 12));
end;

end.
