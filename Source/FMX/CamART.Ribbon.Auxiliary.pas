unit CamART.Ribbon.Auxiliary;

{$B-}

interface

uses
  System.Classes,
  System.Types,
  System.Generics.Collections,
  FMX.Controls,
  CamART.Ribbon.Types,
  CamART.Ribbon.ViewData,
  CamART.Ribbon.ItemViews,
  CamART.Ribbon.ViewFactory;

type
  { A small reusable horizontal surface for command references. It owns view
    adapters, borrows the factory and host, and never owns a source model node.
    Dispose before the borrowed factory/host. }
  TRibbonAuxiliaryPresenter = class(TComponent)
  private
    FHost: TControl;
    FFactory: TRibbonViewFactory;
    FViews: TDictionary<string, TRibbonItemView>;
    FData: TArray<TRibbonItemViewData>;
    FOnInput: TRibbonItemInputEvent;
    FClosing: Boolean;
    FInputDensity: TRibbonInputDensity;
    FRevision: UInt64;
    procedure SetInputDensity(const AValue: TRibbonInputDensity);
    function MeasuredSize(AView: TRibbonItemView): TSizeF;
    procedure Input(Sender: TObject; const AInput: TRibbonItemInput);
    function GetCount: Integer;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent; AHost: TControl;
      AFactory: TRibbonViewFactory); reintroduce;
    destructor Destroy; override;
    procedure Clear;
    procedure Sync(const AData: TArray<TRibbonItemViewData>);
    function Measure: TSizeF;
    function Arrange(const AHeight: Single): Single;
    function FindView(const AId: string): TControl;
    property InputDensity: TRibbonInputDensity read FInputDensity write SetInputDensity;
    property Count: Integer read GetCount;
    property OnInput: TRibbonItemInputEvent read FOnInput write FOnInput;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  CamART.Ribbon.Themes;

type
  { The QAT is a native surface too. A resize/style callback may replace its
    snapshot or destroy the root that owns it. The guard is stack-owned. }
  TRibbonAuxiliaryExecutionGuard = class(TComponent)
  private
    FPresenter: TRibbonAuxiliaryPresenter;
    FRevision: UInt64;
    FView: TRibbonItemView;
    FControl: TControl;
    FWatchingView: Boolean;
    function GetAlive: Boolean;
    function GetCurrent: Boolean;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateGuard(APresenter: TRibbonAuxiliaryPresenter);
    destructor Destroy; override;
    procedure ForgetView;
    procedure WatchView(AView: TRibbonItemView);
    procedure WatchOwnedView(AView: TRibbonItemView);
    property Alive: Boolean read GetAlive;
    property Current: Boolean read GetCurrent;
    property View: TRibbonItemView read FView;
  end;

constructor TRibbonAuxiliaryExecutionGuard.CreateGuard(
  APresenter: TRibbonAuxiliaryPresenter);
begin
  inherited Create(nil);
  FPresenter := APresenter;
  FRevision := APresenter.FRevision;
  FPresenter.FreeNotification(Self);
end;

destructor TRibbonAuxiliaryExecutionGuard.Destroy;
begin
  { Unsubscribe before inherited destruction. A temporary observer going
    away is not a new presenter layout revision. }
  ForgetView;
  if FPresenter <> nil then FPresenter.RemoveFreeNotification(Self);
  inherited;
end;

procedure TRibbonAuxiliaryExecutionGuard.ForgetView;
begin
  if FControl <> nil then TComponent(FControl).RemoveFreeNotification(Self);
  if FView <> nil then FView.RemoveFreeNotification(Self);
  FControl := nil;
  FView := nil;
  FWatchingView := False;
end;

procedure TRibbonAuxiliaryExecutionGuard.WatchView(AView: TRibbonItemView);
begin
  ForgetView;
  FWatchingView := True;
  if not Alive then Exit;
  FView := AView;
  if FView = nil then Exit;
  FView.FreeNotification(Self);
  FControl := FView.Control;
  if FControl <> nil then TComponent(FControl).FreeNotification(Self);
end;

procedure TRibbonAuxiliaryExecutionGuard.WatchOwnedView(AView: TRibbonItemView);
var
  I: Integer;
  Component: TComponent;
begin
  ForgetView;
  FWatchingView := True;
  if not Alive then Exit;
  { Used only when a factory call was interrupted by destruction/resync.
    Establish ownership/liveness through the surviving owner's list before
    dereferencing its returned pointer. Normal Sync watches known map entries
    directly and does not scan the component list for every retained item. }
  for I := 0 to FPresenter.ComponentCount - 1 do
  begin
    Component := FPresenter.Components[I];
    if (Component = AView) and (Component is TRibbonItemView) then
    begin
      FView := TRibbonItemView(Component);
      Break;
    end;
  end;
  if FView = nil then Exit;
  FView.FreeNotification(Self);
  FControl := FView.Control;
  if FControl <> nil then TComponent(FControl).FreeNotification(Self);
end;

procedure TRibbonAuxiliaryExecutionGuard.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation <> opRemove then Exit;
  if AComponent = FPresenter then FPresenter := nil;
  if AComponent = FView then FView := nil;
  if AComponent = FControl then FControl := nil;
end;

function TRibbonAuxiliaryExecutionGuard.GetAlive: Boolean;
begin
  Result := (FPresenter <> nil) and not FPresenter.FClosing;
end;

function TRibbonAuxiliaryExecutionGuard.GetCurrent: Boolean;
begin
  Result := Alive and (FPresenter.FRevision = FRevision) and
    (not FWatchingView or ((FView <> nil) and (FControl <> nil)));
end;

constructor TRibbonAuxiliaryPresenter.Create(AOwner: TComponent; AHost: TControl;
  AFactory: TRibbonViewFactory);
begin
  inherited Create(AOwner);
  if (AHost = nil) or (AFactory = nil) then
    raise EArgumentNilException.Create('An auxiliary host and view factory are required.');
  FHost := AHost;
  FFactory := AFactory;
  TComponent(FHost).FreeNotification(Self);
  FFactory.FreeNotification(Self);
  FViews := TDictionary<string, TRibbonItemView>.Create;
end;

destructor TRibbonAuxiliaryPresenter.Destroy;
begin
  FClosing := True;
  FOnInput := nil;
  Clear;
  if FHost <> nil then TComponent(FHost).RemoveFreeNotification(Self);
  if FFactory <> nil then FFactory.RemoveFreeNotification(Self);
  FreeAndNil(FViews);
  inherited;
end;

procedure TRibbonAuxiliaryPresenter.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  View: TRibbonItemView;
  Changed: Boolean;
begin
  if Operation = opRemove then
  begin
    Changed := False;
    if AComponent = FHost then
    begin
      FHost := nil;
      Changed := True;
    end;
    if AComponent = FFactory then
    begin
      FFactory := nil;
      Changed := True;
    end;
    if (AComponent is TRibbonItemView) and (FViews <> nil) then
      if FViews.TryGetValue(TRibbonItemView(AComponent).ItemId, View) then
        if View = AComponent then
        begin
          FViews.Remove(View.ItemId);
          Changed := True;
        end;
    { Sync removes its own retired view from the map before freeing it.
      That expected removal is not a reentrant replacement snapshot. }
    if Changed then Inc(FRevision);
  end;
  inherited;
end;

procedure TRibbonAuxiliaryPresenter.Clear;
var
  Id: string;
  View: TRibbonItemView;
begin
  Inc(FRevision);
  FData := nil;
  if FViews = nil then Exit;
  for Id in FViews.Keys.ToArray do
  begin
    View := FViews[Id];
    FViews.Remove(Id);
    View.OnInput := nil;
    View.Free;
  end;
end;

procedure TRibbonAuxiliaryPresenter.Sync(const AData: TArray<TRibbonItemViewData>);
var
  Wanted: TDictionary<string, Boolean>;
  Snapshot: TArray<TRibbonItemViewData>;
  Data: TRibbonItemViewData;
  Id: string;
  View: TRibbonItemView;
  WantedVisible: Boolean;
  Guard: TRibbonAuxiliaryExecutionGuard;

  procedure ReleaseUnpublishedView;
  var
    Pending, Published: TRibbonItemView;
  begin
    if not Guard.Alive then Exit;
    Pending := Guard.View;
    if Pending = nil then Exit;
    if FViews.TryGetValue(Pending.ItemId, Published) and (Published = Pending) then Exit;
    Guard.ForgetView;
    Pending.OnInput := nil;
    Pending.Free;
    { Free may reenter/destroy this presenter. No presenter access follows. }
  end;

begin
  if FClosing then Exit;
  if (FHost = nil) or (FFactory = nil) then
    raise EInvalidOperation.Create('Auxiliary view host/factory was destroyed.');
  Wanted := TDictionary<string, Boolean>.Create;
  Guard := nil;
  try
    for Data in AData do
    begin
      if Data.Id = '' then raise EArgumentException.Create('An auxiliary item needs an Id.');
      if Wanted.ContainsKey(Data.Id) then
        raise EArgumentException.Create('Duplicate auxiliary item Id: ' + Data.Id);
      Wanted.Add(Data.Id, Data.Visible);
    end;
    Inc(FRevision);
    Guard := TRibbonAuxiliaryExecutionGuard.CreateGuard(Self);
    FData := Copy(AData);
    Snapshot := Copy(FData);
    for Data in Snapshot do
    begin
      if not Data.Visible then Continue;
      Guard.ForgetView;
      if FViews.TryGetValue(Data.Id, View) and
         ((View.TypeKey <> Data.TypeKey) or (View.Control = nil)) then
      begin
        FViews.Remove(Data.Id);
        View.OnInput := nil;
        View.Free;
        if not Guard.Current then Exit;
      end;
      if not FViews.TryGetValue(Data.Id, View) then
      begin
        View := FFactory.CreateView(Self, FHost, Data);
        if not Guard.Current then
        begin
          Guard.WatchOwnedView(View);
          ReleaseUnpublishedView;
          Exit;
        end;
        Guard.WatchView(View);
        if not Guard.Current then
        begin
          ReleaseUnpublishedView;
          Exit;
        end;
        try
          View.OnInput := Input;
          FViews.Add(Data.Id, View);
        except
          ReleaseUnpublishedView;
          raise;
        end;
      end
      else
      begin
        Guard.WatchView(View);
        if not Guard.Current then Exit;
        View.IconProvider := FFactory.IconProvider;
        if not Guard.Current then Exit;
        View.Apply(Data);
        if not Guard.Current then Exit;
      end;
      { Density can resize the split arrow and enter application OnResize.
        It therefore has the same weak lifetime/revision boundary as Apply. }
      View.InputDensity := FInputDensity;
      if not Guard.Current then Exit;
      if View.CommandButton <> nil then
        View.CommandButton.RibbonStyleRole := rsrQuickAccess;
      if not Guard.Current then Exit;
    end;
    Guard.ForgetView;
    for Id in FViews.Keys.ToArray do
      if not Wanted.TryGetValue(Id, WantedVisible) or not WantedVisible then
      begin
        if not FViews.TryGetValue(Id, View) then Continue;
        FViews.Remove(Id);
        View.OnInput := nil;
        View.Free;
        if not Guard.Current then Exit;
      end;
  finally
    Guard.Free;
    Wanted.Free;
  end;
end;

procedure TRibbonAuxiliaryPresenter.SetInputDensity(
  const AValue: TRibbonInputDensity);
begin
  if (Ord(AValue) < Ord(Low(TRibbonInputDensity))) or
     (Ord(AValue) > Ord(High(TRibbonInputDensity))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon input density.');
  if FInputDensity = AValue then Exit;
  FInputDensity := AValue;
  Inc(FRevision);
end;

function TRibbonAuxiliaryPresenter.MeasuredSize(AView: TRibbonItemView): TSizeF;
var
  MinimumTarget: Single;
  Interactive: Boolean;
begin
  { Capture local policy before native measurement. The caller checks its
    weak lifetime/revision guard before accessing either presenter or view. }
  Interactive := AView.IsInteractive;
  MinimumTarget := 28;
  if FInputDensity = ridTouch then MinimumTarget := 44;
  Result := AView.DesiredSize;
  if not Interactive then Exit;
  Result.Width := Max(Result.Width, MinimumTarget);
  Result.Height := Max(Result.Height, MinimumTarget);
end;

function TRibbonAuxiliaryPresenter.Measure: TSizeF;
var
  Data: TRibbonItemViewData;
  Snapshot: TArray<TRibbonItemViewData>;
  View: TRibbonItemView;
  Size: TSizeF;
  Guard: TRibbonAuxiliaryExecutionGuard;
begin
  Result := TSizeF.Create(0, 0);
  if FClosing then Exit;
  Guard := TRibbonAuxiliaryExecutionGuard.CreateGuard(Self);
  try
    Snapshot := Copy(FData);
    for Data in Snapshot do
      if Data.Visible and FViews.TryGetValue(Data.Id, View) then
      begin
        if View.Control = nil then Exit;
        Size := MeasuredSize(View);
        if not Guard.Current then Exit;
        if View.Control = nil then Exit;
        if Result.Width > 0 then Result.Width := Result.Width + 4;
        Result.Width := Result.Width + Size.Width;
        Result.Height := Max(Result.Height, Size.Height);
      end;
  finally
    Guard.Free;
  end;
end;

function TRibbonAuxiliaryPresenter.Arrange(const AHeight: Single): Single;
var
  Data: TRibbonItemViewData;
  Snapshot: TArray<TRibbonItemViewData>;
  View: TRibbonItemView;
  Size: TSizeF;
  Index: Integer;
  Guard: TRibbonAuxiliaryExecutionGuard;
begin
  Result := 0;
  if IsNan(AHeight) or IsInfinite(AHeight) or (AHeight < 0) then
    raise EArgumentOutOfRangeException.Create('Invalid auxiliary Ribbon height.');
  if FClosing then Exit;
  Guard := TRibbonAuxiliaryExecutionGuard.CreateGuard(Self);
  try
    Snapshot := Copy(FData);
    Index := 0;
    for Data in Snapshot do
      if Data.Visible and FViews.TryGetValue(Data.Id, View) then
      begin
        if View.Control = nil then Exit;
        Size := MeasuredSize(View);
        if not Guard.Current then Exit;
        if View.Control = nil then Exit;
        if Result > 0 then Result := Result + 4;
        View.Control.SetBounds(Result, 0, Size.Width, Max(AHeight, Size.Height));
        if not Guard.Current then Exit;
        if View.Control = nil then Exit;
        View.Control.TabOrder := Index;
        if not Guard.Current then Exit;
        Inc(Index);
        Result := Result + Size.Width;
      end;
  finally
    Guard.Free;
  end;
end;

function TRibbonAuxiliaryPresenter.FindView(const AId: string): TControl;
var
  View: TRibbonItemView;
begin
  if FViews.TryGetValue(AId, View) then Result := View.Control else Result := nil;
end;

procedure TRibbonAuxiliaryPresenter.Input(Sender: TObject;
  const AInput: TRibbonItemInput);
var
  Handler: TRibbonItemInputEvent;
begin
  if FClosing then Exit;
  Handler := FOnInput;
  if Assigned(Handler) then Handler(Self, AInput);
end;

function TRibbonAuxiliaryPresenter.GetCount: Integer;
begin
  Result := FViews.Count;
end;

end.
