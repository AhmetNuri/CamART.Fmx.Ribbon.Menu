unit CamART.Ribbon.Control;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  FMX.Types,
  FMX.Controls,
  FMX.Layouts,
  FMX.StdCtrls,
  FMX.ActnList,
  CamART.Ribbon.Types,
  CamART.Ribbon.Model,
  CamART.Ribbon.Commands,
  CamART.Ribbon.References,
  CamART.Ribbon.State,
  CamART.Ribbon.Layout,
  CamART.Ribbon.Style,
  CamART.Ribbon.Themes,
  CamART.Ribbon.StyleContext,
  CamART.Ribbon.StyleScope,
  CamART.Ribbon.Views,
  CamART.Ribbon.ViewData,
  CamART.Ribbon.ViewFactory,
  CamART.Ribbon.Bindings,
  CamART.Ribbon.ReferenceBindings,
  CamART.Ribbon.Auxiliary,
  CamART.Ribbon.Icons,
  CamART.Ribbon.SkLabels,
  CamART.Ribbon.Actions,
  CamART.Ribbon.Popups,
  CamART.Ribbon.GroupPopup,
  CamART.Ribbon.Interaction,
  CamART.Ribbon.Fonts,
  CamART.Ribbon.Presenter;

type
  { A complete, JSON-independent configuration snapshot. StyleBook is
    deliberately absent: it is a component/form reference, not file data. }
  TRibbonConfigurationSettings = record
    Theme: TRibbonTheme;
    HasActiveTabId: Boolean;
    ActiveTabId: string;
    Collapsed: Boolean;
    QuickAccessVisible: Boolean;
    QuickAccessPosition: TRibbonQATPosition;
    ApplicationCaption: string;
    ApplicationButtonVisible: Boolean;
    ExpandedHeight: Single;
    InputDensity: TRibbonInputDensity;
    ReduceMotion: Boolean;
    CompactCaption: string;
  end;

  { The logical commit has succeeded. A native presentation or application
    observer subsequently raised; callers must NOT retry as an uncommitted
    import or claim that the old graph remains active. }
  ERibbonConfigurationCommittedError = class(Exception);

  TRibbonDiagnosticEvent = procedure(Sender: TObject;
    const AMessage: string) of object;

  TRibbonPopupContextKind = (rpcNone, rpcApplication, rpcButtonMenu, rpcGallery,
    rpcGroups);

  { The component is the composition root, not a business-command handler.
    Model components and persistent visual hosts have different lifetimes.
    All API calls must be made on the FMX UI thread. }
  TCamARTRibbon = class(TStyledControl, IRibbonModelHost, IRibbonStyleScope)
  private
    FModel: TRibbonModel;
    FSelection: TRibbonSelectionController;
    FLayoutEngine: IRibbonLayoutEngine;
    FCommands: IRibbonCommandRegistry;
    FCommandResolver: IRibbonCommandResolver;
    FStyleAdapter: TRibbonStyleAdapter;
    FStyleContext: TRibbonStyleContext;
    FApplyingTheme, FThemeRefreshPending: Boolean;
    FApplyingConfiguration: Boolean;
    FLastStyleDiagnostic: string;
    FNativeDisabledOpacity: Single;
    FPresenter: TRibbonPresenter;
    FBindings: TRibbonBindingRegistry;
    FReferenceResolver: TRibbonReferenceResolver;
    FQuickAccess: TRibbonCommandLinks;
    FApplicationMenu: TRibbonCommandLinks;
    FQuickAccessVisible: Boolean;
    FQuickAccessPosition: TRibbonQATPosition;
    FQuickAccessPresenter: TRibbonAuxiliaryPresenter;
    FQuickAccessScroll: THorzScrollBox;
    FQuickAccessHost: TLayout;
    FApplicationButton: TButton;
    FApplicationCaption: string;
    FApplicationButtonVisible: Boolean;
    FApplicationMeasure: TRibbonTextMeasure;
    FIcons: IRibbonIconRegistry;
    FIconProvider: IRibbonIconProvider;
    FSkLabels: IRibbonSkLabelRegistry;
    FFontProvider: IRibbonFontProvider;
    FPopups: TRibbonPopupService;
    FGroupPopup: TRibbonGroupPopupService;
    FCompactButton: TRibbonInputButton;
    FCompactCaption: string;
    FInputDensity: TRibbonInputDensity;
    FReduceMotion: Boolean;
    FLastLayout: TRibbonLayoutResult;
    FLastGroups: TArray<TRibbonGroupViewData>;
    FLayoutPassCount: Integer;
    FContextWatch: TTimer;
    FLastSceneScale: Single;
    FLastIconRevision: UInt64;
    FLastSkLabelRevision: UInt64;
    FPopupContext: TRibbonPopupContextKind;
    FPopupOwnerId: string;
    FTabScroll: THorzScrollBox;
    FBodyScroll: TScrollBox;
    FTabHost: TLayout;
    FHeaderHost: TLayout;
    FBodyHost: TLayout;
    FReady: Boolean;
    FDestroying: Boolean;
    FRefreshing: Boolean;
    FRestoring: Boolean;
    FRefreshRequested: Boolean;
    FCollapsed: Boolean;
    FExpandedHeight: Single;
    FPendingActiveTabId: string;
    FSelectionEventPending: Boolean;
    FRefreshCount: Integer;
    FOnActiveTabChanged: TNotifyEvent;
    FOnCollapsedChanged: TNotifyEvent;
    FOnDiagnostic: TRibbonDiagnosticEvent;
    function GetStyleBook: TStyleBook;
    procedure SetStyleBook(const AValue: TStyleBook);
    function GetEffectiveStyleBook: TStyleBook;
    function GetTheme: TRibbonTheme;
    procedure SetTheme(const AValue: TRibbonTheme);
    function GetStyleDiagnostics: string;
    procedure StyleContextChanged(Sender: TObject);
    procedure ApplyTheme;
    procedure UpdateThemeEnabled;
    procedure ModelChanged(Sender: TObject; const Changes: TRibbonChanges);
    procedure RefreshInternal(AInvalidateMeasurements: Boolean);
    procedure Relayout;
    procedure SetInputDensity(const AValue: TRibbonInputDensity);
    procedure SetReduceMotion(const AValue: Boolean);
    procedure SetCompactCaption(const AValue: string);
    procedure ConfigureScrolling;
    procedure ContextPulse(Sender: TObject);
    procedure GroupClicked(Sender: TObject; const AId: string);
    procedure GroupPopupInput(Sender: TObject; const AInput: TRibbonItemInput);
    procedure CompactClicked(Sender: TObject);
    procedure SyncGroupPopup;
    procedure EnsureSelectedTabVisible;
    procedure AttachInputControls(AObject: TFmxObject);
    function GroupSnapshot(const AId: string;
      out AData: TRibbonGroupViewData): Boolean;
    function GetLayoutMode: TRibbonLayoutMode;
    function GetMeasurementPassCount: Integer;
    function GetMeasurementCacheHitCount: Integer;
    procedure TabClicked(Sender: TObject; const AId: string);
    procedure ItemInput(Sender: TObject; const AInput: TRibbonItemInput);
    procedure QuickAccessInput(Sender: TObject; const AInput: TRibbonItemInput);
    procedure ReferencesChanged(Sender: TObject);
    procedure ApplicationClicked(Sender: TObject);
    procedure PopupSelected(Sender: TObject; const AId: string);
    function TryClosePopup: Boolean;
    procedure SetQuickAccess(const AValue: TRibbonCommandLinks);
    procedure SetApplicationMenu(const AValue: TRibbonCommandLinks);
    procedure SetQuickAccessVisible(const AValue: Boolean);
    procedure SetQuickAccessPosition(const AValue: TRibbonQATPosition);
    procedure SetApplicationCaption(const AValue: string);
    procedure SetApplicationButtonVisible(const AValue: Boolean);
    procedure SetIconProvider(const AValue: IRibbonIconProvider);
    function GetSvgIcons: IRibbonSvgIconRegistry;
    procedure SetFontProvider(const AValue: IRibbonFontProvider);
    function GetViewFactory: TRibbonViewFactory;
    function QuickAccessData: TArray<TRibbonItemViewData>;
    function PopupData(ALinks: TRibbonCommandLinks): TArray<TRibbonPopupEntry>;
    function ExecuteReference(AReference: TRibbonCommandLink;
      AAnchor: TControl): TRibbonDispatchResult;
    function ExecuteButton(AButton: TRibbonButton;
      ARespectModelAncestors: Boolean): TRibbonDispatchResult;
    function SelectGalleryEntry(const AGalleryId, AEntryId: string;
      APopupPresentation: Boolean): TRibbonDispatchResult;
    procedure OpenButtonPopup(const AId: string; AAnchor: TControl;
      ARespectModelAncestors: Boolean);
    function GetActiveTabId: string;
    procedure SetActiveTabId(const AValue: string);
    procedure SetCollapsed(const AValue: Boolean);
    function GetExpandedHeight: Single;
    procedure SetExpandedHeight(const AValue: Single);
    procedure SetLayoutEngine(const AValue: IRibbonLayoutEngine);
    procedure SetCommandResolver(const AValue: IRibbonCommandResolver);
    function TabStates: TArray<TRibbonTabState>;
    procedure MakeViewData(out ATabs: TArray<TRibbonTabViewData>;
      out AGroups: TArray<TRibbonGroupViewData>);
    procedure LayoutViews;
    function HostAllowsExecution: Boolean;
    procedure ReportDiagnostic(const AMessage: string);
    procedure ValidateInheritedStreamChild(AChild: TComponent);
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
    procedure ApplyStyle; override;
    procedure FreeStyle; override;
    procedure DoResized; override;
    procedure Loaded; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState); override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    function GetChildOwner: TComponent; override;
    function GetChildParent: TComponent; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetRibbonModel: TRibbonModel;
    function GetRibbonStyleContext: TRibbonStyleContext;
    procedure RefreshTheme;
    procedure RecalcEnabled; override;
    function AddTab(const ACaption: string): TRibbonTab;
    procedure RemoveTab(ATab: TRibbonTab);
    procedure Clear;
    { Model batching is independent of the inherited FMX visual update scope. }
    procedure BeginUpdate; reintroduce;
    procedure EndUpdate; reintroduce;
    procedure Refresh;
    procedure RefreshCommands;
    function CaptureConfigurationSettings: TRibbonConfigurationSettings;
    { ASource is a detached staging model with no observer and no open batch.
      On success its owner keeps the former live tabs, to be freed by its
      caller. Links are cloned before mutation. Calls require the UI thread
      and cannot nest inside another model/configuration update. }
    procedure ApplyConfiguration(ASource: TRibbonModel;
      AQuickAccess, AApplicationMenu: TRibbonCommandLinks;
      const ASettings: TRibbonConfigurationSettings);
    procedure BindAction(const ACommandId: string; AAction: TCustomAction);
    procedure PopulateFonts(APicker: TRibbonFontPicker);
    procedure ClosePopup;
    procedure ShowApplicationMenu;
    procedure ShowGroupPopup(const AGroupId: string);
    procedure ShowCompactMenu;
    function GroupPopupIsOpen: Boolean;
    function FindGroupPopupView(const AId: string): TControl;
    function FindGroupLauncher(const AId: string): TRibbonGroupLauncher;
    function GroupPresentation(const AId: string): TRibbonGroupPresentation;
    function PopupIsOpen: Boolean;
    function ExecuteQuickAccessById(const AId: string): TRibbonDispatchResult;
    function GetButtonChecked(const AId: string): Boolean;
    function FindItemView(const AId: string): TControl;
    function FindQuickAccessView(const AId: string): TControl;
    function VisualItemCount: Integer;
    function QuickAccessViewCount: Integer;
    function ExecuteButtonById(const AId: string): TRibbonDispatchResult;
    function FindButtonView(const AId: string): TRibbonCommandButton;
    function FindTabView(const AId: string): TRibbonTabButton;
    function VisualButtonCount: Integer;
    function VisualGroupCount: Integer;
    function VisualTabCount: Integer;
    property Model: TRibbonModel read FModel;
    property EffectiveStyleBook: TStyleBook read GetEffectiveStyleBook;
    property StyleDiagnostics: string read GetStyleDiagnostics;
    property Commands: IRibbonCommandRegistry read FCommands;
    property CommandResolver: IRibbonCommandResolver read FCommandResolver
      write SetCommandResolver;
    property LayoutEngine: IRibbonLayoutEngine read FLayoutEngine
      write SetLayoutEngine;
    { Diagnostic counter: completed view/layout passes, not paint calls. }
    property RefreshCount: Integer read FRefreshCount;
    property LayoutPassCount: Integer read FLayoutPassCount;
    property MeasurementPassCount: Integer read GetMeasurementPassCount;
    property MeasurementCacheHitCount: Integer read GetMeasurementCacheHitCount;
    property LayoutMode: TRibbonLayoutMode read GetLayoutMode;
    property Bindings: TRibbonBindingRegistry read FBindings;
    property ViewFactory: TRibbonViewFactory read GetViewFactory;
    property Icons: IRibbonIconRegistry read FIcons;
    property SvgIcons: IRibbonSvgIconRegistry read GetSvgIcons;
    { TSkLabel templates for sklabel items; snapshots, caller keeps sources. }
    property SkLabels: IRibbonSkLabelRegistry read FSkLabels;
    property IconProvider: IRibbonIconProvider read FIconProvider write SetIconProvider;
    property FontProvider: IRibbonFontProvider read FFontProvider write SetFontProvider;
  published
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Margins;
    property Padding;
    property Position;
    property Size;
    property StyleLookup;
    property StyleBook: TStyleBook read GetStyleBook write SetStyleBook;
    property Theme: TRibbonTheme read GetTheme write SetTheme default rtModernLight;
    property InputDensity: TRibbonInputDensity read FInputDensity
      write SetInputDensity default ridPointer;
    property ReduceMotion: Boolean read FReduceMotion write SetReduceMotion default True;
    property CompactCaption: string read FCompactCaption write SetCompactCaption;
    property QuickAccess: TRibbonCommandLinks read FQuickAccess write SetQuickAccess;
    property QuickAccessVisible: Boolean read FQuickAccessVisible
      write SetQuickAccessVisible default True;
    property QuickAccessPosition: TRibbonQATPosition read FQuickAccessPosition
      write SetQuickAccessPosition default rqpAbove;
    property ApplicationMenu: TRibbonCommandLinks read FApplicationMenu write SetApplicationMenu;
    property ApplicationCaption: string read FApplicationCaption write SetApplicationCaption;
    property ApplicationButtonVisible: Boolean read FApplicationButtonVisible
      write SetApplicationButtonVisible default True;
    property TabOrder;
    property ActiveTabId: string read GetActiveTabId write SetActiveTabId;
    property Collapsed: Boolean read FCollapsed write SetCollapsed default False;
    property ExpandedHeight: Single read GetExpandedHeight write SetExpandedHeight;
    property OnActiveTabChanged: TNotifyEvent read FOnActiveTabChanged
      write FOnActiveTabChanged;
    property OnCollapsedChanged: TNotifyEvent read FOnCollapsedChanged
      write FOnCollapsedChanged;
    property OnDiagnostic: TRibbonDiagnosticEvent read FOnDiagnostic
      write FOnDiagnostic;
  end;

implementation

uses
  System.Math,
  System.UITypes,
  FMX.InertialMovement,
  FMX.BehaviorManager,
  CamART.Ribbon.ThemeStyles,
  CamART.Ribbon.StyledControls,
  System.Generics.Collections;

const
  { Visible logical-unit gap between group frames and the frame/underline
    surrounding the expanded Ribbon body. }
  RibbonBodyFrameGap = 4;

type
  { A callback is allowed to free its button or Ribbon. This observer is owned
    by the stack frame, not by either watched component. No freed object is
    touched when deciding whether to send a post-execution notification. }
  TRibbonExecutionGuard = class(TComponent)
  private
    FRoot: TCamARTRibbon;
    FItem: TRibbonItem;
    FControl: TControl;
    FSourceOwner: TComponent;
    function GetButton: TRibbonButton;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateGuard(ARoot: TCamARTRibbon; AItem: TRibbonItem;
      AControl: TControl = nil; ASourceOwner: TComponent = nil);
    property SourceOwner: TComponent read FSourceOwner;
    property Root: TCamARTRibbon read FRoot;
    property Item: TRibbonItem read FItem;
    property Control: TControl read FControl;
    property Button: TRibbonButton read GetButton;
  end;

constructor TRibbonExecutionGuard.CreateGuard(ARoot: TCamARTRibbon;
  AItem: TRibbonItem; AControl: TControl; ASourceOwner: TComponent);
begin
  inherited Create(nil);
  FRoot := ARoot;
  FItem := AItem;
  FControl := AControl;
  FSourceOwner := ASourceOwner;
  if FSourceOwner <> nil then FSourceOwner.FreeNotification(Self);
  if FRoot <> nil then TComponent(FRoot).FreeNotification(Self);
  if FItem <> nil then FItem.FreeNotification(Self);
  if FControl <> nil then TComponent(FControl).FreeNotification(Self);
end;

function TRibbonExecutionGuard.GetButton: TRibbonButton;
begin
  if FItem is TRibbonButton then Result := TRibbonButton(FItem) else Result := nil;
end;

procedure TRibbonExecutionGuard.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation <> opRemove then Exit;
  if AComponent = FRoot then FRoot := nil;
  if AComponent = FItem then FItem := nil;
  if AComponent = FControl then FControl := nil;
  if AComponent = FSourceOwner then FSourceOwner := nil;
end;

constructor TCamARTRibbon.Create(AOwner: TComponent);
begin
  inherited;
  FNativeDisabledOpacity := DisabledOpacity;
  CanFocus := False;
  ClipChildren := True;
  Width := 640;
  Height := 184;
  { Empty means the semantic default, not an explicit user override. }
  StyleLookup := '';
  FStyleContext := TRibbonStyleContext.Create(Self, Self);
  FStyleContext.OnChanged := StyleContextChanged;
  FExpandedHeight := Height;
  FModel := TRibbonModel.Create(Self);
  FModel.OnChanged := ModelChanged;
  FSelection := TRibbonSelectionController.Create;
  FLayoutEngine := TRibbonAdaptiveLayoutEngine.Create;
  FInputDensity := ridPointer;
  FReduceMotion := True;
  FCompactCaption := 'Commands';
  FLastSceneScale := 1;
  FCommands := TRibbonCommandRegistry.Create;
  FCommandResolver := FCommands;
  FModel.CommandResolver := FCommandResolver;
  FBindings := TRibbonBindingRegistry.Create;
  FReferenceResolver := TRibbonReferenceResolver.Create(FModel, FBindings);
  FReferenceResolver.Commands := FCommandResolver;
  FQuickAccess := TRibbonCommandLinks.Create(Self);
  FQuickAccess.OnChanged := ReferencesChanged;
  FApplicationMenu := TRibbonCommandLinks.Create(Self);
  FApplicationMenu.OnChanged := ReferencesChanged;
  FQuickAccessVisible := True;
  FApplicationButtonVisible := True;
  FApplicationCaption := 'File';
  FIcons := TRibbonIconRegistry.Create;
  FIconProvider := FIcons;
  FSkLabels := TRibbonSkLabelRegistry.Create;
  FFontProvider := TRibbonConfiguredFontProvider.Create(
    TArray<string>.Create('Arial', 'Courier New', 'Times New Roman'));
  FPopups := TRibbonPopupService.Create(Self);
  FPopups.StyleContext := FStyleContext;
  FPopups.IconProvider := FIconProvider;
  FStyleAdapter := TRibbonStyleAdapter.Create(Self);

  FTabScroll := TRibbonStyledHorzScrollBox.Create(Self);
  FTabScroll.Parent := Self;
  FTabScroll.Stored := False;
  FTabScroll.Locked := True;
  FTabScroll.CanFocus := False;
  FTabScroll.ClipChildren := True;
  FHeaderHost := TLayout.Create(Self);
  FHeaderHost.Parent := FTabScroll;
  FHeaderHost.Stored := False;
  FHeaderHost.Locked := True;
  FTabHost := TLayout.Create(Self);
  { Public FMX parenting routes this child to the scroll content. Do not use
    the protected TCustomScrollBox.Content property from this unit. }
  FTabHost.Parent := FHeaderHost;
  FTabHost.Stored := False;
  FTabHost.Locked := True;

  FBodyScroll := TRibbonStyledScrollBox.Create(Self);
  FBodyScroll.Parent := Self;
  FBodyScroll.Stored := False;
  FBodyScroll.Locked := True;
  FBodyScroll.CanFocus := False;
  FBodyScroll.ClipChildren := True;
  FBodyHost := TLayout.Create(Self);
  FBodyHost.Parent := FBodyScroll;
  FBodyHost.Stored := False;
  FBodyHost.Locked := True;

  FPresenter := TRibbonPresenter.Create(Self, FTabHost, FBodyHost);
  FPresenter.OnTabClick := TabClicked;
  FPresenter.OnInput := ItemInput;
  FPresenter.OnGroupPopup := GroupClicked;
  FPresenter.InputDensity := FInputDensity;
  FGroupPopup := TRibbonGroupPopupService.Create(Self, FPresenter.ViewFactory);
  FGroupPopup.StyleContext := FStyleContext;
  FGroupPopup.OnInput := GroupPopupInput;
  FCompactButton := TRibbonInputButton.Create(Self);
  FCompactButton.RibbonStyleRole := rsrCollapsedGroup;
  FCompactButton.Parent := FBodyHost;
  FCompactButton.Stored := False;
  FCompactButton.Text := FCompactCaption;
  FCompactButton.Visible := False;
  FCompactButton.OnClick := CompactClicked;
  AttachRibbonInput(FCompactButton, FInputDensity);
  FPresenter.IconProvider := FIconProvider;
  FPresenter.ViewFactory.SkLabelProvider := FSkLabels;
  FQuickAccessScroll := TRibbonStyledHorzScrollBox.Create(Self);
  FQuickAccessScroll.Parent := Self;
  FQuickAccessScroll.Stored := False;
  FQuickAccessScroll.Locked := True;
  FQuickAccessScroll.CanFocus := False;
  FQuickAccessHost := TLayout.Create(Self);
  FQuickAccessHost.Parent := FQuickAccessScroll;
  FQuickAccessHost.Stored := False;
  FQuickAccessHost.Locked := True;
  FQuickAccessPresenter := TRibbonAuxiliaryPresenter.Create(Self,
    FQuickAccessHost, FPresenter.ViewFactory);
  FQuickAccessPresenter.OnInput := QuickAccessInput;
  FApplicationButton := TRibbonInputButton.Create(Self);
  TRibbonInputButton(FApplicationButton).RibbonStyleRole := rsrApplicationButton;
  FApplicationButton.Parent := FHeaderHost;
  FApplicationButton.Stored := False;
  FApplicationButton.Text := FApplicationCaption;
  FApplicationButton.OnClick := ApplicationClicked;
  FApplicationMeasure := TRibbonTextMeasure.Create;
  AttachRibbonInput(FApplicationButton, FInputDensity);
  FContextWatch := TTimer.Create(Self);
  FContextWatch.Enabled := False;
  FContextWatch.Interval := 150;
  FContextWatch.OnTimer := ContextPulse;
  ConfigureScrolling;
  FReady := True;
  FContextWatch.Enabled := True;
  Refresh;
end;

destructor TCamARTRibbon.Destroy;
begin
  FDestroying := True;
  FReady := False;
  FOnActiveTabChanged := nil;
  FOnCollapsedChanged := nil;
  FOnDiagnostic := nil;
  if FStyleContext <> nil then FStyleContext.OnChanged := nil;
  if FContextWatch <> nil then
  begin
    FContextWatch.Enabled := False;
    FContextWatch.OnTimer := nil;
  end;
  if FModel <> nil then FModel.Shutdown;
  if FQuickAccess <> nil then FQuickAccess.OnChanged := nil;
  if FApplicationMenu <> nil then FApplicationMenu.OnChanged := nil;
  FreeAndNil(FGroupPopup);
  FreeAndNil(FPopups);
  FreeAndNil(FQuickAccessPresenter);
  FreeAndNil(FPresenter);
  FreeAndNil(FStyleContext);
  FreeAndNil(FReferenceResolver);
  FreeAndNil(FBindings);
  FreeAndNil(FQuickAccess);
  FreeAndNil(FApplicationMenu);
  FreeAndNil(FApplicationMeasure);
  if FStyleAdapter <> nil then FStyleAdapter.Clear;
  FreeAndNil(FStyleAdapter);
  FreeAndNil(FSelection);
  FreeAndNil(FModel);
  FCommandResolver := nil;
  FCommands := nil;
  FLayoutEngine := nil;
  FFontProvider := nil;
  FIconProvider := nil;
  FIcons := nil;
  FSkLabels := nil;
  { FMX and TComponent free the persistent host/control and model ownership
    trees. They are intentionally not also stored in owning TObjectLists. }
  inherited;
end;

function TCamARTRibbon.GetRibbonModel: TRibbonModel;
begin
  Result := FModel;
end;

function TCamARTRibbon.AddTab(const ACaption: string): TRibbonTab;
begin
  Result := FModel.AddTab(ACaption);
end;

procedure TCamARTRibbon.RemoveTab(ATab: TRibbonTab);
begin
  FModel.RemoveTab(ATab);
end;

procedure TCamARTRibbon.Clear;
begin
  FModel.Clear;
end;

procedure TCamARTRibbon.BeginUpdate;
begin
  FModel.BeginUpdate;
end;

procedure TCamARTRibbon.EndUpdate;
begin
  FModel.EndUpdate;
end;

function TCamARTRibbon.CaptureConfigurationSettings: TRibbonConfigurationSettings;
begin
  Result.Theme := Theme;
  Result.HasActiveTabId := True;
  Result.ActiveTabId := ActiveTabId;
  Result.Collapsed := FCollapsed;
  Result.QuickAccessVisible := FQuickAccessVisible;
  Result.QuickAccessPosition := FQuickAccessPosition;
  Result.ApplicationCaption := FApplicationCaption;
  Result.ApplicationButtonVisible := FApplicationButtonVisible;
  Result.ExpandedHeight := ExpandedHeight;
  Result.InputDensity := FInputDensity;
  Result.ReduceMotion := FReduceMotion;
  Result.CompactCaption := FCompactCaption;
end;

procedure TCamARTRibbon.ApplyConfiguration(ASource: TRibbonModel;
  AQuickAccess, AApplicationMenu: TRibbonCommandLinks;
  const ASettings: TRibbonConfigurationSettings);
var
  NewQuickAccess, NewApplicationMenu, OldLinks: TRibbonCommandLinks;
  NewSelection, OldSelection: TRibbonSelectionController;
  Tabs: TArray<TRibbonTab>;
  States: TArray<TRibbonTabState>;
  I: Integer;
  Candidate, PreviousId: string;
  PreviousCollapsed, SelectionChanged, RootBatch, SourceBatch,
    Committed: Boolean;
  Guard: TRibbonExecutionGuard;
  CollapsedHandler: TNotifyEvent;
begin
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    raise EInvalidOperation.Create('Ribbon configuration must be applied on the FMX UI thread.');
  if (ASource = nil) or (AQuickAccess = nil) or (AApplicationMenu = nil) then
    raise EArgumentNilException.Create('A detached model and both reference collections are required.');
  if (ASource = FModel) or (ASource.Owner = Self) then
    raise EArgumentException.Create('The staging model must be separate from the live Ribbon.');
  if FDestroying or (csDestroying in ComponentState) or
     (csLoading in ComponentState) or FRestoring or FRefreshing or
     FApplyingTheme or FApplyingConfiguration or (FModel.UpdateCount <> 0) or
     (ASource.UpdateCount <> 0) or Assigned(ASource.OnChanged) then
    raise EInvalidOperation.Create('A configuration requires idle live and detached models.');
  if IsNan(ASettings.ExpandedHeight) or IsInfinite(ASettings.ExpandedHeight) or
     (ASettings.ExpandedHeight <= 0) then
    raise EArgumentException.Create('ExpandedHeight must be finite and positive.');
  if (Ord(ASettings.Theme) < Ord(Low(TRibbonTheme))) or
     (Ord(ASettings.Theme) > Ord(High(TRibbonTheme))) or
     (Ord(ASettings.InputDensity) < Ord(Low(TRibbonInputDensity))) or
     (Ord(ASettings.InputDensity) > Ord(High(TRibbonInputDensity))) or
     (Ord(ASettings.QuickAccessPosition) < Ord(Low(TRibbonQATPosition))) or
     (Ord(ASettings.QuickAccessPosition) > Ord(High(TRibbonQATPosition))) then
    raise EArgumentOutOfRangeException.Create('A configuration contains an invalid enum.');
  ASource.ValidateTree;
  AQuickAccess.Validate;
  AApplicationMenu.Validate;

  { Every allocation/selection validation below precedes the ownership swap.
    No setter, popup closure, command execution, or live collection mutation
    occurs while preparing the complete replacement. }
  NewQuickAccess := nil;
  NewApplicationMenu := nil;
  NewSelection := nil;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil, nil, ASource.Owner);
  RootBatch := False;
  SourceBatch := False;
  Committed := False;
  try
    NewQuickAccess := TRibbonCommandLinks.Create(Self);
    NewApplicationMenu := TRibbonCommandLinks.Create(Self);
    NewQuickAccess.Assign(AQuickAccess);
    NewApplicationMenu.Assign(AApplicationMenu);
    NewSelection := TRibbonSelectionController.Create;
    Tabs := ASource.Tabs;
    SetLength(States, Length(Tabs));
    for I := 0 to High(Tabs) do
    begin
      States[I].Id := Tabs[I].Id;
      States[I].Visible := Tabs[I].Visible;
      States[I].Enabled := Tabs[I].Enabled;
    end;
    PreviousId := ActiveTabId;
    Candidate := '';
    for I := 0 to High(States) do
      if (States[I].Id = PreviousId) and States[I].Visible and States[I].Enabled then
      begin
        Candidate := PreviousId;
        Break;
      end;
    if (Candidate = '') and ASettings.HasActiveTabId and
       (ASettings.ActiveTabId <> '') then
      Candidate := ASettings.ActiveTabId;
    if Candidate <> '' then NewSelection.Select(Candidate, States)
    else NewSelection.Reconcile(States);
    SelectionChanged := PreviousId <> NewSelection.ActiveTabId;
    PreviousCollapsed := FCollapsed;

    FApplyingConfiguration := True;
    FRestoring := True;
    try
      try
        FModel.BeginUpdate;
        RootBatch := True;
        ASource.BeginUpdate;
        SourceBatch := True;
        { ExchangeTabs owns preflight/rollback and restores pending changes
          if transfer fails. It never publishes observer notifications. }
        FModel.ExchangeTabs(ASource);
        if Guard.Root = nil then
          raise EInvalidOperation.Create('The Ribbon was destroyed during component ownership transfer.');
        OldLinks := FQuickAccess;
        FQuickAccess := NewQuickAccess;
        NewQuickAccess := OldLinks;
        OldLinks := FApplicationMenu;
        FApplicationMenu := NewApplicationMenu;
        NewApplicationMenu := OldLinks;
        OldSelection := FSelection;
        FSelection := NewSelection;
        NewSelection := OldSelection;
        NewQuickAccess.OnChanged := nil;
        NewApplicationMenu.OnChanged := nil;
        FQuickAccess.OnChanged := ReferencesChanged;
        FApplicationMenu.OnChanged := ReferencesChanged;
        FSelectionEventPending := SelectionChanged;
        FPendingActiveTabId := '';
        FCollapsed := ASettings.Collapsed;
        FQuickAccessVisible := ASettings.QuickAccessVisible;
        FQuickAccessPosition := ASettings.QuickAccessPosition;
        FApplicationCaption := ASettings.ApplicationCaption;
        FApplicationButtonVisible := ASettings.ApplicationButtonVisible;
        FExpandedHeight := ASettings.ExpandedHeight;
        FInputDensity := ASettings.InputDensity;
        FReduceMotion := ASettings.ReduceMotion;
        FCompactCaption := ASettings.CompactCaption;
        Committed := True;

        { Logical commit ends above. The tree, references, and selection now
          describe one complete configuration. Publication may invoke native
          or user callbacks; they can raise or destroy the Ribbon. }
        FStyleContext.Theme := ASettings.Theme;
        if Guard.Root = nil then Exit;
        ClosePopup;
        if Guard.Root = nil then Exit;
        FApplicationButton.Text := FApplicationCaption;
        if Guard.Root = nil then Exit;
        FCompactButton.Text := FCompactCaption;
        if Guard.Root = nil then Exit;
        FPresenter.InputDensity := FInputDensity;
        if Guard.Root = nil then Exit;
        FQuickAccessPresenter.InputDensity := FInputDensity;
        if Guard.Root = nil then Exit;
        FPopups.InputDensity := FInputDensity;
        if Guard.Root = nil then Exit;
        FGroupPopup.InputDensity := FInputDensity;
        if Guard.Root = nil then Exit;
        AttachRibbonInput(FApplicationButton, FInputDensity);
        AttachRibbonInput(FCompactButton, FInputDensity);
        ConfigureScrolling;
        if Guard.Root = nil then Exit;
        if not FCollapsed then Height := FExpandedHeight;
        if Guard.Root = nil then Exit;
        FModel.Changed([rckStructure, rckMeasure, rckState, rckPaint]);
      finally
        try
          if SourceBatch then
          begin
            if Guard.SourceOwner <> nil then ASource.EndUpdate;
          end;
        finally
          if Guard.Root <> nil then
          begin
            Guard.Root.FRestoring := False;
            if RootBatch then
            begin
              { One combined model publication. EndUpdate can destroy Self. }
              Guard.Root.FModel.EndUpdate;
            end;
          end;
        end;
      end;
      if (Guard.Root <> nil) and Committed and
         (PreviousCollapsed <> ASettings.Collapsed) then
      begin
        CollapsedHandler := Guard.Root.FOnCollapsedChanged;
        if Assigned(CollapsedHandler) then CollapsedHandler(Guard.Root);
      end;
    except
      on E: Exception do
      begin
        if Committed then
          raise ERibbonConfigurationCommittedError.Create(
            'Ribbon configuration was committed, but publication failed: ' +
            E.ClassName + ': ' + E.Message);
        raise;
      end;
    end;
  finally
    if Guard.Root <> nil then
    begin
      Guard.Root.FRestoring := False;
      Guard.Root.FApplyingConfiguration := False;
    end;
    NewSelection.Free;
    NewApplicationMenu.Free;
    NewQuickAccess.Free;
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.ModelChanged(Sender: TObject;
  const Changes: TRibbonChanges);
var
  Guard: TRibbonExecutionGuard;
begin
  if Changes = [] then Exit;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    { Menu descriptors must be refreshed. A full-control group popup instead
      reconciles the same adapters, so typing must not close its editor. }
    FPopupContext := rpcNone;
    FPopupOwnerId := '';
    if FPopups <> nil then FPopups.Close;
    if Guard.Root = nil then Exit;
    if FThemeRefreshPending and not FApplyingTheme then
      ApplyTheme
    else
      RefreshInternal((Changes * [rckStructure, rckMeasure]) <> []);
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.TabStates: TArray<TRibbonTabState>;
var
  Tabs: TArray<TRibbonTab>;
  I: Integer;
begin
  Tabs := FModel.Tabs;
  SetLength(Result, Length(Tabs));
  for I := 0 to High(Tabs) do
  begin
    Result[I].Id := Tabs[I].Id;
    Result[I].Visible := Tabs[I].Visible;
    Result[I].Enabled := Tabs[I].Enabled;
  end;
end;

function TCamARTRibbon.GetActiveTabId: string;
begin
  if FSelection = nil then Exit(FPendingActiveTabId);
  if csLoading in ComponentState then Exit(FPendingActiveTabId);
  Result := FSelection.ActiveTabId;
end;

procedure TCamARTRibbon.SetActiveTabId(const AValue: string);
begin
  if (csLoading in ComponentState) or (FSelection = nil) then
  begin
    FPendingActiveTabId := AValue;
    Exit;
  end;
  if FSelection.Select(AValue, TabStates) then
  begin
    FSelectionEventPending := True;
    if not TryClosePopup then Exit;
    Refresh;
  end;
end;

function TCamARTRibbon.GetExpandedHeight: Single;
begin
  if FCollapsed then Result := FExpandedHeight else Result := Height;
end;

procedure TCamARTRibbon.SetExpandedHeight(const AValue: Single);
begin
  if IsNan(AValue) or IsInfinite(AValue) or (AValue <= 0) then
    raise EArgumentException.Create('ExpandedHeight must be finite and positive.');
  FExpandedHeight := AValue;
  if not FCollapsed then Height := AValue;
end;

procedure TCamARTRibbon.SetCollapsed(const AValue: Boolean);
var
  Handler: TNotifyEvent;
  Guard: TRibbonExecutionGuard;
begin
  if FCollapsed = AValue then Exit;
  if csLoading in ComponentState then
  begin
    FCollapsed := AValue;
    Exit;
  end;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    if AValue then FExpandedHeight := Height;
    FCollapsed := AValue;
    ClosePopup;
    if Guard.Root = nil then Exit;
    if AValue then
      Height := Max(RibbonDefaultTabHeight,
        FPresenter.RecommendedTabHeight) + 8
    else
      Height := FExpandedHeight;
    if Guard.Root = nil then Exit;
    Guard.Root.Refresh;
    if Guard.Root = nil then Exit;
    Handler := Guard.Root.FOnCollapsedChanged;
    if Assigned(Handler) then Handler(Guard.Root);
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.SetLayoutEngine(const AValue: IRibbonLayoutEngine);
begin
  if AValue = nil then
    raise EArgumentNilException.Create('A layout engine is required.');
  FLayoutEngine := AValue;
  Refresh;
end;

procedure TCamARTRibbon.SetCommandResolver(const AValue: IRibbonCommandResolver);
var
  Guard: TRibbonExecutionGuard;
begin
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FModel.BeginUpdate;
    try
      FCommandResolver := AValue;
      FReferenceResolver.Commands := AValue;
      FModel.CommandResolver := AValue;
      ClosePopup;
    finally
      if Guard.Root <> nil then Guard.Root.FModel.EndUpdate;
    end;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.ReferencesChanged(Sender: TObject);
begin
  if FModel <> nil then FModel.Changed([rckStructure, rckMeasure, rckState]);
end;

procedure TCamARTRibbon.SetQuickAccess(const AValue: TRibbonCommandLinks);
begin
  if AValue <> FQuickAccess then FQuickAccess.Assign(AValue);
end;

procedure TCamARTRibbon.SetApplicationMenu(const AValue: TRibbonCommandLinks);
begin
  if AValue <> FApplicationMenu then FApplicationMenu.Assign(AValue);
end;

procedure TCamARTRibbon.SetQuickAccessVisible(const AValue: Boolean);
begin
  if FQuickAccessVisible = AValue then Exit;
  FQuickAccessVisible := AValue;
  if not TryClosePopup then Exit;
  Refresh;
end;

procedure TCamARTRibbon.SetQuickAccessPosition(const AValue: TRibbonQATPosition);
begin
  if FQuickAccessPosition = AValue then Exit;
  FQuickAccessPosition := AValue;
  if not TryClosePopup then Exit;
  Refresh;
end;

procedure TCamARTRibbon.SetApplicationCaption(const AValue: string);
begin
  if FApplicationCaption = AValue then Exit;
  FApplicationCaption := AValue;
  if FApplicationButton <> nil then FApplicationButton.Text := AValue;
  Refresh;
end;

procedure TCamARTRibbon.SetApplicationButtonVisible(const AValue: Boolean);
begin
  if FApplicationButtonVisible = AValue then Exit;
  FApplicationButtonVisible := AValue;
  if not TryClosePopup then Exit;
  Refresh;
end;

function TCamARTRibbon.GetSvgIcons: IRibbonSvgIconRegistry;
begin
  Result := FIcons as IRibbonSvgIconRegistry;
end;

procedure TCamARTRibbon.SetIconProvider(const AValue: IRibbonIconProvider);
var
  Guard: TRibbonExecutionGuard;
begin
  if not TryClosePopup then Exit;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FIconProvider := AValue;
    FPresenter.IconProvider := AValue;
    if Guard.Root = nil then Exit;
    FGroupPopup.IconProvider := AValue;
    if Guard.Root = nil then Exit;
    FPopups.IconProvider := AValue;
    if Guard.Root <> nil then Guard.Root.Refresh;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.SetFontProvider(const AValue: IRibbonFontProvider);
begin
  if AValue = nil then raise EArgumentNilException.Create('A font provider is required.');
  FFontProvider := AValue;
end;

procedure TCamARTRibbon.PopulateFonts(APicker: TRibbonFontPicker);
var
  Names: TArray<string>;
  Name, Selected: string;
  List: TStringList;
  Guard: TRibbonExecutionGuard;
  Provider: IRibbonFontProvider;
begin
  if (APicker = nil) or (APicker.GetModel <> FModel) then
    raise EArgumentException.Create('The font picker must belong to this Ribbon.');
  Guard := TRibbonExecutionGuard.CreateGuard(Self, APicker);
  List := TStringList.Create;
  try
    Provider := FFontProvider;
    Names := Provider.GetFontNames;
    if (Guard.Root = nil) or (Guard.Item = nil) then Exit;
    List.CaseSensitive := False;
    for Name in Names do
      if (Trim(Name) <> '') and (List.IndexOf(Trim(Name)) < 0) then
        List.Add(Trim(Name));
    if List.Count = 0 then
      raise EArgumentException.Create('The font provider returned an empty catalog.');
    Selected := APicker.FontName;
    if Selected = '' then Selected := List[0];
    FModel.BeginUpdate;
    try
      APicker.ReplaceChoicesAndSelection(List, Selected);
    finally
      if Guard.Root <> nil then Guard.Root.FModel.EndUpdate;
    end;
  finally
    List.Free;
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.BindAction(const ACommandId: string; AAction: TCustomAction);
begin
  FCommands.RegisterCommand(ACommandId, TRibbonActionCommand.Create(AAction));
  RefreshCommands;
end;

function TCamARTRibbon.GetViewFactory: TRibbonViewFactory;
begin
  Result := FPresenter.ViewFactory;
end;

function TCamARTRibbon.QuickAccessData: TArray<TRibbonItemViewData>;
var
  I: Integer;
begin
  SetLength(Result, FQuickAccess.Count);
  for I := 0 to FQuickAccess.Count - 1 do
    Result[I] := FReferenceResolver.Snapshot(FQuickAccess[I]);
end;

function TCamARTRibbon.PopupData(ALinks: TRibbonCommandLinks): TArray<TRibbonPopupEntry>;
var
  Data: TRibbonItemViewData;
  I, N: Integer;
begin
  SetLength(Result, ALinks.Count);
  N := 0;
  for I := 0 to ALinks.Count - 1 do
  begin
    Data := FReferenceResolver.Snapshot(ALinks[I], False);
    if not Data.Visible then Continue;
    Result[N].Id := Data.Id;
    Result[N].Caption := Data.Caption;
    Result[N].Hint := Data.Hint;
    Result[N].IconKey := Data.IconKey;
    Result[N].Enabled := Data.Enabled;
    Result[N].Checked := Data.Checked;
    Result[N].Separator := ALinks[I].IsSeparator;
    Inc(N);
  end;
  SetLength(Result, N);
end;

procedure TCamARTRibbon.ClosePopup;
var
  Guard: TRibbonExecutionGuard;
begin
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FPopupContext := rpcNone;
    FPopupOwnerId := '';
    if FPopups <> nil then FPopups.Close;
    if Guard.Root = nil then Exit;
    if FGroupPopup <> nil then FGroupPopup.Close;
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.TryClosePopup: Boolean;
var
  Guard: TRibbonExecutionGuard;
begin
  { Closing a native popup may dispatch focus callbacks owned by the host.
    The caller may continue only while this component still exists. }
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    ClosePopup;
    Result := Guard.Root <> nil;
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.PopupIsOpen: Boolean;
begin
  Result := ((FPopups <> nil) and FPopups.IsOpen) or
    ((FGroupPopup <> nil) and FGroupPopup.IsOpen);
end;

procedure TCamARTRibbon.ApplicationClicked(Sender: TObject);
begin
  if not RibbonActivationAllowed(FApplicationButton) then Exit;
  ShowApplicationMenu;
end;

procedure TCamARTRibbon.ShowApplicationMenu;
var
  Entries: TArray<TRibbonPopupEntry>;
  Anchor: TControl;
begin
  if FDestroying or not HostAllowsExecution then Exit;
  if not TryClosePopup then Exit;
  if not HostAllowsExecution then Exit;
  Entries := PopupData(FApplicationMenu);
  if Length(Entries) = 0 then Exit;
  FPopupContext := rpcApplication;
  Anchor := FApplicationButton;
  if not Anchor.Visible then Anchor := Self;
  FPopups.OpenMenu(Anchor, Entries, PopupSelected);
end;

procedure TCamARTRibbon.OpenButtonPopup(const AId: string; AAnchor: TControl;
  ARespectModelAncestors: Boolean);
var
  Button: TRibbonButton;
  Gallery: TRibbonGallery;
  Entry: TRibbonGalleryEntry;
  Entries: TArray<TRibbonPopupEntry>;
  I, N: Integer;
  Id: string;
  HadAnchor: Boolean;
  Guard: TRibbonExecutionGuard;
begin
  if FDestroying or not HostAllowsExecution then Exit;
  Id := AId;
  HadAnchor := AAnchor <> nil;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil, AAnchor);
  try
    ClosePopup;
    if Guard.Root = nil then Exit;
    if HadAnchor and (Guard.Control = nil) then Exit;
    if not HostAllowsExecution then Exit;
    AAnchor := Guard.Control;
    Button := FModel.FindButtonById(Id);
    if (Button = nil) or not Button.Enabled then Exit;
    if ARespectModelAncestors and
      (not Button.EffectiveEnabled or not Button.EffectiveVisible) then Exit;
    if not TRibbonCommandDispatcher.CanExecute(Button.CommandId,
      FCommandResolver, True) then Exit;
    if AAnchor = nil then AAnchor := FindItemView(Id);
    if AAnchor = nil then AAnchor := Self;
    if Button.ButtonKind = rbkGallery then
    begin
      Gallery := FModel.FindGalleryById(Button.GalleryId);
      if (Gallery = nil) or not Gallery.Enabled then
      begin
        ReportDiagnostic('Gallery button has no enabled gallery: ' + Button.GalleryId);
        Exit;
      end;
      SetLength(Entries, Gallery.Entries.Count);
      N := 0;
      for I := 0 to Gallery.Entries.Count - 1 do
      begin
        Entry := Gallery.Entries[I];
        if not Entry.Visible then Continue;
        Entries[N].Id := Entry.Id;
        Entries[N].Caption := Entry.Caption;
        Entries[N].Hint := Entry.Caption;
        Entries[N].IconKey := Entry.IconKey;
        Entries[N].Enabled := TRibbonCommandDispatcher.CanExecute(Entry.CommandId,
          FCommandResolver, Entry.Enabled);
        Entries[N].Checked := Entry.Id = Gallery.SelectedId;
        Entries[N].Separator := False;
        Inc(N);
      end;
      SetLength(Entries, N);
      if N = 0 then Exit;
      FPopupContext := rpcGallery;
      FPopupOwnerId := Gallery.Id;
      FPopups.OpenGallery(AAnchor, Entries, Gallery.SelectedId, PopupSelected);
    end
    else
    begin
      Entries := PopupData(Button.MenuItems);
      if Length(Entries) = 0 then Exit;
      FPopupContext := rpcButtonMenu;
      FPopupOwnerId := Button.Id;
      FPopups.OpenMenu(AAnchor, Entries, PopupSelected);
    end;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.PopupSelected(Sender: TObject; const AId: string);
var
  Context: TRibbonPopupContextKind;
  OwnerId: string;
  Button: TRibbonButton;
  Link: TRibbonCommandLink;
begin
  { The popup service delivers after its native input stack has unwound.
    Resolve current model/reference state again, never a captured model pointer. }
  Context := FPopupContext;
  OwnerId := FPopupOwnerId;
  FPopupContext := rpcNone;
  FPopupOwnerId := '';
  if FDestroying or not HostAllowsExecution then Exit;
  case Context of
    rpcApplication:
      begin
        Link := FApplicationMenu.FindById(AId);
        if Link <> nil then ExecuteReference(Link, Self);
      end;
    rpcButtonMenu:
      begin
        Button := FModel.FindButtonById(OwnerId);
        if (Button <> nil) and Button.Enabled then
        begin
          Link := Button.MenuItems.FindById(AId);
          if Link <> nil then ExecuteReference(Link, Self);
        end;
      end;
    rpcGallery:
      SelectGalleryEntry(OwnerId, AId, True);
    rpcGroups:
      ShowGroupPopup(AId);
  end;
end;

procedure TCamARTRibbon.QuickAccessInput(Sender: TObject;
  const AInput: TRibbonItemInput);
var
  Link: TRibbonCommandLink;
  Source: TRibbonButton;
  Data: TRibbonItemViewData;
begin
  if not FQuickAccessVisible then Exit;
  Link := FQuickAccess.FindById(AInput.Id);
  if Link = nil then Exit;
  if AInput.Kind = rikDropDown then
  begin
    Data := FReferenceResolver.Snapshot(Link);
    if not Data.Enabled or not Data.Visible then Exit;
    Source := FReferenceResolver.FindSource(Link);
    if Source <> nil then
      OpenButtonPopup(Source.Id, FindQuickAccessView(AInput.Id), False);
  end
  else if AInput.Kind in [rikExecute, rikCheck] then
    ExecuteReference(Link, FindQuickAccessView(AInput.Id))
  else
  begin
    Source := FReferenceResolver.FindSource(Link);
    if Source = nil then Exit;
    case AInput.Kind of
      rikMouseEnter: Source.InvokeMouseEnter;
      rikMouseLeave: Source.InvokeMouseLeave;
    end;
  end;
end;

procedure TCamARTRibbon.ItemInput(Sender: TObject; const AInput: TRibbonItemInput);
var
  Item: TRibbonItem;
  Guard: TRibbonExecutionGuard;
begin
  if FDestroying then Exit;
  Item := FModel.FindItemById(AInput.Id);
  if Item = nil then Exit;
  if AInput.Kind = rikMouseEnter then
  begin
    Item.InvokeMouseEnter;
    Exit;
  end;
  if AInput.Kind = rikMouseLeave then
  begin
    Item.InvokeMouseLeave;
    Exit;
  end;
  if not HostAllowsExecution or not Item.EffectiveEnabled or
     not Item.EffectiveVisible then Exit;
  case AInput.Kind of
    rikExecute, rikCheck:
      if Item is TRibbonButton then ExecuteButton(TRibbonButton(Item), True);
    rikDropDown:
      OpenButtonPopup(AInput.Id, FindItemView(AInput.Id), True);
    rikGallerySelect:
      SelectGalleryEntry(AInput.Id, AInput.SelectedId, False);
  else
    Guard := TRibbonExecutionGuard.CreateGuard(Self, Item);
    try
      FBindings.ApplyInput(Item, AInput);
      if Guard.Root <> nil then Guard.Root.Refresh;
    finally
      Guard.Free;
    end;
  end;
end;

procedure TCamARTRibbon.MakeViewData(out ATabs: TArray<TRibbonTabViewData>;
  out AGroups: TArray<TRibbonGroupViewData>);
var
  Tabs: TArray<TRibbonTab>;
  Groups: TArray<TRibbonGroup>;
  Items: TArray<TRibbonItem>;
  Tab: TRibbonTab;
  ItemList: TList<TRibbonItemViewData>;
  I, J: Integer;
begin
  Tabs := FModel.Tabs;
  SetLength(ATabs, Length(Tabs));
  for I := 0 to High(Tabs) do
  begin
    ATabs[I].Id := Tabs[I].Id;
    ATabs[I].Caption := Tabs[I].Caption;
    ATabs[I].Visible := Tabs[I].Visible;
    ATabs[I].Enabled := Tabs[I].Enabled;
    ATabs[I].Selected := Tabs[I].Id = FSelection.ActiveTabId;
  end;
  SetLength(AGroups, 0);
  Tab := FModel.FindTabById(FSelection.ActiveTabId);
  if Tab = nil then Exit;
  Groups := Tab.Groups;
  SetLength(AGroups, Length(Groups));
  for I := 0 to High(Groups) do
  begin
    AGroups[I].Id := Groups[I].Id;
    AGroups[I].Caption := Groups[I].Caption;
    AGroups[I].Visible := Groups[I].EffectiveVisible;
    AGroups[I].Enabled := Groups[I].EffectiveEnabled;
    AGroups[I].MinWidth := Groups[I].MinWidth;
    AGroups[I].PreferredWidth := Groups[I].PreferredWidth;
    AGroups[I].Pinned := Groups[I].Pinned;
    AGroups[I].AllowCompact := Groups[I].AllowCompact;
    AGroups[I].AllowCollapse := Groups[I].AllowCollapse;
    AGroups[I].CollapsePriority := Groups[I].CollapsePriority;
    Items := Groups[I].Items;
    ItemList := TList<TRibbonItemViewData>.Create;
    try
      for J := 0 to High(Items) do
      begin
        { CanExecute is a pure query by contract: it must not mutate/free the
          model or controls while a presentation snapshot is being built. }
        ItemList.Add(FBindings.Snapshot(Items[J], FCommandResolver));
      end;
      AGroups[I].Items := ItemList.ToArray;
    finally
      ItemList.Free;
    end;
  end;
end;

procedure TCamARTRibbon.LayoutViews;
var
  TabRect, BodyRect, AppInsets, MenuInsets, BodyFrame: TRectF;
  TabHeight, TabWidth, BodyWidth, BodyHeight, QATHeight, QATTop,
    AppWidth, AppGap, CollapsedHeight, AvailableWidth, RevisedWidth,
    MinimumTarget, TabContentWidth, QATWidth, EdgeBottom, ViewWidth,
    ViewHeight, RevisedHeight: Single;
  FitPass: Integer;
  ViewportShrunk: Boolean;
  QATSize, AppSize, MenuSize: TSizeF;
  ViewPos: TPointF;
  Plan: TRibbonLayoutResult;
  Metrics: TRibbonLayoutMetrics;
  Measures: TArray<TRibbonGroupMeasure>;
  OldGroup, NewGroup: TRibbonGroupPlacement;
  Launcher: TRibbonGroupLauncher;
  FocusId: string;
  FocusTarget: TControl;
  CompactHadFocus: Boolean;
  Guard: TRibbonExecutionGuard;
begin
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FocusId := '';
    FocusTarget := nil;
    CompactHadFocus := FCompactButton.IsFocused;
    for OldGroup in FLastLayout.Groups do
    begin
      Launcher := FPresenter.FindGroupLauncher(OldGroup.Id);
      if (Launcher <> nil) and Launcher.IsFocused then
      begin
        FocusId := OldGroup.Id;
        Break;
      end;
    end;
    MinimumTarget := 28;
    if FInputDensity = ridTouch then MinimumTarget := 44;
    TabRect := FStyleAdapter.TabStripRect;
    { Style parts describe placement, but the real Ribbon client is the limit.
      Preserve logical units; scene scale only invalidates raster measurement.
      The body rectangle is derived below from the frame and tab edges. }
    TabRect.Left := Max(Padding.Left, TabRect.Left);
    TabRect.Right := Max(TabRect.Left, Min(Width - Padding.Right, TabRect.Right));
    QATSize := FQuickAccessPresenter.Measure;
    if Guard.Root = nil then Exit;
    QATHeight := 0;
    if FQuickAccessVisible and (FQuickAccessPresenter.Count > 0) then
      QATHeight := Max(MinimumTarget, QATSize.Height) + 4;
    FQuickAccessScroll.Visible := QATHeight > 0;
    if Guard.Root = nil then Exit;
    TabHeight := Max(MinimumTarget, Max(TabRect.Height,
      Max(RibbonDefaultTabHeight, FPresenter.RecommendedTabHeight)));
    FApplicationButton.Visible := FApplicationButtonVisible and
      (FApplicationMenu.Count > 0);
      if Guard.Root = nil then Exit;
    AppWidth := 0;
    AppGap := 0;
    if FApplicationButton.Visible then
    begin
      FApplicationButton.ApplyStyleLookup;
      if Guard.Root = nil then Exit;
      AppSize := FApplicationMeasure.Measure(FApplicationButton.Text,
        FApplicationButton.ResultingTextSettings.Font);
      AppInsets := RibbonControlPadding(FApplicationButton);
      AppWidth := Max(MinimumTarget, AppSize.Width + AppInsets.Left + AppInsets.Right);
      AppGap := 4;
      TabHeight := Max(TabHeight, AppSize.Height + AppInsets.Top + AppInsets.Bottom);
    end;
    if FCollapsed then
    begin
      TabRect.Top := Padding.Top;
      if FQuickAccessPosition = rqpAbove then TabRect.Top := TabRect.Top + QATHeight;
      TabRect.Bottom := TabRect.Top + TabHeight;
    end
    else
    begin
      TabHeight := Max(TabRect.Height, TabHeight);
      if FQuickAccessPosition = rqpAbove then TabRect.Offset(0, QATHeight);
    end;
    { File and tabs share one horizontal viewport. A long File caption must
      never consume the entire fixed strip and make the tabs unreachable. }
    TabWidth := Max(0, TabRect.Width);
    FTabScroll.SetBounds(TabRect.Left, TabRect.Top, TabWidth, TabHeight);
    if Guard.Root = nil then Exit;
    FTabScroll.ApplyStyleLookup;
    if Guard.Root = nil then Exit;
    TabContentWidth := FPresenter.ArrangeTabs(TabHeight);
    if Guard.Root = nil then Exit;
    FTabHost.SetBounds(AppWidth + AppGap, 0, TabContentWidth, TabHeight);
    if Guard.Root = nil then Exit;
    FApplicationButton.SetBounds(0, 0, AppWidth, TabHeight);
    if Guard.Root = nil then Exit;
    FHeaderHost.SetBounds(0, 0,
      Max(TabWidth, FTabHost.Position.X + FTabHost.Width), TabHeight);
      if Guard.Root = nil then Exit;
    EnsureSelectedTabVisible;
    if Guard.Root = nil then Exit;
    FTabScroll.BringToFront;

    QATTop := Padding.Top;
    if FQuickAccessPosition = rqpBelow then
    begin
      if FCollapsed then QATTop := TabRect.Bottom
      else QATTop := Max(TabRect.Top + TabHeight, Height - Padding.Bottom - QATHeight);
    end;
    FQuickAccessScroll.SetBounds(Padding.Left, QATTop,
      Max(0, Width - Padding.Left - Padding.Right), QATHeight);
      if Guard.Root = nil then Exit;
    FQuickAccessHost.Height := QATHeight;
    if Guard.Root = nil then Exit;
    QATWidth := FQuickAccessPresenter.Arrange(QATHeight);
    if Guard.Root = nil then Exit;
    FQuickAccessHost.Width := Max(FQuickAccessScroll.Width, QATWidth);
    if Guard.Root = nil then Exit;

    { Group frames show RibbonBodyFrameGap against every edge surrounding the
      body: the tab strip underline, the inner edge of the outer frame and a
      QAT placed below. This is the single place where the gap is applied:
      the body viewport edges are derived from the measured frame/tab edges,
      so style padding between them (style "content" part) is accounted for
      instead of being added on top. Insetting the viewport, not the content,
      keeps the gap while scrolling. Ribbon.Padding stays a lower bound; the
      engine, group spacing and item placement inside groups are unchanged. }
    BodyFrame := FStyleAdapter.FrameRect;
    EdgeBottom := BodyFrame.Bottom;
    if (FQuickAccessPosition = rqpBelow) and (QATHeight > 0) then
      EdgeBottom := Min(EdgeBottom, QATTop);
    BodyRect.Left := Max(Padding.Left, BodyFrame.Left + RibbonBodyFrameGap);
    BodyRect.Right := Max(BodyRect.Left,
      Min(Width - Padding.Right, BodyFrame.Right - RibbonBodyFrameGap));
    BodyRect.Top := TabRect.Top + TabHeight + RibbonBodyFrameGap;
    BodyRect.Bottom := Min(Height - Padding.Bottom, EdgeBottom - RibbonBodyFrameGap);
    BodyWidth := Max(0, BodyRect.Width);
    BodyHeight := Max(0, BodyRect.Bottom - BodyRect.Top);
    FBodyScroll.SetBounds(BodyRect.Left, BodyRect.Top, BodyWidth, BodyHeight);
    if Guard.Root = nil then Exit;
    FBodyScroll.Visible := not FCollapsed and (BodyHeight > 0);
    if Guard.Root = nil then Exit;
    FBodyScroll.ApplyStyleLookup;
    if Guard.Root = nil then Exit;
    ViewWidth := Max(0, FBodyScroll.ViewportRect.Width);
    ViewHeight := Max(0, FBodyScroll.ViewportRect.Height);
    Metrics := FPresenter.EffectiveMetrics(TRibbonLayoutMetrics.Default);
    if Guard.Root = nil then Exit;
    FCompactButton.ApplyStyleLookup;
    if Guard.Root = nil then Exit;
    MenuSize := FApplicationMeasure.Measure(FCompactButton.Text,
      FCompactButton.ResultingTextSettings.Font);
    MenuInsets := RibbonControlPadding(FCompactButton);
    Metrics.CompactMenuWidth := Max(MinimumTarget,
      MenuSize.Width + MenuInsets.Left + MenuInsets.Right + 28);
    Metrics.CompactMenuHeight := Max(MinimumTarget,
      MenuSize.Height + MenuInsets.Top + MenuInsets.Bottom + 12);
    Measures := FPresenter.MeasureGroups;
    if Guard.Root = nil then Exit;
    { The engine receives the viewport width inside the gap; the scroll
      extent is the plan itself. When everything fits, the extent equals the
      viewport and no scrollbar is shown; otherwise scrolling reaches the
      last group, whose frame then ends at the gapped viewport edge.
      A scrollbar can reduce the real viewport after the extent changes.
      Refit with the smaller observed viewport (each bar appears once), but
      never enlarge the plan from feedback caused by hiding a scrollbar. }
    FitPass := 0;
    repeat
      AvailableWidth := ViewWidth;
      Plan := FLayoutEngine.Calculate(Measures, AvailableWidth, Metrics);
      FBodyHost.SetBounds(0, 0, Max(ViewWidth, Plan.ContentWidth),
        Max(ViewHeight, Plan.ContentHeight));
      if Guard.Root = nil then Exit;
      Inc(FitPass);
      RevisedWidth := Max(0, FBodyScroll.ViewportRect.Width);
      RevisedHeight := Max(0, FBodyScroll.ViewportRect.Height);
      ViewportShrunk := (RevisedWidth < ViewWidth) or (RevisedHeight < ViewHeight);
      ViewWidth := Min(ViewWidth, RevisedWidth);
      ViewHeight := Min(ViewHeight, RevisedHeight);
    until not ViewportShrunk or (FitPass >= 3);
    { A stale scroll offset (e.g. left over from the tiny collapsed viewport)
      would shift the groups up under the tab strip. Keep the offset inside
      the scrollable range; collapsed or non-overflowing bodies sit at 0. }
    ViewPos := FBodyScroll.ViewportPosition;
    if FCollapsed or not FBodyScroll.Visible then
      ViewPos := PointF(0, 0)
    else
    begin
      ViewPos.X := Max(0, Min(ViewPos.X,
        FBodyHost.Width - FBodyScroll.ViewportRect.Width));
      ViewPos.Y := Max(0, Min(ViewPos.Y,
        FBodyHost.Height - FBodyScroll.ViewportRect.Height));
    end;
    if (ViewPos.X <> FBodyScroll.ViewportPosition.X) or
       (ViewPos.Y <> FBodyScroll.ViewportPosition.Y) then
      FBodyScroll.ViewportPosition := ViewPos;
    if Guard.Root = nil then Exit;
    FLastLayout := Plan;
    FCompactButton.Visible := Plan.Mode = rlmCompactMenu;
    if Guard.Root = nil then Exit;
    if FCompactButton.Visible then
      FCompactButton.SetBounds(Plan.CompactMenuBounds.Left,
        Plan.CompactMenuBounds.Top, Plan.CompactMenuBounds.Width,
        Plan.CompactMenuBounds.Height);
        if Guard.Root = nil then Exit;
    FPresenter.ApplyLayout(Plan);
    if Guard.Root = nil then Exit;
    if FocusId <> '' then
    begin
      Launcher := FindGroupLauncher(FocusId);
      if (Launcher <> nil) and not Launcher.Visible then
        FocusTarget := FPresenter.FirstFocusableItem(FocusId);
      if (FocusTarget = nil) and FCompactButton.Visible then
        FocusTarget := FCompactButton;
    end;
    if CompactHadFocus and not FCompactButton.Visible then
      for NewGroup in Plan.Groups do
      begin
        FocusTarget := FPresenter.FirstFocusableItem(NewGroup.Id);
        if FocusTarget = nil then FocusTarget := FindGroupLauncher(NewGroup.Id);
        if (FocusTarget <> nil) and FocusTarget.Visible and
           FocusTarget.ParentedVisible and FocusTarget.CanFocus then Break;
        FocusTarget := nil;
      end;
    if FBodyScroll.Visible then FBodyScroll.BringToFront;
    if FQuickAccessScroll.Visible then FQuickAccessScroll.BringToFront;
    Inc(FLayoutPassCount);
    CollapsedHeight := TabHeight + QATHeight + Padding.Top + Padding.Bottom + 8;
    { Both operations can dispatch application focus/resize callbacks. They
      are final root operations; the caller also watches root lifetime. }
    if FCollapsed and (Height <> CollapsedHeight) then
    begin
      Height := CollapsedHeight;
      Exit;
    end;
    if (FocusTarget <> nil) and FocusTarget.Visible and
       FocusTarget.ParentedVisible and FocusTarget.AbsoluteEnabled and
       FocusTarget.CanFocus then FocusTarget.SetFocus;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.Refresh;
begin
  RefreshInternal(True);
end;

procedure TCamARTRibbon.RefreshInternal(AInvalidateMeasurements: Boolean);
var
  Tabs: TArray<TRibbonTabViewData>;
  Groups: TArray<TRibbonGroupViewData>;
  Handler: TNotifyEvent;
  Guard: TRibbonExecutionGuard;
begin
  if not FReady or FDestroying or FRestoring or
     (csLoading in ComponentState) then Exit;
  if AInvalidateMeasurements then FPresenter.InvalidateMeasurements;
  if FModel.UpdateCount > 0 then
  begin
    { Presentation-only requests inside a model batch must still be delivered
      when the outer EndUpdate runs, even if no model property changed. }
    FModel.Changed([rckStructure, rckMeasure, rckState]);
    Exit;
  end;
  if FRefreshing then
  begin
    FRefreshRequested := True;
    Exit;
  end;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FRefreshing := True;
    try
      repeat
        FRefreshRequested := False;
        if FSelection.Reconcile(TabStates) then FSelectionEventPending := True;
        MakeViewData(Tabs, Groups);
        FLastGroups := Groups;
        FPresenter.Sync(Tabs, Groups);
        if Guard.Root = nil then Exit;
        FQuickAccessPresenter.Sync(QuickAccessData);
        if Guard.Root = nil then Exit;
        AttachInputControls(FTabHost);
        AttachInputControls(FBodyHost);
        AttachInputControls(FQuickAccessHost);
        LayoutViews;
        if Guard.Root = nil then Exit;
        SyncGroupPopup;
        if Guard.Root = nil then Exit;
        { Remember the context actually measured by this refresh. An explicit
          Refresh after an icon/style change must not make the timer close a
          newly opened popup for an already-consumed revision. }
        FLastSceneScale := 1;
        if Scene <> nil then FLastSceneScale := Scene.GetSceneScale;
        FLastIconRevision := 0;
        if FIconProvider <> nil then FLastIconRevision := FIconProvider.GetRevision;
        FLastSkLabelRevision := FSkLabels.GetRevision;
        Inc(FRefreshCount);
        { Replay the full snapshot for a coalesced change, including structure.
          A geometry-only pass could leave a stale view after a model mutation.
          CanExecute and measurement are pure queries by contract. }
      until not FRefreshRequested;
    finally
      if Guard.Root <> nil then FRefreshing := False;
    end;
    if FThemeRefreshPending and not FApplyingTheme then
    begin
      ApplyTheme;
      if Guard.Root = nil then Exit;
    end;
    Handler := nil;
    if FSelectionEventPending then
    begin
      FSelectionEventPending := False;
      Handler := FOnActiveTabChanged;
    end;
    { Public callbacks run after internal state/layout work. The local guard
      does not own the Ribbon and remains valid if this callback destroys it. }
    if Assigned(Handler) then Handler(Self);
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.RefreshCommands;
begin
  if not TryClosePopup then Exit;
  RefreshInternal(False);
end;

procedure TCamARTRibbon.TabClicked(Sender: TObject; const AId: string);
begin
  { Stable ID resolution avoids keeping a pointer to a removed model node. }
  if FModel.FindTabById(AId) = nil then Exit;
  if not RibbonActivationAllowed(FindTabView(AId)) then Exit;
  if GetActiveTabId = AId then
    Refresh  // Restore the selected state of a stays-pressed tab button.
  else
    SetActiveTabId(AId);
end;

function TCamARTRibbon.HostAllowsExecution: Boolean;
var
  Current: TFmxObject;
begin
  Result := False;
  Current := Self;
  while Current <> nil do
  begin
    if Current is TControl then
      if not TControl(Current).Enabled or not TControl(Current).Visible then Exit;
    Current := Current.Parent;
  end;
  Result := True;
end;

function TCamARTRibbon.ExecuteButtonById(
  const AId: string): TRibbonDispatchResult;
var
  Button: TRibbonButton;
begin
  Result := rdrDisabled;
  if FDestroying or not HostAllowsExecution then Exit;
  Button := FModel.FindButtonById(AId);
  if Button = nil then Exit(rdrNoHandler);
  Result := ExecuteButton(Button, True);
end;

function TCamARTRibbon.ExecuteButton(AButton: TRibbonButton;
  ARespectModelAncestors: Boolean): TRibbonDispatchResult;
var
  Guard: TRibbonExecutionGuard;
  Resolver: IRibbonCommandResolver;
  Handler, Executed, Changed: TNotifyEvent;
  CommandId: string;
  Allowed, BeforeChecked, StateChanged: Boolean;
begin
  Result := rdrDisabled;
  if FDestroying or not HostAllowsExecution or (AButton = nil) then Exit;
  Allowed := AButton.Enabled;
  if ARespectModelAncestors then
    Allowed := AButton.EffectiveEnabled and AButton.EffectiveVisible;
  if not Allowed then Exit;
  CommandId := AButton.CommandId;
  Handler := AButton.OnClick;
  Resolver := FCommandResolver;
  BeforeChecked := AButton.Checked;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, AButton);
  try
    if CommandId = '' then
    begin
      StateChanged := AButton.ApplyLocalState;
      if (Guard.Root = nil) or (Guard.Button = nil) then Exit(rdrExecuted);
      { A local state callback may change the current command binding,
        callback, host or model eligibility. Do not dispatch a stale intent. }
      if Guard.Button.CommandId <> '' then Exit(rdrNoHandler);
      Allowed := Guard.Root.HostAllowsExecution and Guard.Button.Enabled;
      if ARespectModelAncestors then
        Allowed := Allowed and Guard.Button.EffectiveEnabled and
          Guard.Button.EffectiveVisible;
      if not Allowed then Exit(rdrDisabled);
      Handler := Guard.Button.OnClick;
      Resolver := Guard.Root.CommandResolver;
      Result := TRibbonCommandDispatcher.Dispatch('', Resolver,
        Guard.Button, Handler, Allowed);
      if (Result = rdrNoHandler) and StateChanged then Result := rdrExecuted;
    end
    else
      Result := TRibbonCommandDispatcher.Dispatch(CommandId, Resolver,
        AButton, Handler, Allowed);
    if Guard.Root = nil then Exit;
    if Result = rdrUnknownCommand then
    begin
      Guard.Root.ReportDiagnostic('Unknown Ribbon command: ' + CommandId);
      Exit;
    end;
    if (Result = rdrExecuted) and (CommandId <> '') and
       (Guard.Button <> nil) then
      if Guard.Button.Checked <> BeforeChecked then
      begin
        { The canonical state remains in the command. Notify once for this
          observed execution transition; never write a duplicate local copy. }
        Changed := Guard.Button.OnChange;
        if Assigned(Changed) then Changed(Guard.Button);
      end;
    if Guard.Root = nil then Exit;
    if (Result = rdrExecuted) and (Guard.Button <> nil) then
    begin
      Executed := Guard.Button.OnExecuted;
      if Assigned(Executed) then Executed(Guard.Button);
    end;
    if Guard.Root <> nil then Guard.Root.RefreshCommands;
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.ExecuteReference(AReference: TRibbonCommandLink;
  AAnchor: TControl): TRibbonDispatchResult;
var
  Data: TRibbonItemViewData;
  Source: TRibbonButton;
  CommandId: string;
  Resolver: IRibbonCommandResolver;
  Guard: TRibbonExecutionGuard;
begin
  Result := rdrDisabled;
  if FDestroying or not HostAllowsExecution or (AReference = nil) then Exit;
  if AReference.IsSeparator then Exit(rdrNoHandler);
  Data := FReferenceResolver.Snapshot(AReference);
  if not Data.Visible or not Data.Enabled then Exit;
  Source := FReferenceResolver.FindSource(AReference);
  if Source <> nil then
  begin
    if Source.ButtonKind in [rbkDropDown, rbkGallery] then
    begin
      Result := rdrExecuted;
      OpenButtonPopup(Source.Id, AAnchor, False);
    end
    else
      Result := ExecuteButton(Source, False);
    Exit;
  end;
  CommandId := AReference.CommandId;
  if CommandId = '' then Exit(rdrNoHandler);
  Resolver := FCommandResolver;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    { A command-only reference has no model callback or duplicate Checked.
      Command.Execute and its optional check-state interface are canonical. }
    Result := TRibbonCommandDispatcher.Dispatch(CommandId, Resolver, nil, nil, True);
    if Guard.Root <> nil then Guard.Root.RefreshCommands;
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.ExecuteQuickAccessById(const AId: string): TRibbonDispatchResult;
var
  Link: TRibbonCommandLink;
begin
  if not FQuickAccessVisible then Exit(rdrDisabled);
  Link := FQuickAccess.FindById(AId);
  if Link = nil then Exit(rdrNoHandler);
  Result := ExecuteReference(Link, FindQuickAccessView(AId));
end;

function TCamARTRibbon.GetButtonChecked(const AId: string): Boolean;
var
  Button: TRibbonButton;
begin
  Button := FModel.FindButtonById(AId);
  Result := (Button <> nil) and Button.Checked;
end;

function TCamARTRibbon.SelectGalleryEntry(const AGalleryId, AEntryId: string;
  APopupPresentation: Boolean): TRibbonDispatchResult;
var
  Gallery: TRibbonGallery;
  Entry: TRibbonGalleryEntry;
  CommandId: string;
  Resolver: IRibbonCommandResolver;
  Guard: TRibbonExecutionGuard;
begin
  Result := rdrDisabled;
  if FDestroying or not HostAllowsExecution then Exit;
  Gallery := FModel.FindGalleryById(AGalleryId);
  if (Gallery = nil) or not Gallery.Enabled then Exit;
  if not APopupPresentation and
    (not Gallery.EffectiveEnabled or not Gallery.EffectiveVisible) then Exit;
  Entry := Gallery.Entries.FindById(AEntryId);
  if (Entry = nil) or not Entry.Enabled or not Entry.Visible then Exit;
  CommandId := Entry.CommandId;
  Resolver := FCommandResolver;
  if not TRibbonCommandDispatcher.CanExecute(CommandId, Resolver, True) then Exit;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, Gallery);
  try
    Gallery.SelectedId := AEntryId;
    if (Guard.Root = nil) or (Guard.Item = nil) then Exit(rdrExecuted);
    { OnChange may change the selection, disable the gallery or replace its
      command resolver. Revalidate the current intent before executing. }
    Gallery := TRibbonGallery(Guard.Item);
    if (Gallery.SelectedId <> AEntryId) or not Gallery.Enabled or
       not Guard.Root.HostAllowsExecution then Exit(rdrDisabled);
    if not APopupPresentation and
      (not Gallery.EffectiveEnabled or not Gallery.EffectiveVisible) then
      Exit(rdrDisabled);
    Entry := Gallery.Entries.FindById(AEntryId);
    if (Entry = nil) or not Entry.Enabled or not Entry.Visible or
       (Entry.CommandId <> CommandId) then Exit(rdrNoHandler);
    Resolver := Guard.Root.CommandResolver;
    if CommandId = '' then Result := rdrExecuted
    else
      Result := TRibbonCommandDispatcher.Dispatch(CommandId, Resolver,
        Guard.Item, nil, True);
    if Guard.Root <> nil then Guard.Root.RefreshCommands;
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.FindItemView(const AId: string): TControl;
begin
  Result := FPresenter.FindItemView(AId);
end;

function TCamARTRibbon.FindQuickAccessView(const AId: string): TControl;
begin
  Result := FQuickAccessPresenter.FindView(AId);
end;

function TCamARTRibbon.VisualItemCount: Integer;
begin
  Result := FPresenter.ItemViewCount;
end;

function TCamARTRibbon.QuickAccessViewCount: Integer;
begin
  Result := FQuickAccessPresenter.Count;
end;

procedure TCamARTRibbon.ReportDiagnostic(const AMessage: string);
var
  Handler: TRibbonDiagnosticEvent;
begin
  Handler := FOnDiagnostic;
  if Assigned(Handler) then Handler(Self, AMessage);
end;

function TCamARTRibbon.GetLayoutMode: TRibbonLayoutMode;
begin
  Result := FLastLayout.Mode;
end;

function TCamARTRibbon.GetMeasurementPassCount: Integer;
begin
  Result := FPresenter.MeasurementPassCount;
end;

function TCamARTRibbon.GetMeasurementCacheHitCount: Integer;
begin
  Result := FPresenter.MeasurementCacheHitCount;
end;

function TCamARTRibbon.GroupPresentation(const AId: string): TRibbonGroupPresentation;
var
  Group: TRibbonGroupPlacement;
begin
  Result := rgpExpanded;
  for Group in FLastLayout.Groups do
    if Group.Id = AId then Exit(Group.Presentation);
end;

function TCamARTRibbon.FindGroupLauncher(const AId: string): TRibbonGroupLauncher;
begin
  Result := FPresenter.FindGroupLauncher(AId);
end;

function TCamARTRibbon.FindGroupPopupView(const AId: string): TControl;
begin
  Result := nil;
  if FGroupPopup <> nil then Result := FGroupPopup.FindItemView(AId);
end;

function TCamARTRibbon.GroupPopupIsOpen: Boolean;
begin
  Result := (FGroupPopup <> nil) and FGroupPopup.IsOpen;
end;

procedure TCamARTRibbon.SetInputDensity(const AValue: TRibbonInputDensity);
begin
  if (Ord(AValue) < Ord(Low(TRibbonInputDensity))) or
     (Ord(AValue) > Ord(High(TRibbonInputDensity))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon input density.');
  if FInputDensity = AValue then Exit;
  FInputDensity := AValue;
  if not TryClosePopup then Exit;
  FPresenter.InputDensity := AValue;
  FQuickAccessPresenter.InputDensity := AValue;
  FPopups.InputDensity := AValue;
  FGroupPopup.InputDensity := AValue;
  AttachRibbonInput(FApplicationButton, AValue);
  AttachRibbonInput(FCompactButton, AValue);
  ConfigureScrolling;
  Refresh;
end;

procedure TCamARTRibbon.SetReduceMotion(const AValue: Boolean);
begin
  if FReduceMotion = AValue then Exit;
  FReduceMotion := AValue;
  ConfigureScrolling;
end;

procedure TCamARTRibbon.SetCompactCaption(const AValue: string);
begin
  if FCompactCaption = AValue then Exit;
  FCompactCaption := AValue;
  FCompactButton.Text := AValue;
  Refresh;
end;

procedure TCamARTRibbon.ConfigureScrolling;
  procedure Configure(ABox: TCustomScrollBox);
  begin
    if ABox = nil then Exit;
    ABox.TouchTracking := TBehaviorBoolean.True;
    AttachRibbonInput(ABox, FInputDensity);
    if FReduceMotion then
    begin
      ABox.ScrollAnimation := TBehaviorBoolean.False;
      ABox.Bounces := TBehaviorBoolean.False;
    end
    else
    begin
      ABox.ScrollAnimation := TBehaviorBoolean.PlatformDefault;
      ABox.Bounces := TBehaviorBoolean.PlatformDefault;
    end;
    if ABox.AniCalculations <> nil then
    begin
      ABox.AniCalculations.Animation := not FReduceMotion;
      ABox.AniCalculations.BoundsAnimation := not FReduceMotion;
    end;
  end;
begin
  Configure(FTabScroll);
  Configure(FBodyScroll);
  Configure(FQuickAccessScroll);
  if FTabScroll <> nil then FTabScroll.AniCalculations.TouchTracking := [ttHorizontal];
  if FBodyScroll <> nil then FBodyScroll.AniCalculations.TouchTracking := [ttHorizontal, ttVertical];
  if FQuickAccessScroll <> nil then FQuickAccessScroll.AniCalculations.TouchTracking := [ttHorizontal];
  if FPopups <> nil then FPopups.ReduceMotion := FReduceMotion;
  if FGroupPopup <> nil then FGroupPopup.ReduceMotion := FReduceMotion;
end;

procedure TCamARTRibbon.AttachInputControls(AObject: TFmxObject);
var
  Child: TFmxObject;
begin
  if AObject = nil then Exit;
  { Native text/combobox/color selection keeps its own drag/IME behavior.
    Only command-like surfaces turn a drag into Ribbon viewport scrolling. }
  if (AObject is TRibbonInputButton) or (AObject is TRibbonInputCheckBox) or
     (AObject is TRibbonInputRadioButton) then
    AttachRibbonInput(TControl(AObject), FInputDensity)
  else if (AObject is TControl) and TControl(AObject).CanFocus then
    AttachRibbonFocus(TControl(AObject));
  if AObject.Children <> nil then
    for Child in AObject.Children do AttachInputControls(Child);
end;

function TCamARTRibbon.GroupSnapshot(const AId: string;
  out AData: TRibbonGroupViewData): Boolean;
var
  Group: TRibbonGroupViewData;
begin
  AData := Default(TRibbonGroupViewData);
  for Group in FLastGroups do
    if Group.Id = AId then
    begin
      AData := Group;
      Exit(Group.Visible);
    end;
  Result := False;
end;

procedure TCamARTRibbon.GroupClicked(Sender: TObject; const AId: string);
begin
  if not RibbonActivationAllowed(FindGroupLauncher(AId)) then Exit;
  ShowGroupPopup(AId);
end;

procedure TCamARTRibbon.ShowGroupPopup(const AGroupId: string);
var
  Data: TRibbonGroupViewData;
  Anchor: TControl;
begin
  if FDestroying or not HostAllowsExecution then Exit;
  if not TryClosePopup then Exit;
  if not GroupSnapshot(AGroupId, Data) or not Data.Enabled then Exit;
  Anchor := FindGroupLauncher(AGroupId);
  if (Anchor = nil) or not Anchor.Visible or not Anchor.ParentedVisible then
    Anchor := FCompactButton;
  if not Anchor.Visible or not Anchor.ParentedVisible then Anchor := Self;
  FGroupPopup.Open(Anchor, Data, FInputDensity);
  { Open may invoke native focus callbacks; it is the final root operation. }
end;

procedure TCamARTRibbon.CompactClicked(Sender: TObject);
begin
  if not RibbonActivationAllowed(FCompactButton) then Exit;
  ShowCompactMenu;
end;

procedure TCamARTRibbon.ShowCompactMenu;
var
  Entries: TArray<TRibbonPopupEntry>;
  Group: TRibbonGroupViewData;
  Anchor: TControl;
  Count: Integer;
begin
  if FDestroying or not HostAllowsExecution then Exit;
  if not TryClosePopup then Exit;
  SetLength(Entries, Length(FLastGroups));
  Count := 0;
  for Group in FLastGroups do
    if Group.Visible then
    begin
      Entries[Count] := Default(TRibbonPopupEntry);
      Entries[Count].Id := Group.Id;
      Entries[Count].Caption := Group.Caption;
      Entries[Count].Hint := Group.Caption;
      Entries[Count].Enabled := Group.Enabled;
      Inc(Count);
    end;
  SetLength(Entries, Count);
  if Count = 0 then Exit;
  FPopupContext := rpcGroups;
  Anchor := FCompactButton;
  if not Anchor.Visible then Anchor := Self;
  FPopups.OpenMenu(Anchor, Entries, PopupSelected);
end;

procedure TCamARTRibbon.GroupPopupInput(Sender: TObject;
  const AInput: TRibbonItemInput);
var
  Anchor: TControl;
begin
  if not GroupPopupIsOpen then Exit;
  if AInput.Kind = rikDropDown then
  begin
    { The next menu must outlive closure of the separate group view. Keep
      its anchor on the main Ribbon; the model is still resolved by Id. }
    Anchor := FindGroupLauncher(FGroupPopup.GroupId);
    if (Anchor = nil) or not Anchor.Visible then Anchor := FCompactButton;
    if not Anchor.Visible then Anchor := Self;
    OpenButtonPopup(AInput.Id, Anchor, True);
  end
  else
    ItemInput(Sender, AInput);
end;

procedure TCamARTRibbon.SyncGroupPopup;
var
  Data: TRibbonGroupViewData;
begin
  if not GroupPopupIsOpen then Exit;
  if not GroupSnapshot(FGroupPopup.GroupId, Data) or not Data.Enabled then
    FGroupPopup.Close
  else
    FGroupPopup.Sync(Data);
end;

procedure TCamARTRibbon.EnsureSelectedTabVisible;
var
  Bounds: TRectF;
  Offset, VisibleWidth, MaxOffset: Single;
begin
  if not FPresenter.SelectedTabBounds(Bounds) then Exit;
  Bounds.Offset(FTabHost.Position.X, FTabHost.Position.Y);
  VisibleWidth := Max(0, FTabScroll.ViewportRect.Width);
  Offset := FTabScroll.ViewportPosition.X;
  if Bounds.Left < Offset then Offset := Bounds.Left
  else if Bounds.Right > Offset + VisibleWidth then
    Offset := Bounds.Right - VisibleWidth;
  MaxOffset := Max(0, FHeaderHost.Width - VisibleWidth);
  Offset := Min(MaxOffset, Max(0, Offset));
  if Offset <> FTabScroll.ViewportPosition.X then
    FTabScroll.ViewportPosition := PointF(Offset, 0);
end;

procedure TCamARTRibbon.ContextPulse(Sender: TObject);
var
  Scale: Single;
  Revision: UInt64;
  Guard: TRibbonExecutionGuard;
begin
  if not FReady or FDestroying or FRefreshing or
     (csLoading in ComponentState) then Exit;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    if FStyleContext.CheckForChanges then Exit;
    if Guard.Root = nil then Exit;
    if FThemeRefreshPending and not FApplyingTheme then
    begin
      ApplyTheme;
      Exit;
    end;
    if not HostAllowsExecution then
    begin
      if PopupIsOpen then ClosePopup;
      Exit;
    end;
    Scale := 1;
    if Scene <> nil then Scale := Scene.GetSceneScale;
    Revision := 0;
    if FIconProvider <> nil then Revision := FIconProvider.GetRevision;
    if (Scale <> FLastSceneScale) or (Revision <> FLastIconRevision) or
       (FSkLabels.GetRevision <> FLastSkLabelRevision) then
    begin
      FLastSceneScale := Scale;
      FLastIconRevision := Revision;
      FLastSkLabelRevision := FSkLabels.GetRevision;
      if not TryClosePopup then Exit;
      Refresh;
      Exit;
    end;
    FPopups.CheckHostGeometry;
    if Guard.Root = nil then Exit;
    FGroupPopup.CheckHostGeometry;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.Relayout;
var
  Guard: TRibbonExecutionGuard;
begin
  if not FReady or FDestroying or FRestoring or
     (csLoading in ComponentState) then Exit;
  if FModel.UpdateCount > 0 then
  begin
    FModel.Changed([rckMeasure]);
    Exit;
  end;
  if FRefreshing then
  begin
    FRefreshRequested := True;
    Exit;
  end;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FRefreshing := True;
    FRefreshRequested := False;
    try
      LayoutViews;
    finally
      if Guard.Root <> nil then FRefreshing := False;
    end;
    if Guard.Root = nil then Exit;
    if FRefreshRequested then RefreshInternal(False);
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.KeyDown(var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  RibbonKeyboardInput(Self);
  if (Key = vkEscape) or (Key = vkHardwareBack) then
    if PopupIsOpen then
    begin
      Key := 0;
      KeyChar := #0;
      ClosePopup;
      Exit;
    end;
  inherited;
end;

function TCamARTRibbon.GetRibbonStyleContext: TRibbonStyleContext;
begin
  Result := FStyleContext;
end;

function TCamARTRibbon.GetStyleBook: TStyleBook;
begin
  Result := nil;
  if FStyleContext <> nil then Result := FStyleContext.StyleBook;
end;

function TCamARTRibbon.GetEffectiveStyleBook: TStyleBook;
begin
  Result := nil;
  if FStyleContext <> nil then Result := FStyleContext.EffectiveStyleBook;
end;

procedure TCamARTRibbon.SetStyleBook(const AValue: TStyleBook);
begin
  FStyleContext.StyleBook := AValue;
  { The context callback may destroy this component; no access follows. }
end;

function TCamARTRibbon.GetTheme: TRibbonTheme;
begin
  Result := rtModernLight;
  if FStyleContext <> nil then Result := FStyleContext.Theme;
end;

procedure TCamARTRibbon.SetTheme(const AValue: TRibbonTheme);
begin
  FStyleContext.Theme := AValue;
end;

function TCamARTRibbon.GetStyleDiagnostics: string;
begin
  Result := '';
  if FStyleContext <> nil then Result := FStyleContext.Diagnostics;
  if (FStyleAdapter <> nil) and (FStyleAdapter.Diagnostics <> '') then
  begin
    if Result <> '' then Result := Result + sLineBreak;
    Result := Result + FStyleAdapter.Diagnostics;
  end;
end;

procedure TCamARTRibbon.RefreshTheme;
begin
  if FStyleContext <> nil then FStyleContext.Refresh;
end;

procedure TCamARTRibbon.StyleContextChanged(Sender: TObject);
begin
  if not FReady or FDestroying then Exit;
  FThemeRefreshPending := True;
  if (csLoading in ComponentState) or FRestoring or FApplyingTheme then Exit;
  if FModel.UpdateCount > 0 then
  begin
    FModel.Changed([rckMeasure]);
    Exit;
  end;
  if FRefreshing then Exit;
  ApplyTheme;
end;

procedure TCamARTRibbon.ApplyTheme;
var
  Guard: TRibbonExecutionGuard;
  Diagnostic: string;

begin
  if not FReady or FDestroying or FApplyingTheme then Exit;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FApplyingTheme := True;
    try
      repeat
        FThemeRefreshPending := False;
        if not TryClosePopup then Exit;
        if not ReapplyRibbonStyleTree(Self) then Exit;
        FPresenter.InvalidateMeasurements;
        RefreshInternal(True);
        if Guard.Root = nil then Exit;
      until not FThemeRefreshPending;
    finally
      if Guard.Root <> nil then FApplyingTheme := False;
    end;
    if Guard.Root = nil then Exit;
    Diagnostic := GetStyleDiagnostics;
    if Diagnostic <> FLastStyleDiagnostic then
    begin
      FLastStyleDiagnostic := Diagnostic;
      if Diagnostic <> '' then ReportDiagnostic(Diagnostic);
    end;
    { ReportDiagnostic is the final external callback. }
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.GetDefaultStyleLookupName: string;
begin
  Result := RibbonRootStyleName;
end;

function TCamARTRibbon.GetStyleObject: TFmxObject;
begin
  Result := GetStyleObject(True);
end;

function TCamARTRibbon.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  if FStyleContext <> nil then
    Exit(FStyleContext.ResolveRibbonStyle(Self, rsrRoot, Clone));
  Result := inherited GetStyleObject(Clone);
  if (Result = nil) and Clone then Result := CreateDefaultRibbonStyle;
end;

procedure TCamARTRibbon.ApplyStyle;
var
  Guard: TRibbonExecutionGuard;
begin
  if not FReady then
  begin
    inherited;
    if FStyleAdapter <> nil then FStyleAdapter.Bind;
    Exit;
  end;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    inherited;
    if Guard.Root = nil then Exit;
    if FStyleAdapter <> nil then FStyleAdapter.Bind;
    UpdateThemeEnabled;
    if Guard.Root = nil then Exit;
    if FApplyingTheme then Exit;
    if not TryClosePopup then Exit;
    Refresh;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.UpdateThemeEnabled;
begin
  if not FReady or FDestroying then Exit;
  if FindStyleResource(RibbonThemeMarkerPart) <> nil then
    DisabledOpacity := 1
  else
    DisabledOpacity := FNativeDisabledOpacity;
  ApplyRibbonThemeEnabled(Self, AbsoluteEnabled);
end;

procedure TCamARTRibbon.RecalcEnabled;
var
  Guard: TRibbonExecutionGuard;
begin
  if not FReady or FDestroying then
  begin
    inherited;
    Exit;
  end;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    inherited;
    if Guard.Root <> nil then UpdateThemeEnabled;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.FreeStyle;
begin
  if FStyleAdapter <> nil then FStyleAdapter.Clear;
  { Hosts remain children of Self/standard scroll contents at every point;
    none is ever inserted in a temporary style subtree. }
  inherited;
end;

procedure TCamARTRibbon.DoResized;
var
  Guard: TRibbonExecutionGuard;
begin
  if not FReady then
  begin
    inherited;
    Exit;
  end;
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    inherited;
    if Guard.Root = nil then Exit;
    { FMX calls Resize before realigning the style tree. DoResized runs after
      alignment, so expansion must measure the new content-part width. }
    if not FCollapsed then FExpandedHeight := Height;
    if not TryClosePopup then Exit;
    Relayout;
  finally
    Guard.Free;
  end;
end;

procedure TCamARTRibbon.GetChildren(Proc: TGetChildProc; Root: TComponent);
begin
  if FModel <> nil then FModel.ValidateTree;
  if FQuickAccess <> nil then FQuickAccess.Validate;
  if FApplicationMenu <> nil then FApplicationMenu.Validate;
  { GetChildOwner is Self for the model ownership chain. Streaming an ordinary
    form-owned TControl below this component would silently change its Owner
    on reload. Stage 2 supports model children only, and rejects that unsupported
    case rather than losing/re-owning external controls. Ask FMX to enumerate
    candidates so internal Stored=False hosts remain outside this decision. }
  inherited GetChildren(ValidateInheritedStreamChild, Root);
  if FModel <> nil then FModel.GetChildren(Proc, Root);
end;

procedure TCamARTRibbon.ValidateInheritedStreamChild(AChild: TComponent);
begin
  if (AChild is TFmxObject) and TFmxObject(AChild).Stored then
    raise EWriteError.CreateFmt(
      'Ribbon cannot stream an external visual child %s (%s). ' +
      'Use the Ribbon model API and registered item views for content.',
      [AChild.Name, AChild.ClassName]);
end;

function TCamARTRibbon.GetChildOwner: TComponent;
begin
  Result := Self;
end;

function TCamARTRibbon.GetChildParent: TComponent;
begin
  Result := Self;
end;

procedure TCamARTRibbon.Loaded;
var
  Requested: string;
  Guard: TRibbonExecutionGuard;
begin
  Guard := TRibbonExecutionGuard.CreateGuard(Self, nil);
  try
    FRestoring := True;
    FModel.BeginUpdate;
    try
      inherited;
      if Guard.Root = nil then Exit;
      FThemeRefreshPending := True;
      FModel.ValidateTree;
      FQuickAccess.Validate;
      FApplicationMenu.Validate;
      Requested := FPendingActiveTabId;
      FPendingActiveTabId := '';
      if Requested <> '' then
        FSelectionEventPending := FSelection.Select(Requested, TabStates)
      else
        FSelectionEventPending := FSelection.Reconcile(TabStates);
      if FCollapsed then Height := RibbonDefaultTabHeight + 8;
      if Guard.Root = nil then Exit;
      FModel.Changed([rckStructure, rckMeasure, rckState]);
    finally
      if Guard.Root <> nil then
      begin
        Guard.Root.FRestoring := False;
        { This can deliver a public selection event. No root access follows. }
        Guard.Root.FModel.EndUpdate;
      end;
    end;
  finally
    Guard.Free;
  end;
end;

function TCamARTRibbon.FindButtonView(const AId: string): TRibbonCommandButton;
begin
  Result := FPresenter.FindButtonView(AId);
end;

function TCamARTRibbon.FindTabView(const AId: string): TRibbonTabButton;
begin
  Result := FPresenter.FindTabView(AId);
end;

function TCamARTRibbon.VisualButtonCount: Integer;
begin
  Result := FPresenter.ButtonViewCount;
end;

function TCamARTRibbon.VisualGroupCount: Integer;
begin
  Result := FPresenter.GroupViewCount;
end;

function TCamARTRibbon.VisualTabCount: Integer;
begin
  Result := FPresenter.TabViewCount;
end;

initialization
  RegisterClass(TCamARTRibbon);

finalization
  UnRegisterClass(TCamARTRibbon);

end.
