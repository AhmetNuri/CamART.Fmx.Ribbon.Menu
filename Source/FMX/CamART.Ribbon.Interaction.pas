unit CamART.Ribbon.Interaction;

{$B-}

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  FMX.Layouts,
  FMX.StdCtrls,
  CamART.Ribbon.Themes,
  CamART.Ribbon.StyleScope,
  CamART.Ribbon.Types;

type
  TRibbonInputGuard = class;

  { A detached lifetime/session record for queued restoration. It never owns
    the native control or its guard. }
  IRibbonInputLifetime = interface
    ['{E3F29E7D-39CB-4426-B22A-65DCDEFA8F4F}']
    function IsAlive: Boolean;
    function GetSession: UInt64;
    function GetControl: TControl;
    procedure Advance;
    procedure Stop;
  end;

  { Attach to generated activation surfaces and scroll backgrounds only.
    Editors/combo/color controls retain their native selection gestures.
    This component is owned by its control and uses no Tag/global state. }
  TRibbonInputGuard = class(TComponent)
  private
    FControl: TControl;
    FScroll: TCustomScrollBox;
    FLifetime: IRibbonInputLifetime;
    FDensity: TRibbonInputDensity;
    FPointerDown: Boolean;
    FPanned: Boolean;
    FManualPan: Boolean;
    FPointerHooksInstalled: Boolean;
    FOriginAbsolute: TPointF;
    FStartViewport: TPointF;
    FPreviousDown: TMouseEvent;
    FPreviousMove: TMouseMoveEvent;
    FPreviousUp: TMouseEvent;
    FPreviousKey: TKeyEvent;
    FPreviousEnter: TNotifyEvent;
    FOnPanFinished: TNotifyEvent;
    procedure HookDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HookMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure HookUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure HookKey(Sender: TObject; var Key: Word;
      var KeyChar: WideChar; Shift: TShiftState);
    procedure HookEnter(Sender: TObject);
    procedure WatchScroll(AScroll: TCustomScrollBox);
    procedure InstallFocusHook;
    procedure InstallPointerHooks;
    procedure RemoveHooks;
    procedure SetDensity(const AValue: TRibbonInputDensity);
    procedure QueuePanFinished;
    function GetActivationAllowed: Boolean;
    function PanSlop: Single;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateForControl(AControl: TControl;
      ADensity: TRibbonInputDensity; APointerInput: Boolean = True);
    destructor Destroy; override;
    procedure BeginPointer(Button: TMouseButton; X, Y: Single);
    procedure MovePointer(X, Y: Single);
    procedure EndPointer(X, Y: Single);
    procedure KeyboardInput;
    procedure Cancel;
    property Density: TRibbonInputDensity read FDensity write SetDensity;
    property PointerDown: Boolean read FPointerDown;
    property Panned: Boolean read FPanned;
    property ActivationAllowed: Boolean read GetActivationAllowed;
    property Lifetime: IRibbonInputLifetime read FLifetime;
    { Sender is the native control. Runs after native input returns. }
    property OnPanFinished: TNotifyEvent read FOnPanFinished write FOnPanFinished;
  end;

  { Announce the complete pointer/key sequence before native activation code.
    In particular, a final mouse-up displacement is recognized before the
    native button/check/radio Click or value-change notification. }
  TRibbonInputButton = class(TButton, IRibbonStyleSource)
  private
    FRibbonStyleRole: TRibbonStyleRole;
    FNativeDisabledOpacity: Single;
    FStyleReady: Boolean;
    procedure SetRibbonStyleRole(const AValue: TRibbonStyleRole);
    procedure UpdateThemeEnabled;
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
    procedure ApplyStyle; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
    procedure RecalcEnabled; override;
    property RibbonStyleRole: TRibbonStyleRole read FRibbonStyleRole
      write SetRibbonStyleRole;
  end;

  TRibbonInputCheckBox = class(TCheckBox, IRibbonStyleSource)
  private
    FNativeDisabledOpacity: Single;
    FStyleReady: Boolean;
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
    procedure ApplyStyle; override;
  public
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState); override;
    constructor Create(AOwner: TComponent); override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
    procedure RecalcEnabled; override;
  end;

  TRibbonInputRadioButton = class(TRadioButton, IRibbonStyleSource)
  private
    FNativeDisabledOpacity: Single;
    FStyleReady: Boolean;
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
    procedure ApplyStyle; override;
  public
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState); override;
    constructor Create(AOwner: TComponent); override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
    procedure RecalcEnabled; override;
  end;

procedure AttachRibbonInput(AControl: TControl; ADensity: TRibbonInputDensity);
{ Focus reveal only: no mouse/key hooks and no selection/pan interception.
  An existing full input guard is retained; EnsureRibbonInput can upgrade a
  focus-only guard without rewrapping its OnEnter callback. }
procedure AttachRibbonFocus(AControl: TControl);
function EnsureRibbonInput(AControl: TControl;
  ADensity: TRibbonInputDensity): TRibbonInputGuard;
function RibbonActivationAllowed(AControl: TControl): Boolean;
function RibbonPointerIsDown(AControl: TControl): Boolean;
procedure RibbonBeginPointer(AControl: TControl; Button: TMouseButton;
  X, Y: Single);
procedure RibbonEndPointer(AControl: TControl; X, Y: Single);
procedure RibbonKeyboardInput(AControl: TControl);
procedure RibbonEnsureControlVisible(AControl: TControl);

implementation

uses
  System.SysUtils,
  System.Math,
  CamART.Ribbon.StyleContext,
  CamART.Ribbon.ThemeStyles;

type
  TRibbonControlAccess = class(TControl)
  public
    property DisabledOpacity;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnKeyDown;
  end;

  TRibbonScrollAccess = class(TCustomScrollBox)
  public
    property ContentLayout;
  end;

  TRibbonInputLifetime = class(TInterfacedObject, IRibbonInputLifetime)
  private
    FAlive: Boolean;
    FSession: UInt64;
    FControl: TControl;
  public
    constructor Create(AControl: TControl);
    function IsAlive: Boolean;
    function GetSession: UInt64;
    function GetControl: TControl;
    procedure Advance;
    procedure Stop;
  end;

procedure SetRibbonViewport(AScroll: TCustomScrollBox; const AOffset: TPointF);
var
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(AScroll);
  try
    AScroll.ViewportPosition := AOffset;
    { The inertial engine throttles DoChanged within one tick. Complete the
      visual translation and its lifetime callbacks before native mouse-up
      continues; a viewport callback may already have freed the scroll box. }
    if Watch.Control <> nil then TRibbonControlAccess(Watch.Control).Realign;
  finally
    Watch.Free;
  end;
end;

procedure UpdateRibbonControlThemeEnabled(AControl: TStyledControl;
  const ANativeOpacity: Single; const AReady: Boolean);
begin
  if not AReady or (csDestroying in AControl.ComponentState) then Exit;
  if AControl.FindStyleResource(RibbonThemeMarkerPart) <> nil then
    TRibbonControlAccess(AControl).DisabledOpacity := 1
  else
    TRibbonControlAccess(AControl).DisabledOpacity := ANativeOpacity;
  ApplyRibbonThemeEnabled(AControl, AControl.AbsoluteEnabled);
end;

function FindGuard(AControl: TControl): TRibbonInputGuard;
var
  I: Integer;
begin
  Result := nil;
  if (AControl = nil) or (csDestroying in AControl.ComponentState) then Exit;
  for I := 0 to AControl.ComponentCount - 1 do
    if AControl.Components[I] is TRibbonInputGuard then
      Exit(TRibbonInputGuard(AControl.Components[I]));
end;

function NearestScroll(AControl: TControl): TCustomScrollBox;
var
  Current: TFmxObject;
begin
  Result := nil;
  Current := AControl;
  while Current <> nil do
  begin
    if Current is TCustomScrollBox then Exit(TCustomScrollBox(Current));
    Current := Current.Parent;
  end;
end;

procedure ResetAncestorInput(AControl: TControl; ACancelActive: Boolean);
var
  Current: TFmxObject;
  Guard: TRibbonInputGuard;
begin
  if AControl = nil then Exit;
  Current := AControl.Parent;
  while Current <> nil do
  begin
    if Current is TControl then
    begin
      Guard := FindGuard(TControl(Current));
      if (Guard <> nil) and (ACancelActive or not Guard.PointerDown) then
        Guard.Cancel;
    end;
    Current := Current.Parent;
  end;
end;

function EqualMethods(const A, B: TMethod): Boolean;
begin
  Result := (A.Code = B.Code) and (A.Data = B.Data);
end;

function SamePoint(const A, B: TPointF): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y);
end;

constructor TRibbonInputLifetime.Create(AControl: TControl);
begin
  inherited Create;
  FAlive := True;
  FSession := 1;
  FControl := AControl;
end;

function TRibbonInputLifetime.IsAlive: Boolean;
begin
  Result := FAlive;
end;

function TRibbonInputLifetime.GetSession: UInt64;
begin
  Result := FSession;
end;

function TRibbonInputLifetime.GetControl: TControl;
begin
  Result := FControl;
end;

procedure TRibbonInputLifetime.Advance;
begin
  if FSession = High(UInt64) then FSession := 1 else Inc(FSession);
end;

procedure TRibbonInputLifetime.Stop;
begin
  FAlive := False;
  FControl := nil;
  Advance;
end;

constructor TRibbonInputGuard.CreateForControl(AControl: TControl;
  ADensity: TRibbonInputDensity; APointerInput: Boolean);
begin
  if AControl = nil then
    raise EArgumentNilException.Create('An input guard requires a native control.');
  if csDestroying in AControl.ComponentState then
    raise EArgumentException.Create('An input guard cannot attach during destruction.');
  inherited Create(AControl);
  FControl := AControl;
  FLifetime := TRibbonInputLifetime.Create(AControl);
  TComponent(FControl).FreeNotification(Self);
  SetDensity(ADensity);
  InstallFocusHook;
  if APointerInput then InstallPointerHooks;
end;

destructor TRibbonInputGuard.Destroy;
begin
  FOnPanFinished := nil;
  if FLifetime <> nil then FLifetime.Stop;
  RemoveHooks;
  WatchScroll(nil);
  if FControl <> nil then TComponent(FControl).RemoveFreeNotification(Self);
  FControl := nil;
  FLifetime := nil;
  inherited;
end;

procedure TRibbonInputGuard.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation <> opRemove then Exit;
  if AComponent = FScroll then
  begin
    FScroll := nil;
    Cancel;
  end;
  if AComponent = FControl then
  begin
    FControl := nil;
    FPointerDown := False;
    FPanned := True;
    if FLifetime <> nil then FLifetime.Stop;
  end;
end;

procedure TRibbonInputGuard.WatchScroll(AScroll: TCustomScrollBox);
begin
  if FScroll = AScroll then Exit;
  if FScroll <> nil then TComponent(FScroll).RemoveFreeNotification(Self);
  FScroll := AScroll;
  if FScroll <> nil then TComponent(FScroll).FreeNotification(Self);
end;

procedure TRibbonInputGuard.SetDensity(const AValue: TRibbonInputDensity);
begin
  if (Ord(AValue) < Ord(Low(TRibbonInputDensity))) or
     (Ord(AValue) > Ord(High(TRibbonInputDensity))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon input density.');
  FDensity := AValue;
end;

function TRibbonInputGuard.PanSlop: Single;
begin
  { Gesture recognition distances in logical units, independent from layout
    breakpoints and from raster/scene DPI. }
  if FDensity = ridTouch then Result := 8 else Result := 4;
end;

procedure TRibbonInputGuard.InstallFocusHook;
var
  Handler: TNotifyEvent;
begin
  if (FControl = nil) or (csDestroying in FControl.ComponentState) then Exit;
  { Called only by construction. Outer popup hooks may forward this handler;
    later pointer upgrades must never recapture that outer wrapper. }
  FPreviousEnter := FControl.OnEnter;
  Handler := HookEnter;
  FControl.OnEnter := Handler;
end;

procedure TRibbonInputGuard.InstallPointerHooks;
var
  Access: TRibbonControlAccess;
  DownHandler, UpHandler: TMouseEvent;
  MoveHandler: TMouseMoveEvent;
  KeyHandler: TKeyEvent;
begin
  if FPointerHooksInstalled then Exit;
  if (FControl = nil) or (csDestroying in FControl.ComponentState) then Exit;
  Access := TRibbonControlAccess(FControl);
  DownHandler := HookDown;
  MoveHandler := HookMove;
  UpHandler := HookUp;
  KeyHandler := HookKey;
  if not EqualMethods(TMethod(Access.OnMouseDown), TMethod(DownHandler)) then
  begin
    FPreviousDown := Access.OnMouseDown;
    Access.OnMouseDown := DownHandler;
  end;
  if not EqualMethods(TMethod(Access.OnMouseMove), TMethod(MoveHandler)) then
  begin
    FPreviousMove := Access.OnMouseMove;
    Access.OnMouseMove := MoveHandler;
  end;
  if not EqualMethods(TMethod(Access.OnMouseUp), TMethod(UpHandler)) then
  begin
    FPreviousUp := Access.OnMouseUp;
    Access.OnMouseUp := UpHandler;
  end;
  if not EqualMethods(TMethod(Access.OnKeyDown), TMethod(KeyHandler)) then
  begin
    FPreviousKey := Access.OnKeyDown;
    Access.OnKeyDown := KeyHandler;
  end;
  FPointerHooksInstalled := True;
end;

procedure TRibbonInputGuard.RemoveHooks;
var
  Access: TRibbonControlAccess;
  DownHandler, UpHandler: TMouseEvent;
  MoveHandler: TMouseMoveEvent;
  KeyHandler: TKeyEvent;
  EnterHandler: TNotifyEvent;
begin
  if (FControl = nil) or (csDestroying in FControl.ComponentState) then Exit;
  Access := TRibbonControlAccess(FControl);
  DownHandler := HookDown;
  MoveHandler := HookMove;
  UpHandler := HookUp;
  KeyHandler := HookKey;
  EnterHandler := HookEnter;
  if EqualMethods(TMethod(Access.OnMouseDown), TMethod(DownHandler)) then
    Access.OnMouseDown := FPreviousDown;
  if EqualMethods(TMethod(Access.OnMouseMove), TMethod(MoveHandler)) then
    Access.OnMouseMove := FPreviousMove;
  if EqualMethods(TMethod(Access.OnMouseUp), TMethod(UpHandler)) then
    Access.OnMouseUp := FPreviousUp;
  if EqualMethods(TMethod(Access.OnKeyDown), TMethod(KeyHandler)) then
    Access.OnKeyDown := FPreviousKey;
  if EqualMethods(TMethod(Access.OnEnter), TMethod(EnterHandler)) then
    Access.OnEnter := FPreviousEnter;
end;

procedure TRibbonInputGuard.Cancel;
begin
  if FLifetime <> nil then FLifetime.Advance;
  FPointerDown := False;
  FPanned := False;
  FManualPan := False;
  WatchScroll(nil);
end;

procedure TRibbonInputGuard.BeginPointer(Button: TMouseButton; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then Exit;
  if (FControl = nil) or (csDestroying in FControl.ComponentState) then Exit;
  InstallPointerHooks;
  { Native subclasses may announce before inherited MouseDown so selection
    notifications already see a down session. The chained event is a no-op. }
  if FPointerDown then Exit;
  ResetAncestorInput(FControl, False);
  FLifetime.Advance;
  FPointerDown := True;
  FPanned := False;
  FManualPan := False;
  FOriginAbsolute := FControl.LocalToAbsolute(PointF(X, Y));
  WatchScroll(NearestScroll(FControl));
  FStartViewport := PointF(0, 0);
  if FScroll <> nil then FStartViewport := FScroll.ViewportPosition;
end;

procedure TRibbonInputGuard.MovePointer(X, Y: Single);
var
  AbsolutePoint, OriginLocal, CurrentLocal, Offset: TPointF;
  DeltaX, DeltaY, LimitX, LimitY, Slop: Single;
  Scroll: TCustomScrollBox;
  Token: IRibbonInputLifetime;
  Session: UInt64;
begin
  if not FPointerDown or (FControl = nil) then Exit;
  Token := FLifetime;
  Session := Token.GetSession;
  AbsolutePoint := FControl.LocalToAbsolute(PointF(X, Y));
  Scroll := FScroll;
  if Scroll <> nil then
  begin
    OriginLocal := Scroll.AbsoluteToLocal(FOriginAbsolute);
    CurrentLocal := Scroll.AbsoluteToLocal(AbsolutePoint);
  end
  else
  begin
    OriginLocal := FOriginAbsolute;
    CurrentLocal := AbsolutePoint;
  end;
  DeltaX := CurrentLocal.X - OriginLocal.X;
  DeltaY := CurrentLocal.Y - OriginLocal.Y;
  Slop := PanSlop;
  if (Abs(DeltaX) >= Slop) or (Abs(DeltaY) >= Slop) then
  begin
    FPanned := True;
    { A scroll box already implements its own direct background gesture. A
      guard attached to that native surface only observes/cancels activation. }
    FManualPan := not (FControl is TCustomScrollBox);
  end;
  if Scroll = nil then Exit;
  if not SamePoint(Scroll.ViewportPosition, FStartViewport) then FPanned := True;
  if not FManualPan then Exit;
  { Transform scene-logical coordinates into the scroll box's logical axes.
    This also respects user transforms without multiplying by SceneScale. }
  Offset := PointF(FStartViewport.X - DeltaX, FStartViewport.Y - DeltaY);
  LimitX := Max(0, Scroll.ContentBounds.Width - Scroll.ViewportRect.Width);
  LimitY := Max(0, Scroll.ContentBounds.Height - Scroll.ViewportRect.Height);
  Offset.X := EnsureRange(Offset.X, 0, LimitX);
  Offset.Y := EnsureRange(Offset.Y, 0, LimitY);
  if not SamePoint(Scroll.ViewportPosition, Offset) then
    SetRibbonViewport(Scroll, Offset);
  { Viewport callbacks can free/reparent the native subtree or guard. Only
    detached token state may be inspected after the assignment above. }
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
end;

function TRibbonInputGuard.GetActivationAllowed: Boolean;
begin
  { A native backend can move the scroll viewport before our final mouse-up
    hook. Observe that movement even when no OnMouseMove was forwarded. }
  if FPointerDown and (FScroll <> nil) then
    if not SamePoint(FScroll.ViewportPosition, FStartViewport) then FPanned := True;
  Result := not FPanned;
end;

procedure TRibbonInputGuard.QueuePanFinished;
var
  Handler: TNotifyEvent;
  Token: IRibbonInputLifetime;
  Session: UInt64;
begin
  Handler := FOnPanFinished;
  if not Assigned(Handler) then Exit;
  Token := FLifetime;
  Session := Token.GetSession;
  TThread.ForceQueue(nil,
    procedure
    var
      Control: TControl;
    begin
      if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      Control := Token.GetControl;
      if (Control = nil) or (csDestroying in Control.ComponentState) then Exit;
      Handler(Control);
      { No control or guard access after the external callback. }
    end);
end;

procedure TRibbonInputGuard.EndPointer(X, Y: Single);
var
  Token: IRibbonInputLifetime;
  Session: UInt64;
begin
  if not FPointerDown then Exit;
  Token := FLifetime;
  Session := Token.GetSession;
  MovePointer(X, Y);
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  FPointerDown := False;
  { Preserve Panned until the next gesture/key, suppressing a trailing click.
    EndPointer is idempotent for pre-inherited + chained native mouse-up. }
  if FPanned then QueuePanFinished;
end;

procedure TRibbonInputGuard.KeyboardInput;
begin
  if FControl <> nil then ResetAncestorInput(FControl, True);
  Cancel;
end;

procedure TRibbonInputGuard.HookDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  Handler: TMouseEvent;
  Token: IRibbonInputLifetime;
begin
  Handler := FPreviousDown;
  Token := FLifetime;
  BeginPointer(Button, X, Y);
  if not Token.IsAlive then Exit;
  if Assigned(Handler) then Handler(Sender, Button, Shift, X, Y);
end;

procedure TRibbonInputGuard.HookMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
var
  Handler: TMouseMoveEvent;
  Token: IRibbonInputLifetime;
  Session: UInt64;
begin
  Handler := FPreviousMove;
  Token := FLifetime;
  Session := Token.GetSession;
  MovePointer(X, Y);
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  if Assigned(Handler) then Handler(Sender, Shift, X, Y);
end;

procedure TRibbonInputGuard.HookUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  Handler: TMouseEvent;
  Token: IRibbonInputLifetime;
  Session: UInt64;
begin
  Handler := FPreviousUp;
  Token := FLifetime;
  Session := Token.GetSession;
  if Button = TMouseButton.mbLeft then EndPointer(X, Y);
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  if Assigned(Handler) then Handler(Sender, Button, Shift, X, Y);
end;

procedure TRibbonInputGuard.HookKey(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
var
  Handler: TKeyEvent;
begin
  Handler := FPreviousKey;
  KeyboardInput;
  if Assigned(Handler) then Handler(Sender, Key, KeyChar, Shift);
end;

procedure TRibbonInputGuard.HookEnter(Sender: TObject);
var
  Handler: TNotifyEvent;
  Token: IRibbonInputLifetime;
  Session: UInt64;
begin
  Handler := FPreviousEnter;
  Token := FLifetime;
  Session := Token.GetSession;
  { A mouse down may set focus before its Click. Do not move the viewport
    underneath that pointer session. Keyboard/programmatic focus is revealed. }
  if not FPointerDown then RibbonEnsureControlVisible(FControl);
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  if Assigned(Handler) then Handler(Sender);
end;

procedure AttachRibbonInput(AControl: TControl; ADensity: TRibbonInputDensity);
begin
  EnsureRibbonInput(AControl, ADensity);
end;

procedure AttachRibbonFocus(AControl: TControl);
begin
  if (AControl = nil) or (csDestroying in AControl.ComponentState) then Exit;
  if FindGuard(AControl) = nil then
    TRibbonInputGuard.CreateForControl(AControl, ridPointer, False);
end;

function EnsureRibbonInput(AControl: TControl;
  ADensity: TRibbonInputDensity): TRibbonInputGuard;
begin
  Result := FindGuard(AControl);
  if (AControl = nil) or (csDestroying in AControl.ComponentState) then Exit;
  if Result = nil then
    Result := TRibbonInputGuard.CreateForControl(AControl, ADensity)
  else
  begin
    { Install once. An outer popup hook may already forward our original
      callback; recapturing that outer wrapper would create a hook cycle. }
    Result.Density := ADensity;
    Result.InstallPointerHooks;
  end;
end;

function RibbonActivationAllowed(AControl: TControl): Boolean;
var
  Guard: TRibbonInputGuard;
begin
  Guard := FindGuard(AControl);
  Result := (Guard = nil) or Guard.ActivationAllowed;
end;

function RibbonPointerIsDown(AControl: TControl): Boolean;
var
  Guard: TRibbonInputGuard;
begin
  Guard := FindGuard(AControl);
  Result := (Guard <> nil) and Guard.PointerDown;
end;

procedure RibbonBeginPointer(AControl: TControl; Button: TMouseButton;
  X, Y: Single);
var
  Guard: TRibbonInputGuard;
begin
  Guard := FindGuard(AControl);
  if Guard = nil then Guard := EnsureRibbonInput(AControl, ridPointer);
  if Guard <> nil then Guard.BeginPointer(Button, X, Y);
end;

procedure RibbonEndPointer(AControl: TControl; X, Y: Single);
var
  Guard: TRibbonInputGuard;
begin
  Guard := FindGuard(AControl);
  if Guard <> nil then Guard.EndPointer(X, Y);
end;

procedure RibbonKeyboardInput(AControl: TControl);
var
  Guard: TRibbonInputGuard;
begin
  Guard := FindGuard(AControl);
  if Guard <> nil then Guard.KeyboardInput
  else ResetAncestorInput(AControl, True);
end;

procedure RibbonEnsureControlVisible(AControl: TControl);
var
  Scroll: TCustomScrollBox;
  Viewport: TControl;
  Bounds: TRectF;
  Corner, Offset: TPointF;
  ViewWidth, ViewHeight, LimitX, LimitY: Single;
  I: Integer;
begin
  if (AControl = nil) or (csDestroying in AControl.ComponentState) then Exit;
  Scroll := NearestScroll(AControl);
  if (Scroll = nil) or (Scroll = AControl) then Exit;
  Viewport := TRibbonScrollAccess(Scroll).ContentLayout;
  if Viewport = nil then Exit;
  ViewWidth := Scroll.ViewportRect.Width;
  ViewHeight := Scroll.ViewportRect.Height;
  if (ViewWidth <= 0) or (ViewHeight <= 0) then Exit;
  { FMX can defer the visual content translation within one animation tick.
    Measure in stable content coordinates and subtract the logical viewport,
    otherwise repeated focus requests accumulate the same offset twice. }
  Viewport := TRibbonScrollAccess(Scroll).Content;
  if Viewport = nil then Exit;
  Offset := Scroll.ViewportPosition;
  Corner := Viewport.AbsoluteToLocal(AControl.LocalToAbsolute(PointF(0, 0))) - Offset;
  Bounds := RectF(Corner.X, Corner.Y, Corner.X, Corner.Y);
  for I := 1 to 3 do
  begin
    case I of
      1: Corner := PointF(AControl.Width, 0);
      2: Corner := PointF(AControl.Width, AControl.Height);
    else
      Corner := PointF(0, AControl.Height);
    end;
    Corner := Viewport.AbsoluteToLocal(AControl.LocalToAbsolute(Corner)) - Offset;
    Bounds.Left := Min(Bounds.Left, Corner.X);
    Bounds.Top := Min(Bounds.Top, Corner.Y);
    Bounds.Right := Max(Bounds.Right, Corner.X);
    Bounds.Bottom := Max(Bounds.Bottom, Corner.Y);
  end;
  Offset := Scroll.ViewportPosition;
  if (Bounds.Width >= ViewWidth) or (Bounds.Left < 0) then
    Offset.X := Offset.X + Bounds.Left
  else if Bounds.Right > ViewWidth then
    Offset.X := Offset.X + Bounds.Right - ViewWidth;
  if (Bounds.Height >= ViewHeight) or (Bounds.Top < 0) then
    Offset.Y := Offset.Y + Bounds.Top
  else if Bounds.Bottom > ViewHeight then
    Offset.Y := Offset.Y + Bounds.Bottom - ViewHeight;
  LimitX := Max(0, Scroll.ContentBounds.Width - ViewWidth);
  LimitY := Max(0, Scroll.ContentBounds.Height - ViewHeight);
  Offset.X := EnsureRange(Offset.X, 0, LimitX);
  Offset.Y := EnsureRange(Offset.Y, 0, LimitY);
  if not SamePoint(Scroll.ViewportPosition, Offset) then
    SetRibbonViewport(Scroll, Offset);
  { A viewport observer may destroy the complete subtree. This is deliberately
    the final action; callers with continuations use a detached token. }
end;

function BeginNativePointer(AControl: TControl; Button: TMouseButton;
  X, Y: Single): Boolean;
var
  Guard: TRibbonInputGuard;
  Token: IRibbonInputLifetime;
begin
  Guard := FindGuard(AControl);
  if Guard = nil then Guard := EnsureRibbonInput(AControl, ridPointer);
  if Guard = nil then Exit(False);
  Token := Guard.Lifetime;
  Guard.BeginPointer(Button, X, Y);
  Result := Token.IsAlive;
end;

function EndNativePointer(AControl: TControl; Button: TMouseButton;
  X, Y: Single): Boolean;
var
  Guard: TRibbonInputGuard;
  Token: IRibbonInputLifetime;
  Session: UInt64;
begin
  Guard := FindGuard(AControl);
  if Guard = nil then Exit(True);
  Token := Guard.Lifetime;
  Session := Token.GetSession;
  if Button = TMouseButton.mbLeft then Guard.EndPointer(X, Y);
  Result := Token.IsAlive and (Token.GetSession = Session);
end;

constructor TRibbonInputButton.Create(AOwner: TComponent);
begin
  FRibbonStyleRole := rsrSmallButton;
  inherited;
  FNativeDisabledOpacity := DisabledOpacity;
  FStyleReady := True;
end;

procedure TRibbonInputButton.SetRibbonStyleRole(const AValue: TRibbonStyleRole);
begin
  if (Ord(AValue) < Ord(Low(TRibbonStyleRole))) or
     (Ord(AValue) > Ord(High(TRibbonStyleRole))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon style role.');
  if FRibbonStyleRole = AValue then Exit;
  FRibbonStyleRole := AValue;
  { The caller's explicit StyleLookup remains authoritative. }
  NeedStyleLookup;
end;

function TRibbonInputButton.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Exit(Context.ResolveRibbonStyle(Self, FRibbonStyleRole, AClone));
  Result := TStyledControl.LookupStyleObject(Self, Self, Scene, StyleLookup,
    'buttonstyle', ParentClassStyleLookupName, AClone, True);
end;

function TRibbonInputButton.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonInputButton.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

procedure TRibbonInputButton.UpdateThemeEnabled;
begin
  { Generated themes carry opaque disabled colors; a second native opacity
    blend would reduce their intended text/background contrast. }
  UpdateRibbonControlThemeEnabled(Self, FNativeDisabledOpacity, FStyleReady);
end;

procedure TRibbonInputButton.ApplyStyle;
var
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control <> nil then UpdateThemeEnabled;
  finally
    Watch.Free;
  end;
end;

procedure TRibbonInputButton.RecalcEnabled;
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
    if Watch.Control <> nil then UpdateThemeEnabled;
  finally
    Watch.Free;
  end;
end;

function TRibbonInputButton.GetDefaultStyleLookupName: string;
begin
  Result := 'buttonstyle';
end;

procedure TRibbonInputButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  if BeginNativePointer(Self, Button, X, Y) then
    inherited MouseDown(Button, Shift, X, Y);
end;

procedure TRibbonInputButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  if EndNativePointer(Self, Button, X, Y) then
    inherited MouseUp(Button, Shift, X, Y);
end;

procedure TRibbonInputButton.KeyDown(var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  RibbonKeyboardInput(Self);
  inherited KeyDown(Key, KeyChar, Shift);
end;

constructor TRibbonInputCheckBox.Create(AOwner: TComponent);
begin
  inherited;
  FNativeDisabledOpacity := DisabledOpacity;
  FStyleReady := True;
end;

procedure TRibbonInputCheckBox.ApplyStyle;
var
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control <> nil then
      UpdateRibbonControlThemeEnabled(Self, FNativeDisabledOpacity, FStyleReady);
  finally
    Watch.Free;
  end;
end;

procedure TRibbonInputCheckBox.RecalcEnabled;
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
    if Watch.Control <> nil then
      UpdateRibbonControlThemeEnabled(Self, FNativeDisabledOpacity, FStyleReady);
  finally
    Watch.Free;
  end;
end;

function TRibbonInputCheckBox.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Exit(Context.ResolveRibbonStyle(Self, rsrCheckBox, AClone));
  Result := TStyledControl.LookupStyleObject(Self, Self, Scene, StyleLookup,
    'checkboxstyle', ParentClassStyleLookupName, AClone, True);
end;

function TRibbonInputCheckBox.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonInputCheckBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonInputCheckBox.GetDefaultStyleLookupName: string;
begin
  Result := 'checkboxstyle';
end;

procedure TRibbonInputCheckBox.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  if BeginNativePointer(Self, Button, X, Y) then
    inherited MouseDown(Button, Shift, X, Y);
end;

procedure TRibbonInputCheckBox.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  if EndNativePointer(Self, Button, X, Y) then
    inherited MouseUp(Button, Shift, X, Y);
end;

procedure TRibbonInputCheckBox.KeyDown(var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  RibbonKeyboardInput(Self);
  inherited KeyDown(Key, KeyChar, Shift);
end;

constructor TRibbonInputRadioButton.Create(AOwner: TComponent);
begin
  inherited;
  FNativeDisabledOpacity := DisabledOpacity;
  FStyleReady := True;
end;

procedure TRibbonInputRadioButton.ApplyStyle;
var
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control <> nil then
      UpdateRibbonControlThemeEnabled(Self, FNativeDisabledOpacity, FStyleReady);
  finally
    Watch.Free;
  end;
end;

procedure TRibbonInputRadioButton.RecalcEnabled;
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
    if Watch.Control <> nil then
      UpdateRibbonControlThemeEnabled(Self, FNativeDisabledOpacity, FStyleReady);
  finally
    Watch.Free;
  end;
end;

function TRibbonInputRadioButton.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Exit(Context.ResolveRibbonStyle(Self, rsrRadioButton, AClone));
  Result := TStyledControl.LookupStyleObject(Self, Self, Scene, StyleLookup,
    'radiobuttonstyle', ParentClassStyleLookupName, AClone, True);
end;

function TRibbonInputRadioButton.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonInputRadioButton.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonInputRadioButton.GetDefaultStyleLookupName: string;
begin
  Result := 'radiobuttonstyle';
end;

procedure TRibbonInputRadioButton.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if BeginNativePointer(Self, Button, X, Y) then
    inherited MouseDown(Button, Shift, X, Y);
end;

procedure TRibbonInputRadioButton.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if EndNativePointer(Self, Button, X, Y) then
    inherited MouseUp(Button, Shift, X, Y);
end;

procedure TRibbonInputRadioButton.KeyDown(var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  RibbonKeyboardInput(Self);
  inherited KeyDown(Key, KeyChar, Shift);
end;

end.
