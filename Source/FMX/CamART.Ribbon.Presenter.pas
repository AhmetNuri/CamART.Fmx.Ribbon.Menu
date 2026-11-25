unit CamART.Ribbon.Presenter;

{$B-}

interface

uses
  System.Classes, System.SysUtils, System.Types, System.Generics.Collections,
  FMX.Controls, CamART.Ribbon.Types, CamART.Ribbon.Views,
  CamART.Ribbon.ViewData, CamART.Ribbon.ItemViews,
  CamART.Ribbon.ViewFactory, CamART.Ribbon.Icons;

type
  ERibbonPresentationError = class(Exception);

  { Stage 2 source-compatible names; new integrations can use ViewData. }
  TRibbonViewClickEvent = CamART.Ribbon.ViewData.TRibbonViewClickEvent;
  TRibbonTabViewData = CamART.Ribbon.ViewData.TRibbonTabViewData;
  TRibbonItemViewData = CamART.Ribbon.ViewData.TRibbonItemViewData;
  TRibbonGroupViewData = CamART.Ribbon.ViewData.TRibbonGroupViewData;
  TRibbonItemInput = CamART.Ribbon.ViewData.TRibbonItemInput;
  TRibbonItemInputEvent = CamART.Ribbon.ViewData.TRibbonItemInputEvent;

  TRibbonPresenter = class(TComponent)
  private
    FTabHost, FContentHost: TControl;
    FTabs: TArray<TRibbonTabViewData>;
    FGroups: TArray<TRibbonGroupViewData>;
    FTabViews: TDictionary<string, TRibbonTabButton>;
    FGroupViews: TDictionary<string, TRibbonGroupView>;
    FGroupLaunchers: TDictionary<string, TRibbonGroupLauncher>;
    FItemViews: TDictionary<string, TRibbonItemView>;
    FViewFactory: TRibbonViewFactory;
    FOwnsFactory: Boolean;
    FInputDensity: TRibbonInputDensity;
    FMeasuredGroups: TArray<TRibbonGroupMeasure>;
    FMeasurementKeys: TArray<string>;
    FMeasurementsValid: Boolean;
    FMeasuredScale: Single;
    FMeasuredIconRevision: UInt64;
    FMeasurementPassCount, FMeasurementCacheHitCount: Integer;
    FOnGroupPopup: TRibbonViewClickEvent;
    FOnTabClick, FOnButtonClick: TRibbonViewClickEvent;
    FOnInput: TRibbonItemInputEvent;
    FShuttingDown: Boolean;
    FSyncing: Integer;
    FLayoutRevision: UInt64;
    procedure TabClicked(Sender: TObject);
    procedure GroupClicked(Sender: TObject);
    procedure SetInputDensity(const AValue: TRibbonInputDensity);
    function BuildMeasurementKeys: TArray<string>;
    procedure RefreshFocusLocks(var AMeasures: TArray<TRibbonGroupMeasure>);
    procedure ItemInput(Sender: TObject; const AInput: TRibbonItemInput);
    procedure ValidateSnapshots(const ATabs: TArray<TRibbonTabViewData>;
      const AGroups: TArray<TRibbonGroupViewData>);
    function GetTabViewCount: Integer;
    function GetGroupViewCount: Integer;
    function GetButtonViewCount: Integer;
    function GetItemViewCount: Integer;
    function GetIconProvider: IRibbonIconProvider;
    procedure SetIconProvider(const AValue: IRibbonIconProvider);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent; ATabHost, AContentHost: TControl;
      AFactory: TRibbonViewFactory = nil); reintroduce;
    destructor Destroy; override;
    procedure Clear;
    procedure Sync(const ATabs: TArray<TRibbonTabViewData>;
      const AGroups: TArray<TRibbonGroupViewData>);
    function MeasureGroups: TArray<TRibbonGroupMeasure>;
    procedure InvalidateMeasurements;
    function EffectiveMetrics(const ABase: TRibbonLayoutMetrics): TRibbonLayoutMetrics;
    function FirstFocusableItem(const AGroupId: string): TControl;
    function SelectedTabBounds(out ABounds: TRectF): Boolean;
    procedure ApplyLayout(const ALayout: TRibbonLayoutResult);
    function RecommendedTabHeight: Single;
    function ArrangeTabs(const AHeight: Single): Single;
    function FindTabView(const AId: string): TRibbonTabButton;
    function FindGroupView(const AId: string): TRibbonGroupView;
    function FindGroupLauncher(const AId: string): TRibbonGroupLauncher;
    function FindItemView(const AId: string): TControl;
    function FindButtonView(const AId: string): TRibbonCommandButton;
    property TabViewCount: Integer read GetTabViewCount;
    property GroupViewCount: Integer read GetGroupViewCount;
    property ButtonViewCount: Integer read GetButtonViewCount;
    property ItemViewCount: Integer read GetItemViewCount;
    property ViewFactory: TRibbonViewFactory read FViewFactory;
    property IconProvider: IRibbonIconProvider read GetIconProvider write SetIconProvider;
    property OnTabClick: TRibbonViewClickEvent read FOnTabClick write FOnTabClick;
    property OnGroupPopup: TRibbonViewClickEvent read FOnGroupPopup write FOnGroupPopup;
    property InputDensity: TRibbonInputDensity read FInputDensity write SetInputDensity;
    property MeasurementPassCount: Integer read FMeasurementPassCount;
    property MeasurementCacheHitCount: Integer read FMeasurementCacheHitCount;
    { Legacy execution route is used only when OnInput is not assigned. }
    property OnButtonClick: TRibbonViewClickEvent read FOnButtonClick write FOnButtonClick;
    property OnInput: TRibbonItemInputEvent read FOnInput write FOnInput;
  end;

implementation

uses
  System.Math, FMX.Types, CamART.Ribbon.Style, CamART.Ribbon.StyleScope,
  CamART.Ribbon.Interaction;

type
  { Owned by the calling stack, never by the presentation being observed.
    Native visibility/focus/resize handlers may destroy or resynchronize it. }
  TRibbonLayoutExecutionGuard = class(TComponent)
  private
    FPresenter: TRibbonPresenter;
    FRevision: UInt64;
    function GetCurrent: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor CreateGuard(APresenter: TRibbonPresenter);
    destructor Destroy; override;
    property Current: Boolean read GetCurrent;
  end;

constructor TRibbonLayoutExecutionGuard.CreateGuard(APresenter: TRibbonPresenter);
begin
  inherited Create(nil);
  FPresenter := APresenter;
  FRevision := APresenter.FLayoutRevision;
  FPresenter.FreeNotification(Self);
end;

destructor TRibbonLayoutExecutionGuard.Destroy;
begin
  { Unsubscribe before inherited destruction. A temporary observer going
    away is not a new presenter layout revision. }
  if FPresenter <> nil then FPresenter.RemoveFreeNotification(Self);
  inherited;
end;

procedure TRibbonLayoutExecutionGuard.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FPresenter) then FPresenter := nil;
end;

function TRibbonLayoutExecutionGuard.GetCurrent: Boolean;
begin
  Result := (FPresenter <> nil) and not FPresenter.FShuttingDown and
    (FPresenter.FLayoutRevision = FRevision);
end;

constructor TRibbonPresenter.Create(AOwner: TComponent;
  ATabHost, AContentHost: TControl; AFactory: TRibbonViewFactory);
begin
  inherited Create(AOwner);
  if (ATabHost = nil) or (AContentHost = nil) then
    raise EArgumentNilException.Create('Ribbon presentation hosts are required.');
  FTabHost := ATabHost;
  FContentHost := AContentHost;
  TComponent(FTabHost).FreeNotification(Self);
  TComponent(FContentHost).FreeNotification(Self);
  FTabViews := TDictionary<string, TRibbonTabButton>.Create;
  FGroupViews := TDictionary<string, TRibbonGroupView>.Create;
  FGroupLaunchers := TDictionary<string, TRibbonGroupLauncher>.Create;
  FItemViews := TDictionary<string, TRibbonItemView>.Create;
  FOwnsFactory := AFactory = nil;
  if FOwnsFactory then FViewFactory := TRibbonViewFactory.Create(Self)
  else
  begin
    FViewFactory := AFactory;
    FViewFactory.FreeNotification(Self);
  end;
end;

destructor TRibbonPresenter.Destroy;
begin
  FShuttingDown := True;
  FOnTabClick := nil;
  FOnButtonClick := nil;
  FOnInput := nil;
  FOnGroupPopup := nil;
  Clear;
  if FTabHost <> nil then TComponent(FTabHost).RemoveFreeNotification(Self);
  if FContentHost <> nil then TComponent(FContentHost).RemoveFreeNotification(Self);
  if FViewFactory <> nil then
    if FOwnsFactory then FreeAndNil(FViewFactory)
    else FViewFactory.RemoveFreeNotification(Self);
  FViewFactory := nil;
  FreeAndNil(FItemViews);
  FreeAndNil(FGroupLaunchers);
  FreeAndNil(FGroupViews);
  FreeAndNil(FTabViews);
  inherited;
end;

procedure TRibbonPresenter.Clear;
var
  Id: string;
  Item: TRibbonItemView;
  Group: TRibbonGroupView;
  Tab: TRibbonTabButton;
  Launcher: TRibbonGroupLauncher;
begin
  Inc(FLayoutRevision);
  Inc(FSyncing);
  try
    SetLength(FTabs, 0);
    SetLength(FGroups, 0);
    InvalidateMeasurements;
    if FItemViews <> nil then
      for Id in FItemViews.Keys.ToArray do
      begin
        Item := FItemViews[Id];
        FItemViews.Remove(Id);
        Item.OnInput := nil;
        Item.Free;
      end;
    if FGroupLaunchers <> nil then
      for Id in FGroupLaunchers.Keys.ToArray do
      begin
        Launcher := FGroupLaunchers[Id];
        FGroupLaunchers.Remove(Id);
        Launcher.OnClick := nil;
        Launcher.Free;
      end;
    if FGroupViews <> nil then
      for Id in FGroupViews.Keys.ToArray do
      begin
        Group := FGroupViews[Id];
        FGroupViews.Remove(Id);
        Group.Free;
      end;
    if FTabViews <> nil then
      for Id in FTabViews.Keys.ToArray do
      begin
        Tab := FTabViews[Id];
        FTabViews.Remove(Id);
        Tab.OnClick := nil;
        Tab.Free;
      end;
  finally
    Dec(FSyncing);
  end;
end;

procedure TRibbonPresenter.Notification(AComponent: TComponent; Operation: TOperation);
var
  Tab: TRibbonTabButton;
  Group: TRibbonGroupView;
  Item: TRibbonItemView;
  Launcher: TRibbonGroupLauncher;
begin
  if Operation = opRemove then
  begin
    Inc(FLayoutRevision);
    if AComponent = FTabHost then FTabHost := nil;
    if AComponent = FContentHost then FContentHost := nil;
    if AComponent = FViewFactory then FViewFactory := nil;
    if (AComponent is TRibbonGroupLauncher) and (FGroupLaunchers <> nil) then
      if FGroupLaunchers.TryGetValue(TRibbonGroupLauncher(AComponent).ItemId, Launcher) then
        if Launcher = AComponent then FGroupLaunchers.Remove(Launcher.ItemId);
    if (AComponent is TRibbonTabButton) and (FTabViews <> nil) then
      if FTabViews.TryGetValue(TRibbonTabButton(AComponent).ItemId, Tab) then
        if Tab = AComponent then FTabViews.Remove(Tab.ItemId);
    if (AComponent is TRibbonGroupView) and (FGroupViews <> nil) then
      if FGroupViews.TryGetValue(TRibbonGroupView(AComponent).ItemId, Group) then
        if Group = AComponent then FGroupViews.Remove(Group.ItemId);
    if (AComponent is TRibbonItemView) and (FItemViews <> nil) then
      if FItemViews.TryGetValue(TRibbonItemView(AComponent).ItemId, Item) then
        if Item = AComponent then FItemViews.Remove(Item.ItemId);
  end;
  inherited;
end;

function TRibbonPresenter.GetIconProvider: IRibbonIconProvider;
begin
  Result := nil;
  if FViewFactory <> nil then Result := FViewFactory.IconProvider;
end;

procedure TRibbonPresenter.SetIconProvider(const AValue: IRibbonIconProvider);
var
  Item: TRibbonItemView;
begin
  if FViewFactory = nil then
    raise ERibbonPresentationError.Create('The Ribbon view factory was destroyed.');
  FViewFactory.IconProvider := AValue;
  InvalidateMeasurements;
  for Item in FItemViews.Values do Item.IconProvider := AValue;
end;

procedure TRibbonPresenter.ValidateSnapshots(const ATabs: TArray<TRibbonTabViewData>;
  const AGroups: TArray<TRibbonGroupViewData>);
var
  Seen: TDictionary<string, Byte>;
  Tab: TRibbonTabViewData;
  Group: TRibbonGroupViewData;
  Item: TRibbonItemViewData;
  procedure AddId(const AId: string);
  begin
    if AId = '' then
      raise EArgumentException.Create('A Ribbon view needs a nonempty Id.');
    if Seen.ContainsKey(AId) then
      raise EArgumentException.CreateFmt('Duplicate Ribbon view Id: %s', [AId]);
    Seen.Add(AId, 0);
  end;
begin
  Seen := TDictionary<string, Byte>.Create;
  try
    for Tab in ATabs do AddId(Tab.Id);
    for Group in AGroups do
    begin
      AddId(Group.Id);
      for Item in Group.Items do
      begin
        AddId(Item.Id);
        if Item.TypeKey = '' then
          raise EArgumentException.Create('A Ribbon item needs a view TypeKey.');
      end;
    end;
  finally
    Seen.Free;
  end;
end;

function SameStrings(const A, B: TArray<string>): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
end;

function SameItemGeometry(const A, B: TRibbonItemViewData): Boolean;
var
  I: Integer;
begin
  Result := (A.Id = B.Id) and (A.TypeKey = B.TypeKey) and
    (A.Caption = B.Caption) and (A.IconKey = B.IconKey) and
    (A.Visible = B.Visible) and (A.ButtonStyle = B.ButtonStyle) and
    (A.ButtonKind = B.ButtonKind) and (A.Text = B.Text) and
    SameStrings(A.Choices, B.Choices) and
    (Length(A.GalleryEntries) = Length(B.GalleryEntries));
  if not Result then Exit;
  for I := 0 to High(A.GalleryEntries) do
    if (A.GalleryEntries[I].Id <> B.GalleryEntries[I].Id) or
       (A.GalleryEntries[I].Caption <> B.GalleryEntries[I].Caption) or
       (A.GalleryEntries[I].IconKey <> B.GalleryEntries[I].IconKey) or
       (A.GalleryEntries[I].Visible <> B.GalleryEntries[I].Visible) then
      Exit(False);
end;

function SameGroupGeometry(const A, B: TArray<TRibbonGroupViewData>): Boolean;
var
  I, J: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for I := 0 to High(A) do
  begin
    if (A[I].Id <> B[I].Id) or (A[I].Caption <> B[I].Caption) or
       (A[I].Visible <> B[I].Visible) or (A[I].MinWidth <> B[I].MinWidth) or
       (A[I].PreferredWidth <> B[I].PreferredWidth) or
       (A[I].Pinned <> B[I].Pinned) or (A[I].AllowCompact <> B[I].AllowCompact) or
       (A[I].AllowCollapse <> B[I].AllowCollapse) or
       (A[I].CollapsePriority <> B[I].CollapsePriority) or
       (Length(A[I].Items) <> Length(B[I].Items)) then Exit(False);
    for J := 0 to High(A[I].Items) do
      if not SameItemGeometry(A[I].Items[J], B[I].Items[J]) then Exit(False);
  end;
end;

function CopyMeasures(const ASource: TArray<TRibbonGroupMeasure>): TArray<TRibbonGroupMeasure>;
var
  I: Integer;
begin
  Result := Copy(ASource);
  for I := 0 to High(Result) do Result[I].Items := Copy(ASource[I].Items);
end;

procedure TRibbonPresenter.Sync(const ATabs: TArray<TRibbonTabViewData>;
  const AGroups: TArray<TRibbonGroupViewData>);
var
  WantedTabs, WantedGroups, WantedItems: TDictionary<string, Byte>;
  I, J, TabOrderIndex: Integer;
  Id: string;
  Tab: TRibbonTabButton;
  Group: TRibbonGroupView;
  Item: TRibbonItemView;
  Launcher: TRibbonGroupLauncher;
begin
  if FShuttingDown then Exit;
  if (FTabHost = nil) or (FContentHost = nil) then
    raise ERibbonPresentationError.Create('Ribbon presentation hosts were destroyed.');
  if FViewFactory = nil then
    raise ERibbonPresentationError.Create('The Ribbon view factory was destroyed.');
  ValidateSnapshots(ATabs, AGroups);
  Inc(FLayoutRevision);
  if not SameGroupGeometry(FGroups, AGroups) then InvalidateMeasurements;
  FTabs := Copy(ATabs);
  FGroups := Copy(AGroups);
  for I := 0 to High(FGroups) do
  begin
    FGroups[I].Items := Copy(AGroups[I].Items);
    for J := 0 to High(FGroups[I].Items) do
    begin
      FGroups[I].Items[J].Choices := Copy(AGroups[I].Items[J].Choices);
      FGroups[I].Items[J].GalleryEntries := Copy(AGroups[I].Items[J].GalleryEntries);
    end;
  end;
  WantedTabs := TDictionary<string, Byte>.Create;
  WantedGroups := nil;
  WantedItems := nil;
  Inc(FSyncing);
  try
    WantedGroups := TDictionary<string, Byte>.Create;
    WantedItems := TDictionary<string, Byte>.Create;
    TabOrderIndex := 0;
    for I := 0 to High(FTabs) do
    begin
      if not FTabs[I].Visible then Continue;
      WantedTabs.Add(FTabs[I].Id, 0);
      if not FTabViews.TryGetValue(FTabs[I].Id, Tab) then
      begin
        Tab := TRibbonTabButton.Create(Self);
        try
          Tab.ItemId := FTabs[I].Id;
          Tab.Parent := FTabHost;
          Tab.OnClick := TabClicked;
          FTabViews.Add(Tab.ItemId, Tab);
        except
          Tab.Free;
          raise;
        end;
      end;
      if Tab.Text <> FTabs[I].Caption then Tab.Text := FTabs[I].Caption;
      Tab.Enabled := FTabs[I].Enabled;
      Tab.Selected := FTabs[I].Selected;
      Tab.TabOrder := TabOrderIndex;
      AttachRibbonInput(Tab, FInputDensity);
      Inc(TabOrderIndex);
    end;
    { New groups exist before retained controls move. Old groups are freed
      only after their retained descendants have a safe new visual parent. }
    for I := 0 to High(FGroups) do
    begin
      if not FGroups[I].Visible then Continue;
      WantedGroups.Add(FGroups[I].Id, 0);
      if not FGroupViews.TryGetValue(FGroups[I].Id, Group) then
      begin
        Group := TRibbonGroupView.Create(Self);
        try
          Group.ItemId := FGroups[I].Id;
          Group.Parent := FContentHost;
          FGroupViews.Add(Group.ItemId, Group);
        except
          Group.Free;
          raise;
        end;
      end;
      if not FGroupLaunchers.TryGetValue(FGroups[I].Id, Launcher) then
      begin
        Launcher := TRibbonGroupLauncher.Create(Self);
        try
          Launcher.ItemId := FGroups[I].Id;
          Launcher.Parent := FContentHost;
          Launcher.Visible := False;
          Launcher.OnClick := GroupClicked;
          TComponent(Launcher).FreeNotification(Self);
          FGroupLaunchers.Add(Launcher.ItemId, Launcher);
        except
          Launcher.Free;
          raise;
        end;
      end;
      Launcher.Text := FGroups[I].Caption + ' ' + #9662;
      Launcher.Hint := FGroups[I].Caption;
      Launcher.ParentShowHint := False;
      Launcher.ShowHint := Launcher.Hint <> '';
      Launcher.Enabled := FGroups[I].Enabled;
      Launcher.TabOrder := I;
      AttachRibbonInput(Launcher, FInputDensity);
      Group.TabOrder := I;
      Group.CaptionText := FGroups[I].Caption;
      Group.Enabled := FGroups[I].Enabled;
    end;
    for I := 0 to High(FGroups) do
    begin
      if not FGroups[I].Visible then Continue;
      Group := FGroupViews[FGroups[I].Id];
      TabOrderIndex := 0;
      for J := 0 to High(FGroups[I].Items) do
      begin
        if not FGroups[I].Items[J].Visible then Continue;
        Id := FGroups[I].Items[J].Id;
        WantedItems.Add(Id, 0);
        Item := nil;
        if FItemViews.TryGetValue(Id, Item) then
          if (Item.TypeKey <> FGroups[I].Items[J].TypeKey) or (Item.Control = nil) then
          begin
            FItemViews.Remove(Id);
            Item.OnInput := nil;
            FreeAndNil(Item);
          end;
        if Item = nil then
        begin
          Item := FViewFactory.CreateView(Self, Group, FGroups[I].Items[J]);
          try
            Item.OnInput := ItemInput;
            FItemViews.Add(Id, Item);
          except
            Item.Free;
            raise;
          end;
        end
        else
        begin
          if Item.Control.Parent <> Group then Item.Control.Parent := Group;
          Item.IconProvider := FViewFactory.IconProvider;
          Item.Apply(FGroups[I].Items[J]);
        end;
        Item.InputDensity := FInputDensity;
        Item.Control.TabOrder := TabOrderIndex;
        Inc(TabOrderIndex);
      end;
    end;
    for Id in FItemViews.Keys.ToArray do
      if not WantedItems.ContainsKey(Id) then
      begin
        Item := FItemViews[Id];
        FItemViews.Remove(Id);
        Item.OnInput := nil;
        Item.Free;
      end;
    for Id in FGroupLaunchers.Keys.ToArray do
      if not WantedGroups.ContainsKey(Id) then
      begin
        Launcher := FGroupLaunchers[Id];
        FGroupLaunchers.Remove(Id);
        Launcher.OnClick := nil;
        Launcher.Free;
      end;
    for Id in FGroupViews.Keys.ToArray do
      if not WantedGroups.ContainsKey(Id) then
      begin
        Group := FGroupViews[Id];
        FGroupViews.Remove(Id);
        Group.Free;
      end;
    for Id in FTabViews.Keys.ToArray do
      if not WantedTabs.ContainsKey(Id) then
      begin
        Tab := FTabViews[Id];
        FTabViews.Remove(Id);
        Tab.OnClick := nil;
        Tab.Free;
      end;
  finally
    Dec(FSyncing);
    WantedItems.Free;
    WantedGroups.Free;
    WantedTabs.Free;
  end;
end;

procedure TRibbonPresenter.InvalidateMeasurements;
begin
  FMeasurementsValid := False;
  SetLength(FMeasuredGroups, 0);
  SetLength(FMeasurementKeys, 0);
end;

procedure TRibbonPresenter.SetInputDensity(const AValue: TRibbonInputDensity);
var
  Item: TRibbonItemView;
  Tab: TRibbonTabButton;
  Launcher: TRibbonGroupLauncher;
begin
  if (Ord(AValue) < Ord(Low(TRibbonInputDensity))) or
     (Ord(AValue) > Ord(High(TRibbonInputDensity))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon input density.');
  if FInputDensity = AValue then Exit;
  FInputDensity := AValue;
  for Item in FItemViews.Values do Item.InputDensity := AValue;
  for Tab in FTabViews.Values do AttachRibbonInput(Tab, AValue);
  for Launcher in FGroupLaunchers.Values do AttachRibbonInput(Launcher, AValue);
  InvalidateMeasurements;
end;

function TRibbonPresenter.EffectiveMetrics(
  const ABase: TRibbonLayoutMetrics): TRibbonLayoutMetrics;
var
  Metrics: TRibbonMetrics;
  Target: Single;
  Group: TRibbonGroupView;
  Inset: Single;
  Insets: TRectF;
begin
  Result := ABase;
  Metrics := FindRibbonMetrics(FContentHost);
  Target := Metrics.MinimumTarget(FInputDensity);
  { One configurable floor replaces the former 3x28 / 2x44 row rules; both
    defaults equal 92, so an untouched Ribbon keeps its historical height. }
  Result.MinimumItemWidth := Max(Result.MinimumItemWidth, Target);
  Result.MinimumItemHeight := Max(Result.MinimumItemHeight, Target);
  Result.ContentHeight := Max(Result.ContentHeight, Metrics.ContentMinHeight);
  { Use style-owned insets as measured input, preserving the caller's base.
    Logical FMX bounds are never multiplied by the scene's raster scale. }
  for Group in FGroupViews.Values do
  begin
    Group.ApplyStyleLookup;
    Insets := RibbonControlPadding(Group);
    Inset := Max(Max(Insets.Left, Insets.Right), Max(Insets.Top, Insets.Bottom));
    Result.Padding := Max(Result.Padding, Inset);
  end;
end;

function TRibbonPresenter.BuildMeasurementKeys: TArray<string>;
var
  Keys: TList<string>;
  Data: TRibbonGroupViewData;
  ItemData: TRibbonItemViewData;
  Group: TRibbonGroupView;
  Launcher: TRibbonGroupLauncher;
  Item: TRibbonItemView;
begin
  Keys := TList<string>.Create;
  try
    for Data in FGroups do
    begin
      if not Data.Visible then Continue;
      if not FGroupViews.TryGetValue(Data.Id, Group) or
         not FGroupLaunchers.TryGetValue(Data.Id, Launcher) then
        raise ERibbonPresentationError.Create('Ribbon group presentation is missing.');
      Keys.Add(Group.MeasurementKey);
      Launcher.ApplyStyleLookup;
      Keys.Add(RibbonControlMeasureKey(Launcher) + ':' +
        RibbonFontMeasureKey(Launcher.ResultingTextSettings.Font));
      for ItemData in Data.Items do
      begin
        if not ItemData.Visible then Continue;
        if not FItemViews.TryGetValue(ItemData.Id, Item) then
          raise ERibbonPresentationError.Create('Ribbon item view is missing.');
        Keys.Add(Item.MeasurementKey);
      end;
    end;
    Result := Keys.ToArray;
  finally
    Keys.Free;
  end;
end;

procedure TRibbonPresenter.RefreshFocusLocks(var AMeasures: TArray<TRibbonGroupMeasure>);
var
  I: Integer;
  ItemMeasure: TRibbonItemMeasure;
  Item: TRibbonItemView;
begin
  for I := 0 to High(AMeasures) do
  begin
    AMeasures[I].FocusLocked := False;
    for ItemMeasure in AMeasures[I].Items do
      if FItemViews.TryGetValue(ItemMeasure.Id, Item) and Item.ContainsFocus then
      begin
        AMeasures[I].FocusLocked := True;
        Break;
      end;
  end;
end;

function TRibbonPresenter.MeasureGroups: TArray<TRibbonGroupMeasure>;
var
  I, J, GroupIndex, ItemIndex: Integer;
  Group: TRibbonGroupView;
  Launcher: TRibbonGroupLauncher;
  Item: TRibbonItemView;
  Size: TSizeF;
  Scale, MinimumTarget: Single;
  Revision: UInt64;
  Keys: TArray<string>;
begin
  if FViewFactory = nil then
    raise ERibbonPresentationError.Create('The Ribbon view factory was destroyed.');
  if FContentHost = nil then
    raise ERibbonPresentationError.Create('The Ribbon content host was destroyed.');
  Scale := RibbonControlScale(FContentHost);
  Revision := 0;
  if FViewFactory.IconProvider <> nil then Revision := FViewFactory.IconProvider.GetRevision;
  Keys := BuildMeasurementKeys;
  if FMeasurementsValid and (Scale = FMeasuredScale) and
     (Revision = FMeasuredIconRevision) and SameStrings(Keys, FMeasurementKeys) then
  begin
    Inc(FMeasurementCacheHitCount);
    Result := CopyMeasures(FMeasuredGroups);
    RefreshFocusLocks(Result);
    Exit;
  end;
  MinimumTarget := FindRibbonMetrics(FContentHost).MinimumTarget(FInputDensity);
  SetLength(Result, Length(FGroups));
  GroupIndex := 0;
  for I := 0 to High(FGroups) do
  begin
    if not FGroups[I].Visible then Continue;
    Group := FGroupViews[FGroups[I].Id];
    Launcher := FGroupLaunchers[FGroups[I].Id];
    Result[GroupIndex] := Default(TRibbonGroupMeasure);
    Result[GroupIndex].Id := FGroups[I].Id;
    Size := Group.DesiredCaptionSize;
    Result[GroupIndex].CaptionWidth := Size.Width;
    Result[GroupIndex].CaptionHeight := Max(Size.Height + 4,
      Group.CaptionBandHeight);
    Result[GroupIndex].MinWidth := FGroups[I].MinWidth;
    Result[GroupIndex].PreferredWidth := FGroups[I].PreferredWidth;
    Result[GroupIndex].Pinned := FGroups[I].Pinned;
    Result[GroupIndex].AllowCompact := FGroups[I].AllowCompact;
    Result[GroupIndex].AllowCollapse := FGroups[I].AllowCollapse;
    Result[GroupIndex].CollapsePriority := FGroups[I].CollapsePriority;
    Size := Launcher.DesiredSize;
    Result[GroupIndex].CollapsedWidth := Max(Size.Width, MinimumTarget);
    Result[GroupIndex].CollapsedHeight := Max(Size.Height, MinimumTarget);
    SetLength(Result[GroupIndex].Items, Length(FGroups[I].Items));
    ItemIndex := 0;
    for J := 0 to High(FGroups[I].Items) do
    begin
      if not FGroups[I].Items[J].Visible then Continue;
      Item := FItemViews[FGroups[I].Items[J].Id];
      Size := Item.DesiredSizeForStyle(FGroups[I].Items[J].ButtonStyle);
      if Item.IsInteractive then
      begin
        Size.Width := Max(Size.Width, MinimumTarget);
        Size.Height := Max(Size.Height, MinimumTarget);
      end;
      Result[GroupIndex].Items[ItemIndex].Id := FGroups[I].Items[J].Id;
      Result[GroupIndex].Items[ItemIndex].Width := Size.Width;
      Result[GroupIndex].Items[ItemIndex].Height := Size.Height;
      Result[GroupIndex].Items[ItemIndex].Style := FGroups[I].Items[J].ButtonStyle;
      Result[GroupIndex].Items[ItemIndex].CanCompact := Item.CanCompact;
      Result[GroupIndex].Items[ItemIndex].FillRow := Item.FillsRow;
      Result[GroupIndex].Items[ItemIndex].CompactStyle := rbsSmall;
      if Item.CanCompact then
      begin
        Size := Item.DesiredSizeForStyle(rbsSmall);
        if Item.IsInteractive then
        begin
          Size.Width := Max(Size.Width, MinimumTarget);
          Size.Height := Max(Size.Height, MinimumTarget);
        end;
        Result[GroupIndex].Items[ItemIndex].CompactWidth := Size.Width;
        Result[GroupIndex].Items[ItemIndex].CompactHeight := Size.Height;
      end;
      Inc(ItemIndex);
    end;
    SetLength(Result[GroupIndex].Items, ItemIndex);
    Inc(GroupIndex);
  end;
  SetLength(Result, GroupIndex);
  FMeasuredGroups := CopyMeasures(Result);
  { Some native styles realize text resources on first DesiredSize. Capture
    the committed keys after measurement to avoid a spurious second pass. }
  FMeasurementKeys := BuildMeasurementKeys;
  FMeasuredScale := Scale;
  FMeasuredIconRevision := Revision;
  FMeasurementsValid := True;
  Inc(FMeasurementPassCount);
  RefreshFocusLocks(Result);
end;

procedure TRibbonPresenter.ApplyLayout(const ALayout: TRibbonLayoutResult);
var
  Plan: TRibbonLayoutResult;
  Placement: TRibbonGroupPlacement;
  ItemPlacement: TRibbonItemPlacement;
  Group: TRibbonGroupView;
  Launcher: TRibbonGroupLauncher;
  Item: TRibbonItemView;
  VisibleGroups: Boolean;
  Planned: TDictionary<string, Byte>;
  Guard: TRibbonLayoutExecutionGuard;
  Id: string;
  I: Integer;
begin
  if FShuttingDown then Exit;
  Inc(FLayoutRevision);
  Guard := TRibbonLayoutExecutionGuard.CreateGuard(Self);
  Planned := nil;
  try
    { Keep the iteration data alive if the caller/root is destroyed or replaces
      its last plan inside a native focus or resize event. }
    Plan := ALayout;
    Plan.Groups := Copy(ALayout.Groups);
    for I := 0 to High(Plan.Groups) do
      Plan.Groups[I].Items := Copy(ALayout.Groups[I].Items);
    VisibleGroups := Plan.Mode = rlmGroups;
    Planned := TDictionary<string, Byte>.Create;
    { Validate before changing native visibility. Repeated layout must not hide
      and re-show unchanged groups: that would discard focus/IME selection. }
    for Placement in Plan.Groups do
    begin
      if not FGroupViews.TryGetValue(Placement.Id, Group) or
         not FGroupLaunchers.ContainsKey(Placement.Id) then
        raise ERibbonPresentationError.Create('Layout references an unknown group.');
      if Planned.ContainsKey(Placement.Id) then
        raise ERibbonPresentationError.Create('Layout contains a duplicate group.');
      Planned.Add(Placement.Id, 0);
      for ItemPlacement in Placement.Items do
      begin
        if not FItemViews.TryGetValue(ItemPlacement.Id, Item) or (Item.Control = nil) then
          raise ERibbonPresentationError.Create('Layout references an unknown item.');
        if Item.Control.Parent <> Group then
          raise ERibbonPresentationError.Create('Layout item/group relationship differs.');
      end;
    end;
    { Iterate copied keys, never a dictionary enumerator across native callbacks. }
    for Id in FGroupViews.Keys.ToArray do
      if not Planned.ContainsKey(Id) then
      begin
        Group := FGroupViews[Id];
        if Group.Visible then Group.Visible := False;
        if not Guard.Current then Exit;
      end;
    for Id in FGroupLaunchers.Keys.ToArray do
      if not Planned.ContainsKey(Id) then
      begin
        Launcher := FGroupLaunchers[Id];
        if Launcher.Visible then Launcher.Visible := False;
        if not Guard.Current then Exit;
      end;
    for Placement in Plan.Groups do
    begin
      Group := FGroupViews[Placement.Id];
      Launcher := FGroupLaunchers[Placement.Id];
      if not VisibleGroups then
      begin
        if Group.Visible then Group.Visible := False;
        if not Guard.Current then Exit;
        if Launcher.Visible then Launcher.Visible := False;
        if not Guard.Current then Exit;
        Continue;
      end;
      if Placement.Presentation = rgpCollapsed then
      begin
        if Group.Visible then Group.Visible := False;
        if not Guard.Current then Exit;
        Launcher.SetBounds(Placement.Bounds.Left, Placement.Bounds.Top,
          Placement.Bounds.Width, Placement.Bounds.Height);
        if not Guard.Current then Exit;
        if not Launcher.Visible then Launcher.Visible := True;
        if not Guard.Current then Exit;
        Continue;
      end;
      if Launcher.Visible then Launcher.Visible := False;
      if not Guard.Current then Exit;
      Group.SetBounds(Placement.Bounds.Left, Placement.Bounds.Top,
        Placement.Bounds.Width, Placement.Bounds.Height);
      if not Guard.Current then Exit;
      Group.SetCaptionBounds(Placement.CaptionBounds);
      if not Guard.Current then Exit;
      if not Group.Visible then Group.Visible := True;
      if not Guard.Current then Exit;
      for ItemPlacement in Placement.Items do
      begin
        Item := FItemViews[ItemPlacement.Id];
        if Item.Control = nil then Exit;
        Item.SetPresentationStyle(ItemPlacement.Style);
        if not Guard.Current then Exit;
        if Item.Control = nil then Exit;
        Item.Control.SetBounds(ItemPlacement.Bounds.Left, ItemPlacement.Bounds.Top,
          ItemPlacement.Bounds.Width, ItemPlacement.Bounds.Height);
        if not Guard.Current then Exit;
      end;
    end;
  finally
    Planned.Free;
    Guard.Free;
  end;
end;

function TRibbonPresenter.FirstFocusableItem(const AGroupId: string): TControl;
var
  Data: TRibbonGroupViewData;
  ItemData: TRibbonItemViewData;
  Item: TRibbonItemView;
  function FindFocusable(AObject: TFmxObject): TControl;
  var
    Child: TFmxObject;
    Control: TControl;
  begin
    Result := nil;
    if AObject is TControl then
    begin
      Control := TControl(AObject);
      if not Control.Visible or not Control.ParentedVisible or
         not Control.AbsoluteEnabled then Exit;
      if Control.CanFocus then Exit(Control);
    end;
    if AObject.Children = nil then Exit;
    for Child in AObject.Children do
    begin
      Result := FindFocusable(Child);
      if Result <> nil then Exit;
    end;
  end;
begin
  Result := nil;
  for Data in FGroups do
    if Data.Id = AGroupId then
    begin
      if not Data.Visible or not Data.Enabled then Exit;
      for ItemData in Data.Items do
        if ItemData.Visible and ItemData.Enabled and
           FItemViews.TryGetValue(ItemData.Id, Item) and (Item.Control <> nil) then
        begin
          Result := FindFocusable(Item.Control);
          if Result <> nil then Exit;
        end;
      Exit;
    end;
end;

function TRibbonPresenter.SelectedTabBounds(out ABounds: TRectF): Boolean;
var
  Data: TRibbonTabViewData;
  Tab: TRibbonTabButton;
begin
  Result := False;
  ABounds := TRectF.Empty;
  for Data in FTabs do
    if Data.Visible and Data.Selected and FTabViews.TryGetValue(Data.Id, Tab) then
    begin
      ABounds := Tab.BoundsRect;
      Exit(True);
    end;
end;

function TRibbonPresenter.RecommendedTabHeight: Single;
var
  Data: TRibbonTabViewData;
  Tabs: TArray<TRibbonTabViewData>;
  Tab: TRibbonTabButton;
  Size: TSizeF;
  Guard: TRibbonLayoutExecutionGuard;
begin
  Result := RibbonDefaultTabHeight;
  if FShuttingDown then Exit;
  Result := FindRibbonMetrics(FContentHost).TabMinHeight;
  if FInputDensity = ridTouch then Result := Max(Result, 44);
  Guard := TRibbonLayoutExecutionGuard.CreateGuard(Self);
  try
    Tabs := Copy(FTabs);
    for Data in Tabs do
      if Data.Visible then
        if FTabViews.TryGetValue(Data.Id, Tab) then
        begin
          Size := Tab.DesiredSize;
          if not Guard.Current then Exit;
          Result := Max(Result, Size.Height);
        end;
  finally
    Guard.Free;
  end;
end;

function TRibbonPresenter.ArrangeTabs(const AHeight: Single): Single;
const
  TabGap: Single = 4;
var
  Data: TRibbonTabViewData;
  Tabs: TArray<TRibbonTabViewData>;
  Tab: TRibbonTabButton;
  X, H, W: Single;
  Guard: TRibbonLayoutExecutionGuard;
begin
  Result := 0;
  if IsNan(AHeight) or IsInfinite(AHeight) or (AHeight < 0) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon tab height.');
  if FShuttingDown then Exit;
  Guard := TRibbonLayoutExecutionGuard.CreateGuard(Self);
  try
    X := 0;
    H := Max(AHeight, RecommendedTabHeight);
    if not Guard.Current then Exit;
    Tabs := Copy(FTabs);
    for Data in Tabs do
    begin
      if not Data.Visible then Continue;
      if not FTabViews.TryGetValue(Data.Id, Tab) then Continue;
      W := Tab.DesiredWidth;
      if not Guard.Current then Exit;
      if FInputDensity = ridTouch then W := Max(W, 44);
      Tab.SetBounds(X, 0, W, H);
      { The native resize callback may destroy this presenter or Sync a new
        tab snapshot. Match the body-layout contract: abandon the old pass
        before touching the presenter, a view or the next dictionary entry. }
      if not Guard.Current then Exit;
      X := X + W + TabGap;
    end;
    if X > 0 then X := X - TabGap;
    Result := X;
  finally
    Guard.Free;
  end;
end;

procedure TRibbonPresenter.TabClicked(Sender: TObject);
var
  Id: string;
  Handler: TRibbonViewClickEvent;
begin
  if FShuttingDown or (FSyncing <> 0) then Exit;
  if not (Sender is TRibbonTabButton) then Exit;
  if not RibbonActivationAllowed(TRibbonTabButton(Sender)) then
  begin
    TRibbonTabButton(Sender).IsPressed := TRibbonTabButton(Sender).Selected;
    Exit;
  end;
  Id := TRibbonTabButton(Sender).ItemId;
  Handler := FOnTabClick;
  TRibbonTabButton(Sender).Selected := True;
  if Assigned(Handler) then Handler(Self, Id);
end;

procedure TRibbonPresenter.GroupClicked(Sender: TObject);
var
  Id: string;
  Launcher: TRibbonGroupLauncher;
  Handler: TRibbonViewClickEvent;
begin
  if FShuttingDown or (FSyncing <> 0) then Exit;
  if not (Sender is TRibbonGroupLauncher) then Exit;
  Launcher := TRibbonGroupLauncher(Sender);
  if not Launcher.Visible or not Launcher.ParentedVisible or
     not Launcher.AbsoluteEnabled or not RibbonActivationAllowed(Launcher) then Exit;
  Id := Launcher.ItemId;
  Handler := FOnGroupPopup;
  if Assigned(Handler) then Handler(Self, Id);
  { The callback may destroy this presenter; no instance access follows. }
end;

procedure TRibbonPresenter.ItemInput(Sender: TObject; const AInput: TRibbonItemInput);
var
  Handler: TRibbonItemInputEvent;
  LegacyHandler: TRibbonViewClickEvent;
  EventData: TRibbonItemInput;
begin
  if FShuttingDown or (FSyncing <> 0) then Exit;
  EventData := AInput;
  Handler := FOnInput;
  LegacyHandler := FOnButtonClick;
  if Assigned(Handler) then
    Handler(Self, EventData)
  else if (EventData.Kind = rikExecute) and Assigned(LegacyHandler) then
    LegacyHandler(Self, EventData.Id);
  { No Self, Sender or view access after an external callback. }
end;

function TRibbonPresenter.FindTabView(const AId: string): TRibbonTabButton;
begin
  if not FTabViews.TryGetValue(AId, Result) then Result := nil;
end;

function TRibbonPresenter.FindGroupView(const AId: string): TRibbonGroupView;
begin
  if not FGroupViews.TryGetValue(AId, Result) then Result := nil;
end;

function TRibbonPresenter.FindGroupLauncher(const AId: string): TRibbonGroupLauncher;
begin
  if not FGroupLaunchers.TryGetValue(AId, Result) then Result := nil;
end;

function TRibbonPresenter.FindItemView(const AId: string): TControl;
var
  Item: TRibbonItemView;
begin
  Result := nil;
  if FItemViews.TryGetValue(AId, Item) then Result := Item.Control;
end;

function TRibbonPresenter.FindButtonView(const AId: string): TRibbonCommandButton;
var
  Item: TRibbonItemView;
begin
  Result := nil;
  if FItemViews.TryGetValue(AId, Item) then Result := Item.CommandButton;
end;

function TRibbonPresenter.GetTabViewCount: Integer;
begin
  Result := FTabViews.Count;
end;

function TRibbonPresenter.GetGroupViewCount: Integer;
begin
  Result := FGroupViews.Count;
end;

function TRibbonPresenter.GetButtonViewCount: Integer;
var
  Item: TRibbonItemView;
begin
  Result := 0;
  for Item in FItemViews.Values do
    if Item.CommandButton <> nil then Inc(Result);
end;

function TRibbonPresenter.GetItemViewCount: Integer;
begin
  Result := FItemViews.Count;
end;

end.
