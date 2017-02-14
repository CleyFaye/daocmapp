object Form1: TForm1
  Left = 378
  Top = 227
  Width = 275
  Height = 267
  Caption = 'MPAK Explorer'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 267
    Height = 21
    AutoSize = True
    ButtonHeight = 21
    ButtonWidth = 63
    Caption = 'ToolBar1'
    EdgeInner = esNone
    EdgeOuter = esNone
    Flat = True
    ShowCaptions = True
    TabOrder = 0
    object ToolButton1: TToolButton
      Left = 0
      Top = 0
      Action = openfile
    end
    object ToolButton2: TToolButton
      Left = 63
      Top = 0
      Action = Extractfile
    end
    object ToolButton3: TToolButton
      Left = 126
      Top = 0
      Action = extractall
    end
    object ToolButton5: TToolButton
      Left = 189
      Top = 0
      Width = 8
      Caption = 'ToolButton5'
      ImageIndex = 4
      Style = tbsSeparator
    end
    object ToolButton4: TToolButton
      Left = 197
      Top = 0
      Action = sortlist
    end
  end
  object ListBox1: TListBox
    Left = 8
    Top = 32
    Width = 251
    Height = 199
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 1
  end
  object ActionList1: TActionList
    Left = 8
    Top = 32
    object openfile: TAction
      Caption = 'Ouvrir'
      OnExecute = openfileExecute
    end
    object sortlist: TAction
      Caption = 'Trier'
      OnExecute = sortlistExecute
      OnUpdate = sortlistUpdate
    end
    object Extractfile: TAction
      Caption = 'Extraire'
      OnExecute = ExtractfileExecute
      OnUpdate = ExtractfileUpdate
    end
    object extractall: TAction
      Caption = 'Extraire tout'
      OnExecute = extractallExecute
      OnUpdate = extractallUpdate
    end
  end
  object od: TOpenDialog
    DefaultExt = 'MPK'
    Filter = 'Fichiers MPAK|*.MPK;*.NPK'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Ouvrir un fichier'
    Left = 8
    Top = 64
  end
end
