unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, Menus, ExtMessage;

type

  { TFMain }

  TFMain = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    BitBtn3: TBitBtn;
    BitBtn4: TBitBtn;
    BitBtn6: TBitBtn;
    MainMenu1: TMainMenu;
    MenuKonfiguracja: TMenuItem;
    mess: TExtMessage;
    lMount: TListBox;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn3Click(Sender: TObject);
    procedure BitBtn4Click(Sender: TObject);
    procedure BitBtn6Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lMountClick(Sender: TObject);
    procedure MenuKonfiguracjaClick(Sender: TObject);
  private
    lMountSciezki: TStringList;
    procedure init;
    procedure wczytaj_woluminy;
    procedure refresh_przyciski;
    procedure generuj_btrfs_grub_migawki;
  public

  end;

var
  FMain: TFMain;

implementation

uses
  config, BaseUnix, Unix, conf;

{$R *.lfm}

{ TFMain }

procedure TFMain.FormCreate(Sender: TObject);
begin
  Caption:='Btrfs Tools Snapshots Gui ('+dm.wersja+')';
  lMountSciezki:=TStringList.Create;
  BitBtn4.Caption:='Przywróć do migawki'+#10+'z której uruchomiony'+#10+'jest system aktualnie';
end;

procedure TFMain.BitBtn1Click(Sender: TObject);
var
  s: string;
  id: integer;
  nazwa,migawka: string;
begin
  if _ROOT<>_SWIAT then exit;
  s:=lMount.Items[lMount.ItemIndex];
  s:=StringReplace(s,'   \> ','',[]);
  id:=StrToInt(GetLineToStr(s,2,' '));
  nazwa:=GetLineToStr(s,9,' ');
  migawka:='@'+nazwa+'_'+FormatDateTime('yyyy-mm-dd',date);
  if dm.list(migawka) then
  begin
    dm.usun_migawke(migawka);
    wczytaj_woluminy;
    application.ProcessMessages;
    sleep(500);
  end;
  dm.nowa_migawka(nazwa,migawka);
  wczytaj_woluminy;
  if nazwa='@' then generuj_btrfs_grub_migawki;
end;

procedure TFMain.BitBtn2Click(Sender: TObject);
var
  s: string;
  id: integer;
  nazwa: string;
begin
  if _ROOT<>_SWIAT then exit;
  s:=lMount.Items[lMount.ItemIndex];
  s:=StringReplace(s,'   \> ','',[]);
  id:=StrToInt(GetLineToStr(s,2,' '));
  nazwa:=GetLineToStr(s,9,' ');
  dm.usun_migawke(nazwa);
  wczytaj_woluminy;
  if pos('@@_',nazwa)=1 then generuj_btrfs_grub_migawki;
end;

procedure TFMain.BitBtn3Click(Sender: TObject);
begin
  generuj_btrfs_grub_migawki;
end;

procedure TFMain.BitBtn4Click(Sender: TObject);
begin
  if _ROOT=_SWIAT then exit;
  showmessage('Zostanie przywrócona migawka, stary wolumin zostanie usunięty i wszystkie pozostałe migawki zostaną usunięte. Tej operacji nie da się cofnąć! Stracisz wszystkie informacje przechowywane na usuwanych woluminach. Zostaniesz zapytany czy kontynuować i wykonać tą operację. W razie kontynuacji operacja zostanie wykonana i komputer automatycznie zrestartowany...');
  if mess.ShowConfirmationYesNo('Kontynuować ?') then
  begin
    dm.wroc_do_migawki;
    close;
  end;
end;

procedure TFMain.BitBtn6Click(Sender: TObject);
begin
  close;
end;

procedure TFMain.FormDestroy(Sender: TObject);
begin
  lMountSciezki.Free;
end;

procedure TFMain.FormShow(Sender: TObject);
begin
  Init;
  if _SWIAT<>_ROOT then
  begin
    BitBtn1.Enabled:=false;
    BitBtn2.Enabled:=false;
    BitBtn4.Enabled:=true;
  end else BitBtn4.Enabled:=false;
end;

procedure TFMain.lMountClick(Sender: TObject);
begin
  refresh_przyciski;
end;

procedure TFMain.MenuKonfiguracjaClick(Sender: TObject);
begin
  FConf:=TFConf.Create(self);
  FConf.ShowModal;
end;

procedure TFMain.init;
begin
  wczytaj_woluminy;
end;

procedure TFMain.wczytaj_woluminy;
begin
  if _GUI_ONLYROOT then
    lMount.Items.Assign(dm.wczytaj_woluminy(true))
  else
    lMount.Items.Assign(dm.wczytaj_woluminy);
  lMount.ItemIndex:=0;
  refresh_przyciski;
end;

procedure TFMain.refresh_przyciski;
var
  s: string;
  migawka: boolean;
begin
  if _SWIAT=_ROOT then
  begin
    if lMount.ItemIndex=-1 then
    begin
      BitBtn1.Enabled:=false;
      BitBtn2.Enabled:=false;
    end else begin
      s:=lMount.Items[lMount.ItemIndex];
      migawka:=pos('   \> ',s)>0;
      BitBtn1.Enabled:=not migawka;
      BitBtn2.Enabled:=migawka;
    end;
    BitBtn4.Enabled:=false;
  end;
end;

procedure TFMain.generuj_btrfs_grub_migawki;
var
  wzor,s,sciezka,nazwa,dzien: string;
  i: integer;
  ss: TStringList;
  err: integer;
begin
  if not _UPDATE_GRUB then exit;
  wzor:=dm.generuj_grub_menuitem.Text;
  ss:=TStringList.Create;
  try
    for i:=0 to lMount.Items.Count-1 do
    begin
      s:=lMount.Items[i];
      if s[1]='I' then sciezka:=GetLineToStr(s,9,' ') else
      begin
        if sciezka='@' then
        begin
          s:=StringReplace(s,'   \> ','',[]);
          nazwa:=GetLineToStr(s,9,' ');
          dzien:=GetLineToStr(nazwa,2,'_');
          ss.Add(StringReplace(StringReplace(wzor,'@',nazwa,[rfReplaceAll]),'$MIGAWKA$','Migawka z dnia: '+dzien,[]));
        end;
      end;
    end;
    ss.Insert(0,'#!/bin/sh');
    ss.Insert(1,'exec tail -n +3 $0');
    ss.Insert(2,'');
    ss.SaveToFile('/etc/grub.d/10_linux_btrfs');
    fpChmod('/etc/grub.d/10_linux_btrfs',&755);
    err:=dm.update_grub;
    if err<>0 then showmessage('Błąd podczas wykonania polecenia "update-grub" nr '+IntToStr(err)+'.');
  finally
    ss.Free;
  end;
end;

end.

