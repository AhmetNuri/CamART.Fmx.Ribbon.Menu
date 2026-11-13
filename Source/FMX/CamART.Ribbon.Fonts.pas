unit CamART.Ribbon.Fonts;

interface

uses
  System.Classes;

type
  { No platform font enumeration is assumed. Applications may supply their
    own catalog through this small interface; names are copied into the model. }
  IRibbonFontProvider = interface
    ['{9839D6EF-32D3-4633-A31B-DFCE8361F2DC}']
    function GetFontNames: TArray<string>;
  end;

  TRibbonConfiguredFontProvider = class(TInterfacedObject, IRibbonFontProvider)
  private
    FNames: TArray<string>;
  public
    constructor Create(const ANames: TArray<string>);
    function GetFontNames: TArray<string>;
  end;

implementation

uses
  System.SysUtils;

constructor TRibbonConfiguredFontProvider.Create(const ANames: TArray<string>);
var
  Names: TStringList;
  Name: string;
  I: Integer;
begin
  inherited Create;
  Names := TStringList.Create;
  try
    Names.CaseSensitive := False;
    for Name in ANames do
      if (Trim(Name) <> '') and (Names.IndexOf(Trim(Name)) < 0) then
        Names.Add(Trim(Name));
    if Names.Count = 0 then
      raise EArgumentException.Create('A configured font catalog must contain a family name.');
    SetLength(FNames, Names.Count);
    for I := 0 to Names.Count - 1 do FNames[I] := Names[I];
  finally
    Names.Free;
  end;
end;

function TRibbonConfiguredFontProvider.GetFontNames: TArray<string>;
begin
  Result := Copy(FNames);
end;

end.
