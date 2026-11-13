unit CamART.Ribbon.Commands;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections;

type
  IRibbonCommand = interface
    ['{165CDAC8-F91D-49D6-9AD2-184F30AE5B78}']
    function CanExecute: Boolean;
    procedure Execute;
  end;

  { Optional read-only command state. GetChecked is a pure UI-thread query.
    The command's Execute method owns state transitions; the Ribbon must never
    toggle this state a second time. }
  IRibbonCheckState = interface
    ['{6C24D219-3796-4125-978F-93CE2D6F168F}']
    function GetChecked: Boolean;
  end;

  IRibbonCommandResolver = interface
    ['{0DBF2610-7558-476F-AAB3-E5ED03E4E7A3}']
    function TryResolve(const AId: string;
      out ACommand: IRibbonCommand): Boolean;
  end;

  IRibbonCommandRegistry = interface(IRibbonCommandResolver)
    ['{FCED93EC-0B25-4E77-A8DA-5F346E64660F}']
    procedure RegisterCommand(const AId: string;
      const ACommand: IRibbonCommand);
    procedure UnregisterCommand(const AId: string);
    procedure Clear;
  end;

  // UI-thread service. IDs are exact and case-sensitive; no hidden aliases.
  TRibbonCommandRegistry = class(TInterfacedObject, IRibbonCommandResolver,
    IRibbonCommandRegistry)
  private
    FCommands: TDictionary<string, IRibbonCommand>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterCommand(const AId: string;
      const ACommand: IRibbonCommand);
    procedure UnregisterCommand(const AId: string);
    procedure Clear;
    function TryResolve(const AId: string;
      out ACommand: IRibbonCommand): Boolean;
  end;

  TRibbonDispatchResult = (rdrExecuted, rdrDisabled, rdrUnknownCommand,
    rdrNoHandler);

  TRibbonCommandDispatcher = class sealed
  public
    class function CanExecute(const ACommandId: string;
      const AResolver: IRibbonCommandResolver;
      const AEnabled: Boolean = True): Boolean; static;
    class function Dispatch(const ACommandId: string;
      const AResolver: IRibbonCommandResolver; ASender: TObject;
      const AOnClick: TNotifyEvent;
      const AEnabled: Boolean = True): TRibbonDispatchResult; reintroduce; static;
  end;

implementation

constructor TRibbonCommandRegistry.Create;
begin
  inherited Create;
  FCommands := TDictionary<string, IRibbonCommand>.Create;
end;

destructor TRibbonCommandRegistry.Destroy;
begin
  FCommands.Free;
  inherited Destroy;
end;

procedure TRibbonCommandRegistry.RegisterCommand(const AId: string;
  const ACommand: IRibbonCommand);
begin
  if AId = '' then
    raise EArgumentException.Create('A command ID must not be empty');
  if ACommand = nil then
    raise EArgumentException.Create('A command instance is required');
  if FCommands.ContainsKey(AId) then
    raise EArgumentException.CreateFmt('Command ID "%s" is already registered',
      [AId]);
  FCommands.Add(AId, ACommand);
end;

procedure TRibbonCommandRegistry.UnregisterCommand(const AId: string);
begin
  FCommands.Remove(AId);
end;

procedure TRibbonCommandRegistry.Clear;
begin
  FCommands.Clear;
end;

function TRibbonCommandRegistry.TryResolve(const AId: string;
  out ACommand: IRibbonCommand): Boolean;
begin
  ACommand := nil;
  Result := FCommands.TryGetValue(AId, ACommand);
end;

class function TRibbonCommandDispatcher.CanExecute(const ACommandId: string;
  const AResolver: IRibbonCommandResolver; const AEnabled: Boolean): Boolean;
var
  Command: IRibbonCommand;
begin
  Result := False;
  if not AEnabled then
    Exit;
  if ACommandId = '' then
    Exit(True);
  if AResolver = nil then
    Exit;
  if not AResolver.TryResolve(ACommandId, Command) or (Command = nil) then
    Exit;
  // The local interface keeps the command alive if it unregisters itself.
  Result := Command.CanExecute;
end;

class function TRibbonCommandDispatcher.Dispatch(const ACommandId: string;
  const AResolver: IRibbonCommandResolver; ASender: TObject;
  const AOnClick: TNotifyEvent; const AEnabled: Boolean): TRibbonDispatchResult;
var
  Command: IRibbonCommand;
begin
  if not AEnabled then
    Exit(rdrDisabled);

  if ACommandId = '' then
  begin
    if not Assigned(AOnClick) then
      Exit(rdrNoHandler);
    AOnClick(ASender);
    // A callback may destroy ASender or its owner. Never access either here.
    Exit(rdrExecuted);
  end;

  if AResolver = nil then
    Exit(rdrUnknownCommand);
  if not AResolver.TryResolve(ACommandId, Command) or (Command = nil) then
    Exit(rdrUnknownCommand);
  if not Command.CanExecute then
    Exit(rdrDisabled);

  // No fallback callback for a nonempty command ID, including missing IDs.
  // Keep a local interface reference across execution. Exceptions propagate.
  Command.Execute;
  Result := rdrExecuted;
  // No post-execution sender callback: the UI owner checks liveness first.
end;

end.
