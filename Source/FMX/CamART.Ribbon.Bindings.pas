unit CamART.Ribbon.Bindings;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  CamART.Ribbon.Types,
  CamART.Ribbon.Model,
  CamART.Ribbon.Commands,
  CamART.Ribbon.ViewData;

type
  ERibbonBindingError = class(Exception);

  { A model adapter knows semantic fields, not concrete native controls.
    New item kinds register an adapter and a view without changing the layout
    engine or adding branches to the presenter's reconciliation loop. }
  IRibbonItemBinding = interface
    ['{E69388E2-80F8-448D-B8B4-CF7914744D20}']
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData);
    procedure Write(AItem: TRibbonItem; const AInput: TRibbonItemInput);
  end;

  TRibbonBindingRegistry = class
  private
    FBindings: TDictionary<string, IRibbonItemBinding>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterBinding(const ATypeKey: string;
      const ABinding: IRibbonItemBinding);
    function Snapshot(AItem: TRibbonItem;
      const AResolver: IRibbonCommandResolver;
      ARespectModelAncestors: Boolean = True): TRibbonItemViewData;
    procedure ApplyInput(AItem: TRibbonItem; const AInput: TRibbonItemInput);
  end;

function RibbonCommandChecked(const ACommandId: string;
  const AResolver: IRibbonCommandResolver; const ALocalValue: Boolean): Boolean;

implementation

type
  TBasicBinding = class(TInterfacedObject, IRibbonItemBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); virtual;
    procedure Write(AItem: TRibbonItem; const AInput: TRibbonItemInput); virtual;
  end;

  TButtonBinding = class(TBasicBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); override;
  end;

  TSeparatorBinding = class(TBasicBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); override;
  end;

  TEditBinding = class(TBasicBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); override;
    procedure Write(AItem: TRibbonItem; const AInput: TRibbonItemInput); override;
  end;

  TComboBinding = class(TBasicBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); override;
    procedure Write(AItem: TRibbonItem; const AInput: TRibbonItemInput); override;
  end;

  TColorBinding = class(TBasicBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); override;
    procedure Write(AItem: TRibbonItem; const AInput: TRibbonItemInput); override;
  end;

  TProgressBinding = class(TBasicBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); override;
  end;

  TGalleryBinding = class(TBasicBinding)
  public
    procedure Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
      var AData: TRibbonItemViewData); override;
    procedure Write(AItem: TRibbonItem; const AInput: TRibbonItemInput); override;
  end;

function RibbonCommandChecked(const ACommandId: string;
  const AResolver: IRibbonCommandResolver; const ALocalValue: Boolean): Boolean;
var
  Command: IRibbonCommand;
  State: IRibbonCheckState;
begin
  if ACommandId = '' then Exit(ALocalValue);
  Result := False;
  if AResolver = nil then Exit;
  if not AResolver.TryResolve(ACommandId, Command) or (Command = nil) then Exit;
  if Supports(Command, IRibbonCheckState, State) then
    Result := State.GetChecked;
end;

procedure TBasicBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
begin
  AData.ButtonStyle := rbsSmall;
end;

procedure TBasicBinding.Write(AItem: TRibbonItem; const AInput: TRibbonItemInput);
begin
  raise ERibbonBindingError.CreateFmt('Item kind %s does not accept this value input.',
    [AItem.TypeKey]);
end;

procedure TButtonBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
var
  Button: TRibbonButton;
  CommandEnabled: Boolean;
begin
  Button := AItem as TRibbonButton;
  AData.ButtonStyle := Button.ButtonStyle;
  AData.ButtonKind := Button.ButtonKind;
  { Command state is independent from this presentation's model eligibility.
    An Action.Update must also run for a disabled main group before Checked
    is read, otherwise an independent QAT may refresh the shared state later
    in this same pass and leave the main presentation one revision behind. }
  CommandEnabled := TRibbonCommandDispatcher.CanExecute(Button.CommandId,
    AResolver, True);
  AData.Enabled := AData.Enabled and CommandEnabled;
  if Button.CommandId = '' then
    AData.Checked := Button.Checked
  else
    AData.Checked := RibbonCommandChecked(Button.CommandId, AResolver, False);
end;

procedure TSeparatorBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
begin
  AData.ButtonStyle := rbsLarge;
end;

procedure TEditBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
begin
  inherited;
  AData.Text := (AItem as TRibbonEdit).Text;
end;

procedure TEditBinding.Write(AItem: TRibbonItem; const AInput: TRibbonItemInput);
begin
  if AInput.Kind <> rikText then inherited
  else (AItem as TRibbonEdit).Text := AInput.Text;
  { No access after the model setter: OnChange may destroy the item/root. }
end;

procedure TComboBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
var
  Combo: TRibbonComboBox;
  I: Integer;
begin
  inherited;
  Combo := AItem as TRibbonComboBox;
  SetLength(AData.Choices, Combo.Items.Count);
  for I := 0 to Combo.Items.Count - 1 do AData.Choices[I] := Combo.Items[I];
  AData.ItemIndex := Combo.ItemIndex;
  AData.Text := Combo.SelectedText;
end;

procedure TComboBinding.Write(AItem: TRibbonItem; const AInput: TRibbonItemInput);
begin
  if AInput.Kind <> rikIndex then inherited
  else (AItem as TRibbonComboBox).ItemIndex := AInput.Index;
end;

procedure TColorBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
begin
  inherited;
  AData.Color := (AItem as TRibbonColorPicker).Color;
end;

procedure TColorBinding.Write(AItem: TRibbonItem; const AInput: TRibbonItemInput);
begin
  if AInput.Kind <> rikColor then inherited
  else (AItem as TRibbonColorPicker).Color := AInput.Color;
end;

procedure TProgressBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
var
  Progress: TRibbonProgressBar;
begin
  inherited;
  Progress := AItem as TRibbonProgressBar;
  AData.Minimum := Progress.Min;
  AData.Maximum := Progress.Max;
  AData.Value := Progress.Value;
end;

procedure TGalleryBinding.Read(AItem: TRibbonItem; const AResolver: IRibbonCommandResolver;
  var AData: TRibbonItemViewData);
var
  Gallery: TRibbonGallery;
  Entry: TRibbonGalleryEntry;
  I, N: Integer;
begin
  Gallery := AItem as TRibbonGallery;
  AData.ButtonStyle := rbsLarge;
  AData.SelectedId := Gallery.SelectedId;
  SetLength(AData.GalleryEntries, Gallery.Entries.Count);
  N := 0;
  for I := 0 to Gallery.Entries.Count - 1 do
  begin
    Entry := Gallery.Entries[I];
    if not Entry.Visible then Continue;
    AData.GalleryEntries[N].Id := Entry.Id;
    AData.GalleryEntries[N].Caption := Entry.Caption;
    AData.GalleryEntries[N].IconKey := Entry.IconKey;
    AData.GalleryEntries[N].Enabled := TRibbonCommandDispatcher.CanExecute(
      Entry.CommandId, AResolver, Entry.Enabled);
    AData.GalleryEntries[N].Visible := True;
    Inc(N);
  end;
  SetLength(AData.GalleryEntries, N);
end;

procedure TGalleryBinding.Write(AItem: TRibbonItem; const AInput: TRibbonItemInput);
begin
  if AInput.Kind <> rikGallerySelect then inherited
  else (AItem as TRibbonGallery).SelectedId := AInput.SelectedId;
end;

constructor TRibbonBindingRegistry.Create;
begin
  inherited;
  FBindings := TDictionary<string, IRibbonItemBinding>.Create;
  RegisterBinding('button', TButtonBinding.Create);
  RegisterBinding('checkbox', TButtonBinding.Create);
  RegisterBinding('radio', TButtonBinding.Create);
  RegisterBinding('dropdownmenu', TButtonBinding.Create);
  RegisterBinding('separator', TSeparatorBinding.Create);
  RegisterBinding('label', TBasicBinding.Create);
  RegisterBinding('edit', TEditBinding.Create);
  RegisterBinding('combo', TComboBinding.Create);
  RegisterBinding('fontpicker', TComboBinding.Create);
  RegisterBinding('fontsizepicker', TComboBinding.Create);
  RegisterBinding('colorpicker', TColorBinding.Create);
  RegisterBinding('progress', TProgressBinding.Create);
  RegisterBinding('gallery', TGalleryBinding.Create);
end;

destructor TRibbonBindingRegistry.Destroy;
begin
  FBindings.Free;
  inherited;
end;

procedure TRibbonBindingRegistry.RegisterBinding(const ATypeKey: string;
  const ABinding: IRibbonItemBinding);
begin
  if (ATypeKey = '') or (ABinding = nil) then
    raise EArgumentException.Create('A nonempty item key and binding are required.');
  FBindings.AddOrSetValue(ATypeKey, ABinding);
end;

function TRibbonBindingRegistry.Snapshot(AItem: TRibbonItem;
  const AResolver: IRibbonCommandResolver;
  ARespectModelAncestors: Boolean): TRibbonItemViewData;
var
  Binding: IRibbonItemBinding;
begin
  if AItem = nil then raise EArgumentNilException.Create('An item is required.');
  if not FBindings.TryGetValue(AItem.TypeKey, Binding) then
    raise ERibbonBindingError.CreateFmt('No model binding for %s.', [AItem.TypeKey]);
  Result := Default(TRibbonItemViewData);
  Result.Id := AItem.Id;
  Result.TypeKey := AItem.TypeKey;
  Result.Caption := AItem.Caption;
  Result.Hint := AItem.Hint;
  Result.IconKey := AItem.IconKey;
  if ARespectModelAncestors then
  begin
    Result.Enabled := AItem.EffectiveEnabled;
    Result.Visible := AItem.EffectiveVisible;
  end
  else
  begin
    Result.Enabled := AItem.Enabled;
    Result.Visible := True;
  end;
  Result.ItemIndex := -1;
  Binding.Read(AItem, AResolver, Result);
end;

procedure TRibbonBindingRegistry.ApplyInput(AItem: TRibbonItem;
  const AInput: TRibbonItemInput);
var
  Binding: IRibbonItemBinding;
begin
  if AItem = nil then raise EArgumentNilException.Create('An item is required.');
  if not FBindings.TryGetValue(AItem.TypeKey, Binding) then
    raise ERibbonBindingError.CreateFmt('No model binding for %s.', [AItem.TypeKey]);
  Binding.Write(AItem, AInput);
  { The retained binding survives an external callback that destroys its
    registry; no registry/item fields are read after that callback. }
end;

end.
