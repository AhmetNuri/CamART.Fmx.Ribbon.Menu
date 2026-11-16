unit CamART.Ribbon.Register;

interface

procedure Register;

implementation

uses
  System.Classes,
  System.TypInfo,
  FMX.Types,
  DesignIntf,
  DesignEditors,
  CamART.Ribbon.Model,
  CamART.Ribbon.References,
  CamART.Ribbon.Control,
  CamART.Ribbon.Editors;

procedure Register;
begin
  { Runtime initialization already registers streamable classes. Palette and
    Object Inspector integration live exclusively in this design package. }
  RegisterComponents('CamART', [TCamARTRibbon]);
  GroupDescendentsWith(TRibbonNode, TFmxObject);
  RegisterNoIcon([TRibbonTab, TRibbonGroup, TRibbonButton, TRibbonSeparator,
    TRibbonLabel, TRibbonEdit, TRibbonComboBox, TRibbonColorPicker,
    TRibbonFontPicker, TRibbonFontSizePicker, TRibbonGallery,
    TRibbonCheckBox, TRibbonRadioButton, TRibbonProgressBar,
    TRibbonDropDownMenu, TRibbonSkLabel]);
  RegisterComponentEditor(TCamARTRibbon, TRibbonComponentEditor);
  RegisterComponentEditor(TRibbonNode, TRibbonComponentEditor);
  RegisterPropertyEditor(TypeInfo(string), TRibbonNode, 'Id',
    TRibbonIdentityProperty);
  RegisterPropertyEditor(TypeInfo(string), TRibbonCommandLink, 'Id',
    TRibbonIdentityProperty);
  RegisterPropertyEditor(TypeInfo(string), TRibbonGalleryEntry, 'Id',
    TRibbonIdentityProperty);
  RegisterPropertyEditor(TypeInfo(string), TRibbonNode, 'IconKey',
    TRibbonIconKeyProperty);
  RegisterPropertyEditor(TypeInfo(string), TRibbonCommandLink, 'IconKey',
    TRibbonIconKeyProperty);
  RegisterPropertyEditor(TypeInfo(string), TRibbonGalleryEntry, 'IconKey',
    TRibbonIconKeyProperty);
  RegisterPropertyEditor(TypeInfo(string), TCamARTRibbon, 'ActiveTabId',
    TRibbonTabIdProperty);
  RegisterPropertyEditor(TypeInfo(string), TRibbonCommandLink, 'ItemId',
    TRibbonItemIdProperty);
  RegisterPropertyEditor(TypeInfo(string), TRibbonButton, 'GalleryId',
    TRibbonGalleryIdProperty);
  { Theme, ButtonStyle and ButtonKind use the IDE's native enum editors.
    StyleBook uses the native component-reference editor. Published events
    retain the standard method editor, whose root is the form designer. }
end;

end.
