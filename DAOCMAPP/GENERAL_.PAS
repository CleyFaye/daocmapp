UNIT General_Res;

INTERFACE

USES
 SysUtils,
 Windows,
 Graphics,
 JPeg,
 Classes;

CONST
 SMPAKError:ARRAY[0..3] OF STRING=( 'Erreur générique',
                                    'Fichier introuvable dans le fichier source',
                                    'Erreur durant la décompression d''un flux',
                                    'Erreur durant l''initialisation de la décompression');
 SZoneListError:ARRAY[0..1] OF STRING=( 'Erreur générique',
                                        'Fichier zones.mpk introuvale où incorrect');
 SRenderError:ARRAY[0..1] OF STRING=( 'Erreur générique',
                                      'Chemin d''accès au jeu incorrect');
 SZONEError:ARRAY[0..2] OF STRING=( 'Erreur générique',
                                    'Dimension de la table de terrain incorrecte',
                                    'Dimension de la table de décalage incorrecte');

TYPE
 TStrArray = ARRAY OF STRING;
 PStrArray = ^TStrArray;
 EMapperError = CLASS(EXception)
 PROTECTED
  _ErrorId:Integer;
 PUBLIC
  CONSTRUCTOR RaiseMe(id:Integer);
  FUNCTION ErrorId:Integer;
  PROCEDURE GetSpec(OUT Name,Err:STRING;id:Integer);VIRTUAL;
 END;
 EMPAKError = CLASS(EMapperError)
 PUBLIC
  PROCEDURE GetSpec(OUT Name,Err:STRING;id:Integer);OVERRIDE;
 END;
 EZoneListError = CLASS(EMapperError)
 PUBLIC
  PROCEDURE GetSpec(OUT Name,Err:STRING;id:Integer);OVERRIDE;
 END;
 ERenderError = CLASS(EMapperError)
 PUBLIC
  PROCEDURE GetSpec(OUT Name,Err:STRING;id:Integer);OVERRIDE;
 END;
 EZoneError = CLASS(EMapperError)
 PUBLIC
  PROCEDURE GetSpec(OUT Name,Err:STRING;id:Integer);OVERRIDE;
 END;
 TOutputStyle = (osNone,osGeneral,osDebug,osBigDebug);
 TStringMemoryStream = CLASS(TMemoryStream)
 PUBLIC
  FUNCTION ReadStr(Orig:Integer=0;Value:Integer=-1):STRING;
  PROCEDURE WriteStr(Value:STRING);
 END;

VAR
 DrawingSurface : TBitmap;

PROCEDURE Pathyfy(VAR Value:STRING);
PROCEDURE WinAskGamePath;

PROCEDURE SetGamePath(Value:STRING);
FUNCTION GamePath:STRING;
FUNCTION AppPath:STRING;

FUNCTION Int2Str(Value:Integer;digit:integer=3):String;

PROCEDURE SetOutputResult(Value : TOutputStyle);
FUNCTION DebugLevel:Integer;
PROCEDURE OutStr( Str:STRING; Level:Integer=1);
PROCEDURE OutPercent(Value:Integer);

FUNCTION CheckDim(bmp:TBitmap;w,h:Integer):Boolean;

PROCEDURE InitSurface( Width,
                       Height:Integer);
PROCEDURE ClearSurface;
PROCEDURE ConvertDDS2BMP(InputStream:TStringMemoryStream;OutputStream:TStringMemoryStream);
PROCEDURE SaveOutput(OutputName:STRING;JPEG:Boolean=True;Quality:Integer=100);

IMPLEMENTATION

USES
 FileCtrl,
 Owned_Window,
 Direct3D_core,
 Direct3D9,
 d3dx9,
 IniFiles;

VAR
 ConfigFile:TIniFile;
 _GamePath:STRING;
 _AppPAth:STRING;
 TempSurface:IDirect3DTexture9;
 OutputResult : TOutputStyle;
 _DebugLevel : Integer;

FUNCTION CheckDim;
BEGIN
 result := (bmp.width=w)and(bmp.height=h);
end;

PROCEDURE OutPercent;
BEGIN
 IF DebugLevel >= 1 THEN BEGIN
  Write(#13);
  Write('Progression:'+IntToStr(Value)+'%');
  IF Value=100 THEN writeLn;
 END;
END;

PROCEDURE OutStr;
BEGIN
 IF Level <= DebugLevel THEN WriteLn(Str);
END;

FUNCTION DebugLevel;
BEGIN
 Result := _DebugLevel;
END;

PROCEDURE SetOutputResult;
BEGIN
 // Définition du niveau de débogage
 OutputResult := Value;
 _DebugLevel := Integer(OutputResult);
END;

PROCEDURE SaveOutput;
VAR
 Extent : STRING;
 JPG : TJPEGImage;
BEGIN
 Extent := '.JPG';
 IF NOT JPEG THEN Extent := '.BMP';
 OutputName := ChangeFileExt(OutputName,Extent);
 IF JPEG THEN BEGIN
  JPG := TJPEGImage.Create;
  JPG.Assign(DrawingSurface);
  JPG.CompressionQuality := Quality;
  JPG.Compress;
  JPG.SaveToFile(OutputName);
 END ELSE BEGIN
  DrawingSurface.SaveToFile(OutputName);
 END;
END;

FUNCTION Int2Str;
BEGIN
 Result := IntToStr(Value);
 WHILE Length(Result)<digit DO Result := '0' + Result;
END;

PROCEDURE ConvertDDS2BMP;
VAR
 D3DBuffer:ID3DXBuffer;
BEGIN
 D3DXCreateBuffer(0,D3DBuffer);
 D3DXCreateTextureFromFileInMemory(d3ddevice9,InputStream.Memory,InputStream.Size,TempSurface);
 D3DXSaveTextureToFileInMemory(D3DBuffer,D3DXIFF_BMP,TempSurface,nil);
 OutputStream.Size := D3DBuffer.GetBufferSize;
 CopyMemory(OutputStream.Memory,D3DBuffer.GetBufferPointer,D3DBuffer.GetBufferSize);
END;

PROCEDURE InitSurface;
var
 res:HResult;
BEGIN
 DrawingSurface := TBitmap.Create;
 DrawingSurface.Width := Width;
 DrawingSurface.Height := Height;
 DrawingSurface.PixelFormat := pf32Bit;
END;

PROCEDURE ClearSurface;
BEGIN
 DrawingSurface.Free;
END;

PROCEDURE SetGamePath;
BEGIN
 _GamePath := Value;
 ConfigFile.WriteString('config','GamePath',_GamePath);
END;

PROCEDURE Pathyfy;
BEGIN
 WHILE Pos('/',Value)>0 DO Value[Pos('/',Value)]:='\';
 IF AnsiLastChar(Value)<>'\' THEN Value:=Value+'\';
END;

PROCEDURE WinAskGamePath;
VAR
 ResDir:String;
BEGIN
 IF SelectDirectory('Sélectionnez le répertoire de DAOC','',ResDir) THEN BEGIN
  Pathyfy(ResDir);
  IF FileExists(ResDir+'camelot.exe') then begin
   SetGamePath(ResDir);
  END ELSE BEGIN
   if MessageBox(0,'Ce dossier ne semble pas contenir DAoC','Erreur',mb_RetryCancel or mb_IconError)=idRetry then WinAskGamePath;
  END;
 END;
END;

FUNCTION GamePath;
BEGIN
 IF _GamePath<>'2BFND' THEN Result := _GamePath ELSE Result := '';
END;

FUNCTION AppPath;
BEGIN
 Result := _AppPath;
END;

{ TStringMemoryStream }

FUNCTION TStringMemoryStream.ReadStr;
BEGIN
 IF Value = -1 THEN Value := Size;
 SetLength( Result, Value);
 Position := Orig;
 Read( Result[1], Value);
END;

PROCEDURE TStringMemoryStream.WriteStr;
BEGIN
 Write( Value[1], Length(Value));
END;

{ EMapperError }

function EMapperError.ErrorId: Integer;
begin
 Result := _ErrorId;
end;

PROCEDURE EMapperError.GetSpec(OUT Name,Err:STRING;id:Integer);
begin
//clean
end;

constructor EMapperError.RaiseMe(id: Integer);
var
 nam:STRING;
 lst:STRING;
begin
 _ErrorId := id;
 GetSpec( nam, lst, id);
 Create('['+nam+IntToStr(id)+'] '+lst);
end;

{ EMPAKError }

procedure EMPAKError.GetSpec(OUT Name,Err:STRING;id:Integer);
begin
 name := 'MPAK';
 err := SMPAKError[id];
end;

{ EZoneListError }

procedure EZoneListError.GetSpec(OUT Name,Err:STRING;id:Integer);
begin
 name := 'ZoneList';
 err := SZoneListError[id];
end;

{ ERenderError }

procedure ERenderError.GetSpec(OUT Name,Err:STRING;id:Integer);
begin
 name := 'RENDER';
 err := SRenderError[id];
end;

{ EZoneError }

procedure EZoneError.GetSpec(out Name, Err: STRING; id: Integer);
begin
 name := 'ZONE';
 err := SZONEError[id];
end;

INITIALIZATION
 _Apppath:=ExtractFilePath(ParamStr(0));
 Pathyfy(_AppPath);
 ConfigFile:=TIniFile.Create(AppPath+'config.ini');
 _GamePath:=ConfigFile.ReadString('config','GamePath','2BFND');
 Owned_Window.CreateMainWindow(0,0,128,128,false);
 CreateDevice(Owned_Window.GetWinHandle,false,nil);
 OutputResult := osNone;
FINALIZATION
 ConfigFile.Free;
END.
