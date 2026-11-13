unit CamART.Ribbon.Themes;

interface

uses
  System.UITypes;

const
  RibbonThemeContractVersion = 1;

type
  TRibbonTheme = (rtOffice2007Blue, rtOffice2010Blue, rtOfficeSilver,
    rtOfficeBlack, rtModernLight, rtModernDark);

  TRibbonStyleRole = (rsrRoot, rsrGroup, rsrTab, rsrLargeButton,
    rsrSmallButton, rsrIconButton, rsrSplitButton, rsrQuickAccess,
    rsrApplicationButton, rsrCollapsedGroup, rsrMenuItem, rsrGalleryItem,
    rsrPopup, rsrSeparator, rsrLabel, rsrCheckBox, rsrRadioButton);

  { All metrics are FMX logical units. Tokens do not contain controls or
    mutable shared style objects. Zero/transparent is a valid explicit color,
    never an implicit "not assigned" flag. Built-in palettes are opaque. }
  TRibbonThemeTokens = record
    Surface: TAlphaColor;
    SurfaceTop: TAlphaColor;
    GroupSurface: TAlphaColor;
    GroupCaptionSurface: TAlphaColor;
    TabSurface: TAlphaColor;
    ActiveTabSurface: TAlphaColor;
    Text: TAlphaColor;
    MutedText: TAlphaColor;
    DisabledText: TAlphaColor;
    DisabledSurface: TAlphaColor;
    Border: TAlphaColor;
    Separator: TAlphaColor;
    Accent: TAlphaColor;
    HoverSurface: TAlphaColor;
    PressedSurface: TAlphaColor;
    CheckedSurface: TAlphaColor;
    Focus: TAlphaColor;
    ApplicationSurface: TAlphaColor;
    ApplicationHoverSurface: TAlphaColor;
    ApplicationPressedSurface: TAlphaColor;
    ApplicationText: TAlphaColor;
    ApplicationFocus: TAlphaColor;
    FontSize: Single;
    CaptionFontSize: Single;
    PaddingX: Single;
    PaddingY: Single;
    GroupPadding: Single;
    TabHeight: Single;
    ButtonCornerRadius: Single;
    GroupCornerRadius: Single;
    BorderThickness: Single;
    FocusThickness: Single;
    LargeIconSize: Single;
    SmallIconSize: Single;
    IconOnlySize: Single;
    UseSurfaceGradient: Boolean;
    TabBold: Boolean;
    CaptionBold: Boolean;
  end;

function RibbonThemeName(ATheme: TRibbonTheme): string;
function RibbonThemeTokens(ATheme: TRibbonTheme): TRibbonThemeTokens;
function RibbonThemeStyleName(ARole: TRibbonStyleRole): string;
procedure ValidateRibbonThemeTokens(const ATokens: TRibbonThemeTokens);
{ Contrast requires opaque actual foreground/background samples. For custom
  alpha colors, composite onto the actual rendered surface before calling.
  This calculation alone is not a WCAG conformance or native render test. }
function RibbonContrastRatio(AForeground, ABackground: TAlphaColor): Double;

implementation

uses
  System.Math,
  System.SysUtils;

function RibbonThemeName(ATheme: TRibbonTheme): string;
begin
  case ATheme of
    rtOffice2007Blue: Result := 'Office 2007 Blue';
    rtOffice2010Blue: Result := 'Office 2010 Blue';
    rtOfficeSilver: Result := 'Office Silver';
    rtOfficeBlack: Result := 'Office Black';
    rtModernLight: Result := 'Modern Light';
    rtModernDark: Result := 'Modern Dark';
  else
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon theme.');
  end;
end;

function RibbonThemeStyleName(ARole: TRibbonStyleRole): string;
begin
  case ARole of
    rsrRoot: Result := 'camartribbonstyle';
    rsrGroup: Result := 'camartribbongroupstyle';
    rsrTab: Result := 'camartribbontabstyle';
    rsrLargeButton: Result := 'camartribbonlargebuttonstyle';
    rsrSmallButton: Result := 'camartribbonsmallbuttonstyle';
    rsrIconButton: Result := 'camartribboniconbuttonstyle';
    rsrSplitButton: Result := 'camartribbonsplitbuttonstyle';
    rsrQuickAccess: Result := 'camartribbonqatstyle';
    rsrApplicationButton: Result := 'camartribbonapplicationbuttonstyle';
    rsrCollapsedGroup: Result := 'camartribboncollapsedgroupstyle';
    rsrMenuItem: Result := 'camartribbonmenuitemstyle';
    rsrGalleryItem: Result := 'camartribbongalleryitemstyle';
    rsrPopup: Result := 'camartribbonpopupstyle';
    rsrSeparator: Result := 'camartribbonseparatorstyle';
    rsrLabel: Result := 'camartribbonlabelstyle';
    rsrCheckBox: Result := 'camartribboncheckboxstyle';
    rsrRadioButton: Result := 'camartribbonradiobuttonstyle';
  else
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon style role.');
  end;
end;

function RibbonThemeTokens(ATheme: TRibbonTheme): TRibbonThemeTokens;
begin
  Result := Default(TRibbonThemeTokens);
  case ATheme of
    rtOffice2007Blue:
      begin
        Result.Surface := TAlphaColor($FFD6E5F7);
        Result.SurfaceTop := TAlphaColor($FFEBF3FD);
        Result.GroupSurface := TAlphaColor($FFF6F9FD);
        Result.GroupCaptionSurface := TAlphaColor($FFDCE8F6);
        Result.TabSurface := TAlphaColor($FFC5D9F0);
        Result.ActiveTabSurface := TAlphaColor($FFF8FBFF);
        Result.Text := TAlphaColor($FF162C46);
        Result.MutedText := TAlphaColor($FF354B63);
        Result.DisabledText := TAlphaColor($FF4E5C70);
        Result.DisabledSurface := TAlphaColor($FFE5EBF2);
        Result.Border := TAlphaColor($FF8CA7C8);
        Result.Separator := TAlphaColor($FF8BA2BC);
        Result.Accent := TAlphaColor($FF174F8A);
        Result.HoverSurface := TAlphaColor($FFEAF3FF);
        Result.PressedSurface := TAlphaColor($FFBED6F1);
        Result.CheckedSurface := TAlphaColor($FFCEE2F8);
        Result.Focus := TAlphaColor($FF123F73);
        Result.ApplicationSurface := TAlphaColor($FF205C9E);
        Result.ApplicationHoverSurface := TAlphaColor($FF174B84);
        Result.ApplicationPressedSurface := TAlphaColor($FF103763);
        Result.ApplicationText := TAlphaColor($FFFFFFFF);
        Result.ApplicationFocus := TAlphaColor($FFE5F3FF);
        Result.FontSize := 12;
        Result.CaptionFontSize := 11;
        Result.PaddingX := 8;
        Result.PaddingY := 6;
        Result.GroupPadding := 7;
        Result.TabHeight := 36;
        Result.ButtonCornerRadius := 4;
        Result.GroupCornerRadius := 4;
        Result.BorderThickness := 1;
        Result.FocusThickness := 2;
        Result.LargeIconSize := 32;
        Result.SmallIconSize := 16;
        Result.IconOnlySize := 24;
        Result.UseSurfaceGradient := True;
        Result.TabBold := True;
        Result.CaptionBold := False;
      end;
    rtOffice2010Blue:
      begin
        Result.Surface := TAlphaColor($FFE5EEF9);
        Result.SurfaceTop := TAlphaColor($FFF3F7FC);
        Result.GroupSurface := TAlphaColor($FFFBFCFE);
        Result.GroupCaptionSurface := TAlphaColor($FFE5EDF7);
        Result.TabSurface := TAlphaColor($FFD8E5F4);
        Result.ActiveTabSurface := TAlphaColor($FFFFFFFF);
        Result.Text := TAlphaColor($FF1A2D43);
        Result.MutedText := TAlphaColor($FF40546D);
        Result.DisabledText := TAlphaColor($FF536276);
        Result.DisabledSurface := TAlphaColor($FFEDF1F6);
        Result.Border := TAlphaColor($FFA5B8D1);
        Result.Separator := TAlphaColor($FF9CAFC7);
        Result.Accent := TAlphaColor($FF215A94);
        Result.HoverSurface := TAlphaColor($FFE7F1FD);
        Result.PressedSurface := TAlphaColor($FFC9DDF4);
        Result.CheckedSurface := TAlphaColor($FFD7E8FA);
        Result.Focus := TAlphaColor($FF16497E);
        Result.ApplicationSurface := TAlphaColor($FF24639E);
        Result.ApplicationHoverSurface := TAlphaColor($FF1D558A);
        Result.ApplicationPressedSurface := TAlphaColor($FF16416C);
        Result.ApplicationText := TAlphaColor($FFFFFFFF);
        Result.ApplicationFocus := TAlphaColor($FFFFFFFF);
        Result.FontSize := 12;
        Result.CaptionFontSize := 11;
        Result.PaddingX := 9;
        Result.PaddingY := 5;
        Result.GroupPadding := 6;
        Result.TabHeight := 34;
        Result.ButtonCornerRadius := 2;
        Result.GroupCornerRadius := 3;
        Result.BorderThickness := 1;
        Result.FocusThickness := 2;
        Result.LargeIconSize := 32;
        Result.SmallIconSize := 16;
        Result.IconOnlySize := 24;
        Result.UseSurfaceGradient := True;
        Result.TabBold := False;
        Result.CaptionBold := False;
      end;
    rtOfficeSilver:
      begin
        Result.Surface := TAlphaColor($FFE9EBF0);
        Result.SurfaceTop := TAlphaColor($FFF7F8FA);
        Result.GroupSurface := TAlphaColor($FFFCFCFD);
        Result.GroupCaptionSurface := TAlphaColor($FFE2E5EC);
        Result.TabSurface := TAlphaColor($FFD9DDE5);
        Result.ActiveTabSurface := TAlphaColor($FFFFFFFF);
        Result.Text := TAlphaColor($FF242735);
        Result.MutedText := TAlphaColor($FF484D60);
        Result.DisabledText := TAlphaColor($FF5A6070);
        Result.DisabledSurface := TAlphaColor($FFECEEF3);
        Result.Border := TAlphaColor($FFA5ACBC);
        Result.Separator := TAlphaColor($FF989FB0);
        Result.Accent := TAlphaColor($FF584B91);
        Result.HoverSurface := TAlphaColor($FFEFEBFA);
        Result.PressedSurface := TAlphaColor($FFD7D1EC);
        Result.CheckedSurface := TAlphaColor($FFE4DEF4);
        Result.Focus := TAlphaColor($FF453973);
        Result.ApplicationSurface := TAlphaColor($FF594A8D);
        Result.ApplicationHoverSurface := TAlphaColor($FF4E407E);
        Result.ApplicationPressedSurface := TAlphaColor($FF3A2F61);
        Result.ApplicationText := TAlphaColor($FFFFFFFF);
        Result.ApplicationFocus := TAlphaColor($FFFFFFFF);
        Result.FontSize := 12;
        Result.CaptionFontSize := 11;
        Result.PaddingX := 8;
        Result.PaddingY := 5;
        Result.GroupPadding := 6;
        Result.TabHeight := 34;
        Result.ButtonCornerRadius := 3;
        Result.GroupCornerRadius := 3;
        Result.BorderThickness := 1;
        Result.FocusThickness := 2;
        Result.LargeIconSize := 32;
        Result.SmallIconSize := 16;
        Result.IconOnlySize := 24;
        Result.UseSurfaceGradient := True;
        Result.TabBold := False;
        Result.CaptionBold := False;
      end;
    rtOfficeBlack:
      begin
        Result.Surface := TAlphaColor($FF353A43);
        Result.SurfaceTop := TAlphaColor($FF4A505B);
        Result.GroupSurface := TAlphaColor($FF424852);
        Result.GroupCaptionSurface := TAlphaColor($FF373D47);
        Result.TabSurface := TAlphaColor($FF303640);
        Result.ActiveTabSurface := TAlphaColor($FF4D5664);
        Result.Text := TAlphaColor($FFF5F7FA);
        Result.MutedText := TAlphaColor($FFD2DAE4);
        Result.DisabledText := TAlphaColor($FFB7C2D0);
        Result.DisabledSurface := TAlphaColor($FF3B424D);
        Result.Border := TAlphaColor($FF8490A0);
        Result.Separator := TAlphaColor($FF8894A5);
        Result.Accent := TAlphaColor($FFB8D5FB);
        Result.HoverSurface := TAlphaColor($FF4B5667);
        Result.PressedSurface := TAlphaColor($FF556174);
        Result.CheckedSurface := TAlphaColor($FF455C78);
        Result.Focus := TAlphaColor($FFC3DFFF);
        Result.ApplicationSurface := TAlphaColor($FF4F5A6C);
        Result.ApplicationHoverSurface := TAlphaColor($FF5B677A);
        Result.ApplicationPressedSurface := TAlphaColor($FF3B4658);
        Result.ApplicationText := TAlphaColor($FFFFFFFF);
        Result.ApplicationFocus := TAlphaColor($FFFFFFFF);
        Result.FontSize := 12;
        Result.CaptionFontSize := 11;
        Result.PaddingX := 9;
        Result.PaddingY := 6;
        Result.GroupPadding := 7;
        Result.TabHeight := 36;
        Result.ButtonCornerRadius := 2;
        Result.GroupCornerRadius := 3;
        Result.BorderThickness := 1;
        Result.FocusThickness := 2;
        Result.LargeIconSize := 32;
        Result.SmallIconSize := 16;
        Result.IconOnlySize := 24;
        Result.UseSurfaceGradient := True;
        Result.TabBold := True;
        Result.CaptionBold := False;
      end;
    rtModernLight:
      begin
        Result.Surface := TAlphaColor($FFF4F6F9);
        Result.SurfaceTop := TAlphaColor($FFFFFFFF);
        Result.GroupSurface := TAlphaColor($FFFFFFFF);
        Result.GroupCaptionSurface := TAlphaColor($FFEDF1F6);
        Result.TabSurface := TAlphaColor($FFE6ECF4);
        Result.ActiveTabSurface := TAlphaColor($FFFFFFFF);
        Result.Text := TAlphaColor($FF1A2636);
        Result.MutedText := TAlphaColor($FF46566D);
        Result.DisabledText := TAlphaColor($FF5A6677);
        Result.DisabledSurface := TAlphaColor($FFEBEFF4);
        Result.Border := TAlphaColor($FFA7B5C7);
        Result.Separator := TAlphaColor($FFA4B0C0);
        Result.Accent := TAlphaColor($FF005FB8);
        Result.HoverSurface := TAlphaColor($FFE0EEFF);
        Result.PressedSurface := TAlphaColor($FFC2DDFC);
        Result.CheckedSurface := TAlphaColor($FFD6E8FF);
        Result.Focus := TAlphaColor($FF004B92);
        Result.ApplicationSurface := TAlphaColor($FF0056A6);
        Result.ApplicationHoverSurface := TAlphaColor($FF004B92);
        Result.ApplicationPressedSurface := TAlphaColor($FF003A72);
        Result.ApplicationText := TAlphaColor($FFFFFFFF);
        Result.ApplicationFocus := TAlphaColor($FFFFFFFF);
        Result.FontSize := 13;
        Result.CaptionFontSize := 12;
        Result.PaddingX := 10;
        Result.PaddingY := 7;
        Result.GroupPadding := 8;
        Result.TabHeight := 38;
        Result.ButtonCornerRadius := 6;
        Result.GroupCornerRadius := 6;
        Result.BorderThickness := 1;
        Result.FocusThickness := 2;
        Result.LargeIconSize := 32;
        Result.SmallIconSize := 18;
        Result.IconOnlySize := 24;
        Result.UseSurfaceGradient := False;
        Result.TabBold := False;
        Result.CaptionBold := False;
      end;
    rtModernDark:
      begin
        Result.Surface := TAlphaColor($FF17212E);
        Result.SurfaceTop := TAlphaColor($FF101923);
        Result.GroupSurface := TAlphaColor($FF202C3B);
        Result.GroupCaptionSurface := TAlphaColor($FF263346);
        Result.TabSurface := TAlphaColor($FF1B2737);
        Result.ActiveTabSurface := TAlphaColor($FF2C3E54);
        Result.Text := TAlphaColor($FFF4F8FD);
        Result.MutedText := TAlphaColor($FFC4CFDE);
        Result.DisabledText := TAlphaColor($FFB1BDCE);
        Result.DisabledSurface := TAlphaColor($FF273346);
        Result.Border := TAlphaColor($FF60738D);
        Result.Separator := TAlphaColor($FF778AA4);
        Result.Accent := TAlphaColor($FF8EC9FF);
        Result.HoverSurface := TAlphaColor($FF30435B);
        Result.PressedSurface := TAlphaColor($FF3C526F);
        Result.CheckedSurface := TAlphaColor($FF2A4667);
        Result.Focus := TAlphaColor($FFB2DDFF);
        Result.ApplicationSurface := TAlphaColor($FF1E5C96);
        Result.ApplicationHoverSurface := TAlphaColor($FF2469A9);
        Result.ApplicationPressedSurface := TAlphaColor($FF16466F);
        Result.ApplicationText := TAlphaColor($FFFFFFFF);
        Result.ApplicationFocus := TAlphaColor($FFFFFFFF);
        Result.FontSize := 13;
        Result.CaptionFontSize := 12;
        Result.PaddingX := 10;
        Result.PaddingY := 7;
        Result.GroupPadding := 9;
        Result.TabHeight := 38;
        Result.ButtonCornerRadius := 5;
        Result.GroupCornerRadius := 5;
        Result.BorderThickness := 1;
        Result.FocusThickness := 2;
        Result.LargeIconSize := 32;
        Result.SmallIconSize := 18;
        Result.IconOnlySize := 24;
        Result.UseSurfaceGradient := False;
        Result.TabBold := False;
        Result.CaptionBold := False;
      end;
  else
    raise EArgumentOutOfRangeException.Create('Invalid Ribbon theme.');
  end;
  ValidateRibbonThemeTokens(Result);
end;

procedure ValidateRibbonThemeTokens(const ATokens: TRibbonThemeTokens);
  procedure RequirePositive(AValue: Single; const AName: string);
  begin
    if IsNan(AValue) or IsInfinite(AValue) or (AValue <= 0) then
      raise EArgumentOutOfRangeException.Create(AName + ' must be finite and positive.');
  end;
  procedure RequireNonnegative(AValue: Single; const AName: string);
  begin
    if IsNan(AValue) or IsInfinite(AValue) or (AValue < 0) then
      raise EArgumentOutOfRangeException.Create(AName + ' must be finite and nonnegative.');
  end;
begin
  RequirePositive(ATokens.FontSize, 'FontSize');
  RequirePositive(ATokens.CaptionFontSize, 'CaptionFontSize');
  RequireNonnegative(ATokens.PaddingX, 'PaddingX');
  RequireNonnegative(ATokens.PaddingY, 'PaddingY');
  RequireNonnegative(ATokens.GroupPadding, 'GroupPadding');
  RequirePositive(ATokens.TabHeight, 'TabHeight');
  RequireNonnegative(ATokens.ButtonCornerRadius, 'ButtonCornerRadius');
  RequireNonnegative(ATokens.GroupCornerRadius, 'GroupCornerRadius');
  RequireNonnegative(ATokens.BorderThickness, 'BorderThickness');
  RequirePositive(ATokens.FocusThickness, 'FocusThickness');
  RequirePositive(ATokens.LargeIconSize, 'LargeIconSize');
  RequirePositive(ATokens.SmallIconSize, 'SmallIconSize');
  RequirePositive(ATokens.IconOnlySize, 'IconOnlySize');
end;

function RibbonContrastRatio(AForeground, ABackground: TAlphaColor): Double;
  function LinearChannel(AChannel: Byte): Double;
  var
    SRGB: Double;
  begin
    SRGB := AChannel / 255.0;
    if SRGB <= 0.04045 then Result := SRGB / 12.92
    else Result := Power((SRGB + 0.055) / 1.055, 2.4);
  end;
  function Luminance(AColor: TAlphaColor): Double;
  var
    Value: Cardinal;
  begin
    Value := Cardinal(AColor);
    if (Value shr 24) <> $FF then
      raise EArgumentException.Create(
        'Contrast needs opaque foreground/background samples after alpha compositing.');
    Result := 0.2126 * LinearChannel(Byte((Value shr 16) and $FF)) +
      0.7152 * LinearChannel(Byte((Value shr 8) and $FF)) +
      0.0722 * LinearChannel(Byte(Value and $FF));
  end;
var
  Foreground, Background: Double;
begin
  { W3C WCAG 2.2 sRGB relative luminance and contrast definition:
    https://www.w3.org/WAI/WCAG21/Understanding/relative-luminance.html
    Use the current 0.04045 transfer-function breakpoint, without rounding
    a computed ratio up to an acceptance threshold. }
  Foreground := Luminance(AForeground);
  Background := Luminance(ABackground);
  Result := (Max(Foreground, Background) + 0.05) /
    (Min(Foreground, Background) + 0.05);
end;

end.
