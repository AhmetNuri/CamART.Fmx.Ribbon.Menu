unit CamART.Ribbon.DesignerDemo;

{$B-}

interface

uses
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.StdCtrls,
  CamART.Ribbon.Control,
  CamART.Ribbon.Model;

type
  TRibbonDesignerDemoForm = class(TForm)
  published
    Ribbon1: TCamARTRibbon;
    FormBook: TStyleBook;
    RibbonBook: TStyleBook;
    StatusLabel: TLabel;
    InheritStyleButton: TButton;
    OwnStyleButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure PasteClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure FormatChanged(Sender: TObject);
    procedure InheritStyleClick(Sender: TObject);
    procedure OwnStyleClick(Sender: TObject);
  private
    FPasteCount, FCopyCount, FFormatCount: Integer;
    procedure UpdateStatus;
  end;

var
  RibbonDesignerDemoForm: TRibbonDesignerDemoForm;

implementation

uses
  System.SysUtils,
  FMX.Styles,
  CamART.Ribbon.Commands,
  CamART.Ribbon.Themes,
  CamART.Ribbon.ThemeStyles;

{$R *.fmx}

type
  TDemoCopyCommand = class(TInterfacedObject, IRibbonCommand)
  private
    FOnExecute: TNotifyEvent;
  public
    constructor Create(const AOnExecute: TNotifyEvent);
    function CanExecute: Boolean;
    procedure Execute;
  end;

constructor TDemoCopyCommand.Create(const AOnExecute: TNotifyEvent);
begin
  inherited Create;
  FOnExecute := AOnExecute;
end;

function TDemoCopyCommand.CanExecute: Boolean;
begin
  Result := True;
end;

procedure TDemoCopyCommand.Execute;
begin
  if Assigned(FOnExecute) then FOnExecute(Self);
end;

procedure FillDemoBook(ABook: TStyleBook; ATheme: TRibbonTheme;
  AContext: TControl);
var
  SourceBook: TStyleBook;
  Stream: TMemoryStream;
  Existing: TFmxObject;
begin
  if ABook = nil then Exit;
  Existing := ABook.GetStyle(AContext);
  if (Existing <> nil) and (Existing.ChildrenCount > 0) then Exit;
  { The .fmx contains ordinary component references to both books. Populate
    their optional Ribbon templates at runtime without rebuilding the model
    or overwriting a StyleBook selection made in the Object Inspector. }
  SourceBook := CreateRibbonThemeStyleBook(nil, ATheme);
  try
    Stream := TMemoryStream.Create;
    try
      TStyleStreaming.SaveToStream(SourceBook.GetStyle(AContext), Stream);
      Stream.Position := 0;
      ABook.LoadFromStream(Stream);
    finally
      Stream.Free;
    end;
  finally
    SourceBook.Free;
  end;
end;

procedure TRibbonDesignerDemoForm.FormCreate(Sender: TObject);
begin
  FillDemoBook(FormBook, rtOffice2010Blue, Ribbon1);
  FillDemoBook(RibbonBook, rtModernDark, Ribbon1);
  Ribbon1.Commands.RegisterCommand('edit.copy', TDemoCopyCommand.Create(CopyClick));
  Ribbon1.RefreshCommands;
  UpdateStatus;
end;

procedure TRibbonDesignerDemoForm.PasteClick(Sender: TObject);
begin
  Inc(FPasteCount);
  UpdateStatus;
end;

procedure TRibbonDesignerDemoForm.CopyClick(Sender: TObject);
begin
  Inc(FCopyCount);
  UpdateStatus;
end;

procedure TRibbonDesignerDemoForm.FormatChanged(Sender: TObject);
begin
  Inc(FFormatCount);
  UpdateStatus;
end;

procedure TRibbonDesignerDemoForm.InheritStyleClick(Sender: TObject);
begin
  Ribbon1.StyleBook := nil;
  UpdateStatus;
end;

procedure TRibbonDesignerDemoForm.OwnStyleClick(Sender: TObject);
begin
  Ribbon1.StyleBook := RibbonBook;
  UpdateStatus;
end;

procedure TRibbonDesignerDemoForm.UpdateStatus;
var
  BookName: string;
begin
  if Ribbon1.EffectiveStyleBook <> nil then
    BookName := Ribbon1.EffectiveStyleBook.Name
  else BookName := '(preset / platform)';
  StatusLabel.Text := Format(
    'Nested .fmx model; paste event: %d; copy command: %d; check change: %d.' +
    sLineBreak + 'Effective StyleBook: %s.' + sLineBreak +
    'Edit Ribbon tree in the IDE, save, close and reopen, then run again.',
    [FPasteCount, FCopyCount, FFormatCount, BookName]);
end;

end.
