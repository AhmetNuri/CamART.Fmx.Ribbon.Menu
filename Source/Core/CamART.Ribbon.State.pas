unit CamART.Ribbon.State;

interface

uses
  System.SysUtils,
  CamART.Ribbon.Types;

type
  TRibbonSelectionController = class
  private
    FActiveTabId: string;
    FPreviousOrder: TArray<string>;
    procedure RememberOrder(const ATabs: TArray<TRibbonTabState>);
    class procedure ValidateTabs(const ATabs: TArray<TRibbonTabState>); static;
    class function FindIndex(const AId: string;
      const ATabs: TArray<TRibbonTabState>): Integer; static;
    class function IsEligible(const ATab: TRibbonTabState): Boolean; static;
    class function IsEligibleAt(const ATabs: TArray<TRibbonTabState>;
      const AIndex: Integer): Boolean; static;
  public
    // Returns True only when the active ID changes. Explicit selection rejects
    // unknown/hidden/disabled tabs. Empty is valid only if no tab is eligible.
    function Select(const AId: string;
      const ATabs: TArray<TRibbonTabState>): Boolean;
    // Keeps a valid selection; otherwise selects successor, then predecessor.
    function Reconcile(const ATabs: TArray<TRibbonTabState>): Boolean;
    property ActiveTabId: string read FActiveTabId;
  end;

implementation

uses
  System.Generics.Collections;

class procedure TRibbonSelectionController.ValidateTabs(
  const ATabs: TArray<TRibbonTabState>);
var
  Seen: TDictionary<string, Byte>;
  Tab: TRibbonTabState;
begin
  Seen := TDictionary<string, Byte>.Create;
  try
    for Tab in ATabs do
    begin
      if Tab.Id = '' then
        raise EArgumentException.Create('A tab snapshot contains an empty ID');
      if Seen.ContainsKey(Tab.Id) then
        raise EArgumentException.CreateFmt('Duplicate tab ID "%s"', [Tab.Id]);
      Seen.Add(Tab.Id, 0);
    end;
  finally
    Seen.Free;
  end;
end;

class function TRibbonSelectionController.FindIndex(const AId: string;
  const ATabs: TArray<TRibbonTabState>): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ATabs) do
    if ATabs[I].Id = AId then
      Exit(I);
  Result := -1;
end;

class function TRibbonSelectionController.IsEligible(
  const ATab: TRibbonTabState): Boolean;
begin
  Result := ATab.Visible and ATab.Enabled;
end;

class function TRibbonSelectionController.IsEligibleAt(
  const ATabs: TArray<TRibbonTabState>; const AIndex: Integer): Boolean;
begin
  Result := False;
  if AIndex < 0 then
    Exit;
  if AIndex > High(ATabs) then
    Exit;
  Result := IsEligible(ATabs[AIndex]);
end;

procedure TRibbonSelectionController.RememberOrder(
  const ATabs: TArray<TRibbonTabState>);
var
  I: Integer;
begin
  SetLength(FPreviousOrder, Length(ATabs));
  for I := 0 to High(ATabs) do
    FPreviousOrder[I] := ATabs[I].Id;
end;

function TRibbonSelectionController.Select(const AId: string;
  const ATabs: TArray<TRibbonTabState>): Boolean;
var
  Index, I: Integer;
begin
  ValidateTabs(ATabs);
  if AId <> '' then
  begin
    Index := FindIndex(AId, ATabs);
    if Index < 0 then
      raise EArgumentException.CreateFmt('Unknown tab ID "%s"', [AId]);
    if not IsEligible(ATabs[Index]) then
      raise EArgumentException.CreateFmt('Tab "%s" is not selectable', [AId]);
  end
  else
    for I := 0 to High(ATabs) do
      if IsEligible(ATabs[I]) then
        raise EArgumentException.Create(
          'Selection may be empty only when no tab is selectable');
  Result := FActiveTabId <> AId;
  FActiveTabId := AId;
  RememberOrder(ATabs);
end;

function TRibbonSelectionController.Reconcile(
  const ATabs: TArray<TRibbonTabState>): Boolean;
var
  Index, OldIndex, I, CandidateIndex: Integer;
  Candidate: string;
begin
  ValidateTabs(ATabs);
  Candidate := '';
  Index := FindIndex(FActiveTabId, ATabs);
  if IsEligibleAt(ATabs, Index) then
    Candidate := FActiveTabId
  else if Index >= 0 then
  begin
    // Still present but hidden/disabled: use the current visible ordering.
    for I := Index + 1 to High(ATabs) do
      if IsEligible(ATabs[I]) then
      begin
        Candidate := ATabs[I].Id;
        Break;
      end;
    if Candidate = '' then
      for I := Index - 1 downto 0 do
        if IsEligible(ATabs[I]) then
        begin
          Candidate := ATabs[I].Id;
          Break;
        end;
  end
  else
  begin
    // Deleted tab: indices may all have shifted. Follow prior neighbour IDs
    // instead of treating the old index as a new, unrelated tab identity.
    OldIndex := -1;
    for I := 0 to High(FPreviousOrder) do
      if FPreviousOrder[I] = FActiveTabId then
      begin
        OldIndex := I;
        Break;
      end;
    if OldIndex >= 0 then
    begin
      for I := OldIndex + 1 to High(FPreviousOrder) do
      begin
        CandidateIndex := FindIndex(FPreviousOrder[I], ATabs);
        if IsEligibleAt(ATabs, CandidateIndex) then
        begin
          Candidate := ATabs[CandidateIndex].Id;
          Break;
        end;
      end;
      if Candidate = '' then
        for I := OldIndex - 1 downto 0 do
        begin
          CandidateIndex := FindIndex(FPreviousOrder[I], ATabs);
          if IsEligibleAt(ATabs, CandidateIndex) then
          begin
            Candidate := ATabs[CandidateIndex].Id;
            Break;
          end;
        end;
    end;
    // First reconciliation, or the entire previous neighbourhood was removed.
    if Candidate = '' then
      for I := 0 to High(ATabs) do
        if IsEligible(ATabs[I]) then
        begin
          Candidate := ATabs[I].Id;
          Break;
        end;
  end;
  Result := Candidate <> FActiveTabId;
  FActiveTabId := Candidate;
  RememberOrder(ATabs);
end;

end.
