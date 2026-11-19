unit CamART.Ribbon.Types;

interface

uses
  System.Classes,
  System.Types;

type
  TRibbonChangeKind = (rckStructure, rckMeasure, rckPaint, rckState);
  TRibbonChanges = set of TRibbonChangeKind;
  TRibbonModelChangedEvent = procedure(Sender: TObject;
    const Changes: TRibbonChanges) of object;

  // Presentation size and activation behaviour are independent dimensions.
  TRibbonButtonStyle = (rbsLarge, rbsSmall, rbsIcon);
  TRibbonButtonKind = (rbkPush, rbkToggle, rbkCheck, rbkDropDown, rbkSplit,
    rbkGallery);
  TRibbonQATPosition = (rqpAbove, rqpBelow);
  TRibbonGroupPresentation = (rgpExpanded, rgpCompact, rgpCollapsed);
  TRibbonLayoutMode = (rlmGroups, rlmCompactMenu);
  TRibbonInputDensity = (ridPointer, ridTouch);

  TRibbonTabState = record
    Id: string;
    Visible: Boolean;
    Enabled: Boolean;
  end;

  TRibbonItemMeasure = record
    Id: string;
    Width: Single;
    Height: Single;
    Style: TRibbonButtonStyle;
    { A presenter supplies a separately measured alternative. Unmeasured
      compact values are ignored when CanCompact is False. }
    CanCompact: Boolean;
    CompactWidth: Single;
    CompactHeight: Single;
    CompactStyle: TRibbonButtonStyle;
  end;

  TRibbonGroupMeasure = record
    Id: string;
    CaptionWidth: Single;
    CaptionHeight: Single;
    MinWidth: Single;
    PreferredWidth: Single;
    Pinned: Boolean;
    AllowCompact: Boolean;
    AllowCollapse: Boolean;
    FocusLocked: Boolean;
    CollapsePriority: Integer;
    { Measured launcher dimensions, already in logical coordinates. }
    CollapsedWidth: Single;
    CollapsedHeight: Single;
    Items: TArray<TRibbonItemMeasure>;
  end;

  TRibbonLayoutMetrics = record
    Padding: Single;
    ItemGap: Single;
    GroupGap: Single;
    CaptionHeight: Single;
    { Free space between the item area and the caption band. }
    CaptionGap: Single;
    ContentHeight: Single;
    MinimumItemWidth: Single;
    MinimumItemHeight: Single;
    CompactMenuWidth: Single;
    CompactMenuHeight: Single;
    class function Default: TRibbonLayoutMetrics; static;
  end;

  TRibbonItemPlacement = record
    Id: string;
    // Relative to the containing group's origin.
    Bounds: TRectF;
    Style: TRibbonButtonStyle;
  end;

  TRibbonGroupPlacement = record
    Id: string;
    // Bounds are in scroll-content coordinates. CaptionBounds are local.
    Bounds: TRectF;
    CaptionBounds: TRectF;
    Presentation: TRibbonGroupPresentation;
    Items: TArray<TRibbonItemPlacement>;
  end;

  TRibbonLayoutResult = record
    Mode: TRibbonLayoutMode;
    CompactMenuBounds: TRectF;
    Groups: TArray<TRibbonGroupPlacement>;
    ContentWidth: Single;
    ContentHeight: Single;
    RequiresHorizontalScroll: Boolean;
  end;

implementation

class function TRibbonLayoutMetrics.Default: TRibbonLayoutMetrics;
begin
  Result.Padding := 6;
  Result.ItemGap := 4;
  Result.GroupGap := 6;
  Result.CaptionHeight := 20;
  Result.CaptionGap := 2;
  Result.ContentHeight := 90;
  Result.MinimumItemWidth := 28;
  Result.MinimumItemHeight := 28;
  { FMX composition overrides this with the actual styled menu measurement. }
  Result.CompactMenuWidth := 96;
  Result.CompactMenuHeight := 32;
end;

end.
