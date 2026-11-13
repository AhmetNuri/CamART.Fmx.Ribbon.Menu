# CamART.Fmx.Ribbon.Menu
 Ribbon Menu Component For Firemonkey
# CamART FMX Ribbon 

**Delphi 13.1 / 13.2 Florence | Installation, Features, Architecture, Usage, Testing, and Release Notes**

**Source version:** `0.7.0-source`  
**Original distribution:** `0.7.0-source+delphi13.2-r1` (November 3, 2026)  
**SVG support update:** November 4, 2026

> **Scope and verification notice:** This document combines the original `README.md` and `00_KURULUM_DELPHI_13_2.md`, translated into English. The newer Delphi 13.1 / 13.x installation corrections take precedence over the historical Delphi 13.2 packaging instructions where they differ. The package is a **source distribution**; native Delphi compilation, BPL loading, IDE acceptance, GUI/device tests, and production qualification were **not performed** in the source preparation environment. Do not interpret source checks as completed native validation.

## 1. Current installation instructions (Delphi 13.1 and 13.x)

### 1.1 Updated BPL locations and the “BPL not found” fix

The package projects can also be built with Delphi 13.1. `VER370` and the `370` package suffix remain unchanged. Package BPL output now goes to Delphi's standard BPL search directories:

| IDE architecture | Current Design BPL location |
|---|---|
| 32-bit IDE (Win32) | `$(BDSCOMMONDIR)\Bpl\CamARTRibbonDesign370.bpl` |
| 64-bit IDE (Win64) | `$(BDSCOMMONDIR)\Bpl\Win64\CamARTRibbonDesign370.bpl` |

The usual `BDSCOMMONDIR` location is `C:\Users\Public\Documents\Embarcadero\Studio\37.0`.

Rebuild **Core, FMX, and Design** with the same compiler and matching IDE architecture. In **Component > Install Packages > Add**, install **only the Design package**. The standard BPL directory must be available in the IDE process's Windows `PATH`; adding it only to the Delphi Library/Search path does not allow Windows to resolve BPL dependencies.

For current, potentially modified sources, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build\Verify-Windows.ps1 -Platform Win32 -Configuration Release
```

For the 64-bit IDE, use `-Platform Win64`. Historical helper names containing `13_2`, and the `Delphi13.2` label used for intermediate DCP/DCU directories, are retained for backward compatibility. Those labels do not themselves require the Delphi 13.2 compiler. If the package group is already open in the IDE, reopen it to reload updated project options.

**Precedence rule:** The standard BPL directories above replace the local BPL paths appearing in the original 13.2 instructions later in this document. Use `Verify-Windows.ps1` rather than the original manifest-checked `Build-Windows.ps1` when building modified sources. The historical commands are retained for reference to the original, unmodified distribution.

### 1.2 Choose the correct IDE architecture

The installed **Design package must match the architecture of the running IDE**, regardless of the target architecture of an application you develop:

| Running IDE | Design package target | Current Design BPL |
|---|---|---|
| `bin\bds.exe` (32-bit IDE) | Win32 / Release | `$(BDSCOMMONDIR)\Bpl\CamARTRibbonDesign370.bpl` |
| `bin64\bds.exe` (64-bit IDE) | Win64 / Release | `$(BDSCOMMONDIR)\Bpl\Win64\CamARTRibbonDesign370.bpl` |

For example, when developing a Win64 application inside the 32-bit IDE, install the **Win32 Design package** in the IDE and separately build the application for Win64. If you use both IDE architectures, build and install the appropriate package for each.

Delphi 13 family identifiers are `VER370`, BDS/CompilerVersion `37.0`, and package suffix `370`. These **do not distinguish** Delphi 13.0, 13.1, and 13.2. Check **Help > About** for the installed point release. `Delphi.Personality.12`, `ProjectFileVersion=12`, and `ProjectVersion=20.1` are project-format fields, not product-version numbers; they were not indiscriminately changed to 13.2/37.

### 1.3 Extract and build

Extract the archive without changing its relative folder structure; for example:

```text
C:\Components\CamARTRibbon_Delphi13_2
```

Keep `Source`, `Design`, `Packages`, `Build`, `Demo`, and the other directories together.

**Original unmodified 13.2 distribution procedure:** Run the first manifest-aware helper build before opening and saving project files in the IDE. Saving converted `.dproj` files changes their content and invalidates the manifest hash of the original snapshot. From the matching **RAD Studio Command Prompt**:

```bat
cd /d C:\Components\CamARTRibbon_Delphi13_2
rem Original 13.2 Win32 helper:
Build\Build-Delphi13_2-Win32.cmd
rem Alternatively, original 13.2 Win64 helper:
Build\Build-Delphi13_2-Win64.cmd
```

Those original helpers build five packages in dependency order in Release mode; they do not prove that demo/test applications ran or that the package was installed successfully. They require the RAD Studio build environment, stop on MSBuild/compiler errors, and do not change the PowerShell execution policy.

For the **current, updated source tree**, prefer the `Verify-Windows.ps1` command in §1.1, which supports the updated BPL locations.

The original optional no-JSON package build was:

```powershell
powershell -NoProfile -File .\Build\Build-Windows.ps1 -Platform Win32 -Configuration Release -PackagesOnly -SkipJson -BuildDesign -DesignPlatform Win32
```

Use `Win64` for both platform arguments when targeting the 64-bit IDE. This builds Core + FMX + Design without the JSON packages. This is a **historical command**; for edited sources, first use the updated verification/build flow.

### 1.4 Launch the IDE and install the component

For the **original** local-BPL distribution layout, the package-path-aware launcher was:

```powershell
powershell -NoProfile -File .\Build\Start-Delphi13_2.ps1 -IdePlatform Win32
# Or:
powershell -NoProfile -File .\Build\Start-Delphi13_2.ps1 -IdePlatform Win64
```

The launcher validates the appropriate `bds.exe` and package architecture, adds the Release package directory only to the **new IDE process's PATH**, and opens the package group. It does not change the permanent system PATH or package registry. An already running IDE can prevent the updated environment from being applied, so close IDE sessions after saving work before invoking this original launcher. It does not terminate processes itself.

For the **current standardized BPL layout**, ensure the corresponding `$(BDSCOMMONDIR)\Bpl` or `$(BDSCOMMONDIR)\Bpl\Win64` directory is visible to the IDE process, then open the relevant IDE. Do not mix 32-bit and 64-bit BPL paths in the same IDE process. Copying CamART binaries into Delphi's `bin`/`bin64` directories is unnecessary.

In the IDE:

1. Open **Component > Install Packages > Add**.
2. Select `CamARTRibbonDesign370.bpl` from the **current standard path** in §1.1.
3. Install **Design only**. Core/FMX (and optional other runtime packages) are dependencies; do not separately install them as IDE design-time packages.
4. If an older CamART Design package registers the same classes, remove that old package first. Do not load two competing Design versions into one IDE session.
5. Confirm **CamART → TCamARTRibbon** appears in the **Tool Palette**.
6. Add the control to an FMX form; open **Edit Ribbon tree...** from its context menu or by double-clicking, add a tab/group/item, then **save, close, and reopen** the form to verify streaming and IDE integration.

These steps are required **native IDE acceptance checks**, not previously executed test results.

### 1.5 Application search paths and deployment

When compiling directly from source, add these paths in **Project Options > Delphi Compiler > Search path**:

```text
C:\Components\CamARTRibbon_Delphi13_2\Source\Core
C:\Components\CamARTRibbon_Delphi13_2\Source\FMX
```

If importing/exporting JSON, also add:

```text
C:\Components\CamARTRibbon_Delphi13_2\Source\Serialization
```

Do **not** add `Design` or IDE `ToolsAPI` sources to an application. Runtime code does not require `designide`. Provided demos already contain the source paths. Deploying CamART BPLs is not mandatory when compiling the application directly with source/static linking.

If using precompiled DCUs/DCPs instead, supply the matching platform/configuration `Packages` directory and the `CamARTRibbonCore\DCU`, `CamARTRibbonFMX\DCU`, and any required JSON-package `DCU` folders. If runtime packages are enabled, use **unsuffixed** package names in application package dependencies and ship the corresponding `*370.bpl` files. Never mix Win32/Win64, Debug/Release, or different Delphi compiler builds.

### 1.6 Package dependencies and build order

| Order | Project | Generated BPL | Function |
|---|---|---|---|
| 1 | `CamARTRibbonCore.dproj` | `CamARTRibbonCore370.bpl` | RTL models and services |
| 2 | `CamARTRibbonFMX.dproj` | `CamARTRibbonFMX370.bpl` | FMX component and views |
| 3 | `CamARTRibbonJSON.dproj` | `CamARTRibbonJSON370.bpl` | Optional JSON codec |
| 4 | `CamARTRibbonJSONFMX.dproj` | `CamARTRibbonJSONFMX370.bpl` | Optional JSON-to-FMX adapter |
| 5 | `CamARTRibbonDesign.dproj` | `CamARTRibbonDesign370.bpl` | IDE-installable design package |

Package group: [`Packages/CamARTRibbon_Delphi13_2.groupproj`](Packages/CamARTRibbon_Delphi13_2.groupproj). The group supports both Windows architectures; its default command-line configuration is Win32 / Release, which may be overridden:

```bat
MSBuild Packages\CamARTRibbon_Delphi13_2.groupproj /t:Build /p:Config=Release /p:Platform=Win64
```

`LIBSUFFIX '370'` versions the **BPL filename only**; DCP filenames such as `CamARTRibbonCore.dcp` and `requires` package names remain unsuffixed. The original distribution kept separate outputs for 14 projects under `Build\Delphi13.2\<Platform>\<Config>`; the current standard BPL output rule in §1.1 supersedes its historical `Packages` BPL location.

### 1.7 Troubleshooting

| Symptom or error | Checks and actions |
|---|---|
| BDS / Delphi targets not found | Use the RAD Studio Command Prompt corresponding to the installed Delphi release. |
| `VER370` or compiler-family mismatch | Check **Help > About**, selected compiler environment and BDS executable path. |
| Package or DCP not found | Verify Core → FMX → optional packages → Design build order and consistent architecture/configuration. |
| BPL failed to load or wrong image format | Match the IDE and BPL architectures; verify that Core/FMX dependencies can be resolved through the IDE process `PATH`. |
| “BPL not found” despite Library/Search path entries | Add the correct **standard BPL directory** to the IDE's Windows `PATH`; Library/Search path does not resolve DLL/BPL loads. |
| Source changed / manifest mismatch | Inspect actual changes, including a saved `.dproj`; use the current `Verify-Windows.ps1` for modified sources. |
| Unit not found in application | Check Core/FM X Search paths and optional Serialization path. |
| Component class already registered | Uninstall the old CamART Design package before installing the replacement. |

If a Pascal compile error occurs, retain the **complete message, unit name, source line, exact Delphi build number, and target architecture**. Do not claim successful native compilation merely because source or package settings were inspected. Do not delete or edit earlier evidence/hash files to manufacture successful results.

## 2. Product overview

CamART FMX Ribbon is a native FireMonkey Ribbon component inspired by Office 2007/2010 layouts, implemented in **Object Pascal / RTL / FMX**. The platform-independent Core has no FMX dependency. The component supports **13 built-in item types**, three button sizes, six behavior types, Quick Access Toolbar (QAT), Application Menu, Action adapters, icon and font providers, responsive layouts, StyleBooks, native editors, optional JSON persistence, and IDE integration.

**Limitations:** Menus currently use a **flat list**, not Office Backstage or nested submenus. The font provider offers a configured name catalog; it does not claim OS-level discovery of installed fonts. SVG rendering uses Delphi's Skia integration. Canonical JSON v2 covers only the documented 13 built-in types; it does not silently degrade an unknown custom subclass into a base type. Only Windows Win32/Win64 package settings are supplied here; additional targets require SDK, deployment and native-device verification. FMXLinux on Linux has separate prerequisites.

## 3. StyleBook precedence and themes

**Precedence:** If `Ribbon.StyleBook` is assigned, **the component's own StyleBook wins**. Otherwise the Ribbon inherits the **form/scene StyleBook**.

| `Ribbon.StyleBook` | `Form.StyleBook` | Effective StyleBook |
|---|---|---|
| A | B or `nil` | A |
| `nil` | B | B |
| `nil` | `nil` | Ribbon theme preset / native application-platform fallback |

`Theme` provides a fallback for missing Ribbon resources, but does **not override** resources present in the selected book. `StyleLookup` is preserved and searched first within the selected book. If a resource is missing in the component's book, the Ribbon does **not** switch to a different form book for that resource. Clearing or freeing the component's book restores form inheritance. Shared StyleBooks and application-global styles are not modified.

```pascal
Form1.StyleBook := FormStyleBook;
Ribbon.StyleBook := RibbonStyleBook; // Component selection takes precedence.
Ribbon.StyleBook := nil;             // Inherit the form's StyleBook again.
```

Six themes are provided: **Office 2007 Blue, Office 2010 Blue, Office Silver, Office Black, Modern Light, and Modern Dark**. To use one as a separate StyleBook:

```pascal
// uses CamART.Ribbon.Themes, CamART.Ribbon.ThemeStyles;
DarkBook := CreateRibbonThemeStyleBook(Self, rtModernDark);
Ribbon.StyleBook := DarkBook;
// Reuse this StyleBook object rather than creating a new one on every change.
```

If you edit resources inside the same StyleBook object, call `Ribbon.RefreshTheme`.

Stage 5 added 17 fixed Ribbon visual roles, typography/padding/icon/state metrics; published `StyleBook` and `Theme`; read-only `EffectiveStyleBook` and `StyleDiagnostics`; explicit `RefreshTheme`; per-Ribbon style contexts with weak book tracking; ownership-aware copies and filtered invalidation. Styles cover root, group, tab, button, checkbox, radio, label, QAT, menu, gallery, separator, and popups, with scoped adapters preserving native edit/combo/list/scroll semantics. Switching themes refreshes styles and measurements, preserves live editor selection/viewport, closes popups, and uses the new theme upon reopening. The theme demo contains two Ribbons and three independent StyleBook selectors. The main demo includes a **Theme and StyleBook example** button. Source-based palette checks include 162 reproducible contrast calculations; native test scenarios were not run.

See [`docs/ThemeSystem.md`](docs/ThemeSystem.md).

## 4. Responsive layout and interaction

Stage 4 introduced `TRibbonAdaptiveLayoutEngine`, which measures **actual content, fonts, icons, and styles**. Presentation modes include normal groups, groups with small buttons, group launchers, and shared compact-group menus; there are **no fixed screen-width breakpoints**.

- Group policies: `Pinned`, `AllowCompact`, `AllowCollapse`, and `CollapsePriority`; ties collapse deterministically from right to left. Horizontal scrolling is used when policy restrictions prevent fitting content.
- Retained presenters preserve model `Owner`, `Id`, `Order`, `CommandId`, values, and preferred `ButtonStyle`. Expanded groups create a separate native control tree using the same factory.
- Measurement caching keys include captions, font/style/icons, visibility, scale, and interaction density. Geometry-only resizes reuse cached measurements; counters expose cache activity.
- Explicit pointer/touch density, minimum hit targets, tap-versus-pan handling, keyboard focus reveal, and scroll-to-selected-tab behavior. File and tabs share one horizontal viewport.
- Popups are positioned inside the host client area; they close on resize/style/scale/geometry changes, support Escape/back, and use session-validated focus restoration.
- `ReduceMotion` and demo scenarios with long text, pinned groups, touch density, and stress conditions.

```pascal
Ribbon.InputDensity := ridTouch;
Ribbon.ReduceMotion := True;
Ribbon.CompactCaption := 'Commands';
Documents.Pinned := True;
// A higher priority keeps a group expanded/compact for longer.
OtherGroup.CollapsePriority := 10;
OtherGroup.AllowCompact := True;
OtherGroup.AllowCollapse := True;
```

Input density is **not inferred** from the platform or window width. A group containing a focused inline editor is not collapsed; scrolling is used if needed. Adaptive presentation never overwrites the model's `ButtonStyle`.

See [`docs/ResponsiveDesign.md`](docs/ResponsiveDesign.md) and [`docs/Stage03Features.md`](docs/Stage03Features.md).

## 5. JSON persistence and IDE editors (Stage 6)

Optional `CamART.Ribbon.Json` supports a canonical **v2 schema** with compatibility for unversioned/v1 `buttons/style` data, all 13 supported built-in types, persistent IDs/order, QAT/menu/gallery references, and theme/configuration settings.

The loading pipeline checks grammar and resource limits, duplicate properties/IDs and data types, registered commands/icons and reference targets, then constructs a **single-owner temporary model** before a bulk commit. Invalid JSON does not clear the live Ribbon. A callback exception after publishing is reported separately as a **committed-error** state.

The package boundary is deliberate: **Core + FMX** for basic use; optional **JSON + JSON-FMX** adapters for persistence; **Design** only for IDE integration. Ordinary Pascal demos do not depend on JSON, and runtime packages do not depend on IDE APIs.

The IDE adds a CamART palette registration, a native FMX tree editor to add/delete/reorder all 13 item types, icon/theme/size controls, reference-aware deletion, and Object Inspector property editors. Actual edits mark the designer as dirty.

Three demos are provided: a regular Pascal demo; a separate JSON import/export demo; and a real `.fmx` demo for nested model/event/StyleBook serialization.

```pascal
// uses CamART.Ribbon.Json, CamART.Ribbon.Json.FMX;
// Register commands and icons referenced by JSON before loading.
JsonText := TRibbonJsonFMX.Save(Ribbon);
Diagnostics := TRibbonJsonFMX.Load(Ribbon, JsonText);
```

Source-based native acceptance tests cover JSON codec/transactions, JSON-FMX, design operations and form streaming, but Delphi/IDE execution was not performed in the source preparation environment.

See [`docs/JsonConfiguration.md`](docs/JsonConfiguration.md), [`docs/JsonSchemaDesign.md`](docs/JsonSchemaDesign.md), [`docs/DesignIntegration.md`](docs/DesignIntegration.md), and [`docs/Stage06Audit.md`](docs/Stage06Audit.md).

## 6. Object Pascal usage example

Add the following method to an FMX form. `HandleSave` and `HandleWrap` are event methods defined on that same form with signature `procedure(Sender: TObject)`. If you stream the form, define those event methods in the form's `published` section.

```pascal
uses
  FMX.Types,
  CamART.Ribbon.Types,
  CamART.Ribbon.Model,
  CamART.Ribbon.References,
  CamART.Ribbon.Control;

procedure TMainForm.CreateRibbon;
var
  Ribbon: TCamARTRibbon;
  Home: TRibbonTab;
  Documents: TRibbonGroup;
  Save, Wrap, Export: TRibbonButton;
  QuickSave: TRibbonCommandLink;
begin
  Ribbon := TCamARTRibbon.Create(Self);
  Ribbon.Name := 'MainRibbon';
  Ribbon.Parent := Self;
  Ribbon.Align := TAlignLayout.Top;
  Ribbon.Height := 240;
  Ribbon.BeginUpdate;
  try
    Home := Ribbon.AddTab('Home');
    Home.Id := 'home';
    Documents := Home.AddGroup('Document');
    Documents.Id := 'document';

    Save := Documents.AddButton('Save');
    Save.Id := 'save-button';
    Save.ButtonStyle := rbsLarge;
    Save.OnClick := HandleSave;
    Save.Hint := 'Save document';

    Wrap := Documents.AddButton('Wrap text');
    Wrap.ButtonStyle := rbsSmall;
    Wrap.ButtonKind := rbkToggle;
    Wrap.OnChange := HandleWrap;

    Export := Documents.AddButton('Export');
    Export.ButtonKind := rbkSplit;
    Export.OnClick := HandleSave;
    Export.MenuItems.AddItem(Save.Id);

    QuickSave := Ribbon.QuickAccess.AddItem(Save.Id);
    QuickSave.Id := 'qat-save';
    Ribbon.QuickAccessPosition := rqpAbove;
    Ribbon.ApplicationCaption := 'File';
    Ribbon.ApplicationMenu.AddItem(Save.Id);
  finally
    Ribbon.EndUpdate;
  end;
end;
```

To use `IconKey`, first register an icon key through `Ribbon.Icons.RegisterBitmap`, `RegisterPngStream`, `SetImages`/`BindKeyToIndex`, or `Ribbon.SvgIcons.RegisterSvg`. The source object remains with the application; the registry owns an independent copy of the bitmap or SVG. After registering, call `Ribbon.Refresh` to update existing views. The demo creates original bitmap and SVG icons using Object Pascal; it does not require external icon files.

For a native Action:

```pascal
Ribbon.BindAction('document.save', SaveAction);
Save.CommandId := 'document.save';
```

Bindings are established in code; Action registry/interface links are **not automatically restored by form streaming**. Re-register application bindings after loading.

## 7. Core behavioral contracts

| Area | Contract |
|---|---|
| Ownership | `Ribbon → Tab → Group → Item`; QAT/menu store ID references. Do not add returned models to a second owning collection. |
| IDs and ordering | `Id` is independent of caption, exact and case-sensitive; `Order` controls sibling order. Reference collections reorder by `Index`. |
| Commands | If `CommandId` is nonempty, only the registered command executes. If empty, local state and `OnClick` are used. Unknown nonempty IDs do not fall back to local callbacks. |
| Checked state | Unbound toggle/check state is stored on the model. When bound, `Checked` comes from the `IRibbonCheckState` source; writing to the model is rejected and no duplicate state is streamed. |
| Queries | `CanExecute` is pure from the model/UI perspective. Action `OnUpdate` may update its own Action state, but must not delete the Ribbon/model or initiate a fresh refresh loop. |
| Refresh | Call `RefreshCommands` after command-state changes; `Refresh` after icon-content changes; `RefreshTheme` after updating resources within the same style template. Command refresh closes open popups and creates a new snapshot. |
| QAT | Its own `Visible`/`Enabled` preferences, the source button's `Enabled`, and command availability are combined. Source tab/group visibility/enabled state does not suppress the independent QAT view. |
| Native controls | The model-state copy is a presentation snapshot only. Native `OnChange` feedback is suppressed during synchronization. A separate value event from a hidden/disabled view restores the snapshot without emitting a business event. |
| Streaming | 13 item types and collections are persisted; internal hosts, controls, and popup views use `Stored=False`. Resolving event methods against the real form root requires native verification. |
| Threads | All model, UI, and service APIs must be used on the **FMX main thread**. |

`FindItemView`, `FindButtonView`, `FindQuickAccessView`, `FindTabView`, and counters are diagnostic interfaces. Returned view controls may be destroyed after removing the source or tab. Streaming arbitrary ordinary FMX children directly under the Ribbon with `Stored=True` is unsupported; use the model/view registration mechanism.

See [`docs/Components.md`](docs/Components.md) and [`docs/Architecture.md`](docs/Architecture.md).

## 8. Stage 7 hardening, tests, and benchmarks

Stage 7 source additions include:

- Lifetime/revision checks in tab-header and QAT measure/arrange callbacks; safe continuation through command/split-arrow resizing.
- Propagation of existing pointer/touch density to new/retained QAT buttons, avoiding reuse of an obsolete snapshot after re-entrant density callbacks.
- Additional native regression suites, while preserving previous suites, including integration with the JSON-free FMX runner.
- `RibbonAcceptanceTests`: runs native suites and emits raw logs, suite outcomes, target/build/compiler information, and a source hash.
- `RibbonBenchmarks`: records raw Stopwatch ticks/frequency and cold/warmup/steady measurements across nine operations, including view/cache/layout indicators and a limited teardown witness.
- Build/run/interaction differentiation across eight targets; 15 P0 manual/device/IDE acceptance flows, a report consistency validator, and a real-build evidence helper.

**No native performance measurements were obtained.** There is no supported claim about speedups, milliseconds/FPS, whole-process leak freedom, or successful execution on every platform. No speculative runtime performance refactor was applied without a measured slow path.

### 8.1 Suggested native validation procedure

1. Extract the source tree intact and verify the current BPL configuration according to §1.
2. Open `Demo/RibbonDemo.dproj` in RAD Studio. Win64 / Debug can serve as an initial application target.
3. Build and execute native acceptance suites on Windows where the relevant helper applies. The original Stage 7 instruction for the **unmodified** distribution was:

   ```powershell
   powershell -NoProfile -File .\Build\Build-Windows.ps1 -Platform Win64 -RunNativeAcceptance
   ```

   Repeat for Win32. For **modified** sources, use the updated `Verify-Windows.ps1` workflow to establish the build first, and run appropriate native acceptance executables separately if the updated helper does not expose the historical option.
4. For Release benchmarking, the original helper used `-BuildBenchmarks -Configuration Release`. Explicitly start measurements inside the benchmark program and retain raw results.
5. Record genuine device/IDE/interaction results in a copy of `Evidence/Stage07NativeRun.template.json`, with separate original logs. The template is **not evidence**.
6. Inspect actual form save/close/reopen behavior, command and QAT state, StyleBook inheritance, JSON persistence, and editor lifecycle. Keep failures and unexecuted scenarios visible.

The original installation report said 161 native scenarios and 20 suites were preserved across the packaging-only change; they had **not** been executed in that distribution. Stage 2–7 native acceptance gates remain open, and the seven-stage source delivery is **not** a qualified production binary.

See [`docs/Stage07Audit.md`](docs/Stage07Audit.md), [`docs/NativeAcceptance.md`](docs/NativeAcceptance.md), [`docs/PlatformAcceptance.md`](docs/PlatformAcceptance.md), [`docs/Performance.md`](docs/Performance.md), [`docs/TestReport.md`](docs/TestReport.md), [`STATUS.md`](STATUS.md), and [`VALIDATION.md`](VALIDATION.md).

## 9. SVG icon update (November 4, 2026)

The newer icon API adds `Ribbon.SvgIcons.RegisterSvg(Key, TSkSvg/TSkSvgBrush)` and `RegisterSvgSource`. Existing bitmap, PNG, and ImageList APIs remain supported. SVG parsing and rendering use Delphi's Skia integration. Windows distribution of FMX applications using this layer requires an appropriate `sk4d.dll`. The Core and RTL JSON packages do not take this Skia dependency.

Use `Build/Verify-Svg.ps1` to check the newer SVG-related sources rather than treating the older Stage 7 report as verification of these subsequent changes. See [`docs/Components.md`](docs/Components.md) and [`docs/TestReport.md`](docs/TestReport.md).

## 10. Source-package layout

| Directory | Contents |
|---|---|
| `Source/Core` | Six RTL units: types, model, commands, references, selection, layout |
| `Source/FMX` | 22 view/service units, including themes, scoped styles, and native styling |
| `Source/Serialization` | Optional RTL JSON codec and independent FMX adapter (two units) |
| `Design` | Four units for palette, policy, component/property/tree editors; not linked to applications at runtime |
| `Demo` | Live preview, all item types, original Pascal icons, responsive/stress examples, two-Ribbon theme example |
| `Demo/Json`, `Demo/Designer` | Standalone JSON demo and real `.fmx` design demo |
| `Tests/Core`, `Tests/FMX`, `Tests/Integration`, `Tests/Acceptance` | Standalone and combined native test runners; source present, native results absent |
| `Tests/Performance` | Native baseline/lifecycle measurement app; no completed measurements |
| `Packages`, `Build` | Four runtime/optional packages, one Design package, 14 projects, Windows build/evidence helpers |
| `Tests/Static`, `Evidence` | Optional source inspections and explicit separation of real vs. missing evidence |
| `docs`, `prompts` | Technical documentation, prior research, and the seven-stage prompt set |

Runtime, demos and native tests are written in Object Pascal. Optional Python source checks and PowerShell build helpers are not linked into the product. No third-party product code or icons were copied.

## 11. Compatibility, scope, and release status

Delphi 12 Athens and Delphi 13 Florence were targeted in the historical source release, but **the minimum supported version has not been established through native builds**. Delphi 13.1 and 13.2 share the `VER370` compiler family. Win32/Win64 project settings are supplied; other targets require installed platform SDKs, IDE deployment settings, and actual device evidence. FMXLinux has separate prerequisites.

The seven-stage source implementation has been delivered; it is **not** a validated multi-platform binary or production-accepted release. Runtime, Design, demo and test Pascal units were reported unchanged in the original Delphi 13.2 packaging-only release. Later 13.1 path corrections and SVG source additions must be evaluated according to their own revisions, rather than mischaracterized as part of the original Stage 7 snapshot.

Original source/distribution status, build constraints and release changes: [`docs/Delphi13_2_Update.md`](docs/Delphi13_2_Update.md), [`docs/Installation.md`](docs/Installation.md), [`docs/CrossPlatformCompatibility.md`](docs/CrossPlatformCompatibility.md), [`STATUS.md`](STATUS.md), [`VALIDATION.md`](VALIDATION.md).

## 12. Official Delphi references

- [Delphi 13.2 release notes](https://docwiki.embarcadero.com/RADStudio/Florence/en/13_Florence_-_Release_2)
- [What's New in Delphi 13](https://docwiki.embarcadero.com/RADStudio/Florence/en/What%27s_New)
- [Compiler Versions Table](https://docwiki.embarcadero.com/RADStudio/Florence/en/Compiler_Versions_Table)
- [64-bit IDE: package installation and separate output folders](https://docwiki.embarcadero.com/RADStudio/Florence/en/64-bit_IDE)
- [Compiler directives for libraries/shared objects (`LIBSUFFIX`)](https://docwiki.embarcadero.com/RADStudio/Florence/en/Compiler_directives_for_libraries_or_shared_objects_(Delphi))

Older target/registry examples in generic 64-bit IDE documentation should not be assumed to apply to every Delphi 13.2 detail; use the current release-specific notes for release-specific changes.

---

**Merged document note:** This English guide consolidates and translates the two supplied Markdown documents. File/directory references and build command names are preserved, and translated strings in the usage example are illustrative labels rather than a modification of the underlying project files. Linked project documents are referenced as supplied; they are not included in this standalone Markdown file.
