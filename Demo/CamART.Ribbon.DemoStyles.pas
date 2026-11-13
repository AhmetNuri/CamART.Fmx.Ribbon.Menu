unit CamART.Ribbon.DemoStyles;

interface

uses
  System.Classes,
  System.UITypes,
  FMX.Controls;

{ Test/demo StyleBooks, not the six product themes planned for Stage 5.
  Uses only FMX object trees and FMX's public style streaming API. }
function CreateRibbonDemoStyleBook(AOwner: TComponent;
  ABackground: TAlphaColor; AOmitContentPart: Boolean = False): TStyleBook;

implementation

uses
  System.SysUtils,
  FMX.Types,
  FMX.Layouts,
  FMX.Objects,
  FMX.Styles,
  CamART.Ribbon.Style;

function CreateRibbonDemoStyleBook(AOwner: TComponent;
  ABackground: TAlphaColor; AOmitContentPart: Boolean): TStyleBook;
var
  Container: TLayout;
  RibbonStyle, GroupStyle, Part: TFmxObject;
  Stream: TMemoryStream;
begin
  Result := nil;
  Container := TLayout.Create(nil);
  try
    RibbonStyle := CreateDefaultRibbonStyle;
    RibbonStyle.StyleName := RibbonRootStyleName;
    RibbonStyle.Parent := Container;
    Part := RibbonStyle.FindStyleResource('background');
    if Part is TRectangle then TRectangle(Part).Fill.Color := ABackground;
    if AOmitContentPart then
    begin
      Part := RibbonStyle.FindStyleResource('content');
      if Part <> nil then Part.StyleName := 'content_omitted_for_test';
    end;
    GroupStyle := CreateDefaultGroupStyle;
    GroupStyle.StyleName := RibbonGroupStyleName;
    GroupStyle.Parent := Container;
    Stream := TMemoryStream.Create;
    try
      TStyleStreaming.SaveToStream(Container, Stream);
      Stream.Position := 0;
      Result := TStyleBook.Create(AOwner);
      try
        Result.LoadFromStream(Stream);
      except
        FreeAndNil(Result);
        raise;
      end;
    finally
      Stream.Free;
    end;
  finally
    Container.Free;
  end;
end;

end.
