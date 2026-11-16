unit CamART.Ribbon.Model;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  System.UITypes,
  System.Generics.Collections,
  CamART.Ribbon.Types,
  CamART.Ribbon.Commands,
  CamART.Ribbon.References;

type
  ERibbonModelError = class(Exception);

  TRibbonModel = class;
  TRibbonNode = class;
  TRibbonTab = class;
  TRibbonGroup = class;
  TRibbonItem = class;
  TRibbonButton = class;
  TRibbonSeparator = class;
  TRibbonLabel = class;
  TRibbonSkLabel = class;
  TRibbonEdit = class;
  TRibbonComboBox = class;
  TRibbonColorPicker = class;
  TRibbonFontPicker = class;
  TRibbonFontSizePicker = class;
  TRibbonGallery = class;
  TRibbonCheckBox = class;
  TRibbonRadioButton = class;
  TRibbonProgressBar = class;
  TRibbonDropDownMenu = class;
  TRibbonItemClass = class of TRibbonItem;

  { Implemented by the visual root and by the headless test root. TComponent
    implementations are not reference-counted; this interface does not own
    the root or the facade. All model operations run on the host's UI thread. }
  IRibbonModelHost = interface
    ['{46539F18-9EAF-4E69-A2D2-925BBBE6F885}']
    function GetRibbonModel: TRibbonModel;
  end;

  { A token observes lifetime; it never owns or references the model. Keeping a
    token alive across a callback does not keep a destroyed component alive. }
  IRibbonModelLifetime = interface
    ['{77730ED4-B72C-4898-BE57-AF2963CD4602}']
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

  TRibbonNode = class abstract(TComponent)
  private
    FId: string;
    FCaption: string;
    FIconKey: string;
    FEnabled: Boolean;
    FVisible: Boolean;
    FOrder: Integer;
    FReady: Boolean;
    FDeleting: Boolean;
    FExchangeLocked: Boolean;
    FNodeLifetime: IRibbonModelLifetime;
    procedure SetId(const Value: string);
    procedure SetCaption(const Value: string);
    procedure SetIconKey(const Value: string);
    procedure SetEnabled(const Value: Boolean);
    procedure SetVisible(const Value: Boolean);
    procedure SetOrder(const Value: Integer);
  protected
    function AcceptsOwner(AOwner: TComponent): Boolean; virtual; abstract;
    procedure RequireMutable;
    procedure Changed(const Changes: TRibbonChanges);
    procedure ValueChanged(const Changes: TRibbonChanges;
      const AHandler: TNotifyEvent);
    procedure ValidateState; virtual;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    function GetChildOwner: TComponent; override;
    function GetChildParent: TComponent; override;
    procedure SetParentComponent(Value: TComponent); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    function GetParentComponent: TComponent; override;
    function HasParent: Boolean; override;
    function GetModel: TRibbonModel;
    function EffectiveEnabled: Boolean;
    function EffectiveVisible: Boolean;
    procedure MoveTo(NewParent: TComponent; NewOrder: Integer); virtual;
    property Ready: Boolean read FReady;
    property Deleting: Boolean read FDeleting;
  published
    property Id: string read FId write SetId;
    property Caption: string read FCaption write SetCaption;
    property IconKey: string read FIconKey write SetIconKey;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Visible: Boolean read FVisible write SetVisible default True;
    property Order: Integer read FOrder write SetOrder default 0;
  end;

  TRibbonTab = class(TRibbonNode)
  protected
    function AcceptsOwner(AOwner: TComponent): Boolean; override;
  public
    function Groups: TArray<TRibbonGroup>;
    function AddGroup(const ACaption: string): TRibbonGroup;
    procedure RemoveGroup(AGroup: TRibbonGroup);
  end;

  TRibbonGroup = class(TRibbonNode)
  private
    FMinWidth: Single;
    FPreferredWidth: Single;
    FPinned: Boolean;
    FAllowCompact: Boolean;
    FAllowCollapse: Boolean;
    FCollapsePriority: Integer;
    procedure SetPinned(const Value: Boolean);
    procedure SetAllowCompact(const Value: Boolean);
    procedure SetAllowCollapse(const Value: Boolean);
    procedure SetCollapsePriority(const Value: Integer);
    procedure SetMinWidth(const Value: Single);
    procedure SetPreferredWidth(const Value: Single);
  protected
    function AcceptsOwner(AOwner: TComponent): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    function Items: TArray<TRibbonItem>;
    function AddItem(AItemClass: TRibbonItemClass;
      const ACaption: string = ''): TRibbonItem;
    function AddButton(const ACaption: string): TRibbonButton;
    function AddSeparator(const ACaption: string = ''): TRibbonSeparator;
    function AddLabel(const ACaption: string = ''): TRibbonLabel;
    function AddSkLabel(const ACaption: string = '';
      const ATemplateKey: string = ''): TRibbonSkLabel;
    function AddEdit(const ACaption: string = ''): TRibbonEdit;
    function AddComboBox(const ACaption: string = ''): TRibbonComboBox;
    function AddColorPicker(const ACaption: string = ''): TRibbonColorPicker;
    function AddFontPicker(const ACaption: string = ''): TRibbonFontPicker;
    function AddFontSizePicker(const ACaption: string = ''): TRibbonFontSizePicker;
    function AddGallery(const ACaption: string = ''): TRibbonGallery;
    function AddCheckBox(const ACaption: string = ''): TRibbonCheckBox;
    function AddRadioButton(const ACaption: string = ''): TRibbonRadioButton;
    function AddProgressBar(const ACaption: string = ''): TRibbonProgressBar;
    function AddDropDownMenu(const ACaption: string = ''): TRibbonDropDownMenu;
    procedure RemoveItem(AItem: TRibbonItem);
  published
    property MinWidth: Single read FMinWidth write SetMinWidth;
    property PreferredWidth: Single read FPreferredWidth write SetPreferredWidth;
    property Pinned: Boolean read FPinned write SetPinned default False;
    property AllowCompact: Boolean read FAllowCompact write SetAllowCompact default True;
    property AllowCollapse: Boolean read FAllowCollapse write SetAllowCollapse default True;
    property CollapsePriority: Integer read FCollapsePriority write SetCollapsePriority default 0;
  end;

  TRibbonItem = class abstract(TRibbonNode)
  private
    FHint: string;
    FOnMouseEnter: TNotifyEvent;
    FOnMouseLeave: TNotifyEvent;
    procedure SetHint(const AValue: string);
  protected
    function AcceptsOwner(AOwner: TComponent): Boolean; override;
    function GetTypeKey: string; virtual; abstract;
  public
    procedure InvokeMouseEnter;
    procedure InvokeMouseLeave;
    property TypeKey: string read GetTypeKey;
  published
    property Hint: string read FHint write SetHint;
    property OnMouseEnter: TNotifyEvent read FOnMouseEnter write FOnMouseEnter;
    property OnMouseLeave: TNotifyEvent read FOnMouseLeave write FOnMouseLeave;
  end;

  TRibbonButton = class(TRibbonItem)
  private
    FButtonStyle: TRibbonButtonStyle;
    FButtonKind: TRibbonButtonKind;
    FChecked: Boolean;
    FCommandId: string;
    FGalleryId: string;
    FMenuItems: TRibbonCommandLinks;
    FOnClick: TNotifyEvent;
    FOnExecuted: TNotifyEvent;
    FOnChange: TNotifyEvent;
    function GetChecked: Boolean;
    function IsCheckedStored: Boolean;
    procedure SetButtonStyle(const Value: TRibbonButtonStyle);
    procedure SetGalleryId(const AValue: string);
    procedure SetMenuItems(const AValue: TRibbonCommandLinks);
    procedure MenuItemsChanged(Sender: TObject);
  protected
    function GetTypeKey: string; override;
    procedure SetButtonKind(const AValue: TRibbonButtonKind); virtual;
    procedure SetChecked(const AValue: Boolean); virtual;
    procedure SetCommandId(const Value: string); virtual;
    procedure ValidateState; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Only commandless toggle/check activation changes local state. A bound
      command owns its state. The callback may destroy this model component. }
    function ApplyLocalState: Boolean; virtual;
    { For direct, commandless usage. Bound commands are dispatched by the root.
      No member is accessed after the callback, which may delete this button. }
    procedure InvokeClick;
  published
    property ButtonStyle: TRibbonButtonStyle read FButtonStyle
      write SetButtonStyle default rbsLarge;
    property ButtonKind: TRibbonButtonKind read FButtonKind
      write SetButtonKind default rbkPush;
    property Checked: Boolean read GetChecked write SetChecked
      stored IsCheckedStored default False;
    property CommandId: string read FCommandId write SetCommandId;
    property GalleryId: string read FGalleryId write SetGalleryId;
    property MenuItems: TRibbonCommandLinks read FMenuItems write SetMenuItems;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnExecuted: TNotifyEvent read FOnExecuted write FOnExecuted;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TRibbonSeparator = class(TRibbonItem)
  protected
    function GetTypeKey: string; override;
  end;

  TRibbonLabel = class(TRibbonItem)
  protected
    function GetTypeKey: string; override;
  end;

  { Presentation-neutral rich label. TemplateKey names an application-side
    text template (the FMX layer resolves it to a Skia TSkLabel snapshot).
    Core stores only the key; no Skia/FMX dependency enters this package. }
  TRibbonSkLabel = class(TRibbonItem)
  private
    FTemplateKey: string;
    procedure SetTemplateKey(const AValue: string);
  protected
    function GetTypeKey: string; override;
  published
    property TemplateKey: string read FTemplateKey write SetTemplateKey;
  end;

  TRibbonEdit = class(TRibbonItem)
  private
    FText: string;
    FOnChange: TNotifyEvent;
    procedure SetText(const AValue: string);
  protected
    function GetTypeKey: string; override;
  published
    property Text: string read FText write SetText;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TRibbonComboBox = class(TRibbonItem)
  private
    FItems: TStringList;
    FItemIndex: Integer;
    FLastIndex: Integer;
    FSelectedText: string;
    FSelectionUpdate: Integer;
    FListPending: Boolean;
    FOnChange: TNotifyEvent;
    function GetItems: TStrings;
    procedure SetItems(const AValue: TStrings);
    procedure ItemsChanged(Sender: TObject);
    procedure PublishSelection(AListChanged: Boolean);
  protected
    function GetTypeKey: string; override;
    procedure SetItemIndex(const AValue: Integer); virtual;
    procedure SelectText(const AValue: string);
    function GetSelectedText: string;
    procedure ValidateChoices(AChoices: TStrings;
      const ASelectedText: string); virtual;
    procedure ValidateState; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ReplaceChoicesAndSelection(AChoices: TStrings;
      const ASelectedText: string);
    property SelectedText: string read GetSelectedText;
  published
    property Items: TStrings read GetItems write SetItems;
    property ItemIndex: Integer read FItemIndex write SetItemIndex default -1;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TRibbonColorPicker = class(TRibbonItem)
  private
    FColor: TAlphaColor;
    FOnChange: TNotifyEvent;
    procedure SetColor(const AValue: TAlphaColor);
  protected
    function GetTypeKey: string; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Color: TAlphaColor read FColor write SetColor default $FF000000;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TRibbonFontPicker = class(TRibbonComboBox)
  protected
    function GetTypeKey: string; override;
  published
    { Core stores the requested family; the platform renderer resolves fonts. }
    property FontName: string read GetSelectedText write SelectText;
  end;

  TRibbonFontSizePicker = class(TRibbonComboBox)
  private
    function GetFontSize: Single;
    function IsFontSizeStored: Boolean;
    procedure SetFontSize(const AValue: Single);
  protected
    function GetTypeKey: string; override;
    procedure SetItemIndex(const AValue: Integer); override;
    procedure ValidateChoices(AChoices: TStrings;
      const ASelectedText: string); override;
    procedure ValidateState; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    { Point sizes use invariant decimal text. ItemIndex=-1 means no selection,
      reported as FontSize=0. Setting FontSize requires a positive finite value. }
    property FontSize: Single read GetFontSize write SetFontSize
      stored IsFontSizeStored;
    property ItemIndex default 3;
  end;

  TRibbonGalleryEntries = class;

  TRibbonGalleryEntry = class(TCollectionItem)
  private
    FId, FCaption, FIconKey, FCommandId: string;
    FEnabled, FVisible: Boolean;
    procedure SetId(const AValue: string);
    procedure SetCaption(const AValue: string);
    procedure SetIconKey(const AValue: string);
    procedure SetCommandId(const AValue: string);
    procedure SetEnabled(const AValue: Boolean);
    procedure SetVisible(const AValue: Boolean);
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Id: string read FId write SetId;
    property Caption: string read FCaption write SetCaption;
    property IconKey: string read FIconKey write SetIconKey;
    property CommandId: string read FCommandId write SetCommandId;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  TRibbonGalleryEntries = class(TOwnedCollection)
  private
    FOnChanged: TNotifyEvent;
    FDestroying: Boolean;
    function GetItem(AIndex: Integer): TRibbonGalleryEntry;
    procedure SetItem(AIndex: Integer; const AValue: TRibbonGalleryEntry);
    procedure CheckUniqueId(AEntry: TRibbonGalleryEntry; const AId: string);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AOwner: TPersistent);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    function Add: TRibbonGalleryEntry;
    function AddEntry(const ACaption, ACommandId: string;
      const AIconKey: string = ''): TRibbonGalleryEntry;
    function FindById(const AId: string): TRibbonGalleryEntry;
    procedure Validate;
    property Items[AIndex: Integer]: TRibbonGalleryEntry read GetItem
      write SetItem; default;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

  TRibbonGallery = class(TRibbonItem)
  private
    FEntries: TRibbonGalleryEntries;
    FSelectedId: string;
    FOnChange: TNotifyEvent;
    procedure SetEntries(const AValue: TRibbonGalleryEntries);
    procedure SetSelectedId(const AValue: string);
    procedure EntriesChanged(Sender: TObject);
  protected
    function GetTypeKey: string; override;
    procedure ValidateState; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Entries: TRibbonGalleryEntries read FEntries write SetEntries;
    property SelectedId: string read FSelectedId write SetSelectedId;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TRibbonCheckBox = class(TRibbonButton)
  protected
    function GetTypeKey: string; override;
    procedure SetButtonKind(const AValue: TRibbonButtonKind); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ButtonKind default rbkCheck;
    property ButtonStyle default rbsSmall;
  end;

  TRibbonRadioButton = class(TRibbonCheckBox)
  private
    FGroupName: string;
    procedure SetGroupName(const AValue: string);
    procedure ApplyChecked(const AValue, AForceNotify: Boolean);
  protected
    function GetTypeKey: string; override;
    procedure SetChecked(const AValue: Boolean); override;
    procedure SetCommandId(const Value: string); override;
    procedure ValidateState; override;
  public
    function ApplyLocalState: Boolean; override;
    procedure MoveTo(NewParent: TComponent; NewOrder: Integer); override;
  published
    property GroupName: string read FGroupName write SetGroupName;
  end;

  TRibbonProgressBar = class(TRibbonItem)
  private
    FMin, FMax, FValue: Single;
    procedure SetMin(const AValue: Single);
    procedure SetMax(const AValue: Single);
    procedure SetValue(const AValue: Single);
  protected
    function GetTypeKey: string; override;
    procedure ValidateState; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetRange(const AMin, AMax: Single);
  published
    property Min: Single read FMin write SetMin;
    property Max: Single read FMax write SetMax;
    property Value: Single read FValue write SetValue;
  end;

  TRibbonDropDownMenu = class(TRibbonButton)
  protected
    function GetTypeKey: string; override;
    procedure SetButtonKind(const AValue: TRibbonButtonKind); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ButtonKind default rbkDropDown;
  end;

  { The facade owns no model components. AOwner owns tabs, tabs own groups,
    groups own items. Arrays returned by this class are non-owning snapshots. }
  TRibbonModel = class
  private
    FOwner: TComponent;
    FUpdateCount: Integer;
    FPending: TRibbonChanges;
    FNotifying: Boolean;
    FExchanging: Boolean;
    FShuttingDown: Boolean;
    FOnChanged: TRibbonModelChangedEvent;
    FCommandResolver: IRibbonCommandResolver;
    FLifetime: IRibbonModelLifetime;
    procedure FlushChanges;
    procedure RequireActive;
    procedure SetCommandResolver(const AValue: IRibbonCommandResolver);
  public
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    procedure Shutdown;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure Changed(const Changes: TRibbonChanges);
    function Tabs: TArray<TRibbonTab>;
    function AddTab(const ACaption: string): TRibbonTab;
    procedure RemoveTab(ATab: TRibbonTab);
    procedure Clear;
    function FindNodeById(const AId: string): TRibbonNode;
    function FindTabById(const AId: string): TRibbonTab;
    function FindButtonById(const AId: string): TRibbonButton;
    function FindItemById(const AId: string): TRibbonItem;
    function FindGalleryById(const AId: string): TRibbonGallery;
    procedure CheckUniqueId(ANode: TRibbonNode; const AId: string);
    procedure ValidateTree;
    { Both models must be batched. Swaps complete tab trees without publishing
      a model change until the caller ends its outer batch. The other owner
      then owns the previous tree. Validation/name/transfer failures restore
      tab ownership, orders and pending changes. Native TComponent ownership
      notifications remain synchronous: observers must not destroy or mutate
      either participating tree during transfer. Post-commit observer errors
      are not a parse failure and cannot undo already delivered callbacks. }
    procedure ExchangeTabs(AOther: TRibbonModel);
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent);
    property Owner: TComponent read FOwner;
    property UpdateCount: Integer read FUpdateCount;
    property CommandResolver: IRibbonCommandResolver read FCommandResolver
      write SetCommandResolver;
    property OnChanged: TRibbonModelChangedEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  System.Math;

type
  TRibbonStateNotice = record
    Node: TRibbonNode;
    Lifetime: IRibbonModelLifetime;
    Handler: TNotifyEvent;
  end;

  TRibbonModelLifetime = class(TInterfacedObject, IRibbonModelLifetime)
  private
    FAlive: Boolean;
  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

constructor TRibbonModelLifetime.Create;
begin
  inherited Create;
  FAlive := True;
end;

function TRibbonModelLifetime.IsAlive: Boolean;
begin
  Result := FAlive;
end;

procedure TRibbonModelLifetime.Invalidate;
begin
  FAlive := False;
end;

function ModelForOwner(AOwner: TComponent): TRibbonModel;
var
  Current: TComponent;
  Host: IRibbonModelHost;
begin
  Result := nil;
  Current := AOwner;
  while Current <> nil do
  begin
    if Supports(Current, IRibbonModelHost, Host) then
      Exit(Host.GetRibbonModel);
    Current := Current.Owner;
  end;
end;

function ChildNodes(AOwner: TComponent): TArray<TRibbonNode>;
var
  List: TList<TRibbonNode>;
  I, J: Integer;
  Node, Item: TRibbonNode;
begin
  List := TList<TRibbonNode>.Create;
  try
    if AOwner <> nil then
      for I := 0 to AOwner.ComponentCount - 1 do
        if AOwner.Components[I] is TRibbonNode then
        begin
          Node := TRibbonNode(AOwner.Components[I]);
          if Node.FReady and not Node.FDeleting and
             not (csDestroying in Node.ComponentState) then
            List.Add(Node);
        end;
    Result := List.ToArray;
    { Stable insertion sort: equal order during streaming preserves the exact
      child insertion order. Typical sibling sets are small. }
    for I := 1 to High(Result) do
    begin
      Item := Result[I];
      J := I - 1;
      while (J >= 0) and (Result[J].FOrder > Item.FOrder) do
      begin
        Result[J + 1] := Result[J];
        Dec(J);
      end;
      Result[J + 1] := Item;
    end;
  finally
    List.Free;
  end;
end;

procedure CheckIdText(const AId: string);
begin
  if (AId = '') or (Trim(AId) <> AId) then
    raise ERibbonModelError.Create('Ribbon Id must be nonempty and have no surrounding whitespace.');
end;

procedure NormalizeOrders(AOwner: TComponent);
var
  Nodes: TArray<TRibbonNode>;
  I: Integer;
begin
  Nodes := ChildNodes(AOwner);
  for I := 0 to High(Nodes) do
    Nodes[I].FOrder := I;
end;

procedure CheckIncomingIds(ANode: TRibbonNode; AModel: TRibbonModel);
var
  Seen: TDictionary<string, Byte>;
  procedure CheckNode(Node: TRibbonNode);
  var
    Child: TRibbonNode;
  begin
    CheckIdText(Node.Id);
    if Seen.ContainsKey(Node.Id) then
      raise ERibbonModelError.CreateFmt('Duplicate Ribbon Id: %s', [Node.Id]);
    Seen.Add(Node.Id, 0);
    if AModel <> nil then
      AModel.CheckUniqueId(Node, Node.Id);
    for Child in ChildNodes(Node) do
      CheckNode(Child);
  end;
begin
  { A detached subtree has no facade to enforce Id uniqueness during edits.
    Check every descendant before changing any ownership. }
  Seen := TDictionary<string, Byte>.Create;
  try
    CheckNode(ANode);
  finally
    Seen.Free;
  end;
end;

{ TRibbonNode }

constructor TRibbonNode.Create(AOwner: TComponent);
var
  G: TGUID;
  Token: string;
  Model: TRibbonModel;
begin
  { Check before inherited Create inserts this component into its owner. }
  if AOwner is TRibbonNode then TRibbonNode(AOwner).RequireMutable;
  Model := ModelForOwner(AOwner);
  if Model <> nil then Model.RequireActive;
  inherited Create(AOwner);
  FNodeLifetime := TRibbonModelLifetime.Create;
  FEnabled := True;
  FVisible := True;
  if CreateGUID(G) <> 0 then
    raise ERibbonModelError.Create('Cannot create a persistent Ribbon Id.');
  FId := LowerCase(GUIDToString(G));
  Token := StringReplace(FId, '-', '', [rfReplaceAll]);
  Token := StringReplace(Token, '{', '', [rfReplaceAll]);
  Token := StringReplace(Token, '}', '', [rfReplaceAll]);
  Name := 'Ribbon' + Token;
  { This is a child component, not a ref-counted interface object. }
  SetSubComponent(True);
end;

procedure TRibbonNode.AfterConstruction;
var
  Model: TRibbonModel;
begin
  inherited;
  if (Owner <> nil) and not AcceptsOwner(Owner) then
    raise ERibbonModelError.CreateFmt('%s has an invalid owner.', [ClassName]);
  FOrder := Length(ChildNodes(Owner));
  FReady := True;
  Model := GetModel;
  if Model <> nil then
  begin
    Model.CheckUniqueId(Self, FId);
    Model.Changed([rckStructure, rckMeasure, rckState]);
  end;
end;

destructor TRibbonNode.Destroy;
var
  Model: TRibbonModel;
  Lifetime: IRibbonModelLifetime;
  Batch, WasReady: Boolean;
begin
  WasReady := FReady;
  if FNodeLifetime <> nil then FNodeLifetime.Invalidate;
  Model := GetModel;
  Batch := (Model <> nil) and not Model.FShuttingDown and not Model.FExchanging and
    not (csDestroying in Model.Owner.ComponentState);
  if Batch then
  begin
    Lifetime := Model.FLifetime;
    Model.BeginUpdate;
  end;
  FDeleting := True;
  FReady := False;
  try
    try
      if Batch then
        Model.Changed([rckStructure, rckMeasure, rckState]);
      { Exclude this node before compacting its surviving siblings. Otherwise
        deletion leaves gaps and a subsequent append can create equal Orders.
        Do not reorder for failed construction or a parent being destroyed. }
      if WasReady and (Owner <> nil) and
         not (csDestroying in Owner.ComponentState) then
        NormalizeOrders(Owner);
    finally
      inherited;
    end;
  finally
    { Inherited destruction can notify arbitrary external components. The host
      and facade may have been destroyed by such a notification. Check the
      retained token before using the cached model pointer. }
    if Batch then
      if Lifetime.IsAlive then
        Model.EndUpdate;
  end;
end;

function TRibbonNode.GetModel: TRibbonModel;
begin
  Result := ModelForOwner(Owner);
end;

procedure TRibbonNode.RequireMutable;
var
  Model: TRibbonModel;
begin
  if FExchangeLocked then
    raise ERibbonModelError.Create('Ribbon nodes cannot be changed during content exchange.');
  Model := GetModel;
  if Model <> nil then Model.RequireActive;
end;

procedure TRibbonNode.Changed(const Changes: TRibbonChanges);
var
  Model: TRibbonModel;
begin
  if not FReady or FDeleting or (csDestroying in ComponentState) then
    Exit;
  Model := GetModel;
  if Model <> nil then
    Model.Changed(Changes);
end;

procedure TRibbonNode.ValueChanged(const Changes: TRibbonChanges;
  const AHandler: TNotifyEvent);
var
  Lifetime: IRibbonModelLifetime;
  Notify: Boolean;
begin
  if not FReady or FDeleting then Exit;
  Lifetime := FNodeLifetime;
  Notify := not (csLoading in ComponentState);
  Changed(Changes);
  { A model notification may have destroyed this node or its entire host. }
  if not Lifetime.IsAlive then Exit;
  if Notify and Assigned(AHandler) then AHandler(Self);
end;

procedure TRibbonNode.ValidateState;
begin
  { Descendants validate their independent persistent state here. }
end;

procedure TRibbonNode.SetId(const Value: string);
var
  Model: TRibbonModel;
begin
  RequireMutable;
  if Value = FId then
    Exit;
  CheckIdText(Value);
  Model := GetModel;
  if Model <> nil then
    Model.CheckUniqueId(Self, Value);
  FId := Value;
  Changed([rckStructure, rckState]);
end;

procedure TRibbonNode.SetCaption(const Value: string);
begin
  RequireMutable;
  if FCaption = Value then Exit;
  FCaption := Value;
  Changed([rckMeasure, rckPaint]);
end;

procedure TRibbonNode.SetIconKey(const Value: string);
begin
  RequireMutable;
  if FIconKey = Value then Exit;
  FIconKey := Value;
  Changed([rckMeasure, rckPaint]);
end;

procedure TRibbonNode.SetEnabled(const Value: Boolean);
begin
  RequireMutable;
  if FEnabled = Value then Exit;
  FEnabled := Value;
  Changed([rckState, rckPaint]);
end;

procedure TRibbonNode.SetVisible(const Value: Boolean);
begin
  RequireMutable;
  if FVisible = Value then Exit;
  FVisible := Value;
  Changed([rckStructure, rckMeasure, rckState]);
end;

procedure TRibbonNode.SetOrder(const Value: Integer);
var
  Nodes: TArray<TRibbonNode>;
  List: TList<TRibbonNode>;
  Node: TRibbonNode;
  I, Position: Integer;
  OrderChanged: Boolean;
begin
  RequireMutable;
  if Value < 0 then
    raise ERibbonModelError.Create('Ribbon Order cannot be negative.');
  if not FReady or (csLoading in ComponentState) or (Owner = nil) then
  begin
    FOrder := Value;
    Exit;
  end;
  Nodes := ChildNodes(Owner);
  List := TList<TRibbonNode>.Create;
  OrderChanged := False;
  try
    for Node in Nodes do
      if Node <> Self then
        List.Add(Node);
    Position := Min(Value, List.Count);
    List.Insert(Position, Self);
    for I := 0 to List.Count - 1 do
      if List[I].FOrder <> I then
      begin
        List[I].FOrder := I;
        OrderChanged := True;
      end;
  finally
    List.Free;
  end;
  if OrderChanged then
    Changed([rckStructure, rckMeasure]);
end;

function TRibbonNode.GetParentComponent: TComponent;
begin
  Result := Owner;
end;

function TRibbonNode.HasParent: Boolean;
begin
  Result := Owner <> nil;
end;

function TRibbonNode.GetChildOwner: TComponent;
begin
  Result := Self;
end;

function TRibbonNode.GetChildParent: TComponent;
begin
  Result := Self;
end;

procedure TRibbonNode.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  Node: TRibbonNode;
begin
  for Node in ChildNodes(Self) do
    Proc(Node);
end;

procedure TRibbonNode.SetParentComponent(Value: TComponent);
begin
  RequireMutable;
  if Value = Owner then
    Exit;
  if Value = nil then
    raise ERibbonModelError.Create('Detach by removing the Ribbon node; a live node cannot have two ownership models.');
  MoveTo(Value, FOrder);
end;

procedure TRibbonNode.MoveTo(NewParent: TComponent; NewOrder: Integer);
var
  Current, OldOwner: TComponent;
  Model, NewModel: TRibbonModel;
  OldOrder: Integer;
begin
  RequireMutable;
  if FDeleting or (csDestroying in ComponentState) then
    raise ERibbonModelError.Create('Cannot move a Ribbon node during destruction.');
  if NewParent is TRibbonNode then TRibbonNode(NewParent).RequireMutable;
  if (NewParent = nil) or not AcceptsOwner(NewParent) then
    raise ERibbonModelError.CreateFmt('%s has an invalid destination owner.', [ClassName]);
  if NewOrder < 0 then
    raise ERibbonModelError.Create('Ribbon Order cannot be negative.');
  Current := NewParent;
  while Current <> nil do
  begin
    if Current = Self then
      raise ERibbonModelError.Create('A Ribbon node cannot own itself or an ancestor.');
    Current := Current.Owner;
  end;
  Model := GetModel;
  NewModel := ModelForOwner(NewParent);
  if NewModel <> nil then NewModel.RequireActive;
  if (Model <> nil) and (Model <> NewModel) then
    raise ERibbonModelError.Create('MoveTo cannot move nodes between Ribbon roots.');
  if (Name <> '') and (NewParent.FindComponent(Name) <> nil) and
     (NewParent.FindComponent(Name) <> Self) then
    raise ERibbonModelError.Create('A component with this Name already exists in the destination.');
  CheckIncomingIds(Self, NewModel);
  if Model = nil then
    Model := NewModel;
  if Model <> nil then
    Model.BeginUpdate;
  try
    OldOwner := Owner;
    OldOrder := FOrder;
    if OldOwner <> NewParent then
    begin
      if OldOwner <> nil then
        OldOwner.RemoveComponent(Self);
      try
        NewParent.InsertComponent(Self);
      except
        if OldOwner <> nil then
          OldOwner.InsertComponent(Self);
        FOrder := OldOrder;
        raise;
      end;
      NormalizeOrders(OldOwner);
    end;
    SetOrder(NewOrder);
    Changed([rckStructure, rckMeasure, rckState]);
  finally
    if Model <> nil then
      Model.EndUpdate;
  end;
end;

procedure TRibbonNode.Loaded;
begin
  inherited;
  if not AcceptsOwner(Owner) then
    raise ERibbonModelError.CreateFmt('%s loaded with an invalid owner.', [ClassName]);
  CheckIdText(FId);
  ValidateState;
  Changed([rckStructure, rckMeasure, rckState]);
end;

function TRibbonNode.EffectiveEnabled: Boolean;
var
  Current: TComponent;
  Node: TRibbonNode;
begin
  Result := False;
  Current := Self;
  while Current is TRibbonNode do
  begin
    Node := TRibbonNode(Current);
    if not Node.FEnabled or not Node.FReady or Node.FDeleting or
       (csDestroying in Node.ComponentState) then
      Exit;
    Current := Current.Owner;
  end;
  Result := True;
end;

function TRibbonNode.EffectiveVisible: Boolean;
var
  Current: TComponent;
  Node: TRibbonNode;
begin
  Result := False;
  Current := Self;
  while Current is TRibbonNode do
  begin
    Node := TRibbonNode(Current);
    if not Node.FVisible or not Node.FReady or Node.FDeleting or
       (csDestroying in Node.ComponentState) then
      Exit;
    Current := Current.Owner;
  end;
  Result := True;
end;

{ TRibbonTab }

function TRibbonTab.AcceptsOwner(AOwner: TComponent): Boolean;
var
  Host: IRibbonModelHost;
begin
  Result := (AOwner <> nil) and Supports(AOwner, IRibbonModelHost, Host);
end;

function TRibbonTab.Groups: TArray<TRibbonGroup>;
var
  Node: TRibbonNode;
  List: TList<TRibbonGroup>;
begin
  List := TList<TRibbonGroup>.Create;
  try
    for Node in ChildNodes(Self) do
      if Node is TRibbonGroup then
        List.Add(TRibbonGroup(Node));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TRibbonTab.AddGroup(const ACaption: string): TRibbonGroup;
var
  Model: TRibbonModel;
begin
  RequireMutable;
  Model := GetModel;
  if Model <> nil then Model.BeginUpdate;
  try
    Result := TRibbonGroup.Create(Self);
    try
      Result.Caption := ACaption;
    except
      Result.Free;
      raise;
    end;
  finally
    if Model <> nil then Model.EndUpdate;
  end;
end;

procedure TRibbonTab.RemoveGroup(AGroup: TRibbonGroup);
begin
  RequireMutable;
  if (AGroup = nil) or (AGroup.Owner <> Self) then
    raise ERibbonModelError.Create('The group is not owned by this tab.');
  AGroup.Free;
end;

{ TRibbonGroup }

constructor TRibbonGroup.Create(AOwner: TComponent);
begin
  inherited;
  FAllowCompact := True;
  FAllowCollapse := True;
end;

function TRibbonGroup.AcceptsOwner(AOwner: TComponent): Boolean;
begin
  Result := AOwner is TRibbonTab;
end;

function TRibbonGroup.Items: TArray<TRibbonItem>;
var
  Node: TRibbonNode;
  List: TList<TRibbonItem>;
begin
  List := TList<TRibbonItem>.Create;
  try
    for Node in ChildNodes(Self) do
      if Node is TRibbonItem then
        List.Add(TRibbonItem(Node));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TRibbonGroup.AddItem(AItemClass: TRibbonItemClass;
  const ACaption: string): TRibbonItem;
var
  Model: TRibbonModel;
begin
  RequireMutable;
  if AItemClass = nil then
    raise ERibbonModelError.Create('An item class is required.');
  Model := GetModel;
  if Model <> nil then Model.BeginUpdate;
  try
    Result := AItemClass.Create(Self);
    try
      Result.Caption := ACaption;
    except
      Result.Free;
      raise;
    end;
  finally
    if Model <> nil then Model.EndUpdate;
  end;
end;

function TRibbonGroup.AddButton(const ACaption: string): TRibbonButton;
begin
  Result := TRibbonButton(AddItem(TRibbonButton, ACaption));
end;

function TRibbonGroup.AddSeparator(const ACaption: string): TRibbonSeparator;
begin
  Result := TRibbonSeparator(AddItem(TRibbonSeparator, ACaption));
end;

function TRibbonGroup.AddLabel(const ACaption: string): TRibbonLabel;
begin
  Result := TRibbonLabel(AddItem(TRibbonLabel, ACaption));
end;

function TRibbonGroup.AddSkLabel(const ACaption, ATemplateKey: string): TRibbonSkLabel;
begin
  Result := TRibbonSkLabel(AddItem(TRibbonSkLabel, ACaption));
  if ATemplateKey <> '' then Result.TemplateKey := ATemplateKey;
end;

function TRibbonGroup.AddEdit(const ACaption: string): TRibbonEdit;
begin
  Result := TRibbonEdit(AddItem(TRibbonEdit, ACaption));
end;

function TRibbonGroup.AddComboBox(const ACaption: string): TRibbonComboBox;
begin
  Result := TRibbonComboBox(AddItem(TRibbonComboBox, ACaption));
end;

function TRibbonGroup.AddColorPicker(const ACaption: string): TRibbonColorPicker;
begin
  Result := TRibbonColorPicker(AddItem(TRibbonColorPicker, ACaption));
end;

function TRibbonGroup.AddFontPicker(const ACaption: string): TRibbonFontPicker;
begin
  Result := TRibbonFontPicker(AddItem(TRibbonFontPicker, ACaption));
end;

function TRibbonGroup.AddFontSizePicker(const ACaption: string): TRibbonFontSizePicker;
begin
  Result := TRibbonFontSizePicker(AddItem(TRibbonFontSizePicker, ACaption));
end;

function TRibbonGroup.AddGallery(const ACaption: string): TRibbonGallery;
begin
  Result := TRibbonGallery(AddItem(TRibbonGallery, ACaption));
end;

function TRibbonGroup.AddCheckBox(const ACaption: string): TRibbonCheckBox;
begin
  Result := TRibbonCheckBox(AddItem(TRibbonCheckBox, ACaption));
end;

function TRibbonGroup.AddRadioButton(const ACaption: string): TRibbonRadioButton;
begin
  Result := TRibbonRadioButton(AddItem(TRibbonRadioButton, ACaption));
end;

function TRibbonGroup.AddProgressBar(const ACaption: string): TRibbonProgressBar;
begin
  Result := TRibbonProgressBar(AddItem(TRibbonProgressBar, ACaption));
end;

function TRibbonGroup.AddDropDownMenu(const ACaption: string): TRibbonDropDownMenu;
begin
  Result := TRibbonDropDownMenu(AddItem(TRibbonDropDownMenu, ACaption));
end;

procedure TRibbonGroup.RemoveItem(AItem: TRibbonItem);
begin
  RequireMutable;
  if (AItem = nil) or (AItem.Owner <> Self) then
    raise ERibbonModelError.Create('The item is not owned by this group.');
  AItem.Free;
end;

procedure TRibbonGroup.SetPinned(const Value: Boolean);
begin
  RequireMutable;
  if FPinned = Value then Exit;
  FPinned := Value;
  Changed([rckMeasure]);
end;

procedure TRibbonGroup.SetAllowCompact(const Value: Boolean);
begin
  RequireMutable;
  if FAllowCompact = Value then Exit;
  FAllowCompact := Value;
  Changed([rckMeasure]);
end;

procedure TRibbonGroup.SetAllowCollapse(const Value: Boolean);
begin
  RequireMutable;
  if FAllowCollapse = Value then Exit;
  FAllowCollapse := Value;
  Changed([rckMeasure]);
end;

procedure TRibbonGroup.SetCollapsePriority(const Value: Integer);
begin
  RequireMutable;
  if FCollapsePriority = Value then Exit;
  FCollapsePriority := Value;
  Changed([rckMeasure]);
end;

procedure TRibbonGroup.SetMinWidth(const Value: Single);
begin
  RequireMutable;
  if IsNan(Value) or IsInfinite(Value) or (Value < 0) then
    raise ERibbonModelError.Create('MinWidth must be finite and nonnegative.');
  if FMinWidth = Value then Exit;
  FMinWidth := Value;
  Changed([rckMeasure]);
end;

procedure TRibbonGroup.SetPreferredWidth(const Value: Single);
begin
  RequireMutable;
  if IsNan(Value) or IsInfinite(Value) or (Value < 0) then
    raise ERibbonModelError.Create('PreferredWidth must be finite and nonnegative.');
  if FPreferredWidth = Value then Exit;
  FPreferredWidth := Value;
  Changed([rckMeasure]);
end;

{ TRibbonItem }

function TRibbonItem.AcceptsOwner(AOwner: TComponent): Boolean;
begin
  Result := AOwner is TRibbonGroup;
end;

procedure TRibbonItem.SetHint(const AValue: string);
begin
  RequireMutable;
  if FHint = AValue then Exit;
  FHint := AValue;
  Changed([rckPaint]);
end;

procedure TRibbonItem.InvokeMouseEnter;
var
  Handler: TNotifyEvent;
begin
  Handler := FOnMouseEnter;
  if Assigned(Handler) then Handler(Self);
end;

procedure TRibbonItem.InvokeMouseLeave;
var
  Handler: TNotifyEvent;
begin
  Handler := FOnMouseLeave;
  if Assigned(Handler) then Handler(Self);
end;

{ TRibbonButton }

constructor TRibbonButton.Create(AOwner: TComponent);
begin
  inherited;
  FButtonStyle := rbsLarge;
  FButtonKind := rbkPush;
  FMenuItems := TRibbonCommandLinks.Create(Self);
  FMenuItems.OnChanged := MenuItemsChanged;
end;

destructor TRibbonButton.Destroy;
begin
  if FMenuItems <> nil then FMenuItems.OnChanged := nil;
  FreeAndNil(FMenuItems);
  inherited;
end;

function TRibbonButton.GetTypeKey: string;
begin
  Result := 'button';
end;

procedure TRibbonButton.SetButtonKind(const AValue: TRibbonButtonKind);
begin
  RequireMutable;
  if FButtonKind = AValue then Exit;
  FButtonKind := AValue;
  Changed([rckStructure, rckMeasure, rckState]);
end;

procedure TRibbonButton.SetChecked(const AValue: Boolean);
begin
  RequireMutable;
  if FCommandId <> '' then
    raise ERibbonModelError.Create(
      'Checked is read-only for a bound command; update the command state instead.');
  if FChecked = AValue then Exit;
  FChecked := AValue;
  ValueChanged([rckState, rckPaint], FOnChange);
end;

function TRibbonButton.GetChecked: Boolean;
var
  Model: TRibbonModel;
  Resolver: IRibbonCommandResolver;
  Command: IRibbonCommand;
  State: IRibbonCheckState;
  CommandId: string;
begin
  if FCommandId = '' then Exit(FChecked);
  CommandId := FCommandId;
  Model := GetModel;
  if Model = nil then Exit(False);
  Resolver := Model.CommandResolver;
  if Resolver = nil then Exit(False);
  if not Resolver.TryResolve(CommandId, Command) or (Command = nil) then Exit(False);
  if not Supports(Command, IRibbonCheckState, State) then Exit(False);
  Result := State.GetChecked;
end;

function TRibbonButton.IsCheckedStored: Boolean;
begin
  Result := FCommandId = '';
end;

procedure TRibbonButton.SetGalleryId(const AValue: string);
begin
  RequireMutable;
  if FGalleryId = AValue then Exit;
  if AValue <> '' then CheckIdText(AValue);
  FGalleryId := AValue;
  Changed([rckState]);
end;

procedure TRibbonButton.SetMenuItems(const AValue: TRibbonCommandLinks);
begin
  RequireMutable;
  if AValue = nil then
    raise ERibbonModelError.Create('MenuItems cannot be nil.');
  FMenuItems.Assign(AValue);
end;

procedure TRibbonButton.MenuItemsChanged(Sender: TObject);
begin
  Changed([rckStructure, rckMeasure, rckState]);
end;

procedure TRibbonButton.ValidateState;
begin
  inherited;
  FMenuItems.Validate;
  if FGalleryId <> '' then CheckIdText(FGalleryId);
end;

function TRibbonButton.ApplyLocalState: Boolean;
begin
  Result := (FCommandId = '') and (FButtonKind in [rbkToggle, rbkCheck]);
  if Result then Checked := not FChecked;
  { SetChecked can invoke user code. Do not access fields after that call. }
end;

procedure TRibbonButton.SetButtonStyle(const Value: TRibbonButtonStyle);
begin
  RequireMutable;
  if FButtonStyle = Value then Exit;
  FButtonStyle := Value;
  Changed([rckMeasure, rckPaint]);
end;

procedure TRibbonButton.SetCommandId(const Value: string);
begin
  RequireMutable;
  if FCommandId = Value then Exit;
  if Value <> '' then CheckIdText(Value);
  FCommandId := Value;
  Changed([rckState]);
end;

procedure TRibbonButton.InvokeClick;
var
  Handler: TNotifyEvent;
  Lifetime: IRibbonModelLifetime;
begin
  RequireMutable;
  if not EffectiveEnabled or not EffectiveVisible then Exit;
  if FCommandId <> '' then
    raise ERibbonModelError.Create('Use the Ribbon dispatcher for a bound CommandId.');
  Lifetime := FNodeLifetime;
  ApplyLocalState;
  if not Lifetime.IsAlive then Exit;
  { OnChange may leave this node alive but replace the local intent with a
    command, or make this node or an ancestor ineligible. Cancel that original
    click before consulting its current handler. }
  if (FCommandId <> '') or not EffectiveEnabled or not EffectiveVisible then Exit;
  Handler := FOnClick;
  if Assigned(Handler) then
    Handler(Self);
end;

{ Value and content models }

function TRibbonSeparator.GetTypeKey: string;
begin
  Result := 'separator';
end;

function TRibbonLabel.GetTypeKey: string;
begin
  Result := 'label';
end;

function TRibbonSkLabel.GetTypeKey: string;
begin
  Result := 'sklabel';
end;

procedure TRibbonSkLabel.SetTemplateKey(const AValue: string);
begin
  RequireMutable;
  if FTemplateKey = AValue then Exit;
  FTemplateKey := AValue;
  Changed([rckMeasure, rckPaint]);
end;

function TRibbonEdit.GetTypeKey: string;
begin
  Result := 'edit';
end;

procedure TRibbonEdit.SetText(const AValue: string);
begin
  RequireMutable;
  if FText = AValue then Exit;
  FText := AValue;
  ValueChanged([rckMeasure, rckState, rckPaint], FOnChange);
end;

constructor TRibbonComboBox.Create(AOwner: TComponent);
begin
  inherited;
  FItemIndex := -1;
  FLastIndex := -1;
  FItems := TStringList.Create;
  FItems.OnChange := ItemsChanged;
end;

destructor TRibbonComboBox.Destroy;
begin
  if FItems <> nil then FItems.OnChange := nil;
  FreeAndNil(FItems);
  inherited;
end;

function TRibbonComboBox.GetTypeKey: string;
begin
  Result := 'combo';
end;

function TRibbonComboBox.GetItems: TStrings;
begin
  Result := FItems;
end;

procedure TRibbonComboBox.SetItems(const AValue: TStrings);
begin
  RequireMutable;
  if AValue = nil then
    raise ERibbonModelError.Create('ComboBox Items cannot be nil.');
  if AValue = FItems then Exit;
  FItems.Assign(AValue);
end;

function TRibbonComboBox.GetSelectedText: string;
begin
  Result := '';
  if (FItemIndex >= 0) and (FItemIndex < FItems.Count) then
    Result := FItems[FItemIndex];
end;

procedure TRibbonComboBox.PublishSelection(AListChanged: Boolean);
var
  Text: string;
  SelectionChanged: Boolean;
begin
  if FSelectionUpdate > 0 then
  begin
    FListPending := FListPending or AListChanged;
    Exit;
  end;
  if not (csLoading in ComponentState) then
    if FItemIndex >= FItems.Count then FItemIndex := -1;
  Text := GetSelectedText;
  SelectionChanged := (FLastIndex <> FItemIndex) or (FSelectedText <> Text);
  FLastIndex := FItemIndex;
  FSelectedText := Text;
  AListChanged := AListChanged or FListPending;
  FListPending := False;
  if SelectionChanged then
    ValueChanged([rckMeasure, rckState, rckPaint], FOnChange)
  else if AListChanged then
    Changed([rckMeasure, rckState, rckPaint]);
end;

procedure TRibbonComboBox.ItemsChanged(Sender: TObject);
begin
  PublishSelection(True);
end;

procedure TRibbonComboBox.SetItemIndex(const AValue: Integer);
begin
  RequireMutable;
  if AValue < -1 then
    raise ERibbonModelError.Create('ItemIndex must be -1 or a valid item index.');
  if not (csLoading in ComponentState) and (AValue >= FItems.Count) then
    raise ERibbonModelError.Create('ItemIndex is outside the Items list.');
  if FItemIndex = AValue then Exit;
  FItemIndex := AValue;
  PublishSelection(False);
end;

procedure TRibbonComboBox.SelectText(const AValue: string);
var
  Index: Integer;
begin
  RequireMutable;
  Inc(FSelectionUpdate);
  try
    if AValue = '' then
      Index := -1
    else
    begin
      Index := FItems.IndexOf(AValue);
      if Index < 0 then Index := FItems.Add(AValue);
    end;
    SetItemIndex(Index);
  finally
    Dec(FSelectionUpdate);
    if FSelectionUpdate = 0 then PublishSelection(False);
  end;
end;

procedure TRibbonComboBox.ReplaceChoicesAndSelection(AChoices: TStrings;
  const ASelectedText: string);
begin
  RequireMutable;
  if AChoices = nil then
    raise ERibbonModelError.Create('Replacement choices cannot be nil.');
  ValidateChoices(AChoices, ASelectedText);
  Inc(FSelectionUpdate);
  try
    if AChoices <> FItems then FItems.Assign(AChoices);
    { SelectText adds a missing requested value and has its own nested scope.
      Neither the temporary index nor the intermediate list is published. }
    SelectText(ASelectedText);
  finally
    Dec(FSelectionUpdate);
    if FSelectionUpdate = 0 then PublishSelection(False);
  end;
end;

procedure TRibbonComboBox.ValidateChoices(AChoices: TStrings;
  const ASelectedText: string);
begin
  { General combo-box choices are arbitrary strings. Specialized models
    validate the complete proposed choice set before an atomic replacement. }
end;

procedure TRibbonComboBox.ValidateState;
begin
  inherited;
  if (FItemIndex < -1) or (FItemIndex >= FItems.Count) then
    raise ERibbonModelError.Create('A streamed ComboBox ItemIndex is out of range.');
end;

constructor TRibbonColorPicker.Create(AOwner: TComponent);
begin
  inherited;
  FColor := TAlphaColor($FF000000);
end;

function TRibbonColorPicker.GetTypeKey: string;
begin
  Result := 'colorpicker';
end;

procedure TRibbonColorPicker.SetColor(const AValue: TAlphaColor);
begin
  RequireMutable;
  if FColor = AValue then Exit;
  FColor := AValue;
  ValueChanged([rckState, rckPaint], FOnChange);
end;

function TRibbonFontPicker.GetTypeKey: string;
begin
  Result := 'fontpicker';
end;

function TryPointSize(const AText: string; out AValue: Single): Boolean;
var
  Number: Double;
begin
  Result := TryStrToFloat(AText, Number, TFormatSettings.Invariant);
  if Result then
    Result := not IsNan(Number) and not IsInfinite(Number) and
      (Number > 0) and (Number <= 1000000);
  if Result then AValue := Number else AValue := 0;
end;

constructor TRibbonFontSizePicker.Create(AOwner: TComponent);
const
  Sizes: array[0..14] of string =
    ('8', '9', '10', '11', '12', '14', '16', '18', '20', '24', '28',
     '32', '36', '48', '72');
var
  Size: string;
begin
  inherited;
  for Size in Sizes do FItems.Add(Size);
  ItemIndex := 3;
end;

function TRibbonFontSizePicker.GetTypeKey: string;
begin
  Result := 'fontsizepicker';
end;

function TRibbonFontSizePicker.GetFontSize: Single;
begin
  if ItemIndex < 0 then Exit(0);
  if not TryPointSize(GetSelectedText, Result) then
    raise ERibbonModelError.Create('A selected font size must be a positive invariant number.');
end;

function TRibbonFontSizePicker.IsFontSizeStored: Boolean;
begin
  Result := ItemIndex >= 0;
end;

procedure TRibbonFontSizePicker.SetFontSize(const AValue: Single);
begin
  RequireMutable;
  if IsNan(AValue) or IsInfinite(AValue) or (AValue <= 0) or
     (AValue > 1000000) then
    raise ERibbonModelError.Create('FontSize must be finite, positive and at most 1000000 points.');
  SelectText(FloatToStr(AValue, TFormatSettings.Invariant));
end;

procedure TRibbonFontSizePicker.SetItemIndex(const AValue: Integer);
var
  Size: Single;
begin
  RequireMutable;
  if not (csLoading in ComponentState) and (AValue >= 0) and
     (AValue < FItems.Count) then
    if not TryPointSize(FItems[AValue], Size) then
      raise ERibbonModelError.Create('The selected font-size item is not a positive number.');
  inherited;
end;

procedure TRibbonFontSizePicker.ValidateState;
begin
  inherited;
  ValidateChoices(FItems, '');
end;

procedure TRibbonFontSizePicker.ValidateChoices(AChoices: TStrings;
  const ASelectedText: string);
var
  I: Integer;
  Size: Single;
begin
  inherited;
  for I := 0 to AChoices.Count - 1 do
    if not TryPointSize(AChoices[I], Size) then
      raise ERibbonModelError.Create('Font-size items must contain positive invariant numbers.');
  if ASelectedText <> '' then
    if not TryPointSize(ASelectedText, Size) then
      raise ERibbonModelError.Create('The requested font size must be a positive invariant number.');
end;

{ Gallery data is independent of both the popup and inline item controls. }

constructor TRibbonGalleryEntry.Create(ACollection: TCollection);
var
  G: TGUID;
begin
  inherited Create(nil);
  if (ACollection <> nil) and not (ACollection is TRibbonGalleryEntries) then
    raise ERibbonModelError.Create('Gallery entries require TRibbonGalleryEntries.');
  if CreateGUID(G) <> 0 then
    raise ERibbonModelError.Create('Cannot create a persistent gallery-entry ID.');
  FId := LowerCase(GUIDToString(G));
  FEnabled := True;
  FVisible := True;
  Collection := ACollection;
end;

procedure TRibbonGalleryEntry.Assign(Source: TPersistent);
var
  Entry: TRibbonGalleryEntry;
begin
  if Source = Self then Exit;
  if not (Source is TRibbonGalleryEntry) then
  begin
    inherited;
    Exit;
  end;
  Entry := TRibbonGalleryEntry(Source);
  CheckIdText(Entry.Id);
  if Collection is TRibbonGalleryEntries then
    TRibbonGalleryEntries(Collection).CheckUniqueId(Self, Entry.Id);
  FId := Entry.FId;
  FCaption := Entry.FCaption;
  FIconKey := Entry.FIconKey;
  FCommandId := Entry.FCommandId;
  FEnabled := Entry.FEnabled;
  FVisible := Entry.FVisible;
  Changed(False);
end;

procedure TRibbonGalleryEntry.SetId(const AValue: string);
begin
  if FId = AValue then Exit;
  CheckIdText(AValue);
  if Collection is TRibbonGalleryEntries then
    TRibbonGalleryEntries(Collection).CheckUniqueId(Self, AValue);
  FId := AValue;
  Changed(False);
end;

procedure TRibbonGalleryEntry.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  Changed(False);
end;

procedure TRibbonGalleryEntry.SetIconKey(const AValue: string);
begin
  if FIconKey = AValue then Exit;
  FIconKey := AValue;
  Changed(False);
end;

procedure TRibbonGalleryEntry.SetCommandId(const AValue: string);
begin
  if FCommandId = AValue then Exit;
  if AValue <> '' then CheckIdText(AValue);
  FCommandId := AValue;
  Changed(False);
end;

procedure TRibbonGalleryEntry.SetEnabled(const AValue: Boolean);
begin
  if FEnabled = AValue then Exit;
  FEnabled := AValue;
  Changed(False);
end;

procedure TRibbonGalleryEntry.SetVisible(const AValue: Boolean);
begin
  if FVisible = AValue then Exit;
  FVisible := AValue;
  Changed(False);
end;

constructor TRibbonGalleryEntries.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TRibbonGalleryEntry);
end;

destructor TRibbonGalleryEntries.Destroy;
begin
  FDestroying := True;
  FOnChanged := nil;
  inherited;
end;

procedure TRibbonGalleryEntries.Assign(Source: TPersistent);
begin
  if Source = Self then Exit;
  if Source is TRibbonGalleryEntries then TRibbonGalleryEntries(Source).Validate;
  inherited;
end;

function TRibbonGalleryEntries.GetItem(AIndex: Integer): TRibbonGalleryEntry;
begin
  Result := TRibbonGalleryEntry(inherited Items[AIndex]);
end;

procedure TRibbonGalleryEntries.SetItem(AIndex: Integer;
  const AValue: TRibbonGalleryEntry);
begin
  Items[AIndex].Assign(AValue);
end;

procedure TRibbonGalleryEntries.Update(Item: TCollectionItem);
var
  Handler: TNotifyEvent;
  PersistentOwner: TPersistent;
begin
  inherited;
  if FDestroying then Exit;
  PersistentOwner := GetOwner;
  if PersistentOwner is TComponent then
    if [csLoading, csDestroying] * TComponent(PersistentOwner).ComponentState <> [] then
      Exit;
  Handler := FOnChanged;
  if Assigned(Handler) then Handler(Self);
end;

function TRibbonGalleryEntries.Add: TRibbonGalleryEntry;
begin
  Result := TRibbonGalleryEntry(inherited Add);
end;

function TRibbonGalleryEntries.AddEntry(const ACaption, ACommandId,
  AIconKey: string): TRibbonGalleryEntry;
begin
  if ACommandId <> '' then CheckIdText(ACommandId);
  BeginUpdate;
  try
    Result := Add;
    Result.Caption := ACaption;
    Result.CommandId := ACommandId;
    Result.IconKey := AIconKey;
  finally
    EndUpdate;
  end;
end;

function TRibbonGalleryEntries.FindById(const AId: string): TRibbonGalleryEntry;
var
  I: Integer;
begin
  if AId <> '' then
    for I := 0 to Count - 1 do
      if Items[I].Id = AId then Exit(Items[I]);
  Result := nil;
end;

procedure TRibbonGalleryEntries.CheckUniqueId(AEntry: TRibbonGalleryEntry;
  const AId: string);
var
  Entry: TRibbonGalleryEntry;
begin
  CheckIdText(AId);
  Entry := FindById(AId);
  if (Entry <> nil) and (Entry <> AEntry) then
    raise ERibbonModelError.CreateFmt('Duplicate gallery-entry Id: %s', [AId]);
end;

procedure TRibbonGalleryEntries.Validate;
var
  Seen: TDictionary<string, Byte>;
  I: Integer;
begin
  Seen := TDictionary<string, Byte>.Create;
  try
    for I := 0 to Count - 1 do
    begin
      CheckIdText(Items[I].Id);
      if Seen.ContainsKey(Items[I].Id) then
        raise ERibbonModelError.CreateFmt('Duplicate gallery-entry Id: %s', [Items[I].Id]);
      Seen.Add(Items[I].Id, 0);
      if Items[I].CommandId <> '' then CheckIdText(Items[I].CommandId);
    end;
  finally
    Seen.Free;
  end;
end;

constructor TRibbonGallery.Create(AOwner: TComponent);
begin
  inherited;
  FEntries := TRibbonGalleryEntries.Create(Self);
  FEntries.OnChanged := EntriesChanged;
end;

destructor TRibbonGallery.Destroy;
begin
  if FEntries <> nil then FEntries.OnChanged := nil;
  FreeAndNil(FEntries);
  inherited;
end;

function TRibbonGallery.GetTypeKey: string;
begin
  Result := 'gallery';
end;

procedure TRibbonGallery.SetEntries(const AValue: TRibbonGalleryEntries);
begin
  RequireMutable;
  if AValue = nil then
    raise ERibbonModelError.Create('Gallery Entries cannot be nil.');
  FEntries.Assign(AValue);
end;

procedure TRibbonGallery.SetSelectedId(const AValue: string);
begin
  RequireMutable;
  if FSelectedId = AValue then Exit;
  if AValue <> '' then
  begin
    CheckIdText(AValue);
    if not (csLoading in ComponentState) and (FEntries.FindById(AValue) = nil) then
      raise ERibbonModelError.CreateFmt('Unknown gallery-entry Id: %s', [AValue]);
  end;
  FSelectedId := AValue;
  ValueChanged([rckState, rckPaint], FOnChange);
end;

procedure TRibbonGallery.EntriesChanged(Sender: TObject);
var
  SelectionChanged: Boolean;
begin
  SelectionChanged := (FSelectedId <> '') and
    (FEntries.FindById(FSelectedId) = nil);
  if SelectionChanged then FSelectedId := '';
  if SelectionChanged then
    ValueChanged([rckStructure, rckMeasure, rckState, rckPaint], FOnChange)
  else
    Changed([rckStructure, rckMeasure, rckState, rckPaint]);
end;

procedure TRibbonGallery.ValidateState;
begin
  inherited;
  FEntries.Validate;
  if (FSelectedId <> '') and (FEntries.FindById(FSelectedId) = nil) then
    raise ERibbonModelError.Create('A streamed Gallery selection does not exist.');
end;

{ Checked state and commandless radio groups }

constructor TRibbonCheckBox.Create(AOwner: TComponent);
begin
  inherited;
  FButtonKind := rbkCheck;
  FButtonStyle := rbsSmall;
end;

function TRibbonCheckBox.GetTypeKey: string;
begin
  Result := 'checkbox';
end;

procedure TRibbonCheckBox.SetButtonKind(const AValue: TRibbonButtonKind);
begin
  RequireMutable;
  if AValue <> rbkCheck then
    raise ERibbonModelError.Create('A CheckBox or RadioButton always uses rbkCheck.');
  inherited;
end;

function TRibbonRadioButton.GetTypeKey: string;
begin
  Result := 'radio';
end;

procedure TRibbonRadioButton.ApplyChecked(const AValue, AForceNotify: Boolean);
var
  Notices: TList<TRibbonStateNotice>;
  Pending: TArray<TRibbonStateNotice>;
  Notice: TRibbonStateNotice;
  Node: TRibbonNode;
  Other: TRibbonRadioButton;

  procedure Commit(Radio: TRibbonRadioButton; const Value: Boolean);
  var
    Item: TRibbonStateNotice;
  begin
    if Radio.FChecked = Value then Exit;
    Radio.FChecked := Value;
    Item.Node := Radio;
    Item.Lifetime := Radio.FNodeLifetime;
    if Radio.FReady and not (csLoading in Radio.ComponentState) then
      Item.Handler := Radio.FOnChange
    else
      Item.Handler := nil;
    Notices.Add(Item);
  end;

begin
  RequireMutable;
  if FCommandId <> '' then
    raise ERibbonModelError.Create(
      'Checked is read-only for a bound command; update the command state instead.');
  if csLoading in ComponentState then
  begin
    { Checked and GroupName are separate stream properties. Do not apply
      exclusion until the entire component definition has been read. }
    inherited SetChecked(AValue);
    Exit;
  end;
  Notices := TList<TRibbonStateNotice>.Create;
  try
    if AValue and (FCommandId = '') then
      for Node in ChildNodes(Owner) do
        if (Node <> Self) and (Node is TRibbonRadioButton) then
        begin
          Other := TRibbonRadioButton(Node);
          if (Other.FCommandId = '') and (Other.FGroupName = FGroupName) then
            Commit(Other, False);
        end;
    Commit(Self, AValue);
    Pending := Notices.ToArray;
  finally
    Notices.Free;
  end;
  if (Length(Pending) > 0) or AForceNotify then
    Changed([rckState, rckPaint]);
  { All state was committed before either model or user callbacks. Every
    callback has its own lifetime token because a prior one may delete peers. }
  for Notice in Pending do
    if Notice.Lifetime.IsAlive then
      if Assigned(Notice.Handler) then Notice.Handler(Notice.Node);
end;

procedure TRibbonRadioButton.SetChecked(const AValue: Boolean);
begin
  RequireMutable;
  ApplyChecked(AValue, False);
end;

procedure TRibbonRadioButton.SetGroupName(const AValue: string);
begin
  RequireMutable;
  if FGroupName = AValue then Exit;
  FGroupName := AValue;
  if FCommandId = '' then ApplyChecked(FChecked, True)
  else Changed([rckState, rckPaint]);
end;

procedure TRibbonRadioButton.SetCommandId(const Value: string);
begin
  RequireMutable;
  if FCommandId = Value then Exit;
  if Value <> '' then CheckIdText(Value);
  FCommandId := Value;
  if FCommandId = '' then ApplyChecked(FChecked, True)
  else Changed([rckState, rckPaint]);
end;

function TRibbonRadioButton.ApplyLocalState: Boolean;
begin
  Result := (FCommandId = '') and not FChecked;
  if Result then SetChecked(True);
end;

procedure TRibbonRadioButton.MoveTo(NewParent: TComponent; NewOrder: Integer);
var
  Model: TRibbonModel;
  ModelLifetime, NodeLifetime: IRibbonModelLifetime;
begin
  Model := GetModel;
  if Model = nil then Model := ModelForOwner(NewParent);
  NodeLifetime := FNodeLifetime;
  if Model <> nil then
  begin
    ModelLifetime := Model.FLifetime;
    Model.BeginUpdate;
  end;
  try
    inherited;
    if NodeLifetime.IsAlive then
      if FCommandId = '' then ApplyChecked(FChecked, True);
  finally
    if Model <> nil then
      if ModelLifetime.IsAlive then Model.EndUpdate;
  end;
end;

procedure TRibbonRadioButton.ValidateState;
var
  Node: TRibbonNode;
  Other: TRibbonRadioButton;
begin
  inherited;
  if not FChecked or (FCommandId <> '') then Exit;
  for Node in ChildNodes(Owner) do
    if (Node <> Self) and (Node is TRibbonRadioButton) then
    begin
      Other := TRibbonRadioButton(Node);
      if Other.FChecked and (Other.FCommandId = '') and
         (Other.FGroupName = FGroupName) then
        raise ERibbonModelError.Create('A commandless radio group has multiple checked items.');
    end;
end;

{ Progress values are finite; range changes clamp a running value atomically. }

constructor TRibbonProgressBar.Create(AOwner: TComponent);
begin
  inherited;
  FMin := 0;
  FMax := 100;
  FValue := 0;
end;

function TRibbonProgressBar.GetTypeKey: string;
begin
  Result := 'progress';
end;

procedure TRibbonProgressBar.SetRange(const AMin, AMax: Single);
begin
  RequireMutable;
  if IsNan(AMin) or IsInfinite(AMin) or IsNan(AMax) or IsInfinite(AMax) or
     (AMin >= AMax) then
    raise ERibbonModelError.Create('Progress range must be finite with Min < Max.');
  if (FMin = AMin) and (FMax = AMax) then Exit;
  FMin := AMin;
  FMax := AMax;
  FValue := EnsureRange(FValue, FMin, FMax);
  Changed([rckState, rckPaint]);
end;

procedure TRibbonProgressBar.SetMin(const AValue: Single);
begin
  RequireMutable;
  if IsNan(AValue) or IsInfinite(AValue) then
    raise ERibbonModelError.Create('Progress Min must be finite.');
  if csLoading in ComponentState then FMin := AValue
  else SetRange(AValue, FMax);
end;

procedure TRibbonProgressBar.SetMax(const AValue: Single);
begin
  RequireMutable;
  if IsNan(AValue) or IsInfinite(AValue) then
    raise ERibbonModelError.Create('Progress Max must be finite.');
  if csLoading in ComponentState then FMax := AValue
  else SetRange(FMin, AValue);
end;

procedure TRibbonProgressBar.SetValue(const AValue: Single);
var
  Value: Single;
begin
  RequireMutable;
  if IsNan(AValue) or IsInfinite(AValue) then
    raise ERibbonModelError.Create('Progress Value must be finite.');
  if csLoading in ComponentState then Value := AValue
  else Value := EnsureRange(AValue, FMin, FMax);
  if FValue = Value then Exit;
  FValue := Value;
  Changed([rckState, rckPaint]);
end;

procedure TRibbonProgressBar.ValidateState;
begin
  inherited;
  if IsNan(FMin) or IsInfinite(FMin) or IsNan(FMax) or IsInfinite(FMax) or
     IsNan(FValue) or IsInfinite(FValue) or (FMin >= FMax) or
     (FValue < FMin) or (FValue > FMax) then
    raise ERibbonModelError.Create('A streamed progress range or value is invalid.');
end;

constructor TRibbonDropDownMenu.Create(AOwner: TComponent);
begin
  inherited;
  FButtonKind := rbkDropDown;
end;

function TRibbonDropDownMenu.GetTypeKey: string;
begin
  Result := 'dropdownmenu';
end;

procedure TRibbonDropDownMenu.SetButtonKind(const AValue: TRibbonButtonKind);
begin
  RequireMutable;
  if AValue <> rbkDropDown then
    raise ERibbonModelError.Create('A DropDownMenu always uses rbkDropDown.');
  inherited;
end;

{ TRibbonModel }

constructor TRibbonModel.Create(AOwner: TComponent);
begin
  inherited Create;
  FLifetime := TRibbonModelLifetime.Create;
  if AOwner = nil then
    raise ERibbonModelError.Create('The Ribbon model facade requires an owner component.');
  FOwner := AOwner;
end;

destructor TRibbonModel.Destroy;
begin
  if FLifetime <> nil then
    FLifetime.Invalidate;
  Shutdown;
  FLifetime := nil;
  inherited;
end;

procedure TRibbonModel.Shutdown;
begin
  if FLifetime <> nil then FLifetime.Invalidate;
  FShuttingDown := True;
  FOnChanged := nil;
  FPending := [];
  FCommandResolver := nil;
end;

procedure TRibbonModel.SetCommandResolver(const AValue: IRibbonCommandResolver);
begin
  RequireActive;
  if FCommandResolver = AValue then Exit;
  FCommandResolver := AValue;
  Changed([rckState, rckPaint]);
end;

procedure TRibbonModel.RequireActive;
begin
  if FExchanging then
    raise ERibbonModelError.Create('The Ribbon model cannot be changed during content exchange.');
  if FShuttingDown or (csDestroying in FOwner.ComponentState) then
    raise ERibbonModelError.Create('The Ribbon model is shutting down.');
end;

procedure TRibbonModel.BeginUpdate;
begin
  RequireActive;
  Inc(FUpdateCount);
end;

procedure TRibbonModel.EndUpdate;
begin
  if FExchanging then
    raise ERibbonModelError.Create('Cannot publish a model batch during content exchange.');
  if FUpdateCount = 0 then
    raise ERibbonModelError.Create('EndUpdate has no matching BeginUpdate.');
  Dec(FUpdateCount);
  if FUpdateCount = 0 then FlushChanges;
end;

procedure TRibbonModel.Changed(const Changes: TRibbonChanges);
begin
  if FShuttingDown or (csDestroying in FOwner.ComponentState) then Exit;
  FPending := FPending + Changes;
  FlushChanges;
end;

procedure TRibbonModel.FlushChanges;
var
  Changes: TRibbonChanges;
  Handler: TRibbonModelChangedEvent;
  Lifetime: IRibbonModelLifetime;
begin
  if FShuttingDown or FNotifying or (FUpdateCount > 0) or
     (csLoading in FOwner.ComponentState) or
     (csDestroying in FOwner.ComponentState) then
    Exit;
  Lifetime := FLifetime;
  FNotifying := True;
  try
    while True do
    begin
      { This check must be separate: do not read Self if the previous callback
        destroyed the host and its facade. The local token remains valid. }
      if not Lifetime.IsAlive then
        Exit;
      if FShuttingDown or (FUpdateCount > 0) or (FPending = []) then
        Exit;
      Changes := FPending;
      FPending := [];
      Handler := FOnChanged;
      if Assigned(Handler) then
        Handler(Self, Changes);
      { Mutations made by the handler are delivered as a subsequent combined
        notification, never as recursive notification stack frames. Host/model
        destruction is detected before any further access to Self. }
    end;
  finally
    if Lifetime.IsAlive then
      FNotifying := False;
  end;
end;

function TRibbonModel.Tabs: TArray<TRibbonTab>;
var
  Node: TRibbonNode;
  List: TList<TRibbonTab>;
begin
  List := TList<TRibbonTab>.Create;
  try
    for Node in ChildNodes(FOwner) do
      if Node is TRibbonTab then
        List.Add(TRibbonTab(Node));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TRibbonModel.AddTab(const ACaption: string): TRibbonTab;
begin
  BeginUpdate;
  try
    Result := TRibbonTab.Create(FOwner);
    try
      Result.Caption := ACaption;
    except
      Result.Free;
      raise;
    end;
  finally
    EndUpdate;
  end;
end;

procedure TRibbonModel.RemoveTab(ATab: TRibbonTab);
begin
  RequireActive;
  if (ATab = nil) or (ATab.Owner <> FOwner) then
    raise ERibbonModelError.Create('The tab is not owned by this Ribbon.');
  ATab.Free;
end;

procedure TRibbonModel.Clear;
var
  Snapshot: TArray<TRibbonTab>;
  TabLifetimes: TArray<IRibbonModelLifetime>;
  Lifetime: IRibbonModelLifetime;
  I: Integer;
begin
  Lifetime := FLifetime;
  BeginUpdate;
  try
    Snapshot := Tabs;
    SetLength(TabLifetimes, Length(Snapshot));
    for I := 0 to High(Snapshot) do
      TabLifetimes[I] := Snapshot[I].FNodeLifetime;
    for I := 0 to High(Snapshot) do
    begin
      { Native destruction notifications may free the root, or an as-yet
        unvisited peer. Inspect retained tokens before touching either raw
        pointer; the original snapshot still defines this Clear operation. }
      if not Lifetime.IsAlive then Exit;
      if TabLifetimes[I].IsAlive then Snapshot[I].Free;
    end;
  finally
    if Lifetime.IsAlive then EndUpdate;
  end;
end;

function TRibbonModel.FindNodeById(const AId: string): TRibbonNode;
  function FindIn(AOwner: TComponent): TRibbonNode;
  var
    Node: TRibbonNode;
  begin
    Result := nil;
    for Node in ChildNodes(AOwner) do
    begin
      if Node.Id = AId then Exit(Node);
      Result := FindIn(Node);
      if Result <> nil then Exit;
    end;
  end;
begin
  if AId = '' then Exit(nil);
  Result := FindIn(FOwner);
end;

function TRibbonModel.FindTabById(const AId: string): TRibbonTab;
var
  Node: TRibbonNode;
begin
  Node := FindNodeById(AId);
  if Node is TRibbonTab then Result := TRibbonTab(Node) else Result := nil;
end;

function TRibbonModel.FindButtonById(const AId: string): TRibbonButton;
var
  Node: TRibbonNode;
begin
  Node := FindNodeById(AId);
  if Node is TRibbonButton then Result := TRibbonButton(Node) else Result := nil;
end;

function TRibbonModel.FindItemById(const AId: string): TRibbonItem;
var
  Node: TRibbonNode;
begin
  Node := FindNodeById(AId);
  if Node is TRibbonItem then Result := TRibbonItem(Node) else Result := nil;
end;

function TRibbonModel.FindGalleryById(const AId: string): TRibbonGallery;
var
  Node: TRibbonNode;
begin
  Node := FindNodeById(AId);
  if Node is TRibbonGallery then Result := TRibbonGallery(Node) else Result := nil;
end;

procedure TRibbonModel.CheckUniqueId(ANode: TRibbonNode; const AId: string);
var
  Existing: TRibbonNode;
begin
  CheckIdText(AId);
  Existing := FindNodeById(AId);
  if (Existing <> nil) and (Existing <> ANode) then
    raise ERibbonModelError.CreateFmt('Duplicate Ribbon Id: %s', [AId]);
end;

procedure TRibbonModel.ExchangeTabs(AOther: TRibbonModel);
var
  LeftTabs, RightTabs: TArray<TRibbonTab>;
  LeftTokens, RightTokens: TArray<IRibbonModelLifetime>;
  LockedNodes: TArray<TRibbonStateNotice>;
  LockList: TList<TRibbonStateNotice>;
  Notice: TRibbonStateNotice;
  LeftOwner, RightOwner: TComponent;
  LeftLifetime, RightLifetime: IRibbonModelLifetime;
  LeftPending, RightPending: TRibbonChanges;
  I: Integer;

  procedure CollectLocks(AOwner: TComponent);
  var
    Node: TRibbonNode;
    Entry: TRibbonStateNotice;
  begin
    for Node in ChildNodes(AOwner) do
    begin
      Entry.Node := Node;
      Entry.Lifetime := Node.FNodeLifetime;
      Entry.Handler := nil;
      LockList.Add(Entry);
      CollectLocks(Node);
    end;
  end;

  procedure FreeOrphans(const ATabs: TArray<TRibbonTab>;
    const ATokens: TArray<IRibbonModelLifetime>);
  var
    N: Integer;
  begin
    { A failed/destructive host notification may leave later snapshot tabs
      detached. Never dereference a dead token or an owner; release only live
      components whose Owner is nil. Continue best-effort cleanup if a custom
      destructor itself violates the host contract. Preserve the primary
      transfer exception rather than reporting a normal rollback. }
    for N := 0 to High(ATabs) do
      if ATokens[N].IsAlive then
        if ATabs[N].Owner = nil then
          try
            ATabs[N].Free;
          except
            { No successful transfer is reported; the original exception
              remains authoritative and arbitrary destructor effects cannot
              be rolled back. Other detached tabs still need cleanup. }
          end;
  end;

  procedure RequireOwners;
  begin
    if not LeftLifetime.IsAlive or not RightLifetime.IsAlive then
      raise ERibbonModelError.Create(
        'A Ribbon owner was destroyed during content exchange.');
  end;

  procedure RequireNode(const AToken: IRibbonModelLifetime);
  begin
    RequireOwners;
    if not AToken.IsAlive then
      raise ERibbonModelError.Create(
        'A Ribbon tab was destroyed during content exchange.');
  end;

  procedure Preflight(const AIncoming, AOutgoing: TArray<TRibbonTab>;
    ADestination: TComponent);
  var
    Tab, ExistingTab: TRibbonTab;
    Existing: TComponent;
    IsOutgoing: Boolean;
  begin
    for Tab in AIncoming do
    begin
      if not Tab.AcceptsOwner(ADestination) then
        raise ERibbonModelError.Create('Invalid content exchange owner.');
      Existing := ADestination.FindComponent(Tab.Name);
      if Existing = nil then Continue;
      IsOutgoing := False;
      for ExistingTab in AOutgoing do
        if ExistingTab = Existing then
        begin
          IsOutgoing := True;
          Break;
        end;
      if not IsOutgoing then
        raise ERibbonModelError.CreateFmt(
          'Content exchange would collide with component Name "%s".',
          [Tab.Name]);
    end;
  end;

  procedure Detach(const ATabs: TArray<TRibbonTab>;
    const ATokens: TArray<IRibbonModelLifetime>);
  var
    N: Integer;
    CurrentOwner: TComponent;
  begin
    for N := 0 to High(ATabs) do
    begin
      RequireNode(ATokens[N]);
      CurrentOwner := ATabs[N].Owner;
      if CurrentOwner <> nil then CurrentOwner.RemoveComponent(ATabs[N]);
      RequireNode(ATokens[N]);
    end;
  end;

  procedure Attach(const ATabs: TArray<TRibbonTab>;
    const ATokens: TArray<IRibbonModelLifetime>; ADestination: TComponent);
  var
    N: Integer;
  begin
    for N := 0 to High(ATabs) do
    begin
      RequireNode(ATokens[N]);
      ADestination.InsertComponent(ATabs[N]);
      RequireNode(ATokens[N]);
    end;
  end;

begin
  if AOther = nil then
    raise EArgumentNilException.Create('An exchange model is required.');
  if AOther = Self then Exit;
  RequireActive;
  AOther.RequireActive;
  if FExchanging or AOther.FExchanging then
    raise ERibbonModelError.Create('Reentrant content exchange is not allowed.');
  if (FUpdateCount = 0) or (AOther.FUpdateCount = 0) then
    raise ERibbonModelError.Create('Content exchange requires both models in BeginUpdate.');
  if FOwner = AOther.FOwner then
    raise ERibbonModelError.Create('Content exchange requires distinct owners.');
  { The incoming tree is detached from the live UI. ValidateTree may normalize
    its order; it is intentionally not called on the live receiver here. }
  AOther.ValidateTree;
  LeftTabs := Tabs;
  RightTabs := AOther.Tabs;
  LeftOwner := FOwner;
  RightOwner := AOther.FOwner;
  LeftLifetime := FLifetime;
  RightLifetime := AOther.FLifetime;
  SetLength(LeftTokens, Length(LeftTabs));
  SetLength(RightTokens, Length(RightTabs));
  for I := 0 to High(LeftTabs) do LeftTokens[I] := LeftTabs[I].FNodeLifetime;
  for I := 0 to High(RightTabs) do RightTokens[I] := RightTabs[I].FNodeLifetime;
  Preflight(RightTabs, LeftTabs, LeftOwner);
  Preflight(LeftTabs, RightTabs, RightOwner);
  LockList := TList<TRibbonStateNotice>.Create;
  try
    CollectLocks(LeftOwner);
    CollectLocks(RightOwner);
    LockedNodes := LockList.ToArray;
  finally
    LockList.Free;
  end;
  LeftPending := FPending;
  RightPending := AOther.FPending;
  FExchanging := True;
  AOther.FExchanging := True;
  for Notice in LockedNodes do Notice.Node.FExchangeLocked := True;
  try
    try
      Detach(LeftTabs, LeftTokens);
      Detach(RightTabs, RightTokens);
      Attach(LeftTabs, LeftTokens, RightOwner);
      Attach(RightTabs, RightTokens, LeftOwner);
    except
      { A one-shot ownership-notification failure is recoverable. A component
        that deliberately destroys a participant or repeatedly throws while
        rolling back is a host contract violation, not malformed JSON. }
      if LeftLifetime.IsAlive and RightLifetime.IsAlive then
      begin
        try
          Detach(LeftTabs, LeftTokens);
          Detach(RightTabs, RightTokens);
          Attach(LeftTabs, LeftTokens, LeftOwner);
          Attach(RightTabs, RightTokens, RightOwner);
          FPending := LeftPending;
          AOther.FPending := RightPending;
        except
          FreeOrphans(LeftTabs, LeftTokens);
          FreeOrphans(RightTabs, RightTokens);
          raise;
        end;
      end
      else
      begin
        FreeOrphans(LeftTabs, LeftTokens);
        FreeOrphans(RightTabs, RightTokens);
      end;
      raise;
    end;
    FPending := FPending + [rckStructure, rckMeasure, rckState, rckPaint];
    AOther.FPending := AOther.FPending + [rckStructure, rckMeasure, rckState, rckPaint];
  finally
    for Notice in LockedNodes do
      if Notice.Lifetime.IsAlive then Notice.Node.FExchangeLocked := False;
    if LeftLifetime.IsAlive then FExchanging := False;
    if RightLifetime.IsAlive then AOther.FExchanging := False;
  end;
end;

procedure TRibbonModel.ValidateTree;
var
  Seen: TDictionary<string, Byte>;
  procedure ValidateChildren(AOwner: TComponent);
  var
    Node: TRibbonNode;
  begin
    for Node in ChildNodes(AOwner) do
    begin
      if not Node.AcceptsOwner(AOwner) then
        raise ERibbonModelError.CreateFmt('%s has an invalid owner.', [Node.ClassName]);
      CheckIdText(Node.Id);
      if Seen.ContainsKey(Node.Id) then
        raise ERibbonModelError.CreateFmt('Duplicate Ribbon Id: %s', [Node.Id]);
      Seen.Add(Node.Id, 0);
      if Node.Name = '' then
        raise ERibbonModelError.Create('Streamed Ribbon nodes require a component Name.');
      ValidateChildren(Node);
      Node.ValidateState;
    end;
    NormalizeOrders(AOwner);
  end;
begin
  RequireActive;
  Seen := TDictionary<string, Byte>.Create;
  try
    ValidateChildren(FOwner);
  finally
    Seen.Free;
  end;
end;

procedure TRibbonModel.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  Tab: TRibbonTab;
begin
  for Tab in Tabs do
    Proc(Tab);
end;

initialization
  RegisterClasses([TRibbonTab, TRibbonGroup, TRibbonButton, TRibbonSeparator,
    TRibbonLabel, TRibbonEdit, TRibbonComboBox, TRibbonColorPicker,
    TRibbonFontPicker, TRibbonFontSizePicker, TRibbonGallery, TRibbonCheckBox,
    TRibbonRadioButton, TRibbonProgressBar, TRibbonDropDownMenu,
    TRibbonSkLabel]);

finalization
  UnRegisterClass(TRibbonSkLabel);
  UnRegisterClass(TRibbonDropDownMenu);
  UnRegisterClass(TRibbonProgressBar);
  UnRegisterClass(TRibbonRadioButton);
  UnRegisterClass(TRibbonCheckBox);
  UnRegisterClass(TRibbonGallery);
  UnRegisterClass(TRibbonFontSizePicker);
  UnRegisterClass(TRibbonFontPicker);
  UnRegisterClass(TRibbonColorPicker);
  UnRegisterClass(TRibbonComboBox);
  UnRegisterClass(TRibbonEdit);
  UnRegisterClass(TRibbonLabel);
  UnRegisterClass(TRibbonSeparator);
  UnRegisterClass(TRibbonButton);
  UnRegisterClass(TRibbonGroup);
  UnRegisterClass(TRibbonTab);

end.
