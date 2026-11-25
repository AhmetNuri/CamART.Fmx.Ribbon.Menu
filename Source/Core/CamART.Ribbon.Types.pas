unit CamART.Ribbon.Types;

interface

uses
  System.Classes,
  System.Types;

type
  TRibbonChangeKind = (rckStructure, rckMeasure, rckPaint, rckState);
  TRibbonChanges = set of TRibbonChangeKind;
  TRibbonModelChangedEvent = procedure(Sender: TObject;
    const Changes: TRibbonChanges) of object;

  // Presentation size and activation behaviour are independent dimensions.
  TRibbonButtonStyle = (rbsLarge, rbsSmall, rbsIcon);
  TRibbonButtonKind = (rbkPush, rbkToggle, rbkCheck, rbkDropDown, rbkSplit,
    rbkGallery);
  TRibbonQATPosition = (rqpAbove, rqpBelow);
  TRibbonGroupPresentation = (rgpExpanded, rgpCompact, rgpCollapsed);
  TRibbonLayoutMode = (rlmGroups, rlmCompactMenu);
  TRibbonInputDensity = (ridPointer, ridTouch);

  TRibbonTabState = record
    Id: string;
    Visible: Boolean;
    Enabled: Boolean;
  end;

  TRibbonItemMeasure = record
    Id: string;
    Width: Single;
    Height: Single;
    Style: TRibbonButtonStyle;
    { A presenter supplies a separately measured alternative. Unmeasured
      compact values are ignored when CanCompact is False. }
    CanCompact: Boolean;
    CompactWidth: Single;
    CompactHeight: Single;
    CompactStyle: TRibbonButtonStyle;
    { Decorative items (separators) take the real height of the row they sit
      in instead of imposing their own measured height on the layout. }
    FillRow: Boolean;
  end;

  TRibbonGroupMeasure = record
    Id: string;
    CaptionWidth: Single;
    CaptionHeight: Single;
    MinWidth: Single;
    PreferredWidth: Single;
    Pinned: Boolean;
    AllowCompact: Boolean;
    AllowCollapse: Boolean;
    FocusLocked: Boolean;
    CollapsePriority: Integer;
    { Measured launcher dimensions, already in logical coordinates. }
    CollapsedWidth: Single;
    CollapsedHeight: Single;
    Items: TArray<TRibbonItemMeasure>;
  end;

  TRibbonLayoutMetrics = record
    Padding: Single;
    ItemGap: Single;
    GroupGap: Single;
    CaptionHeight: Single;
    { Free space between the item area and the caption band. }
    CaptionGap: Single;
    ContentHeight: Single;
    MinimumItemWidth: Single;
    MinimumItemHeight: Single;
    CompactMenuWidth: Single;
    CompactMenuHeight: Single;
    class function Default: TRibbonLayoutMetrics; static;
  end;

  TRibbonItemPlacement = record
    Id: string;
    // Relative to the containing group's origin.
    Bounds: TRectF;
    Style: TRibbonButtonStyle;
  end;

  TRibbonGroupPlacement = record
    Id: string;
    // Bounds are in scroll-content coordinates. CaptionBounds are local.
    Bounds: TRectF;
    CaptionBounds: TRectF;
    Presentation: TRibbonGroupPresentation;
    Items: TArray<TRibbonItemPlacement>;
  end;

  TRibbonLayoutResult = record
    Mode: TRibbonLayoutMode;
    CompactMenuBounds: TRectF;
    Groups: TArray<TRibbonGroupPlacement>;
    ContentWidth: Single;
    ContentHeight: Single;
    RequiresHorizontalScroll: Boolean;
  end;

const
  { Default size floors. TRibbonMetrics starts from these values, so a Ribbon
    that never touches Metrics measures exactly as earlier releases did. }
  RibbonDefaultTabMinHeight = 34;
  RibbonDefaultLargeButtonMinHeight = 64;
  RibbonDefaultSmallButtonMinHeight = 28;
  RibbonDefaultSeparatorMinHeight = 24;
  RibbonDefaultContentMinHeight = 92;
  RibbonDefaultGroupPadding = 6;
  RibbonDefaultItemGap = 4;
  RibbonDefaultGroupGap = 6;
  RibbonDefaultCaptionHeight = 20;
  RibbonDefaultCaptionGap = 2;
  { Touch accessibility floor; deliberately not configurable. }
  RibbonTouchTargetSize = 44;

type
  { Value snapshot of TRibbonMetrics in published-property order: TabMin,
    LargeButtonMin, SmallButtonMin, SeparatorMin, ContentMin, GroupPadding,
    ItemGap, GroupGap, CaptionHeight, CaptionGap. Used by configuration/JSON. }
  TRibbonMetricValues = array[0..9] of Single;

  { Central, streamable size policy of one Ribbon (logical FMX units). Views,
    presenters and the layout read these values; nothing else hard-codes a
    size floor. Theme tokens still decide paint/padding/icon sizes; these
    values only bound measurement and layout. }
  TRibbonMetrics = class(TPersistent)
  private
    FValues: TRibbonMetricValues;
    FOnChange: TNotifyEvent;
    function GetValue(const AIndex: Integer): Single;
    procedure SetValue(const AIndex: Integer; const AValue: Single);
    function IsValueStored(const AIndex: Integer): Boolean;
    class function DefaultValue(AIndex: Integer): Single; static;
  protected
    procedure Changed; virtual;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
    procedure ResetToDefaults;
    function IsDefault: Boolean;
    function GetValues: TRibbonMetricValues;
    { Validates all values first, then assigns them with one notification. }
    procedure SetValues(const AValues: TRibbonMetricValues);
    class function Defaults: TRibbonMetricValues; static;
    class function IsValidValue(const AValue: Single): Boolean; static;
    { Raises EArgumentOutOfRangeException for a nonfinite/negative value. }
    class procedure ValidateValues(const AValues: TRibbonMetricValues); static;
    { Pointer density uses SmallButtonMinHeight; touch keeps its 44 floor. }
    function MinimumTarget(ADensity: TRibbonInputDensity): Single;
    { Base metrics for a layout engine; presenters add style/density floors. }
    function ToLayoutMetrics: TRibbonLayoutMetrics;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property TabMinHeight: Single index 0 read GetValue write SetValue
      stored IsValueStored;
    property LargeButtonMinHeight: Single index 1 read GetValue write SetValue
      stored IsValueStored;
    property SmallButtonMinHeight: Single index 2 read GetValue write SetValue
      stored IsValueStored;
    { Separators follow their row; this is only their own minimum. }
    property SeparatorMinHeight: Single index 3 read GetValue write SetValue
      stored IsValueStored;
    { Item area floor. Zero lets the tallest measured item decide. }
    property ContentMinHeight: Single index 4 read GetValue write SetValue
      stored IsValueStored;
    property GroupPadding: Single index 5 read GetValue write SetValue
      stored IsValueStored;
    property ItemGap: Single index 6 read GetValue write SetValue
      stored IsValueStored;
    property GroupGap: Single index 7 read GetValue write SetValue
      stored IsValueStored;
    property CaptionHeight: Single index 8 read GetValue write SetValue
      stored IsValueStored;
    property CaptionGap: Single index 9 read GetValue write SetValue
      stored IsValueStored;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

{ TRibbonMetrics }

class function TRibbonMetrics.DefaultValue(AIndex: Integer): Single;
begin
  case AIndex of
    0: Result := RibbonDefaultTabMinHeight;
    1: Result := RibbonDefaultLargeButtonMinHeight;
    2: Result := RibbonDefaultSmallButtonMinHeight;
    3: Result := RibbonDefaultSeparatorMinHeight;
    4: Result := RibbonDefaultContentMinHeight;
    5: Result := RibbonDefaultGroupPadding;
    6: Result := RibbonDefaultItemGap;
    7: Result := RibbonDefaultGroupGap;
    8: Result := RibbonDefaultCaptionHeight;
    9: Result := RibbonDefaultCaptionGap;
  else
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon metric index.');
  end;
end;

constructor TRibbonMetrics.Create;
begin
  inherited Create;
  ResetToDefaults;
end;

procedure TRibbonMetrics.ResetToDefaults;
var
  I: Integer;
begin
  for I := Low(FValues) to High(FValues) do FValues[I] := DefaultValue(I);
  Changed;
end;

function TRibbonMetrics.GetValue(const AIndex: Integer): Single;
begin
  Result := FValues[AIndex];
end;

class function TRibbonMetrics.IsValidValue(const AValue: Single): Boolean;
begin
  Result := not IsNan(AValue) and not IsInfinite(AValue) and (AValue >= 0);
end;

class procedure TRibbonMetrics.ValidateValues(const AValues: TRibbonMetricValues);
var
  I: Integer;
begin
  for I := Low(AValues) to High(AValues) do
    if not IsValidValue(AValues[I]) then
      raise EArgumentOutOfRangeException.Create(
        'Ribbon metrics must be finite and nonnegative.');
end;

class function TRibbonMetrics.Defaults: TRibbonMetricValues;
var
  I: Integer;
begin
  for I := Low(Result) to High(Result) do Result[I] := DefaultValue(I);
end;

function TRibbonMetrics.GetValues: TRibbonMetricValues;
begin
  Result := FValues;
end;

procedure TRibbonMetrics.SetValues(const AValues: TRibbonMetricValues);
var
  I: Integer;
  Same: Boolean;
begin
  ValidateValues(AValues);
  Same := True;
  for I := Low(AValues) to High(AValues) do
    if FValues[I] <> AValues[I] then Same := False;
  if Same then Exit;
  FValues := AValues;
  Changed;
end;

procedure TRibbonMetrics.SetValue(const AIndex: Integer; const AValue: Single);
begin
  if not IsValidValue(AValue) then
    raise EArgumentOutOfRangeException.Create(
      'Ribbon metrics must be finite and nonnegative.');
  if FValues[AIndex] = AValue then Exit;
  FValues[AIndex] := AValue;
  Changed;
end;

function TRibbonMetrics.IsValueStored(const AIndex: Integer): Boolean;
begin
  Result := FValues[AIndex] <> DefaultValue(AIndex);
end;

function TRibbonMetrics.IsDefault: Boolean;
var
  I: Integer;
begin
  for I := Low(FValues) to High(FValues) do
    if IsValueStored(I) then Exit(False);
  Result := True;
end;

procedure TRibbonMetrics.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TRibbonMetrics.Assign(Source: TPersistent);
begin
  if Source is TRibbonMetrics then
  begin
    FValues := TRibbonMetrics(Source).FValues;
    Changed;
  end
  else
    inherited;
end;

function TRibbonMetrics.MinimumTarget(ADensity: TRibbonInputDensity): Single;
begin
  if ADensity = ridTouch then Result := RibbonTouchTargetSize
  else Result := SmallButtonMinHeight;
end;

function TRibbonMetrics.ToLayoutMetrics: TRibbonLayoutMetrics;
begin
  Result := TRibbonLayoutMetrics.Default;
  Result.Padding := GroupPadding;
  Result.ItemGap := ItemGap;
  Result.GroupGap := GroupGap;
  Result.CaptionHeight := CaptionHeight;
  Result.CaptionGap := CaptionGap;
  { Engines require a positive nominal height; measured items raise it. }
  Result.ContentHeight := Max(1, ContentMinHeight);
  Result.MinimumItemHeight := SmallButtonMinHeight;
end;

class function TRibbonLayoutMetrics.Default: TRibbonLayoutMetrics;
begin
  Result.Padding := 6;
  Result.ItemGap := 4;
  Result.GroupGap := 6;
  Result.CaptionHeight := 20;
  Result.CaptionGap := 2;
  Result.ContentHeight := 90;
  Result.MinimumItemWidth := 28;
  Result.MinimumItemHeight := 28;
  { FMX composition overrides this with the actual styled menu measurement. }
  Result.CompactMenuWidth := 96;
  Result.CompactMenuHeight := 32;
end;

end.
