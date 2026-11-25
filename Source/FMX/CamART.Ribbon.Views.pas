unit CamART.Ribbon.Views;

{$B-}

interface

uses
  System.Classes,
  System.Types,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Graphics,
  FMX.TextLayout,
  FMX.Objects,
  CamART.Ribbon.Icons,
  CamART.Ribbon.Interaction,
  CamART.Ribbon.Themes,
  CamART.Ribbon.StyleScope,
  CamART.Ribbon.Types;

type
  { Persistent, instance-local text measurement. It owns no model or style part. }
  TRibbonTextMeasure = class
  private
    FLayout: TTextLayout;
  public
    constructor Create;
    destructor Destroy; override;
    function Measure(const AText: string; AFont: TFont): TSizeF;
  end;

  TRibbonTabButton = class(TRibbonInputButton)
  private
    FItemId: string;
    FSelected: Boolean;
    FTextMeasure: TRibbonTextMeasure;
    procedure SetSelected(const AValue: Boolean);
  protected
    function GetDefaultStyleLookupName: string; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DesiredSize: TSizeF;
    function DesiredWidth: Single;
    property ItemId: string read FItemId write FItemId;
    property Selected: Boolean read FSelected write SetSelected;
  end;

  { A collapsed group opens a separate presentation of the same model IDs. }
  TRibbonGroupLauncher = class(TRibbonInputButton)
  private
    FItemId: string;
    FTextMeasure: TRibbonTextMeasure;
  protected
    function GetDefaultStyleLookupName: string; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DesiredSize: TSizeF;
    property ItemId: string read FItemId write FItemId;
  end;

  TRibbonCommandButton = class(TRibbonInputButton)
  private
    FItemId: string;
    FTextMeasure: TRibbonTextMeasure;
    FIcon: TRibbonIconBinding;
    FIconKey: string;
    FButtonStyle: TRibbonButtonStyle;
    FButtonKind: TRibbonButtonKind;
    FMinimumTargetSize: Single;
    FArrow: TButton;
    FStyleText: TText;
    FOnDropDown: TNotifyEvent;
    FArranging: Boolean;
    procedure SetMinimumTargetSize(const AValue: Single);
    procedure ArrowClick(Sender: TObject);
    procedure IconChanged(Sender: TObject);
    procedure ArrangeContent;
    function RoleForStyle(AStyle: TRibbonButtonStyle): TRibbonStyleRole;
    function IconSize: Single;
    function GetHasIcon: Boolean;
  protected
    function GetDefaultStyleLookupName: string; override;
    procedure ApplyStyle; override;
    procedure FreeStyle; override;
    procedure Resize; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Configure(AStyle: TRibbonButtonStyle; AKind: TRibbonButtonKind;
      const AIconKey: string; const AProvider: IRibbonIconProvider;
      AChecked: Boolean);
    function DesiredSize(AStyle: TRibbonButtonStyle): TSizeF;
    property ItemId: string read FItemId write FItemId;
    property HasIcon: Boolean read GetHasIcon;
    property PresentationStyle: TRibbonButtonStyle read FButtonStyle;
    property MinimumTargetSize: Single read FMinimumTargetSize write SetMinimumTargetSize;
    property ArrowButton: TButton read FArrow;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
  end;

  TRibbonGroupView = class(TStyledControl, IRibbonStyleSource)
  private
    FItemId: string;
    FCaption: string;
    FCaptionLabel: TLabel;
    FStyleCaption: TText;
    FCaptionBounds: TRectF;
    FTextMeasure: TRibbonTextMeasure;
    FDefaultTemplate: TFmxObject;
    FNativeDisabledOpacity: Single;
    FStyleReady: Boolean;
    procedure SetCaptionText(const AValue: string);
    procedure UpdateCaption;
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
    procedure ApplyStyle; override;
    procedure FreeStyle; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
    procedure RecalcEnabled; override;
    function DesiredCaptionSize: TSizeF;
    function CaptionBandHeight: Single;
    function DesiredCaptionWidth: Single;
    function MeasurementKey: string;
    procedure SetCaptionBounds(const AValue: TRectF);
    property ItemId: string read FItemId write FItemId;
    property CaptionText: string read FCaption write SetCaptionText;
  end;

function RibbonControlScale(AControl: TControl): Single;
function RibbonFontMeasureKey(AFont: TFont): string;
function RibbonControlPadding(AControl: TControl): TRectF;
function RibbonControlMeasureKey(AControl: TControl): string;
procedure PlaceRibbonStylePart(AHost, APart: TControl; const ABounds: TRectF);

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  CamART.Ribbon.Style,
  CamART.Ribbon.StyleContext,
  CamART.Ribbon.StyledControls,
  CamART.Ribbon.ThemeStyles;

function RibbonControlScale(AControl: TControl): Single;
begin
  Result := 1;
  if (AControl <> nil) and (AControl.Scene <> nil) then
    Result := AControl.Scene.GetSceneScale;
  if Result <= 0 then Result := 1;
end;

function RibbonFontMeasureKey(AFont: TFont): string;
begin
  if AFont = nil then Exit('');
  { Length-prefix the family so delimiters in user font names cannot alias. }
  Result := IntToStr(Length(AFont.Family)) + ':' + AFont.Family + ':' +
    FloatToStr(AFont.Size) + ':' +
    IntToStr(Ord(TFontStyle.fsBold in AFont.Style)) +
    IntToStr(Ord(TFontStyle.fsItalic in AFont.Style)) +
    IntToStr(Ord(TFontStyle.fsUnderline in AFont.Style)) +
    IntToStr(Ord(TFontStyle.fsStrikeOut in AFont.Style));
end;

function TemplatePadding(ATemplate: TFmxObject): TRectF;
  function Safe(AValue: Single): Single;
  begin
    Result := 0;
    if not IsNan(AValue) and not IsInfinite(AValue) and (AValue > 0) then
      Result := AValue;
  end;
begin
  Result := RibbonThemeStylePadding(ATemplate);
  if ATemplate is TControl then
    with TControl(ATemplate).Padding do
      Result := RectF(Safe(Left), Safe(Top), Safe(Right), Safe(Bottom));
end;

function RibbonControlPadding(AControl: TControl): TRectF;
var
  Source: IRibbonStyleSource;
  Insets: TRectF;
begin
  Result := RectF(0, 0, 0, 0);
  if AControl = nil then Exit;
  if Supports(AControl, IRibbonStyleSource, Source) then
    Insets := TemplatePadding(Source.GetRibbonStyle(False))
  else
    Insets := RibbonThemeStylePadding(AControl);
  Result := RectF(Max(0, AControl.Padding.Left) + Insets.Left,
    Max(0, AControl.Padding.Top) + Insets.Top,
    Max(0, AControl.Padding.Right) + Insets.Right,
    Max(0, AControl.Padding.Bottom) + Insets.Bottom);
end;

function RibbonControlMeasureKey(AControl: TControl): string;
var
  Insets: TRectF;
  Context: TRibbonStyleContext;
begin
  if AControl = nil then Exit('');
  if AControl is TStyledControl then TStyledControl(AControl).ApplyStyleLookup;
  Insets := RibbonControlPadding(AControl);
  Result := IntToStr(Ord(AControl.HitTest)) + ':' +
    IntToStr(Ord(AControl.CanFocus)) + ':' +
    FloatToStr(Insets.Left) + ':' + FloatToStr(Insets.Top) + ':' +
    FloatToStr(Insets.Right) + ':' + FloatToStr(Insets.Bottom) + ':' +
    FloatToStr(RibbonThemeStyleMetric(AControl, RibbonThemeLargeIconPart, 32)) + ':' +
    FloatToStr(RibbonThemeStyleMetric(AControl, RibbonThemeSmallIconPart, 16)) + ':' +
    FloatToStr(RibbonThemeStyleMetric(AControl, RibbonThemeOnlyIconPart, 24));
  if AControl is TStyledControl then
    Result := Result + ':' + TStyledControl(AControl).StyleLookup;
  Context := FindRibbonStyleContext(AControl);
  if Context <> nil then Result := Result + ':' + UIntToStr(Context.Revision);
end;

procedure PlaceRibbonStylePart(AHost, APart: TControl; const ABounds: TRectF);
var
  PartParent: TControl;
  P1, P2: TPointF;
begin
  APart.Align := TAlignLayout.None;
  if APart.Parent is TControl then
  begin
    PartParent := TControl(APart.Parent);
    P1 := PartParent.AbsoluteToLocal(AHost.LocalToAbsolute(
      PointF(ABounds.Left, ABounds.Top)));
    P2 := PartParent.AbsoluteToLocal(AHost.LocalToAbsolute(
      PointF(ABounds.Right, ABounds.Bottom)));
    APart.SetBounds(Min(P1.X, P2.X), Min(P1.Y, P2.Y),
      Abs(P2.X - P1.X), Abs(P2.Y - P1.Y));
  end
  else
    APart.SetBounds(ABounds.Left, ABounds.Top, ABounds.Width, ABounds.Height);
end;

constructor TRibbonTextMeasure.Create;
begin
  inherited Create;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create;
end;

destructor TRibbonTextMeasure.Destroy;
begin
  FLayout.Free;
  inherited;
end;

function TRibbonTextMeasure.Measure(const AText: string; AFont: TFont): TSizeF;
begin
  if AFont = nil then
    raise EArgumentNilException.Create('Text measurement requires a font.');
  FLayout.BeginUpdate;
  try
    FLayout.MaxSize := PointF(1000000, 1000000);
    FLayout.WordWrap := False;
    FLayout.Font.Assign(AFont);
    FLayout.Text := AText;
  finally
    FLayout.EndUpdate;
  end;
  Result := TSizeF.Create(Ceil(FLayout.TextWidth), Ceil(FLayout.TextHeight));
end;

constructor TRibbonTabButton.Create(AOwner: TComponent);
begin
  inherited;
  RibbonStyleRole := rsrTab;
  Stored := False;
  CanFocus := True;
  StaysPressed := True;
  FTextMeasure := TRibbonTextMeasure.Create;
end;

destructor TRibbonTabButton.Destroy;
begin
  FTextMeasure.Free;
  inherited;
end;

function TRibbonTabButton.GetDefaultStyleLookupName: string;
begin
  { A descendant's generated class style name would bypass a form StyleBook's
    standard button resource. Explicit StyleLookup still takes precedence. }
  Result := 'buttonstyle';
end;

procedure TRibbonTabButton.SetSelected(const AValue: Boolean);
begin
  FSelected := AValue;
  IsPressed := AValue;
end;

function TRibbonTabButton.DesiredSize: TSizeF;
var
  Size: TSizeF;
  Insets: TRectF;
begin
  ApplyStyleLookup;
  Insets := RibbonControlPadding(Self);
  Size := FTextMeasure.Measure(Text, ResultingTextSettings.Font);
  Result := TSizeF.Create(
    Max(64, Size.Width + 24 + Insets.Left + Insets.Right),
    Max(FindRibbonMetrics(Self).TabMinHeight,
      Size.Height + 12 + Insets.Top + Insets.Bottom));
end;

function TRibbonTabButton.DesiredWidth: Single;
var
  Size: TSizeF;
begin
  Size := DesiredSize;
  Result := Size.Width;
end;

constructor TRibbonGroupLauncher.Create(AOwner: TComponent);
begin
  inherited;
  RibbonStyleRole := rsrCollapsedGroup;
  Stored := False;
  CanFocus := True;
  FTextMeasure := TRibbonTextMeasure.Create;
end;

destructor TRibbonGroupLauncher.Destroy;
begin
  FTextMeasure.Free;
  inherited;
end;

function TRibbonGroupLauncher.GetDefaultStyleLookupName: string;
begin
  Result := 'buttonstyle';
end;

function TRibbonGroupLauncher.DesiredSize: TSizeF;
var
  Size: TSizeF;
  Insets: TRectF;
begin
  ApplyStyleLookup;
  Insets := RibbonControlPadding(Self);
  Size := FTextMeasure.Measure(Text, ResultingTextSettings.Font);
  Result := TSizeF.Create(Max(48, Size.Width + 24 + Insets.Left + Insets.Right),
    Max(40, Size.Height + 16 + Insets.Top + Insets.Bottom));
end;

constructor TRibbonCommandButton.Create(AOwner: TComponent);
begin
  inherited;
  RibbonStyleRole := rsrLargeButton;
  Stored := False;
  CanFocus := True;
  FTextMeasure := TRibbonTextMeasure.Create;
  FMinimumTargetSize := 28;
  FIcon := TRibbonIconBinding.Create(Self, Self, nil);
  FIcon.OnChanged := IconChanged;
  FArrow := TRibbonInputButton.Create(Self);
  TRibbonInputButton(FArrow).RibbonStyleRole := rsrSplitButton;
  AttachRibbonInput(FArrow, ridPointer);
  FArrow.Parent := Self;
  FArrow.Stored := False;
  FArrow.Text := #9662;
  FArrow.CanFocus := True;
  FArrow.Visible := False;
  FArrow.Hint := 'Open menu';
  FArrow.ShowHint := True;
  FArrow.OnClick := ArrowClick;
end;

destructor TRibbonCommandButton.Destroy;
begin
  FOnDropDown := nil;
  FArranging := True;
  FStyleText := nil;
  if FIcon <> nil then FIcon.OnChanged := nil;
  FIcon := nil;
  FArrow := nil;
  FTextMeasure.Free;
  inherited;
end;

function TRibbonCommandButton.GetDefaultStyleLookupName: string;
begin
  Result := 'buttonstyle';
end;

procedure TRibbonCommandButton.ApplyStyle;
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
    ArrangeContent;
  finally
    Watch.Free;
  end;
end;

procedure TRibbonCommandButton.FreeStyle;
begin
  FStyleText := nil;
  inherited;
end;

procedure TRibbonCommandButton.Resize;
var
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control = nil then Exit;
    ArrangeContent;
  finally
    Watch.Free;
  end;
end;

procedure TRibbonCommandButton.IconChanged(Sender: TObject);
begin
  { Image-list removal can resolve an icon to no image without a Ribbon
    refresh. Restore the native caption immediately; ArrangeContent's guard
    also covers notifications raised by its own SetIcon call. }
  ArrangeContent;
end;

function TRibbonCommandButton.IconSize: Single;
begin
  case FButtonStyle of
    rbsLarge: Result := RibbonThemeStyleMetric(Self, RibbonThemeLargeIconPart, 32);
    rbsIcon: Result := RibbonThemeStyleMetric(Self, RibbonThemeOnlyIconPart, 24);
  else
    Result := RibbonThemeStyleMetric(Self, RibbonThemeSmallIconPart, 16);
  end;
end;

function TRibbonCommandButton.RoleForStyle(AStyle: TRibbonButtonStyle): TRibbonStyleRole;
begin
  Result := RibbonStyleRole;
  { QAT/menu/application contexts retain their assigned semantic role when
    the responsive layout changes only the content arrangement. }
  if not (Result in [rsrLargeButton, rsrSmallButton, rsrIconButton]) then Exit;
  case AStyle of
    rbsLarge: Result := rsrLargeButton;
    rbsIcon: Result := rsrIconButton;
  else
    Result := rsrSmallButton;
  end;
end;

function TRibbonCommandButton.GetHasIcon: Boolean;
begin
  Result := False;
  if FIcon <> nil then Result := FIcon.HasIcon and FIcon.Visible;
end;

procedure TRibbonCommandButton.SetMinimumTargetSize(const AValue: Single);
begin
  if IsNan(AValue) or IsInfinite(AValue) or (AValue <= 0) then
    raise EArgumentOutOfRangeException.Create('A target size must be finite and positive.');
  if FMinimumTargetSize = AValue then Exit;
  FMinimumTargetSize := AValue;
  ArrangeContent;
end;

procedure TRibbonCommandButton.Configure(AStyle: TRibbonButtonStyle;
  AKind: TRibbonButtonKind; const AIconKey: string;
  const AProvider: IRibbonIconProvider; AChecked: Boolean);
begin
  FButtonStyle := AStyle;
  RibbonStyleRole := RoleForStyle(AStyle);
  FButtonKind := AKind;
  FIconKey := AIconKey;
  FIcon.Provider := AProvider;
  FArrow.Visible := AKind in [rbkDropDown, rbkSplit, rbkGallery];
  FArrow.Enabled := Enabled;
  StaysPressed := (AKind in [rbkToggle, rbkCheck]) or AChecked;
  IsPressed := AChecked;
  ArrangeContent;
end;

procedure TRibbonCommandButton.ArrowClick(Sender: TObject);
var
  Handler: TNotifyEvent;
begin
  if not AbsoluteEnabled or not Visible or not ParentedVisible or
     not FArrow.Visible or not RibbonActivationAllowed(Self) or
     not RibbonActivationAllowed(FArrow) then Exit;
  Handler := FOnDropDown;
  if Assigned(Handler) then Handler(Self);
  { A dropdown callback may destroy this button. No Self access follows. }
end;

procedure TRibbonCommandButton.KeyDown(var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
var
  Handler: TNotifyEvent;
begin
  RibbonKeyboardInput(Self);
  if (Key = vkDown) and (ssAlt in Shift) and FArrow.Visible then
  begin
    Key := 0;
    KeyChar := #0;
    if not AbsoluteEnabled or not Visible or not ParentedVisible then Exit;
    Handler := FOnDropDown;
    if Assigned(Handler) then Handler(Self);
    Exit;
  end;
  inherited;
end;

procedure TRibbonCommandButton.ArrangeContent;
var
  R, TextRect, Insets: TRectF;
  HasImage: Boolean;
  Side, ArrowWidth: Single;
  Watch: TRibbonStyleWatch;
begin
  if FArranging or (FIcon = nil) or (FArrow = nil) then Exit;
  Watch := TRibbonStyleWatch.Create(Self);
  try
    FArranging := True;
    try
      Side := IconSize;
      HasImage := FIcon.SetIcon(FIconKey, Side, RibbonControlScale(Self));
      if Watch.Control = nil then Exit;
      { An opaque third-party button style may expose no TText resource. Retain
        its native caption in that case rather than overlaying it with an icon. }
      HasImage := HasImage and (FStyleText <> nil);
      FIcon.Visible := HasImage;
      if Watch.Control = nil then Exit;
      ArrowWidth := 0;
      if FArrow.Visible then
      begin
        ArrowWidth := Max(24, FMinimumTargetSize);
        FArrow.SetBounds(Max(0, Width - ArrowWidth), 0, ArrowWidth, Height);
        if Watch.Control = nil then Exit;
        FArrow.BringToFront;
        if Watch.Control = nil then Exit;
      end;
      Insets := RibbonControlPadding(Self);
      R := RectF(Insets.Left + 6, Insets.Top + 4,
        Max(Insets.Left + 6, Width - ArrowWidth - Insets.Right - 6),
        Max(Insets.Top + 4, Height - Insets.Bottom - 4));
      TextRect := R;
      if HasImage then
        case FButtonStyle of
          rbsLarge:
            begin
              FIcon.SetBounds(R.Left + Max(0, (R.Width - Side) / 2),
                R.Top + 2, Side, Side);
              if Watch.Control = nil then Exit;
              TextRect.Top := Min(R.Bottom, R.Top + Side + 6);
            end;
          rbsSmall:
            begin
              FIcon.SetBounds(R.Left, R.Top + Max(0, (R.Height - Side) / 2),
                Side, Side);
              if Watch.Control = nil then Exit;
              TextRect.Left := Min(R.Right, R.Left + Side + 6);
            end;
          rbsIcon:
            begin
              FIcon.SetBounds(R.Left + Max(0, (R.Width - Side) / 2),
                R.Top + Max(0, (R.Height - Side) / 2), Side, Side);
              if Watch.Control = nil then Exit;
            end;
        end;
      if FStyleText <> nil then
      begin
        FStyleText.Visible := not ((FButtonStyle = rbsIcon) and HasImage);
        if Watch.Control = nil then Exit;
        PlaceRibbonStylePart(Self, FStyleText, TextRect);
      end;
    finally
      if Watch.Control <> nil then FArranging := False;
    end;
  finally
    Watch.Free;
  end;
end;

function TRibbonCommandButton.DesiredSize(AStyle: TRibbonButtonStyle): TSizeF;
var
  Size: TSizeF;
  Extra, Side: Single;
  Template, Part: TFmxObject;
  Context: TRibbonStyleContext;
  Insets: TRectF;
  Font: TFont;
  HasImage: Boolean;
  Metrics: TRibbonMetrics;
  Target: Single;
begin
  ApplyStyleLookup;
  Metrics := FindRibbonMetrics(Self);
  { MinimumTargetSize is the density floor (28 pointer / 44 touch). The
    pointer value is the configurable small-item floor of the Ribbon. }
  Target := FMinimumTargetSize;
  if Target = RibbonDefaultSmallButtonMinHeight then
    Target := Metrics.SmallButtonMinHeight;
  Template := nil;
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Template := Context.ResolveRibbonStyle(Self, RoleForStyle(AStyle), False);
  Insets := TemplatePadding(Template);
  if Template = nil then Insets := RibbonThemeStylePadding(Self);
  Insets := RectF(Insets.Left + Max(0, Padding.Left),
    Insets.Top + Max(0, Padding.Top), Insets.Right + Max(0, Padding.Right),
    Insets.Bottom + Max(0, Padding.Bottom));
  Font := TFont.Create;
  try
    Font.Assign(ResultingTextSettings.Font);
    Part := nil;
    if Template <> nil then Part := Template.FindStyleResource('text', False);
    if Part is TText then
    begin
      { Measure the other role's real template without applying it to the
        live control. Explicit user font overrides remain authoritative. }
      if TStyledSetting.Family in StyledSettings then
        Font.Family := TText(Part).TextSettings.Font.Family;
      if TStyledSetting.Size in StyledSettings then
        Font.Size := TText(Part).TextSettings.Font.Size;
      if TStyledSetting.Style in StyledSettings then
        Font.Style := TText(Part).TextSettings.Font.Style;
    end;
    HasImage := (FIcon <> nil) and FIcon.HasIcon and
      ((Part is TText) or ((Template = nil) and (FStyleText <> nil)));
    case AStyle of
      rbsLarge: Side := RibbonThemeStyleMetric(Template, RibbonThemeLargeIconPart, 32);
      rbsIcon: Side := RibbonThemeStyleMetric(Template, RibbonThemeOnlyIconPart, 24);
    else
      Side := RibbonThemeStyleMetric(Template, RibbonThemeSmallIconPart, 16);
    end;
    Size := FTextMeasure.Measure(Text, Font);
    if (AStyle = rbsIcon) and HasImage then
      Result := TSizeF.Create(Side + 16, Side + 16)
    else if AStyle = rbsLarge then
    begin
      Extra := 0;
      if HasImage then Extra := Side + 6;
      Result := TSizeF.Create(Max(Max(72, Side + 16), Size.Width + 24),
        Max(Metrics.LargeButtonMinHeight, Size.Height + 20 + Extra));
    end
    else
    begin
      Extra := 0;
      if HasImage then Extra := Side + 6;
      Result := TSizeF.Create(Max(36, Size.Width + 20 + Extra),
        Max(Max(Metrics.SmallButtonMinHeight, Side + 8), Size.Height + 10));
    end;
    Result.Width := Max(Result.Width, Target);
    Result.Height := Max(Result.Height, Target);
    if FArrow.Visible then Result.Width := Result.Width + Max(24, FMinimumTargetSize);
    Result.Width := Result.Width + Insets.Left + Insets.Right;
    Result.Height := Result.Height + Insets.Top + Insets.Bottom;
  finally
    Font.Free;
  end;
end;

constructor TRibbonGroupView.Create(AOwner: TComponent);
begin
  inherited;
  FNativeDisabledOpacity := DisabledOpacity;
  Stored := False;
  CanFocus := False;
  HitTest := False;
  FTextMeasure := TRibbonTextMeasure.Create;
  FCaptionLabel := TRibbonStyledLabel.Create(Self);
  FCaptionLabel.Parent := Self;
  FCaptionLabel.Stored := False;
  FCaptionLabel.HitTest := False;
  FCaptionLabel.CanFocus := False;
  FCaptionLabel.TextSettings.HorzAlign := TTextAlign.Center;
  FCaptionLabel.TextSettings.VertAlign := TTextAlign.Center;
  FCaptionLabel.TextSettings.WordWrap := False;
  FStyleReady := True;
end;

destructor TRibbonGroupView.Destroy;
begin
  FStyleCaption := nil;
  FTextMeasure.Free;
  FDefaultTemplate.Free;
  inherited;
end;

function TRibbonGroupView.GetDefaultStyleLookupName: string;
begin
  Result := RibbonGroupStyleName;
end;

function TRibbonGroupView.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Exit(Context.ResolveRibbonStyle(Self, rsrGroup, AClone));
  Result := TStyledControl.LookupStyleObject(Self, Self, Scene, StyleLookup,
    RibbonGroupStyleName, ParentClassStyleLookupName, AClone, True);
  if Result <> nil then Exit;
  { Standalone presenter use remains supported. The False overload borrows a
    stable template; only the True overload transfers a newly owned clone. }
  if FDefaultTemplate = nil then FDefaultTemplate := CreateDefaultGroupStyle;
  if AClone then Result := FDefaultTemplate.Clone(nil)
  else Result := FDefaultTemplate;
end;

function TRibbonGroupView.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonGroupView.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

procedure TRibbonGroupView.ApplyStyle;
var
  Part: TFmxObject;
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control = nil then Exit;
    FStyleCaption := nil;
    Part := FindStyleResource('caption');
    if Part is TText then FStyleCaption := TText(Part);
    if FStyleReady then
    begin
      if FindStyleResource(RibbonThemeMarkerPart) <> nil then DisabledOpacity := 1
      else DisabledOpacity := FNativeDisabledOpacity;
      ApplyRibbonThemeEnabled(Self, AbsoluteEnabled);
    end;
    UpdateCaption;
  finally
    Watch.Free;
  end;
end;

procedure TRibbonGroupView.RecalcEnabled;
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

procedure TRibbonGroupView.FreeStyle;
begin
  FStyleCaption := nil;
  if FCaptionLabel <> nil then
    FCaptionLabel.Visible := True;
  inherited;
end;

procedure TRibbonGroupView.SetCaptionText(const AValue: string);
begin
  if FCaption <> AValue then
  begin
    FCaption := AValue;
    UpdateCaption;
  end;
end;

procedure TRibbonGroupView.UpdateCaption;
var
  PartParent: TControl;
  P1, P2: TPointF;
begin
  if FCaptionLabel = nil then
    Exit;
  FCaptionLabel.Text := FCaption;
  FCaptionLabel.Visible := FStyleCaption = nil;
  if FStyleCaption <> nil then
  begin
    FStyleCaption.Text := FCaption;
    FStyleCaption.Align := TAlignLayout.None;
    if FStyleCaption.Parent is TControl then
    begin
      { A user StyleBook may nest caption inside another layout. Placement
        comes from the group layout engine, in this control's coordinates. }
      PartParent := TControl(FStyleCaption.Parent);
      P1 := PartParent.AbsoluteToLocal(LocalToAbsolute(
        PointF(FCaptionBounds.Left, FCaptionBounds.Top)));
      P2 := PartParent.AbsoluteToLocal(LocalToAbsolute(
        PointF(FCaptionBounds.Right, FCaptionBounds.Bottom)));
      FStyleCaption.SetBounds(Min(P1.X, P2.X), Min(P1.Y, P2.Y),
        Abs(P2.X - P1.X), Abs(P2.Y - P1.Y));
    end
    else
      FStyleCaption.SetBounds(FCaptionBounds.Left, FCaptionBounds.Top,
        FCaptionBounds.Width, FCaptionBounds.Height);
  end;
  FCaptionLabel.SetBounds(FCaptionBounds.Left, FCaptionBounds.Top,
    FCaptionBounds.Width, FCaptionBounds.Height);
end;

function TRibbonGroupView.DesiredCaptionSize: TSizeF;
begin
  ApplyStyleLookup;
  if FStyleCaption <> nil then
    Result := FTextMeasure.Measure(FCaption, FStyleCaption.TextSettings.Font)
  else
  begin
    FCaptionLabel.ApplyStyleLookup;
    Result := FTextMeasure.Measure(FCaption,
      FCaptionLabel.ResultingTextSettings.Font);
  end;
end;

function TRibbonGroupView.CaptionBandHeight: Single;
var
  Band: TFmxObject;
begin
  { The style's caption band has its own height. The layout caption area must
    be at least as tall, otherwise the band paints over the item area. }
  Result := 0;
  ApplyStyleLookup;
  Band := FindStyleResource('captionbackground');
  if (Band is TControl) and (TControl(Band).Align = TAlignLayout.Bottom) then
    Result := TControl(Band).Height;
end;

function TRibbonGroupView.DesiredCaptionWidth: Single;
var
  Size: TSizeF;
begin
  Size := DesiredCaptionSize;
  Result := Size.Width;
end;

function TRibbonGroupView.MeasurementKey: string;
begin
  ApplyStyleLookup;
  Result := RibbonControlMeasureKey(Self);
  if FStyleCaption <> nil then
    Result := Result + ':' + RibbonFontMeasureKey(FStyleCaption.TextSettings.Font)
  else
  begin
    FCaptionLabel.ApplyStyleLookup;
    Result := Result + ':' + RibbonFontMeasureKey(FCaptionLabel.ResultingTextSettings.Font);
  end;
end;

procedure TRibbonGroupView.SetCaptionBounds(const AValue: TRectF);
begin
  FCaptionBounds := AValue;
  UpdateCaption;
end;

end.
