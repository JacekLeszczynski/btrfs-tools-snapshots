unit conf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin,
  Buttons, ExtCtrls, ExtMessage;

type

  { TFConf }

  TFConf = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    mess: TExtMessage;
    restart_dbus: TCheckBox;
    Label10: TLabel;
    Label9: TLabel;
    newrootsnapshot: TCheckBox;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    RadioButton4: TRadioButton;
    updategrub: TCheckBox;
    Label2: TLabel;
    maxmigawek: TSpinEdit;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure maxmigawekChange(Sender: TObject);
    procedure newrootsnapshotChange(Sender: TObject);
    procedure restart_dbusChange(Sender: TObject);
    procedure updategrubChange(Sender: TObject);
    procedure _AUTOWYZWALACZ(Sender: TObject);
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

procedure TFConf.BitBtn2Click(Sender: TObject);
begin
  showmessage('System zostanie zrestartowany za pomocą ustawionego sygnału restartowania systemu. Nic więcej nie będzie wykonywane. Opcja służy do przetestowania poprawności wykonywania tej operacji.');
  if mess.ShowConfirmationYesNo('Kontynuować ?') then
  begin
    _FORCE_REBOOT:=true;
    close;
  end;
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

procedure TFConf.newrootsnapshotChange(Sender: TObject);
begin
  _BACK_ROOT_GEN_SNAPSHOT:=newrootsnapshot.Checked;
  dm.ini.WriteBool('back-root-gen-snapshot',_BACK_ROOT_GEN_SNAPSHOT);
end;

procedure TFConf.restart_dbusChange(Sender: TObject);
begin
  _RESTART_DBUS:=restart_dbus.Checked;
  dm.ini.WriteBool('restart-dbus',_RESTART_DBUS);
end;

procedure TFConf.updategrubChange(Sender: TObject);
begin
  _UPDATE_GRUB:=updategrub.Checked;
  dm.ini.WriteBool('update-grub',_UPDATE_GRUB);
end;

procedure TFConf._AUTOWYZWALACZ(Sender: TObject);
begin
  if RadioButton1.Checked then
  begin
    _AUTO_RUN:=false;
    if dm.ini.ReadBool('auto-run',false)<>_AUTO_RUN then dm.ini.WriteBool('auto-run',_AUTO_RUN);
  end else begin
    if RadioButton2.Checked then dm.ini.WriteString('trigger','dpkg') else
    if RadioButton3.Checked then dm.ini.WriteString('trigger','cron.daily') else
    if RadioButton4.Checked then dm.ini.WriteString('trigger','cron.weekly');
    _AUTO_RUN:=true;
    if dm.ini.ReadBool('auto-run',false)<>_AUTO_RUN then dm.ini.WriteBool('auto-run',_AUTO_RUN);
  end;
end;

procedure TFConf.wczytaj_all;
var
  s: string;
  a: integer;
begin
  if _AUTO_RUN then
  begin
    s:=dm.ini.ReadString('trigger','dpkg');
    if s='dpkg' then a:=0 else
    if s='cron.daily' then a:=1 else
    if s='cron.weekly' then a:=2 else a:=-1;
    case a of
      0: RadioButton2.Checked:=true;
      1: RadioButton3.Checked:=true;
      2: RadioButton4.Checked:=true;
      else  RadioButton1.Checked:=true;
    end;
  end else RadioButton1.Checked:=true;
  updategrub.Checked:=_UPDATE_GRUB;
  maxmigawek.Value:=_MAX_COUNT_SNAPSHOTS;
  newrootsnapshot.Checked:=_BACK_ROOT_GEN_SNAPSHOT;
  restart_dbus.Checked:=_RESTART_DBUS;
end;

end.

