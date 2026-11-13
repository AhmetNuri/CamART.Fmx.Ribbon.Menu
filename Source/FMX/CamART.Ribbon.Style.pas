unit CamART.Ribbon.Style;

{$B-}

interface

uses
  System.Classes,
  System.Types,
  FMX.Types,
  FMX.Controls,
  CamART.Ribbon.StyleContext,
  CamART.Ribbon.StyleScope;

const
  RibbonDefaultTabHeight: Single = 34;
  RibbonRootStyleName = 'camartribbonstyle';
  RibbonGroupStyleName = 'camartribbongroupstyle';

type
  TRibbonStyleContinuation = reference to function: Boolean;

  { Native popup boundary. The context is borrowed; the native popup book
    is assigned only when the service prepares a safe new opening. }
  TRibbonStyledPopup = class(TPopup, IRibbonStyleScope, IRibbonStyleSource)
  private
    FStyleContext: TRibbonStyleContext;
    procedure SetStyleContext(const AValue: TRibbonStyleContext);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    destructor Destroy; override;
    function GetRibbonStyleContext: TRibbonStyleContext;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
    function PrepareStyleBook: Boolean;
    property StyleContext: TRibbonStyleContext read FStyleContext write SetStyleContext;
  end;

  { An editor needs an activating window. A native nonactivating TPopup on
    Windows is dismissed when its TEdit text service calls SetFocus. }
  TRibbonInteractivePopup = class(TRibbonStyledPopup)
  protected
    function CreatePopupForm: TFmxObject; override;
  end;

  TRibbonStyledSeparator = class(TStyledControl, IRibbonStyleSource)
  private
    FFallback: TFmxObject;
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    destructor Destroy; override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  { References belong to FMX's current style instance. Clear must be called
    before inherited FreeStyle. This adapter never frees or reparents a part. }
  TRibbonStyleAdapter = class
  private
    FControl: TStyledControl;
    FTabStrip: TControl;
    FContent: TControl;
    FDiagnostics: string;
    function GetHasTabStripPart: Boolean;
    function GetHasContentPart: Boolean;
    function PartBounds(APart: TControl): TRectF;
  public
    constructor Create(AControl: TStyledControl);
    procedure Bind;
    procedure Clear;
    function TabStripRect: TRectF;
    function ContentRect: TRectF;
    property Diagnostics: string read FDiagnostics;
    property HasTabStripPart: Boolean read GetHasTabStripPart;
    property HasContentPart: Boolean read GetHasContentPart;
  end;

function CreateDefaultRibbonStyle: TFmxObject;
function CreateDefaultGroupStyle: TFmxObject;
{ Snapshot weak control references before applying any style. Native style
  callbacks may delete a child, the popup, or its service. False cancels the
  current open operation; the helper never frees retained logical controls. }
function ReapplyRibbonStyleTree(ARoot: TControl;
  const AStillCurrent: TRibbonStyleContinuation = nil): Boolean;

implementation

uses
  System.SysUtils,
  System.Math,
  System.UITypes,
  System.Generics.Collections,
  FMX.Edit,
  FMX.Forms,
  FMX.Layouts,
  FMX.Objects,
  CamART.Ribbon.Themes,
  CamART.Ribbon.ThemeStyles;

type
  TRibbonInteractivePopupForm = class(TCustomPopupForm)
  protected
    procedure DoDeactivate; override;
  end;

  TRibbonReapplyState = class
  public
    Watch: TRibbonStyleWatch;
    Text: string;
    SelStart, SelLength: Integer;
    Viewport: TPointF;
    HasEdit, HasScroll: Boolean;
    constructor Create(AControl: TControl);
    destructor Destroy; override;
  end;

constructor TRibbonReapplyState.Create(AControl: TControl);
begin
  inherited Create;
  Watch := TRibbonStyleWatch.Create(AControl);
  HasEdit := AControl is TEdit;
  if HasEdit then
  begin
    Text := TEdit(AControl).Text;
    SelStart := TEdit(AControl).SelStart;
    SelLength := TEdit(AControl).SelLength;
  end;
  HasScroll := AControl is TCustomScrollBox;
  if HasScroll then Viewport := TCustomScrollBox(AControl).ViewportPosition;
end;

destructor TRibbonReapplyState.Destroy;
begin
  Watch.Free;
  inherited;
end;

function ReapplyRibbonStyleTree(ARoot: TControl;
  const AStillCurrent: TRibbonStyleContinuation): Boolean;
var
  RootWatch: TRibbonStyleWatch;
  Controls: TObjectList<TRibbonReapplyState>;
  State: TRibbonReapplyState;
  I: Integer;
  procedure Collect(AObject: TFmxObject);
  var
    Child: TFmxObject;
  begin
    if AObject is TStyledControl then
      Controls.Add(TRibbonReapplyState.Create(TControl(AObject)));
    if AObject.Children <> nil then
      for Child in AObject.Children do Collect(Child);
  end;
  function Current: Boolean;
  begin
    Result := RootWatch.Control <> nil;
    if Result and Assigned(AStillCurrent) then Result := AStillCurrent();
    Result := Result and (RootWatch.Control <> nil);
  end;
begin
  Result := False;
  if (ARoot = nil) or (csDestroying in ARoot.ComponentState) then Exit;
  RootWatch := TRibbonStyleWatch.Create(ARoot);
  Controls := nil;
  try
    Controls := TObjectList<TRibbonReapplyState>.Create(True);
    Collect(ARoot);
    for State in Controls do
    begin
      if not Current then Exit;
      if State.Watch.Control = nil then Continue;
      TStyledControl(State.Watch.Control).NeedStyleLookup;
      if not Current then Exit;
      if State.Watch.Control = nil then Continue;
      TStyledControl(State.Watch.Control).ApplyStyleLookup;
    end;
    { Restore after descendants, including an editor's actual presentation,
      have completed. A callback that edits text owns that new value. Never
      assign Text, reconstruct a presentation, or move keyboard focus here. }
    for I := Controls.Count - 1 downto 0 do
    begin
      if not Current then Exit;
      State := Controls[I];
      if State.Watch.Control = nil then Continue;
      if State.HasEdit and (TEdit(State.Watch.Control).Text = State.Text) then
      begin
        TEdit(State.Watch.Control).SelStart := State.SelStart;
        if not Current then Exit;
        if State.Watch.Control = nil then Continue;
        if TEdit(State.Watch.Control).Text = State.Text then
          TEdit(State.Watch.Control).SelLength := State.SelLength;
      end;
      if not Current then Exit;
      if (State.Watch.Control <> nil) and State.HasScroll then
        TCustomScrollBox(State.Watch.Control).ViewportPosition := State.Viewport;
    end;
    Result := Current;
  finally
    Controls.Free;
    RootWatch.Free;
  end;
end;

procedure TRibbonStyledPopup.SetStyleContext(const AValue: TRibbonStyleContext);
begin
  if FStyleContext = AValue then Exit;
  if (AValue <> nil) and (csDestroying in AValue.ComponentState) then
    raise EArgumentException.Create('Cannot use a destroying Ribbon style context.');
  if FStyleContext <> nil then FStyleContext.RemoveFreeNotification(Self);
  FStyleContext := AValue;
  if FStyleContext <> nil then FStyleContext.FreeNotification(Self);
  { No FreeStyle/ApplyStyleLookup from a setter or native input callback. }
end;

destructor TRibbonStyledPopup.Destroy;
begin
  if FStyleContext <> nil then FStyleContext.RemoveFreeNotification(Self);
  FStyleContext := nil;
  inherited;
end;

procedure TRibbonStyledPopup.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FStyleContext) then
    FStyleContext := nil;
  inherited;
end;

function TRibbonStyledPopup.GetRibbonStyleContext: TRibbonStyleContext;
begin
  Result := FStyleContext;
  if (Result <> nil) and (csDestroying in Result.ComponentState) then Result := nil;
end;

function TRibbonStyledPopup.GetDefaultStyleLookupName: string;
begin
  Result := 'popupstyle';
end;

function TRibbonStyledPopup.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := GetRibbonStyleContext;
  if Context <> nil then
    Result := Context.ResolveRibbonStyle(Self, rsrPopup, AClone)
  else
    Result := TStyledControl.LookupStyleObject(Self, Self, Scene, StyleLookup,
      'popupstyle', ParentClassStyleLookupName, AClone, True);
end;

function TRibbonStyledPopup.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledPopup.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

procedure TRibbonInteractivePopupForm.DoDeactivate;
begin
  inherited;
  { Standard child dropdowns remain nonactivating; switching to another
    top-level window dismisses this modeless, borderless editor host. }
  if Visible then Close;
end;

function TRibbonInteractivePopup.CreatePopupForm: TFmxObject;
var
  Form: TRibbonInteractivePopupForm;
begin
  Form := TRibbonInteractivePopupForm.Create(Self, StyleBook, PlacementTarget, True);
  try
    Form.FormStyle := TFormStyle.Normal;
    Result := Form;
  except
    Form.Free;
    raise;
  end;
end;

function TRibbonStyledPopup.PrepareStyleBook: Boolean;
var
  Watch: TRibbonStyleWatch;
  Context: TRibbonStyleContext;
  Book: TStyleBook;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    Book := nil;
    Context := GetRibbonStyleContext;
    if Context <> nil then Book := Context.EffectiveStyleBook
    else if Scene <> nil then Book := Scene.GetStyleBook;
    StyleBook := Book;
    Result := Watch.Control <> nil;
  finally
    Watch.Free;
  end;
end;

destructor TRibbonStyledSeparator.Destroy;
begin
  FFallback.Free;
  inherited;
end;

function TRibbonStyledSeparator.GetDefaultStyleLookupName: string;
begin
  Result := RibbonThemeStyleName(rsrSeparator);
end;

function TRibbonStyledSeparator.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then Exit(Context.ResolveRibbonStyle(Self, rsrSeparator, AClone));
  Result := TStyledControl.LookupStyleObject(Self, Self, Scene, StyleLookup,
    GetDefaultStyleLookupName, ParentClassStyleLookupName, AClone, True);
  if Result <> nil then Exit;
  if FFallback = nil then FFallback := CreateRibbonThemeStyle(rsrSeparator, rtModernLight);
  Result := FFallback;
  if AClone then Result := FFallback.Clone(nil);
end;

function TRibbonStyledSeparator.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledSeparator.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function CreateDefaultRibbonStyle: TFmxObject;
begin
  Result := CreateRibbonThemeStyle(rsrRoot, rtModernLight);
end;

function CreateDefaultGroupStyle: TFmxObject;
begin
  Result := CreateRibbonThemeStyle(rsrGroup, rtModernLight);
end;

constructor TRibbonStyleAdapter.Create(AControl: TStyledControl);
begin
  inherited Create;
  if AControl = nil then
    raise EArgumentNilException.Create('Ribbon style control is required.');
  FControl := AControl;
end;

procedure TRibbonStyleAdapter.Bind;
var
  Part: TFmxObject;
begin
  Clear;
  Part := FControl.FindStyleResource('tabstrip');
  if Part is TControl then
    FTabStrip := TControl(Part)
  else
    FDiagnostics := 'Ribbon style part tabstrip is missing or is not a TControl; using measured fallback bounds.';
  Part := FControl.FindStyleResource('content');
  if Part is TControl then
    FContent := TControl(Part)
  else
  begin
    if FDiagnostics <> '' then FDiagnostics := FDiagnostics + sLineBreak;
    FDiagnostics := FDiagnostics + 'Ribbon style part content is missing or is not a TControl; using measured fallback bounds.';
  end;
end;

procedure TRibbonStyleAdapter.Clear;
begin
  FTabStrip := nil;
  FContent := nil;
  FDiagnostics := '';
end;

function TRibbonStyleAdapter.GetHasTabStripPart: Boolean;
begin
  Result := FTabStrip <> nil;
end;

function TRibbonStyleAdapter.GetHasContentPart: Boolean;
begin
  Result := FContent <> nil;
end;

function TRibbonStyleAdapter.PartBounds(APart: TControl): TRectF;
var
  P1, P2: TPointF;
begin
  P1 := FControl.AbsoluteToLocal(APart.LocalToAbsolute(PointF(0, 0)));
  P2 := FControl.AbsoluteToLocal(
    APart.LocalToAbsolute(PointF(APart.Width, APart.Height)));
  Result := RectF(Min(P1.X, P2.X), Min(P1.Y, P2.Y),
    Max(P1.X, P2.X), Max(P1.Y, P2.Y));
end;

function TRibbonStyleAdapter.TabStripRect: TRectF;
begin
  if FTabStrip <> nil then
    Exit(PartBounds(FTabStrip));
  Result := RectF(0, 0, Max(0, FControl.Width),
    Min(RibbonDefaultTabHeight, Max(0, FControl.Height)));
end;

function TRibbonStyleAdapter.ContentRect: TRectF;
var
  TabRect: TRectF;
begin
  if FContent <> nil then
    Exit(PartBounds(FContent));
  TabRect := TabStripRect;
  Result := RectF(0, TabRect.Bottom, Max(0, FControl.Width),
    Max(TabRect.Bottom, FControl.Height));
end;

end.
