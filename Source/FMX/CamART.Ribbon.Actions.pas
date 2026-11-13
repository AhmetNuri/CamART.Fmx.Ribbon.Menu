unit CamART.Ribbon.Actions;

{$B-}

interface

uses
  System.Classes,
  FMX.ActnList,
  CamART.Ribbon.Commands;

type
  { The adapter owns its observer, never the action. Keep the adapter through
    IRibbonCommand, normally in the Ribbon command registry. It must be used
    on the FMX UI thread. Action.OnUpdate may update action state; it must not
    mutate the Ribbon model while a presentation snapshot is being measured. }
  TRibbonActionCommand = class(TInterfacedObject, IRibbonCommand,
    IRibbonCheckState)
  private
    FAction: TCustomAction;
    FObserver: TComponent;
    procedure ActionRemoved(AComponent: TComponent);
  public
    constructor Create(AAction: TCustomAction);
    destructor Destroy; override;
    function CanExecute: Boolean;
    procedure Execute;
    function GetChecked: Boolean;
  end;

function RibbonActionCommand(AAction: TCustomAction): IRibbonCommand;

implementation

uses
  System.SysUtils;

type
  TRibbonActionObserver = class(TComponent)
  private
    FCommand: TRibbonActionCommand;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateObserver(ACommand: TRibbonActionCommand);
  end;

constructor TRibbonActionObserver.CreateObserver(ACommand: TRibbonActionCommand);
begin
  inherited Create(nil);
  FCommand := ACommand;
end;

procedure TRibbonActionObserver.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if Operation = opRemove then FCommand.ActionRemoved(AComponent);
  inherited;
end;

constructor TRibbonActionCommand.Create(AAction: TCustomAction);
begin
  inherited Create;
  if AAction = nil then
    raise EArgumentNilException.Create('An FMX action is required.');
  if csDestroying in AAction.ComponentState then
    raise EArgumentException.Create('Cannot bind a destroying action.');
  FObserver := TRibbonActionObserver.CreateObserver(Self);
  FAction := AAction;
  FAction.FreeNotification(FObserver);
end;

destructor TRibbonActionCommand.Destroy;
begin
  if FAction <> nil then FAction.RemoveFreeNotification(FObserver);
  FObserver.Free;
  inherited;
end;

procedure TRibbonActionCommand.ActionRemoved(AComponent: TComponent);
begin
  if AComponent = FAction then FAction := nil;
end;

function TRibbonActionCommand.CanExecute: Boolean;
var
  KeepAlive: IRibbonCommand;
  Action: TCustomAction;
begin
  KeepAlive := Self;
  Result := False;
  Action := FAction;
  if Action = nil then Exit;
  if csDestroying in Action.ComponentState then Exit;
  Action.Update;
  { OnUpdate may destroy the action or unregister this adapter. Re-read the
    weak reference, with KeepAlive retaining the observer through this call. }
  Action := FAction;
  if Action = nil then Exit;
  if csDestroying in Action.ComponentState then Exit;
  Result := Action.Enabled;
end;

procedure TRibbonActionCommand.Execute;
var
  KeepAlive: IRibbonCommand;
  Action: TCustomAction;
begin
  KeepAlive := Self;
  Action := FAction;
  if Action = nil then Exit;
  if csDestroying in Action.ComponentState then Exit;
  { FMX TCustomAction.Execute performs Update and its execution path owns
    AutoCheck/Checked semantics. Calling OnExecute directly or toggling here
    would bypass or duplicate those native semantics. }
  Action.Execute;
  { No action access after user code. The dispatcher owns post-execute events. }
end;

function TRibbonActionCommand.GetChecked: Boolean;
begin
  Result := False;
  if FAction = nil then Exit;
  if csDestroying in FAction.ComponentState then Exit;
  Result := FAction.Checked;
end;

function RibbonActionCommand(AAction: TCustomAction): IRibbonCommand;
begin
  Result := TRibbonActionCommand.Create(AAction);
end;

end.
