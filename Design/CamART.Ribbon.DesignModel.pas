unit CamART.Ribbon.DesignModel;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  CamART.Ribbon.Types,
  CamART.Ribbon.Model,
  CamART.Ribbon.Control;

type
  ERibbonDesignError = class(Exception);

  TRibbonDesignNodeKind = (rdnTab, rdnGroup, rdnButton, rdnSeparator,
    rdnLabel, rdnEdit, rdnComboBox, rdnColorPicker, rdnFontPicker,
    rdnFontSizePicker, rdnGallery, rdnCheckBox, rdnRadioButton,
    rdnProgressBar, rdnDropDownMenu, rdnSkLabel);

  { Design-only operation policy, kept independent of DesignIntf so native
    acceptance tests can exercise the exact ownership/reference code. It is
    not included in any runtime package. IDs, not borrowed tree pointers, are
    the interface between the editor window and this policy. }
  TRibbonDesignOperations = class sealed
  public
    class function KindName(AKind: TRibbonDesignNodeKind): string; static;
    class function Add(ARibbon: TCamARTRibbon; const AParentId: string;
      AKind: TRibbonDesignNodeKind; const AOnModified: TProc = nil): string; static;
    class function Move(ARibbon: TCamARTRibbon; const AId: string;
      AOffset: Integer; const AOnModified: TProc = nil): Boolean; static;
    class procedure CheckCanDelete(ARibbon: TCamARTRibbon;
      const AId: string); static;
    class function Delete(ARibbon: TCamARTRibbon;
      const AId: string; const AOnModified: TProc = nil): Boolean; static;
    class function ApplyNode(ARibbon: TCamARTRibbon; const AId,
      ACaption, AIconKey: string; AEnabled, AVisible: Boolean;
      AStyle: TRibbonButtonStyle; const AOnModified: TProc = nil): Boolean; static;
    class function RibbonFor(AObject: TPersistent): TCamARTRibbon; static;
    class procedure CollectIconKeys(ARibbon: TCamARTRibbon;
      AKeys: TStrings); static;
  end;

implementation

uses
  System.Generics.Collections,
  CamART.Ribbon.References;

type
  TPersistentAccess = class(TPersistent);

  TDesignLifetime = class(TComponent)
  private
    FRoot: TCamARTRibbon;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateFor(ARoot: TCamARTRibbon);
    destructor Destroy; override;
    property Root: TCamARTRibbon read FRoot;
  end;

constructor TDesignLifetime.CreateFor(ARoot: TCamARTRibbon);
begin
  inherited Create(nil);
  FRoot := ARoot;
  TComponent(FRoot).FreeNotification(Self);
end;

destructor TDesignLifetime.Destroy;
begin
  if FRoot <> nil then TComponent(FRoot).RemoveFreeNotification(Self);
  inherited;
end;

procedure TDesignLifetime.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FRoot) then FRoot := nil;
end;

procedure RequireRibbon(ARibbon: TCamARTRibbon);
begin
  if (ARibbon = nil) or (csDestroying in ARibbon.ComponentState) then
    raise ERibbonDesignError.Create('The Ribbon is no longer available.');
end;

procedure RequireMutable(ANode: TComponent);
begin
  if (ANode = nil) or (csDestroying in ANode.ComponentState) then
    raise ERibbonDesignError.Create('The selected component is no longer available.');
  if csAncestor in ANode.ComponentState then
    raise ERibbonDesignError.Create(
      'Change this inherited component in its ancestor form.');
end;

function RequireNode(ARibbon: TCamARTRibbon; const AId: string): TRibbonNode;
begin
  RequireRibbon(ARibbon);
  Result := ARibbon.Model.FindNodeById(AId);
  if Result = nil then
    raise ERibbonDesignError.Create('Select an existing Ribbon node.');
end;

function ItemClassFor(AKind: TRibbonDesignNodeKind): TRibbonItemClass;
begin
  case AKind of
    rdnButton: Result := TRibbonButton;
    rdnSeparator: Result := TRibbonSeparator;
    rdnLabel: Result := TRibbonLabel;
    rdnEdit: Result := TRibbonEdit;
    rdnComboBox: Result := TRibbonComboBox;
    rdnColorPicker: Result := TRibbonColorPicker;
    rdnFontPicker: Result := TRibbonFontPicker;
    rdnFontSizePicker: Result := TRibbonFontSizePicker;
    rdnGallery: Result := TRibbonGallery;
    rdnCheckBox: Result := TRibbonCheckBox;
    rdnRadioButton: Result := TRibbonRadioButton;
    rdnProgressBar: Result := TRibbonProgressBar;
    rdnDropDownMenu: Result := TRibbonDropDownMenu;
    rdnSkLabel: Result := TRibbonSkLabel;
  else
    raise ERibbonDesignError.Create('The selected kind is not an item.');
  end;
end;

class function TRibbonDesignOperations.KindName(
  AKind: TRibbonDesignNodeKind): string;
begin
  case AKind of
    rdnTab: Result := 'Tab';
    rdnGroup: Result := 'Group';
    rdnButton: Result := 'Button';
    rdnSeparator: Result := 'Separator';
    rdnLabel: Result := 'Label';
    rdnEdit: Result := 'Edit';
    rdnComboBox: Result := 'ComboBox';
    rdnColorPicker: Result := 'ColorPicker';
    rdnFontPicker: Result := 'FontPicker';
    rdnFontSizePicker: Result := 'FontSizePicker';
    rdnGallery: Result := 'Gallery';
    rdnCheckBox: Result := 'CheckBox';
    rdnRadioButton: Result := 'RadioButton';
    rdnProgressBar: Result := 'ProgressBar';
    rdnDropDownMenu: Result := 'DropDownMenu';
    rdnSkLabel: Result := 'SkLabel';
  else
    raise ERibbonDesignError.Create('Unknown editor item kind.');
  end;
end;

class function TRibbonDesignOperations.Add(ARibbon: TCamARTRibbon;
  const AParentId: string; AKind: TRibbonDesignNodeKind;
  const AOnModified: TProc): string;
var
  ParentNode, NewNode: TRibbonNode;
  Guard: TDesignLifetime;
begin
  RequireRibbon(ARibbon);
  ParentNode := nil;
  if AKind = rdnTab then
  begin
    if AParentId <> '' then
      raise ERibbonDesignError.Create('Select the Ribbon root before adding a tab.');
    RequireMutable(ARibbon);
  end
  else
  begin
    ParentNode := RequireNode(ARibbon, AParentId);
    RequireMutable(ParentNode);
    if ((AKind = rdnGroup) and not (ParentNode is TRibbonTab)) or
       ((AKind <> rdnGroup) and not (ParentNode is TRibbonGroup)) then
      raise ERibbonDesignError.Create(
        'Groups belong to tabs; items belong to groups. Select their parent.');
  end;
  Guard := TDesignLifetime.CreateFor(ARibbon);
  try
    ARibbon.BeginUpdate;
    try
      case AKind of
        rdnTab: NewNode := ARibbon.AddTab('New tab');
        rdnGroup: NewNode := TRibbonTab(ParentNode).AddGroup('New group');
      else
        NewNode := TRibbonGroup(ParentNode).AddItem(ItemClassFor(AKind),
          KindName(AKind));
      end;
      { The model generates a permanent ID and globally improbable component
        name. Do not rename an existing node or use captions as identity. }
      Result := NewNode.Id;
      if Assigned(AOnModified) then AOnModified;
    finally
      if Guard.Root <> nil then Guard.Root.EndUpdate;
    end;
  finally
    Guard.Free;
  end;
end;

class function TRibbonDesignOperations.Move(ARibbon: TCamARTRibbon;
  const AId: string; AOffset: Integer; const AOnModified: TProc): Boolean;
var
  Node: TRibbonNode;
  Count, NewOrder: Integer;
  Guard: TDesignLifetime;
begin
  Result := False;
  Node := RequireNode(ARibbon, AId);
  RequireMutable(Node);
  if (AOffset <> -1) and (AOffset <> 1) then
    raise ERibbonDesignError.Create('Reorder offset must be -1 or 1.');
  if Node is TRibbonTab then Count := Length(ARibbon.Model.Tabs)
  else if Node is TRibbonGroup then
    Count := Length(TRibbonTab(Node.Owner).Groups)
  else Count := Length(TRibbonGroup(Node.Owner).Items);
  NewOrder := Node.Order + AOffset;
  if (NewOrder < 0) or (NewOrder >= Count) then Exit;
  Guard := TDesignLifetime.CreateFor(ARibbon);
  try
    ARibbon.BeginUpdate;
    try
      Node.Order := NewOrder;
      Result := True;
      if Assigned(AOnModified) then AOnModified;
    finally
      if Guard.Root <> nil then Guard.Root.EndUpdate;
    end;
  finally
    Guard.Free;
  end;
end;

class procedure TRibbonDesignOperations.CheckCanDelete(
  ARibbon: TCamARTRibbon; const AId: string);
var
  Node: TRibbonNode;
  Ids: TDictionary<string, Byte>;
  Tab: TRibbonTab;
  Group: TRibbonGroup;
  Item: TRibbonItem;
  Button: TRibbonButton;
  procedure AddSubtree(AComponent: TComponent);
  var
    I: Integer;
    Child: TComponent;
  begin
    if AComponent is TRibbonNode then
    begin
      RequireMutable(AComponent);
      Ids.Add(TRibbonNode(AComponent).Id, 0);
    end;
    for I := 0 to AComponent.ComponentCount - 1 do
    begin
      Child := AComponent.Components[I];
      if Child is TRibbonNode then AddSubtree(Child);
    end;
  end;
  procedure CheckLinks(ALinks: TRibbonCommandLinks; const APath: string);
  var
    I: Integer;
  begin
    for I := 0 to ALinks.Count - 1 do
      if Ids.ContainsKey(ALinks[I].ItemId) then
        raise ERibbonDesignError.CreateFmt(
          'Remove reference %s[%d] to "%s" before deleting this subtree.',
          [APath, I, ALinks[I].ItemId]);
  end;
begin
  Node := RequireNode(ARibbon, AId);
  RequireMutable(Node);
  Ids := TDictionary<string, Byte>.Create;
  try
    AddSubtree(Node);
    CheckLinks(ARibbon.QuickAccess, 'QuickAccess');
    CheckLinks(ARibbon.ApplicationMenu, 'ApplicationMenu');
    for Tab in ARibbon.Model.Tabs do
      for Group in Tab.Groups do
        for Item in Group.Items do
          if (Item is TRibbonButton) and not Ids.ContainsKey(Item.Id) then
          begin
            Button := TRibbonButton(Item);
            CheckLinks(Button.MenuItems, Button.Name + '.MenuItems');
            if Ids.ContainsKey(Button.GalleryId) then
              raise ERibbonDesignError.CreateFmt(
                'Clear %s.GalleryId before deleting the referenced gallery.',
                [Button.Name]);
          end;
  finally
    Ids.Free;
  end;
end;

class function TRibbonDesignOperations.Delete(ARibbon: TCamARTRibbon;
  const AId: string; const AOnModified: TProc): Boolean;
var
  Node: TRibbonNode;
  Guard: TDesignLifetime;
begin
  CheckCanDelete(ARibbon, AId);
  Node := RequireNode(ARibbon, AId);
  Guard := TDesignLifetime.CreateFor(ARibbon);
  try
    ARibbon.BeginUpdate;
    try
      try
        Node.Free;
        Result := True;
      finally
        { Destruction can notify user components which raise after mutation.
          The source must remain dirty even in that exceptional case. }
        if Assigned(AOnModified) then AOnModified;
      end;
    finally
      if Guard.Root <> nil then Guard.Root.EndUpdate;
    end;
  finally
    Guard.Free;
  end;
end;

class function TRibbonDesignOperations.ApplyNode(ARibbon: TCamARTRibbon;
  const AId, ACaption, AIconKey: string; AEnabled, AVisible: Boolean;
  AStyle: TRibbonButtonStyle; const AOnModified: TProc): Boolean;
var
  Node: TRibbonNode;
  Guard: TDesignLifetime;
begin
  Node := RequireNode(ARibbon, AId);
  RequireMutable(Node);
  if (Ord(AStyle) < Ord(Low(TRibbonButtonStyle))) or
     (Ord(AStyle) > Ord(High(TRibbonButtonStyle))) then
    raise ERibbonDesignError.Create('Unknown button size.');
  Result := (Node.Caption <> ACaption) or (Node.IconKey <> AIconKey) or
    (Node.Enabled <> AEnabled) or (Node.Visible <> AVisible);
  if Node is TRibbonButton then
    Result := Result or (TRibbonButton(Node).ButtonStyle <> AStyle);
  if not Result then Exit;
  Guard := TDesignLifetime.CreateFor(ARibbon);
  try
    ARibbon.BeginUpdate;
    try
      Node.Caption := ACaption;
      Node.IconKey := AIconKey;
      Node.Enabled := AEnabled;
      Node.Visible := AVisible;
      if Node is TRibbonButton then TRibbonButton(Node).ButtonStyle := AStyle;
      if Assigned(AOnModified) then AOnModified;
    finally
      if Guard.Root <> nil then Guard.Root.EndUpdate;
    end;
  finally
    Guard.Free;
  end;
end;

class function TRibbonDesignOperations.RibbonFor(
  AObject: TPersistent): TCamARTRibbon;
var
  I: Integer;
begin
  Result := nil;
  { GetOwner is the documented TPersistent chain used by nested collections
    and the Object Inspector. No private RTTI or component-layout access. }
  for I := 0 to 127 do
  begin
    if AObject = nil then Exit;
    if AObject is TCamARTRibbon then Exit(TCamARTRibbon(AObject));
    AObject := TPersistentAccess(AObject).GetOwner;
  end;
end;

class procedure TRibbonDesignOperations.CollectIconKeys(
  ARibbon: TCamARTRibbon; AKeys: TStrings);
var
  Tab: TRibbonTab;
  Group: TRibbonGroup;
  Item: TRibbonItem;
  I: Integer;
  procedure AddKey(const AKey: string);
  begin
    if (AKey <> '') and (AKeys.IndexOf(AKey) < 0) then AKeys.Add(AKey);
  end;
  procedure AddLinks(ALinks: TRibbonCommandLinks);
  var
    J: Integer;
  begin
    for J := 0 to ALinks.Count - 1 do AddKey(ALinks[J].IconKey);
  end;
begin
  if (ARibbon = nil) or (AKeys = nil) then Exit;
  AddLinks(ARibbon.QuickAccess);
  AddLinks(ARibbon.ApplicationMenu);
  for Tab in ARibbon.Model.Tabs do
  begin
    AddKey(Tab.IconKey);
    for Group in Tab.Groups do
    begin
      AddKey(Group.IconKey);
      for Item in Group.Items do
      begin
        AddKey(Item.IconKey);
        if Item is TRibbonButton then AddLinks(TRibbonButton(Item).MenuItems);
        if Item is TRibbonGallery then
          for I := 0 to TRibbonGallery(Item).Entries.Count - 1 do
            AddKey(TRibbonGallery(Item).Entries[I].IconKey);
      end;
    end;
  end;
end;

end.
