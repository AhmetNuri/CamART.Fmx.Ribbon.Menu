unit CamART.Ribbon.StyleScope;

{$B-}

interface

uses
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.Layouts,
  CamART.Ribbon.StyleContext;

type
  { A stack-owned weak observer for native callbacks that may remove the
    control. It never changes input sessions, density, or model ownership. }
  TRibbonStyleWatch = class(TComponent)
  private
    FControl: TControl;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AControl: TControl); reintroduce;
    destructor Destroy; override;
    property Control: TControl read FControl;
  end;

  { A scope supplies a borrowed context. Contexts and books never become
    model owners, and walking a native Parent chain does not change it. }
  IRibbonStyleScope = interface
    ['{21D6E6B2-B260-4FB4-A307-E9D727853C6D}']
    function GetRibbonStyleContext: TRibbonStyleContext;
  end;

  { Presented native controls can forward their real presentation lookup to
    the outer control without a global form/style-manager mutation. }
  IRibbonStyleSource = interface
    ['{9D4713E0-2319-48FD-9633-947DA7BB042D}']
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  { The popup's native Parent is outside the main Ribbon. This weak scope
    boundary gives its retained children the same selected StyleBook. }
  TRibbonStyleScopeHost = class(TLayout, IRibbonStyleScope)
  private
    FStyleContext: TRibbonStyleContext;
    procedure SetStyleContext(const AValue: TRibbonStyleContext);
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    destructor Destroy; override;
    function GetRibbonStyleContext: TRibbonStyleContext;
    property StyleContext: TRibbonStyleContext read FStyleContext
      write SetStyleContext;
  end;

function FindRibbonStyleContext(AObject: TFmxObject): TRibbonStyleContext;

implementation

uses
  System.SysUtils;

constructor TRibbonStyleWatch.Create(AControl: TControl);
begin
  inherited Create(nil);
  FControl := AControl;
  if FControl <> nil then TComponent(FControl).FreeNotification(Self);
end;

destructor TRibbonStyleWatch.Destroy;
begin
  if FControl <> nil then TComponent(FControl).RemoveFreeNotification(Self);
  inherited;
end;

procedure TRibbonStyleWatch.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FControl) then FControl := nil;
  inherited;
end;

function FindRibbonStyleContext(AObject: TFmxObject): TRibbonStyleContext;
var
  Current: TFmxObject;
  Scope: IRibbonStyleScope;
begin
  Result := nil;
  Current := AObject;
  while Current <> nil do
  begin
    if csDestroying in Current.ComponentState then Exit;
    if Supports(Current, IRibbonStyleScope, Scope) then
    begin
      { A scope boundary is authoritative even when its context was freed.
        Never leak across a closed popup into an unrelated form scope. }
      Result := Scope.GetRibbonStyleContext;
      if (Result <> nil) and (csDestroying in Result.ComponentState) then
        Result := nil;
      Exit;
    end;
    Current := Current.Parent;
  end;
end;

procedure TRibbonStyleScopeHost.SetStyleContext(const AValue: TRibbonStyleContext);
begin
  if FStyleContext = AValue then Exit;
  if FStyleContext <> nil then FStyleContext.RemoveFreeNotification(Self);
  FStyleContext := AValue;
  if FStyleContext <> nil then FStyleContext.FreeNotification(Self);
end;

destructor TRibbonStyleScopeHost.Destroy;
begin
  SetStyleContext(nil);
  inherited;
end;

procedure TRibbonStyleScopeHost.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FStyleContext) then
    FStyleContext := nil;
  inherited;
end;

function TRibbonStyleScopeHost.GetRibbonStyleContext: TRibbonStyleContext;
begin
  Result := FStyleContext;
end;

end.
