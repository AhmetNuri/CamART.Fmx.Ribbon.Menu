unit CamART.Ribbon.DemoIcons;

interface

uses
  CamART.Ribbon.Icons;

{ Original geometric demo icons, generated once with the FMX bitmap canvas.
  No resource DLL, downloaded asset, user file or platform API is involved. }
procedure RegisterRibbonDemoIcons(const ARegistry: IRibbonIconRegistry);
procedure RegisterRibbonDemoSvgIcons(const ARegistry: IRibbonSvgIconRegistry);

implementation

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Skia,
  FMX.Graphics;

procedure AddIcon(const ARegistry: IRibbonIconRegistry; const AKey: string;
  AShape: Integer; AColor: TAlphaColor);
var
  Bitmap: TBitmap;
  Canvas: TCanvas;
  X, Y: Integer;

  procedure Box(L, T, R, B: Single; Color: TAlphaColor);
  begin
    Canvas.Fill.Color := Color;
    Canvas.FillRect(RectF(L, T, R, B), 0, 0, [], 1);
  end;

  procedure Line(X1, Y1, X2, Y2: Single; Color: TAlphaColor; Thickness: Single = 4);
  begin
    Canvas.Stroke.Color := Color;
    Canvas.Stroke.Thickness := Thickness;
    Canvas.DrawLine(PointF(X1, Y1), PointF(X2, Y2), 1);
  end;

begin
  Bitmap := TBitmap.Create(64, 64);
  try
    Canvas := Bitmap.Canvas;
    if not Canvas.BeginScene then
      raise Exception.Create('The native FMX demo icon canvas is unavailable.');
    try
      Canvas.Clear(0);
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Stroke.Kind := TBrushKind.Solid;
      case AShape of
        0: { document }
          begin
            Box(14, 7, 49, 57, AColor);
            Box(22, 20, 41, 24, $FFFFFFFF);
            Box(22, 30, 41, 34, $FFFFFFFF);
            Box(22, 40, 36, 44, $FFFFFFFF);
          end;
        1: { copy }
          begin
            Box(9, 8, 40, 47, $FFB7CDE8);
            Box(22, 20, 54, 58, AColor);
            Box(29, 29, 46, 33, $FFFFFFFF);
            Box(29, 39, 46, 43, $FFFFFFFF);
          end;
        2: { clipboard }
          begin
            Box(13, 13, 51, 57, AColor);
            Box(23, 6, 41, 20, $FF52647D);
            Box(21, 28, 43, 32, $FFFFFFFF);
            Box(21, 39, 43, 43, $FFFFFFFF);
          end;
        3: { save }
          begin
            Box(9, 8, 55, 57, AColor);
            Box(19, 8, 43, 27, $FFDDE9F6);
            Box(35, 10, 40, 23, $FF354A65);
            Box(18, 35, 46, 57, $FFFFFFFF);
            Box(23, 42, 41, 46, $FFB7CDE8);
          end;
        4: { folder }
          begin
            Box(7, 17, 30, 29, $FFE5AB35);
            Box(7, 24, 57, 53, AColor);
            Box(12, 30, 52, 35, $FFFFDF84);
          end;
        5: { export arrow }
          begin
            Box(8, 16, 31, 55, $FFB7CDE8);
            Line(24, 32, 55, 32, AColor, 6);
            Line(43, 20, 55, 32, AColor, 6);
            Line(43, 44, 55, 32, AColor, 6);
          end;
        6: { check }
          begin
            Box(8, 9, 56, 57, AColor);
            Line(18, 33, 28, 43, $FFFFFFFF, 6);
            Line(28, 43, 47, 23, $FFFFFFFF, 6);
          end;
        7: { bold / font }
          begin
            Line(16, 54, 31, 10, AColor, 6);
            Line(31, 10, 49, 54, AColor, 6);
            Line(22, 38, 42, 38, AColor, 5);
          end;
        8: { gallery grid }
          for Y := 0 to 2 do
            for X := 0 to 2 do
              Box(7 + X * 18, 7 + Y * 18, 20 + X * 18, 20 + Y * 18, AColor);
        9: { progress }
          begin
            Box(5, 22, 59, 43, $FFD4DDE8);
            Box(9, 26, 43, 39, AColor);
          end;
        10: { style card }
          begin
            Box(7, 8, 57, 56, $FFF0F3F7);
            Box(7, 8, 57, 23, AColor);
            Box(14, 30, 49, 34, $FF8493A8);
            Box(14, 40, 40, 44, $FFB8C3D1);
          end;
      end;
    finally
      Canvas.EndScene;
    end;
    ARegistry.RegisterBitmap(AKey, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure RegisterRibbonDemoIcons(const ARegistry: IRibbonIconRegistry);
begin
  if ARegistry = nil then raise EArgumentNilException.Create('An icon registry is required.');
  AddIcon(ARegistry, 'new', 0, $FF3979BF);
  AddIcon(ARegistry, 'copy', 1, $FF3E76B9);
  AddIcon(ARegistry, 'paste', 2, $FF3A88B5);
  AddIcon(ARegistry, 'save', 3, $FF3574BC);
  AddIcon(ARegistry, 'open', 4, $FFE6B446);
  AddIcon(ARegistry, 'export', 5, $FF4078BA);
  AddIcon(ARegistry, 'check', 6, $FF3A9170);
  AddIcon(ARegistry, 'bold', 7, $FF42546B);
  AddIcon(ARegistry, 'gallery', 8, $FF7867B0);
  AddIcon(ARegistry, 'progress', 9, $FF3A9170);
  AddIcon(ARegistry, 'style.blue', 10, $FF3979BF);
  AddIcon(ARegistry, 'style.green', 10, $FF3A9170);
  AddIcon(ARegistry, 'style.gold', 10, $FFD3A246);
  AddIcon(ARegistry, 'style.plum', 10, $FF8D68A8);
  AddIcon(ARegistry, 'style.slate', 10, $FF65788E);
  AddIcon(ARegistry, 'style.coral', 10, $FFCD7461);
end;

procedure RegisterRibbonDemoSvgIcons(const ARegistry: IRibbonSvgIconRegistry);
const
  DocumentSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    '<defs><linearGradient id="paper" x2="0" y2="1">' +
    '<stop stop-color="#3989d5"/><stop offset="1" stop-color="#2353a0"/>' +
    '</linearGradient></defs><path fill="url(#paper)" d="M6 2h13l7 7v21H6z"/>' +
    '<path fill="#90d5f6" d="M19 2v7h7z"/>' +
    '<path stroke="#fff" stroke-width="2" d="M10 14h12M10 19h12M10 24h8"/></svg>';
var
  Svg: TSkSvg;
begin
  if ARegistry = nil then raise EArgumentNilException.Create('An SVG registry is required.');
  Svg := TSkSvg.Create(nil);
  try
    Svg.SetBounds(0, 0, 32, 32);
    Svg.Svg.Source := DocumentSvg;
    ARegistry.RegisterSvg('svg.document', Svg);
    Svg.Svg.OverrideColor := TAlphaColor($FF2C9971);
    ARegistry.RegisterSvg('svg.green', Svg);
    Svg.Svg.OverrideColor := TAlphaColors.Null;
    Svg.Svg.GrayScale := True;
    ARegistry.RegisterSvg('svg.gray', Svg);
  finally
    Svg.Free; // All three registrations retain independent vector snapshots.
  end;
end;

end.
