unit CamART.Ribbon.Json;

{$B-}

interface

uses
  System.Classes,
  System.SysUtils,
  CamART.Ribbon.Types,
  CamART.Ribbon.Model,
  CamART.Ribbon.Commands,
  CamART.Ribbon.References;

const
  { The style keys (themeMode, inheritFormNativeStyles, metrics) are an
    optional, backward compatible v2 extension: older readers ignore them with
    a diagnostic, newer readers default every absent key. }
  RibbonJsonSchemaVersion = 2;
  { JSON keys of TRibbonMetricValues, in the same index order. }
  RibbonJsonMetricKeys: array[0..9] of string = ('tabMinHeight',
    'largeButtonMinHeight', 'smallButtonMinHeight', 'separatorMinHeight',
    'contentMinHeight', 'groupPadding', 'itemGap', 'groupGap',
    'captionHeight', 'captionGap');

type
  ERibbonJsonError = class(Exception)
  private
    FPath, FCode: string;
  public
    constructor Create(const APath, ACode, AMessage: string);
    property Path: string read FPath;
    property Code: string read FCode;
  end;

  TRibbonJsonLimits = record
    MaxUtf8Bytes, MaxDepth, MaxNodes, MaxStringLength, MaxJsonValues: Integer;
    class function Default: TRibbonJsonLimits; static;
    procedure Validate;
  end;

  { A pure query, never an icon-file loader. nil is allowed only when the
    document contains no nonempty icon keys. No command is executed by Parse. }
  IRibbonJsonIconResolver = interface
    ['{E6A1A4D8-3A95-42C9-895D-21B8D3654799}']
    function HasIcon(const AKey: string): Boolean;
  end;

  TRibbonJsonSettings = record
    Theme: string;
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
    { Optional style extension (absent keys keep these defaults). }
    ThemeMode: string; // 'auto' | 'manual'
    InheritFormNativeStyles: Boolean;
    Metrics: TRibbonMetricValues;
    class function Default: TRibbonJsonSettings; static;
    { True when any style setting differs from its default. }
    function HasStyleSettings: Boolean;
  end;

  { This ordinary component owns its detached tabs, which own groups/items.
    There is no reference-counted ownership of TComponent models. After a
    successful ExchangeTabs, this document owns the previous live tab tree. }
  TRibbonJsonDocument = class(TComponent, IRibbonModelHost)
  private
    FModel: TRibbonModel;
    FQuickAccess, FApplicationMenu: TRibbonCommandLinks;
    FSettings: TRibbonJsonSettings;
    FDiagnostics: TStringList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetRibbonModel: TRibbonModel;
    property Model: TRibbonModel read FModel;
    property QuickAccess: TRibbonCommandLinks read FQuickAccess;
    property ApplicationMenu: TRibbonCommandLinks read FApplicationMenu;
    property Settings: TRibbonJsonSettings read FSettings write FSettings;
    property Diagnostics: TStringList read FDiagnostics;
  end;

  TRibbonJsonCodec = class sealed
  public
    class function Parse(const AText: string;
      const ACommands: IRibbonCommandResolver;
      const AIcons: IRibbonJsonIconResolver;
      const ALimits: TRibbonJsonLimits): TRibbonJsonDocument; static;
    class function Export(AModel: TRibbonModel;
      AQuickAccess, AApplicationMenu: TRibbonCommandLinks;
      const ASettings: TRibbonJsonSettings): string; static;
  end;

implementation

uses
  System.JSON,
  System.Math,
  System.UITypes,
  System.Generics.Collections;

type
  { A bounded grammar pass precedes System.JSON allocation. It rejects trailing
    data, comments, malformed numbers/escapes, excessive nesting and strings.
    JSON object duplicate keys are checked on the parsed tree before binding. }
  TJsonPreflight = class
  private
    FText: string;
    FPosition, FDepth, FValues: Integer;
    FLimits: TRibbonJsonLimits;
    function Peek: Char;
    procedure Fail(const AMessage: string);
    procedure WhiteSpace;
    procedure Expect(const C: Char);
    procedure ReadString;
    procedure ReadNumber;
    procedure ReadLiteral(const AValue: string);
    procedure ReadValue;
  public
    constructor Create(const AText: string; const ALimits: TRibbonJsonLimits);
    procedure Execute;
  end;

  TJsonReader = class
  private
    FDocument: TRibbonJsonDocument;
    FCommands: IRibbonCommandResolver;
    FIcons: IRibbonJsonIconResolver;
    FLimits: TRibbonJsonLimits;
    FIds: TDictionary<string, string>;
    FPaths: TDictionary<string, string>;
    FNodes, FVersion: Integer;
    function Member(AObject: TJSONObject; const AName: string): TJSONValue;
    function ObjectValue(AValue: TJSONValue; const APath: string): TJSONObject;
    function ArrayValue(AValue: TJSONValue; const APath: string): TJSONArray;
    function StringValue(AValue: TJSONValue; const APath: string): string;
    function Text(AObject: TJSONObject; const AName, APath, ADefault: string): string;
    function Bool(AObject: TJSONObject; const AName, APath: string;
      const ADefault: Boolean): Boolean;
    function Number(AObject: TJSONObject; const AName, APath: string;
      const ADefault: Double): Double;
    function IntegerValue(AObject: TJSONObject; const AName, APath: string;
      const ADefault: Integer): Integer;
    procedure CheckJsonTree(AValue: TJSONValue; const APath: string);
    procedure CheckProperties(AObject: TJSONObject; const APath: string;
      const AAllowed: array of string);
    procedure AddIdentity(const AId, APath: string);
    function ReadIdentity(AObject: TJSONObject; const APath, AGenerated: string): string;
    procedure CheckOrder(AObject: TJSONObject; const APath: string; AIndex: Integer);
    procedure CheckCommand(const AId, APath: string);
    procedure CheckIcon(const AKey, APath: string);
    procedure ReadCommon(AObject: TJSONObject; ANode: TRibbonNode;
      const APath: string; AIndex: Integer);
    procedure ReadLinks(AValue: TJSONValue; ALinks: TRibbonCommandLinks;
      const APath: string);
    procedure ReadItem(AObject: TJSONObject; AGroup: TRibbonGroup;
      const APath: string; AIndex: Integer; ALegacyButton: Boolean);
    procedure ReadGroup(AObject: TJSONObject; ATab: TRibbonTab;
      const APath: string; AIndex: Integer);
    procedure ReadTab(AObject: TJSONObject; const APath: string; AIndex: Integer);
    procedure ReadSettings(AObject: TJSONObject);
    procedure ReadMetrics(AObject: TJSONObject; var AValues: TRibbonMetricValues);
    procedure ResolveReferences;
    procedure ResolveLinks(ALinks: TRibbonCommandLinks; const APath: string);
  public
    constructor Create(ADocument: TRibbonJsonDocument;
      const ACommands: IRibbonCommandResolver; const AIcons: IRibbonJsonIconResolver;
      const ALimits: TRibbonJsonLimits);
    destructor Destroy; override;
    procedure Read(ARoot: TJSONObject);
  end;

procedure JsonError(const APath, ACode, AMessage: string);
begin
  raise ERibbonJsonError.Create(APath, ACode, AMessage);
end;

constructor ERibbonJsonError.Create(const APath, ACode, AMessage: string);
begin
  FPath := APath;
  FCode := ACode;
  inherited Create(APath + ' [' + ACode + ']: ' + AMessage);
end;

class function TRibbonJsonLimits.Default: TRibbonJsonLimits;
begin
  Result.MaxUtf8Bytes := 1024 * 1024;
  Result.MaxDepth := 32;
  Result.MaxNodes := 10000;
  Result.MaxStringLength := 16384;
  Result.MaxJsonValues := 100000;
end;

procedure TRibbonJsonLimits.Validate;
begin
  if (MaxUtf8Bytes < 1) or (MaxDepth < 1) or (MaxDepth > 256) or
     (MaxNodes < 1) or (MaxStringLength < 1) or (MaxJsonValues < 1) then
    raise EArgumentException.Create('Positive JSON limits are required; MaxDepth must be 1..256.');
end;

class function TRibbonJsonSettings.Default: TRibbonJsonSettings;
begin
  Result := System.Default(TRibbonJsonSettings);
  Result.Theme := 'ModernLight';
  Result.QuickAccessVisible := True;
  Result.QuickAccessPosition := rqpAbove;
  Result.ApplicationCaption := 'File';
  Result.ApplicationButtonVisible := True;
  Result.ExpandedHeight := 184;
  Result.InputDensity := ridPointer;
  Result.ReduceMotion := True;
  Result.CompactCaption := 'Commands';
  Result.ThemeMode := 'auto';
  Result.InheritFormNativeStyles := False;
  Result.Metrics := TRibbonMetrics.Defaults;
end;

function TRibbonJsonSettings.HasStyleSettings: Boolean;
var
  Defaults: TRibbonMetricValues;
  I: Integer;
begin
  Result := (ThemeMode <> 'auto') or InheritFormNativeStyles;
  if Result then Exit;
  Defaults := TRibbonMetrics.Defaults;
  for I := Low(Defaults) to High(Defaults) do
    if Metrics[I] <> Defaults[I] then Exit(True);
end;

constructor TRibbonJsonDocument.Create(AOwner: TComponent);
begin
  inherited;
  FModel := TRibbonModel.Create(Self);
  FQuickAccess := TRibbonCommandLinks.Create(Self);
  FApplicationMenu := TRibbonCommandLinks.Create(Self);
  FDiagnostics := TStringList.Create;
  FSettings := TRibbonJsonSettings.Default;
end;

destructor TRibbonJsonDocument.Destroy;
var
  ModelToFree: TRibbonModel;
begin
  ModelToFree := FModel;
  if FModel <> nil then FModel.Shutdown;
  FQuickAccess.Free;
  FApplicationMenu.Free;
  FDiagnostics.Free;
  { Children are freed while their facade remains valid but shut down. }
  try
    inherited;
  finally
    ModelToFree.Free;
  end;
end;

function TRibbonJsonDocument.GetRibbonModel: TRibbonModel;
begin
  Result := FModel;
end;

constructor TJsonPreflight.Create(const AText: string;
  const ALimits: TRibbonJsonLimits);
begin
  inherited Create;
  FText := AText;
  FLimits := ALimits;
  FPosition := 1;
end;

function TJsonPreflight.Peek: Char;
begin
  if FPosition > Length(FText) then Result := #0
  else Result := FText[FPosition];
end;

procedure TJsonPreflight.Fail(const AMessage: string);
begin
  JsonError('$@' + IntToStr(FPosition), 'syntax', AMessage);
end;

procedure TJsonPreflight.WhiteSpace;
begin
  while CharInSet(Peek, [#9, #10, #13, ' ']) do Inc(FPosition);
end;

procedure TJsonPreflight.Expect(const C: Char);
begin
  if Peek <> C then Fail('Expected "' + C + '".');
  Inc(FPosition);
end;

procedure TJsonPreflight.ReadString;
var
  Units, I, Code: Integer;
  C: Char;
  Hex: string;
begin
  Expect('"');
  Units := 0;
  while Peek <> '"' do
  begin
    C := Peek;
    if Ord(C) < 32 then Fail('Unterminated string or unescaped control character.');
    Inc(FPosition);
    Inc(Units);
    if C = '\' then
    begin
      C := Peek;
      if not CharInSet(C, ['"', '\', '/', 'b', 'f', 'n', 'r', 't', 'u']) then
        Fail('Invalid string escape.');
      Inc(FPosition);
      if C = 'u' then
      begin
        Hex := '';
        for I := 1 to 4 do
        begin
          C := Peek;
          if not CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']) then
            Fail('A Unicode escape needs four hexadecimal digits.');
          Hex := Hex + C;
          Inc(FPosition);
        end;
        Code := StrToInt('$' + Hex);
        if (Code >= $D800) and (Code <= $DBFF) then
        begin
          Expect('\');
          Expect('u');
          Hex := '';
          for I := 1 to 4 do
          begin
            C := Peek;
            if not CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']) then
              Fail('Invalid low surrogate escape.');
            Hex := Hex + C;
            Inc(FPosition);
          end;
          Code := StrToInt('$' + Hex);
          if (Code < $DC00) or (Code > $DFFF) then
            Fail('High surrogate requires a low surrogate.');
          Inc(Units);
        end
        else if (Code >= $DC00) and (Code <= $DFFF) then
          Fail('Low surrogate has no matching high surrogate.');
      end;
    end
    else if (Ord(C) >= $D800) and (Ord(C) <= $DBFF) then
    begin
      if (Ord(Peek) < $DC00) or (Ord(Peek) > $DFFF) then
        Fail('High surrogate requires a low surrogate.');
      Inc(FPosition);
      Inc(Units);
    end
    else if (Ord(C) >= $DC00) and (Ord(C) <= $DFFF) then
      Fail('Low surrogate has no matching high surrogate.');
    if Units > FLimits.MaxStringLength then
      JsonError('$@' + IntToStr(FPosition), 'limit.string', 'String length limit exceeded.');
  end;
  Expect('"');
end;

procedure TJsonPreflight.ReadNumber;
begin
  if Peek = '-' then Inc(FPosition);
  if Peek = '0' then Inc(FPosition)
  else
  begin
    if not CharInSet(Peek, ['1'..'9']) then Fail('Invalid JSON number.');
    repeat Inc(FPosition) until not CharInSet(Peek, ['0'..'9']);
  end;
  if Peek = '.' then
  begin
    Inc(FPosition);
    if not CharInSet(Peek, ['0'..'9']) then Fail('A fraction requires digits.');
    repeat Inc(FPosition) until not CharInSet(Peek, ['0'..'9']);
  end;
  if CharInSet(Peek, ['e', 'E']) then
  begin
    Inc(FPosition);
    if CharInSet(Peek, ['+', '-']) then Inc(FPosition);
    if not CharInSet(Peek, ['0'..'9']) then Fail('An exponent requires digits.');
    repeat Inc(FPosition) until not CharInSet(Peek, ['0'..'9']);
  end;
end;

procedure TJsonPreflight.ReadLiteral(const AValue: string);
var
  I: Integer;
begin
  for I := 1 to Length(AValue) do Expect(AValue[I]);
end;

procedure TJsonPreflight.ReadValue;
var
  Container: Char;
begin
  WhiteSpace;
  Inc(FValues);
  if FValues > FLimits.MaxJsonValues then
    JsonError('$@' + IntToStr(FPosition), 'limit.values', 'JSON value count limit exceeded.');
  case Peek of
    '"': ReadString;
    '-', '0'..'9': ReadNumber;
    't': ReadLiteral('true');
    'f': ReadLiteral('false');
    'n': ReadLiteral('null');
    '{', '[':
      begin
        Container := Peek;
        Inc(FPosition);
        Inc(FDepth);
        if FDepth > FLimits.MaxDepth then
          JsonError('$@' + IntToStr(FPosition), 'limit.depth', 'JSON nesting limit exceeded.');
        WhiteSpace;
        if ((Container = '{') and (Peek <> '}')) or
           ((Container = '[') and (Peek <> ']')) then
          while True do
          begin
            if Container = '{' then
            begin
              ReadString;
              WhiteSpace;
              Expect(':');
            end;
            ReadValue;
            WhiteSpace;
            if Peek <> ',' then Break;
            Inc(FPosition);
            WhiteSpace;
          end;
        if Container = '{' then Expect('}') else Expect(']');
        Dec(FDepth);
      end;
  else
    Fail('Expected a JSON value.');
  end;
end;

procedure TJsonPreflight.Execute;
begin
  FLimits.Validate;
  { Unicode length is a cheap lower bound before requesting a UTF-8 count. }
  if (Length(FText) > FLimits.MaxUtf8Bytes) or
     (TEncoding.UTF8.GetByteCount(FText) > FLimits.MaxUtf8Bytes) then
    JsonError('$', 'limit.bytes', 'UTF-8 document size limit exceeded.');
  ReadValue;
  WhiteSpace;
  if FPosition <= Length(FText) then Fail('Trailing data after the root value.');
end;

constructor TJsonReader.Create(ADocument: TRibbonJsonDocument;
  const ACommands: IRibbonCommandResolver; const AIcons: IRibbonJsonIconResolver;
  const ALimits: TRibbonJsonLimits);
begin
  inherited Create;
  FDocument := ADocument;
  FCommands := ACommands;
  FIcons := AIcons;
  FLimits := ALimits;
  FIds := TDictionary<string, string>.Create;
  FPaths := TDictionary<string, string>.Create;
end;

destructor TJsonReader.Destroy;
begin
  FPaths.Free;
  FIds.Free;
  inherited;
end;

function TJsonReader.Member(AObject: TJSONObject; const AName: string): TJSONValue;
var
  I: Integer;
begin
  for I := 0 to AObject.Count - 1 do
    if AObject.Pairs[I].JsonString.Value = AName then
      Exit(AObject.Pairs[I].JsonValue);
  Result := nil;
end;

function TJsonReader.ObjectValue(AValue: TJSONValue; const APath: string): TJSONObject;
begin
  if not (AValue is TJSONObject) then JsonError(APath, 'type', 'Expected an object.');
  Result := TJSONObject(AValue);
end;

function TJsonReader.ArrayValue(AValue: TJSONValue; const APath: string): TJSONArray;
begin
  if not (AValue is TJSONArray) then JsonError(APath, 'type', 'Expected an array.');
  Result := TJSONArray(AValue);
end;

function TJsonReader.StringValue(AValue: TJSONValue; const APath: string): string;
begin
  if (AValue = nil) or (AValue.ClassType <> TJSONString) then
    JsonError(APath, 'type', 'Expected a string; JSON numbers are not strings.');
  Result := AValue.Value;
  if Length(Result) > FLimits.MaxStringLength then
    JsonError(APath, 'limit.string', 'String length limit exceeded.');
end;

function TJsonReader.Text(AObject: TJSONObject; const AName, APath,
  ADefault: string): string;
var
  Value: TJSONValue;
begin
  Value := Member(AObject, AName);
  if Value = nil then Exit(ADefault);
  Result := StringValue(Value, APath + '.' + AName);
end;

function TJsonReader.Bool(AObject: TJSONObject; const AName, APath: string;
  const ADefault: Boolean): Boolean;
var
  Value: TJSONValue;
begin
  Value := Member(AObject, AName);
  if Value = nil then Exit(ADefault);
  if not (Value is TJSONBool) then
    JsonError(APath + '.' + AName, 'type', 'Expected a Boolean.');
  Result := TJSONBool(Value).AsBoolean;
end;

function TJsonReader.Number(AObject: TJSONObject; const AName, APath: string;
  const ADefault: Double): Double;
var
  Value: TJSONValue;
  FS: TFormatSettings;
begin
  Value := Member(AObject, AName);
  if Value = nil then Exit(ADefault);
  if not (Value is TJSONNumber) then
    JsonError(APath + '.' + AName, 'type', 'Expected a number.');
  FS := TFormatSettings.Invariant;
  if not TryStrToFloat(Value.Value, Result, FS) then
    JsonError(APath + '.' + AName, 'number', 'Number is outside the supported finite range.');
  if IsNan(Result) or IsInfinite(Result) or (Abs(Result) > MaxSingle) then
    JsonError(APath + '.' + AName, 'number', 'A finite Single-range number is required.');
end;

function TJsonReader.IntegerValue(AObject: TJSONObject; const AName,
  APath: string; const ADefault: Integer): Integer;
var
  N: Double;
begin
  N := Number(AObject, AName, APath, ADefault);
  if (N < Low(Integer)) or (N > High(Integer)) or (Frac(N) <> 0) then
    JsonError(APath + '.' + AName, 'integer', 'Expected a 32-bit integer.');
  Result := Trunc(N);
end;

procedure TJsonReader.CheckJsonTree(AValue: TJSONValue; const APath: string);
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  Seen: TDictionary<string, Byte>;
  I: Integer;
  Key: string;
begin
  if AValue is TJSONObject then
  begin
    Obj := TJSONObject(AValue);
    Seen := TDictionary<string, Byte>.Create;
    try
      for I := 0 to Obj.Count - 1 do
      begin
        Key := Obj.Pairs[I].JsonString.Value;
        if Seen.ContainsKey(Key) then
          JsonError(APath + '.' + Key, 'duplicate.property', 'A JSON object cannot repeat a property.');
        Seen.Add(Key, 0);
        CheckJsonTree(Obj.Pairs[I].JsonValue, APath + '.' + Key);
      end;
    finally
      Seen.Free;
    end;
  end
  else if AValue is TJSONArray then
  begin
    Arr := TJSONArray(AValue);
    for I := 0 to Arr.Count - 1 do
      CheckJsonTree(Arr.Items[I], APath + '[' + IntToStr(I) + ']');
  end;
end;

procedure TJsonReader.CheckProperties(AObject: TJSONObject; const APath: string;
  const AAllowed: array of string);
var
  I, J: Integer;
  Key: string;
  Found: Boolean;
begin
  for I := 0 to AObject.Count - 1 do
  begin
    Key := AObject.Pairs[I].JsonString.Value;
    Found := False;
    for J := Low(AAllowed) to High(AAllowed) do
      if Key = AAllowed[J] then
      begin
        Found := True;
        Break;
      end;
    if not Found then
    begin
      if SameText(Key, 'onClick') or SameText(Key, 'onChange') or
         SameText(Key, 'handler') or SameText(Key, 'className') or
         SameText(Key, 'script') or SameText(Key, 'method') then
        JsonError(APath + '.' + Key, 'executable.property',
          'JSON configuration cannot contain event handlers, classes or executable code.');
      FDocument.Diagnostics.Add(APath + '.' + Key + ': ignored optional property.');
    end;
  end;
end;

procedure TJsonReader.AddIdentity(const AId, APath: string);
var
  Previous: string;
begin
  if (AId = '') or (Trim(AId) <> AId) then
    JsonError(APath, 'id', 'An ID must be nonempty and have no surrounding whitespace.');
  if FIds.TryGetValue(AId, Previous) then
    JsonError(APath, 'duplicate.id', 'ID already used at ' + Previous + '.');
  Inc(FNodes);
  if FNodes > FLimits.MaxNodes then
    JsonError(APath, 'limit.nodes', 'Model/reference/entry count limit exceeded.');
  FIds.Add(AId, APath);
end;

function TJsonReader.ReadIdentity(AObject: TJSONObject; const APath,
  AGenerated: string): string;
begin
  if (Member(AObject, 'id') = nil) and (FVersion >= 2) then
    JsonError(APath + '.id', 'required', 'Canonical schema requires a persistent ID.');
  Result := Text(AObject, 'id', APath, AGenerated);
  AddIdentity(Result, APath + '.id');
  FPaths.Add(Result, APath);
end;

procedure TJsonReader.CheckOrder(AObject: TJSONObject; const APath: string;
  AIndex: Integer);
begin
  if IntegerValue(AObject, 'order', APath, AIndex) <> AIndex then
    JsonError(APath + '.order', 'order', 'Order must match the zero-based array position.');
end;

procedure TJsonReader.CheckCommand(const AId, APath: string);
var
  Command: IRibbonCommand;
begin
  if AId = '' then Exit;
  if (Trim(AId) <> AId) or (FCommands = nil) or
     not FCommands.TryResolve(AId, Command) or (Command = nil) then
    JsonError(APath, 'unknown.command', 'Command is not registered: ' + AId);
end;

procedure TJsonReader.CheckIcon(const AKey, APath: string);
begin
  if AKey = '' then Exit;
  if (FIcons = nil) or not FIcons.HasIcon(AKey) then
    JsonError(APath, 'unknown.icon', 'Icon key is not registered: ' + AKey);
end;

procedure TJsonReader.ReadCommon(AObject: TJSONObject; ANode: TRibbonNode;
  const APath: string; AIndex: Integer);
var
  Caption: string;
begin
  ANode.Id := ReadIdentity(AObject, APath, ANode.Id);
  CheckOrder(AObject, APath, AIndex);
  Caption := '';
  if FVersion = 1 then Caption := Text(AObject, 'name', APath, '');
  ANode.Caption := Text(AObject, 'caption', APath, Caption);
  ANode.IconKey := Text(AObject, 'icon', APath, '');
  ANode.Visible := Bool(AObject, 'visible', APath, True);
  ANode.Enabled := Bool(AObject, 'enabled', APath, True);
  CheckIcon(ANode.IconKey, APath + '.icon');
end;

function ButtonStyleName(AStyle: TRibbonButtonStyle): string;
begin
  case AStyle of
    rbsLarge: Result := 'large';
    rbsSmall: Result := 'small';
    rbsIcon: Result := 'icon';
  else
    raise EArgumentException.Create('Unknown button style.');
  end;
end;

function ButtonKindName(AKind: TRibbonButtonKind): string;
begin
  case AKind of
    rbkPush: Result := 'push';
    rbkToggle: Result := 'toggle';
    rbkCheck: Result := 'check';
    rbkDropDown: Result := 'dropdown';
    rbkSplit: Result := 'split';
    rbkGallery: Result := 'gallery';
  else
    raise EArgumentException.Create('Unknown button kind.');
  end;
end;

function ReadButtonStyle(const AText, APath: string): TRibbonButtonStyle;
begin
  if AText = 'large' then Exit(rbsLarge);
  if AText = 'small' then Exit(rbsSmall);
  if AText = 'icon' then Exit(rbsIcon);
  JsonError(APath, 'enum', 'Expected large, small or icon.');
  Result := rbsLarge;
end;

function ReadButtonKind(const AText, APath: string): TRibbonButtonKind;
begin
  if AText = 'push' then Exit(rbkPush);
  if AText = 'toggle' then Exit(rbkToggle);
  if AText = 'check' then Exit(rbkCheck);
  if AText = 'dropdown' then Exit(rbkDropDown);
  if AText = 'split' then Exit(rbkSplit);
  if AText = 'gallery' then Exit(rbkGallery);
  JsonError(APath, 'enum', 'Unknown button behaviour: ' + AText);
  Result := rbkPush;
end;

procedure TJsonReader.ReadLinks(AValue: TJSONValue; ALinks: TRibbonCommandLinks;
  const APath: string);
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  Link: TRibbonCommandLink;
  I: Integer;
  Path, CommandId, ItemId: string;
  Separator: Boolean;
begin
  if AValue = nil then Exit;
  Arr := ArrayValue(AValue, APath);
  for I := 0 to Arr.Count - 1 do
  begin
    Path := APath + '[' + IntToStr(I) + ']';
    Obj := ObjectValue(Arr.Items[I], Path);
    CheckProperties(Obj, Path, ['id', 'order', 'item', 'command', 'separator',
      'caption', 'hint', 'icon', 'overrideCaption', 'overrideHint', 'overrideIcon',
      'visible', 'enabled', 'kind']);
    CheckOrder(Obj, Path, I);
    Link := ALinks.Add;
    Link.Id := ReadIdentity(Obj, Path, Link.Id);
    ItemId := Text(Obj, 'item', Path, '');
    CommandId := Text(Obj, 'command', Path, '');
    Separator := Bool(Obj, 'separator', Path, False);
    if Ord(ItemId <> '') + Ord(CommandId <> '') + Ord(Separator) <> 1 then
      JsonError(Path, 'reference', 'A link needs exactly one of item, command or separator=true.');
    Link.ItemId := ItemId;
    Link.CommandId := CommandId;
    Link.IsSeparator := Separator;
    Link.Caption := Text(Obj, 'caption', Path, '');
    Link.Hint := Text(Obj, 'hint', Path, '');
    Link.IconKey := Text(Obj, 'icon', Path, '');
    Link.OverrideCaption := Bool(Obj, 'overrideCaption', Path, False);
    Link.OverrideHint := Bool(Obj, 'overrideHint', Path, False);
    Link.OverrideIcon := Bool(Obj, 'overrideIcon', Path, False);
    Link.Visible := Bool(Obj, 'visible', Path, True);
    Link.Enabled := Bool(Obj, 'enabled', Path, True);
    Link.ButtonKind := ReadButtonKind(Text(Obj, 'kind', Path, 'push'), Path + '.kind');
    CheckCommand(CommandId, Path + '.command');
    CheckIcon(Link.IconKey, Path + '.icon');
    try
      Link.Validate;
    except
      on E: ERibbonReferenceError do JsonError(Path, 'reference', E.Message);
    end;
  end;
end;

procedure TJsonReader.ReadItem(AObject: TJSONObject; AGroup: TRibbonGroup;
  const APath: string; AIndex: Integer; ALegacyButton: Boolean);
var
  Kind, Style, Path, CommandId, GroupName, ColorText: string;
  ItemClass: TRibbonItemClass;
  Item: TRibbonItem;
  Button: TRibbonButton;
  Radio: TRibbonRadioButton;
  Sibling: TRibbonItem;
  Combo: TRibbonComboBox;
  Gallery: TRibbonGallery;
  Entry: TRibbonGalleryEntry;
  Entries: TJSONArray;
  Obj: TJSONObject;
  I, Index: Integer;
  Choices: TStringList;
  Value, Minimum, Maximum: Double;
  ColorValue: UInt64;
  Checked: Boolean;
  V: TJSONValue;
begin
  if ALegacyButton then Kind := Text(AObject, 'type', APath, 'button')
  else
  begin
    if Member(AObject, 'type') = nil then
      JsonError(APath + '.type', 'required', 'An item type is required.');
    Kind := Text(AObject, 'type', APath, '');
  end;
  if Kind = 'button' then ItemClass := TRibbonButton
  else if Kind = 'separator' then ItemClass := TRibbonSeparator
  else if Kind = 'label' then ItemClass := TRibbonLabel
  else if Kind = 'sklabel' then ItemClass := TRibbonSkLabel
  else if Kind = 'edit' then ItemClass := TRibbonEdit
  else if Kind = 'combo' then ItemClass := TRibbonComboBox
  else if Kind = 'colorpicker' then ItemClass := TRibbonColorPicker
  else if Kind = 'fontpicker' then ItemClass := TRibbonFontPicker
  else if Kind = 'fontsizepicker' then ItemClass := TRibbonFontSizePicker
  else if Kind = 'gallery' then ItemClass := TRibbonGallery
  else if Kind = 'checkbox' then ItemClass := TRibbonCheckBox
  else if Kind = 'radio' then ItemClass := TRibbonRadioButton
  else if Kind = 'progress' then ItemClass := TRibbonProgressBar
  else if Kind = 'dropdownmenu' then ItemClass := TRibbonDropDownMenu
  else
  begin
    JsonError(APath + '.type', 'unknown.type', 'Unknown required item type: ' + Kind);
    Exit;
  end;
  { A closed whitelist maps schema type keys to the existing model classes.
    No RTTI class lookup, event lookup or arbitrary class instantiation occurs. }
  Item := AGroup.AddItem(ItemClass);
  ReadCommon(AObject, Item, APath, AIndex);
  Item.Hint := Text(AObject, 'hint', APath, '');
  if Item is TRibbonButton then
  begin
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint', 'style', 'kind', 'command', 'checked',
      'gallery', 'menu', 'groupName']);
    Button := TRibbonButton(Item);
    Style := Text(AObject, 'style', APath, ButtonStyleName(Button.ButtonStyle));
    if FVersion = 1 then Style := LowerCase(Style);
    Button.ButtonStyle := ReadButtonStyle(Style, APath + '.style');
    Kind := Text(AObject, 'kind', APath, ButtonKindName(Button.ButtonKind));
    try
      Button.ButtonKind := ReadButtonKind(Kind, APath + '.kind');
    except
      on E: ERibbonModelError do JsonError(APath + '.kind', 'kind', E.Message);
    end;
    CommandId := Text(AObject, 'command', APath, '');
    CheckCommand(CommandId, APath + '.command');
    Button.CommandId := CommandId;
    Button.GalleryId := Text(AObject, 'gallery', APath, '');
    ReadLinks(Member(AObject, 'menu'), Button.MenuItems, APath + '.menu');
    Checked := Bool(AObject, 'checked', APath, False);
    if Item is TRibbonRadioButton then
    begin
      Radio := TRibbonRadioButton(Item);
      GroupName := Text(AObject, 'groupName', APath, '');
      Radio.GroupName := GroupName;
      { Reject conflicting local radio intent instead of silently unchecking
        an earlier item while sequentially building the detached model. }
      if Checked and (CommandId = '') then
        for Sibling in AGroup.Items do
          if (Sibling <> Radio) and (Sibling is TRibbonRadioButton) then
            if (TRibbonRadioButton(Sibling).CommandId = '') and
               (TRibbonRadioButton(Sibling).GroupName = GroupName) and
               TRibbonRadioButton(Sibling).Checked then
              JsonError(APath + '.checked', 'radio.group',
                'Only one commandless radio in a group may be checked.');
    end
    else if Member(AObject, 'groupName') <> nil then
      JsonError(APath + '.groupName', 'property.type', 'groupName applies only to radio items.');
    if CommandId = '' then Button.Checked := Checked
    else if Member(AObject, 'checked') <> nil then
      FDocument.Diagnostics.Add(APath + '.checked: ignored; registered command owns checked state.');
  end
  else if Item is TRibbonEdit then
  begin
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint', 'text']);
    TRibbonEdit(Item).Text := Text(AObject, 'text', APath, '');
  end
  else if Item is TRibbonComboBox then
  begin
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint', 'choices', 'itemIndex']);
    Combo := TRibbonComboBox(Item);
    V := Member(AObject, 'choices');
    if V <> nil then
    begin
      Entries := ArrayValue(V, APath + '.choices');
      Choices := TStringList.Create;
      try
        for I := 0 to Entries.Count - 1 do
          Choices.Add(StringValue(Entries.Items[I], APath + '.choices[' + IntToStr(I) + ']'));
        try
          Combo.Items := Choices;
        except
          on E: ERibbonModelError do JsonError(APath + '.choices', 'choices', E.Message);
        end;
      finally
        Choices.Free;
      end;
    end;
    Index := IntegerValue(AObject, 'itemIndex', APath, Combo.ItemIndex);
    if (Index < -1) or (Index >= Combo.Items.Count) then
      JsonError(APath + '.itemIndex', 'range', 'Selection index is outside the choices array.');
    Combo.ItemIndex := Index;
  end
  else if Item is TRibbonColorPicker then
  begin
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint', 'color']);
    ColorText := Text(AObject, 'color', APath, '#FF000000');
    if (Length(ColorText) <> 9) or (ColorText[1] <> '#') or
       not TryStrToUInt64('$' + Copy(ColorText, 2, 8), ColorValue) or
       (ColorValue > High(Cardinal)) then
      JsonError(APath + '.color', 'color', 'Expected #AARRGGBB.');
    TRibbonColorPicker(Item).Color := TAlphaColor(ColorValue);
  end
  else if Item is TRibbonGallery then
  begin
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint', 'entries', 'selectedId']);
    Gallery := TRibbonGallery(Item);
    V := Member(AObject, 'entries');
    if V <> nil then
    begin
      Entries := ArrayValue(V, APath + '.entries');
      for I := 0 to Entries.Count - 1 do
      begin
        Path := APath + '.entries[' + IntToStr(I) + ']';
        Obj := ObjectValue(Entries.Items[I], Path);
        CheckProperties(Obj, Path, ['id', 'order', 'caption', 'icon', 'command', 'visible', 'enabled']);
        CheckOrder(Obj, Path, I);
        Entry := Gallery.Entries.Add;
        Entry.Id := ReadIdentity(Obj, Path, Entry.Id);
        Entry.Caption := Text(Obj, 'caption', Path, '');
        Entry.IconKey := Text(Obj, 'icon', Path, '');
        Entry.CommandId := Text(Obj, 'command', Path, '');
        Entry.Visible := Bool(Obj, 'visible', Path, True);
        Entry.Enabled := Bool(Obj, 'enabled', Path, True);
        CheckCommand(Entry.CommandId, Path + '.command');
        CheckIcon(Entry.IconKey, Path + '.icon');
      end;
    end;
    Kind := Text(AObject, 'selectedId', APath, '');
    if (Kind <> '') and (Gallery.Entries.FindById(Kind) = nil) then
      JsonError(APath + '.selectedId', 'reference', 'Selected gallery entry does not exist.');
    Gallery.SelectedId := Kind;
  end
  else if Item is TRibbonSkLabel then
  begin
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint', 'template']);
    { Only the template key is data. The TSkLabel appearance is registered by
      the application; an unregistered key falls back to the caption. }
    TRibbonSkLabel(Item).TemplateKey := Text(AObject, 'template', APath, '');
  end
  else if Item is TRibbonProgressBar then
  begin
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint', 'min', 'max', 'value']);
    Minimum := Number(AObject, 'min', APath, 0);
    Maximum := Number(AObject, 'max', APath, 100);
    Value := Number(AObject, 'value', APath, Minimum);
    if (Minimum >= Maximum) or (Value < Minimum) or (Value > Maximum) then
      JsonError(APath, 'range', 'Progress requires min < max and min <= value <= max.');
    TRibbonProgressBar(Item).SetRange(Minimum, Maximum);
    TRibbonProgressBar(Item).Value := Value;
  end
  else
    CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
      'icon', 'visible', 'enabled', 'hint']);
end;

procedure TJsonReader.ReadGroup(AObject: TJSONObject; ATab: TRibbonTab;
  const APath: string; AIndex: Integer);
var
  Group: TRibbonGroup;
  Value: TJSONValue;
  Items: TJSONArray;
  I: Integer;
  Path, ArrayName: string;
  Minimum, Preferred: Double;
  LegacyButtons: Boolean;
begin
  CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
    'icon', 'visible', 'enabled', 'minWidth', 'preferredWidth', 'pinned',
    'allowCompact', 'allowCollapse', 'collapsePriority', 'items', 'buttons']);
  if Text(AObject, 'type', APath, 'group') <> 'group' then
    JsonError(APath + '.type', 'unknown.type', 'Expected group.');
  Group := ATab.AddGroup('');
  ReadCommon(AObject, Group, APath, AIndex);
  Minimum := Number(AObject, 'minWidth', APath, Group.MinWidth);
  Preferred := Number(AObject, 'preferredWidth', APath, Group.PreferredWidth);
  if (Minimum < 0) or (Preferred < Minimum) then
    JsonError(APath, 'width', 'Group widths require 0 <= minWidth <= preferredWidth.');
  { Setting Preferred first can clamp against the old Min. Start at zero. }
  Group.MinWidth := 0;
  Group.PreferredWidth := Preferred;
  Group.MinWidth := Minimum;
  Group.Pinned := Bool(AObject, 'pinned', APath, False);
  Group.AllowCompact := Bool(AObject, 'allowCompact', APath, True);
  Group.AllowCollapse := Bool(AObject, 'allowCollapse', APath, True);
  Group.CollapsePriority := IntegerValue(AObject, 'collapsePriority', APath, 0);
  Value := Member(AObject, 'items');
  LegacyButtons := False;
  ArrayName := 'items';
  if Member(AObject, 'buttons') <> nil then
  begin
    if (FVersion <> 1) or (Value <> nil) then
      JsonError(APath + '.buttons', 'legacy', 'buttons is accepted only in v1 and cannot coexist with items.');
    Value := Member(AObject, 'buttons');
    LegacyButtons := True;
    ArrayName := 'buttons';
  end;
  if Value = nil then
    JsonError(APath + '.items', 'required', 'A group needs an items array (v1 may use buttons).');
  Items := ArrayValue(Value, APath + '.' + ArrayName);
  for I := 0 to Items.Count - 1 do
  begin
    Path := APath + '.' + ArrayName + '[' + IntToStr(I) + ']';
    ReadItem(ObjectValue(Items.Items[I], Path), Group, Path, I, LegacyButtons);
  end;
end;

procedure TJsonReader.ReadTab(AObject: TJSONObject; const APath: string; AIndex: Integer);
var
  Tab: TRibbonTab;
  Groups: TJSONArray;
  I: Integer;
  Path: string;
begin
  CheckProperties(AObject, APath, ['id', 'order', 'type', 'caption', 'name',
    'icon', 'visible', 'enabled', 'groups']);
  if Text(AObject, 'type', APath, 'tab') <> 'tab' then
    JsonError(APath + '.type', 'unknown.type', 'Expected tab.');
  Tab := FDocument.Model.AddTab('');
  ReadCommon(AObject, Tab, APath, AIndex);
  if Member(AObject, 'groups') = nil then
    JsonError(APath + '.groups', 'required', 'A tab needs a groups array.');
  Groups := ArrayValue(Member(AObject, 'groups'), APath + '.groups');
  for I := 0 to Groups.Count - 1 do
  begin
    Path := APath + '.groups[' + IntToStr(I) + ']';
    ReadGroup(ObjectValue(Groups.Items[I], Path), Tab, Path, I);
  end;
end;

procedure TJsonReader.ReadMetrics(AObject: TJSONObject;
  var AValues: TRibbonMetricValues);
var
  I: Integer;
  Value: Double;
begin
  CheckProperties(AObject, '$.metrics', RibbonJsonMetricKeys);
  for I := Low(RibbonJsonMetricKeys) to High(RibbonJsonMetricKeys) do
  begin
    Value := Number(AObject, RibbonJsonMetricKeys[I], '$.metrics', AValues[I]);
    if not TRibbonMetrics.IsValidValue(Value) then
      JsonError('$.metrics.' + RibbonJsonMetricKeys[I], 'range',
        'Ribbon metrics must be finite and nonnegative.');
    AValues[I] := Value;
  end;
end;

procedure TJsonReader.ReadSettings(AObject: TJSONObject);
var
  Settings: TRibbonJsonSettings;
  Key: string;
begin
  Settings := TRibbonJsonSettings.Default;
  Key := Text(AObject, 'theme', '$', Settings.Theme);
  if FVersion = 1 then
  begin
    if SameText(Key, 'Silver') then Key := 'OfficeSilver';
    if SameText(Key, 'Black') then Key := 'OfficeBlack';
  end;
  if (Key <> 'Office2007Blue') and (Key <> 'Office2010Blue') and
     (Key <> 'OfficeSilver') and (Key <> 'OfficeBlack') and
     (Key <> 'ModernLight') and (Key <> 'ModernDark') then
    JsonError('$.theme', 'enum', 'Unknown theme preset: ' + Key);
  Settings.Theme := Key;
  Settings.HasActiveTabId := Member(AObject, 'activeTabId') <> nil;
  Settings.ActiveTabId := Text(AObject, 'activeTabId', '$', '');
  Settings.Collapsed := Bool(AObject, 'collapsed', '$', False);
  Settings.QuickAccessVisible := Bool(AObject, 'quickAccessVisible', '$', True);
  Key := Text(AObject, 'quickAccessPosition', '$', 'above');
  if Key = 'above' then Settings.QuickAccessPosition := rqpAbove
  else if Key = 'below' then Settings.QuickAccessPosition := rqpBelow
  else JsonError('$.quickAccessPosition', 'enum', 'Expected above or below.');
  Settings.ApplicationCaption := Text(AObject, 'applicationCaption', '$', 'File');
  Settings.ApplicationButtonVisible := Bool(AObject, 'applicationButtonVisible', '$', True);
  Settings.ExpandedHeight := Number(AObject, 'expandedHeight', '$', 184);
  if Settings.ExpandedHeight <= 0 then
    JsonError('$.expandedHeight', 'range', 'Expanded height must be positive.');
  Key := Text(AObject, 'inputDensity', '$', 'pointer');
  if Key = 'pointer' then Settings.InputDensity := ridPointer
  else if Key = 'touch' then Settings.InputDensity := ridTouch
  else JsonError('$.inputDensity', 'enum', 'Expected pointer or touch.');
  Settings.ReduceMotion := Bool(AObject, 'reduceMotion', '$', True);
  Settings.CompactCaption := Text(AObject, 'compactCaption', '$', 'Commands');
  { Style extension: each key is optional and keeps its default, so every
    existing v1/v2 document loads unchanged. }
  Settings.ThemeMode := Text(AObject, 'themeMode', '$', 'auto');
  if (Settings.ThemeMode <> 'auto') and (Settings.ThemeMode <> 'manual') then
    JsonError('$.themeMode', 'enum', 'Expected auto or manual.');
  Settings.InheritFormNativeStyles := Bool(AObject, 'inheritFormNativeStyles', '$', False);
  if Member(AObject, 'metrics') <> nil then
    ReadMetrics(ObjectValue(Member(AObject, 'metrics'), '$.metrics'), Settings.Metrics);
  FDocument.Settings := Settings;
end;

procedure TJsonReader.ResolveLinks(ALinks: TRibbonCommandLinks; const APath: string);
var
  I: Integer;
  Path: string;
begin
  for I := 0 to ALinks.Count - 1 do
  begin
    Path := APath + '[' + IntToStr(I) + ']';
    if (ALinks[I].ItemId <> '') and
       (FDocument.Model.FindButtonById(ALinks[I].ItemId) = nil) then
      JsonError(Path + '.item', 'reference', 'The item reference must name a button-family item.');
  end;
end;

procedure TJsonReader.ResolveReferences;
var
  Tab: TRibbonTab;
  Group: TRibbonGroup;
  Item: TRibbonItem;
  Button: TRibbonButton;
  Path: string;
  Settings: TRibbonJsonSettings;
begin
  ResolveLinks(FDocument.QuickAccess, '$.quickAccess');
  ResolveLinks(FDocument.ApplicationMenu, '$.applicationMenu');
  for Tab in FDocument.Model.Tabs do
    for Group in Tab.Groups do
      for Item in Group.Items do
        if Item is TRibbonButton then
        begin
          Button := TRibbonButton(Item);
          Path := FPaths[Button.Id];
          ResolveLinks(Button.MenuItems, Path + '.menu');
          if (Button.GalleryId <> '') and
             (FDocument.Model.FindGalleryById(Button.GalleryId) = nil) then
            JsonError(Path + '.gallery', 'reference', 'Gallery target does not exist.');
          if (Button.ButtonKind = rbkGallery) and (Button.GalleryId = '') then
            JsonError(Path + '.gallery', 'required', 'A gallery button needs a gallery target.');
        end;
  Settings := FDocument.Settings;
  if Settings.HasActiveTabId and (Settings.ActiveTabId <> '') then
  begin
    Tab := FDocument.Model.FindTabById(Settings.ActiveTabId);
    if (Tab = nil) or not Tab.Visible or not Tab.Enabled then
      JsonError('$.activeTabId', 'reference', 'The active tab must exist and be visible and enabled.');
  end;
end;

procedure TJsonReader.Read(ARoot: TJSONObject);
var
  Tabs: TJSONArray;
  I: Integer;
  Path: string;
begin
  CheckJsonTree(ARoot, '$');
  FVersion := IntegerValue(ARoot, 'schemaVersion', '$', 1);
  if not (FVersion in [1, RibbonJsonSchemaVersion]) then
    JsonError('$.schemaVersion', 'version', 'Only schema versions 1 and 2 are supported.');
  CheckProperties(ARoot, '$', ['schemaVersion', 'theme', 'activeTabId', 'collapsed',
    'quickAccessVisible', 'quickAccessPosition', 'applicationCaption',
    'applicationButtonVisible', 'expandedHeight', 'inputDensity', 'reduceMotion',
    'compactCaption', 'tabs', 'quickAccess', 'applicationMenu',
    'themeMode', 'inheritFormNativeStyles', 'metrics']);
  if FVersion = 1 then
    FDocument.Diagnostics.Add('$: migrated v1 input; generated missing IDs are retained by canonical export.');
  ReadSettings(ARoot);
  if Member(ARoot, 'tabs') = nil then
    JsonError('$.tabs', 'required', 'A Ribbon definition needs a tabs array.');
  Tabs := ArrayValue(Member(ARoot, 'tabs'), '$.tabs');
  for I := 0 to Tabs.Count - 1 do
  begin
    Path := '$.tabs[' + IntToStr(I) + ']';
    ReadTab(ObjectValue(Tabs.Items[I], Path), Path, I);
  end;
  ReadLinks(Member(ARoot, 'quickAccess'), FDocument.QuickAccess, '$.quickAccess');
  ReadLinks(Member(ARoot, 'applicationMenu'), FDocument.ApplicationMenu, '$.applicationMenu');
  ResolveReferences;
  try
    FDocument.Model.ValidateTree;
    FDocument.QuickAccess.Validate;
    FDocument.ApplicationMenu.Validate;
  except
    on E: ERibbonModelError do JsonError('$', 'model', E.Message);
    on E: ERibbonReferenceError do JsonError('$', 'reference', E.Message);
  end;
end;

class function TRibbonJsonCodec.Parse(const AText: string;
  const ACommands: IRibbonCommandResolver; const AIcons: IRibbonJsonIconResolver;
  const ALimits: TRibbonJsonLimits): TRibbonJsonDocument;
var
  Preflight: TJsonPreflight;
  Root: TJSONValue;
  Reader: TJsonReader;
  Document: TRibbonJsonDocument;
begin
  Preflight := TJsonPreflight.Create(AText, ALimits);
  try
    Preflight.Execute;
  finally
    Preflight.Free;
  end;
  Root := nil;
  try
    try
      Root := TJSONObject.ParseJSONValue(AText, True, True);
    except
      on E: Exception do JsonError('$', 'syntax', E.Message);
    end;
    if not (Root is TJSONObject) then
      JsonError('$', 'type', 'The Ribbon root must be an object.');
    Document := TRibbonJsonDocument.Create(nil);
    try
      Document.Model.BeginUpdate;
      try
        Document.Model.CommandResolver := ACommands;
        Reader := TJsonReader.Create(Document, ACommands, AIcons, ALimits);
        try
          try
            Reader.Read(TJSONObject(Root));
          except
            on E: ERibbonModelError do JsonError('$', 'model', E.Message);
            on E: ERibbonReferenceError do JsonError('$', 'reference', E.Message);
          end;
        finally
          Reader.Free;
        end;
      finally
        Document.Model.EndUpdate;
      end;
      Result := Document;
      Document := nil;
    finally
      Document.Free;
    end;
  finally
    Root.Free;
  end;
end;

procedure AddText(AObject: TJSONObject; const AName, AValue: string);
begin
  AObject.AddPair(AName, TJSONString.Create(AValue));
end;

procedure AddBool(AObject: TJSONObject; const AName: string; AValue: Boolean);
begin
  AObject.AddPair(AName, TJSONBool.Create(AValue));
end;

procedure AddNumber(AObject: TJSONObject; const AName: string; AValue: Double);
begin
  if IsNan(AValue) or IsInfinite(AValue) then
    JsonError('$.' + AName, 'number', 'Cannot export a nonfinite number.');
  AObject.AddPair(AName, TJSONNumber.Create(AValue));
end;

class function TRibbonJsonCodec.Export(AModel: TRibbonModel;
  AQuickAccess, AApplicationMenu: TRibbonCommandLinks;
  const ASettings: TRibbonJsonSettings): string;
var
  Root: TJSONObject;
  Seen: TDictionary<string, Byte>;
  Tabs, Groups, Items: TJSONArray;
  TabObject, GroupObject: TJSONObject;
  Tab: TRibbonTab;
  Group: TRibbonGroup;
  Item: TRibbonItem;
  TabIndex, GroupIndex, ItemIndex: Integer;
  MetricIndex: Integer;
  DefaultMetrics: TRibbonMetricValues;
  MetricsObject: TJSONObject;

  procedure WriteIdentity(AObject: TJSONObject; const AId: string; AIndex: Integer);
  begin
    if (AId = '') or (Trim(AId) <> AId) then
      JsonError('$.id', 'id', 'Cannot export an empty or whitespace-padded ID.');
    if Seen.ContainsKey(AId) then
      JsonError('$.id', 'duplicate.id', 'Cannot export duplicate global ID: ' + AId);
    Seen.Add(AId, 0);
    AddText(AObject, 'id', AId);
    AddNumber(AObject, 'order', AIndex);
  end;

  procedure WriteCommon(AObject: TJSONObject; ANode: TRibbonNode; AIndex: Integer);
  begin
    WriteIdentity(AObject, ANode.Id, AIndex);
    AddText(AObject, 'caption', ANode.Caption);
    AddText(AObject, 'icon', ANode.IconKey);
    AddBool(AObject, 'visible', ANode.Visible);
    AddBool(AObject, 'enabled', ANode.Enabled);
  end;

  function WriteLinks(ALinks: TRibbonCommandLinks): TJSONArray;
  var
    I: Integer;
    Obj: TJSONObject;
    Link: TRibbonCommandLink;
  begin
    Result := TJSONArray.Create;
    try
      ALinks.Validate;
      for I := 0 to ALinks.Count - 1 do
      begin
        Link := ALinks[I];
        Obj := TJSONObject.Create;
        Result.AddElement(Obj);
        WriteIdentity(Obj, Link.Id, I);
        if Link.ItemId <> '' then
        begin
          if AModel.FindButtonById(Link.ItemId) = nil then
            JsonError('$.item', 'reference', 'Cannot export a broken item reference: ' + Link.ItemId);
          AddText(Obj, 'item', Link.ItemId);
        end
        else if Link.CommandId <> '' then AddText(Obj, 'command', Link.CommandId)
        else AddBool(Obj, 'separator', True);
        AddText(Obj, 'caption', Link.Caption);
        AddText(Obj, 'hint', Link.Hint);
        AddText(Obj, 'icon', Link.IconKey);
        AddBool(Obj, 'overrideCaption', Link.OverrideCaption);
        AddBool(Obj, 'overrideHint', Link.OverrideHint);
        AddBool(Obj, 'overrideIcon', Link.OverrideIcon);
        AddBool(Obj, 'visible', Link.Visible);
        AddBool(Obj, 'enabled', Link.Enabled);
        AddText(Obj, 'kind', ButtonKindName(Link.ButtonKind));
      end;
    except
      Result.Free;
      raise;
    end;
  end;

  function WriteItem(AItem: TRibbonItem; AIndex: Integer): TJSONObject;
  var
    Button: TRibbonButton;
    Combo: TRibbonComboBox;
    Gallery: TRibbonGallery;
    Entry: TRibbonGalleryEntry;
    Progress: TRibbonProgressBar;
    Arr: TJSONArray;
    Obj: TJSONObject;
    I: Integer;
    C: TClass;
  begin
    C := AItem.ClassType;
    if (C <> TRibbonButton) and (C <> TRibbonSeparator) and (C <> TRibbonLabel) and
       (C <> TRibbonEdit) and (C <> TRibbonComboBox) and (C <> TRibbonColorPicker) and
       (C <> TRibbonFontPicker) and (C <> TRibbonFontSizePicker) and
       (C <> TRibbonGallery) and (C <> TRibbonCheckBox) and
       (C <> TRibbonRadioButton) and (C <> TRibbonProgressBar) and
       (C <> TRibbonDropDownMenu) and (C <> TRibbonSkLabel) then
      JsonError('$.type', 'unknown.type', 'No JSON codec is registered for class ' + AItem.ClassName);
    Result := TJSONObject.Create;
    try
      WriteCommon(Result, AItem, AIndex);
      AddText(Result, 'type', AItem.TypeKey);
      AddText(Result, 'hint', AItem.Hint);
      if AItem is TRibbonButton then
      begin
        Button := TRibbonButton(AItem);
        AddText(Result, 'style', ButtonStyleName(Button.ButtonStyle));
        AddText(Result, 'kind', ButtonKindName(Button.ButtonKind));
        AddText(Result, 'command', Button.CommandId);
        { Do not query command Checked or serialize business state as a local
          toggle. Command-bound state is owned exclusively by the registry. }
        if Button.CommandId = '' then AddBool(Result, 'checked', Button.Checked);
        if (Button.GalleryId <> '') and (AModel.FindGalleryById(Button.GalleryId) = nil) then
          JsonError('$.gallery', 'reference', 'Cannot export a broken gallery reference.');
        if (Button.ButtonKind = rbkGallery) and (Button.GalleryId = '') then
          JsonError('$.gallery', 'required', 'A gallery button requires a target.');
        AddText(Result, 'gallery', Button.GalleryId);
        Result.AddPair('menu', WriteLinks(Button.MenuItems));
        if AItem is TRibbonRadioButton then
          AddText(Result, 'groupName', TRibbonRadioButton(AItem).GroupName);
      end
      else if AItem is TRibbonEdit then
        AddText(Result, 'text', TRibbonEdit(AItem).Text)
      else if AItem is TRibbonSkLabel then
        AddText(Result, 'template', TRibbonSkLabel(AItem).TemplateKey)
      else if AItem is TRibbonComboBox then
      begin
        Combo := TRibbonComboBox(AItem);
        Arr := TJSONArray.Create;
        Result.AddPair('choices', Arr);
        for I := 0 to Combo.Items.Count - 1 do
          Arr.AddElement(TJSONString.Create(Combo.Items[I]));
        if (Combo.ItemIndex < -1) or (Combo.ItemIndex >= Combo.Items.Count) then
          JsonError('$.itemIndex', 'range', 'Cannot export an invalid combo selection.');
        AddNumber(Result, 'itemIndex', Combo.ItemIndex);
      end
      else if AItem is TRibbonColorPicker then
        AddText(Result, 'color', '#' + IntToHex(Cardinal(TRibbonColorPicker(AItem).Color), 8))
      else if AItem is TRibbonGallery then
      begin
        Gallery := TRibbonGallery(AItem);
        Gallery.Entries.Validate;
        Arr := TJSONArray.Create;
        Result.AddPair('entries', Arr);
        for I := 0 to Gallery.Entries.Count - 1 do
        begin
          Entry := Gallery.Entries[I];
          Obj := TJSONObject.Create;
          Arr.AddElement(Obj);
          WriteIdentity(Obj, Entry.Id, I);
          AddText(Obj, 'caption', Entry.Caption);
          AddText(Obj, 'icon', Entry.IconKey);
          AddText(Obj, 'command', Entry.CommandId);
          AddBool(Obj, 'visible', Entry.Visible);
          AddBool(Obj, 'enabled', Entry.Enabled);
        end;
        if (Gallery.SelectedId <> '') and (Gallery.Entries.FindById(Gallery.SelectedId) = nil) then
          JsonError('$.selectedId', 'reference', 'Cannot export a broken gallery selection.');
        AddText(Result, 'selectedId', Gallery.SelectedId);
      end
      else if AItem is TRibbonProgressBar then
      begin
        Progress := TRibbonProgressBar(AItem);
        AddNumber(Result, 'min', Progress.Min);
        AddNumber(Result, 'max', Progress.Max);
        AddNumber(Result, 'value', Progress.Value);
      end;
    except
      Result.Free;
      raise;
    end;
  end;

begin
  if (AModel = nil) or (AQuickAccess = nil) or (AApplicationMenu = nil) then
    raise EArgumentNilException.Create('Export requires model, quick access and application menu.');
  if (ASettings.Theme <> 'Office2007Blue') and
     (ASettings.Theme <> 'Office2010Blue') and
     (ASettings.Theme <> 'OfficeSilver') and
     (ASettings.Theme <> 'OfficeBlack') and
     (ASettings.Theme <> 'ModernLight') and
     (ASettings.Theme <> 'ModernDark') then
    JsonError('$.theme', 'enum', 'Cannot export an unknown theme.');
  if (Ord(ASettings.QuickAccessPosition) < Ord(Low(TRibbonQATPosition))) or
     (Ord(ASettings.QuickAccessPosition) > Ord(High(TRibbonQATPosition))) then
    JsonError('$.quickAccessPosition', 'enum', 'Cannot export an invalid QAT position.');
  if (Ord(ASettings.InputDensity) < Ord(Low(TRibbonInputDensity))) or
     (Ord(ASettings.InputDensity) > Ord(High(TRibbonInputDensity))) then
    JsonError('$.inputDensity', 'enum', 'Cannot export an invalid input density.');
  if IsNan(ASettings.ExpandedHeight) or IsInfinite(ASettings.ExpandedHeight) or
     (ASettings.ExpandedHeight <= 0) then
    JsonError('$.expandedHeight', 'range', 'Cannot export a nonpositive or nonfinite height.');
  if (ASettings.ThemeMode <> 'auto') and (ASettings.ThemeMode <> 'manual') then
    JsonError('$.themeMode', 'enum', 'Cannot export an unknown theme mode.');
  for MetricIndex := Low(ASettings.Metrics) to High(ASettings.Metrics) do
    if not TRibbonMetrics.IsValidValue(ASettings.Metrics[MetricIndex]) then
      JsonError('$.metrics.' + RibbonJsonMetricKeys[MetricIndex], 'range',
        'Cannot export a negative or nonfinite metric.');
  Root := TJSONObject.Create;
  Seen := nil;
  try
    Seen := TDictionary<string, Byte>.Create;
    AddNumber(Root, 'schemaVersion', RibbonJsonSchemaVersion);
    AddText(Root, 'theme', ASettings.Theme);
    if ASettings.HasActiveTabId then
    begin
      if ASettings.ActiveTabId <> '' then
      begin
        Tab := AModel.FindTabById(ASettings.ActiveTabId);
        if (Tab = nil) or not Tab.Visible or not Tab.Enabled then
          JsonError('$.activeTabId', 'reference', 'Cannot export an unavailable active tab.');
      end;
      AddText(Root, 'activeTabId', ASettings.ActiveTabId);
    end;
    AddBool(Root, 'collapsed', ASettings.Collapsed);
    AddBool(Root, 'quickAccessVisible', ASettings.QuickAccessVisible);
    if ASettings.QuickAccessPosition = rqpAbove then AddText(Root, 'quickAccessPosition', 'above')
    else AddText(Root, 'quickAccessPosition', 'below');
    AddText(Root, 'applicationCaption', ASettings.ApplicationCaption);
    AddBool(Root, 'applicationButtonVisible', ASettings.ApplicationButtonVisible);
    AddNumber(Root, 'expandedHeight', ASettings.ExpandedHeight);
    if ASettings.InputDensity = ridPointer then AddText(Root, 'inputDensity', 'pointer')
    else AddText(Root, 'inputDensity', 'touch');
    AddBool(Root, 'reduceMotion', ASettings.ReduceMotion);
    AddText(Root, 'compactCaption', ASettings.CompactCaption);
    { Style keys are written only when they differ from their defaults, so a
      default configuration exports byte-identically to earlier releases. }
    if ASettings.ThemeMode <> 'auto' then
      AddText(Root, 'themeMode', ASettings.ThemeMode);
    if ASettings.InheritFormNativeStyles then
      AddBool(Root, 'inheritFormNativeStyles', True);
    DefaultMetrics := TRibbonMetrics.Defaults;
    MetricsObject := nil;
    for MetricIndex := Low(DefaultMetrics) to High(DefaultMetrics) do
      if ASettings.Metrics[MetricIndex] <> DefaultMetrics[MetricIndex] then
      begin
        if MetricsObject = nil then
        begin
          MetricsObject := TJSONObject.Create;
          Root.AddPair('metrics', MetricsObject);
        end;
        AddNumber(MetricsObject, RibbonJsonMetricKeys[MetricIndex],
          ASettings.Metrics[MetricIndex]);
      end;
    Tabs := TJSONArray.Create;
    Root.AddPair('tabs', Tabs);
    TabIndex := 0;
    for Tab in AModel.Tabs do
    begin
      if Tab.ClassType <> TRibbonTab then
        JsonError('$.tabs.type', 'unknown.type', 'Cannot export an unregistered tab subclass.');
      TabObject := TJSONObject.Create;
      Tabs.AddElement(TabObject);
      WriteCommon(TabObject, Tab, TabIndex);
      AddText(TabObject, 'type', 'tab');
      Groups := TJSONArray.Create;
      TabObject.AddPair('groups', Groups);
      GroupIndex := 0;
      for Group in Tab.Groups do
      begin
        if Group.ClassType <> TRibbonGroup then
          JsonError('$.groups.type', 'unknown.type', 'Cannot export an unregistered group subclass.');
        if Group.PreferredWidth < Group.MinWidth then
          JsonError('$.preferredWidth', 'width', 'Cannot export inconsistent group widths.');
        GroupObject := TJSONObject.Create;
        Groups.AddElement(GroupObject);
        WriteCommon(GroupObject, Group, GroupIndex);
        AddText(GroupObject, 'type', 'group');
        AddNumber(GroupObject, 'minWidth', Group.MinWidth);
        AddNumber(GroupObject, 'preferredWidth', Group.PreferredWidth);
        AddBool(GroupObject, 'pinned', Group.Pinned);
        AddBool(GroupObject, 'allowCompact', Group.AllowCompact);
        AddBool(GroupObject, 'allowCollapse', Group.AllowCollapse);
        AddNumber(GroupObject, 'collapsePriority', Group.CollapsePriority);
        Items := TJSONArray.Create;
        GroupObject.AddPair('items', Items);
        ItemIndex := 0;
        for Item in Group.Items do
        begin
          Items.AddElement(WriteItem(Item, ItemIndex));
          Inc(ItemIndex);
        end;
        Inc(GroupIndex);
      end;
      Inc(TabIndex);
    end;
    Root.AddPair('quickAccess', WriteLinks(AQuickAccess));
    Root.AddPair('applicationMenu', WriteLinks(AApplicationMenu));
    Result := Root.ToJSON;
  finally
    Seen.Free;
    Root.Free;
  end;
end;

end.
