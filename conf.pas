unit conf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin,
  Buttons;

type

  { TFConf }

  TFConf = class(TForm)
    BitBtn1: TBitBtn;
    Label3: TLabel;
    updategrub: TCheckBox;
    aktywne: TCheckBox;
    wyzwalacz: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    maxmigawek: TSpinEdit;
    procedure aktywneChange(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure maxmigawekChange(Sender: TObject);
    procedure updategrubChange(Sender: TObject);
    procedure wyzwalaczChange(Sender: TObject);
  private
    procedure wczytaj_all;
  public

  end;

var
  FConf: TFConf;

implementation

uses
  config;

{$R *.lfm}

{ TFConf }

procedure TFConf.BitBtn1Click(Sender: TObject);
begin
  close;
end;

procedure TFConf.aktywneChange(Sender: TObject);
begin
  _AUTO_RUN:=aktywne.Checked;
  dm.ini.WriteBool('auto-run',_AUTO_RUN);
end;

procedure TFConf.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction:=caFree;
end;

procedure TFConf.FormShow(Sender: TObject);
begin
  wczytaj_all;
end;

procedure TFConf.maxmigawekChange(Sender: TObject);
begin
  _MAX_COUNT_SNAPSHOTS:=maxmigawek.Value;
  dm.ini.WriteInteger('snapshots_max',_MAX_COUNT_SNAPSHOTS);
end;

procedure TFConf.updategrubChange(Sender: TObject);
begin
  _UPDATE_GRUB:=updategrub.Checked;
  dm.ini.WriteBool('update-grub',_UPDATE_GRUB);
end;

procedure TFConf.wyzwalaczChange(Sender: TObject);
begin
  case wyzwalacz.ItemIndex of
    0: dm.ini.WriteString('trigger','dpkg');
    1: dm.ini.WriteString('trigger','cron.daily');
    2: dm.ini.WriteString('trigger','cron.weekly');
  end;
end;

procedure TFConf.wczytaj_all;
var
  s: string;
  a: integer;
begin
  aktywne.Checked:=_AUTO_RUN;
  updategrub.Checked:=_UPDATE_GRUB;
  s:=dm.ini.ReadString('trigger','dpkg');
  if s='dpkg' then a:=0 else
  if s='cron.daily' then a:=1 else
  if s='cron.weekly' then a:=2 else a:=-1;
  wyzwalacz.ItemIndex:=a;
  maxmigawek.Value:=_MAX_COUNT_SNAPSHOTS;
end;

end.

