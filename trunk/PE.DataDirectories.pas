unit PE.DataDirectories;

interface

uses
  System.Classes,

  PE.Common,
  PE.Msg,
  PE.Types.Directories;

type
  TDataDirectories = class
  private
    FPE: TObject; // TPEImage
    FItems: array of TImageDataDirectory;
    function GetCount: integer; inline;
    procedure SetCount(const Value: integer);
  public
    constructor Create(APE: TObject);

    procedure Clear;

    procedure LoadFromStream(Stream: TStream; const Msg: TMsgMgr;
      StartOffset, SectionHdrOffset: TFileOffset; DeclaredCount: integer);

    // Return saved size.
    function SaveToStream(Stream: TStream): integer;

    function Get(Index: integer; OutDir: PImageDataDirectory): boolean;

    // Put directory safely. If Index > than current item count, empty items
    // will be added.
    procedure Put(Index: cardinal; const Dir: TImageDataDirectory); overload;

    procedure Put(Index: cardinal; RVA, Size: uint32); overload;

    property Count: integer read GetCount write SetCount;

  end;

implementation

uses
  PE.Image;

{ TDataDirectories }

procedure TDataDirectories.Clear;
begin
  FItems := nil;
  self.Count := 0;
end;

constructor TDataDirectories.Create(APE: TObject);
begin
  self.FPE := APE;
end;

function TDataDirectories.Get(Index: integer;
  OutDir: PImageDataDirectory): boolean;
begin
  Result := (Index >= 0) and (Index < Length(FItems));
  if Result and (OutDir <> nil) then
    OutDir^ := FItems[Index];
end;

procedure TDataDirectories.Put(Index: cardinal; const Dir: TImageDataDirectory);
begin
  if Index >= Length(FItems) then
    SetLength(FItems, Index + 1);
  FItems[Index] := Dir;
end;

procedure TDataDirectories.Put(Index: cardinal; RVA, Size: uint32);
var
  d: TImageDataDirectory;
begin
  d.VirtualAddress := RVA;
  d.Size := Size;
  Put(Index, d);
end;

function TDataDirectories.GetCount: integer;
begin
  Result := Length(FItems);
end;

procedure TDataDirectories.LoadFromStream;
var
  CountToEOF: integer; // Count from StartOfs to EOF.
  CountToRead: integer;
  SizeToEOF: uint64;
  Size: uint32;
begin

  SizeToEOF := (Stream.Size - StartOffset);

  CountToEOF := SizeToEOF div SizeOf(TImageDataDirectory);

  // File can have part of dword stored. It must be extended with zeros.
  if (SizeToEOF mod SizeOf(TImageDataDirectory)) <> 0 then
    inc(CountToEOF);

  CountToRead := DeclaredCount;

  if DeclaredCount < 16 then
    Msg.Write('[DataDirectories] Non-usual count of directories (%d).',
      [DeclaredCount]);

  // if DeclaredCount > CountInRange then
  // begin
  // Msg.Write('[DataDirectories] Declared count of directories (%d) is greater '
  // + 'than should be (%d) in range of file offsets 0x%x - 0x%x.',
  // [DeclaredCount, CountInRange, StartOffset, SectionHdrOffset]);
  // Msg.Write('[DataDirectories] Directories from %d are loaded starting from '
  // + 'section headers offset (0x%x)', [CountInRange + 1, SectionHdrOffset]);
  // end;

  if DeclaredCount > CountToEOF then
    begin
      CountToRead := CountToEOF;

      Msg.Write('[DataDirectories] Declared count of directories is greater ' +
        'than file can contain (%d > %d).', [DeclaredCount, CountToEOF]);
    end;

  // Read data directories.

  Size := CountToRead * SizeOf(TImageDataDirectory);
  SetLength(FItems, CountToRead);
  // Must clear buffer, cause it can have partial values (filled with zeros).
  FillChar(FItems[0], Size, 0);
  // Not all readed size/rva can be valid. You must check rvas before use.
  Stream.Read(FItems[0], Size);

  // Set final count.
  self.Count := CountToRead;

end;

function TDataDirectories.SaveToStream(Stream: TStream): integer;
begin
  Result := Stream.Write(FItems[0], Length(FItems) *
    SizeOf(TImageDataDirectory))
end;

procedure TDataDirectories.SetCount(const Value: integer);
begin
  SetLength(FItems, Value);
  TPEImage(FPE).OptionalHeader.NumberOfRvaAndSizes := Value;
end;

end.