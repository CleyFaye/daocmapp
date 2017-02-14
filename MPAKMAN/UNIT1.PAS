unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ActnList, Menus, ComCtrls, ToolWin, StdCtrls;

type
  TForm1 = class(TForm)
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ActionList1: TActionList;
    openfile: TAction;
    od: TOpenDialog;
    ListBox1: TListBox;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    sortlist: TAction;
    Extractfile: TAction;
    extractall: TAction;
    procedure FormCreate(Sender: TObject);
    procedure openfileExecute(Sender: TObject);
    procedure sortlistUpdate(Sender: TObject);
    procedure sortlistExecute(Sender: TObject);
    procedure ExtractfileUpdate(Sender: TObject);
    procedure ExtractfileExecute(Sender: TObject);
    procedure extractallUpdate(Sender: TObject);
    procedure extractallExecute(Sender: TObject);
  private
    { Déclarations privées }
  public
   OpenFileName:STRING;
  end;

var
  Form1: TForm1;

implementation

uses general_res,dempak, filectrl;

{$R *.DFM}

procedure TForm1.FormCreate(Sender: TObject);
begin
 OpenFileName := '';
end;

procedure TForm1.openfileExecute(Sender: TObject);
var
 str:TStringMemoryStream;
begin
 if od.execute then begin
  if _IsMPAK(od.filename) then begin
   ListBox1.Items.Clear;
   OpenFileName := od.filename;
   str := _DeMPAK(OpenFileName,'',dcGetCatalog);
   ListBox1.Items.CommaText := str.ReadStr;
   str.Free;
  end else begin
   ShowMessage('Le fichier spécifié n''est pas un fichier MPAK valide');
  end;
 end;
end;

procedure TForm1.sortlistUpdate(Sender: TObject);
begin
 sortlist.enabled := ListBox1.Items.Count>0;
end;

procedure TForm1.sortlistExecute(Sender: TObject);
var
 s:TStringList;
begin
 s:=TStringList.Create;
 s.commatext:=ListBox1.Items.CommaText;
 s.Sort;
 ListBox1.Items.CommaText:=s.commatext;
 s.free;
end;

procedure TForm1.ExtractfileUpdate(Sender: TObject);
begin
 ExtractFile.Enabled := ListBox1.ItemIndex>-1;
end;

procedure TForm1.ExtractfileExecute(Sender: TObject);
var
 str:TStringMemoryStream;
 f:TFileStream;
 dest:String;
begin
 IF SelectDirectory('Dossier de sortie','',dest) THEN BEGIN
  str:=_DeMPAK(OpenFileName,ListBox1.Items.Strings[ListBox1.ItemIndex],dcGetEntry);
  Pathyfy(dest);
  f:=TFileStream.Create(dest+ListBox1.Items.Strings[ListBox1.ItemIndex],fmCreate);
  f.CopyFrom(str,0);
  f.Free;
  str.Free;
 END;
end;

procedure TForm1.extractallUpdate(Sender: TObject);
begin
 ExtractAll.Enabled := ListBox1.Items.count>0;
end;

procedure TForm1.extractallExecute(Sender: TObject);
var
 dest:String;
begin
 IF SelectDirectory('Dossier de sortie','',dest) THEN BEGIN
  _DeMPAK(OpenFileName,dest);
 END;
end;

end.
