unit RiverRender;

interface

uses General_Res, zone;

procedure RenderRiver(zone:TDZone);

implementation

uses sysutils, windows, classes, graphics,graphicex;

procedure RenderRiver;
var
 rivercheck,i:integer;
 count:integer;
 leftbank:ARRAY OF TPoint;
 rightbank:ARRAY OF TPoint;
 minx,maxx,miny,maxy:integer;
 strl:TStringList;
 lb,rb:string;
 rivname:string;
 x,y:integer;
 height:integer;
 color:TColor;

procedure AddLeft(x,y:integer);
begin
 SetLength(leftbank,length(leftbank)+1);
 leftbank[high(leftbank)]:=point(x,y);
end;
procedure AddRight(x,y:integer);
begin
 SetLength(rightbank,length(rightbank)+1);
 rightbank[high(rightbank)]:=point(x,y);
end;
procedure ReverseRight;
var
 tmp:ARRAY OF TPoint;
 ii:integer;
begin
 SetLength(tmp,length(rightbank));
 CopyMemory(@tmp[1],@rightbank[1],SizeOf(TPoint)*Length(RightBank));
 for ii:=0 to high(tmp) do begin
  RightBank[ii]:=tmp[High(tmp)-ii];
 end;
 SetLength(tmp,0);
end;

begin
 rivercheck:=0;
 strl:=TStringList.Create;
 while zone.sector_dat.ReadInteger('river'+int2str(rivercheck,2),'bankpoints',-1)<>-1 do begin
  rivname := 'river'+int2str(rivercheck,2);
  count:=zone.sector_dat.ReadInteger(rivname,'bankpoints',-1);
  if count>0 then begin
   SetLength(leftbank,0);
   SetLength(rightbank,0);
   minx := -1;
   maxx := -1;
   miny := -1;
   maxy := -1;

   for i := 0 to count-1 do begin
    lb := zone.sector_dat.ReadString(rivname,'left'+int2str(i,2),'0,0,0');
    rb := zone.sector_dat.ReadString(rivname,'right'+int2str(i,2),'0,0,0');
    strl.CommaText := lb;
    x := zone.RToIX(StrToInt(strl.strings[0])*256);
    x := zone.RToIY(StrToInt(strl.strings[1])*256);
    AddLeft(x,y);
    if minx=-1 then begin
     minx:=x;
     maxx:=x;
     miny:=y;
     maxy:=y;
    end;
    if x<minx then minx:=x;
    if y<miny then miny:=y;
    if x>maxx then maxx:=x;
    if y>maxy then maxy:=y;
    strl.CommaText := rb;
    x := zone.RToIX(StrToInt(strl.strings[0])*256);
    x := zone.RToIY(StrToInt(strl.strings[1])*256);
    AddRight(x,y);
    if x<minx then minx:=x;
    if y<miny then miny:=y;
    if x>maxx then maxx:=x;
    if y>maxy then maxy:=y;
   end;
   ReverseRight;
   height := zone.sector_dat.ReadInteger(rivname,'height',0);
   color := zone.sector_dat.ReadInteger(rivname,'color',clBlue);
   
  end;
  rivercheck:=rivercheck+1;
 end;
 strl.Free;

                rightbank.reverse();
                height = sd.getint(s, 'height')

                try:
                    color = int(sd.get(s, 'color'))
                    color = (color % 256, (color / 256) % 256, color / 65536)
                except ConfigParser.NoOptionError, e:
                    color = (0,0,255)

                color = self.zone.getColor(self.name, 'color', color)
                self.rivers.append( (height, leftbank+rightbank, (minx, miny, maxx+1, maxy+1), color) )

        if self.rivers: self.zone.loadHeightmap()

end;

end.
