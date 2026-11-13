unit CamART.Ribbon.ViewFactory;

interface

uses
  System.Classes,
  System.Generics.Collections,
  FMX.Controls,
  CamART.Ribbon.ViewData,
  CamART.Ribbon.ItemViews,
  CamART.Ribbon.Icons;

type
  { Registry is the extension seam. The presenter does not switch on model
    classes or item kinds. Register custom keys before creating their views. }
  TRibbonViewFactory = class(TComponent)
  private
    FClasses: TDictionary<string, TRibbonItemViewClass>;
    FIconProvider: IRibbonIconProvider;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RegisterView(const ATypeKey: string; AViewClass: TRibbonItemViewClass);
    procedure UnregisterView(const ATypeKey: string);
    function CreateView(AOwner: TComponent; AParent: TControl;
      const AData: TRibbonItemViewData): TRibbonItemView;
    property IconProvider: IRibbonIconProvider read FIconProvider
      write FIconProvider;
  end;

implementation

uses
  System.SysUtils;

constructor TRibbonViewFactory.Create(AOwner: TComponent);
begin
  inherited;
  FClasses := TDictionary<string, TRibbonItemViewClass>.Create;
  RegisterView('button', TRibbonButtonItemView);
  RegisterView('separator', TRibbonSeparatorItemView);
  RegisterView('label', TRibbonLabelItemView);
  RegisterView('edit', TRibbonEditItemView);
  RegisterView('combo', TRibbonComboItemView);
  RegisterView('colorpicker', TRibbonColorItemView);
  RegisterView('fontpicker', TRibbonComboItemView);
  RegisterView('fontsizepicker', TRibbonComboItemView);
  RegisterView('gallery', TRibbonGalleryItemView);
  RegisterView('checkbox', TRibbonCheckItemView);
  RegisterView('radio', TRibbonRadioItemView);
  RegisterView('progress', TRibbonProgressItemView);
  RegisterView('dropdownmenu', TRibbonButtonItemView);
end;

destructor TRibbonViewFactory.Destroy;
begin
  FIconProvider := nil;
  FClasses.Free;
  inherited;
end;

procedure TRibbonViewFactory.RegisterView(const ATypeKey: string;
  AViewClass: TRibbonItemViewClass);
begin
  if (ATypeKey = '') or (AViewClass = nil) then
    raise EArgumentException.Create('A view registration needs a key and class.');
  if FClasses.ContainsKey(ATypeKey) then
    raise EArgumentException.CreateFmt('Ribbon view key is already registered: %s',
      [ATypeKey]);
  FClasses.Add(ATypeKey, AViewClass);
end;

procedure TRibbonViewFactory.UnregisterView(const ATypeKey: string);
begin
  FClasses.Remove(ATypeKey);
end;

function TRibbonViewFactory.CreateView(AOwner: TComponent; AParent: TControl;
  const AData: TRibbonItemViewData): TRibbonItemView;
var
  ViewClass: TRibbonItemViewClass;
begin
  if AParent = nil then
    raise EArgumentNilException.Create('A Ribbon item view needs a visual parent.');
  if not FClasses.TryGetValue(AData.TypeKey, ViewClass) then
    raise ERibbonItemViewError.CreateFmt('No Ribbon view is registered for %s.',
      [AData.TypeKey]);
  Result := ViewClass.Create(AOwner);
  try
    if Result.Control = nil then
      raise ERibbonItemViewError.Create('A registered adapter created no control.');
    Result.Control.Parent := AParent;
    Result.IconProvider := FIconProvider;
    Result.Apply(AData);
  except
    Result.Free;
    raise;
  end;
end;

end.
