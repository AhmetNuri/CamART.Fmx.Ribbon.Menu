unit CamART.Ribbon.References;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  CamART.Ribbon.Types;

type
  ERibbonReferenceError = class(Exception);
  TRibbonCommandLinks = class;

  { A reference contains persistent IDs and presentation overrides only. It
    never acquires ownership of, or stores a pointer to, a model component. }
  TRibbonCommandLink = class(TCollectionItem)
  private
    FId: string;
    FItemId: string;
    FCommandId: string;
    FCaption: string;
    FHint: string;
    FIconKey: string;
    FOverrideCaption: Boolean;
    FOverrideHint: Boolean;
    FOverrideIcon: Boolean;
    FEnabled: Boolean;
    FVisible: Boolean;
    FButtonKind: TRibbonButtonKind;
    FIsSeparator: Boolean;
    procedure SetId(const AValue: string);
    procedure SetItemId(const AValue: string);
    procedure SetCommandId(const AValue: string);
    procedure SetCaption(const AValue: string);
    procedure SetHint(const AValue: string);
    procedure SetIconKey(const AValue: string);
    procedure SetOverrideCaption(const AValue: Boolean);
    procedure SetOverrideHint(const AValue: Boolean);
    procedure SetOverrideIcon(const AValue: Boolean);
    procedure SetEnabled(const AValue: Boolean);
    procedure SetVisible(const AValue: Boolean);
    procedure SetButtonKind(const AValue: TRibbonButtonKind);
    procedure SetIsSeparator(const AValue: Boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    function EffectiveCaption(const AInheritedCaption: string): string;
    function EffectiveHint(const AInheritedHint: string): string;
    function EffectiveIconKey(const AInheritedIconKey: string): string;
    procedure Validate;
  published
    { This string identity intentionally hides TCollectionItem's transient
      integer ID. Collection.Index remains the ordering API. }
    property Id: string read FId write SetId;
    property ItemId: string read FItemId write SetItemId;
    property CommandId: string read FCommandId write SetCommandId;
    property Caption: string read FCaption write SetCaption;
    property Hint: string read FHint write SetHint;
    property IconKey: string read FIconKey write SetIconKey;
    property OverrideCaption: Boolean read FOverrideCaption
      write SetOverrideCaption default False;
    property OverrideHint: Boolean read FOverrideHint
      write SetOverrideHint default False;
    property OverrideIcon: Boolean read FOverrideIcon
      write SetOverrideIcon default False;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Visible: Boolean read FVisible write SetVisible default True;
    property ButtonKind: TRibbonButtonKind read FButtonKind
      write SetButtonKind default rbkPush;
    property IsSeparator: Boolean read FIsSeparator
      write SetIsSeparator default False;
  end;

  { Flat QAT/application/button-menu reference collection. Add returns a draft;
    configure it in BeginUpdate/EndUpdate and call Validate before persistence
    or execution. AddItem/AddCommand/AddSeparator create complete entries. }
  TRibbonCommandLinks = class(TOwnedCollection)
  private
    FOnChanged: TNotifyEvent;
    FDestroying: Boolean;
    function GetItem(AIndex: Integer): TRibbonCommandLink;
    procedure SetItem(AIndex: Integer; const AValue: TRibbonCommandLink);
    procedure CheckUniqueId(ALink: TRibbonCommandLink; const AId: string);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AOwner: TPersistent);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    function Add: TRibbonCommandLink;
    function AddItem(const AItemId: string): TRibbonCommandLink;
    function AddCommand(const ACommandId, ACaption: string;
      const AIconKey: string = ''): TRibbonCommandLink;
    function AddSeparator: TRibbonCommandLink;
    function FindById(const AId: string): TRibbonCommandLink;
    procedure Validate;
    property Items[AIndex: Integer]: TRibbonCommandLink read GetItem
      write SetItem; default;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  System.Generics.Collections;

procedure RequireId(const AId: string);
begin
  if (AId = '') or (AId <> Trim(AId)) then
    raise ERibbonReferenceError.Create(
      'A reference ID must be nonempty and have no surrounding whitespace.');
end;

function NewId: string;
var
  G: TGUID;
begin
  if CreateGUID(G) <> 0 then
    raise ERibbonReferenceError.Create('Cannot create a persistent reference ID.');
  Result := LowerCase(GUIDToString(G));
end;

constructor TRibbonCommandLink.Create(ACollection: TCollection);
begin
  { Initialize before collection insertion: a collection update must not see
    a half-initialized identity or Boolean default. }
  inherited Create(nil);
  if (ACollection <> nil) and not (ACollection is TRibbonCommandLinks) then
    raise ERibbonReferenceError.Create('Command links require TRibbonCommandLinks.');
  FId := NewId;
  FEnabled := True;
  FVisible := True;
  FButtonKind := rbkPush;
  Collection := ACollection;
end;

procedure TRibbonCommandLink.SetId(const AValue: string);
begin
  if FId = AValue then Exit;
  RequireId(AValue);
  if Collection is TRibbonCommandLinks then
    TRibbonCommandLinks(Collection).CheckUniqueId(Self, AValue);
  FId := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetItemId(const AValue: string);
begin
  if FItemId = AValue then Exit;
  if AValue <> '' then
  begin
    RequireId(AValue);
    if (FCommandId <> '') or FIsSeparator then
      raise ERibbonReferenceError.Create(
        'An item reference cannot also be a command or a separator.');
  end;
  FItemId := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetCommandId(const AValue: string);
begin
  if FCommandId = AValue then Exit;
  if AValue <> '' then
  begin
    RequireId(AValue);
    if (FItemId <> '') or FIsSeparator then
      raise ERibbonReferenceError.Create(
        'A command reference cannot also be an item or a separator.');
  end;
  FCommandId := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetHint(const AValue: string);
begin
  if FHint = AValue then Exit;
  FHint := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetIconKey(const AValue: string);
begin
  if FIconKey = AValue then Exit;
  FIconKey := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetOverrideCaption(const AValue: Boolean);
begin
  if FOverrideCaption = AValue then Exit;
  FOverrideCaption := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetOverrideHint(const AValue: Boolean);
begin
  if FOverrideHint = AValue then Exit;
  FOverrideHint := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetOverrideIcon(const AValue: Boolean);
begin
  if FOverrideIcon = AValue then Exit;
  FOverrideIcon := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetEnabled(const AValue: Boolean);
begin
  if FEnabled = AValue then Exit;
  FEnabled := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetVisible(const AValue: Boolean);
begin
  if FVisible = AValue then Exit;
  FVisible := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetButtonKind(const AValue: TRibbonButtonKind);
begin
  if FButtonKind = AValue then Exit;
  FButtonKind := AValue;
  Changed(False);
end;

procedure TRibbonCommandLink.SetIsSeparator(const AValue: Boolean);
begin
  if FIsSeparator = AValue then Exit;
  if AValue and ((FItemId <> '') or (FCommandId <> '')) then
    raise ERibbonReferenceError.Create(
      'A separator cannot contain an item or command reference.');
  FIsSeparator := AValue;
  Changed(False);
end;

function TRibbonCommandLink.GetDisplayName: string;
begin
  if FIsSeparator then Result := '(separator)'
  else if FCaption <> '' then Result := FCaption
  else if FItemId <> '' then Result := FItemId
  else if FCommandId <> '' then Result := FCommandId
  else Result := FId;
end;

procedure TRibbonCommandLink.Assign(Source: TPersistent);
var
  Link: TRibbonCommandLink;
begin
  if Source = Self then Exit;
  if not (Source is TRibbonCommandLink) then
  begin
    inherited;
    Exit;
  end;
  Link := TRibbonCommandLink(Source);
  Link.Validate;
  if Collection is TRibbonCommandLinks then
    TRibbonCommandLinks(Collection).CheckUniqueId(Self, Link.Id);
  FId := Link.FId;
  FItemId := Link.FItemId;
  FCommandId := Link.FCommandId;
  FCaption := Link.FCaption;
  FHint := Link.FHint;
  FIconKey := Link.FIconKey;
  FOverrideCaption := Link.FOverrideCaption;
  FOverrideHint := Link.FOverrideHint;
  FOverrideIcon := Link.FOverrideIcon;
  FEnabled := Link.FEnabled;
  FVisible := Link.FVisible;
  FButtonKind := Link.FButtonKind;
  FIsSeparator := Link.FIsSeparator;
  Changed(False);
end;

function TRibbonCommandLink.EffectiveCaption(
  const AInheritedCaption: string): string;
begin
  if (FItemId = '') or FOverrideCaption then Result := FCaption
  else Result := AInheritedCaption;
end;

function TRibbonCommandLink.EffectiveHint(const AInheritedHint: string): string;
begin
  if (FItemId = '') or FOverrideHint then Result := FHint
  else Result := AInheritedHint;
end;

function TRibbonCommandLink.EffectiveIconKey(
  const AInheritedIconKey: string): string;
begin
  if (FItemId = '') or FOverrideIcon then Result := FIconKey
  else Result := AInheritedIconKey;
end;

procedure TRibbonCommandLink.Validate;
begin
  RequireId(FId);
  if FIsSeparator then
  begin
    if (FItemId <> '') or (FCommandId <> '') then
      raise ERibbonReferenceError.Create('A separator cannot execute a command.');
  end
  else if (FItemId = '') = (FCommandId = '') then
    raise ERibbonReferenceError.Create(
      'A link must reference exactly one ItemId or CommandId.');
  if FItemId <> '' then RequireId(FItemId);
  if FCommandId <> '' then
  begin
    RequireId(FCommandId);
    if not (FButtonKind in [rbkPush, rbkToggle, rbkCheck]) then
      raise ERibbonReferenceError.Create(
        'DropDown, Split and Gallery references require ItemId menu/gallery data.');
  end;
end;

constructor TRibbonCommandLinks.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TRibbonCommandLink);
end;

destructor TRibbonCommandLinks.Destroy;
begin
  FDestroying := True;
  FOnChanged := nil;
  inherited;
end;

procedure TRibbonCommandLinks.Assign(Source: TPersistent);
begin
  if Source = Self then Exit;
  if Source is TRibbonCommandLinks then TRibbonCommandLinks(Source).Validate;
  inherited;
end;

procedure TRibbonCommandLinks.Update(Item: TCollectionItem);
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
  { The callback may destroy the owner and this collection. No access follows. }
end;

function TRibbonCommandLinks.GetItem(AIndex: Integer): TRibbonCommandLink;
begin
  Result := TRibbonCommandLink(inherited Items[AIndex]);
end;

procedure TRibbonCommandLinks.SetItem(AIndex: Integer;
  const AValue: TRibbonCommandLink);
begin
  Items[AIndex].Assign(AValue);
end;

procedure TRibbonCommandLinks.CheckUniqueId(ALink: TRibbonCommandLink;
  const AId: string);
var
  Link: TRibbonCommandLink;
begin
  RequireId(AId);
  Link := FindById(AId);
  if (Link <> nil) and (Link <> ALink) then
    raise ERibbonReferenceError.CreateFmt('Duplicate reference Id: %s', [AId]);
end;

function TRibbonCommandLinks.Add: TRibbonCommandLink;
begin
  Result := TRibbonCommandLink(inherited Add);
end;

function TRibbonCommandLinks.AddItem(const AItemId: string): TRibbonCommandLink;
begin
  RequireId(AItemId);
  BeginUpdate;
  try
    Result := Add;
    Result.ItemId := AItemId;
  finally
    EndUpdate;
  end;
end;

function TRibbonCommandLinks.AddCommand(const ACommandId, ACaption,
  AIconKey: string): TRibbonCommandLink;
begin
  RequireId(ACommandId);
  BeginUpdate;
  try
    Result := Add;
    Result.CommandId := ACommandId;
    Result.Caption := ACaption;
    Result.IconKey := AIconKey;
  finally
    EndUpdate;
  end;
end;

function TRibbonCommandLinks.AddSeparator: TRibbonCommandLink;
begin
  BeginUpdate;
  try
    Result := Add;
    Result.IsSeparator := True;
  finally
    EndUpdate;
  end;
end;

function TRibbonCommandLinks.FindById(const AId: string): TRibbonCommandLink;
var
  I: Integer;
begin
  if AId <> '' then
    for I := 0 to Count - 1 do
      if Items[I].Id = AId then Exit(Items[I]);
  Result := nil;
end;

procedure TRibbonCommandLinks.Validate;
var
  Seen: TDictionary<string, Byte>;
  I: Integer;
begin
  Seen := TDictionary<string, Byte>.Create;
  try
    for I := 0 to Count - 1 do
    begin
      Items[I].Validate;
      if Seen.ContainsKey(Items[I].Id) then
        raise ERibbonReferenceError.CreateFmt('Duplicate reference Id: %s', [Items[I].Id]);
      Seen.Add(Items[I].Id, 0);
    end;
  finally
    Seen.Free;
  end;
end;

end.
