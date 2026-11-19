unit CamART.Ribbon.TreeEditor;

{$B-}

interface

uses
  CamART.Ribbon.Control,
  DesignIntf;

procedure EditRibbonTree(ARibbon: TCamARTRibbon; const ADesigner: IDesigner);

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Layouts,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.ListBox,
  FMX.TreeView,
  CamART.Ribbon.Types,
  CamART.Ribbon.Model,
  CamART.Ribbon.Themes,
  CamART.Ribbon.DesignModel;

type
  TRibbonTreeEditorForm = class(TForm)
  private
    FRoot: TCamARTRibbon;
    FDesigner: IDesigner;
    FTree: TTreeView;
    FRight: TScrollBox;
    FStatus, FSelection: TLabel;
    FCaption, FIconKey, FIdentity: TEdit;
    FVisible, FEnabled: TCheckBox;
    FKind, FSize, FTheme: TComboBox;
    FAdd, FDelete, FUp, FDown, FApply, FThemeApply: TButton;
    FInspector: TButton;
    FBuilding, FReadOnly, FSyncing: Boolean;
    FClosing, FRefreshPending, FRestoreVisible: Boolean;
    function SelectedId: string;
    function SelectedNode: TRibbonNode;
    function AddButton(AParent: TControl; const AText: string;
      AX, AY, AW: Single; AClick: TNotifyEvent): TButton;
    function AddLabel(const AText: string; AY: Single): TLabel;
    procedure RequireWritable;
    procedure MarkModified;
    procedure BuildUI;
    procedure RebuildTree(const ASelectedId: string);
    procedure ReadSelection;
    procedure ChangedSelection(Sender: TObject);
    procedure AddClicked(Sender: TObject);
    procedure DeleteClicked(Sender: TObject);
    procedure MoveClicked(Sender: TObject);
    procedure ApplyClicked(Sender: TObject);
    procedure ThemeClicked(Sender: TObject);
    procedure InspectClicked(Sender: TObject);
    procedure CloseClicked(Sender: TObject);
    procedure ShowError(E: Exception);
    procedure Retire;
    procedure FollowDesignerSelection(const ASelection: IDesignerSelections);
    procedure RefreshFromDesigner;
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateFor(ARibbon: TCamARTRibbon; const ADesigner: IDesigner);
    destructor Destroy; override;
    procedure SelectInspectorObject;
  end;

  { The IDE boundary owns sessions, not model objects. Notifications only
    schedule structural refreshes: ItemDeleted may arrive during destruction.
    A cancellable FMX timer also disposes retired windows outside their events. }
  TRibbonTreeSessions = class(TInterfacedObject, IDesignNotification, IDesignWindow)
  private
    FEditors: TObjectList<TRibbonTreeEditorForm>;
    FTimer: TTimer;
    procedure TimerTick(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Schedule;
    procedure Open(ARibbon: TCamARTRibbon; const ADesigner: IDesigner);
    procedure ItemDeleted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemInserted(const ADesigner: IDesigner; AItem: TPersistent);
    procedure ItemsModified(const ADesigner: IDesigner);
    procedure SelectionChanged(const ADesigner: IDesigner;
      const ASelection: IDesignerSelections);
    procedure DesignerOpened(const ADesigner: IDesigner; AResurrecting: Boolean);
    procedure DesignerClosed(const ADesigner: IDesigner; AGoingDormant: Boolean);
    procedure WindowHide;
    procedure WindowShow;
  end;

var
  Sessions: TRibbonTreeSessions;
  SessionNotification: IDesignNotification;

constructor TRibbonTreeSessions.Create;
begin
  inherited;
  FEditors := TObjectList<TRibbonTreeEditorForm>.Create(True);
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := 50;
  FTimer.OnTimer := TimerTick;
end;

destructor TRibbonTreeSessions.Destroy;
begin
  { No anonymous queued callbacks can survive package unloading. }
  FTimer.Free;
  FEditors.Free;
  inherited;
end;

procedure TRibbonTreeSessions.Schedule;
begin
  FTimer.Enabled := True;
end;

procedure TRibbonTreeSessions.TimerTick(Sender: TObject);
var
  I: Integer;
  Editor: TRibbonTreeEditorForm;
begin
  FTimer.Enabled := False;
  for I := FEditors.Count - 1 downto 0 do
  begin
    Editor := FEditors[I];
    if Editor.FClosing then FEditors.Delete(I)
    else if Editor.FRefreshPending then
    begin
      Editor.FRefreshPending := False;
      try
        Editor.RefreshFromDesigner;
      except
        on E: Exception do Editor.ShowError(E);
      end;
    end;
  end;
end;

procedure TRibbonTreeSessions.Open(ARibbon: TCamARTRibbon;
  const ADesigner: IDesigner);
var
  Editor: TRibbonTreeEditorForm;
begin
  for Editor in FEditors do
    if not Editor.FClosing and (Editor.FRoot = ARibbon) and
       (Editor.FDesigner = ADesigner) then
    begin
      if Editor.WindowState = TWindowState.wsMinimized then
        Editor.WindowState := TWindowState.wsNormal;
      Editor.Show;
      Editor.BringToFront;
      Exit;
    end;
  Editor := TRibbonTreeEditorForm.CreateFor(ARibbon, ADesigner);
  FEditors.Add(Editor);
  try
    Editor.Show;
    Editor.SelectInspectorObject;
  except
    FEditors.Remove(Editor);
    raise;
  end;
end;

procedure TRibbonTreeSessions.ItemsModified(const ADesigner: IDesigner);
var
  Editor: TRibbonTreeEditorForm;
begin
  for Editor in FEditors do
    if not Editor.FClosing and (Editor.FDesigner = ADesigner) then
    begin
      Editor.FRefreshPending := True;
      Schedule;
    end;
end;

procedure TRibbonTreeSessions.ItemInserted(const ADesigner: IDesigner;
  AItem: TPersistent);
begin
  ItemsModified(ADesigner);
end;

procedure TRibbonTreeSessions.ItemDeleted(const ADesigner: IDesigner;
  AItem: TPersistent);
var
  Editor: TRibbonTreeEditorForm;
begin
  for Editor in FEditors do
    if not Editor.FClosing and (Editor.FDesigner = ADesigner) and
       (AItem = Editor.FRoot) then Editor.Retire;
  ItemsModified(ADesigner);
end;

procedure TRibbonTreeSessions.SelectionChanged(const ADesigner: IDesigner;
  const ASelection: IDesignerSelections);
var
  Editor: TRibbonTreeEditorForm;
begin
  for Editor in FEditors do
    if not Editor.FClosing and not Editor.FSyncing and
       (Editor.FDesigner = ADesigner) then
      Editor.FollowDesignerSelection(ASelection);
end;

procedure TRibbonTreeSessions.DesignerOpened(const ADesigner: IDesigner;
  AResurrecting: Boolean);
begin
  { Closed/dormant sessions are deliberately not resurrected. }
end;

procedure TRibbonTreeSessions.DesignerClosed(const ADesigner: IDesigner;
  AGoingDormant: Boolean);
var
  Editor: TRibbonTreeEditorForm;
begin
  for Editor in FEditors do
    if Editor.FDesigner = ADesigner then Editor.Retire;
end;

procedure TRibbonTreeSessions.WindowHide;
var
  Editor: TRibbonTreeEditorForm;
begin
  for Editor in FEditors do
    if not Editor.FClosing and Editor.Visible then
    begin
      Editor.FRestoreVisible := True;
      Editor.Hide;
    end;
end;

procedure TRibbonTreeSessions.WindowShow;
var
  Editor: TRibbonTreeEditorForm;
begin
  for Editor in FEditors do
    if not Editor.FClosing and Editor.FRestoreVisible then
    begin
      Editor.FRestoreVisible := False;
      Editor.Show;
    end;
end;

constructor TRibbonTreeEditorForm.CreateFor(ARibbon: TCamARTRibbon;
  const ADesigner: IDesigner);
begin
  inherited CreateNew(nil);
  if (ARibbon = nil) or (ADesigner = nil) then
    raise ERibbonDesignError.Create('A Ribbon and active form designer are required.');
  if (csDestroying in ARibbon.ComponentState) or ADesigner.IsDormant then
    raise ERibbonDesignError.Create('The form designer is no longer available.');
  FRoot := ARibbon;
  FDesigner := ADesigner;
  TComponent(FRoot).FreeNotification(Self);
  FReadOnly := FDesigner.IsSourceReadOnly;
  Caption := 'CamART Ribbon designer';
  Width := 1000;
  Height := 730;
  Position := TFormPosition.ScreenCenter;
  { Keep this modeless editor visible while the IDE Object Inspector has focus. }
  FormStyle := TFormStyle.StayOnTop;
  BuildUI;
  RebuildTree('');
end;

destructor TRibbonTreeEditorForm.Destroy;
begin
  if FRoot <> nil then TComponent(FRoot).RemoveFreeNotification(Self);
  FRoot := nil;
  FDesigner := nil;
  inherited;
end;

procedure TRibbonTreeEditorForm.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FRoot) then
  begin
    FRoot := nil;
    Retire;
  end;
end;

procedure TRibbonTreeEditorForm.Retire;
begin
  if FClosing then Exit;
  FClosing := True;
  FRefreshPending := False;
  FDesigner := nil;
  if FRoot <> nil then TComponent(FRoot).RemoveFreeNotification(Self);
  FRoot := nil;
  Hide;
  Sessions.Schedule;
end;

procedure TRibbonTreeEditorForm.DoClose(var CloseAction: TCloseAction);
begin
  inherited;
  if CloseAction <> TCloseAction.caNone then
  begin
    { caFree uses an uncancellable anonymous FMX queue. The session owner
      instead frees us on its next timer tick or synchronously on unload. }
    CloseAction := TCloseAction.caHide;
    Retire;
  end;
end;

function TRibbonTreeEditorForm.AddButton(AParent: TControl;
  const AText: string; AX, AY, AW: Single; AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(AX, AY, AW, 32);
  Result.Text := AText;
  Result.OnClick := AClick;
end;

function TRibbonTreeEditorForm.AddLabel(const AText: string;
  AY: Single): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := FRight;
  Result.SetBounds(12, AY, 328, 22);
  Result.Text := AText;
end;

procedure TRibbonTreeEditorForm.BuildUI;
var
  Footer: TLayout;
  CloseButton: TButton;
  Kind: TRibbonDesignNodeKind;
  Theme: TRibbonTheme;
begin
  Footer := TLayout.Create(Self);
  Footer.Parent := Self;
  Footer.Align := TAlignLayout.Bottom;
  Footer.Height := 88;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.Align := TAlignLayout.Client;
  FStatus.Margins.Left := 12;
  FStatus.Margins.Right := 12;
  FStatus.WordWrap := True;
  FStatus.Text := 'Changes are applied to the form by each action. ' +
    'Close keeps applied changes. IDs remain stable; events are edited in the Object Inspector.';
  CloseButton := AddButton(Footer, 'Close', 0, 0, 105, CloseClicked);
  CloseButton.Align := TAlignLayout.Right;
  CloseButton.Margins.Rect := TRectF.Create(0, 20, 12, 20);

  FRight := TScrollBox.Create(Self);
  FRight.Parent := Self;
  FRight.Align := TAlignLayout.Right;
  FRight.Width := 360;
  FTree := TTreeView.Create(Self);
  FTree.Parent := Self;
  FTree.Align := TAlignLayout.Client;
  FTree.OnChange := ChangedSelection;

  FSelection := AddLabel('Ribbon', 8);
  FSelection.Height := 44;
  FSelection.WordWrap := True;
  AddLabel('Permanent ID (read only)', 58);
  FIdentity := TEdit.Create(Self);
  FIdentity.Parent := FRight;
  FIdentity.SetBounds(12, 82, 328, 28);
  FIdentity.ReadOnly := True;
  AddLabel('Caption', 116);
  FCaption := TEdit.Create(Self);
  FCaption.Parent := FRight;
  FCaption.SetBounds(12, 140, 328, 28);
  AddLabel('IconKey (application-defined key)', 174);
  FIconKey := TEdit.Create(Self);
  FIconKey.Parent := FRight;
  FIconKey.SetBounds(12, 198, 328, 28);
  FVisible := TCheckBox.Create(Self);
  FVisible.Parent := FRight;
  FVisible.SetBounds(12, 234, 150, 26);
  FVisible.Text := 'Visible';
  FEnabled := TCheckBox.Create(Self);
  FEnabled.Parent := FRight;
  FEnabled.SetBounds(180, 234, 150, 26);
  FEnabled.Text := 'Enabled';
  AddLabel('Button size', 266);
  FSize := TComboBox.Create(Self);
  FSize.Parent := FRight;
  FSize.SetBounds(12, 290, 156, 28);
  FSize.Items.Add('Large');
  FSize.Items.Add('Small');
  FSize.Items.Add('Icon');
  FSize.ItemIndex := 0;
  FApply := AddButton(FRight, 'Apply properties', 180, 288, 160, ApplyClicked);

  AddLabel('Add under selected parent', 328);
  FKind := TComboBox.Create(Self);
  FKind.Parent := FRight;
  FKind.SetBounds(12, 352, 210, 28);
  for Kind := Low(TRibbonDesignNodeKind) to High(TRibbonDesignNodeKind) do
    FKind.Items.Add(TRibbonDesignOperations.KindName(Kind));
  FKind.ItemIndex := 0;
  FAdd := AddButton(FRight, 'Add', 234, 350, 106, AddClicked);
  FDelete := AddButton(FRight, 'Delete subtree', 12, 392, 148, DeleteClicked);
  FUp := AddButton(FRight, 'Up', 172, 392, 78, MoveClicked);
  FUp.Tag := -1;
  FDown := AddButton(FRight, 'Down', 262, 392, 78, MoveClicked);
  FDown.Tag := 1;

  AddLabel('Ribbon preset (StyleBook retains priority)', 436);
  FTheme := TComboBox.Create(Self);
  FTheme.Parent := FRight;
  FTheme.SetBounds(12, 460, 210, 28);
  for Theme := Low(TRibbonTheme) to High(TRibbonTheme) do
    FTheme.Items.Add(RibbonThemeName(Theme));
  FThemeApply := AddButton(FRight, 'Apply', 234, 458, 106, ThemeClicked);
  FInspector := AddButton(FRight, 'Open selection in Object Inspector',
    12, 506, 328, InspectClicked);
  with AddLabel('Use Object Inspector for command IDs, collections, events, ' +
    'StyleBook, layout and all type-specific properties.', 550) do
  begin
    Height := 66;
    WordWrap := True;
  end;
end;

function TRibbonTreeEditorForm.SelectedId: string;
begin
  Result := '';
  if FTree.Selected <> nil then Result := FTree.Selected.TagString;
end;

function TRibbonTreeEditorForm.SelectedNode: TRibbonNode;
begin
  Result := nil;
  if (FRoot <> nil) and (SelectedId <> '') then
    Result := FRoot.Model.FindNodeById(SelectedId);
end;

procedure TRibbonTreeEditorForm.RebuildTree(const ASelectedId: string);
var
  RootItem, TabItem, GroupItem, SelectionItem: TTreeViewItem;
  Tab: TRibbonTab;
  Group: TRibbonGroup;
  Item: TRibbonItem;
  function NewTreeItem(AParent: TFmxObject; ANode: TRibbonNode): TTreeViewItem;
  begin
    Result := TTreeViewItem.Create(FTree);
    Result.Parent := AParent;
    Result.Text := ANode.Caption + '  [' + ANode.ClassName + ']';
    Result.TagString := ANode.Id;
    if ANode.Id = ASelectedId then SelectionItem := Result;
  end;
begin
  if FRoot = nil then Exit;
  FBuilding := True;
  FTree.BeginUpdate;
  try
    FTree.Clear;
    RootItem := TTreeViewItem.Create(FTree);
    RootItem.Parent := FTree;
    RootItem.Text := FRoot.Name + '  [TCamARTRibbon]';
    RootItem.TagString := '';
    SelectionItem := RootItem;
    for Tab in FRoot.Model.Tabs do
    begin
      TabItem := NewTreeItem(RootItem, Tab);
      for Group in Tab.Groups do
      begin
        GroupItem := NewTreeItem(TabItem, Group);
        for Item in Group.Items do
          NewTreeItem(GroupItem, Item);
        GroupItem.IsExpanded := True;
      end;
      TabItem.IsExpanded := True;
    end;
    RootItem.IsExpanded := True;
    FTree.Selected := SelectionItem;
  finally
    FTree.EndUpdate;
    FBuilding := False;
  end;
  ReadSelection;
end;

procedure TRibbonTreeEditorForm.ReadSelection;
var
  Node: TRibbonNode;
  Editable: Boolean;
begin
  if (FRoot = nil) or (FDesigner = nil) then Exit;
  FReadOnly := FDesigner.IsSourceReadOnly;
  FRight.Enabled := FTree.Selected <> nil;
  if FTree.Selected = nil then Exit;
  Node := SelectedNode;
  Editable := not FReadOnly and (Node <> nil);
  if Node <> nil then Editable := Editable and not (csAncestor in Node.ComponentState);
  FCaption.Enabled := Editable;
  FIconKey.Enabled := Editable;
  FEnabled.Enabled := Editable;
  FVisible.Enabled := Editable;
  FApply.Enabled := Editable;
  FDelete.Enabled := Editable;
  FUp.Enabled := Editable;
  FDown.Enabled := Editable;
  FSize.Enabled := Editable and (Node is TRibbonButton);
  FAdd.Enabled := not FReadOnly;
  FTheme.Enabled := not FReadOnly and not (csAncestor in FRoot.ComponentState);
  FThemeApply.Enabled := FTheme.Enabled;
  FTheme.ItemIndex := Ord(FRoot.Theme);
  if Node = nil then
  begin
    FSelection.Text := FRoot.Name + ' / Ribbon';
    FIdentity.Text := '(Ribbon root)';
    FCaption.Text := '';
    FIconKey.Text := '';
    FEnabled.IsChecked := FRoot.Enabled;
    FVisible.IsChecked := FRoot.Visible;
    FKind.ItemIndex := Ord(rdnTab);
  end
  else
  begin
    FSelection.Text := Node.Name + ' / ' + Node.ClassName;
    FIdentity.Text := Node.Id;
    FCaption.Text := Node.Caption;
    FIconKey.Text := Node.IconKey;
    FEnabled.IsChecked := Node.Enabled;
    FVisible.IsChecked := Node.Visible;
    if Node is TRibbonButton then FSize.ItemIndex := Ord(TRibbonButton(Node).ButtonStyle);
    if Node is TRibbonTab then FKind.ItemIndex := Ord(rdnGroup)
    else if Node is TRibbonGroup then FKind.ItemIndex := Ord(rdnButton);
  end;
  if FReadOnly then FStatus.Text := 'The form source is read only. Editing is disabled.';
end;

procedure TRibbonTreeEditorForm.ChangedSelection(Sender: TObject);
begin
  if FBuilding or FClosing then Exit;
  try
    ReadSelection;
    SelectInspectorObject;
  except
    on E: Exception do ShowError(E);
  end;
end;

procedure TRibbonTreeEditorForm.FollowDesignerSelection(
  const ASelection: IDesignerSelections);
var
  I: Integer;
  Item, Match: TTreeViewItem;
  Candidate: TPersistent;
begin
  if FClosing or FBuilding or FSyncing or (FRoot = nil) then Exit;
  Match := nil;
  { A single-selection tree never collapses an IDE multi-selection. Compare
    identities only; do not dereference a borrowed IDE selection pointer. }
  if (ASelection <> nil) and (ASelection.Count = 1) then
    for I := 0 to FTree.GlobalCount - 1 do
    begin
      Item := FTree.ItemByGlobalIndex(I);
      if Item.TagString = '' then Candidate := FRoot
      else Candidate := FRoot.Model.FindNodeById(Item.TagString);
      if (Candidate <> nil) and (Candidate = ASelection[0]) then
      begin
        Match := Item;
        Break;
      end;
    end;
  FBuilding := True;
  try
    FTree.Selected := Match;
    if Match <> nil then
    begin
      Item := Match.ParentItem;
      while Item <> nil do
      begin
        Item.IsExpanded := True;
        Item := Item.ParentItem;
      end;
    end;
  finally
    FBuilding := False;
  end;
  ReadSelection;
end;

procedure TRibbonTreeEditorForm.RefreshFromDesigner;
var
  Selection: IDesignerSelections;
begin
  if FClosing or (FRoot = nil) or (FDesigner = nil) then Exit;
  RebuildTree(SelectedId);
  Selection := CreateSelectionList;
  FDesigner.GetSelections(Selection);
  FollowDesignerSelection(Selection);
end;

procedure TRibbonTreeEditorForm.RequireWritable;
begin
  if (FRoot = nil) or (FDesigner = nil) then
    raise ERibbonDesignError.Create('The form designer is no longer available.');
  if FReadOnly or FDesigner.IsSourceReadOnly then
    raise ERibbonDesignError.Create('The form source is read only.');
end;

procedure TRibbonTreeEditorForm.MarkModified;
begin
  { Called after a real data change and before EndUpdate can run user model
    notifications. Selecting, opening, closing and failed preflight are clean. }
  if (FRoot <> nil) and (FDesigner <> nil) then FDesigner.Modified;
end;

procedure TRibbonTreeEditorForm.ShowError(E: Exception);
begin
  FStatus.Text := E.ClassName + ': ' + E.Message;
  if FRoot <> nil then RebuildTree(SelectedId);
end;

procedure TRibbonTreeEditorForm.AddClicked(Sender: TObject);
var
  NewId: string;
begin
  try
    RequireWritable;
    if (FKind.ItemIndex < Ord(Low(TRibbonDesignNodeKind))) or
       (FKind.ItemIndex > Ord(High(TRibbonDesignNodeKind))) then Exit;
    NewId := TRibbonDesignOperations.Add(FRoot, SelectedId,
      TRibbonDesignNodeKind(FKind.ItemIndex),
      procedure begin MarkModified; end);
    RebuildTree(NewId);
    SelectInspectorObject;
    FStatus.Text := 'Node added. Use Object Inspector to edit events and type-specific properties.';
  except
    on E: Exception do ShowError(E);
  end;
end;

procedure TRibbonTreeEditorForm.DeleteClicked(Sender: TObject);
var
  Id: string;
begin
  try
    RequireWritable;
    Id := SelectedId;
    TRibbonDesignOperations.CheckCanDelete(FRoot, Id);
    { Remove the soon-to-be-freed nested component from the IDE selection. }
    FDesigner.SelectComponent(FRoot);
    if FRoot = nil then Exit;
    TRibbonDesignOperations.Delete(FRoot, Id,
      procedure begin MarkModified; end);
    RebuildTree('');
    FStatus.Text := 'Subtree deleted. External references were checked before deletion.';
  except
    on E: Exception do ShowError(E);
  end;
end;

procedure TRibbonTreeEditorForm.MoveClicked(Sender: TObject);
var
  Id: string;
begin
  try
    RequireWritable;
    Id := SelectedId;
    if TRibbonDesignOperations.Move(FRoot, Id, TButton(Sender).Tag,
      procedure begin MarkModified; end) then
    begin
      RebuildTree(Id);
      FStatus.Text := 'Sibling order changed; permanent IDs were preserved.';
    end;
  except
    on E: Exception do ShowError(E);
  end;
end;

procedure TRibbonTreeEditorForm.ApplyClicked(Sender: TObject);
var
  Id: string;
begin
  try
    RequireWritable;
    if (FSize.ItemIndex < Ord(Low(TRibbonButtonStyle))) or
       (FSize.ItemIndex > Ord(High(TRibbonButtonStyle))) then Exit;
    Id := SelectedId;
    if TRibbonDesignOperations.ApplyNode(FRoot, Id, FCaption.Text,
      FIconKey.Text, FEnabled.IsChecked, FVisible.IsChecked,
      TRibbonButtonStyle(FSize.ItemIndex),
      procedure begin MarkModified; end) then
    begin
      RebuildTree(Id);
      FStatus.Text := 'Properties applied.';
    end;
  except
    on E: Exception do ShowError(E);
  end;
end;

procedure TRibbonTreeEditorForm.ThemeClicked(Sender: TObject);
var
  Theme: TRibbonTheme;
begin
  try
    RequireWritable;
    if csAncestor in FRoot.ComponentState then
      raise ERibbonDesignError.Create('Change the theme in the ancestor form.');
    if (FTheme.ItemIndex < Ord(Low(TRibbonTheme))) or
       (FTheme.ItemIndex > Ord(High(TRibbonTheme))) then Exit;
    Theme := TRibbonTheme(FTheme.ItemIndex);
    if FRoot.Theme = Theme then Exit;
    FRoot.BeginUpdate;
    try
      FRoot.Theme := Theme;
      MarkModified;
    finally
      if FRoot <> nil then FRoot.EndUpdate;
    end;
    FStatus.Text := 'Preset changed. A component StyleBook still overrides the form StyleBook.';
  except
    on E: Exception do ShowError(E);
  end;
end;

procedure TRibbonTreeEditorForm.InspectClicked(Sender: TObject);
begin
  try
    SelectInspectorObject;
  except
    on E: Exception do ShowError(E);
  end;
end;

procedure TRibbonTreeEditorForm.CloseClicked(Sender: TObject);
begin
  Close;
end;

procedure TRibbonTreeEditorForm.SelectInspectorObject;
var
  Instance: TComponent;
begin
  if FClosing or FSyncing or (FRoot = nil) or (FDesigner = nil) or
     (FTree.Selected = nil) then Exit;
  if SelectedId = '' then Instance := FRoot
  else Instance := SelectedNode;
  if (Instance = nil) or (csDestroying in Instance.ComponentState) then
  begin
    FRefreshPending := True;
    Sessions.Schedule;
    Exit;
  end;
  FSyncing := True;
  try
    { No Activate/Modified/ModalEdit: selection neither steals focus from the
      tree nor dirties the form; properties and events stay native to the IDE. }
    FDesigner.SelectComponent(Instance);
  finally
    FSyncing := False;
  end;
end;

procedure EditRibbonTree(ARibbon: TCamARTRibbon; const ADesigner: IDesigner);
begin
  if Sessions = nil then
  begin
    Sessions := TRibbonTreeSessions.Create;
    SessionNotification := Sessions;
    RegisterDesignNotification(SessionNotification);
  end;
  Sessions.Open(ARibbon, ADesigner);
end;

initialization
  { Sessions are created lazily by the component editor. }

finalization
  if SessionNotification <> nil then
  begin
    UnregisterDesignNotification(SessionNotification);
    SessionNotification := nil;
    Sessions := nil;
  end;

end.
