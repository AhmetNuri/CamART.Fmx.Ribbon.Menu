unit CamART.Ribbon.ThemeStyles;

interface

uses
  System.Classes,
  System.Types,
  FMX.Types,
  FMX.Controls,
  CamART.Ribbon.Themes;

const
  RibbonThemeMarkerPart = 'camartthemev1';
  RibbonThemeDisabledPart = 'disabledbackground';
  RibbonThemeMetricsPart = 'ribbonmetrics';
  RibbonThemeLargeIconPart = 'ribboniconlarge';
  RibbonThemeSmallIconPart = 'ribboniconsmall';
  RibbonThemeOnlyIconPart = 'ribbonicononly';

{ Every call creates an independent, streamable template. No shared StyleBook
  resource or application-global style is changed. Returned objects belong to
  the caller until supplied to FMX as that control's owned style instance. }
function CreateRibbonThemeStyle(ARole: TRibbonStyleRole;
  const ATokens: TRibbonThemeTokens): TFmxObject; overload;
function CreateRibbonThemeStyle(ARole: TRibbonStyleRole;
  ATheme: TRibbonTheme): TFmxObject; overload;

{ Ribbon-specific resources only. Full native Edit/Combo/Color/ScrollBox
  semantics stay with the selected book or the FMX platform style. }
function CreateRibbonThemeStyleBook(AOwner: TComponent;
  const ATokens: TRibbonThemeTokens): TStyleBook; overload;
function CreateRibbonThemeStyleBook(AOwner: TComponent;
  ATheme: TRibbonTheme): TStyleBook; overload;

{ Apply only to an isolated control style instance, never a shared book's
  template. Does nothing when the private generated-template marker is absent.
  FMX has no documented IsEnabled trigger: owning native controls call this
  from ApplyStyle/EnabledChanged or their state synchronization. Native
  DisabledOpacity still handles ancestor disabled rendering. }
procedure ApplyRibbonThemeEnabled(AInstance: TFmxObject; AEnabled: Boolean);
{ Read geometry from the actual chosen style instance, including a generated
  custom-token book. Missing/wrong metric parts use explicit safe defaults. }
function RibbonThemeStylePadding(AInstance: TFmxObject): TRectF;
function RibbonThemeStyleMetric(AInstance: TFmxObject; const AName: string;
  ADefault: Single): Single;

implementation

uses
  System.SysUtils,
  System.Math,
  System.UITypes,
  FMX.Ani,
  FMX.Graphics,
  FMX.Layouts,
  FMX.Objects,
  FMX.Styles;

function AddRectangle(AOwner: TComponent; AParent: TFmxObject;
  const AName: string; AColor: TAlphaColor; ABorder: TAlphaColor;
  ARadius, ABorderWidth: Single): TRectangle;
begin
  Result := TRectangle.Create(AOwner);
  Result.Parent := AParent;
  Result.StyleName := AName;
  Result.HitTest := False;
  Result.Align := TAlignLayout.Contents;
  Result.Fill.Kind := TBrushKind.Solid;
  Result.Fill.Color := AColor;
  Result.Stroke.Color := ABorder;
  Result.Stroke.Thickness := ABorderWidth;
  if ABorderWidth = 0 then Result.Stroke.Kind := TBrushKind.None;
  Result.XRadius := ARadius;
  Result.YRadius := ARadius;
end;

function AddText(AOwner: TComponent; AParent: TFmxObject;
  const AName: string; AColor: TAlphaColor; ASize: Single): TText;
begin
  Result := TText.Create(AOwner);
  Result.Parent := AParent;
  Result.StyleName := AName;
  Result.Align := TAlignLayout.Client;
  Result.HitTest := False;
  Result.Text := '';
  Result.TextSettings.Font.Size := ASize;
  Result.TextSettings.FontColor := AColor;
  Result.TextSettings.WordWrap := False;
  Result.TextSettings.HorzAlign := TTextAlign.Center;
  Result.TextSettings.VertAlign := TTextAlign.Center;
end;

procedure AddStateValue(AControl: TControl; const AName, ATrigger: string;
  AValue: Single);
var
  Animation: TFloatAnimation;
begin
  Animation := TFloatAnimation.Create(AControl);
  Animation.Parent := AControl;
  Animation.StyleName := AName;
  Animation.PropertyName := 'Opacity';
  Animation.StartValue := AValue;
  Animation.StopValue := AValue;
  Animation.StartFromCurrent := False;
  Animation.Duration := 0;
  Animation.Loop := False;
  Animation.AutoReverse := False;
  Animation.Trigger := ATrigger;
  { A zero-duration native trigger is a state assignment. No transient
    interpolation, timer policy, effect or delayed business callback is used.
    Opposite states have separate assignments, so a stopped forward trigger
    cannot leave the overlay at its former stop value. }
end;

procedure AddBooleanState(AControl: TControl; const AProperty: string);
begin
  AControl.Opacity := 0;
  AddStateValue(AControl, 'stateon', AProperty + '=true', 1);
  AddStateValue(AControl, 'stateoff', AProperty + '=false', 0);
end;

procedure AddMetadata(ARoot: TLayout; ANormalText, ADisabledText: TAlphaColor;
  const T: TRibbonThemeTokens);
var
  Metadata, Metrics, Metric: TLayout;
  Part: TText;
  procedure AddMetric(const AName: string; AValue: Single);
  begin
    Metric := TLayout.Create(Metrics);
    Metric.Parent := Metrics;
    Metric.StyleName := AName;
    Metric.Visible := False;
    Metric.HitTest := False;
    Metric.SetBounds(0, 0, AValue, 0);
  end;
begin
  Metadata := TLayout.Create(ARoot);
  Metadata.Parent := ARoot;
  Metadata.StyleName := RibbonThemeMarkerPart;
  Metadata.Visible := False;
  Metadata.HitTest := False;
  Metadata.SetBounds(0, 0, 0, 0);
  Part := AddText(Metadata, Metadata, 'normaltextcolor', ANormalText, 1);
  Part.Visible := False;
  Part := AddText(Metadata, Metadata, 'disabledtextcolor', ADisabledText, 1);
  Part.Visible := False;
  Metrics := TLayout.Create(ARoot);
  Metrics.Parent := ARoot;
  Metrics.StyleName := RibbonThemeMetricsPart;
  Metrics.Visible := False;
  Metrics.HitTest := False;
  Metrics.SetBounds(0, 0, 0, 0);
  Metrics.Padding.Rect := ARoot.Padding.Rect;
  AddMetric(RibbonThemeLargeIconPart, T.LargeIconSize);
  AddMetric(RibbonThemeSmallIconPart, T.SmallIconSize);
  AddMetric(RibbonThemeOnlyIconPart, T.IconOnlySize);
end;

function RibbonThemeStylePadding(AInstance: TFmxObject): TRectF;
var
  Part: TFmxObject;
  Bounds: TRectF;
  function Valid(AValue: Single): Boolean;
  begin
    Result := not IsNan(AValue) and not IsInfinite(AValue) and (AValue >= 0);
  end;
begin
  Result := RectF(0, 0, 0, 0);
  if AInstance = nil then Exit;
  Part := AInstance.FindStyleResource(RibbonThemeMetricsPart);
  if not (Part is TLayout) then Exit;
  Bounds := TLayout(Part).Padding.Rect;
  if Valid(Bounds.Left) and Valid(Bounds.Top) and
     Valid(Bounds.Right) and Valid(Bounds.Bottom) then Result := Bounds;
end;

function RibbonThemeStyleMetric(AInstance: TFmxObject;
  const AName: string; ADefault: Single): Single;
var
  Part: TFmxObject;
  Value: Single;
begin
  Result := ADefault;
  if AInstance = nil then Exit;
  Part := AInstance.FindStyleResource(AName);
  if not (Part is TLayout) then Exit;
  Value := TLayout(Part).Width;
  if not IsNan(Value) and not IsInfinite(Value) and (Value > 0) then
    Result := Value;
end;

procedure ApplyRibbonThemeEnabled(AInstance: TFmxObject; AEnabled: Boolean);
var
  Marker, Part, ColorPart: TFmxObject;
  Text: TText;
begin
  if AInstance = nil then Exit;
  Marker := AInstance.FindStyleResource(RibbonThemeMarkerPart);
  if not (Marker is TLayout) then Exit;
  Part := AInstance.FindStyleResource(RibbonThemeDisabledPart);
  if Part is TControl then
    if AEnabled then TControl(Part).Opacity := 0
    else TControl(Part).Opacity := 1;
  Part := AInstance.FindStyleResource('text');
  if not (Part is TText) then Part := AInstance.FindStyleResource('caption');
  if not (Part is TText) then Exit;
  Text := TText(Part);
  if AEnabled then ColorPart := Marker.FindStyleResource('normaltextcolor')
  else ColorPart := Marker.FindStyleResource('disabledtextcolor');
  if ColorPart is TText then
    Text.TextSettings.FontColor := TText(ColorPart).TextSettings.FontColor;
end;

procedure SetSurfaceGradient(ARectangle: TRectangle;
  ATop, ABottom: TAlphaColor);
begin
  ARectangle.Fill.Kind := TBrushKind.Gradient;
  ARectangle.Fill.Gradient.Style := TGradientStyle.Linear;
  { The rectangle owns a new native gradient with its two default endpoints. }
  ARectangle.Fill.Gradient.Color := ATop;
  ARectangle.Fill.Gradient.Color1 := ABottom;
  ARectangle.Fill.Gradient.StartPosition.Point := PointF(0, 0);
  ARectangle.Fill.Gradient.StopPosition.Point := PointF(0, 1);
end;

function CreateRootStyle(const T: TRibbonThemeTokens): TLayout;
var
  Background: TRectangle;
  TabStrip, Content: TLayout;
begin
  Result := TLayout.Create(nil);
  try
    Result.StyleName := RibbonThemeStyleName(rsrRoot);
    Result.SetBounds(0, 0, 640, 168);
    Result.HitTest := False;
    Result.Padding.Rect := RectF(T.GroupPadding, 0, T.GroupPadding, T.GroupPadding);
    Background := AddRectangle(Result, Result, 'background', T.Surface,
      T.Border, 0, T.BorderThickness);
    if T.UseSurfaceGradient then
      SetSurfaceGradient(Background, T.SurfaceTop, T.Surface);
    TabStrip := TLayout.Create(Result);
    TabStrip.Parent := Result;
    TabStrip.StyleName := 'tabstrip';
    TabStrip.Align := TAlignLayout.Top;
    TabStrip.Height := T.TabHeight;
    TabStrip.HitTest := False;
    Content := TLayout.Create(Result);
    Content.Parent := Result;
    Content.StyleName := 'content';
    Content.Align := TAlignLayout.Client;
    Content.HitTest := False;
    AddMetadata(Result, T.Text, T.DisabledText, T);
  except
    Result.Free;
    raise;
  end;
end;

function CreateGroupStyle(const T: TRibbonThemeTokens): TLayout;
var
  CaptionBand: TRectangle;
  Caption: TText;
begin
  Result := TLayout.Create(nil);
  try
    Result.StyleName := RibbonThemeStyleName(rsrGroup);
    Result.SetBounds(0, 0, 128, 128);
    Result.HitTest := False;
    Result.Padding.Rect := RectF(T.GroupPadding, T.GroupPadding,
      T.GroupPadding, T.GroupPadding);
    AddRectangle(Result, Result, 'background', T.GroupSurface, T.Border,
      T.GroupCornerRadius, T.BorderThickness);
    CaptionBand := AddRectangle(Result, Result, 'captionbackground',
      T.GroupCaptionSurface, T.Border, 0, 0);
    CaptionBand.Align := TAlignLayout.Bottom;
    CaptionBand.Height := T.CaptionFontSize + 10;
    Caption := AddText(CaptionBand, CaptionBand, 'caption', T.MutedText,
      T.CaptionFontSize);
    if T.CaptionBold then Caption.TextSettings.Font.Style := [TFontStyle.fsBold];
    AddMetadata(Result, T.MutedText, T.DisabledText, T);
  except
    Result.Free;
    raise;
  end;
end;

function CreateButtonStyle(ARole: TRibbonStyleRole;
  const T: TRibbonThemeTokens): TLayout;
var
  BaseColor, HoverColor, PressedColor, SelectedColor, TextColor,
    FocusColor: TAlphaColor;
  Hover, Pressed, Selected, Disabled, Focus, Mark: TRectangle;
  Selection: TLayout;
  Text: TText;
  StateProperty: string;
begin
  BaseColor := T.GroupSurface;
  HoverColor := T.HoverSurface;
  PressedColor := T.PressedSurface;
  SelectedColor := T.CheckedSurface;
  TextColor := T.Text;
  FocusColor := T.Focus;
  StateProperty := 'IsPressed';
  if ARole = rsrTab then
  begin
    BaseColor := T.TabSurface;
    SelectedColor := T.ActiveTabSurface;
  end;
  if ARole = rsrApplicationButton then
  begin
    BaseColor := T.ApplicationSurface;
    HoverColor := T.ApplicationHoverSurface;
    PressedColor := T.ApplicationPressedSurface;
    SelectedColor := T.ApplicationPressedSurface;
    TextColor := T.ApplicationText;
    FocusColor := T.ApplicationFocus;
  end;
  if ARole = rsrGalleryItem then StateProperty := 'IsSelected';
  Result := TLayout.Create(nil);
  try
    Result.StyleName := RibbonThemeStyleName(ARole);
    Result.HitTest := False;
    Result.Padding.Rect := RectF(T.PaddingX, T.PaddingY, T.PaddingX, T.PaddingY);
    case ARole of
      rsrLargeButton, rsrSplitButton: Result.SetBounds(0, 0, 112, 84);
      rsrIconButton, rsrQuickAccess: Result.SetBounds(0, 0, 36, 36);
      rsrTab: Result.SetBounds(0, 0, 100, T.TabHeight);
      rsrApplicationButton: Result.SetBounds(0, 0, 88, T.TabHeight);
      rsrCollapsedGroup: Result.SetBounds(0, 0, 128, 104);
      rsrMenuItem: Result.SetBounds(0, 0, 208, 36);
      rsrGalleryItem: Result.SetBounds(0, 0, 112, 84);
    else
      Result.SetBounds(0, 0, 112, 34);
    end;
    AddRectangle(Result, Result, 'background', BaseColor, T.Border,
      T.ButtonCornerRadius, T.BorderThickness);
    Selected := AddRectangle(Result, Result, 'selectedbackground',
      SelectedColor, T.Border, T.ButtonCornerRadius, T.BorderThickness);
    AddBooleanState(Selected, StateProperty);
    Hover := AddRectangle(Result, Result, 'hoverbackground', HoverColor,
      T.Border, T.ButtonCornerRadius, T.BorderThickness);
    Hover.Opacity := 0;
    AddStateValue(Hover, 'hoveron', 'IsMouseOver=true;' + StateProperty + '=false', 1);
    AddStateValue(Hover, 'hoveroff', 'IsMouseOver=false', 0);
    AddStateValue(Hover, 'selectedoff', StateProperty + '=true', 0);
    if ARole <> rsrGalleryItem then
    begin
      Pressed := AddRectangle(Result, Result, 'pressedbackground',
        PressedColor, T.Border, T.ButtonCornerRadius, T.BorderThickness);
      Pressed.Opacity := 0;
      AddStateValue(Pressed, 'pressedon', 'IsPressed=true;IsMouseOver=true', 1);
      AddStateValue(Pressed, 'pressedoff', 'IsPressed=false', 0);
      AddStateValue(Pressed, 'mouseout', 'IsMouseOver=false', 0);
    end;
    Disabled := AddRectangle(Result, Result, RibbonThemeDisabledPart,
      T.DisabledSurface, T.Border, T.ButtonCornerRadius, T.BorderThickness);
    Disabled.Opacity := 0;
    Selection := TLayout.Create(Result);
    Selection.Parent := Result;
    Selection.StyleName := 'selection';
    Selection.Align := TAlignLayout.Contents;
    Selection.HitTest := False;
    Selection.Padding.Rect := RectF(3, 3, 3, 3);
    AddBooleanState(Selection, StateProperty);
    { A persistent geometric underline is visible for selected/checked
      commands and tabs. Selection is not encoded by fill hue alone. }
    Mark := AddRectangle(Selection, Selection, 'selectionmark',
      T.Accent, T.Accent, 0, 0);
    if ARole = rsrApplicationButton then Mark.Fill.Color := T.ApplicationText;
    Mark.Align := TAlignLayout.Bottom;
    Mark.Height := 3;
    Text := AddText(Result, Result, 'text', TextColor, T.FontSize);
    Text.Margins.Rect := RectF(0, 0, 0, 3);
    if ARole = rsrTab then
      if T.TabBold then Text.TextSettings.Font.Style := [TFontStyle.fsBold];
    if ARole = rsrMenuItem then Text.TextSettings.HorzAlign := TTextAlign.Leading;
    Focus := AddRectangle(Result, Result, 'focus', TAlphaColor(0),
      FocusColor, T.ButtonCornerRadius, T.FocusThickness);
    Focus.Fill.Kind := TBrushKind.None;
    Focus.Margins.Rect := RectF(3, 3, 3, 3);
    Focus.Stroke.Dash := TStrokeDash.Dash;
    AddBooleanState(Focus, 'IsFocused');
    AddMetadata(Result, TextColor, T.DisabledText, T);
  except
    Result.Free;
    raise;
  end;
end;

function CreateCheckStyle(ARole: TRibbonStyleRole;
  const T: TRibbonThemeTokens): TLayout;
var
  Leading, Indicator: TLayout;
  Hover, Pressed, Disabled, Focus, Box, CheckedBox: TRectangle;
  Circle, CheckedCircle, Dot: TEllipse;
  CheckPath: TPath;
  Mark: TControl;
  Text: TText;
  procedure ConfigureCircle(ACircle: TEllipse; const AName: string;
    AFill: TAlphaColor);
  begin
    ACircle.Parent := Indicator;
    ACircle.StyleName := AName;
    ACircle.Align := TAlignLayout.Contents;
    ACircle.HitTest := False;
    ACircle.Fill.Color := AFill;
    ACircle.Stroke.Color := T.Focus;
    ACircle.Stroke.Thickness := Max(1, T.BorderThickness);
  end;
begin
  Result := TLayout.Create(nil);
  try
    Result.StyleName := RibbonThemeStyleName(ARole);
    Result.SetBounds(0, 0, 144, 36);
    Result.HitTest := False;
    Result.Padding.Rect := RectF(T.PaddingX, T.PaddingY, T.PaddingX, T.PaddingY);
    AddRectangle(Result, Result, 'background', T.GroupSurface, T.Border,
      T.ButtonCornerRadius, 0);
    Hover := AddRectangle(Result, Result, 'hoverbackground', T.HoverSurface,
      T.Border, T.ButtonCornerRadius, 0);
    AddBooleanState(Hover, 'IsMouseOver');
    Pressed := AddRectangle(Result, Result, 'pressedbackground', T.PressedSurface,
      T.Border, T.ButtonCornerRadius, 0);
    AddBooleanState(Pressed, 'IsPressed');
    Disabled := AddRectangle(Result, Result, RibbonThemeDisabledPart,
      T.DisabledSurface, T.Border, T.ButtonCornerRadius, 0);
    Disabled.Opacity := 0;
    Leading := TLayout.Create(Result);
    Leading.Parent := Result;
    Leading.StyleName := 'indicatorarea';
    Leading.Align := TAlignLayout.Left;
    Leading.Width := T.SmallIconSize + 8;
    Leading.HitTest := False;
    Indicator := TLayout.Create(Leading);
    Indicator.Parent := Leading;
    Indicator.StyleName := 'indicator';
    Indicator.Align := TAlignLayout.Center;
    Indicator.SetBounds(0, 0, T.SmallIconSize, T.SmallIconSize);
    Indicator.HitTest := False;
    if ARole = rsrCheckBox then
    begin
      Box := AddRectangle(Indicator, Indicator, 'checkbox', T.GroupSurface,
        T.Focus, Min(3, T.ButtonCornerRadius), Max(1, T.BorderThickness));
      CheckedBox := AddRectangle(Indicator, Indicator, 'checkedbackground',
        T.CheckedSurface, T.Focus, Box.XRadius, Max(1, T.BorderThickness));
      AddBooleanState(CheckedBox, 'IsChecked');
      CheckPath := TPath.Create(Indicator);
      CheckPath.Parent := Indicator;
      CheckPath.Align := TAlignLayout.Contents;
      CheckPath.Margins.Rect := RectF(3, 3, 3, 3);
      CheckPath.HitTest := False;
      CheckPath.Fill.Kind := TBrushKind.None;
      CheckPath.Stroke.Color := T.Accent;
      CheckPath.Stroke.Thickness := T.FocusThickness;
      CheckPath.WrapMode := TPathWrapMode.Fit;
      { Original geometric check; no copied font glyph, image or asset. }
      CheckPath.Data.Data := 'M 1,6 L 5,10 L 12,1';
      Mark := CheckPath;
    end
    else
    begin
      Circle := TEllipse.Create(Indicator);
      ConfigureCircle(Circle, 'radiobutton', T.GroupSurface);
      CheckedCircle := TEllipse.Create(Indicator);
      ConfigureCircle(CheckedCircle, 'checkedbackground', T.CheckedSurface);
      AddBooleanState(CheckedCircle, 'IsChecked');
      Dot := TEllipse.Create(Indicator);
      ConfigureCircle(Dot, 'checkmark', T.Accent);
      Dot.Stroke.Kind := TBrushKind.None;
      Dot.Margins.Rect := RectF(T.SmallIconSize * 0.28, T.SmallIconSize * 0.28,
        T.SmallIconSize * 0.28, T.SmallIconSize * 0.28);
      Mark := Dot;
    end;
    Mark.StyleName := 'checkmark';
    AddBooleanState(Mark, 'IsChecked');
    Text := AddText(Result, Result, 'text', T.Text, T.FontSize);
    Text.TextSettings.HorzAlign := TTextAlign.Leading;
    Focus := AddRectangle(Result, Result, 'focus', TAlphaColor(0), T.Focus,
      T.ButtonCornerRadius, T.FocusThickness);
    Focus.Fill.Kind := TBrushKind.None;
    Focus.Margins.Rect := RectF(2, 2, 2, 2);
    Focus.Stroke.Dash := TStrokeDash.Dash;
    AddBooleanState(Focus, 'IsFocused');
    { The indicator stays above the disabled surface: a disabled checked
      value is still represented by its check/dot rather than color alone. }
    AddMetadata(Result, T.Text, T.DisabledText, T);
  except
    Result.Free;
    raise;
  end;
end;

function CreateSurfaceStyle(ARole: TRibbonStyleRole;
  const T: TRibbonThemeTokens): TLayout;
var
  Part: TRectangle;
begin
  Result := TLayout.Create(nil);
  try
    Result.StyleName := RibbonThemeStyleName(ARole);
    Result.HitTest := False;
    case ARole of
      rsrPopup:
        begin
          Result.SetBounds(0, 0, 240, 260);
          Result.Padding.Rect := RectF(T.GroupPadding, T.GroupPadding,
            T.GroupPadding, T.GroupPadding);
          AddRectangle(Result, Result, 'background', T.GroupSurface,
            T.Border, T.GroupCornerRadius, T.BorderThickness);
        end;
      rsrSeparator:
        begin
          Result.SetBounds(0, 0, 12, 96);
          Part := AddRectangle(Result, Result, 'background', T.Separator,
            T.Separator, 0, 0);
          { The retained separator view supplies its orientation and extent.
            Fill that actual bound so compact rows do not retain a 72-unit
            template line outside their 24-unit viewport. }
          Part.Align := TAlignLayout.Contents;
        end;
      rsrLabel:
        begin
          Result.SetBounds(0, 0, 112, 28);
          AddText(Result, Result, 'text', T.Text, T.FontSize);
        end;
    end;
    AddMetadata(Result, T.Text, T.DisabledText, T);
  except
    Result.Free;
    raise;
  end;
end;

function CreateRibbonThemeStyle(ARole: TRibbonStyleRole;
  const ATokens: TRibbonThemeTokens): TFmxObject;
begin
  ValidateRibbonThemeTokens(ATokens);
  case ARole of
    rsrRoot: Result := CreateRootStyle(ATokens);
    rsrGroup: Result := CreateGroupStyle(ATokens);
    rsrTab, rsrLargeButton, rsrSmallButton, rsrIconButton, rsrSplitButton,
    rsrQuickAccess, rsrApplicationButton, rsrCollapsedGroup, rsrMenuItem,
    rsrGalleryItem: Result := CreateButtonStyle(ARole, ATokens);
    rsrCheckBox, rsrRadioButton: Result := CreateCheckStyle(ARole, ATokens);
    rsrPopup, rsrSeparator, rsrLabel: Result := CreateSurfaceStyle(ARole, ATokens);
  else
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon style role.');
  end;
end;

function CreateRibbonThemeStyle(ARole: TRibbonStyleRole;
  ATheme: TRibbonTheme): TFmxObject;
begin
  Result := CreateRibbonThemeStyle(ARole, RibbonThemeTokens(ATheme));
end;

function CreateRibbonThemeStyleBook(AOwner: TComponent;
  const ATokens: TRibbonThemeTokens): TStyleBook;
var
  Container: TLayout;
  Template: TFmxObject;
  Role: TRibbonStyleRole;
  Stream: TMemoryStream;
begin
  ValidateRibbonThemeTokens(ATokens);
  Result := nil;
  Container := TLayout.Create(nil);
  try
    Container.StyleName := 'camartthemebookv1';
    for Role := Low(TRibbonStyleRole) to High(TRibbonStyleRole) do
    begin
      Template := CreateRibbonThemeStyle(Role, ATokens);
      try
        Template.Parent := Container;
      except
        Template.Free;
        raise;
      end;
    end;
    Stream := TMemoryStream.Create;
    try
      TStyleStreaming.SaveToStream(Container, Stream);
      Stream.Position := 0;
      Result := TStyleBook.Create(AOwner);
      try
        Result.LoadFromStream(Stream);
      except
        FreeAndNil(Result);
        raise;
      end;
    finally
      Stream.Free;
    end;
  finally
    Container.Free;
  end;
end;

function CreateRibbonThemeStyleBook(AOwner: TComponent;
  ATheme: TRibbonTheme): TStyleBook;
begin
  Result := CreateRibbonThemeStyleBook(AOwner, RibbonThemeTokens(ATheme));
end;

end.
