unit CamART.Ribbon.ViewData;

interface

uses
  System.UITypes,
  CamART.Ribbon.Types;

type
  TRibbonViewClickEvent = procedure(Sender: TObject; const AId: string) of object;

  TRibbonTabViewData = record
    Id, Caption: string;
    Visible, Enabled, Selected: Boolean;
  end;

  TRibbonGalleryEntryViewData = record
    Id, Caption, IconKey: string;
    Enabled, Visible: Boolean;
  end;

  { Value-only presentation data. A view never keeps a model-node pointer. }
  TRibbonItemViewData = record
    Id, TypeKey, Caption, Hint, IconKey: string;
    Visible, Enabled, Checked: Boolean;
    ButtonStyle: TRibbonButtonStyle;
    ButtonKind: TRibbonButtonKind;
    Text: string;
    Choices: TArray<string>;
    ItemIndex: Integer;
    Color: TAlphaColor;
    Minimum, Maximum, Value: Single;
    GalleryEntries: TArray<TRibbonGalleryEntryViewData>;
    SelectedId: string;
  end;

  TRibbonGroupViewData = record
    Id, Caption: string;
    Visible, Enabled: Boolean;
    MinWidth, PreferredWidth: Single;
    Pinned, AllowCompact, AllowCollapse: Boolean;
    CollapsePriority: Integer;
    Items: TArray<TRibbonItemViewData>;
  end;

  TRibbonItemInputKind = (rikExecute, rikDropDown, rikText, rikIndex,
    rikColor, rikGallerySelect, rikCheck, rikMouseEnter, rikMouseLeave);

  TRibbonItemInput = record
    Kind: TRibbonItemInputKind;
    Id, Text, SelectedId: string;
    Index: Integer;
    Color: TAlphaColor;
    Checked: Boolean;
  end;

  TRibbonItemInputEvent = procedure(Sender: TObject;
    const AInput: TRibbonItemInput) of object;

implementation

end.
