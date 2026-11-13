unit CamART.Ribbon.Icons;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.ImageList,
  System.Generics.Collections,
  FMX.Controls,
  FMX.Graphics,
  FMX.ImgList,
  FMX.Skia,
  FMX.Objects;

type
  { UI-thread queries. The destination belongs to the caller; no cache-owned
    bitmap escapes this interface. Image-list references are borrowed only for
    the immediate binding operation and are watched with FreeNotification. }
  IRibbonIconProvider = interface
    ['{9C8BC913-55B0-4302-8F3B-97240D6E70C0}']
    function GetRevision: UInt64;
    function TryGetImage(const AKey: string; out AImages: TCustomImageList;
      out AImageIndex: Integer): Boolean;
    function CopyBitmap(const AKey: string; const ALogicalSize, AScale: Single;
      ADestination: TBitmap): Boolean;
  end;

  IRibbonIconRegistry = interface(IRibbonIconProvider)
    ['{5DCE0D6B-8B37-4593-B651-C2E785751F17}']
    procedure SetImages(AImages: TCustomImageList);
    procedure BindKeyToIndex(const AKey: string; AImageIndex: Integer);
    procedure RegisterBitmap(const AKey: string; ABitmap: TBitmap);
    procedure RegisterPngStream(const AKey: string; AStream: TStream);
    procedure UnregisterIcon(const AKey: string);
    procedure Invalidate;
    procedure Clear;
    function GetCachedCount: Integer;
    function GetCachedBytes: Int64;
  end;

  { A separate interface preserves the existing provider/registry contracts.
    Registrations are snapshots; the caller retains its SVG control/brush. }
  IRibbonSvgIconRegistry = interface(IRibbonIconRegistry)
    ['{D628FA63-5715-47F5-B1DD-90307A5230A4}']
    procedure RegisterSvg(const AKey: string; ASvg: TSkSvg); overload;
    procedure RegisterSvg(const AKey: string; ASvg: TSkSvgBrush); overload;
    procedure RegisterSvgSource(const AKey, ASource: string);
  end;

  TRibbonIconCacheItem = class
  public
    Bitmap: TBitmap;
    LastUse: UInt64;
    Bytes: Int64;
    destructor Destroy; override;
  end;

  TRibbonIconRegistry = class(TInterfacedObject, IRibbonIconProvider,
    IRibbonIconRegistry, IRibbonSvgIconRegistry)
  private type
    TSvgSource = class(TSkSvgBrush)
    public
      Opacity: Single;
      Viewport: TSizeF;
    end;
  private
    FImages: TCustomImageList;
    FImageObserver: TComponent;
    FImageLink: TImageLink;
    FImageIndices: TDictionary<string, Integer>;
    FSources: TObjectDictionary<string, TBitmap>;
    FSvgSources: TObjectDictionary<string, TSvgSource>;
    FCache: TObjectDictionary<string, TRibbonIconCacheItem>;
    FRevision: UInt64;
    FClock: UInt64;
    FBytes: Int64;
    FMaxEntries: Integer;
    FMaxBytes: Int64;
    procedure ImageListRemoved(AComponent: TComponent);
    procedure ImagesChanged(Sender: TObject);
    procedure TrimCache;
    function CacheKey(const AKey: string; ASize, AScale: Single): string;
    function RenderBitmap(ASource: TBitmap; APixels: Integer): TBitmap;
    function RenderSvg(ASource: TSvgSource; ALogicalSize: Single;
      APixels: Integer): TBitmap;
    procedure RegisterSvgCopy(const AKey: string; ASvg: TSkSvgBrush;
      AOpacity: Single; const AViewport: TSizeF);
  public
    constructor Create(AMaxEntries: Integer = 64;
      AMaxBytes: Int64 = 8388608);
    destructor Destroy; override;
    function GetRevision: UInt64;
    function TryGetImage(const AKey: string; out AImages: TCustomImageList;
      out AImageIndex: Integer): Boolean;
    function CopyBitmap(const AKey: string; const ALogicalSize, AScale: Single;
      ADestination: TBitmap): Boolean;
    procedure SetImages(AImages: TCustomImageList);
    procedure BindKeyToIndex(const AKey: string; AImageIndex: Integer);
    procedure RegisterBitmap(const AKey: string; ABitmap: TBitmap);
    { Consumes a PNG from the current position of a seekable stream. The
      caller retains the stream; decoding happens here, never while painting. }
    procedure RegisterPngStream(const AKey: string; AStream: TStream);
    procedure RegisterSvg(const AKey: string; ASvg: TSkSvg); overload;
    procedure RegisterSvg(const AKey: string; ASvg: TSkSvgBrush); overload;
    procedure RegisterSvgSource(const AKey, ASource: string);
    procedure UnregisterIcon(const AKey: string);
    procedure Invalidate;
    procedure Clear;
    function GetCachedCount: Integer;
    function GetCachedBytes: Int64;
    property CachedCount: Integer read GetCachedCount;
    property CachedBytes: Int64 read GetCachedBytes;
  end;

  TRibbonIconBinding = class(TComponent)
  private
    FParent: TControl;
    FGlyph: TGlyph;
    FImage: TImage;
    FObservedImages: TCustomImageList;
    FProvider: IRibbonIconProvider;
    FKey: string;
    FLogicalSize: Single;
    FScale: Single;
    FRevision: UInt64;
    FVisible: Boolean;
    FValid: Boolean;
    FHasIcon: Boolean;
    FUsingGlyph: Boolean;
    FDestroying: Boolean;
    FOnChanged: TNotifyEvent;
    procedure SetProvider(const AValue: IRibbonIconProvider);
    procedure SetVisible(const AValue: Boolean);
    procedure UpdateVisibility;
    procedure WatchImages(AImages: TCustomImageList);
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent; AParent: TControl;
      const AProvider: IRibbonIconProvider); reintroduce;
    destructor Destroy; override;
    function SetIcon(const AKey: string; const ALogicalSize: Single = 16;
      const AScale: Single = 1): Boolean;
    procedure SetBounds(const X, Y, W, H: Single);
    property Provider: IRibbonIconProvider read FProvider write SetProvider;
    property Visible: Boolean read FVisible write SetVisible;
    property HasIcon: Boolean read FHasIcon;
    { Raised after a resolved icon is gained, lost or changes native route.
      The callback observes final state and may release this binding. }
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  System.Math,
  System.Skia,
  System.UITypes,
  FMX.Types;

type
  TRibbonImageListObserver = class(TComponent)
  private
    FRegistry: TRibbonIconRegistry;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor CreateObserver(ARegistry: TRibbonIconRegistry);
  end;

procedure RequireKey(const AKey: string);
begin
  if AKey = '' then
    raise EArgumentException.Create('An icon key must not be empty.');
end;

function RasterPixels(ALogicalSize, AScale: Single): Integer;
var
  Pixels: Double;
begin
  if IsNan(ALogicalSize) or IsInfinite(ALogicalSize) or
     (ALogicalSize <= 0) or IsNan(AScale) or IsInfinite(AScale) or
     (AScale <= 0) then
    raise EArgumentException.Create('Icon size and scale must be finite and positive.');
  Pixels := Double(ALogicalSize) * Double(AScale);
  { A documented raster-icon limit, independent from the LRU byte budget. }
  if Pixels > 4096 then
    raise EArgumentOutOfRangeException.Create('An icon raster must not exceed 4096 pixels.');
  Result := Max(1, Ceil(Pixels));
end;

constructor TRibbonImageListObserver.CreateObserver(ARegistry: TRibbonIconRegistry);
begin
  inherited Create(nil);
  FRegistry := ARegistry;
end;

procedure TRibbonImageListObserver.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if Operation = opRemove then FRegistry.ImageListRemoved(AComponent);
  inherited;
end;

destructor TRibbonIconCacheItem.Destroy;
begin
  Bitmap.Free;
  inherited;
end;

constructor TRibbonIconRegistry.Create(AMaxEntries: Integer; AMaxBytes: Int64);
begin
  inherited Create;
  if (AMaxEntries <= 0) or (AMaxBytes <= 0) then
    raise EArgumentException.Create('Icon cache entry and byte limits must be positive.');
  FMaxEntries := AMaxEntries;
  FMaxBytes := AMaxBytes;
  FRevision := 1;
  FImageIndices := TDictionary<string, Integer>.Create;
  FSources := TObjectDictionary<string, TBitmap>.Create([doOwnsValues]);
  FSvgSources := TObjectDictionary<string, TSvgSource>.Create([doOwnsValues]);
  FCache := TObjectDictionary<string, TRibbonIconCacheItem>.Create([doOwnsValues]);
  FImageObserver := TRibbonImageListObserver.CreateObserver(Self);
  FImageLink := TImageLink.Create;
  FImageLink.OnChange := ImagesChanged;
end;

destructor TRibbonIconRegistry.Destroy;
begin
  if FImages <> nil then FImages.RemoveFreeNotification(FImageObserver);
  if FImageLink <> nil then FImageLink.OnChange := nil;
  FImageLink.Free;
  FImageObserver.Free;
  FCache.Free;
  FSvgSources.Free;
  FSources.Free;
  FImageIndices.Free;
  inherited;
end;

procedure TRibbonIconRegistry.ImageListRemoved(AComponent: TComponent);
begin
  if AComponent = FImages then
  begin
    FImages := nil;
    Invalidate;
  end;
end;

procedure TRibbonIconRegistry.ImagesChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TRibbonIconRegistry.SetImages(AImages: TCustomImageList);
begin
  if FImages = AImages then Exit;
  if AImages <> nil then
    if csDestroying in AImages.ComponentState then
      raise EArgumentException.Create('Cannot bind a destroying image list.');
  if FImages <> nil then FImages.RemoveFreeNotification(FImageObserver);
  FImages := AImages;
  if FImages <> nil then FImages.FreeNotification(FImageObserver);
  FImageLink.Images := FImages;
  Invalidate;
end;

procedure TRibbonIconRegistry.BindKeyToIndex(const AKey: string; AImageIndex: Integer);
begin
  RequireKey(AKey);
  if AImageIndex < 0 then
    raise EArgumentOutOfRangeException.Create('ImageIndex must not be negative.');
  FImageIndices.AddOrSetValue(AKey, AImageIndex);
  Invalidate;
end;

procedure TRibbonIconRegistry.RegisterBitmap(const AKey: string; ABitmap: TBitmap);
var
  Owned: TBitmap;
begin
  RequireKey(AKey);
  if ABitmap = nil then raise EArgumentNilException.Create('An icon bitmap is required.');
  if ABitmap.IsEmpty then raise EArgumentException.Create('An icon bitmap must not be empty.');
  Owned := TBitmap.Create;
  try
    Owned.Assign(ABitmap);
    FSources.AddOrSetValue(AKey, Owned);
    Owned := nil;
  finally
    Owned.Free;
  end;
  FSvgSources.Remove(AKey);
  Invalidate;
end;

procedure TRibbonIconRegistry.RegisterSvgCopy(const AKey: string;
  ASvg: TSkSvgBrush; AOpacity: Single; const AViewport: TSizeF);
var
  Owned: TSvgSource;
begin
  RequireKey(AKey);
  if ASvg = nil then raise EArgumentNilException.Create('An SVG brush is required.');
  if Trim(string(ASvg.Source)) = '' then
    raise EArgumentException.Create('An SVG source must not be empty.');
  Owned := TSvgSource.Create;
  try
    { Assign shares the mutable Skia DOM. Copy the published settings instead
      so rendering this snapshot never changes the caller's document. }
    Owned.Source := ASvg.Source;
    Owned.OverrideColor := ASvg.OverrideColor;
    Owned.GrayScale := ASvg.GrayScale;
    Owned.WrapMode := ASvg.WrapMode;
    Owned.Opacity := AOpacity;
    Owned.Viewport := AViewport;
    if Owned.DOM = nil then
      raise EArgumentException.Create('The supplied icon source is not a valid SVG document.');
    FSvgSources.AddOrSetValue(AKey, Owned);
    Owned := nil;
  finally
    Owned.Free;
  end;
  FSources.Remove(AKey);
  Invalidate;
end;

procedure TRibbonIconRegistry.RegisterSvg(const AKey: string; ASvg: TSkSvg);
begin
  RequireKey(AKey);
  if ASvg = nil then raise EArgumentNilException.Create('An SVG control is required.');
  if csDestroying in ASvg.ComponentState then
    raise EArgumentException.Create('Cannot register a destroying SVG control.');
  RegisterSvgCopy(AKey, ASvg.Svg, ASvg.Opacity, TSizeF.Create(ASvg.Width, ASvg.Height));
end;

procedure TRibbonIconRegistry.RegisterSvg(const AKey: string; ASvg: TSkSvgBrush);
begin
  RegisterSvgCopy(AKey, ASvg, 1, TSizeF.Create(0, 0));
end;

procedure TRibbonIconRegistry.RegisterSvgSource(const AKey, ASource: string);
var
  Svg: TSkSvgBrush;
begin
  Svg := TSkSvgBrush.Create;
  try
    Svg.Source := TSkSvgSource(ASource);
    RegisterSvg(AKey, Svg);
  finally
    Svg.Free;
  end;
end;

procedure TRibbonIconRegistry.RegisterPngStream(const AKey: string; AStream: TStream);
const
  PngSignature: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
  Signature: array[0..7] of Byte;
  Start: Int64;
  I: Integer;
  Bitmap: TBitmap;
begin
  RequireKey(AKey);
  if AStream = nil then raise EArgumentNilException.Create('A PNG stream is required.');
  Start := AStream.Position;
  AStream.ReadBuffer(Signature, SizeOf(Signature));
  AStream.Position := Start;
  for I := Low(Signature) to High(Signature) do
    if Signature[I] <> PngSignature[I] then
      raise EArgumentException.Create('The supplied icon stream is not PNG.');
  Bitmap := TBitmap.Create;
  try
    Bitmap.LoadFromStream(AStream);
    RegisterBitmap(AKey, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TRibbonIconRegistry.UnregisterIcon(const AKey: string);
begin
  FImageIndices.Remove(AKey);
  FSources.Remove(AKey);
  FSvgSources.Remove(AKey);
  Invalidate;
end;

procedure TRibbonIconRegistry.Invalidate;
begin
  FCache.Clear;
  FBytes := 0;
  if FRevision = High(UInt64) then FRevision := 1 else Inc(FRevision);
end;

procedure TRibbonIconRegistry.Clear;
begin
  SetImages(nil);
  FImageIndices.Clear;
  FSources.Clear;
  FSvgSources.Clear;
  Invalidate;
end;

function TRibbonIconRegistry.GetRevision: UInt64;
begin
  Result := FRevision;
end;

function TRibbonIconRegistry.GetCachedCount: Integer;
begin
  Result := FCache.Count;
end;

function TRibbonIconRegistry.GetCachedBytes: Int64;
begin
  Result := FBytes;
end;

function TRibbonIconRegistry.TryGetImage(const AKey: string;
  out AImages: TCustomImageList; out AImageIndex: Integer): Boolean;
var
  Index: Integer;
begin
  AImages := nil;
  AImageIndex := -1;
  Result := False;
  if FImages = nil then Exit;
  if csDestroying in FImages.ComponentState then Exit;
  if not FImageIndices.TryGetValue(AKey, Index) then Exit;
  if Index >= FImages.Count then Exit;
  AImages := FImages;
  AImageIndex := Index;
  Result := True;
end;

function TRibbonIconRegistry.CacheKey(const AKey: string;
  ASize, AScale: Single): string;
var
  SizeBits, ScaleBits: Cardinal;
begin
  Move(ASize, SizeBits, SizeOf(SizeBits));
  Move(AScale, ScaleBits, SizeOf(ScaleBits));
  Result := IntToStr(Length(AKey)) + ':' + AKey + ':' +
    IntToHex(SizeBits, 8) + ':' + IntToHex(ScaleBits, 8) + ':' +
    UIntToStr(FRevision);
end;

function TRibbonIconRegistry.RenderBitmap(ASource: TBitmap;
  APixels: Integer): TBitmap;
var
  Scale, W, H: Single;
begin
  Result := TBitmap.Create(APixels, APixels);
  try
    Result.Clear(TAlphaColor(0));
    Scale := Min(APixels / ASource.Width, APixels / ASource.Height);
    W := ASource.Width * Scale;
    H := ASource.Height * Scale;
    if not Result.Canvas.BeginScene then
      raise EInvalidOperation.Create('The FMX icon canvas is unavailable.');
    try
      Result.Canvas.DrawBitmap(ASource,
        RectF(0, 0, ASource.Width, ASource.Height),
        RectF((APixels - W) / 2, (APixels - H) / 2,
          (APixels + W) / 2, (APixels + H) / 2), 1);
    finally
      Result.Canvas.EndScene;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TRibbonIconRegistry.RenderSvg(ASource: TSvgSource;
  ALogicalSize: Single; APixels: Integer): TBitmap;
var
  W, H, Scale: Single;
begin
  W := ASource.Viewport.Width;
  H := ASource.Viewport.Height;
  if (W <= 0) or (H <= 0) then
  begin
    W := ALogicalSize;
    H := ALogicalSize;
  end;
  Scale := APixels / Max(W, H);
  Result := TBitmap.Create(APixels, APixels);
  try
    Result.SkiaDraw(
      procedure(const ACanvas: ISkCanvas)
      begin
        ACanvas.Translate((APixels - W * Scale) / 2,
          (APixels - H * Scale) / 2);
        ACanvas.Scale(Scale, Scale);
        ASource.Render(ACanvas, RectF(0, 0, W, H), ASource.Opacity);
      end);
  except
    Result.Free;
    raise;
  end;
end;

procedure TRibbonIconRegistry.TrimCache;
var
  Pair: TPair<string, TRibbonIconCacheItem>;
  Oldest: TRibbonIconCacheItem;
  Key: string;
begin
  while (FCache.Count > FMaxEntries) or (FBytes > FMaxBytes) do
  begin
    Oldest := nil;
    Key := '';
    for Pair in FCache do
      if (Oldest = nil) or (Pair.Value.LastUse < Oldest.LastUse) then
      begin
        Oldest := Pair.Value;
        Key := Pair.Key;
      end;
    if Oldest = nil then Exit;
    Dec(FBytes, Oldest.Bytes);
    FCache.Remove(Key);
  end;
end;

function TRibbonIconRegistry.CopyBitmap(const AKey: string;
  const ALogicalSize, AScale: Single; ADestination: TBitmap): Boolean;
var
  Source, Rendered: TBitmap;
  SvgSource: TSvgSource;
  Entry: TRibbonIconCacheItem;
  Key: string;
  Pixels: Integer;
begin
  if ADestination = nil then
    raise EArgumentNilException.Create('An owned bitmap destination is required.');
  Pixels := RasterPixels(ALogicalSize, AScale);
  Result := FSources.TryGetValue(AKey, Source);
  SvgSource := nil;
  if not Result then Result := FSvgSources.TryGetValue(AKey, SvgSource);
  if not Result then
  begin
    ADestination.SetSize(0, 0);
    Exit;
  end;
  if FClock = High(UInt64) then
  begin
    FCache.Clear;
    FBytes := 0;
    FClock := 0;
  end;
  Inc(FClock);
  Key := CacheKey(AKey, ALogicalSize, AScale);
  if FCache.TryGetValue(Key, Entry) then
  begin
    Entry.LastUse := FClock;
    ADestination.Assign(Entry.Bitmap);
    Exit;
  end;
  if SvgSource <> nil then
    Rendered := RenderSvg(SvgSource, ALogicalSize, Pixels)
  else
    Rendered := RenderBitmap(Source, Pixels);
  try
    ADestination.Assign(Rendered);
    if Int64(Pixels) * Pixels * 4 <= FMaxBytes then
    begin
      Entry := TRibbonIconCacheItem.Create;
      try
        Entry.Bytes := Int64(Pixels) * Pixels * 4;
        Entry.LastUse := FClock;
        Entry.Bitmap := Rendered;
        Rendered := nil;
        FCache.Add(Key, Entry);
        Inc(FBytes, Entry.Bytes);
        Entry := nil;
      finally
        Entry.Free;
      end;
      TrimCache;
    end;
  finally
    Rendered.Free;
  end;
end;

constructor TRibbonIconBinding.Create(AOwner: TComponent; AParent: TControl;
  const AProvider: IRibbonIconProvider);
begin
  inherited Create(AOwner);
  if AParent = nil then raise EArgumentNilException.Create('An icon parent is required.');
  FParent := AParent;
  TComponent(FParent).FreeNotification(Self);
  FLogicalSize := 16;
  FScale := 1;
  FVisible := True;
  FProvider := AProvider;
  FGlyph := TGlyph.Create(Self);
  FGlyph.Parent := FParent;
  FGlyph.Stored := False;
  FGlyph.HitTest := False;
  FGlyph.AutoHide := False;
  { Native BestSize chooses a non-distorted rectangle for the image list. }
  FGlyph.Stretch := False;
  FGlyph.Visible := False;
  FImage := TImage.Create(Self);
  FImage.Parent := FParent;
  FImage.Stored := False;
  FImage.HitTest := False;
  FImage.WrapMode := TImageWrapMode.Fit;
  FImage.Visible := False;
end;

destructor TRibbonIconBinding.Destroy;
begin
  FDestroying := True;
  FOnChanged := nil;
  WatchImages(nil);
  if FParent <> nil then TComponent(FParent).RemoveFreeNotification(Self);
  FreeAndNil(FGlyph);
  FreeAndNil(FImage);
  FProvider := nil;
  inherited;
end;

procedure TRibbonIconBinding.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FParent then FParent := nil;
    if AComponent = FGlyph then FGlyph := nil;
    if AComponent = FImage then FImage := nil;
    if AComponent = FObservedImages then
    begin
      FObservedImages := nil;
      FValid := False;
      if not FDestroying and (FParent <> nil) and
         not (csDestroying in FParent.ComponentState) then
        SetIcon(FKey, FLogicalSize, FScale);
    end;
  end;
  { SetIcon can deliver OnChanged; do not access Self after that callback. }
end;

procedure TRibbonIconBinding.WatchImages(AImages: TCustomImageList);
begin
  if FObservedImages = AImages then Exit;
  if FObservedImages <> nil then FObservedImages.RemoveFreeNotification(Self);
  FObservedImages := AImages;
  if FObservedImages <> nil then FObservedImages.FreeNotification(Self);
end;

procedure TRibbonIconBinding.SetProvider(const AValue: IRibbonIconProvider);
begin
  if FProvider = AValue then Exit;
  FProvider := AValue;
  FValid := False;
  SetIcon(FKey, FLogicalSize, FScale);
end;

function TRibbonIconBinding.SetIcon(const AKey: string;
  const ALogicalSize, AScale: Single): Boolean;
var
  Revision: UInt64;
  Images: TCustomImageList;
  Index: Integer;
  PreviousHasIcon, PreviousUsingGlyph: Boolean;
  Handler: TNotifyEvent;
begin
  RasterPixels(ALogicalSize, AScale);
  Revision := 0;
  if FProvider <> nil then Revision := FProvider.GetRevision;
  if FValid and (FKey = AKey) and (FLogicalSize = ALogicalSize) and
     (FScale = AScale) and (FRevision = Revision) then Exit(FHasIcon);
  PreviousHasIcon := FHasIcon;
  PreviousUsingGlyph := FUsingGlyph;
  FValid := False;
  FKey := AKey;
  FLogicalSize := ALogicalSize;
  FScale := AScale;
  FRevision := Revision;
  FHasIcon := False;
  FUsingGlyph := False;
  WatchImages(nil);
  if FGlyph <> nil then
  begin
    FGlyph.Images := nil;
    FGlyph.ImageIndex := -1;
  end;
  if FImage <> nil then FImage.Bitmap.SetSize(0, 0);
  if (FProvider <> nil) and (AKey <> '') and
     (FGlyph <> nil) and (FImage <> nil) then
  begin
    if FProvider.TryGetImage(AKey, Images, Index) then
    begin
      WatchImages(Images);
      FGlyph.Images := Images;
      FGlyph.ImageIndex := Index;
      FUsingGlyph := True;
      FHasIcon := True;
    end
    else
      FHasIcon := FProvider.CopyBitmap(AKey, ALogicalSize, AScale, FImage.Bitmap);
  end;
  UpdateVisibility;
  FValid := True;
  Result := FHasIcon;
  if not FDestroying and (FParent <> nil) and
     not (csDestroying in FParent.ComponentState) and
     ((PreviousHasIcon <> FHasIcon) or
      (PreviousUsingGlyph <> FUsingGlyph)) then
  begin
    Handler := FOnChanged;
    if Assigned(Handler) then Handler(Self);
    { No binding or visual access after the external callback. }
  end;
end;

procedure TRibbonIconBinding.SetBounds(const X, Y, W, H: Single);
begin
  if FGlyph <> nil then
  begin
    FGlyph.SetBounds(X, Y, W, H);
    FGlyph.BringToFront;
  end;
  if FImage <> nil then
  begin
    FImage.SetBounds(X, Y, W, H);
    FImage.BringToFront;
  end;
end;

procedure TRibbonIconBinding.SetVisible(const AValue: Boolean);
begin
  FVisible := AValue;
  UpdateVisibility;
end;

procedure TRibbonIconBinding.UpdateVisibility;
begin
  if FGlyph <> nil then FGlyph.Visible := FVisible and FHasIcon and FUsingGlyph;
  if FImage <> nil then FImage.Visible := FVisible and FHasIcon and not FUsingGlyph;
end;

end.
