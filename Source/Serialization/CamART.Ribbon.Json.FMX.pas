unit CamART.Ribbon.Json.FMX;

{$B-}

interface

uses
  CamART.Ribbon.Control,
  CamART.Ribbon.Json;

type
  { Optional boundary adapter. Core and normal FMX runtime never use this
    unit; adding JSON persistence is an explicit application choice. }
  TRibbonJsonFMX = class sealed
  public
    { Returns nonfatal migration/optional-property diagnostics. A validation
      failure raises ERibbonJsonError before touching the live Ribbon.
      ERibbonConfigurationCommittedError means the new graph is active but
      native presentation or an application observer raised afterwards. }
    class function Load(ARibbon: TCamARTRibbon;
      const AText: string): string; overload; static;
    class function Load(ARibbon: TCamARTRibbon; const AText: string;
      const ALimits: TRibbonJsonLimits): string; overload; static;
    class function Save(ARibbon: TCamARTRibbon): string; static;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  FMX.Graphics,
  FMX.ImgList,
  CamART.Ribbon.Icons,
  CamART.Ribbon.Themes;

type
  TRibbonJsonRootWatch = class(TComponent)
  private
    FRoot: TCamARTRibbon;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateWatch(ARoot: TCamARTRibbon);
    property Root: TCamARTRibbon read FRoot;
  end;

  { Queries registered provider keys only. A JSON icon string is never
    interpreted as a file path, URL, method, or native class name. }
  TRibbonJsonIconProbe = class(TInterfacedObject, IRibbonJsonIconResolver)
  private
    FProvider: IRibbonIconProvider;
    FKnown: TDictionary<string, Boolean>;
  public
    constructor Create(const AProvider: IRibbonIconProvider);
    destructor Destroy; override;
    function HasIcon(const AKey: string): Boolean;
  end;

constructor TRibbonJsonRootWatch.CreateWatch(ARoot: TCamARTRibbon);
begin
  inherited Create(nil);
  FRoot := ARoot;
  if FRoot <> nil then TComponent(FRoot).FreeNotification(Self);
end;

procedure TRibbonJsonRootWatch.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FRoot) then FRoot := nil;
end;

constructor TRibbonJsonIconProbe.Create(const AProvider: IRibbonIconProvider);
begin
  inherited Create;
  FProvider := AProvider;
  FKnown := TDictionary<string, Boolean>.Create;
end;

destructor TRibbonJsonIconProbe.Destroy;
begin
  FKnown.Free;
  FProvider := nil;
  inherited;
end;

function TRibbonJsonIconProbe.HasIcon(const AKey: string): Boolean;
var
  Images: TCustomImageList;
  Index: Integer;
  Bitmap: TBitmap;
begin
  if AKey = '' then Exit(True);
  if FKnown.TryGetValue(AKey, Result) then Exit;
  Result := False;
  if FProvider <> nil then
  begin
    Images := nil;
    Index := -1;
    Result := FProvider.TryGetImage(AKey, Images, Index) and
      (Images <> nil) and (Index >= 0);
    if not Result then
    begin
      Bitmap := TBitmap.Create;
      try
        Result := FProvider.CopyBitmap(AKey, 16, 1, Bitmap) and
          (Bitmap.Width > 0) and (Bitmap.Height > 0);
      finally
        Bitmap.Free;
      end;
    end;
  end;
  FKnown.Add(AKey, Result);
end;

function ThemeFromKey(const AKey: string): TRibbonTheme;
begin
  if AKey = 'Office2007Blue' then Exit(rtOffice2007Blue);
  if AKey = 'Office2010Blue' then Exit(rtOffice2010Blue);
  if AKey = 'OfficeSilver' then Exit(rtOfficeSilver);
  if AKey = 'OfficeBlack' then Exit(rtOfficeBlack);
  if AKey = 'ModernLight' then Exit(rtModernLight);
  if AKey = 'ModernDark' then Exit(rtModernDark);
  raise EArgumentException.Create('Unknown Ribbon theme key: ' + AKey);
end;

function ThemeKey(const ATheme: TRibbonTheme): string;
begin
  case ATheme of
    rtOffice2007Blue: Result := 'Office2007Blue';
    rtOffice2010Blue: Result := 'Office2010Blue';
    rtOfficeSilver: Result := 'OfficeSilver';
    rtOfficeBlack: Result := 'OfficeBlack';
    rtModernLight: Result := 'ModernLight';
    rtModernDark: Result := 'ModernDark';
  else
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon theme.');
  end;
end;

function VisualSettings(const AValue: TRibbonJsonSettings): TRibbonConfigurationSettings;
begin
  Result.Theme := ThemeFromKey(AValue.Theme);
  Result.HasActiveTabId := AValue.HasActiveTabId;
  Result.ActiveTabId := AValue.ActiveTabId;
  Result.Collapsed := AValue.Collapsed;
  Result.QuickAccessVisible := AValue.QuickAccessVisible;
  Result.QuickAccessPosition := AValue.QuickAccessPosition;
  Result.ApplicationCaption := AValue.ApplicationCaption;
  Result.ApplicationButtonVisible := AValue.ApplicationButtonVisible;
  Result.ExpandedHeight := AValue.ExpandedHeight;
  Result.InputDensity := AValue.InputDensity;
  Result.ReduceMotion := AValue.ReduceMotion;
  Result.CompactCaption := AValue.CompactCaption;
end;

function JsonSettings(const AValue: TRibbonConfigurationSettings): TRibbonJsonSettings;
begin
  Result := TRibbonJsonSettings.Default;
  Result.Theme := ThemeKey(AValue.Theme);
  Result.HasActiveTabId := AValue.HasActiveTabId;
  Result.ActiveTabId := AValue.ActiveTabId;
  Result.Collapsed := AValue.Collapsed;
  Result.QuickAccessVisible := AValue.QuickAccessVisible;
  Result.QuickAccessPosition := AValue.QuickAccessPosition;
  Result.ApplicationCaption := AValue.ApplicationCaption;
  Result.ApplicationButtonVisible := AValue.ApplicationButtonVisible;
  Result.ExpandedHeight := AValue.ExpandedHeight;
  Result.InputDensity := AValue.InputDensity;
  Result.ReduceMotion := AValue.ReduceMotion;
  Result.CompactCaption := AValue.CompactCaption;
end;

function StyleSettings(const AValue: TRibbonJsonSettings): TRibbonStyleConfiguration;
begin
  { Absent style keys already carry their defaults in AValue. }
  Result := TRibbonStyleConfiguration.Default;
  if AValue.ThemeMode = 'manual' then Result.ThemeMode := rtmManual
  else if AValue.ThemeMode = 'auto' then Result.ThemeMode := rtmAuto
  else raise EArgumentException.Create('Unknown Ribbon theme mode key: ' + AValue.ThemeMode);
  Result.InheritFormNativeStyles := AValue.InheritFormNativeStyles;
  Result.Metrics := AValue.Metrics;
end;

function JsonSettingsWithStyle(const AValue: TRibbonConfigurationSettings;
  const AStyle: TRibbonStyleConfiguration): TRibbonJsonSettings;
begin
  Result := JsonSettings(AValue);
  if AStyle.ThemeMode = rtmManual then Result.ThemeMode := 'manual'
  else Result.ThemeMode := 'auto';
  Result.InheritFormNativeStyles := AStyle.InheritFormNativeStyles;
  Result.Metrics := AStyle.Metrics;
end;

procedure RequireRibbon(ARibbon: TCamARTRibbon);
begin
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    raise EInvalidOperation.Create('Ribbon JSON integration requires the FMX UI thread.');
  if ARibbon = nil then raise EArgumentNilException.Create('A Ribbon is required.');
  if csDestroying in ARibbon.ComponentState then
    raise EInvalidOperation.Create('The Ribbon is being destroyed.');
end;

class function TRibbonJsonFMX.Load(ARibbon: TCamARTRibbon;
  const AText: string): string;
begin
  Result := Load(ARibbon, AText, TRibbonJsonLimits.Default);
end;

class function TRibbonJsonFMX.Load(ARibbon: TCamARTRibbon; const AText: string;
  const ALimits: TRibbonJsonLimits): string;
var
  Document: TRibbonJsonDocument;
  Icons: IRibbonJsonIconResolver;
  Settings: TRibbonConfigurationSettings;
  Style: TRibbonStyleConfiguration;
  Watch: TRibbonJsonRootWatch;
begin
  RequireRibbon(ARibbon);
  Watch := TRibbonJsonRootWatch.CreateWatch(ARibbon);
  Document := nil;
  try
    Icons := TRibbonJsonIconProbe.Create(ARibbon.IconProvider);
    Document := TRibbonJsonCodec.Parse(AText, ARibbon.CommandResolver,
      Icons, ALimits);
    Settings := VisualSettings(Document.Settings);
    Style := StyleSettings(Document.Settings);
    Result := Document.Diagnostics.Text;
    if Watch.Root = nil then
      raise EInvalidOperation.Create('The Ribbon was destroyed by a configuration resolver.');
    Watch.Root.ApplyConfiguration(Document.Model, Document.QuickAccess,
      Document.ApplicationMenu, Settings, Style);
    { No Ribbon access after publication: OnActiveTabChanged may free it.
      The document now owns the old tabs and releases them in finally. }
  finally
    Document.Free;
    Watch.Free;
  end;
end;

class function TRibbonJsonFMX.Save(ARibbon: TCamARTRibbon): string;
begin
  RequireRibbon(ARibbon);
  Result := TRibbonJsonCodec.Export(ARibbon.Model, ARibbon.QuickAccess,
    ARibbon.ApplicationMenu, JsonSettingsWithStyle(
      ARibbon.CaptureConfigurationSettings, ARibbon.CaptureStyleConfiguration));
end;

end.
