program Project1;
{$APPTYPE CONSOLE}
uses
  sysutils,
  zlibex,
  windows,
  classes;

const
 chunksize=1024;

var
 inputfilename:string;
 outputfilename:string;
 inputstream:File;
 tempstream:String;
 outputstream:File;
 tempfile1:file;
 s:string;
 streaminit:boolean;
 stream:TZStreamRec;
 unused_size:integer;
 filelist:TStringList;
 fileposlist:ARRAY OF Integer;
 i:integer;

function CZInflate(str:string):string;
var
 s:string;
 res:integer;
 b:boolean;
 in_size:integer;
 before_out:integer;
 tstr:string;
begin
 unused_size:=0;
 tempstream:='';
 if streaminit then begin
  in_size:=length(str)+stream.total_in;
  s:=str;
  stream.next_in:=@s[1];
  stream.avail_in:=length(s);
  stream.opaque:=nil;
  setlength(tstr,chunksize);
  b:=false;
//  stream.next_out:=@tempstream[1];
  stream.avail_out:=chunksize;
  stream.next_out:=@tstr[1];
  before_out:=stream.total_out;
  repeat
   res:=inflate(stream,0);
   if res=z_ok then begin
    if stream.avail_out=0 then begin
     tempstream:=tempstream+tstr;
     stream.next_out:=@tstr[1];
     stream.avail_out:=chunksize;
    end;
   end;
   if res=z_stream_end then b:=true;
//   if res=z_stream_error then b:=true;
   if res=z_buf_error then b:=true;
   if (res<0)and(not(b)) then raise exception.Create('erreur dans la décompression');
  until b;
  tempstream:=tempstream+copy(tstr,1,chunksize-stream.avail_out);
  stream.avail_out:=0;
  unused_size:=in_size-stream.total_in;
 end else begin
  tempstream:='';
  streaminit:=true;
  in_size:=length(str);
  s:=str;
  ZeroMemory(@stream,sizeof(stream));
  stream.next_in:=@s[1];
  stream.avail_in:=length(s);
  stream.opaque:=nil;
  res:=inflateinit(stream);
  if res<>z_ok then raise exception.Create('Erreur à l''initialisation du flux de décompression.');
  setlength(tstr,chunksize);
  b:=false;
  stream.next_out:=@tstr[1];
  stream.avail_out:=chunksize;
  repeat
   res:=inflate(stream,0);
   if res=z_ok then begin
    if stream.avail_out=0 then begin
     tempstream:=tempstream+tstr;
     stream.next_out:=@tstr[1];
     stream.avail_out:=chunksize;
    end;
   end;
   if res=z_stream_end then b:=true;
//   if res=z_stream_error then b:=true;
   if res=z_buf_error then b:=true;
   if (res<0)and(not(b)) then raise exception.Create('erreur dans la décompression');
  until b;
  tempstream:=tempstream+copy(tstr,1,chunksize-stream.avail_out);
  stream.avail_out:=0;
  unused_size:=in_size-stream.total_in;
 end;
end;

procedure CZStop;
begin
 inflateend(stream);
 streaminit:=false;
end;

procedure SafeFreeMem;
begin
 try
  CloseFile(inputstream);
 except
 end;
 try
  CloseFile(outputstream);
 except
 end;
 try
  closefile(tempfile1);
 except
 end;
 filelist.free;
 SetLength(fileposlist,0);
end;

function ReadStream:HResult;
var
 str:string;
 i:integer;
 dstr:string;
 orig:integer;
 processed:integer;
 sss:string;
begin
 result:=0;
 orig:=Filepos(inputstream);
 processed:=0;
 Assignfile(tempfile1,'zstream.tmp');
 rewrite(tempfile1,1);
 repeat
  setlength(str,chunksize);
  BlockRead(inputstream,str[1],chunksize,i);
  setlength(str,i);
  tempstream:='';
  CZInflate(str);
  processed:=processed+i;
  BlockWrite(tempfile1,tempstream[1],length(tempstream));
 until (unused_size<>0)or(i<chunksize);
 seek(inputstream,orig+processed-unused_size);
 closefile(tempfile1);
 CZStop;
end;

procedure AddFilePos(i:integer);
begin
 setlength(fileposlist,length(fileposlist)+1);
 fileposlist[high(fileposlist)]:=i;
end;

procedure DecodeDirectory(s:string;baseoffset:integer);
var
 offset:integer;
 nam:string;
 entryoffset:integer;
 i,i2:integer;
 s2:string;
begin
 filelist.Clear;
 SetLength(fileposlist,0);
 offset:=1;
 while offset+283 < length(s) do begin
  nam:='';
  i:=0;
  while (offset+i<length(s))and(s[offset+i]<>chr(0)) do begin
   nam:=nam+s[offset+i];
   i:=i+1;
  end;
  s2:='';
  for i2:=0 TO 3 do begin
   s2:=s2+s[offset+272+i2];
  end;
  copymemory(@entryoffset,@s2[1],4);
  AddFilePos(entryoffset+baseoffset);
  filelist.Add(LowerCase(nam));
  offset:=offset+284;
 end;
end;

begin
 streaminit:=false;
 filelist:=TStringList.Create;
 WriteLn('MPAK test program');
 tempstream:='';
 WriteLn('Fichier source:');
 // Définir le nom de la source ici
 inputfilename:='ter003.mpk';
 WriteLn(inputfilename);
 // Ouverture du fichier
 WriteLn('Ouverture du fichier');
 AssignFile(inputstream,inputfilename);
 ReSet(inputstream,1);
 // On vérifie que c'est un MPAK
 WriteLn('Vérification FCC');
 s:='XXXX';
 BlockRead(inputstream,s[1],4);
 WriteLn('FCC:'+s);
 if s='MPAK' then begin
  // Fichier MPAK, on continue dans cette indentation
  // Le début des données se fait au 21eme octet
  WriteLn('Déplaçage en position 21 et lecture du premier flux');
  Seek(inputstream,21);
  ReadStream;
  AssignFile(tempfile1,'zstream.tmp');
  ReSet(tempfile1,1);
  setlength(s,filesize(tempfile1));
  BlockRead(tempfile1,s[1],length(s));
  WriteLn('Nom du fichier d''origine:'+s);
  s:='';
  CloseFile(tempfile1);
  WriteLn('Lecture de la liste des fichiers stockées');
  ReadStream;
  AssignFile(tempfile1,'zstream.tmp');
  ReSet(tempfile1,1);
  setlength(s,filesize(tempfile1));
  BlockRead(tempfile1,s[1],length(s));
  CloseFile(tempfile1);
  DecodeDirectory(s,filepos(inputstream));
  WriteLn('Création du dossier de sortie');
  CreateDir(inputfilename+'.out');
  for i:=0 to filelist.count-1 do begin
   Seek(inputstream,fileposlist[i]);
   WriteLn('Lecture du fichier : '+filelist.strings[i]);
   ReadStream;
   WriteLn('Copie...');
   outputfilename:=inputfilename+'.out\'+filelist.strings[i]+#0;
   CopyFile('zstream.tmp'#0,@outputfilename[1],false);
  end;
  WriteLn('Terminé');
 end else begin
  WriteLn('Le fichier n''est pas un fichier MPAK');
 end;
 SafeFreeMem;
end.
