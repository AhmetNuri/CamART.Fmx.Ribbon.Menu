unit CamART.Ribbon.Popups;

{$B-}

interface

uses
  System.Classes,
  System.Types,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Layouts,
  FMX.StdCtrls,
  FMX.TextLayout,
  CamART.Ribbon.Icons,
  CamART.Ribbon.Types,
  CamART.Ribbon.Themes,
  CamART.Ribbon.StyleContext,
  CamART.Ribbon.Style,
  CamART.Ribbon.PopupGeometry;

type
  TRibbonPopupEntry = record
    Id: string;
    Caption: string;
    Hint: string;
    IconKey: string;
    Enabled: Boolean;
    Checked: Boolean;
    Separator: Boolean;
  end;

  TRibbonPopupSelectEvent = procedure(Sender: TObject;
    const AId: string) of object;

  IRibbonPopupLifetime = interface
    ['{0383EE22-A3FA-4339-8D0A-ED032CBB737C}']
    function IsAlive: Boolean;
    function GetSession: UInt64;
    function GetAnchor: TControl;
    function GetHost: TCommonCustomForm;
    procedure Advance;
    procedure Stop;
    procedure SetTargets(AAnchor: TControl; AHost: TCommonCustomForm);
  end;

  { Detached descriptors only: this service never stores a model node.
    Selection is queued after the native click stack has unwound. Close,
    another Open, or destruction cancels pending selection/focus work. }
  TRibbonPopupService = class(TComponent)
  private
    FPopup: TRibbonStyledPopup;
    FBody: TLayout;
    FScroll: TScrollBox;
    FButtons: TList<TButton>;
    FMeasure: TTextLayout;
    FHostWatch: TTimer;
    FAnchor: TControl;
    FHost: TCommonCustomForm;
    FLifetime: IRibbonPopupLifetime;
    FOnSelect: TRibbonPopupSelectEvent;
    FIconProvider: IRibbonIconProvider;
    FDestroying: Boolean;
    FColumns: Integer;
    FIconScale: Single;
    FInputDensity: TRibbonInputDensity;
    FReduceMotion: Boolean;
    FViewport: TRibbonPopupViewport;
    FStyleContext: TRibbonStyleContext;
    FStyleRevision: UInt64;
    FStyleDirty: Boolean;
    procedure SetStyleContext(const AValue: TRibbonStyleContext);
    function PrepareStyles: Boolean;
    procedure SetInputDensity(const AValue: TRibbonInputDensity);
    procedure SetReduceMotion(const AValue: Boolean);
    procedure ApplyMotionPolicy;
    function GetIsOpen: Boolean;
    procedure SetIconProvider(const AValue: IRibbonIconProvider);
    procedure EnsurePopup;
    procedure AttachTargets(AAnchor: TControl);
    procedure ReleaseTargets;
    procedure ValidateEntries(const AEntries: TArray<TRibbonPopupEntry>);
    function BeginOpen(AAnchor: TControl;
      AOnSelect: TRibbonPopupSelectEvent): Boolean;
    procedure FinishOpen(AWidth, AHeight: Single);
    procedure QueueReturn(AHandler: TRibbonPopupSelectEvent; const AId: string;
      ARestoreFocus: Boolean);
    procedure ClosePopup(ARestoreFocus: Boolean);
    procedure EntryClicked(Sender: TObject);
    procedure PopupClosed(Sender: TObject);
    procedure PopupKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: WideChar; Shift: TShiftState);
    procedure HostPulse(Sender: TObject);
    function AddButton(const AEntry: TRibbonPopupEntry;
      ASelected: Boolean; ARole: TRibbonStyleRole): TButton;
    function AddCaption(AButton: TButton; const ACaption: string): TLabel;
    function CaptionSize(ALabel: TLabel; out ASize: TSizeF): Boolean;
    function EntryMetrics(AButton: TButton; const AIconPart: string;
      ADefaultIcon: Single; out AInsets: TRectF; out AIconSide: Single): Boolean;
    procedure FocusRelative(ASender: TObject; ADelta: Integer);
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenMenu(AAnchor: TControl;
      const AEntries: TArray<TRibbonPopupEntry>;
      AOnSelect: TRibbonPopupSelectEvent);
    procedure OpenGallery(AAnchor: TControl;
      const AEntries: TArray<TRibbonPopupEntry>; const ASelectedId: string;
      AOnSelect: TRibbonPopupSelectEvent);
    procedure Close;
    procedure CheckHostGeometry;
    property InputDensity: TRibbonInputDensity read FInputDensity write SetInputDensity;
    property ReduceMotion: Boolean read FReduceMotion write SetReduceMotion default True;
    property IsOpen: Boolean read GetIsOpen;
    property ScrollBox: TScrollBox read FScroll;
    property StyleContext: TRibbonStyleContext read FStyleContext write SetStyleContext;
    property IconProvider: IRibbonIconProvider read FIconProvider
      write SetIconProvider;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.UITypes,
  FMX.BehaviorManager,
  FMX.Graphics,
  FMX.Objects,
  CamART.Ribbon.Interaction,
  CamART.Ribbon.Views,
  CamART.Ribbon.ThemeStyles,
  CamART.Ribbon.StyleScope,
  CamART.Ribbon.StyledControls;

type
  TRibbonNativePopup = class(TRibbonStyledPopup)
  public
    property OnKeyDown;
  end;

  TRibbonPopupButton = class(TRibbonInputButton)
  private
    function GetSelected: Boolean;
  protected
    procedure ApplyStyle; override;
  public
    { Gallery style roles use the same IsSelected contract as inline list
      cells. The popup's semantic selected value remains the native pressed
      state, which is established before the style is applied. }
    property IsSelected: Boolean read GetSelected;
  end;

  { BeginOpen must watch the incoming anchor before closing the previous
    popup: native close/focus callbacks may release a different control. }
  TRibbonPopupAnchorGuard = class(TComponent)
  private
    FAnchor: TControl;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateAnchor(AAnchor: TControl);
    destructor Destroy; override;
    property Anchor: TControl read FAnchor;
  end;

  TRibbonPopupLifetime = class(TInterfacedObject, IRibbonPopupLifetime)
  private
    FAlive: Boolean;
    FSession: UInt64;
    FAnchor: TControl;
    FHost: TCommonCustomForm;
  public
    constructor Create;
    function IsAlive: Boolean;
    function GetSession: UInt64;
    function GetAnchor: TControl;
    function GetHost: TCommonCustomForm;
    procedure Advance;
    procedure Stop;
    procedure SetTargets(AAnchor: TControl; AHost: TCommonCustomForm);
  end;

procedure TRibbonPopupButton.ApplyStyle;
var
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control = nil then Exit;
    { Preserve native Text for the button's semantic caption. The measured
      label supplies its visual text, so hide only the style text control. }
    if TextObject <> nil then
    begin
      TextObject.Visible := False;
      TextObject.HitTest := False;
    end;
    if RibbonStyleRole = rsrGalleryItem then
      StartTriggerAnimation(Self, 'IsSelected');
  finally
    Watch.Free;
  end;
end;

function TRibbonPopupButton.GetSelected: Boolean;
begin
  Result := IsPressed;
end;

constructor TRibbonPopupAnchorGuard.CreateAnchor(AAnchor: TControl);
begin
  inherited Create(nil);
  if AAnchor = nil then
    raise EArgumentNilException.Create('A popup anchor is required.');
  if csDestroying in AAnchor.ComponentState then
    raise EArgumentException.Create('A popup anchor is being destroyed.');
  FAnchor := AAnchor;
  TComponent(FAnchor).FreeNotification(Self);
end;

destructor TRibbonPopupAnchorGuard.Destroy;
begin
  if FAnchor <> nil then TComponent(FAnchor).RemoveFreeNotification(Self);
  inherited;
end;

procedure TRibbonPopupAnchorGuard.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FAnchor) then FAnchor := nil;
end;

function FocusIdentity(AHost: TCommonCustomForm): Pointer;
var
  FocusedControl: IControl;
begin
  Result := nil;
  if AHost = nil then Exit;
  FocusedControl := AHost.Focused;
  if FocusedControl <> nil then Result := Pointer(FocusedControl.GetObject);
  { This local interface is released before any focus or user callback. The
    returned address is compared only and does not retain the control. }
end;

function PopupTargetsAvailable(const AToken: IRibbonPopupLifetime): Boolean;
var
  Anchor: TControl;
  Host: TCommonCustomForm;
begin
  Result := False;
  Anchor := AToken.GetAnchor;
  Host := AToken.GetHost;
  if (Anchor = nil) or (Host = nil) then Exit;
  Result := not (csDestroying in Anchor.ComponentState) and
    not (csDestroying in Host.ComponentState) and Host.Visible and
    Anchor.Visible and Anchor.ParentedVisible and Anchor.AbsoluteEnabled;
end;

constructor TRibbonPopupLifetime.Create;
begin
  inherited Create;
  FAlive := True;
  FSession := 1;
end;

function TRibbonPopupLifetime.IsAlive: Boolean;
begin
  Result := FAlive;
end;

function TRibbonPopupLifetime.GetSession: UInt64;
begin
  Result := FSession;
end;

function TRibbonPopupLifetime.GetAnchor: TControl;
begin
  Result := FAnchor;
end;

function TRibbonPopupLifetime.GetHost: TCommonCustomForm;
begin
  Result := FHost;
end;

procedure TRibbonPopupLifetime.Advance;
begin
  if FSession = High(UInt64) then FSession := 1 else Inc(FSession);
end;

procedure TRibbonPopupLifetime.Stop;
begin
  FAlive := False;
  FAnchor := nil;
  FHost := nil;
  Advance;
end;

procedure TRibbonPopupLifetime.SetTargets(AAnchor: TControl;
  AHost: TCommonCustomForm);
begin
  FAnchor := AAnchor;
  FHost := AHost;
end;

constructor TRibbonPopupService.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FReduceMotion := True;
  FLifetime := TRibbonPopupLifetime.Create;
  FButtons := TList<TButton>.Create;
  FMeasure := TTextLayoutManager.DefaultTextLayout.Create;
  FHostWatch := TTimer.Create(Self);
  FHostWatch.Enabled := False;
  FHostWatch.Interval := 100;
  FHostWatch.OnTimer := HostPulse;
  EnsurePopup;
end;

destructor TRibbonPopupService.Destroy;
begin
  FDestroying := True;
  if FStyleContext <> nil then FStyleContext.RemoveFreeNotification(Self);
  FStyleContext := nil;
  if FLifetime <> nil then FLifetime.Stop;
  FOnSelect := nil;
  if FHostWatch <> nil then
  begin
    FHostWatch.Enabled := False;
    FHostWatch.OnTimer := nil;
  end;
  ReleaseTargets;
  if FPopup <> nil then
  begin
    FPopup.OnClosePopup := nil;
    TRibbonNativePopup(FPopup).OnKeyDown := nil;
    FPopup.IsOpen := False;
  end;
  FreeAndNil(FPopup);
  FBody := nil;
  FScroll := nil;
  FButtons.Free;
  FMeasure.Free;
  FIconProvider := nil;
  FLifetime := nil;
  inherited;
end;

procedure TRibbonPopupService.EnsurePopup;
begin
  if FPopup <> nil then Exit;
  FPopup := TRibbonNativePopup.Create(Self);
  FPopup.StyleContext := FStyleContext;
  FPopup.Stored := False;
  FPopup.Placement := TPlacement.Bottom;
  FPopup.DragWithParent := True;
  FPopup.CanFocus := True;
  FPopup.OnClosePopup := PopupClosed;
  TRibbonNativePopup(FPopup).OnKeyDown := PopupKeyDown;
  TComponent(FPopup).FreeNotification(Self);
  { FMX TPopup has no StaysOpen property. Its native popup form handles
    outside mouse/touch dismissal; IsOpen is the supported close API. }
end;

procedure TRibbonPopupService.SetStyleContext(const AValue: TRibbonStyleContext);
begin
  if FStyleContext = AValue then Exit;
  if (AValue <> nil) and (csDestroying in AValue.ComponentState) then
    raise EArgumentException.Create('Cannot use a destroying Ribbon style context.');
  if FStyleContext <> nil then FStyleContext.RemoveFreeNotification(Self);
  FStyleContext := AValue;
  if FStyleContext <> nil then FStyleContext.FreeNotification(Self);
  FStyleDirty := True;
  if FPopup <> nil then FPopup.StyleContext := FStyleContext;
  { Closing is final: user focus/close callbacks may destroy this service. }
  Close;
end;

function TRibbonPopupService.PrepareStyles: Boolean;
var
  Token: IRibbonPopupLifetime;
  Session, Revision: UInt64;
  Context: TRibbonStyleContext;
  PreviousBook: TStyleBook;
begin
  Result := False;
  Token := FLifetime;
  Session := Token.GetSession;
  Context := FStyleContext;
  Revision := 0;
  if Context <> nil then Revision := Context.Revision;
  PreviousBook := FPopup.StyleBook;
  if not FPopup.PrepareStyleBook then Exit;
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  if (Context <> nil) and (Context.Revision <> Revision) then Exit;
  if FStyleDirty or (FStyleRevision <> Revision) or
     (PreviousBook <> FPopup.StyleBook) then
  begin
    FStyleDirty := True;
    if not ReapplyRibbonStyleTree(FPopup,
      function: Boolean
      begin
        Result := Token.IsAlive and (Token.GetSession = Session);
        if Result and (Context <> nil) then Result := Context.Revision = Revision;
      end) then Exit;
    FStyleRevision := Revision;
    FStyleDirty := False;
  end;
  Result := True;
end;

procedure TRibbonPopupService.ReleaseTargets;
begin
  if FAnchor <> nil then TComponent(FAnchor).RemoveFreeNotification(Self);
  if FHost <> nil then TComponent(FHost).RemoveFreeNotification(Self);
  FAnchor := nil;
  FHost := nil;
  if FLifetime <> nil then FLifetime.SetTargets(nil, nil);
end;

procedure TRibbonPopupService.AttachTargets(AAnchor: TControl);
var
  Current: TFmxObject;
begin
  if AAnchor = nil then raise EArgumentNilException.Create('A popup anchor is required.');
  if csDestroying in AAnchor.ComponentState then
    raise EArgumentException.Create('A popup anchor is being destroyed.');
  Current := AAnchor;
  while (Current <> nil) and not (Current is TCommonCustomForm) do
    Current := Current.Parent;
  if not (Current is TCommonCustomForm) then
    raise EArgumentException.Create('A popup anchor must belong to an FMX form.');
  ReleaseTargets;
  FAnchor := AAnchor;
  FHost := TCommonCustomForm(Current);
  TComponent(FAnchor).FreeNotification(Self);
  TComponent(FHost).FreeNotification(Self);
  FLifetime.SetTargets(FAnchor, FHost);
  { Parent assignment may enter native callbacks; keep it final. Absolute
    placement is supplied later from the guarded viewport snapshot. }
  FPopup.Parent := FHost;
end;

procedure TRibbonPopupService.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  LostTarget: Boolean;
begin
  inherited;
  if Operation = opRemove then
  begin
    LostTarget := False;
    if AComponent = FStyleContext then
    begin
      FStyleContext := nil;
      FStyleDirty := True;
      LostTarget := True;
    end;
    if AComponent = FAnchor then
    begin
      FAnchor := nil;
      if FPopup <> nil then FPopup.PlacementTarget := nil;
      LostTarget := True;
    end;
    if AComponent = FHost then
    begin
      FHost := nil;
      LostTarget := True;
    end;
    if AComponent = FPopup then
    begin
      FPopup := nil;
      FBody := nil;
      FScroll := nil;
      if FButtons <> nil then FButtons.Clear;
      LostTarget := True;
    end;
    if LostTarget and not FDestroying then
    begin
      FLifetime.SetTargets(FAnchor, FHost);
      Close;
    end;
  end;
end;

function TRibbonPopupService.GetIsOpen: Boolean;
begin
  Result := (FPopup <> nil) and FPopup.IsOpen;
end;

procedure TRibbonPopupService.SetReduceMotion(const AValue: Boolean);
begin
  FReduceMotion := AValue;
  ApplyMotionPolicy;
end;

procedure TRibbonPopupService.ApplyMotionPolicy;
begin
  if FScroll = nil then Exit;
  { Only the owned scroll surface is changed. Caller StyleBook animations
    remain under the application's control. The behavior flags keep a
    later platform/style refresh from enabling inertial movement again. }
  if FReduceMotion then
  begin
    FScroll.ScrollAnimation := TBehaviorBoolean.False;
    FScroll.Bounces := TBehaviorBoolean.False;
  end
  else
  begin
    FScroll.ScrollAnimation := TBehaviorBoolean.PlatformDefault;
    FScroll.Bounces := TBehaviorBoolean.PlatformDefault;
  end;
  FScroll.AniCalculations.Animation := not FReduceMotion;
  FScroll.AniCalculations.BoundsAnimation := not FReduceMotion;
end;

procedure TRibbonPopupService.SetInputDensity(const AValue: TRibbonInputDensity);
begin
  if (Ord(AValue) < Ord(Low(TRibbonInputDensity))) or
     (Ord(AValue) > Ord(High(TRibbonInputDensity))) then
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon input density.');
  if FInputDensity = AValue then Exit;
  FInputDensity := AValue;
  Close;
end;

procedure TRibbonPopupService.SetIconProvider(const AValue: IRibbonIconProvider);
begin
  if FIconProvider = AValue then Exit;
  FIconProvider := AValue;
  Close;
end;

procedure TRibbonPopupService.ValidateEntries(const AEntries: TArray<TRibbonPopupEntry>);
var
  Entry: TRibbonPopupEntry;
  Seen: TDictionary<string, Byte>;
begin
  Seen := TDictionary<string, Byte>.Create;
  try
    for Entry in AEntries do
    begin
      if Entry.Separator then Continue;
      if Entry.Id = '' then
        raise EArgumentException.Create('A selectable popup entry needs an Id.');
      if Seen.ContainsKey(Entry.Id) then
        raise EArgumentException.CreateFmt('Duplicate popup entry Id: %s', [Entry.Id]);
      Seen.Add(Entry.Id, 0);
    end;
  finally
    Seen.Free;
  end;
end;

function TRibbonPopupService.BeginOpen(AAnchor: TControl;
  AOnSelect: TRibbonPopupSelectEvent): Boolean;
var
  Token: IRibbonPopupLifetime;
  Guard: TRibbonPopupAnchorGuard;
  Session: UInt64;
begin
  Result := False;
  Token := FLifetime;
  Guard := TRibbonPopupAnchorGuard.CreateAnchor(AAnchor);
  try
    { Close advances once. A reentrant Open/Close advances again and owns
      the new session; this outer request must then stop. }
    Session := Token.GetSession;
    if Session = High(UInt64) then Session := 1 else Inc(Session);
    Close;
    if not Token.IsAlive or (Token.GetSession <> Session) or
       (Guard.Anchor = nil) then Exit;
    Token.Advance;
    Session := Token.GetSession;
    EnsurePopup;
    AttachTargets(Guard.Anchor);
    if not Token.IsAlive or (Token.GetSession <> Session) or
       (Guard.Anchor = nil) then Exit;
    if not PopupTargetsAvailable(Token) then Exit;
    FIconScale := 1;
    if Guard.Anchor.Scene <> nil then
      FIconScale := Guard.Anchor.Scene.GetSceneScale;
    FOnSelect := AOnSelect;
    FButtons.Clear;
    FreeAndNil(FBody);
    FScroll := nil;
    if not PrepareStyles then Exit;
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
    FBody := TLayout.Create(FPopup);
    FBody.Parent := FPopup;
    FBody.Stored := False;
    FBody.Align := TAlignLayout.Client;
    FScroll := TRibbonStyledScrollBox.Create(FBody);
    FScroll.Parent := FBody;
    FScroll.Stored := False;
    FScroll.Align := TAlignLayout.Client;
    FScroll.CanFocus := False;
    FScroll.ClipChildren := True;
    AttachRibbonInput(FScroll, FInputDensity);
    ApplyMotionPolicy;
    Result := True;
  finally
    Guard.Free;
  end;
end;

function TRibbonPopupService.AddButton(const AEntry: TRibbonPopupEntry;
  ASelected: Boolean; ARole: TRibbonStyleRole): TButton;
begin
  Result := TRibbonPopupButton.Create(FBody);
  TRibbonPopupButton(Result).RibbonStyleRole := ARole;
  Result.Parent := FScroll;
  Result.Stored := False;
  Result.Text := AEntry.Caption;
  Result.Hint := AEntry.Hint;
  Result.ParentShowHint := False;
  Result.ShowHint := AEntry.Hint <> '';
  Result.TagString := AEntry.Id;
  Result.Enabled := AEntry.Enabled;
  Result.StaysPressed := True;
  Result.IsPressed := ASelected;
  Result.TabOrder := FButtons.Count;
  Result.OnClick := EntryClicked;
  Result.OnKeyDown := PopupKeyDown;
  AttachRibbonInput(Result, FInputDensity);
  FButtons.Add(Result);
end;

function TRibbonPopupService.AddCaption(AButton: TButton;
  const ACaption: string): TLabel;
begin
  Result := TRibbonStyledLabel.Create(AButton);
  Result.Parent := AButton;
  Result.Stored := False;
  Result.HitTest := False;
  Result.CanFocus := False;
  Result.Text := ACaption;
  Result.TextSettings.WordWrap := False;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Other];
end;

function TRibbonPopupService.CaptionSize(ALabel: TLabel;
  out ASize: TSizeF): Boolean;
var
  Token: IRibbonPopupLifetime;
  Session: UInt64;
  Watch: TRibbonStyleWatch;
begin
  Result := False;
  ASize := TSizeF.Create(0, 0);
  Token := FLifetime;
  Session := Token.GetSession;
  Watch := TRibbonStyleWatch.Create(ALabel);
  try
    ALabel.ApplyStyleLookup;
    if not Token.IsAlive or (Token.GetSession <> Session) or
       (Watch.Control = nil) then Exit;
    FMeasure.BeginUpdate;
    try
      FMeasure.MaxSize := PointF(1000000, 1000000);
      FMeasure.WordWrap := False;
      FMeasure.Font.Assign(ALabel.ResultingTextSettings.Font);
      FMeasure.Text := ALabel.Text;
    finally
      FMeasure.EndUpdate;
    end;
    ASize := TSizeF.Create(Ceil(FMeasure.TextWidth), Ceil(FMeasure.TextHeight));
    Result := True;
  finally
    Watch.Free;
  end;
end;

function TRibbonPopupService.EntryMetrics(AButton: TButton;
  const AIconPart: string; ADefaultIcon: Single; out AInsets: TRectF;
  out AIconSide: Single): Boolean;
var
  Token: IRibbonPopupLifetime;
  Session: UInt64;
  Watch: TRibbonStyleWatch;
  Template: TFmxObject;
begin
  Result := False;
  AInsets := RectF(0, 0, 0, 0);
  AIconSide := ADefaultIcon;
  Token := FLifetime;
  Session := Token.GetSession;
  Watch := TRibbonStyleWatch.Create(AButton);
  try
    { Read the borrowed selected template. Measuring popup entries must not
      apply another role to the live native button or change shared resources. }
    Template := TRibbonInputButton(AButton).GetRibbonStyle(False);
    if not Token.IsAlive or (Token.GetSession <> Session) or
       (Watch.Control = nil) then Exit;
    AIconSide := RibbonThemeStyleMetric(Template, AIconPart, ADefaultIcon);
    AInsets := RibbonControlPadding(AButton);
    Result := Token.IsAlive and (Token.GetSession = Session) and
      (Watch.Control <> nil);
  finally
    Watch.Free;
  end;
end;

procedure TRibbonPopupService.OpenMenu(AAnchor: TControl;
  const AEntries: TArray<TRibbonPopupEntry>;
  AOnSelect: TRibbonPopupSelectEvent);
var
  Entry: TRibbonPopupEntry;
  Button: TButton;
  LabelControl: TLabel;
  Line: TRibbonStyledSeparator;
  Icon: TRibbonIconBinding;
  Size: TSizeF;
  Insets: TRectF;
  Y, W, H, RowW, Side, InnerH: Single;
  Caption: string;
  Token: IRibbonPopupLifetime;
  Session: UInt64;
begin
  ValidateEntries(AEntries);
  if not BeginOpen(AAnchor, AOnSelect) then Exit;
  Token := FLifetime;
  Session := Token.GetSession;
  FColumns := 1;
  Y := 6;
  W := 180;
  for Entry in AEntries do
  begin
    if Entry.Separator then
    begin
      Line := TRibbonStyledSeparator.Create(FBody);
      Line.Parent := FScroll;
      Line.Stored := False;
      Line.HitTest := False;
      Line.SetBounds(8, Y + 3, 164, 1);
      Y := Y + 9;
      Continue;
    end;
    Button := AddButton(Entry, Entry.Checked, rsrMenuItem);
    Caption := Entry.Caption;
    if Entry.Checked then Caption := #$2713 + ' ' + Caption;
    LabelControl := AddCaption(Button, Caption);
    if not CaptionSize(LabelControl, Size) then Exit;
    if not EntryMetrics(Button, RibbonThemeSmallIconPart, 16, Insets, Side) then Exit;
    RowW := Max(168, Size.Width + Side + 28) + Insets.Left + Insets.Right;
    W := Max(W, RowW + 12);
    H := Max(32, Max(Size.Height, Side) + 12) + Insets.Top + Insets.Bottom;
    if FInputDensity = ridTouch then H := Max(44, H);
    InnerH := H - Insets.Top - Insets.Bottom;
    Button.SetBounds(6, Y, RowW, H);
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
    LabelControl.SetBounds(Insets.Left + Side + 18,
      Insets.Top + (InnerH - Size.Height) / 2, Size.Width + 2, Size.Height);
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
    Icon := TRibbonIconBinding.Create(Button, Button, FIconProvider);
    Icon.SetBounds(Insets.Left + 9, Insets.Top + (InnerH - Side) / 2, Side, Side);
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
    Icon.SetIcon(Entry.IconKey, Side, FIconScale);
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
    Y := Y + H + 3;
  end;
  for Button in FButtons do
  begin
    Button.Width := W - 12;
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  end;
  if FButtons.Count = 0 then
  begin
    Close;
    Exit;
  end;
  FinishOpen(W + 16, Y + 16);
end;

procedure TRibbonPopupService.OpenGallery(AAnchor: TControl;
  const AEntries: TArray<TRibbonPopupEntry>; const ASelectedId: string;
  AOnSelect: TRibbonPopupSelectEvent);
var
  Entry: TRibbonPopupEntry;
  Button: TButton;
  LabelControl: TLabel;
  Icon: TRibbonIconBinding;
  Labels: TList<TLabel>;
  Sizes: TList<TSizeF>;
  Paddings: TList<TRectF>;
  IconSizes: TList<Single>;
  Size: TSizeF;
  Insets: TRectF;
  CellW, CellH, X, Y, Side: Single;
  I, J: Integer;
  Token: IRibbonPopupLifetime;
  Session: UInt64;
begin
  ValidateEntries(AEntries);
  if not BeginOpen(AAnchor, AOnSelect) then Exit;
  Token := FLifetime;
  Session := Token.GetSession;
  Labels := TList<TLabel>.Create;
  Sizes := nil;
  Paddings := nil;
  IconSizes := nil;
  try
    Sizes := TList<TSizeF>.Create;
    Paddings := TList<TRectF>.Create;
    IconSizes := TList<Single>.Create;
    CellW := 96;
    CellH := 80;
    for Entry in AEntries do
    begin
      if Entry.Separator then Continue;
      Button := AddButton(Entry, Entry.Id = ASelectedId, rsrGalleryItem);
      LabelControl := AddCaption(Button, Entry.Caption);
      LabelControl.TextSettings.HorzAlign := TTextAlign.Center;
      if not CaptionSize(LabelControl, Size) then Exit;
      if not EntryMetrics(Button, RibbonThemeLargeIconPart, 32, Insets, Side) then Exit;
      Labels.Add(LabelControl);
      Sizes.Add(Size);
      Paddings.Add(Insets);
      IconSizes.Add(Side);
      CellW := Max(CellW, Max(96, Max(Size.Width + 16, Side + 16)) +
        Insets.Left + Insets.Right);
      CellH := Max(CellH, Max(80, Size.Height + Side + 22) +
        Insets.Top + Insets.Bottom);
      Icon := TRibbonIconBinding.Create(Button, Button, FIconProvider);
      Icon.SetIcon(Entry.IconKey, Side, FIconScale);
      if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      { Bounds are finalized after all captions have been measured. }
      Icon.Tag := FButtons.Count - 1;
    end;
    if FButtons.Count = 0 then
    begin
      Close;
      Exit;
    end;
    { Fit measured cells to the actual logical viewport. Narrow hosts retain
      at least one full cell via horizontal scrolling rather than clipping. }
    FColumns := Min(FButtons.Count, Max(1,
      Floor((FHost.ClientWidth - 12) / (CellW + 4))));
    for I := 0 to FButtons.Count - 1 do
    begin
      Button := FButtons[I];
      Insets := Paddings[I];
      Side := IconSizes[I];
      X := 6 + (I mod FColumns) * (CellW + 4);
      Y := 6 + (I div FColumns) * (CellH + 4);
      Button.SetBounds(X, Y, CellW, CellH);
      if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      Labels[I].SetBounds(Insets.Left + 8,
        CellH - Insets.Bottom - Sizes[I].Height - 8,
        Max(0, CellW - Insets.Left - Insets.Right - 16), Sizes[I].Height);
      if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      for J := 0 to Button.ComponentCount - 1 do
        if Button.Components[J] is TRibbonIconBinding then
        begin
          TRibbonIconBinding(Button.Components[J]).SetBounds(
            Insets.Left + (CellW - Insets.Left - Insets.Right - Side) / 2,
            Insets.Top + 10, Side, Side);
          if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
        end;
    end;
    FinishOpen(12 + FColumns * (CellW + 4) + 16,
      12 + ((FButtons.Count + FColumns - 1) div FColumns) *
        (CellH + 4) + 16);
  finally
    IconSizes.Free;
    Paddings.Free;
    Sizes.Free;
    Labels.Free;
  end;
end;

procedure TRibbonPopupService.FinishOpen(AWidth, AHeight: Single);
var
  Token: IRibbonPopupLifetime;
  Session: UInt64;
  First: TButton;
  FirstWatch: TRibbonStyleWatch;
  Button: TButton;
  Bounds: TRectF;
  MinimumHeight: Single;
begin
  Token := FLifetime;
  Session := Token.GetSession;
  if not PopupTargetsAvailable(Token) then Exit;
  if FStyleDirty or ((FStyleContext <> nil) and
     (FStyleContext.Revision <> FStyleRevision)) then
  begin
    FStyleDirty := True;
    Close;
    Exit;
  end;
  FViewport := TRibbonPopupViewport.Capture(FHost, FAnchor);
  if not FViewport.HasArea then Exit;
  MinimumHeight := 32;
  if FInputDensity = ridTouch then MinimumHeight := 44;
  Bounds := RibbonPopupScreenBounds(FViewport,
    TSizeF.Create(AWidth, AHeight), MinimumHeight);
  ApplyRibbonPopupBounds(FPopup, Bounds);
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  First := nil;
  for Button in FButtons do
    if Button.Enabled then
    begin
      First := Button;
      Break;
    end;
  FirstWatch := TRibbonStyleWatch.Create(First);
  try
    FHostWatch.Enabled := True;
    FPopup.IsOpen := True;
    if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      if not IsOpen then Exit;
      { Reparenting into the native window invalidates the pre-open style. }
      FPopup.ApplyStyleLookup;
      if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      if not IsOpen then Exit;
      { Opening can apply a native style and release an individual item.
      Focus assignment is final: application focus handlers can run here. }
    if FirstWatch.Control <> nil then FirstWatch.Control.SetFocus
    else FPopup.SetFocus;
  finally
    FirstWatch.Free;
  end;
end;

procedure TRibbonPopupService.QueueReturn(AHandler: TRibbonPopupSelectEvent;
  const AId: string; ARestoreFocus: Boolean);
var
  Token: IRibbonPopupLifetime;
  Session: UInt64;
  SenderObject: TObject;
  SelectedId: string;
  ExpectedFocus: Pointer;
begin
  Token := FLifetime;
  Session := Token.GetSession;
  SenderObject := Self;
  SelectedId := AId;
  ExpectedFocus := FocusIdentity(Token.GetHost);
  TThread.ForceQueue(nil,
    procedure
    var
      Anchor: TControl;
      Host: TCommonCustomForm;
    begin
      if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      { A host may be hidden after the popup closes and before this queued
        callback runs. The open-popup timer is no longer active then. }
      if not PopupTargetsAvailable(Token) then Exit;
      Anchor := Token.GetAnchor;
      Host := Token.GetHost;
      if ARestoreFocus and (Anchor <> nil) and (Host <> nil) then
        if not (csDestroying in Anchor.ComponentState) and
           not (csDestroying in Host.ComponentState) and Host.Visible and
           Host.Active then
          if FocusIdentity(Host) = ExpectedFocus then
            if Anchor.CanFocus and Anchor.AbsoluteEnabled and
               Anchor.Visible and Anchor.ParentedVisible then
              Anchor.SetFocus;
      if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
      if not PopupTargetsAvailable(Token) then Exit;
      if Assigned(AHandler) then AHandler(SenderObject, SelectedId);
      { No service, popup, anchor or sender access after the user callback. }
    end);
end;

procedure TRibbonPopupService.EntryClicked(Sender: TObject);
var
  Handler: TRibbonPopupSelectEvent;
  Id: string;
  Token: IRibbonPopupLifetime;
  Session: UInt64;
begin
  if not IsOpen or not (Sender is TButton) then Exit;
  if not TButton(Sender).Enabled or
     not RibbonActivationAllowed(TButton(Sender)) then Exit;
  Id := TButton(Sender).TagString;
  Handler := FOnSelect;
  FOnSelect := nil;
  Token := FLifetime;
  Session := Token.GetSession;
  FPopup.IsOpen := False;
  if not Token.IsAlive then Exit;
  if Token.GetSession <> Session then Exit;
  QueueReturn(Handler, Id, True);
end;

procedure TRibbonPopupService.PopupClosed(Sender: TObject);
begin
  if FDestroying then Exit;
  FHostWatch.Enabled := False;
  FOnSelect := nil;
  { Native outside-click dismissal must keep the destination control's focus.
    Only Escape and a committed selection explicitly request focus return. }
  { Keep the closed control tree. It is freed at the next Open, after the
    native callback stack has returned, or during service destruction. }
end;

procedure TRibbonPopupService.Close;
begin
  ClosePopup(False);
end;

procedure TRibbonPopupService.ClosePopup(ARestoreFocus: Boolean);
var
  Token: IRibbonPopupLifetime;
  Session: UInt64;
begin
  Token := FLifetime;
  if Token = nil then Exit;
  Token.Advance;
  Session := Token.GetSession;
  FOnSelect := nil;
  if FHostWatch <> nil then FHostWatch.Enabled := False;
  if FPopup <> nil then FPopup.IsOpen := False;
  if not Token.IsAlive or (Token.GetSession <> Session) then Exit;
  if ARestoreFocus then QueueReturn(nil, '', True);
end;

procedure TRibbonPopupService.HostPulse(Sender: TObject);
begin
  if not IsOpen then
  begin
    FHostWatch.Enabled := False;
    Exit;
  end;
  CheckHostGeometry;
end;

procedure TRibbonPopupService.CheckHostGeometry;
var
  Current: TRibbonPopupViewport;
begin
  if not IsOpen then Exit;
  if FStyleDirty or ((FStyleContext <> nil) and
     (FStyleContext.Revision <> FStyleRevision)) then
  begin
    FStyleDirty := True;
    Close;
    Exit;
  end;
  if not PopupTargetsAvailable(FLifetime) then
  begin
    Close;
    Exit;
  end;
  Current := TRibbonPopupViewport.Capture(FHost, FAnchor);
  if not Current.SameGeometry(FViewport) then Close;
end;

procedure TRibbonPopupService.FocusRelative(ASender: TObject; ADelta: Integer);
var
  Start, Index, Attempt: Integer;
  Button: TButton;
begin
  if FButtons.Count = 0 then Exit;
  Start := -1;
  if ASender is TButton then Start := FButtons.IndexOf(TButton(ASender));
  Index := Start;
  for Attempt := 1 to FButtons.Count do
  begin
    Index := (Index + ADelta) mod FButtons.Count;
    if Index < 0 then Inc(Index, FButtons.Count);
    Button := FButtons[Index];
    if Button.Enabled then
    begin
      Button.SetFocus;
      Exit;
    end;
  end;
end;

procedure TRibbonPopupService.PopupKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
var
  Delta: Integer;
begin
  if Sender is TControl then RibbonKeyboardInput(TControl(Sender));
  if (Key = vkEscape) or (Key = vkHardwareBack) then
  begin
    Key := 0;
    KeyChar := #0;
    ClosePopup(True);
    Exit;
  end;
  Delta := 0;
  case Key of
    vkUp: Delta := -Max(1, FColumns);
    vkDown: Delta := Max(1, FColumns);
    vkLeft: Delta := -1;
    vkRight: Delta := 1;
  end;
  if Delta <> 0 then
  begin
    Key := 0;
    KeyChar := #0;
    FocusRelative(Sender, Delta);
  end;
end;

end.
