unit CamART.Ribbon.PopupGeometry;

interface

uses
  System.Types,
  FMX.Controls,
  FMX.Forms;

type
  { All dimensions are FMX logical coordinates. SceneScale is a change token,
    never a second multiplier applied to the popup bounds. }
  TRibbonPopupViewport = record
    Origin: TPointF;
    Size: TSizeF;
    AnchorRect: TRectF;
    SceneScale: Single;
    class function Capture(AHost: TCommonCustomForm;
      AAnchor: TControl): TRibbonPopupViewport; static;
    function SameGeometry(const AOther: TRibbonPopupViewport): Boolean;
    function HasArea: Boolean;
  end;

function RibbonPopupScreenBounds(const AViewport: TRibbonPopupViewport;
  const ADesiredSize: TSizeF; const AMinimumHeight: Single): TRectF;
procedure ApplyRibbonPopupBounds(APopup: TPopup;
  const AScreenBounds: TRectF);

implementation

uses
  System.SysUtils,
  System.Math;

class function TRibbonPopupViewport.Capture(AHost: TCommonCustomForm;
  AAnchor: TControl): TRibbonPopupViewport;
begin
  if (AHost = nil) or (AAnchor = nil) then
    raise EArgumentNilException.Create('Popup geometry needs a host and anchor.');
  Result.Origin := AHost.ClientToScreen(PointF(0, 0));
  Result.Size := TSizeF.Create(Max(0, AHost.ClientWidth),
    Max(0, AHost.ClientHeight));
  Result.AnchorRect := AAnchor.AbsoluteRect;
  Result.SceneScale := 1;
  if AAnchor.Scene <> nil then
    Result.SceneScale := AAnchor.Scene.GetSceneScale;
end;

function TRibbonPopupViewport.SameGeometry(
  const AOther: TRibbonPopupViewport): Boolean;
begin
  Result := (Origin.X = AOther.Origin.X) and (Origin.Y = AOther.Origin.Y) and
    (Size.Width = AOther.Size.Width) and (Size.Height = AOther.Size.Height) and
    (AnchorRect.Left = AOther.AnchorRect.Left) and
    (AnchorRect.Top = AOther.AnchorRect.Top) and
    (AnchorRect.Right = AOther.AnchorRect.Right) and
    (AnchorRect.Bottom = AOther.AnchorRect.Bottom) and
    (SceneScale = AOther.SceneScale);
end;

function TRibbonPopupViewport.HasArea: Boolean;
begin
  Result := (Size.Width > 0) and (Size.Height > 0);
end;

procedure CheckFinite(const AValue: Single; const AName: string);
begin
  if IsNan(AValue) or IsInfinite(AValue) then
    raise EArgumentOutOfRangeException.Create(AName + ' must be finite.');
end;

function RibbonPopupScreenBounds(const AViewport: TRibbonPopupViewport;
  const ADesiredSize: TSizeF; const AMinimumHeight: Single): TRectF;
var
  W, H, X, Y, Below, Above, AvailableHeight: Single;
  PlaceBelow: Boolean;
begin
  CheckFinite(ADesiredSize.Width, 'Popup width');
  CheckFinite(ADesiredSize.Height, 'Popup height');
  CheckFinite(AMinimumHeight, 'Popup minimum height');
  CheckFinite(AViewport.Size.Width, 'Viewport width');
  CheckFinite(AViewport.Size.Height, 'Viewport height');
  CheckFinite(AViewport.Origin.X, 'Viewport X');
  CheckFinite(AViewport.Origin.Y, 'Viewport Y');
  CheckFinite(AViewport.AnchorRect.Left, 'Anchor left');
  CheckFinite(AViewport.AnchorRect.Top, 'Anchor top');
  CheckFinite(AViewport.AnchorRect.Right, 'Anchor right');
  CheckFinite(AViewport.AnchorRect.Bottom, 'Anchor bottom');
  if (ADesiredSize.Width < 0) or (ADesiredSize.Height < 0) or
     (AMinimumHeight < 0) or (AViewport.Size.Width < 0) or
     (AViewport.Size.Height < 0) then
    raise EArgumentOutOfRangeException.Create('Popup dimensions must be nonnegative.');
  if not AViewport.HasArea then Exit(RectF(0, 0, 0, 0));
  W := Min(AViewport.Size.Width, Max(1, ADesiredSize.Width));
  Above := Max(0, Min(AViewport.Size.Height, AViewport.AnchorRect.Top));
  Below := Max(0, AViewport.Size.Height -
    Max(0, Min(AViewport.Size.Height, AViewport.AnchorRect.Bottom)));
  PlaceBelow := (Below >= ADesiredSize.Height) or (Below >= Above);
  if PlaceBelow then AvailableHeight := Below else AvailableHeight := Above;
  { If neither side can hold even one usable row, use the host viewport and
    allow overlap with the anchor. Scroll preserves access in a tiny window. }
  if AvailableHeight < Min(AMinimumHeight, AViewport.Size.Height) then
    AvailableHeight := AViewport.Size.Height;
  H := Min(AvailableHeight, Max(1, ADesiredSize.Height));
  X := Max(0, Min(AViewport.Size.Width - W, AViewport.AnchorRect.Left));
  if PlaceBelow then Y := AViewport.AnchorRect.Bottom
  else Y := AViewport.AnchorRect.Top - H;
  Y := Max(0, Min(AViewport.Size.Height - H, Y));
  Result := RectF(AViewport.Origin.X + X, AViewport.Origin.Y + Y,
    AViewport.Origin.X + X + W, AViewport.Origin.Y + Y + H);
end;

procedure ApplyRibbonPopupBounds(APopup: TPopup;
  const AScreenBounds: TRectF);
begin
  if APopup = nil then raise EArgumentNilException.Create('Popup is required.');
  APopup.PlacementTarget := nil;
  APopup.Placement := TPlacement.Absolute;
  APopup.Width := AScreenBounds.Width;
  APopup.Height := AScreenBounds.Height;
  { Absolute placement takes both position and size from this rectangle. }
  APopup.PlacementRectangle.Rect := AScreenBounds;
end;

end.
