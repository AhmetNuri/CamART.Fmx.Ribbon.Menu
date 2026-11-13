unit CamART.Ribbon.ReferenceBindings;

{$B-}

interface

uses
  CamART.Ribbon.Model,
  CamART.Ribbon.References,
  CamART.Ribbon.Commands,
  CamART.Ribbon.Bindings,
  CamART.Ribbon.ViewData;

type
  { A QAT/menu reference has its own visibility and enabled preference. A
    hidden/inactive source tab does not hide or disable this presentation.
    The source button's own Enabled and the common command still apply. }
  TRibbonReferenceResolver = class
  private
    FModel: TRibbonModel;
    FBindings: TRibbonBindingRegistry;
    FCommands: IRibbonCommandResolver;
  public
    constructor Create(AModel: TRibbonModel; ABindings: TRibbonBindingRegistry);
    function FindSource(AReference: TRibbonCommandLink): TRibbonButton;
    function Snapshot(AReference: TRibbonCommandLink;
      ACompact: Boolean = True): TRibbonItemViewData;
    property Commands: IRibbonCommandResolver read FCommands write FCommands;
  end;

implementation

uses
  System.SysUtils,
  CamART.Ribbon.Types;

constructor TRibbonReferenceResolver.Create(AModel: TRibbonModel;
  ABindings: TRibbonBindingRegistry);
begin
  inherited Create;
  if (AModel = nil) or (ABindings = nil) then
    raise EArgumentNilException.Create('Reference resolution requires model and bindings.');
  FModel := AModel;
  FBindings := ABindings;
end;

function TRibbonReferenceResolver.FindSource(
  AReference: TRibbonCommandLink): TRibbonButton;
begin
  Result := nil;
  if (AReference = nil) or (AReference.ItemId = '') then Exit;
  Result := FModel.FindButtonById(AReference.ItemId);
end;

function TRibbonReferenceResolver.Snapshot(AReference: TRibbonCommandLink;
  ACompact: Boolean): TRibbonItemViewData;
var
  Source: TRibbonButton;
begin
  if AReference = nil then raise EArgumentNilException.Create('A command reference is required.');
  Result := Default(TRibbonItemViewData);
  Result.Id := AReference.Id;
  Result.TypeKey := 'button';
  Result.Visible := AReference.Visible;
  Result.Enabled := False;
  Result.ButtonKind := AReference.ButtonKind;
  Result.ButtonStyle := rbsSmall;
  Result.Caption := AReference.Caption;
  Result.Hint := AReference.Hint;
  Result.IconKey := AReference.IconKey;
  if AReference.IsSeparator then
  begin
    Result.TypeKey := 'separator';
    Exit;
  end;
  if AReference.ItemId <> '' then
  begin
    Source := FindSource(AReference);
    if Source <> nil then
    begin
      Result := FBindings.Snapshot(Source, FCommands, False);
      Result.Id := AReference.Id;
      Result.TypeKey := 'button';
      Result.Visible := AReference.Visible;
      Result.Enabled := Result.Enabled and AReference.Enabled;
      Result.Caption := AReference.EffectiveCaption(Source.Caption);
      Result.Hint := AReference.EffectiveHint(Source.Hint);
      Result.IconKey := AReference.EffectiveIconKey(Source.IconKey);
    end
    else if Result.Caption = '' then
      Result.Caption := AReference.ItemId;
  end
  else if AReference.CommandId <> '' then
  begin
    { A command-only reference has no menu/gallery owner. Incomplete drafts
      are disabled until valid; Validate reports them at the stream boundary. }
    if AReference.ButtonKind in [rbkDropDown, rbkSplit, rbkGallery] then Exit;
    { Update shared command state even when this reference is locally disabled. }
    Result.Enabled := TRibbonCommandDispatcher.CanExecute(AReference.CommandId,
      FCommands, True) and AReference.Enabled;
    Result.Checked := RibbonCommandChecked(AReference.CommandId, FCommands, False);
    if Result.Caption = '' then Result.Caption := AReference.CommandId;
  end;
  if ACompact then Result.ButtonStyle := rbsIcon
  else Result.ButtonStyle := rbsSmall;
end;

end.
