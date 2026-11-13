unit CamART.Ribbon.StyledControls;

{$B-}

interface

uses
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.ListBox,
  FMX.Colors,
  FMX.Layouts,
  CamART.Ribbon.StyleScope;

type
  { These controls retain the FMX control implementation. Only resource
    resolution changes. A missing resource in an explicitly selected book
    must never fall through to the hosting form's different book. }
  TRibbonStyledEdit = class(TEdit, IRibbonStyleSource)
  protected
    function DefinePresentationName: string; override;
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
  end;

  TRibbonStyledComboBox = class(TComboBox, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
    procedure DropDown; override;
  end;

  TRibbonStyledColorComboBox = class(TColorComboBox, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
    procedure DropDown; override;
  end;

  TRibbonStyledLabel = class(TLabel, IRibbonStyleSource)
  private
    FNativeDisabledOpacity: Single;
    FStyleReady: Boolean;
    procedure UpdateThemeEnabled;
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
    procedure ApplyStyle; override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
    procedure RecalcEnabled; override;
  end;

  TRibbonStyledProgressBar = class(TProgressBar, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
  end;

  TRibbonStyledListBox = class(TListBox, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
  end;

  TRibbonStyledListBoxItem = class(TListBoxItem, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
  end;

  TRibbonStyledScrollBox = class(TScrollBox, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
  end;

  TRibbonStyledHorzScrollBox = class(THorzScrollBox, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject; virtual;
  end;

{ A new instance tree with exact native scroll/track/thumb/button classes
  replaced by compatible scoped descendants through this reader only. The
  source remains borrowed; no global class/style registration is changed.
  This copies the native component streaming contract. Runtime-only custom
  properties (for example Source with empty SourceLookup) are not serialized.
  Complete native template/reference equivalence is a native acceptance gate. }
function CloneRibbonNativeStyle(ATemplate: TFmxObject): TFmxObject;

implementation

uses
  System.SysUtils,
  FMX.Controls.Presentation,
  FMX.Edit.Style,
  FMX.Pickers,
  FMX.Presentation.Factory,
  FMX.Presentation.Style,
  CamART.Ribbon.Themes,
  CamART.Ribbon.ThemeStyles,
  CamART.Ribbon.StyleContext;

const
  RibbonEditPresentationName = 'CamARTRibbon-ScopedEdit-Styled';

type
  TRibbonNativeScrollBar = class(TScrollBar, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  TRibbonNativeSmallScrollBar = class(TSmallScrollBar, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  TRibbonNativeTrack = class(TTrack, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  TRibbonNativeThumb = class(TThumb, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  TRibbonNativeSpeedButton = class(TSpeedButton, IRibbonStyleSource)
  protected
    function GetDefaultStyleLookupName: string; override;
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  public
    function GetRibbonStyle(const AClone: Boolean): TFmxObject;
  end;

  TRibbonNativeStyleReader = class
  public
    procedure FindComponentClass(Reader: TReader; const ClassName: string;
      var ComponentClass: TComponentClass);
  end;

  { TEdit is a presented control. Its styled presentation has its own virtual
    GetStyleObject methods; overriding only TEdit is insufficient as a contract.
    Inheriting the actual FMX styled editor preserves caret/IME/selection and
    keyboard behavior while explicitly routing style requests to its owner. }
  TRibbonEditPresentation = class(TStyledEdit)
  protected
    function GetStyleObject: TFmxObject; overload; override;
    function GetStyleObject(const Clone: Boolean): TFmxObject; overload; override;
  end;

procedure TRibbonNativeStyleReader.FindComponentClass(Reader: TReader;
  const ClassName: string; var ComponentClass: TComponentClass);
begin
  { Match exact framework types. A third-party descendant retains its class,
    streaming contract and presentation implementation. OnFindComponentClass
    is a documented per-reader replacement hook for resolved class refs. }
  if (ComponentClass = TScrollBar) or SameText(ClassName, 'TRibbonNativeScrollBar') then
    ComponentClass := TRibbonNativeScrollBar
  else if (ComponentClass = TSmallScrollBar) or
      SameText(ClassName, 'TRibbonNativeSmallScrollBar') then
    ComponentClass := TRibbonNativeSmallScrollBar
  else if (ComponentClass = TTrack) or SameText(ClassName, 'TRibbonNativeTrack') then
    ComponentClass := TRibbonNativeTrack
  else if (ComponentClass = TThumb) or SameText(ClassName, 'TRibbonNativeThumb') then
    ComponentClass := TRibbonNativeThumb
  else if (ComponentClass = TSpeedButton) or
      SameText(ClassName, 'TRibbonNativeSpeedButton') then
    ComponentClass := TRibbonNativeSpeedButton
  else if (ComponentClass = TScrollBox) or
      SameText(ClassName, 'TRibbonStyledScrollBox') then
    ComponentClass := TRibbonStyledScrollBox
  else if (ComponentClass = THorzScrollBox) or
      SameText(ClassName, 'TRibbonStyledHorzScrollBox') then
    ComponentClass := TRibbonStyledHorzScrollBox
  else if (ComponentClass = TListBox) or SameText(ClassName, 'TRibbonStyledListBox') then
    ComponentClass := TRibbonStyledListBox
  else if (ComponentClass = TListBoxItem) or
      SameText(ClassName, 'TRibbonStyledListBoxItem') then
    ComponentClass := TRibbonStyledListBoxItem;
end;

function CloneRibbonNativeStyle(ATemplate: TFmxObject): TFmxObject;
var
  Stream: TMemoryStream;
  Reader: TReader;
  Mapping: TRibbonNativeStyleReader;
  RootClass: TComponentClass;
begin
  Result := nil;
  if ATemplate = nil then Exit;
  Stream := TMemoryStream.Create;
  Mapping := TRibbonNativeStyleReader.Create;
  try
    { Use the standard complete component stream: native published values,
      DefineProperties data and intra-tree references stay with the native
      reader. No shared template is edited or reparented. }
    Stream.WriteComponent(ATemplate);
    Stream.Position := 0;
    Reader := TReader.Create(Stream, 4096);
    try
      Reader.OnFindComponentClass := Mapping.FindComponentClass;
      RootClass := TComponentClass(ATemplate.ClassType);
      Mapping.FindComponentClass(Reader, ATemplate.ClassName, RootClass);
      Result := TFmxObject(RootClass.Create(nil));
      try
        Reader.ReadRootComponent(Result);
      except
        FreeAndNil(Result);
        raise;
      end;
    finally
      Reader.Free;
    end;
  finally
    Mapping.Free;
    Stream.Free;
  end;
end;

function ResolveScopedNativeStyle(AControl: TStyledControl;
  const ADefaultName: string; const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
  Template: TFmxObject;
begin
  Context := FindRibbonStyleContext(AControl);
  if Context <> nil then
  begin
    Template := Context.ResolveNativeStyle(AControl, ADefaultName, False);
    Result := Template;
    if AClone then
    begin
      Result := CloneRibbonNativeStyle(Template);
      try
        Context.BindStyleSources(AControl, Result, Template);
      except
        FreeAndNil(Result);
        raise;
      end;
    end;
    Exit;
  end;

  { A detached/out-of-scope control keeps normal native lookup semantics.
    The public class helper also avoids recursion between the two virtual
    GetStyleObject overloads in a descendant. }
  Result := TStyledControl.LookupStyleObject(AControl, AControl, AControl.Scene,
    AControl.StyleLookup, ADefaultName, AControl.ParentClassStyleLookupName,
    AClone, True);
end;

procedure PrepareComboPopupStyle(AControl: TStyledControl; APopup: TPopup);
var
  Context: TRibbonStyleContext;
begin
  if APopup = nil then Exit;
  Context := FindRibbonStyleContext(AControl);
  if Context <> nil then
    { This is the combo's own popup, not the host form or the global manager.
      Its list, internally created items, and scrollbars therefore inherit
      the same effective book through FMX's native popup style mechanism. }
    APopup.StyleBook := Context.EffectiveStyleBook;
end;

function TRibbonEditPresentation.GetStyleObject: TFmxObject;
begin
  Result := GetStyleObject(True);
end;

function TRibbonEditPresentation.GetStyleObject(const Clone: Boolean): TFmxObject;
var
  Source: IRibbonStyleSource;
begin
  if (PresentedControl <> nil) and
     Supports(PresentedControl, IRibbonStyleSource, Source) then
    Result := Source.GetRibbonStyle(Clone)
  else
    Result := inherited GetStyleObject(Clone);
end;

function TRibbonStyledEdit.DefinePresentationName: string;
begin
  if ControlType = TControlType.Styled then
    Result := RibbonEditPresentationName
  else
    Result := inherited DefinePresentationName;
end;

function TRibbonStyledEdit.GetDefaultStyleLookupName: string;
begin
  Result := 'editstyle';
end;

function TRibbonStyledEdit.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, 'editstyle', AClone);
end;

function TRibbonStyledEdit.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledEdit.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

constructor TRibbonStyledComboBox.Create(AOwner: TComponent);
begin
  inherited;
  { Platform list pickers do not consume FMX StyleBooks. The Ribbon uses the
    standard FMX popup so the selected book remains authoritative on mobile. }
  DropDownKind := TDropDownKind.Custom;
end;

function TRibbonStyledComboBox.GetDefaultStyleLookupName: string;
begin
  Result := 'comboboxstyle';
end;

function TRibbonStyledComboBox.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, 'comboboxstyle', AClone);
end;

function TRibbonStyledComboBox.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledComboBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

procedure TRibbonStyledComboBox.DropDown;
begin
  PrepareComboPopupStyle(Self, Popup);
  inherited;
end;

constructor TRibbonStyledColorComboBox.Create(AOwner: TComponent);
begin
  inherited;
  DropDownKind := TDropDownKind.Custom;
end;

function TRibbonStyledColorComboBox.GetDefaultStyleLookupName: string;
begin
  { TCustomColorComboBox shares TCustomComboBox's native chrome; color cells
    are still produced and maintained by the inherited color control. }
  Result := 'comboboxstyle';
end;

function TRibbonStyledColorComboBox.GetRibbonStyle(
  const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, 'comboboxstyle', AClone);
end;

function TRibbonStyledColorComboBox.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledColorComboBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

procedure TRibbonStyledColorComboBox.DropDown;
begin
  PrepareComboPopupStyle(Self, Popup);
  inherited;
end;

constructor TRibbonStyledLabel.Create(AOwner: TComponent);
begin
  inherited;
  FNativeDisabledOpacity := DisabledOpacity;
  FStyleReady := True;
end;

function TRibbonStyledLabel.GetDefaultStyleLookupName: string;
begin
  Result := 'labelstyle';
end;

function TRibbonStyledLabel.GetRibbonStyle(const AClone: Boolean): TFmxObject;
var
  Context: TRibbonStyleContext;
begin
  Context := FindRibbonStyleContext(Self);
  if Context <> nil then
    Result := Context.ResolveRibbonStyle(Self, rsrLabel, AClone)
  else
    Result := ResolveScopedNativeStyle(Self, 'labelstyle', AClone);
end;

function TRibbonStyledLabel.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledLabel.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

procedure TRibbonStyledLabel.UpdateThemeEnabled;
begin
  if not FStyleReady or (csDestroying in ComponentState) then Exit;
  if FindStyleResource(RibbonThemeMarkerPart) <> nil then
    DisabledOpacity := 1
  else
    DisabledOpacity := FNativeDisabledOpacity;
  ApplyRibbonThemeEnabled(Self, AbsoluteEnabled);
end;

procedure TRibbonStyledLabel.ApplyStyle;
var
  Watch: TRibbonStyleWatch;
begin
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control <> nil then UpdateThemeEnabled;
  finally
    Watch.Free;
  end;
end;

procedure TRibbonStyledLabel.RecalcEnabled;
var
  Watch: TRibbonStyleWatch;
begin
  if not FStyleReady or (csDestroying in ComponentState) then
  begin
    inherited;
    Exit;
  end;
  Watch := TRibbonStyleWatch.Create(Self);
  try
    inherited;
    if Watch.Control <> nil then UpdateThemeEnabled;
  finally
    Watch.Free;
  end;
end;

function TRibbonStyledProgressBar.GetDefaultStyleLookupName: string;
begin
  Result := 'progressbarstyle';
end;

function TRibbonStyledProgressBar.GetRibbonStyle(
  const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, 'progressbarstyle', AClone);
end;

function TRibbonStyledProgressBar.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledProgressBar.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonStyledListBox.GetDefaultStyleLookupName: string;
begin
  Result := 'listboxstyle';
end;

function TRibbonStyledListBox.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, 'listboxstyle', AClone);
end;

function TRibbonStyledListBox.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledListBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonStyledListBoxItem.GetDefaultStyleLookupName: string;
begin
  Result := 'listboxitemstyle';
end;

function TRibbonStyledListBoxItem.GetRibbonStyle(
  const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, 'listboxitemstyle', AClone);
end;

function TRibbonStyledListBoxItem.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledListBoxItem.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonStyledScrollBox.GetDefaultStyleLookupName: string;
begin
  Result := 'scrollboxstyle';
end;

function TRibbonStyledScrollBox.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, GetDefaultStyleLookupName, AClone);
end;

function TRibbonStyledScrollBox.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledScrollBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonStyledHorzScrollBox.GetDefaultStyleLookupName: string;
begin
  Result := inherited GetDefaultStyleLookupName;
end;

function TRibbonStyledHorzScrollBox.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, GetDefaultStyleLookupName, AClone);
end;

function TRibbonStyledHorzScrollBox.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonStyledHorzScrollBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonNativeScrollBar.GetDefaultStyleLookupName: string;
begin
  Result := 'scrollbarstyle';
end;

function TRibbonNativeScrollBar.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, GetDefaultStyleLookupName, AClone);
end;

function TRibbonNativeScrollBar.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonNativeScrollBar.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonNativeSmallScrollBar.GetDefaultStyleLookupName: string;
begin
  Result := 'smallscrollbarstyle';
end;

function TRibbonNativeSmallScrollBar.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, GetDefaultStyleLookupName, AClone);
end;

function TRibbonNativeSmallScrollBar.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonNativeSmallScrollBar.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonNativeTrack.GetDefaultStyleLookupName: string;
begin
  Result := 'trackstyle';
end;

function TRibbonNativeTrack.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, GetDefaultStyleLookupName, AClone);
end;

function TRibbonNativeTrack.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonNativeTrack.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonNativeThumb.GetDefaultStyleLookupName: string;
begin
  Result := 'thumbstyle';
end;

function TRibbonNativeThumb.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, GetDefaultStyleLookupName, AClone);
end;

function TRibbonNativeThumb.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonNativeThumb.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

function TRibbonNativeSpeedButton.GetDefaultStyleLookupName: string;
begin
  Result := 'speedbuttonstyle';
end;

function TRibbonNativeSpeedButton.GetRibbonStyle(const AClone: Boolean): TFmxObject;
begin
  Result := ResolveScopedNativeStyle(Self, GetDefaultStyleLookupName, AClone);
end;

function TRibbonNativeSpeedButton.GetStyleObject: TFmxObject;
begin
  Result := GetRibbonStyle(True);
end;

function TRibbonNativeSpeedButton.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  Result := GetRibbonStyle(Clone);
end;

initialization
  { Register only the private Ribbon presentation name. FMX's standard edit
    registration and unrelated application controls remain untouched. }
  TPresentationProxyFactory.Current.Register(RibbonEditPresentationName,
    TStyledPresentationProxy<TRibbonEditPresentation>);

finalization
  TPresentationProxyFactory.Current.Unregister(RibbonEditPresentationName,
    TStyledPresentationProxy<TRibbonEditPresentation>);

end.
