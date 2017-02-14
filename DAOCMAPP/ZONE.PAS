unit zone;

interface

USES
 Windows,
 Graphics,
 SysUtils,
 DeMPAK,
 IniFiles,
 ZoneList,
 GraphicEx,
 General_Res;

TYPE
 TDZone = CLASS
 PRIVATE
  _BaseZonePath : STRING;
  FZone: TZone;
  FZoneId: Integer;
  FScale: Integer;
  FHeightMap: TBitmap;
  Fsector_dat: TIniFile;
    function GetHeightMap: TBitmap;
 PROTECTED
  _csvFile:STRING;
  _datFile:STRING;
 PUBLIC
  PROPERTY BaseZonePath:STRING READ _BaseZonePath;
  PROPERTY Zone:TZone READ FZone;
  PROPERTY ZoneID:Integer READ FZoneId;
  PROPERTY Scale:Integer READ FScale;
  PROPERTY HeightMap:TBitmap READ GetHeightMap;
  PROPERTY sector_dat:TIniFile READ Fsector_dat;
  CONSTRUCTOR Create(id:Integer;finalscale:integer);
  DESTRUCTOR Destroy;OVERRIDE;
  PROCEDURE LoadHeightMap;
  FUNCTION DataFile(filename:STRING):TStringMemoryStream;
  FUNCTION IToR(Value:TPoint):TPoint;
  FUNCTION IToRX(Value:Integer):Integer;
  FUNCTION IToRY(Value:Integer):Integer;
  FUNCTION RToIX(Value:Integer):Integer;
  FUNCTION RToIY(Value:Integer):Integer;
 END;

implementation

USES
 Classes;

{ TDZone }

constructor TDZone.Create;
var
 str:TStringMemoryStream;
 fs:TFileStream;
begin
 inherited Create;
 FZoneId := id;
 Fscale := finalscale DIV 65536;
 FZone := GetZone(id);
 if FZone.ZoneType = ztHousing THEN _BaseZonePath := gamepath+'phousing\zones\zone'+Int2Str(id)+'\' else _BaseZonePath := gamepath+'zones\zone'+Int2Str(id)+'\';
 _datfile := _BaseZonePath + 'dat'+int2str(id)+'.mpk';
 _csvfile := _BaseZonePath + 'csv'+int2str(id)+'.mpk';
 str := DataFile('sector.dat');
 fs := TFileStream.Create(apppath+int2str(id)+'sec.dat',fmCreate);
 fs.CopyFrom(str,0);
 str.Free;
 fs.free;
 Fsector_dat := TIniFile.Create(apppath+int2str(id)+'sec.dat');
 FHeightMap := nil;
end;

FUNCTION TDZone.DataFile;
BEGIN
 Result := NIL;
 TRY
  Result := _DeMPAK(_csvfile,filename,dcGetEntry);
 EXCEPT ON
  E:EMPAKError do BEGIN
   Result := _DeMPAK(_datfile,filename,dcGetEntry);
  END;
 END;
 Result.Position := 0;
END;

destructor TDZone.Destroy;
begin
 Fsector_dat.Free;
 FHeightMap.Free;
 DeleteFile(apppath+int2str(FZoneId)+'sec.dat');
 inherited;
end;

function TDZone.GetHeightMap: TBitmap;
begin
 IF FHeightMap=nil then LoadHeightMap;
 result := FHeightMap;
end;

FUNCTION TDZone.IToR;
BEGIN
 Result := Point(ITORX(Value.X),IToRY(Value.Y));
END;

FUNCTION TDZone.IToRX;
BEGIN
 Result := Value DIV Scale;
END;

FUNCTION TDZone.IToRY;
BEGIN
 Result := Value DIV Scale;
END;

procedure TDZone.LoadHeightMap;
var
 terrainscale, offsetscale : Integer;
 terrainmap, offsetmap : TPCXGraphic;
 str:TStringMemoryStream;
 x,y:integer;
 progress:integer;
begin
 if FHeightMap=nil then begin
  terrainscale := sector_dat.ReadInteger('terrain','scalefactor',1);
  offsetscale := sector_dat.ReadInteger('terrain','offsetfactor',1);
  str := DataFile('terrain.pcx');
  terrainmap := TPCXGraphic.Create;
  terrainmap.LoadFromStream(str);
  str.Free;
  str := DAtaFile('offset.pcx');
  offsetmap := TPCXGraphic.Create;
  offsetmap.LoadFromStream(str);
  str.Free;
  if not CheckDim(terrainmap,256,256) then raise EZoneError.RaiseMe(1);
  if not CheckDim(offsetmap,256,256) then raise EZoneError.RaiseMe(2);
  FHeightMap := TBitmap.Create;
  FHeightMap.Width := 256;
  FHeightMap.Height := 256;
  OutStr('Génération de la table d''altitude');
  progress := 0;
  for x := 0 TO 255 do begin
   for y := 0 TO 255 do begin
    FHeightMap.Canvas.Pixels[x,y] := terrainmap.canvas.Pixels[x,y] * terrainscale + offsetmap.canvas.pixels[x,y] * offsetscale;
    progress := progress + 1;
   end;
   OutPercent(Trunc(x / 2.55));
  end;
  terrainmap.Free;
  offsetmap.Free;
 end;
end;

function TDZone.RToIX(Value: Integer): Integer;
begin
 result := Value * FScale;
end;

function TDZone.RToIY(Value: Integer): Integer;
begin
 result := Value * FScale;
end;

end.
