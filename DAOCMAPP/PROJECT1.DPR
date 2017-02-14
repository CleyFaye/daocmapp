program Project1;
{$APPTYPE CONSOLE}
uses
  Graphics,
  GraphicEx,
  sysutils,
  windows,
  classes,
  dempak in 'dempak.pas',
  general_res in 'general_res.pas',
  zonelist in 'zonelist.pas',
  BackgroundRender in 'BackgroundRender.pas',
  zone in 'zone.pas',
  RiverRender in 'RiverRender.pas';

var
 inputfilename:string;
 inputstr:TStringMemoryStream;
 outputstr:TStringMemoryStream;
 filestr:TFileStream;
 z:TDZone;

begin
 WriteLn('daoc mapper test program');
 WriteLn('Tentative de décodage de la zone 100');
 SetOutputResult(osGeneral);
 InitSurface(512,512);
 z := TDZone.Create(100,512);
 RenderBackground(z);
{ z.LoadHeightMap;
 z.HeightMap.SaveToFile(apppath+'height.bmp');}
 SaveOutput(apppath+'zone100',true,100);
 ClearSurface;
 z.Free;
end.
