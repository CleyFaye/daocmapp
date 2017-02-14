UNIT BackgroundRender;

INTERFACE

USES Zone;

PROCEDURE RenderBackground(Zone:TDZone);

IMPLEMENTATION

USES
 SysUtils,
 Classes,
 Graphics,
 General_Res,
 DeMPAK;

PROCEDURE RenderBackground;
VAR
 TileWidth,TileHeight : Integer;
 UseDDS : Boolean;
 TexName : STRING;
 iX,iY : Integer;
 CatalogStream,ConvertStream : TStringMemoryStream;
 Catalog : TStringList;
 TextureExtent : STRING;
 SectorBitmap : TBitmap;
 ProgressCount : Integer;

 PROCEDURE WriteSector;
 VAR
  TextureStream : TStringMemoryStream;
  SectorTextureName : STRING;
 begin
  SectorTextureName := 'tex' + Int2Str( iX, 2) + '-' + Int2Str( iY, 2) + TextureExtent;
  OutStr( 'Nom du fichier de section : '+SectorTextureName, 2);
  IF Catalog.IndexOf(SectorTextureName) <> -1 THEN BEGIN
   OutStr( 'Décompression du fichier MPK->texture', 3);
   TextureStream := _DeMPAK( TexName, SectorTextureName, dcGetEntry);
   IF UseDDS THEN BEGIN
    OutStr( 'Décompression DDS->BMP', 3);
    ConvertDDS2BMP( TextureStream, ConvertStream);
    TextureStream.Size := 0;
    TextureStream.CopyFrom( ConvertStream, 0);
   END;
   TextureStream.Position := 0;
   SectorBitmap.LoadFromStream(TextureStream);
   OutStr( 'Ecriture de la section', 3);
   DrawingSurface.canvas.StretchDraw( Rect( iX * TileWidth, iY * TileWidth, iX * TileWidth + TileWidth, iY * TileWidth + TileWidth), SectorBitmap);
   TextureStream.Free;
  END;
 END;

BEGIN
 OutStr( 'Initialisation des variables', 2);
 OutStr( '-->Taille des sections', 3);
 TileWidth := DrawingSurface.Width DIV 8;
 TileHeight := DrawingSurface.Height DIV 8;
 OutStr( '-->Nom du fichier de textures compressées', 3);
 TexName := zone.BaseZonePath + '\tex' + Int2Str(zone.ZoneId) + '.mpk';
 OutStr( '   '+TexName, 3);
 OutStr( '-->Détection du format utilisé dans la zone', 2);
 UseDDS := False;
 TextureExtent := '.bmp';
 IF NOT FileExists(TexName) THEN RAISE ERenderError.RaiseMe(1);
 CatalogStream := _DeMPAK(TexName,'',dcGetCatalog);
 Catalog := TStringList.Create;
 Catalog.CommaText := CatalogStream.ReadStr;
 CatalogStream.Free;
 IF LowerCase(ExtractFileExt(Catalog.Strings[0])) = '.dds' THEN BEGIN
  OutStr( '   Format DDS', 3);
  UseDDS := True;
  TextureExtent := '.dds';
  ConvertStream := TStringMemoryStream.Create;
 END ELSE BEGIN
  OutStr( 'Format BMP', 3);
 END;
 OutStr( '-->Création du bitmap temporaire', 3);
 SectorBitmap := TBitmap.Create;
 ProgressCount := 1;
 OutStr('Rendu du terrain de la zone '+Int2Str(zone.ZoneId));
 FOR iX := 0 TO 7 DO BEGIN
  FOR iY := 0 TO 7 dO BEGIN
   OutPercent(Trunc(ProgressCount / 64 * 100));
   ProgressCount := ProgressCount + 1;
   OutStr( 'Traitement de la section '+IntToStr(iX)+'-'+IntToStr(iY), 2);
   WriteSector;
  END;
 END;
 Catalog.Free;
 ConvertStream.Free;
 SectorBitmap.Free;
END;

END.
