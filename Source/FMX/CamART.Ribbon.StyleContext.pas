unit CamART.Ribbon.StyleContext;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Messaging,
  FMX.Types,
  FMX.Controls,
  CamART.Ribbon.Types,
  CamART.Ribbon.Themes;

type
  { One context per Ribbon. Books and host are borrowed and weakly observed.
    Preset templates are owned here; controls receive clones for live styles.
    No form assignment or global style-manager mutation is performed. }
  TRibbonStyleContext = class(TComponent)
  private
    FHost: TControl;
    FStyleBook: TStyleBook;
    FObservedBook: TStyleBook;
    FObservedRoot: TFmxObject;
    FObservedScene: Pointer;
    FTheme: TRibbonTheme;
    FThemeMode: TRibbonThemeMode;
    FInheritFormNativeStyles: Boolean;
    FMetrics: TRibbonMetrics;
    FRevision: UInt64;
    FPresets: TObjectDictionary<TRibbonStyleRole, TFmxObject>;
    FDiagnostics: TStringList;
    FOnChanged: TNotifyEvent;
    FSubscription: Integer;
    FSubscribed: Boolean;
    FClosing: Boolean;
    procedure SetStyleBook(const AValue: TStyleBook);
    procedure SetTheme(const AValue: TRibbonTheme);
    procedure SetThemeMode(const AValue: TRibbonThemeMode);
    procedure SetInheritFormNativeStyles(const AValue: Boolean);
    function GetMetrics: TRibbonMetrics;
    function SceneStyleBook: TStyleBook;
    function ManualThemeActive: Boolean;
    function GetEffectiveStyleBook: TStyleBook;
    function GetDiagnostics: string;
    function Capture: Boolean;
    procedure Changed;
    procedure StyleMessage(const Sender: TObject; const M: TMessage);
    function PresetTemplate(ARole: TRibbonStyleRole): TFmxObject;
    function BookTemplate(AControl: TStyledControl;
      const ANames: array of string): TFmxObject;
    procedure AddDiagnostic(const AText: string);
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent; AHost: TControl); reintroduce;
    destructor Destroy; override;
    { Call after directly editing a shared template's properties; ordinary
      book/form changes are observed through FMX messages and identity checks. }
    procedure Refresh;
    { Bind source-image lookup only on an owned clone. The selected book's
      atlas must not be replaced later by the host form's different atlas.
      ATemplate is the original borrowed source and preserves atlas origin. }
    procedure BindStyleSources(AControl: TStyledControl;
      AClone, ATemplate: TFmxObject);
    function CheckForChanges: Boolean;
    function ResolveRibbonStyle(AControl: TStyledControl;
      ARole: TRibbonStyleRole; const AClone: Boolean = True): TFmxObject;
    function ResolveNativeStyle(AControl: TStyledControl;
      const ADefaultName: string; const AClone: Boolean = True): TFmxObject;
    property StyleBook: TStyleBook read FStyleBook write SetStyleBook;
    property EffectiveStyleBook: TStyleBook read GetEffectiveStyleBook;
    property Theme: TRibbonTheme read FTheme write SetTheme;
    property ThemeMode: TRibbonThemeMode read FThemeMode write SetThemeMode;
    { With an explicit component StyleBook, native controls missing from it
      use the form/scene book before the platform style. Off by default:
      the component book then stays fully isolated (historical rule). }
    property InheritFormNativeStyles: Boolean read FInheritFormNativeStyles
      write SetInheritFormNativeStyles;
    { Borrowed from the Ribbon; never nil for readers (shared defaults). }
    property Metrics: TRibbonMetrics read GetMetrics write FMetrics;
    property Revision: UInt64 read FRevision;
    property Diagnostics: string read GetDiagnostics;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

{ Shared, read-only-by-convention defaults for views outside any Ribbon
  scope (for example before parenting). Never modify the returned object. }
function RibbonDefaultMetrics: TRibbonMetrics;

implementation

uses
  FMX.Styles,
  FMX.Styles.Objects,
  FMX.Objects,
  CamART.Ribbon.ThemeStyles;

var
  GDefaultMetrics: TRibbonMetrics;

function RibbonDefaultMetrics: TRibbonMetrics;
begin
  if GDefaultMetrics = nil then GDefaultMetrics := TRibbonMetrics.Create;
  Result := GDefaultMetrics;
end;

function ResourceIn(ARoot: TFmxObject; const AName: string): TFmxObject;
begin
  Result := nil;
  if (ARoot = nil) or (AName = '') then Exit;
  if SameText(ARoot.StyleName, AName) then Exit(ARoot);
  { No scene/global pool search: search this selected template tree only. }
  Result := ARoot.FindStyleResource(AName, False);
end;

function StyleResult(ATemplate: TFmxObject; AClone: Boolean): TFmxObject;
begin
  Result := ATemplate;
  if AClone and (Result <> nil) then Result := Result.Clone(nil);
end;

function NativeName(ARole: TRibbonStyleRole): string;
begin
  case ARole of
    rsrTab, rsrLargeButton, rsrSmallButton, rsrIconButton, rsrSplitButton,
    rsrQuickAccess, rsrApplicationButton, rsrCollapsedGroup, rsrMenuItem:
      Result := 'buttonstyle';
    rsrGalleryItem: Result := 'listboxitemstyle';
    rsrPopup: Result := 'popupstyle';
    rsrLabel: Result := 'labelstyle';
    rsrCheckBox: Result := 'checkboxstyle';
    rsrRadioButton: Result := 'radiobuttonstyle';
  else
    Result := '';
  end;
end;

constructor TRibbonStyleContext.Create(AOwner: TComponent; AHost: TControl);
begin
  inherited Create(AOwner);
  if AHost = nil then raise EArgumentNilException.Create('A Ribbon style host is required.');
  FHost := AHost;
  TComponent(FHost).FreeNotification(Self);
  FTheme := rtModernLight;
  FRevision := 1;
  FPresets := TObjectDictionary<TRibbonStyleRole, TFmxObject>.Create([doOwnsValues]);
  FDiagnostics := TStringList.Create;
  FDiagnostics.CaseSensitive := True;
  FSubscription := TMessageManager.DefaultManager.SubscribeToMessage(
    TStyleChangedMessage, StyleMessage);
  FSubscribed := True;
  Capture;
end;

destructor TRibbonStyleContext.Destroy;
begin
  FClosing := True;
  FOnChanged := nil;
  if FSubscribed then
    TMessageManager.DefaultManager.Unsubscribe(TStyleChangedMessage, FSubscription);
  if FHost <> nil then TComponent(FHost).RemoveFreeNotification(Self);
  if FStyleBook <> nil then TComponent(FStyleBook).RemoveFreeNotification(Self);
  if (FObservedBook <> nil) and (FObservedBook <> FStyleBook) then
    TComponent(FObservedBook).RemoveFreeNotification(Self);
  FHost := nil;
  FStyleBook := nil;
  FObservedBook := nil;
  FObservedRoot := nil;
  FPresets.Free;
  FDiagnostics.Free;
  inherited;
end;

function TRibbonStyleContext.GetEffectiveStyleBook: TStyleBook;
begin
  Result := nil;
  if FClosing or (FHost = nil) or (csDestroying in FHost.ComponentState) then Exit;
  if (FStyleBook <> nil) and not (csDestroying in FStyleBook.ComponentState) then
    Exit(FStyleBook);
  { The explicit component book is the only user book when assigned.
    Clearing/freeing it restores the host form/scene's book. }
  if FHost.Scene <> nil then Result := FHost.Scene.GetStyleBook;
  if (Result <> nil) and (csDestroying in Result.ComponentState) then Result := nil;
end;

function TRibbonStyleContext.Capture: Boolean;
var
  Book: TStyleBook;
  Root: TFmxObject;
  SceneKey: Pointer;
begin
  Book := GetEffectiveStyleBook;
  Root := nil;
  if (Book <> nil) and (FHost <> nil) then Root := Book.GetStyle(FHost);
  SceneKey := nil;
  if (FHost <> nil) and not (csDestroying in FHost.ComponentState) and
     (FHost.Scene <> nil) then
    SceneKey := Pointer(FHost.Scene.GetObject);
  Result := (Book <> FObservedBook) or (Root <> FObservedRoot) or
    (SceneKey <> FObservedScene);
  if Book <> FObservedBook then
  begin
    if (FObservedBook <> nil) and (FObservedBook <> FStyleBook) then
      TComponent(FObservedBook).RemoveFreeNotification(Self);
    FObservedBook := Book;
    if FObservedBook <> nil then TComponent(FObservedBook).FreeNotification(Self);
  end;
  FObservedRoot := Root;
  FObservedScene := SceneKey;
end;

procedure TRibbonStyleContext.Changed;
var
  Handler: TNotifyEvent;
begin
  if FClosing then Exit;
  if FRevision = High(UInt64) then FRevision := 1 else Inc(FRevision);
  FDiagnostics.Clear;
  Handler := FOnChanged;
  { Host is allowed to destroy the Ribbon/context. This callback is last. }
  if Assigned(Handler) then Handler(Self);
end;

procedure TRibbonStyleContext.Refresh;
begin
  if FClosing then Exit;
  Capture;
  Changed;
end;

function TRibbonStyleContext.CheckForChanges: Boolean;
begin
  Result := False;
  if FClosing then Exit;
  Result := Capture;
  if Result then Changed;
end;

procedure TRibbonStyleContext.SetStyleBook(const AValue: TStyleBook);
var
  Previous: TStyleBook;
begin
  if FStyleBook = AValue then Exit;
  if (AValue <> nil) and (csDestroying in AValue.ComponentState) then
    raise EArgumentException.Create('A Ribbon cannot select a StyleBook during destruction.');
  Previous := FStyleBook;
  FStyleBook := AValue;
  if (Previous <> nil) and (Previous <> FObservedBook) then
    TComponent(Previous).RemoveFreeNotification(Self);
  if FStyleBook <> nil then TComponent(FStyleBook).FreeNotification(Self);
  Refresh;
end;

procedure TRibbonStyleContext.SetThemeMode(const AValue: TRibbonThemeMode);
begin
  if (Ord(AValue) < Ord(Low(TRibbonThemeMode))) or
     (Ord(AValue) > Ord(High(TRibbonThemeMode))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon theme mode.');
  if FThemeMode = AValue then Exit;
  FThemeMode := AValue;
  Refresh;
end;

procedure TRibbonStyleContext.SetInheritFormNativeStyles(const AValue: Boolean);
begin
  if FInheritFormNativeStyles = AValue then Exit;
  FInheritFormNativeStyles := AValue;
  Refresh;
end;

function TRibbonStyleContext.GetMetrics: TRibbonMetrics;
begin
  Result := FMetrics;
  if Result = nil then Result := RibbonDefaultMetrics;
end;

function TRibbonStyleContext.SceneStyleBook: TStyleBook;
begin
  Result := nil;
  if FClosing or (FHost = nil) or (csDestroying in FHost.ComponentState) or
     (FHost.Scene = nil) then Exit;
  Result := FHost.Scene.GetStyleBook;
  if (Result <> nil) and (csDestroying in Result.ComponentState) then Result := nil;
end;

function TRibbonStyleContext.ManualThemeActive: Boolean;
begin
  { An explicit component book is the most specific choice and wins. }
  Result := (FThemeMode = rtmManual) and (FStyleBook = nil);
end;

procedure TRibbonStyleContext.SetTheme(const AValue: TRibbonTheme);
begin
  if (Ord(AValue) < Ord(Low(TRibbonTheme))) or
     (Ord(AValue) > Ord(High(TRibbonTheme))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon theme.');
  if FTheme = AValue then Exit;
  FTheme := AValue;
  FPresets.Clear;
  { Do not erase StyleLookup, override a selected book, or modify its tree. }
  Refresh;
end;

procedure TRibbonStyleContext.StyleMessage(const Sender: TObject; const M: TMessage);
var
  MessageData: TStyleChangedMessage;
  SelectedBook: TStyleBook;
begin
  if FClosing or (FHost = nil) or (csDestroying in FHost.ComponentState) or
     not (M is TStyleChangedMessage) then Exit;
  MessageData := TStyleChangedMessage(M);
  SelectedBook := GetEffectiveStyleBook;
  { A manager-wide change can replace native-control fallback resources. }
  if (MessageData.Value = nil) and (MessageData.Scene = nil) then
  begin
    Refresh;
    Exit;
  end;
  { A selected book changed independently of a scene. Assigning the same
    book to an unrelated popup/form is not a change to this Ribbon's style. }
  if (MessageData.Scene = nil) and (SelectedBook <> nil) and
     (MessageData.Value = SelectedBook) then
  begin
    Refresh;
    Exit;
  end;
  if ((FStyleBook = nil) or FInheritFormNativeStyles) and
     (MessageData.Scene = FHost.Scene) then
  begin
    { The form book is in use: directly, or as native-control fallback. }
    Refresh;
    Exit;
  end;
  if (SelectedBook <> nil) and (MessageData.Value = SelectedBook) then
    { Load/reload can change the template identity even when a notification
      was sent for another scene. No event is raised for identity equality. }
    CheckForChanges;
end;

procedure TRibbonStyleContext.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  ChangedBook: Boolean;
begin
  inherited;
  if Operation <> opRemove then Exit;
  if AComponent = FHost then
  begin
    FHost := nil;
    FOnChanged := nil;
    Exit;
  end;
  ChangedBook := False;
  if AComponent = FStyleBook then
  begin
    FStyleBook := nil;
    ChangedBook := True;
  end;
  if AComponent = FObservedBook then
  begin
    FObservedBook := nil;
    FObservedRoot := nil;
    ChangedBook := True;
  end;
  if ChangedBook and not FClosing then Refresh;
end;

function TRibbonStyleContext.GetDiagnostics: string;
begin
  Result := Trim(FDiagnostics.Text);
end;

procedure TRibbonStyleContext.AddDiagnostic(const AText: string);
begin
  if FDiagnostics.IndexOf(AText) < 0 then FDiagnostics.Add(AText);
end;

function TRibbonStyleContext.BookTemplate(AControl: TStyledControl;
  const ANames: array of string): TFmxObject;
var
  Book: TStyleBook;
  Root: TFmxObject;
  Name: string;
begin
  Result := nil;
  Book := GetEffectiveStyleBook;
  if Book = nil then Exit;
  Root := Book.GetStyle(AControl);
  for Name in ANames do
  begin
    Result := ResourceIn(Root, Name);
    if Result <> nil then Exit;
  end;
end;

procedure TRibbonStyleContext.BindStyleSources(AControl: TStyledControl;
  AClone, ATemplate: TFmxObject);
var
  Book, SceneBook: TStyleBook;
  BookRoot, SceneRoot, PlatformRoot, Origin: TFmxObject;
  FromSelectedBook: Boolean;

  procedure Visit(AObject: TFmxObject);
  var
    Styled: TCustomStyleObject;
    ImageResource: TFmxObject;
    Child: TFmxObject;
    Lookup: string;
  begin
    if AObject is TCustomStyleObject then
    begin
      Styled := TCustomStyleObject(AObject);
      Lookup := Styled.SourceLookup;
      if Lookup <> '' then
      begin
        ImageResource := ResourceIn(AClone, Lookup);
        if not (ImageResource is TImage) and FromSelectedBook then
          ImageResource := ResourceIn(BookRoot, Lookup);
        if not (ImageResource is TImage) then
          ImageResource := ResourceIn(PlatformRoot, Lookup);
        { Clear lookup before setting Source: only the clone is changed.
          A later native scene lookup cannot select a different form atlas. }
        Styled.SourceLookup := '';
        if ImageResource is TImage then Styled.Source := TImage(ImageResource)
        else
        begin
          Styled.Source := nil;
          AddDiagnostic('Style image "' + Lookup +
            '" is missing from the selected book and application/platform style.');
        end;
      end;
    end;
    if AObject.Children <> nil then
      for Child in AObject.Children do Visit(Child);
  end;

begin
  if (AClone = nil) or FClosing then Exit;
  if AControl = nil then raise EArgumentNilException.Create('A style control is required.');
  Book := GetEffectiveStyleBook;
  BookRoot := nil;
  if Book <> nil then BookRoot := Book.GetStyle(AControl);
  SceneRoot := nil;
  if FInheritFormNativeStyles and (FStyleBook <> nil) then
  begin
    SceneBook := SceneStyleBook;
    if (SceneBook <> nil) and (SceneBook <> FStyleBook) then
      SceneRoot := SceneBook.GetStyle(AControl);
  end;
  PlatformRoot := TStyleManager.ActiveStyle(AControl);
  FromSelectedBook := False;
  Origin := ATemplate;
  while Origin <> nil do
  begin
    if Origin = BookRoot then
    begin
      FromSelectedBook := True;
      Break;
    end;
    { An inherited form-book template keeps the form book's own atlas. }
    if (SceneRoot <> nil) and (Origin = SceneRoot) then
    begin
      BookRoot := SceneRoot;
      FromSelectedBook := True;
      Break;
    end;
    Origin := Origin.Parent;
  end;
  { A complete platform fallback template keeps its own atlas coordinate
    system. A sparse component book with a colliding image name must not
    replace that platform atlas. Only selected-book templates prefer BookRoot. }
  Visit(AClone);
end;

function TRibbonStyleContext.PresetTemplate(ARole: TRibbonStyleRole): TFmxObject;
begin
  if not FPresets.TryGetValue(ARole, Result) then
  begin
    Result := CreateRibbonThemeStyle(ARole, FTheme);
    try
      FPresets.Add(ARole, Result);
    except
      Result.Free;
      raise;
    end;
  end;
end;

function TRibbonStyleContext.ResolveRibbonStyle(AControl: TStyledControl;
  ARole: TRibbonStyleRole; const AClone: Boolean): TFmxObject;
var
  Template: TFmxObject;
  Lookup, RoleName, StandardName: string;
begin
  if AControl = nil then raise EArgumentNilException.Create('A style control is required.');
  if (Ord(ARole) < Ord(Low(TRibbonStyleRole))) or
     (Ord(ARole) > Ord(High(TRibbonStyleRole))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon style role.');
  Lookup := AControl.StyleLookup;
  RoleName := RibbonThemeStyleName(ARole);
  StandardName := NativeName(ARole);
  if ManualThemeActive then
  begin
    { Manual theme: the form book does not repaint Ribbon roles. Only an
      explicit per-control StyleLookup is still honoured. }
    Template := nil;
    if (Lookup <> '') and (Lookup <> RoleName) then
      Template := BookTemplate(AControl, [Lookup]);
  end
  else
    Template := BookTemplate(AControl, [Lookup, RoleName, StandardName]);
  if (Template <> nil) and not (ARole in [rsrRoot, rsrGroup, rsrPopup,
    rsrSeparator]) and (Template.FindStyleResource('text', False) = nil) then
  begin
    { Textual native roles need a named text resource. Do not cast it to a
      particular renderer type: a valid user style may use a native text
      renderer other than TText. Only absence triggers this safe fallback. }
    AddDiagnostic('Ribbon style "' + Template.StyleName +
      '" has no text resource; using a readable fallback for ' + RoleName + '.');
    Template := PresetTemplate(ARole);
  end;
  if Template = nil then
  begin
    if (Lookup <> '') and (Lookup <> RoleName) then
      AddDiagnostic('StyleLookup "' + Lookup + '" was not found in the selected book; ' +
        'using the Ribbon fallback for ' + RoleName + '.');
    Template := PresetTemplate(ARole);
  end;
  Result := StyleResult(Template, AClone);
  if AClone then
    try
      BindStyleSources(AControl, Result, Template);
    except
      Result.Free;
      raise;
    end;
end;

function TRibbonStyleContext.ResolveNativeStyle(AControl: TStyledControl;
  const ADefaultName: string; const AClone: Boolean): TFmxObject;
var
  Template, Root: TFmxObject;
  SceneBook: TStyleBook;
begin
  if AControl = nil then raise EArgumentNilException.Create('A style control is required.');
  Template := BookTemplate(AControl, [AControl.StyleLookup, ADefaultName]);
  if (Template = nil) and FInheritFormNativeStyles and (FStyleBook <> nil) then
  begin
    { Opt-in: a component book that styles only Ribbon roles lets the
      application's form book supply complete native controls. }
    SceneBook := SceneStyleBook;
    if (SceneBook <> nil) and (SceneBook <> FStyleBook) then
    begin
      Root := SceneBook.GetStyle(AControl);
      Template := ResourceIn(Root, AControl.StyleLookup);
      if Template = nil then Template := ResourceIn(Root, ADefaultName);
    end;
  end;
  if Template = nil then
  begin
    { Keep complete native edit/combo/list/check semantics. Do not call
      inherited scene lookup here: that could reintroduce the form's book
      after the user chose an independent component book. }
    Root := TStyleManager.ActiveStyle(AControl);
    Template := ResourceIn(Root, AControl.StyleLookup);
    if Template = nil then Template := ResourceIn(Root, ADefaultName);
  end;
  if Template = nil then
    AddDiagnostic('Native style "' + ADefaultName + '" is unavailable in the selected ' +
      'book and application/platform style.');
  Result := StyleResult(Template, AClone);
  if AClone then
    try
      BindStyleSources(AControl, Result, Template);
    except
      Result.Free;
      raise;
    end;
end;

initialization

finalization
  GDefaultMetrics.Free;

end.
