UNIT ZoneList;

INTERFACE

TYPE
 TZoneType = (ztOutLand,ztCity,ztDungeon,ztHousing);
 TZone = RECORD
  ZoneType : TZoneType;
  ZoneName : STRING;
  OffsetX : Integer;
  OffsetY : Integer;
  Region : Integer;
 END;
 TZoneArray = ARRAY[0..255] OF TZone;

FUNCTION GetZone:TZoneArray;OVERLOAD;
FUNCTION GetZone(id:integer):TZone;OVERLOAD;

IMPLEMENTATION

USES
 SysUtils,
 dempak,
 classes,
 IniFiles,
 Windows,
 General_Res;

FUNCTION GetZone(id:integer):TZone;
BEGIN
 result := GetZone[id];
END;

FUNCTION GetZone:TZoneArray;
VAR
 TempStream:TStringMemoryStream;
 FileStream:TFileStream;
 ZoneIni:TIniFile;
 i:Integer;
 s:STRING;
BEGIN
 IF GamePath<>'' THEN BEGIN
  TempStream := _DeMPAK(GamePath+'zones\zones.mpk','zones.dat',dcGetEntry);
  FileStream := TFileStream.Create(AppPath+'zones.dat',fmCreate);
  FileStream.CopyFrom( TempStream, 0);
  FileStream.Free;
  ZoneIni := TIniFile.Create(AppPath+'zones.dat');
  ZeroMemory(@Result, SizeOf(Result));
  FOR i := 0 TO 255 DO BEGIN
   s := IntToStr(i);
   WHILE Length(s)<3 DO s := '0' + s;
   s := 'zone' + s;
   Result[i].ZoneType := TZoneType(ZoneIni.ReadInteger(s,'type',0));
   Result[i].ZoneName := ZoneIni.ReadString(s,'name','Unknown');
   Result[i].OffsetX := ZoneIni.ReadInteger(s,'region_offset_x',0);
   Result[i].OffsetY := ZoneIni.ReadInteger(s,'region_offset_y',0);
   Result[i].Region := ZoneIni.ReadInteger(s,'region',0);
  END;
  ZoneIni.Free;
  s := AppPath+'zones.dat'#0;
  DeleteFile(@s[1]);
 END ELSE BEGIN
  RAISE EZoneListError.RaiseMe(1);
 END;
END;

END.
(*
Mode d'emploi de cette unitée:
Renvoie la liste des zones répertoriées dans zones.mpk
Pour l'utiliser, une seule procédure : GetZone

GetZone
Sans paramètres

Result:TZoneArray          Liste des TZone

Type de données:

TZoneType=(ztOutLand,ztCity,ztDungeon,ztHousing)
-ztOutLand : Terrain standard
-ztCity : Ville
-ztDungeon : Donjon
-ztHousing : Habitation

TZone=RECORD
-ZoneType : TZoneType  Type de la zone
-ZoneName : STRING     Nom de la zone
-OffsetX : Integer     Coord X (largeur zone : 8)
-OffsetY : Integer     Coord Y (largeur zone : 8)
-Region : Integer      Région contenant la zone

TZoneArray = ARRAY[0..255] OF TZone
Liste de toutes les zones

Auteur : Gabriel Paul 'Cley Faye' Risterucci
Homepage : new664.fr.st
mail : dareaperpa666@hotmail.com

Le fichier source de mon mapper DAoC est grandement inspiré de celui trouvé
sur www.randomly.org.