unit CamART.Ribbon.Editors;

{$B-}

interface

uses
  System.Classes,
  DesignIntf,
  DesignEditors;

type
  TRibbonComponentEditor = class(TComponentEditor)
  public
    procedure Edit; override;
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

  { IDs are written by model creation/import and persisted unchanged. Editing
    a Caption or Name does not break QAT/menu/gallery references. Deliberate
    graph-wide ID migrations belong in application code, not a string edit. }
  TRibbonIdentityProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
  end;

  { Suggestions come from this Ribbon's persisted graph. Unknown application
    icon/command registries may be populated only at runtime; arbitrary icon
    keys remain editable instead of pretending the design-time list is final. }
  TRibbonIconKeyProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  TRibbonTabIdProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  TRibbonItemIdProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const Value: string); override;
  end;

  TRibbonGalleryIdProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const Value: string); override;
  end;

implementation

uses
  System.SysUtils,
  CamART.Ribbon.Model,
  CamART.Ribbon.Control,
  CamART.Ribbon.References,
  CamART.Ribbon.DesignModel,
  CamART.Ribbon.TreeEditor;

procedure TRibbonComponentEditor.Edit;
var
  Ribbon: TCamARTRibbon;
begin
  Ribbon := TRibbonDesignOperations.RibbonFor(Component);
  if Ribbon <> nil then EditRibbonTree(Ribbon, Designer);
end;

function TRibbonComponentEditor.GetVerbCount: Integer;
begin
  Result := 2;
end;

function TRibbonComponentEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Edit Ribbon tree...';
    1: Result := 'Select Ribbon root';
  else
    raise EArgumentOutOfRangeException.Create('Unknown Ribbon editor verb.');
  end;
end;

procedure TRibbonComponentEditor.ExecuteVerb(Index: Integer);
var
  Ribbon: TCamARTRibbon;
begin
  case Index of
    0: Edit;
    1:
      begin
        Ribbon := TRibbonDesignOperations.RibbonFor(Component);
        if Ribbon <> nil then Designer.SelectComponent(Ribbon);
      end;
  else
    raise EArgumentOutOfRangeException.Create('Unknown Ribbon editor verb.');
  end;
end;

function TRibbonIdentityProperty.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paReadOnly];
end;

function TRibbonIconKeyProperty.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paValueList, paSortList];
end;

procedure TRibbonIconKeyProperty.GetValues(Proc: TGetStrProc);
var
  Keys: TStringList;
  I: Integer;
  Ribbon: TCamARTRibbon;
begin
  Proc('');
  Ribbon := TRibbonDesignOperations.RibbonFor(GetComponent(0));
  if Ribbon = nil then Exit;
  Keys := TStringList.Create;
  try
    Keys.CaseSensitive := True;
    Keys.Sorted := True;
    Keys.Duplicates := dupIgnore;
    TRibbonDesignOperations.CollectIconKeys(Ribbon, Keys);
    for I := 0 to Keys.Count - 1 do Proc(Keys[I]);
  finally
    Keys.Free;
  end;
end;

function TRibbonTabIdProperty.GetAttributes: TPropertyAttributes;
begin
  Result := (inherited GetAttributes - [paMultiSelect]) + [paValueList];
end;

procedure TRibbonTabIdProperty.GetValues(Proc: TGetStrProc);
var
  Ribbon: TCamARTRibbon;
  Tab: TRibbonTab;
  HasEligible: Boolean;
begin
  HasEligible := False;
  Ribbon := TRibbonDesignOperations.RibbonFor(GetComponent(0));
  if Ribbon <> nil then
    for Tab in Ribbon.Model.Tabs do
      if Tab.Visible and Tab.Enabled then
      begin
        Proc(Tab.Id);
        HasEligible := True;
      end;
  if not HasEligible then Proc('');
end;

function TRibbonItemIdProperty.GetAttributes: TPropertyAttributes;
begin
  { Single-selection avoids assigning an ID from one Ribbon to another root. }
  Result := (inherited GetAttributes - [paMultiSelect]) + [paValueList];
end;

procedure TRibbonItemIdProperty.GetValues(Proc: TGetStrProc);
var
  Ribbon: TCamARTRibbon;
  Tab: TRibbonTab;
  Group: TRibbonGroup;
  Item: TRibbonItem;
begin
  Proc('');
  Ribbon := TRibbonDesignOperations.RibbonFor(GetComponent(0));
  if Ribbon <> nil then
    for Tab in Ribbon.Model.Tabs do
      for Group in Tab.Groups do
        for Item in Group.Items do
          { QAT/menu references execute button descendants; galleries are
            reached through a gallery-button's GalleryId. }
          if Item is TRibbonButton then Proc(Item.Id);
end;

procedure TRibbonItemIdProperty.SetValue(const Value: string);
var
  Ribbon: TCamARTRibbon;
begin
  Ribbon := TRibbonDesignOperations.RibbonFor(GetComponent(0));
  if (Value <> '') and ((Ribbon = nil) or
     (Ribbon.Model.FindButtonById(Value) = nil)) then
    raise ERibbonDesignError.Create('ItemId must identify a button in this Ribbon.');
  inherited SetValue(Value);
end;

function TRibbonGalleryIdProperty.GetAttributes: TPropertyAttributes;
begin
  Result := (inherited GetAttributes - [paMultiSelect]) + [paValueList];
end;

procedure TRibbonGalleryIdProperty.GetValues(Proc: TGetStrProc);
var
  Ribbon: TCamARTRibbon;
  Tab: TRibbonTab;
  Group: TRibbonGroup;
  Item: TRibbonItem;
begin
  Proc('');
  Ribbon := TRibbonDesignOperations.RibbonFor(GetComponent(0));
  if Ribbon <> nil then
    for Tab in Ribbon.Model.Tabs do
      for Group in Tab.Groups do
        for Item in Group.Items do
          if Item is TRibbonGallery then Proc(Item.Id);
end;

procedure TRibbonGalleryIdProperty.SetValue(const Value: string);
var
  Ribbon: TCamARTRibbon;
begin
  Ribbon := TRibbonDesignOperations.RibbonFor(GetComponent(0));
  if (Value <> '') and ((Ribbon = nil) or
     (Ribbon.Model.FindGalleryById(Value) = nil)) then
    raise ERibbonDesignError.Create('GalleryId must identify a gallery in this Ribbon.');
  inherited SetValue(Value);
end;

end.
