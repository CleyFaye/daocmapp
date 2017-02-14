UNIT dempak;

INTERFACE

USES
 General_Res;

TYPE
 TDeMPAKCommand=(dcExtractAll,dcGetCatalog,dcGetEntry);

FUNCTION _IsMPAK( InputFileName:STRING):Boolean;

FUNCTION _DeMPAK( InputFileName:STRING;
                  BaseDirectory:STRING;
                  Command:TDeMPAKCommand=dcExtractAll
                  ):TStringMemoryStream;

IMPLEMENTATION

USES
 SysUtils,
 ZlibEX,
 Windows,
 FileCtrl,
 Classes;

CONST
 ChunkSize = 1024;

VAR
// Variable de décompression
 ZStream:TZStreamRec;
 ZLIB_Initialized:Boolean;             // Indique si il s'agit du premier appel à zLib
 Junk_Input:Integer;                   // Quantité de données non utilisé lors de la décompression

// Variable du catalogue
 FileDirectory:TStringList;
 FilePosDirectory:ARRAY OF Integer;

// Variable fichier
 InputFile:FILE;

// Flux mémoire temporaire
 TempStream:TStringMemoryStream;

FUNCTION _IsMPAK;
VAR
 f:FILE;
 s:STRING;
BEGIN
 AssignFile( f, InputFileName);
 ReSet(f,1);
 s := 'XXXX';
 BlockRead(f,s[1],4);
 CloseFile(f);
 Result := s = 'MPAK';
END;

PROCEDURE SafeFreeMem;
BEGIN
 TRY
  CloseFile(InputFile);
 EXCEPT
 END;
 FileDirectory.Free;
 TempStream.Free;
END;

FUNCTION CZInflate(DeflatedString:STRING):STRING;
VAR
 Input_Size:Integer;
 OutputBuffer:STRING;
 LoopChecker:Boolean;
 FuncResult:HResult;
BEGIN
 OutStr('Entrée dans CZInflate',3);
 Junk_Input := 0;
 Result := '';
 IF ZLIB_Initialized THEN BEGIN
  Input_Size := Length(DeflatedString) + ZStream.Total_In;
  ZStream.Next_In := @DeflatedString[1];
  ZStream.Avail_In := Length(DeflatedString);
  ZStream.Opaque := NIL;
  LoopChecker := False;
  SetLength(OutputBuffer,chunksize);
  ZStream.Avail_Out := ChunkSize;
  ZStream.Next_Out := @OutputBuffer[1];
  REPEAT
   FuncResult := Inflate( ZStream, 0);
   CASE FuncResult OF
    Z_Ok:BEGIN
     IF ZStream.Avail_Out = 0 THEN BEGIN
      Result := Result + OutputBuffer;
      ZStream.Next_Out := @OutputBuffer[1];
      ZStream.Avail_Out := ChunkSize;
     END;
    END;
    Z_Stream_End:BEGIN
     LoopChecker := True;
    END;
    Z_Buf_Error:BEGIN
     LoopChecker := True;
    END;
   END;
   IF ( FuncResult < 0 ) AND ( NOT LoopChecker ) THEN RAISE EMPAKError.RaiseMe(2);
  UNTIL LoopChecker;
  Result := Result + Copy( OutputBuffer, 1, Chunksize - ZStream.Avail_Out);
  Junk_Input := Input_Size - ZStream.Total_In;
 END ELSE BEGIN
  OutStr('Initialisation du flux de décompression',2);
  ZLIB_Initialized := True;
  Input_Size := Length(DeflatedString);
  ZeroMemory( @ZStream, SizeOf(ZStream));
  ZStream.Next_In := @DeflatedString[1];
  ZStream.Avail_In := Length(DeflatedString);
  ZStream.Opaque := NIL;
  FuncResult := InflateInit(ZStream);
  IF FuncResult <> Z_Ok THEN RAISE EMPAKError.RaiseMe(3);
  LoopChecker := False;
  SetLength( OutputBuffer, ChunkSize);
  ZStream.Next_Out := @OutputBuffer[1];
  ZStream.Avail_Out := ChunkSize;
  REPEAT
   FuncResult := Inflate( ZStream, 0);
   CASE FuncResult OF
    Z_Ok:BEGIN
     IF ZStream.Avail_Out = 0 THEN BEGIN
      Result := Result + OutputBuffer;
      ZStream.Next_Out := @OutputBuffer[1];
      ZStream.Avail_Out := ChunkSize;
     END;
    END;
    Z_Stream_End:BEGIN
     LoopChecker := True;
    END;
    Z_Buf_Error:BEGIN
     LoopChecker := True;
    END;
   END;
   IF ( FuncResult < 0 ) AND ( NOT LoopChecker ) THEN RAISE EMPAKError.RaiseMe(2);
  UNTIL LoopChecker;
  Result := Result + Copy( OutputBuffer, 1, ChunkSize - ZStream.Avail_Out);
  Junk_Input := Input_Size - ZStream.Total_In;
 END;
END;

PROCEDURE CZStop;
BEGIN
 InflateEnd(ZStream);
 ZLIB_Initialized := False;
END;

FUNCTION ReadStream:HResult;
VAR
 StreamOrigin:Integer;
 ByteRead:Integer;
 ReadBuffer:STRING;
 ReadSize:Integer;
BEGIN
 OutStr( 'Entrée dans la procédure ReadStream', 3);
 Result := 0;
 StreamOrigin := Filepos(InputFile);
 ByteRead := 0;
 OutStr( 'Vidage du flux mémoire temporaire', 3);
 TempStream.Clear;
 REPEAT
  SetLength( ReadBuffer, ChunkSize);
  BlockRead( InputFile, ReadBuffer[1], ChunkSize, ReadSize);
  SetLength( ReadBuffer, ReadSize);
  ByteRead := ByteRead + ReadSize;
  TempStream.WriteStr(CZInflate(ReadBuffer));
 UNTIL ( Junk_Input <> 0 ) OR ( ReadSize < ChunkSize);
 Seek( InputFile, StreamOrigin + ByteRead - Junk_Input);
 CZStop;
END;

PROCEDURE AddFilePos(Value:Integer);
BEGIN
 SetLength( FilePosDirectory, Length(FilePosDirectory) + 1);
 FilePosDirectory[High(FilePosDirectory)] := Value;
END;

PROCEDURE DecodeDirectory;
var
 BaseOffSet:Integer;
 Catalog:STRING;
 Offset:Integer;
 TempName:STRING;
 Reader:Integer;
 EntryOffset:Integer;
begin
 OutStr( 'Entrée dans DecodeDirectory', 3);
 BaseOffset := FilePos(InputFile);
 Catalog := TempStream.ReadStr;
 FileDirectory.Clear;
 SetLength(FilePosDirectory,0);
 Offset := 1;
 WHILE Offset + 283 <= Length(Catalog) DO BEGIN
  TempName := '';
  Reader := 0;
  WHILE ( ( Offset + Reader ) < Length(Catalog) ) AND (Catalog[Offset + Reader] <> Chr(0) ) DO BEGIN
   TempName := TempName + Catalog[Offset + Reader];
   Reader := Reader + 1;
  END;
  CopyMemory(@EntryOffset,@Catalog[OffSet+272],4);
  AddFilePos(BaseOffset + EntryOffset);
  FileDirectory.Add(LowerCase(TempName));
  Offset := Offset + 284;
 END;
END;

FUNCTION _DeMPAK;
VAR
 i:Integer;
 s,s2:STRING;
 WritingStream:TFileStream;
BEGIN

 Result := NIL;

 TRY
  // Initialisation des variables communes aux fonctions
  OutStr( 'Initialisation des variables', 2);
  OutStr( '-->ZLIB_Initialized', 3);
  ZLIB_Initialized := false;
  OutStr( '-->FileCatalog', 3);
  FileDirectory := TStringList.Create;
  OutStr( '-->TempStream', 3);
  TempStream := TStringMemoryStream.Create;

  // Ouverture du fichier
  OutStr( 'Ouverture du fichier '+InputFileName, 2);
  AssignFile(InputFile, InputFileName);
  ReSet(InputFile, 1);

  // On vérifie que c'est un MPAK
  OutStr( 'Vérification du FCC', 2);
  s := 'XXXX';
  BlockRead(InputFile,s[1],4);
  OutStr( 'FCC:'+s, 3);
  IF s = 'MPAK' THEN BEGIN
   // Fichier MPAK, on continue dans cette indentation
   // Le début des est au 21eme octet
   OutStr( 'Décalage 21 et lecture du premier flux', 2);
   Seek( InputFile, 21);
   ReadStream;
   s:=TempStream.ReadStr;
   OutStr( 'Nom du fichier d''origine:'+s, 2);
   OutStr( 'Lecture de la liste de fichier', 2);
   ReadStream;
   OutStr( 'Décodage de la liste de ficheir', 2);
   DecodeDirectory;
   IF Command = dcGetCatalog THEN BEGIN
    Result := TStringMemoryStream.Create;
    Result.WriteStr(FileDirectory.CommaText);
   END;
   IF Command = dcExtractAll THEN BEGIN
    Pathyfy(BaseDirectory);
    BaseDirectory := BaseDirectory + ExtractFileName(InputFileName) + '.out\';
    ForceDirectories(BaseDirectory);
    FOR i:=0 TO FileDirectory.Count-1 DO BEGIN
     Seek(InputFile,FilePosDirectory[i]);
     OutStr( 'Décompression du fichier '+FileDirectory.Strings[i], 1);
     ReadStream;
     OutStr( 'Ecriture du fichier '+basedirectory+FileDirectory.Strings[i], 1);
     s:=BaseDirectory+FileDirectory.Strings[i];
     s2:=s+#0;
     IF FileExists(s) THEN DeleteFile(@s2[1]);
     WritingStream := TFileStream.Create( s, fmCreate);
     WritingStream.CopyFrom( TempStream, 0);
     WritingStream.Free;
    END;
   END;
   IF Command = dcGetEntry THEN BEGIN
    BaseDirectory := LowerCase(BaseDirectory);
    IF FileDirectory.IndexOf(BaseDirectory) = -1 THEN BEGIN
     RAISE EMPAKError.RaiseMe(1);
    END;
    Seek(InputFile,FilePosDirectory[FileDirectory.IndexOf(BaseDirectory)]);
    OutStr( 'Décompression du fichier '+BaseDirectory, 2);
    ReadStream;
    OutStr( 'Transfert des données décompressée comme résultat de la fonction', 2);
    Result := TStringMemoryStream.Create;
    Result.CopyFrom( TempStream, 0);
   END;
   OutStr( 'Terminé', 2);
  END ELSE BEGIN
   OutStr( 'Le fichier '+InputFileName+' n''est pas un fichier MPAK', 2);
  END;
 FINALLY
  SafeFreeMem;
 END;
END;

END.
(*
Mode d'emploi de cette unitée:
Elle permet de décoder les fichiers MPAK(mpk et npk) de DAoC

_IsMPAK
PAramères:
InputFileName:STRING        Nom du fichier à vérifier
Renvoie True si le fichier est un MPAK(d'après FCC)

_DeMPAK
Paramètres:
InputFileName:STRING        Nom du fichier MPAK source
BaseDirectory:STRING        Dossier où seront placé les fichiers extraits
                            OU nom du fichier à extraire
Command:TDeMPAKCommand      Commande à éxécuter

Result:TStringMemoryStream  Dépend du paramètre Command.

Type de données:

TDeMPAKCommand=(dcExtractAll,dcGetCatalog,dcGetEntry)
-dcCheckMPAK : Vérifie qu'il s'agit bien d'un fichier MPAK
-dcExtractAll : extrait tout les fichiers de la source vers le dossier
                BaseDirectory spécifié, sous dossiers sources.out\
-dcGetCatalog : renvoie dans Result le CommaText du catalogue de fichier
-dcGetEntry : renvoie dans Result le fichier spécifié par BaseDirectory
              (exception MPAK1 si fichier introuvable)
              (le fichier zones.mpk est géré spécialement et ne permet
               d'extraire que zones.dat)

Auteur : Gabriel Paul 'Cley Faye' Risterucci
Homepage : new664.fr.st
mail : dareaperpa666@hotmail.com

Le fichier source de mon mapper DAoC est grandement inspiré de celui trouvé
sur www.randomly.org.
