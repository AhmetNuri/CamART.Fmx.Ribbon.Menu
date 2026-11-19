unit CamART.Ribbon.Layout;

{$B-}

interface

uses
  CamART.Ribbon.Types;

type
  IRibbonLayoutEngine = interface
    ['{0BC9EF90-63B6-4DF1-B5D1-D8E4DB19F9A7}']
    function Calculate(const AGroups: TArray<TRibbonGroupMeasure>;
      const AAvailableWidth: Single;
      const AMetrics: TRibbonLayoutMetrics): TRibbonLayoutResult;
  end;

  { Retained measured-column engine. It deliberately ignores Stage 4
    alternatives/preferences and remains useful for full group popup layout. }
  TRibbonBasicLayoutEngine = class(TInterfacedObject, IRibbonLayoutEngine)
  public
    function Calculate(const AGroups: TArray<TRibbonGroupMeasure>;
      const AAvailableWidth: Single;
      const AMetrics: TRibbonLayoutMetrics): TRibbonLayoutResult;
  end;

  { Pure, deterministic layout policy. Input widths/heights and all output
    rectangles are logical coordinates; no platform/DPI guess is made here. }
  TRibbonAdaptiveLayoutEngine = class(TInterfacedObject, IRibbonLayoutEngine)
  public
    function Calculate(const AGroups: TArray<TRibbonGroupMeasure>;
      const AAvailableWidth: Single;
      const AMetrics: TRibbonLayoutMetrics): TRibbonLayoutResult;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults;

procedure RequireFiniteNonNegative(const AValue: Single; const AName: string);
begin
  if IsNan(AValue) or IsInfinite(AValue) or (AValue < 0) then
    raise EArgumentOutOfRangeException.CreateFmt(
      '%s must be finite and nonnegative', [AName]);
end;

procedure RequireFinitePositive(const AValue: Single; const AName: string);
begin
  RequireFiniteNonNegative(AValue, AName);
  if AValue = 0 then
    raise EArgumentOutOfRangeException.CreateFmt('%s must be positive', [AName]);
end;

function CheckedAdd(const A, B: Single; const AName: string): Single;
var
  Sum: Double;
begin
  // Calculate in Double so a Single overflow is detected before conversion.
  Sum := Double(A) + Double(B);
  if IsNan(Sum) or IsInfinite(Sum) or (Sum > MaxSingle) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Layout extent overflow: %s', [AName]);
  Result := Single(Sum);
end;

procedure ValidateInput(const AGroups: TArray<TRibbonGroupMeasure>;
  const AAvailableWidth: Single; const AMetrics: TRibbonLayoutMetrics);
var
  Ids: TDictionary<string, Byte>;
  Group: TRibbonGroupMeasure;
  Item: TRibbonItemMeasure;

  procedure CheckId(const AId: string);
  begin
    if AId = '' then
      raise EArgumentException.Create('A layout snapshot contains an empty ID');
    if Ids.ContainsKey(AId) then
      raise EArgumentException.CreateFmt('Duplicate layout node ID "%s"', [AId]);
    Ids.Add(AId, 0);
  end;

begin
  RequireFiniteNonNegative(AAvailableWidth, 'AvailableWidth');
  RequireFiniteNonNegative(AMetrics.Padding, 'Padding');
  RequireFiniteNonNegative(AMetrics.ItemGap, 'ItemGap');
  RequireFiniteNonNegative(AMetrics.GroupGap, 'GroupGap');
  RequireFiniteNonNegative(AMetrics.CaptionHeight, 'CaptionHeight');
  RequireFiniteNonNegative(AMetrics.CaptionGap, 'CaptionGap');
  RequireFinitePositive(AMetrics.ContentHeight, 'ContentHeight');

  Ids := TDictionary<string, Byte>.Create;
  try
    for Group in AGroups do
    begin
      CheckId(Group.Id);
      RequireFiniteNonNegative(Group.CaptionWidth, 'Group.CaptionWidth');
      RequireFiniteNonNegative(Group.CaptionHeight, 'Group.CaptionHeight');
      RequireFiniteNonNegative(Group.MinWidth, 'Group.MinWidth');
      RequireFiniteNonNegative(Group.PreferredWidth, 'Group.PreferredWidth');
      for Item in Group.Items do
      begin
        CheckId(Item.Id);
        RequireFinitePositive(Item.Width, 'Item.Width');
        RequireFinitePositive(Item.Height, 'Item.Height');
        if (Ord(Item.Style) < Ord(Low(TRibbonButtonStyle))) or
          (Ord(Item.Style) > Ord(High(TRibbonButtonStyle))) then
          raise EArgumentOutOfRangeException.Create('Invalid button style');
      end;
    end;
  finally
    Ids.Free;
  end;
end;

function TRibbonBasicLayoutEngine.Calculate(
  const AGroups: TArray<TRibbonGroupMeasure>;
  const AAvailableWidth: Single;
  const AMetrics: TRibbonLayoutMetrics): TRibbonLayoutResult;
var
  I, J: Integer;
  ContentHeight, CaptionHeight, GroupHeight, GroupWidth, CaptionWidth,
    HorizontalPadding: Single;
  GroupX, X, ColumnY, ColumnWidth, RightEdge, ItemBottom: Single;
  HasSmallColumn, HasAnyColumn: Boolean;
  Placement: TRibbonGroupPlacement;
  Item: TRibbonItemMeasure;

  procedure BeginNewColumn;
  begin
    if HasAnyColumn then
      X := CheckedAdd(RightEdge, AMetrics.ItemGap, 'column start');
    HasAnyColumn := True;
    ColumnY := 0;
    ColumnWidth := 0;
  end;

begin
  Result := Default(TRibbonLayoutResult);
  ValidateInput(AGroups, AAvailableWidth, AMetrics);
  if Length(AGroups) = 0 then
    Exit;

  // Measured controls are never clipped to a smaller nominal row height.
  ContentHeight := AMetrics.ContentHeight;
  CaptionHeight := AMetrics.CaptionHeight;
  for I := 0 to High(AGroups) do
  begin
    CaptionHeight := Max(CaptionHeight, AGroups[I].CaptionHeight);
    for J := 0 to High(AGroups[I].Items) do
      ContentHeight := Max(ContentHeight, AGroups[I].Items[J].Height);
  end;
  HorizontalPadding := CheckedAdd(AMetrics.Padding, AMetrics.Padding,
    'group padding');
  GroupHeight := CheckedAdd(ContentHeight, CaptionHeight,
    'group content and caption');
  GroupHeight := CheckedAdd(GroupHeight, AMetrics.CaptionGap, 'caption gap');
  GroupHeight := CheckedAdd(GroupHeight, HorizontalPadding, 'group height');

  SetLength(Result.Groups, Length(AGroups));
  GroupX := 0;
  for I := 0 to High(AGroups) do
  begin
    Placement := Default(TRibbonGroupPlacement);
    Placement.Id := AGroups[I].Id;
    SetLength(Placement.Items, Length(AGroups[I].Items));
    X := AMetrics.Padding;
    RightEdge := X;
    ColumnY := 0;
    ColumnWidth := 0;
    HasSmallColumn := False;
    HasAnyColumn := False;

    for J := 0 to High(AGroups[I].Items) do
    begin
      Item := AGroups[I].Items[J];
      Placement.Items[J].Id := Item.Id;
      Placement.Items[J].Style := Item.Style;
      if Item.Style = rbsLarge then
      begin
        BeginNewColumn;
        RightEdge := CheckedAdd(X, Item.Width, 'large item right edge');
        Placement.Items[J].Bounds := RectF(X, AMetrics.Padding, RightEdge,
          CheckedAdd(AMetrics.Padding, ContentHeight, 'large item bottom'));
        HasSmallColumn := False;
      end
      else
      begin
        if HasSmallColumn then
        begin
          ItemBottom := CheckedAdd(ColumnY, Item.Height, 'small column height');
          if ItemBottom > ContentHeight then
            HasSmallColumn := False;
        end;
        if not HasSmallColumn then
        begin
          BeginNewColumn;
          HasSmallColumn := True;
        end;
        ItemBottom := CheckedAdd(ColumnY, Item.Height, 'small item bottom');
        Placement.Items[J].Bounds := RectF(X,
          CheckedAdd(AMetrics.Padding, ColumnY, 'small item top'),
          CheckedAdd(X, Item.Width, 'small item right edge'),
          CheckedAdd(AMetrics.Padding, ItemBottom, 'small item bottom'));
        ColumnWidth := Max(ColumnWidth, Item.Width);
        RightEdge := CheckedAdd(X, ColumnWidth, 'small column right edge');
        ColumnY := CheckedAdd(ItemBottom, AMetrics.ItemGap, 'next small row');
      end;
    end;

    // Include both inset sides, the full measured caption, and user minimums.
    GroupWidth := CheckedAdd(RightEdge, AMetrics.Padding, 'group width');
    CaptionWidth := CheckedAdd(AGroups[I].CaptionWidth, HorizontalPadding,
      'caption width');
    GroupWidth := Max(GroupWidth, CaptionWidth);
    GroupWidth := Max(GroupWidth, AGroups[I].MinWidth);
    GroupWidth := Max(GroupWidth, AGroups[I].PreferredWidth);
    Placement.Bounds := RectF(GroupX, 0,
      CheckedAdd(GroupX, GroupWidth, 'group right edge'), GroupHeight);
    Placement.CaptionBounds := RectF(AMetrics.Padding,
      CheckedAdd(CheckedAdd(AMetrics.Padding, ContentHeight, 'caption top'),
        AMetrics.CaptionGap, 'caption top gap'),
      GroupWidth - AMetrics.Padding,
      GroupHeight - AMetrics.Padding);
    Result.Groups[I] := Placement;
    GroupX := Placement.Bounds.Right;
    if I < High(AGroups) then
      GroupX := CheckedAdd(GroupX, AMetrics.GroupGap, 'group spacing');
  end;

  Result.ContentWidth := GroupX;
  Result.ContentHeight := GroupHeight;
  Result.RequiresHorizontalScroll := Result.ContentWidth > AAvailableWidth;
end;

{ TRibbonAdaptiveLayoutEngine }

type
  TRibbonGroupVariants = record
    Placement: array[TRibbonGroupPresentation] of TRibbonGroupPlacement;
    Available: array[TRibbonGroupPresentation] of Boolean;
  end;

function TRibbonAdaptiveLayoutEngine.Calculate(
  const AGroups: TArray<TRibbonGroupMeasure>;
  const AAvailableWidth: Single;
  const AMetrics: TRibbonLayoutMetrics): TRibbonLayoutResult;
var
  Basic: IRibbonLayoutEngine;
  Variants: TArray<TRibbonGroupVariants>;
  Selected: TArray<TRibbonGroupPresentation>;
  ReductionOrder: TArray<Integer>;
  SharedMetrics: TRibbonLayoutMetrics;
  OneGroup: TArray<TRibbonGroupMeasure>;
  SinglePlan: TRibbonLayoutResult;
  Placement: TRibbonGroupPlacement;
  Candidate: TRibbonGroupPresentation;
  I, J, Index: Integer;
  TotalWidth: Double;
  GroupX, CandidateWidth, CurrentWidth: Single;
  CanUseCompactMenu: Boolean;

  function IsProtected(const AIndex: Integer): Boolean;
  begin
    Result := AGroups[AIndex].Pinned or AGroups[AIndex].FocusLocked;
  end;

  function GroupWidth(const AIndex: Integer;
    const AMode: TRibbonGroupPresentation): Single;
  begin
    Result := Variants[AIndex].Placement[AMode].Bounds.Width;
  end;

  procedure MeasureInlineVariant(const AIndex: Integer;
    const AMode: TRibbonGroupPresentation);
  var
    K: Integer;
  begin
    OneGroup[0] := AGroups[AIndex];
    { Records contain dynamic arrays: copy the nested array before replacing
      alternative sizes. The caller's snapshot must remain immutable. }
    OneGroup[0].Items := Copy(AGroups[AIndex].Items);
    if AMode = rgpCompact then
    begin
      OneGroup[0].PreferredWidth := 0;
      for K := 0 to High(OneGroup[0].Items) do
        if OneGroup[0].Items[K].CanCompact then
        begin
          OneGroup[0].Items[K].Width := OneGroup[0].Items[K].CompactWidth;
          OneGroup[0].Items[K].Height := OneGroup[0].Items[K].CompactHeight;
          OneGroup[0].Items[K].Style := OneGroup[0].Items[K].CompactStyle;
        end;
    end;
    SinglePlan := Basic.Calculate(OneGroup, AAvailableWidth, SharedMetrics);
    Variants[AIndex].Placement[AMode] := SinglePlan.Groups[0];
    Variants[AIndex].Placement[AMode].Presentation := AMode;
    Variants[AIndex].Available[AMode] := True;
  end;

begin
  Result := Default(TRibbonLayoutResult);
  ValidateInput(AGroups, AAvailableWidth, AMetrics);
  RequireFiniteNonNegative(AMetrics.MinimumItemWidth, 'MinimumItemWidth');
  RequireFiniteNonNegative(AMetrics.MinimumItemHeight, 'MinimumItemHeight');
  RequireFiniteNonNegative(AMetrics.CompactMenuWidth, 'CompactMenuWidth');
  RequireFiniteNonNegative(AMetrics.CompactMenuHeight, 'CompactMenuHeight');
  if Length(AGroups) = 0 then Exit;

  { Keep one measured row capacity across candidates. A decision cannot alter
    another group's measurement and feed a different decision back into itself.
    Native presenters apply pointer/touch minima to interactive measurements;
    the engine never turns a thin separator into an interaction target. }
  SharedMetrics := AMetrics;
  for I := 0 to High(AGroups) do
  begin
    SharedMetrics.CaptionHeight := Max(SharedMetrics.CaptionHeight,
      AGroups[I].CaptionHeight);
    for J := 0 to High(AGroups[I].Items) do
    begin
      SharedMetrics.ContentHeight := Max(SharedMetrics.ContentHeight,
        AGroups[I].Items[J].Height);
      if AGroups[I].AllowCompact and not IsProtected(I) and
         AGroups[I].Items[J].CanCompact then
      begin
        RequireFinitePositive(AGroups[I].Items[J].CompactWidth,
          'Item.CompactWidth');
        RequireFinitePositive(AGroups[I].Items[J].CompactHeight,
          'Item.CompactHeight');
        if (Ord(AGroups[I].Items[J].CompactStyle) < Ord(Low(TRibbonButtonStyle))) or
           (Ord(AGroups[I].Items[J].CompactStyle) > Ord(High(TRibbonButtonStyle))) then
          raise EArgumentOutOfRangeException.Create('Invalid compact button style');
        SharedMetrics.ContentHeight := Max(SharedMetrics.ContentHeight,
          AGroups[I].Items[J].CompactHeight);
      end;
    end;
    if AGroups[I].AllowCollapse and not IsProtected(I) then
    begin
      RequireFinitePositive(AGroups[I].CollapsedWidth, 'Group.CollapsedWidth');
      RequireFinitePositive(AGroups[I].CollapsedHeight, 'Group.CollapsedHeight');
    end;
  end;

  Basic := TRibbonBasicLayoutEngine.Create;
  SetLength(OneGroup, 1);
  SetLength(Variants, Length(AGroups));
  SetLength(Selected, Length(AGroups));
  SetLength(ReductionOrder, Length(AGroups));
  TotalWidth := 0;
  CanUseCompactMenu := True;
  for I := 0 to High(AGroups) do
  begin
    Selected[I] := rgpExpanded;
    ReductionOrder[I] := I;
    MeasureInlineVariant(I, rgpExpanded);
    TotalWidth := TotalWidth + Double(GroupWidth(I, rgpExpanded));
    if I > 0 then TotalWidth := TotalWidth + Double(AMetrics.GroupGap);
    if AGroups[I].AllowCompact and not IsProtected(I) then
      MeasureInlineVariant(I, rgpCompact);
    if AGroups[I].AllowCollapse and not IsProtected(I) then
    begin
      Placement := Default(TRibbonGroupPlacement);
      Placement.Id := AGroups[I].Id;
      Placement.Presentation := rgpCollapsed;
      Placement.Bounds := RectF(0, 0,
        Max(AGroups[I].CollapsedWidth, AMetrics.MinimumItemWidth),
        Max(Max(AGroups[I].CollapsedHeight, AMetrics.MinimumItemHeight),
          Variants[I].Placement[rgpExpanded].Bounds.Height));
      Variants[I].Placement[rgpCollapsed] := Placement;
      Variants[I].Available[rgpCollapsed] := True;
    end
    else
      CanUseCompactMenu := False;
  end;

  { Every comparison has a total order: lower priority reduces first, and
    rightmost input order breaks ties. Id text, hash iteration and prior
    viewport history never influence the plan. Avoid integer subtraction:
    user priorities may include Low(Integer) and High(Integer). }
  TArray.Sort<Integer>(ReductionOrder, TComparer<Integer>.Construct(
    function(const Left, Right: Integer): Integer
    begin
      if AGroups[Left].CollapsePriority < AGroups[Right].CollapsePriority then
        Exit(-1);
      if AGroups[Left].CollapsePriority > AGroups[Right].CollapsePriority then
        Exit(1);
      if Left > Right then Exit(-1);
      if Left < Right then Exit(1);
      Result := 0;
    end));

  { Compact all useful candidates before sending any group into a popup.
    A wider/equal alternative is never selected merely because it is named
    compact: full caption/font measurements may make it less space-efficient. }
  for Candidate := rgpCompact to rgpCollapsed do
  begin
    if TotalWidth <= Double(AAvailableWidth) then Break;
    for Index in ReductionOrder do
    begin
      if TotalWidth <= Double(AAvailableWidth) then Break;
      if not Variants[Index].Available[Candidate] then Continue;
      CandidateWidth := GroupWidth(Index, Candidate);
      CurrentWidth := GroupWidth(Index, Selected[Index]);
      if CandidateWidth >= CurrentWidth then Continue;
      TotalWidth := TotalWidth - Double(CurrentWidth) + Double(CandidateWidth);
      Selected[Index] := Candidate;
    end;
  end;

  if (TotalWidth > Double(AAvailableWidth)) and CanUseCompactMenu then
  begin
    RequireFinitePositive(AMetrics.CompactMenuWidth, 'CompactMenuWidth');
    RequireFinitePositive(AMetrics.CompactMenuHeight, 'CompactMenuHeight');
    CandidateWidth := Max(AMetrics.CompactMenuWidth, AMetrics.MinimumItemWidth);
    { A global menu is an alternative too. Do not replace one already narrow
      group with a wider launcher merely because the viewport is tiny. }
    if Double(CandidateWidth) < TotalWidth then
    begin
      Result.Mode := rlmCompactMenu;
      Result.CompactMenuBounds := RectF(0, 0, CandidateWidth,
        Max(AMetrics.CompactMenuHeight, AMetrics.MinimumItemHeight));
      Result.ContentWidth := Result.CompactMenuBounds.Width;
      Result.ContentHeight := Result.CompactMenuBounds.Height;
      Result.RequiresHorizontalScroll := Result.ContentWidth > AAvailableWidth;
      SetLength(Result.Groups, Length(AGroups));
      for I := 0 to High(AGroups) do
      begin
        { Ids describe the groups exposed by the compact launcher. They have
          no inline bounds/items in this mode; popup presentation is separate. }
        Result.Groups[I].Id := AGroups[I].Id;
        Result.Groups[I].Presentation := rgpCollapsed;
      end;
      Exit;
    end;
  end;

  Result.Mode := rlmGroups;
  SetLength(Result.Groups, Length(AGroups));
  GroupX := 0;
  for I := 0 to High(AGroups) do
  begin
    Placement := Variants[I].Placement[Selected[I]];
    CandidateWidth := Placement.Bounds.Width;
    Placement.Bounds := RectF(GroupX, 0,
      CheckedAdd(GroupX, CandidateWidth, 'adaptive group right edge'),
      Placement.Bounds.Height);
    Result.Groups[I] := Placement;
    Result.ContentHeight := Max(Result.ContentHeight, Placement.Bounds.Height);
    GroupX := Placement.Bounds.Right;
    if I < High(AGroups) then
      GroupX := CheckedAdd(GroupX, AMetrics.GroupGap, 'adaptive group spacing');
  end;
  Result.ContentWidth := GroupX;
  { Locked/pinned/forbidden modes remain visible through horizontal scrolling.
    Even a measured compact launcher may itself exceed a zero/narrow viewport. }
  Result.RequiresHorizontalScroll := Result.ContentWidth > AAvailableWidth;
end;

end.
