unit CamART.Ribbon.SkLabels;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Skia,
  CamART.Ribbon.ItemViews,
  CamART.Ribbon.StyleScope;

type
  { UI-thread query used by sklabel views. A template is an independent
    snapshot of a TSkLabel's text appearance (TextSettings, StyledSettings and
    rich Words). The caller keeps ownership of the registered source label. }
  IRibbonSkLabelProvider = interface
    ['{ECA43332-8E0F-4F69-85D1-68DFCFB1B0C7}']
    function GetRevision: UInt64;
    function HasTemplate(const AKey: string): Boolean;
    { Copies the registered snapshot into ATarget. Returns False and leaves the
      target unchanged when the key is unknown. }
    function ApplyTemplate(const AKey: string; ATarget: TSkLabel): Boolean;
  end;

  IRibbonSkLabelRegistry = interface(IRibbonSkLabelProvider)
    ['{838A8D49-F2C6-41A3-9AF0-88D177DEB6F0}']
    procedure RegisterLabel(const AKey: string; ALabel: TSkLabel);
    procedure UnregisterLabel(const AKey: string);
    procedure Clear;
    function GetCount: Integer;
  end;

  TRibbonSkLabelRegistry = class(TInterfacedObject, IRibbonSkLabelProvider,
    IRibbonSkLabelRegistry)
  private
    FTemplates: TObjectDictionary<string, TSkLabel>;
    FRevision: UInt64;
    procedure Changed;
  public
    constructor Create;
    destructor Destroy; override;
    function GetRevision: UInt64;
    function HasTemplate(const AKey: string): Boolean;
    function ApplyTemplate(const AKey: string; ATarget: TSkLabel): Boolean;
    procedure RegisterLabel(const AKey: string; ALabel: TSkLabel);
    procedure UnregisterLabel(const AKey: string);
    procedure Clear;
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;

  { Optional view contract. The view factory hands its provider to any view
    that supports this interface; no concrete view class is switched on. }
  IRibbonSkLabelConsumer = interface
    ['{75F7DB8B-FEF0-4D1B-884E-17508D41EA59}']
    procedure SetSkLabelProvider(const AProvider: IRibbonSkLabelProvider);
  end;

  { Native TSkLabel whose default text appearance resolves through the Ribbon
    style scope (same label role as the classic TLabel view). }
  TRibbonSkLabelControl = class(TSkLabel, IRibbonStyleSource)
  protected
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
  end;

  TRibbonSkLabelItemView = class(TRibbonItemView, IRibbonSkLabelConsumer)
  private
    FLabel: TRibbonSkLabelControl;
    FMeasure: TSkLabel;
    FProvider: IRibbonSkLabelProvider;
    FDefaultStyled: TStyledSettings;
    FSignature: string;
    FResolved: Boolean;
    function CurrentSignature: string;
    function ContentSize: TSizeF;
  protected
    procedure DoApply; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSkLabelProvider(const AProvider: IRibbonSkLabelProvider);
    function DesiredSize: TSizeF; override;
    function MeasurementKey: string; override;
    { True when the item's TemplateKey resolved to a registered template. }
    property TemplateResolved: Boolean read FResolved;
    property LabelControl: TRibbonSkLabelControl read FLabel;
  end;

implementation

uses
  System.Math,
  CamART.Ribbon.Themes,
  CamART.Ribbon.StyleContext,
  CamART.Ribbon.Views;

type
  { Off-scene measuring twin; exposes the native AutoSize fit request. }
  TRibbonSkLabelMeasure = class(TSkLabel)
  public
    function FitSize: TSizeF;
  end;

function TRibbonSkLabelMeasure.FitSize: TSizeF;
begin
  SetSize(Width, Height);
  Result := TSizeF.Create(Width, Height);
end;

procedure RequireKey(const AKey: string);
begin
  if AKey = '' then
    raise EArgumentException.Create('A label template key must not be empty.');
end;

procedure CopyAppearance(ASource, ATarget: TSkLabel);
var
  I: Integer;
begin
  ATarget.BeginUpdate;
  try
    ATarget.StyledSettings := ASource.StyledSettings;
    ATarget.TextSettings := ASource.TextSettings;
    ATarget.Words := ASource.Words;
    { Word click handlers belong to the source form's lifetime. A Ribbon label
      is non-interactive, so a snapshot never retains foreign method pointers. }
    for I := 0 to ATarget.Words.Count - 1 do
      ATarget.Words[I].OnClick := nil;
  finally
    ATarget.EndUpdate;
  end;
end;

{ TRibbonSkLabelRegistry }

constructor TRibbonSkLabelRegistry.Create;
begin
  inherited Create;
  FRevision := 1;
  FTemplates := TObjectDictionary<string, TSkLabel>.Create([doOwnsValues]);
end;

destructor TRibbonSkLabelRegistry.Destroy;
begin
  FTemplates.Free;
  inherited;
end;

procedure TRibbonSkLabelRegistry.Changed;
begin
  Inc(FRevision);
end;

function TRibbonSkLabelRegistry.GetRevision: UInt64;
begin
  Result := FRevision;
end;

function TRibbonSkLabelRegistry.GetCount: Integer;
begin
  Result := FTemplates.Count;
end;

function TRibbonSkLabelRegistry.HasTemplate(const AKey: string): Boolean;
begin
  Result := (AKey <> '') and FTemplates.ContainsKey(AKey);
end;

function TRibbonSkLabelRegistry.ApplyTemplate(const AKey: string;
  ATarget: TSkLabel): Boolean;
var
  Template: TSkLabel;
begin
  if ATarget = nil then raise EArgumentNilException.Create('A target label is required.');
  Result := (AKey <> '') and FTemplates.TryGetValue(AKey, Template);
  if Result then CopyAppearance(Template, ATarget);
end;

procedure TRibbonSkLabelRegistry.RegisterLabel(const AKey: string;
  ALabel: TSkLabel);
var
  Owned: TSkLabel;
begin
  RequireKey(AKey);
  if ALabel = nil then raise EArgumentNilException.Create('A TSkLabel is required.');
  if csDestroying in ALabel.ComponentState then
    raise EArgumentException.Create('Cannot register a destroying TSkLabel.');
  Owned := TSkLabel.Create(nil);
  try
    Owned.AutoSize := False;
    CopyAppearance(ALabel, Owned);
    FTemplates.AddOrSetValue(AKey, Owned);
    Owned := nil;
  finally
    Owned.Free;
  end;
  Changed;
end;

procedure TRibbonSkLabelRegistry.UnregisterLabel(const AKey: string);
begin
  if not FTemplates.ContainsKey(AKey) then Exit;
  FTemplates.Remove(AKey);
  Changed;
end;

procedure TRibbonSkLabelRegistry.Clear;
begin
  if FTemplates.Count = 0 then Exit;
  FTemplates.Clear;
  Changed;
end;

{ TRibbonSkLabelControl }

function TRibbonSkLabelControl.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Result := Context.ResolveRibbonStyle(Self, rsrLabel, AClone)
  else
    Result := inherited GetStyleObject(AClone);
end;

function TRibbonSkLabelControl.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonSkLabelControl.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

{ TRibbonSkLabelItemView }

constructor TRibbonSkLabelItemView.Create(AOwner: TComponent);
begin
  inherited;
  FLabel := TRibbonSkLabelControl.Create(Self);
  FLabel.AutoSize := False;
  FLabel.CanFocus := False;
  FLabel.HitTest := False;
  FDefaultStyled := FLabel.StyledSettings;
  { Off-scene twin used only for intrinsic measurement. It receives the
    resolved settings of the visible label, so no style lookup is required. }
  FMeasure := TRibbonSkLabelMeasure.Create(nil);
  FMeasure.AutoSize := True;
  SetControl(FLabel);
end;

destructor TRibbonSkLabelItemView.Destroy;
begin
  FProvider := nil;
  FMeasure.Free;
  inherited;
end;

procedure TRibbonSkLabelItemView.SetSkLabelProvider(
  const AProvider: IRibbonSkLabelProvider);
begin
  if FProvider = AProvider then Exit;
  FProvider := AProvider;
  FSignature := '';
  if (Control <> nil) and (ItemId <> '') then Apply(FData);
end;

function TRibbonSkLabelItemView.CurrentSignature: string;
var
  Revision: UInt64;
begin
  Revision := 0;
  if FProvider <> nil then Revision := FProvider.GetRevision;
  Result := IntToStr(Length(FData.TemplateKey)) + ':' + FData.TemplateKey + ':' +
    UIntToStr(Revision) + ':' + FData.Caption;
end;

procedure TRibbonSkLabelItemView.DoApply;
var
  Signature: string;
begin
  Signature := CurrentSignature;
  { Apply runs on every Ribbon sync. Rebuild the Skia paragraph only when the
    caption, template key or template registry revision actually changed. }
  if Signature = FSignature then Exit;
  FLabel.BeginUpdate;
  try
    FLabel.Words.Clear;
    FLabel.TextSettings.Assign(nil);
    FLabel.StyledSettings := FDefaultStyled;
    FResolved := (FData.TemplateKey <> '') and (FProvider <> nil) and
      FProvider.ApplyTemplate(FData.TemplateKey, FLabel);
    { A style-only template (no words) presents the model caption. A rich
      template supplies its own words; a missing template falls back to the
      caption with the Ribbon label appearance. }
    if not FResolved or (FLabel.Text = '') then FLabel.Text := FData.Caption;
    { Vertical placement inside the item slot belongs to the Ribbon layout. }
    FLabel.TextSettings.VertAlign := TTextAlign.Center;
  finally
    FLabel.EndUpdate;
  end;
  FSignature := Signature;
end;

function TRibbonSkLabelItemView.ContentSize: TSizeF;
begin
  FLabel.ApplyStyleLookup;
  FMeasure.BeginUpdate;
  try
    FMeasure.StyledSettings := [];
    FMeasure.TextSettings := FLabel.ResultingTextSettings;
    FMeasure.Words := FLabel.Words;
  finally
    FMeasure.EndUpdate;
  end;
  if FMeasure.Text = '' then Exit(TSizeF.Create(0, 0));
  { AutoSize performs the native Skia paragraph fit at unbounded width. }
  Result := TRibbonSkLabelMeasure(FMeasure).FitSize;
  Result := TSizeF.Create(Ceil(Result.Width), Ceil(Result.Height));
end;

function TRibbonSkLabelItemView.DesiredSize: TSizeF;
var
  Size: TSizeF;
  Insets: TRectF;
begin
  Size := ContentSize;
  Insets := RibbonControlPadding(FLabel);
  Result := TSizeF.Create(
    Max(20, Size.Width + 8) + Insets.Left + Insets.Right,
    Max(24, Size.Height + 6) + Insets.Top + Insets.Bottom);
end;

function TRibbonSkLabelItemView.MeasurementKey: string;
begin
  Result := inherited MeasurementKey + ':sk:' + CurrentSignature;
end;

end.
