unit config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtParams, process, IniFiles;

type

  TMontowanie = record
    zasob: string;
    count: integer;
  end;

  TMontowanieOperacja = (omMount,omUmount);

  { Tdm }

  Tdm = class
  private
    ss: TStringList;
    montowanie: array [0..5] of TMontowanie;
    procedure montowanie_clear(zasob: string = '');
    function montowanie_wykonaj(zasob: string; operacja: TMontowanieOperacja): boolean;
    function sciezka_wstecz(sciezka: string): string;
    function sciezka_nazwa_katalogu(sciezka: string): string;
    function sciezka_normalizacja(sciezka: string): string;
    procedure reboot;
    function spakuj(katalog: string): integer;
    function rozpakuj(katalog: string): integer;
    function wyczysc_zasob(katalog: string): integer;
    function nowy_wolumin(nazwa: string): integer;
    function usun_archiwum(katalog: string): integer;
    function is_root_active: boolean;
  public
    ini: TIniFile;
    params: TExtParams;
    proc: TProcess;
    smount,sfstab: TStringList;
    constructor Create;
    destructor Destroy; override;
    function init: boolean;
    function wersja: string;
    procedure zamontuj(device,mnt,subvol: string; force: boolean = false);
    procedure odmontuj(mnt: string; force: boolean = false);
    procedure odmontuj_all;
    function migawki(nazwa: string): TStringList;
    function subvolume_to_strdatetime(nazwa: string): string;
    function get_default: integer;
    procedure get_default(var id: integer; var nazwa: string; var migawka: boolean);
    procedure set_default(id: integer);
    function whoami: string;
    function list_all: TStringList;
    function list(subvolume: string = ''): boolean;
    function wczytaj_woluminy(only_root: boolean = false; only_snapshots: boolean = false): TStringList;
    procedure nowa_migawka(force: boolean = false);
    procedure nowa_migawka(zrodlo,cel: string);
    procedure usun_migawke(nazwa: string; force: boolean = false);
    procedure convert_partition(sciezka,nazwa_woluminu: string);
    function generuj_grub_menuitem: TStringList;
    function update_grub: integer;
    procedure generuj_btrfs_grub_migawki;
    procedure wroc_do_migawki;
    procedure usun_stare_migawki;
    procedure autoprogram;
  end;

const
  _DEBUG = false;
  _CONF = '/etc/default/btrfs-tools-snapshots';

var
  _MONTOWANIE_RECZNE: boolean = false;
  _DEVICE: string;
  _ROOT: string = '@';
  _UPDATE_GRUB: boolean = false;
  _MNT: string = '/mnt';
  _SWIAT: string;
  _TEST: boolean = false;
  _MAX_COUNT_SNAPSHOTS: integer = 0;
  _AUTO_RUN: boolean = false;
  dm: Tdm;
  TextSeparator: char;

function GetLineToStr(s:string;l:integer;separator:char;wynik:string=''):string;
function StringToItemIndex(slist:TStrings;kod:string;wart_domyslna:integer=-1):integer;

implementation

uses
  cverinfo, BaseUnix, Unix;

function GetLineToStr(s: string; l: integer; separator: char; wynik: string
  ): string;
var
  i,ll,dl: integer;
  b: boolean;
begin
  b:=false;
  dl:=length(s);
  ll:=1;
  s:=s+separator;
  for i:=1 to length(s) do
  begin
    if s[i]=textseparator then b:=not b;
    if (not b) and (s[i]=separator) then inc(ll);
    if ll=l then break;
  end;
  if ll=1 then dec(i);
  delete(s,1,i);
  b:=false;
  for i:=1 to length(s) do
  begin
    if s[i]=textseparator then b:=not b;
    if (not b) and (s[i]=separator) then break;
  end;
  delete(s,i,dl);
  if (s<>'') and (s[1]=textseparator) then
  begin
    delete(s,1,1);
    delete(s,length(s),1);
  end;
  if s='' then s:=wynik;
  result:=s;
end;

function StringToItemIndex(slist: TStrings; kod: string; wart_domyslna: integer
  ): integer;
var
  i,a: integer;
begin
   a:=wart_domyslna;
   for i:=0 to slist.Count-1 do if slist[i]=kod then
   begin
     a:=i;
     break;
   end;
   result:=a;
end;

{ Tdm }

procedure Tdm.montowanie_clear(zasob: string);
var
  i: integer;
begin
  for i:=0 to 5 do
  begin
    if zasob='' then
    begin
      montowanie[i].zasob:='';
      montowanie[i].count:=0;
    end else if montowanie[i].zasob=zasob then
    begin
      montowanie[i].zasob:='';
      montowanie[i].count:=0;
      break;
    end;
  end;
end;

function Tdm.montowanie_wykonaj(zasob: string; operacja: TMontowanieOperacja): boolean;
var
  i,indeks,wolny: integer;
begin
  indeks:=-1; wolny:=-1;
  (* odszukuję indeks *)
  for i:=0 to 5 do
  begin
    if (wolny=-1) and (montowanie[i].zasob='') then wolny:=i;
    if (indeks=-1) and (montowanie[i].zasob=zasob) then indeks:=i;
    if indeks>-1 then break;
  end;
  if operacja=omMount then
  begin
    (* montowanie *)
    if indeks=-1 then
    begin
      indeks:=wolny;
      montowanie[indeks].zasob:=zasob;
      montowanie[indeks].count:=1;
      //if _TEST then writeln('Info: Zgoda na zamontowanie udzielona.');
      result:=true;
    end else begin
      inc(montowanie[indeks].count);
      //if _TEST then writeln('Info: Zgoda na zamontowanie nie udzielona.');
      result:=false;
    end;
  end else begin
    (* odmontowanie *)
    if indeks=-1 then result:=false else
    begin
      dec(montowanie[indeks].count);
      if montowanie[indeks].count=0 then
      begin
        montowanie[indeks].zasob:='';
        //if _TEST then writeln('Info: Zgoda na odmontowanie udzielona.');
        result:=true;
      end else begin
        //if _TEST then writeln('Info: Zgoda na odmontowanie nie udzielona.');
        result:=false;
      end;
    end;
  end;
end;

function Tdm.sciezka_wstecz(sciezka: string): string;
var
  s: string;
  i,l: integer;
begin
  s:=sciezka;
  l:=length(s);
  if s[l]='/' then delete(s,l,1);
  for i:=length(sciezka) downto 1 do
  begin
    l:=length(s);
    if s[l]='/' then
    begin
      delete(s,l,1);
      break;
    end else delete(s,l,1);
  end;
  if s='' then s:='/';
  result:=s;
end;

function Tdm.sciezka_nazwa_katalogu(sciezka: string): string;
var
  s: string;
  l,a: integer;
begin
  s:=sciezka;
  l:=length(s);
  if s[l]='/' then delete(s,l,1);
  while true do
  begin
    a:=pos('/',s);
    if a=0 then break else delete(s,1,a);
  end;
  result:=s;
end;

function Tdm.sciezka_normalizacja(sciezka: string): string;
var
  s: string;
begin
  s:=sciezka;
  while pos('//',s)>0 do s:=StringReplace(s,'//','/',[]);
  result:=s;
end;

procedure Tdm.reboot;
begin
  ss.Clear;
  proc.Parameters.Clear;
  proc.Options:=[];
  proc.Executable:='shutdown';
  proc.Parameters.Add('-r');
  proc.Parameters.Add('now');
  if _TEST then writeln('shutdown -r now') else proc.Execute;
end;

function Tdm.spakuj(katalog: string): integer;
var
  pom,workdir,nazwa,plik: string;
begin
  pom:=sciezka_normalizacja(_MNT+'/'+_ROOT+'/'+katalog);
  workdir:=sciezka_wstecz(pom);
  nazwa:=sciezka_nazwa_katalogu(pom);
  plik:=nazwa+'.tgz';
  ss.Clear;
  proc.Parameters.Clear;
  proc.Executable:='tar';
  proc.Parameters.Add('cvzf');
  proc.Parameters.Add(plik);
  proc.Parameters.Add(nazwa);
  proc.CurrentDirectory:=workdir;
  if _TEST then
  begin
    writeln('cd '+workdir+' && tar cvzf '+plik+' '+nazwa);
    result:=0;
  end else begin
    proc.Execute;
    result:=proc.ExitCode;
    proc.Terminate(0);
  end;
  proc.CurrentDirectory:='';
end;

function Tdm.rozpakuj(katalog: string): integer;
var
  pom,workdir,nazwa,plik: string;
begin
  pom:=sciezka_normalizacja(_MNT+'/'+_ROOT+'/'+katalog);
  workdir:=sciezka_wstecz(pom);
  nazwa:=sciezka_nazwa_katalogu(pom);
  plik:=nazwa+'.tgz';
  ss.Clear;
  proc.Parameters.Clear;
  proc.CurrentDirectory:=workdir;
  proc.Executable:='tar';
  proc.Parameters.Add('xvzf');
  proc.Parameters.Add(plik);
  if _TEST then
  begin
    writeln('cd '+workdir+' && tar xvzf '+plik);
    result:=0;
  end else begin
    proc.Execute;
    result:=proc.ExitCode;
    proc.Terminate(0);
  end;
  proc.CurrentDirectory:='';
end;

function Tdm.wyczysc_zasob(katalog: string): integer;
var
  pom,workdir,nazwa: string;
begin
  pom:=sciezka_normalizacja(_MNT+'/'+_ROOT+'/'+katalog);
  workdir:=sciezka_wstecz(pom);
  nazwa:=sciezka_nazwa_katalogu(pom);
  ss.Clear;
  proc.Parameters.Clear;
  proc.CurrentDirectory:=workdir;
  proc.Executable:='rm';
  proc.Parameters.Add('-f');
  proc.Parameters.Add('-R');
  proc.Parameters.Add(nazwa);
  if _TEST then
  begin
    writeln('cd '+workdir+' && rm -f -R '+nazwa);
    writeln('mkdir '+workdir+'/'+nazwa);
    result:=0;
  end else begin
    proc.Execute;
    mkdir(workdir+'/'+nazwa);
    result:=proc.ExitCode;
    proc.Terminate(0);
  end;
  proc.CurrentDirectory:='';
end;

function Tdm.nowy_wolumin(nazwa: string): integer;
begin
  ss.Clear;
  proc.Parameters.Clear;
  proc.CurrentDirectory:=_MNT;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('create');
  proc.Parameters.Add(nazwa);
  if _TEST then
  begin
    writeln('cd '+_MNT+' && btrfs subvolume create '+nazwa);
    result:=0;
  end else begin
    proc.Execute;
    result:=proc.ExitCode;
    proc.Terminate(0);
  end;
  proc.CurrentDirectory:='';
end;

function Tdm.usun_archiwum(katalog: string): integer;
var
  pom,workdir,nazwa,plik: string;
begin
  pom:=sciezka_normalizacja(_MNT+'/'+_ROOT+'/'+katalog);
  workdir:=sciezka_wstecz(pom);
  nazwa:=sciezka_nazwa_katalogu(pom);
  plik:=nazwa+'.tgz';
  ss.Clear;
  proc.Parameters.Clear;
  proc.CurrentDirectory:=workdir;
  proc.Executable:='rm';
  proc.Parameters.Add('-f');
  proc.Parameters.Add(plik);
  if _TEST then
  begin
    writeln('cd '+workdir+' && rm -f '+plik);
    result:=0;
  end else begin
    proc.Execute;
    result:=proc.ExitCode;
    proc.Terminate(0);
  end;
  proc.CurrentDirectory:='';
end;

function Tdm.is_root_active: boolean;
var
  b: boolean;
  i: integer;
  s,pom,nazwa: string;
begin
  b:=false;
  wczytaj_woluminy(true);
  for i:=0 to ss.Count-1 do
  begin
    s:=StringReplace(ss[i],'   \> ','',[]);
    nazwa:=GetLineToStr(s,9,' ');
    if nazwa=_ROOT then
    begin
      pom:=GetLineToStr(s,10,' ');
      if pos('I',pom)>0 then b:=true;
      break;
    end;
  end;
  if _TEST then if b then writeln('Info: System uruchomiony z woluminu root.') else writeln('Uwaga: System uruchomiony z migawki!');
  result:=b;
end;

constructor Tdm.Create;
begin
  montowanie_clear;
  params:=TExtParams.Create(nil);
  params.ParamsForValues.Add('set-root');
  params.ParamsForValues.Add('set-grub');
  params.ParamsForValues.Add('set-default');
  params.ParamsForValues.Add('set-auto-run');
  params.ParamsForValues.Add('set-max-snapshouts');
  params.ParamsForValues.Add('del');
  params.ParamsForValues.Add('convert-partition');
  params.ParamsForValues.Add('subvolume');
  params.ParamsForValues.Add('device');
  params.ParamsForValues.Add('root');
  proc:=TProcess.Create(nil);
  proc.Options:=[poWaitOnExit,poUsePipes];
  ss:=TStringList.Create;
  smount:=TStringList.Create;
  sfstab:=TStringList.Create;
  ini:=TIniFile.Create(_CONF);
end;

destructor Tdm.Destroy;
begin
  params.Free;
  proc.Free;
  ss.Free;
  smount.Free;
  sfstab.Free;
  inherited Destroy;
end;

function Tdm.init: boolean;
var
  i,a: integer;
  s: string;
begin
  if _DEBUG then exit;
  (* DEVICE *)
  smount.Clear;
  proc.Parameters.Clear;
  proc.Executable:='mount';
  proc.Execute;
  smount.LoadFromStream(proc.Output);
  proc.Terminate(0);
  for i:=smount.Count-1 downto 0 do if pos('/dev/sd',smount[i])=0 then smount.Delete(i);
  if dm.params.IsParam('device') then _DEVICE:=dm.params.GetValue('device') else for i:=0 to smount.Count-1 do
  begin
    s:=smount[i];
    if pos('on / type',s)>0 then
    begin
      _DEVICE:=GetLineToStr(s,1,' ');
      break;
    end;
  end;
  if _DEVICE='' then
  begin
    writeln('UWAGA! NIEZNANE URZĄDZENIE! WYCHODZĘ!');
    result:=false;
  end else begin
    result:=true;
  end;
  (* ustawienie _SWIAT - czyli miejsca w którym się znajdujemy *)
  for i:=0 to smount.Count-1 do
  begin
    s:=smount[i];
    if pos('on / type',s)>0 then
    begin
      a:=pos('subvol=/',s);
      if a>0 then
      begin
        delete(s,1,a+7);
        a:=pos(')',s);
        if a>0 then delete(s,a,100000);
        _SWIAT:=s;
      end;
      break;
    end;
  end;
  (* ROOT *)
  if dm.params.IsParam('root') then _ROOT:=dm.params.GetValue('root') else _ROOT:=dm.ini.ReadString('config','root','@');
  _UPDATE_GRUB:=dm.ini.ReadBool('config','update-grub',false);
  _MAX_COUNT_SNAPSHOTS:=dm.ini.ReadInteger('snapshots','max',0);
  _AUTO_RUN:=dm.ini.ReadBool('config','auto-run',false);
end;

function Tdm.wersja: string;
var
  major,minor,release,build: integer;
begin
  cverinfo.GetProgramVersion(major,minor,release,build);
  result:=IntToStr(major)+'.'+IntToStr(minor)+'.'+IntToStr(release)+'-'+IntToStr(build);
end;

procedure Tdm.zamontuj(device, mnt, subvol: string; force: boolean);
var
  b: boolean;
begin
  if _MONTOWANIE_RECZNE and (not force) then exit;
  b:=montowanie_wykonaj(mnt,omMount);
  if (not b) and (not force) then exit;
  proc.Parameters.Clear;
  proc.Executable:='mount';
  proc.Parameters.Add('-o');
  proc.Parameters.Add('subvol='+subvol);
  proc.Parameters.Add(device);
  proc.Parameters.Add(mnt);
  if _TEST then
  begin
    writeln('mount -o subvol='+subvol+' '+device+' '+mnt);
    if mnt=_MNT then
    begin
      proc.Execute;
      proc.Terminate(0);
    end;
  end else begin
    proc.Execute;
    proc.Terminate(0);
  end;
end;

procedure Tdm.odmontuj(mnt: string; force: boolean);
var
  b: boolean;
begin
  if _MONTOWANIE_RECZNE and (not force) then exit;
  b:=montowanie_wykonaj(mnt,omUmount);
  if (not b) and (not force) then exit;
  proc.Parameters.Clear;
  proc.Executable:='umount';
  proc.Parameters.Add(mnt);
  if _TEST then
  begin
    writeln('umount '+mnt);
    if mnt=_MNT then
    begin
      proc.Execute;
      proc.Terminate(0);
    end;
  end else begin
    proc.Execute;
    proc.Terminate(0);
  end;
  if force then montowanie_clear(mnt);
end;

procedure Tdm.odmontuj_all;
var
  i: integer;
begin
  for i:=5 to 0 do if montowanie[i].zasob<>'' then odmontuj(montowanie[i].zasob,true);
end;

function Tdm.migawki(nazwa: string): TStringList;
var
  s,pom: string;
  i,a: integer;
begin
  zamontuj(_DEVICE,_MNT,'/');
  proc.CurrentDirectory:=_MNT;
  proc.Parameters.Clear;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('show');
  proc.Parameters.Add(nazwa);
  proc.Execute;
  ss.LoadFromStream(proc.Output);
  proc.Terminate(0);
  proc.CurrentDirectory:='';
  odmontuj(_MNT);
  for i:=0 to ss.Count-1 do
  begin
    s:=ss[i];
    a:=pos('Snapshot(s):',s);
    if a>0 then
    begin
      a:=i+1;
      break;
    end;
  end;
  s:='';
  for i:=a to ss.Count-1 do s:=s+ss[i]+' ';
  s:=trim(StringReplace(s,#9,'',[rfReplaceAll]));
  s:=StringReplace(s,' ',';',[rfReplaceAll]);
  ss.Clear;
  i:=0;
  while true do
  begin
    inc(i);
    pom:=GetLineToStr(s,i,';');
    if pom='' then break;
    ss.Add(pom);
  end;
  result:=ss;
end;

function Tdm.subvolume_to_strdatetime(nazwa: string): string;
var
  s,pom: string;
  i,a: integer;
  FS: TFormatSettings;
begin
  FS.ShortDateFormat:='y/m/d';
  FS.DateSeparator:='-';
  pom:='';
  zamontuj(_DEVICE,_MNT,'/');
  proc.CurrentDirectory:=_MNT;
  proc.Parameters.Clear;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('show');
  proc.Parameters.Add(nazwa);
  proc.Execute;
  ss.LoadFromStream(proc.Output);
  proc.Terminate(0);
  proc.CurrentDirectory:='';
  odmontuj(_MNT);
  for i:=0 to ss.Count-1 do
  begin
    s:=ss[i];
    a:=pos('Creation time:',s);
    if a>0 then break;
  end;
  delete(s,1,a+14);
  s:=trim(StringReplace(s,#9,'',[rfReplaceAll]));
  result:=s;
end;

function Tdm.get_default: integer;
begin
  ss.Clear;
  proc.Parameters.Clear;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('get-default');
  proc.Parameters.Add('/');
  proc.Execute;
  ss.LoadFromStream(proc.Output);
  proc.Terminate(0);
  result:=StrToInt(GetLineToStr(ss[0],2,' '));
end;

procedure Tdm.get_default(var id: integer; var nazwa: string;
  var migawka: boolean);
begin
  ss.Clear;
  proc.Parameters.Clear;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('get-default');
  proc.Parameters.Add('/');
  proc.Execute;
  ss.LoadFromStream(proc.Output);
  proc.Terminate(0);
  id:=StrToInt(GetLineToStr(ss[0],2,' '));
  nazwa:=GetLineToStr(ss[0],9,' ');
  migawka:=pos('migawka',nazwa)>0;
end;

procedure Tdm.set_default(id: integer);
var
  i: integer;
begin
  ss.Clear;
  proc.CurrentDirectory:=_MNT;
  proc.Parameters.Clear;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('set-default');
  proc.Parameters.Add(IntToStr(id));
  proc.Parameters.Add('/');
  if _TEST then writeln('btrfs subvolume set-default '+IntToStr(id)+' /') else proc.Execute;
  ss.LoadFromStream(proc.Output);
  proc.Terminate(0);
  for i:=0 to ss.Count-1 do writeln(ss[i]);
end;

function Tdm.whoami: string;
begin
  ss.Clear;
  proc.Parameters.Clear;
  proc.Executable:='whoami';
  proc.Execute;
  ss.LoadFromStream(proc.Output);
  proc.Terminate(0);
  result:=ss[0];
end;

function Tdm.list_all: TStringList;
begin
  zamontuj(_DEVICE,_MNT,'/');
  proc.CurrentDirectory:=_MNT;
  proc.Parameters.Clear;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('list');
  proc.Parameters.Add('.');
  proc.Execute;
  ss.LoadFromStream(proc.Output);
  proc.Terminate(0);
  proc.CurrentDirectory:='';
  odmontuj(_MNT);
  result:=ss;
end;

function Tdm.list(subvolume: string): boolean;
var
  i,id: integer;
  s,nn,nazwa,sdata: string;
  istnieje: boolean;
begin
  list_all;
  for i:=0 to ss.Count-1 do
  begin
    s:=ss[i];
    id:=StrToInt(GetLineToStr(s,2,' '));
    nn:=GetLineToStr(s,9,' ');
    if subvolume='' then
    begin
      nazwa:=GetLineToStr(nn,1,'_');
      sdata:=GetLineToStr(nn,2,'_');
      if nazwa='@migawka' then writeln('Migawka:  ID: ',id,', NAME: ',nazwa,'_',sdata,', DATE: ',sdata)
                          else writeln('Wolumin:  ID: ',id,', NAME: ',nn);
    end else begin
      if nn=subvolume then
      begin
        istnieje:=true;
        break;
      end;
    end;
  end;
  if subvolume='' then result:=true else result:=istnieje;
end;

function Tdm.wczytaj_woluminy(only_root: boolean; only_snapshots: boolean
  ): TStringList;
var
  id,i,j,a: integer;
  s,pom: string;
  tab,tab1,tab2: TStringList;
  sciezka,wolumin: string;
  s1: string;
  vol: TStringList;
begin
  id:=dm.get_default;
  s:='ID '+IntToStr(id)+' gen';

  vol:=TStringList.Create;
  try
    tab:=TStringList.Create;
    tab1:=TStringList.Create;
    tab2:=TStringList.Create;
    try
      tab.Assign(dm.list_all);
      for i:=0 to tab.Count-1 do tab1.Add(GetLineToStr(tab[i],9,' '));

      i:=0;
      while true do
      begin
        if i>tab1.Count-1 then break;
        sciezka:=tab1[i];
        tab2.Assign(migawki(sciezka));
        wolumin:=tab1[i];
        for j:=0 to tab2.Count-1 do
        begin
          s1:=tab2[j];
          a:=StringToItemIndex(tab1,s1);
          if a>-1 then
          begin
            pom:=tab[a];
            tab.Delete(a);
            tab.Insert(i+1,'   \> '+pom);
            pom:=tab1[a];
            tab1.Delete(a);
            tab1.Insert(i+1,pom);
            inc(i);
          end;
        end;
        inc(i);
      end;

      vol.Assign(tab);
    finally
      tab.Free;
      tab1.Free;
      tab2.Free;
    end;

    wolumin:='';
    if only_root then
    begin
      for i:=0 to vol.Count-1 do
      begin
        pom:=vol[i];
        if pos('   \> ',pom)=0 then
        begin
          wolumin:=GetLineToStr(pom,9,' ');
          if only_snapshots then
          begin
            vol.Delete(i);
            vol.Insert(i,'');
            continue;
          end;
        end;
        if wolumin<>_ROOT then
        begin
          vol.Delete(i);
          vol.Insert(i,'');
        end;
      end;
      for i:=vol.Count-1 downto 0 do if vol[i]='' then vol.Delete(i);
      if only_snapshots then for i:=0 to vol.Count-1 do
      begin
        pom:=StringReplace(vol[i],'   \> ','',[]);
        vol.Delete(i);
        vol.Insert(i,pom);
      end;
    end;

    for i:=0 to vol.Count-1 do
    begin
      pom:=vol[i];
      sciezka:=StringReplace(pom,'   \> ','',[]);
      sciezka:=GetLineToStr(sciezka,9,' ');
      if (pos(s,pom)>0) and (sciezka=_SWIAT) then
      begin
        vol.Delete(i);
        vol.Insert(i,pom+' [SI]');
      end else if pos(s,pom)>0 then
      begin
        vol.Delete(i);
        vol.Insert(i,pom+' [S]');
      end else if sciezka=_SWIAT then
      begin
        vol.Delete(i);
        vol.Insert(i,pom+' [I]');
      end;
    end;
    ss.Assign(vol);
  finally
    vol.Free;
  end;
  result:=ss;
end;

procedure Tdm.nowa_migawka(force: boolean);
var
  migawka: string;
begin
  zamontuj(_DEVICE,_MNT,'/');
  migawka:='@'+_ROOT+'_'+FormatDateTime('yyyy-mm-dd',date);
  if dm.list(migawka) then
  begin
    if force then dm.usun_migawke(migawka) else
    begin
      if _TEST then writeln('Info: Migawka istnieje, wychodzę...');
      odmontuj(_MNT);
      exit;
    end;
  end;
  proc.Parameters.Clear;
  proc.CurrentDirectory:=_MNT;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('snapshot');
  proc.Parameters.Add(_ROOT);
  proc.Parameters.Add(migawka);
  if _TEST then writeln('subvolume snapshot '+_ROOT+' '+migawka) else proc.Execute;
  proc.Terminate(0);
  proc.CurrentDirectory:='';
  odmontuj(_MNT);
end;

procedure Tdm.nowa_migawka(zrodlo, cel: string);
begin
  zamontuj(_DEVICE,_MNT,'/');
  proc.Parameters.Clear;
  proc.CurrentDirectory:=_MNT;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('snapshot');
  proc.Parameters.Add(zrodlo);
  proc.Parameters.Add(cel);
  proc.Execute;
  proc.Terminate(0);
  proc.CurrentDirectory:='';
  odmontuj(_MNT);
end;

procedure Tdm.usun_migawke(nazwa: string; force: boolean);
begin
  if (not force) and (pos('@@',nazwa)=0) then
  begin
    writeln('Próbujesz usunąć wolumin, tego typu operacje zostały zablokowane!');
    writeln('By usunąć wolumin musisz użyć flagi [--force].');
    exit;
  end;
  zamontuj(_DEVICE,_MNT,'/');
  proc.Parameters.Clear;
  proc.CurrentDirectory:=_MNT;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('delete');
  proc.Parameters.Add(nazwa);
  if _TEST then writeln('btrfs subvolume delete '+nazwa) else proc.Execute;
  proc.Terminate(0);
  proc.CurrentDirectory:='';
  odmontuj(_MNT);
end;

procedure Tdm.convert_partition(sciezka, nazwa_woluminu: string);
var
  subvolume: string;
  exitcode: integer;
begin
  (* określenie nazwy woluminu *)
  subvolume:='';
  if nazwa_woluminu<>'' then subvolume:=nazwa_woluminu
  else if sciezka='/home' then subvolume:='@home'
  else if sciezka='/var' then subvolume:='@var'
  else if sciezka='/var/cache' then subvolume:='@cache';
  if subvolume='' then
  begin
    writeln('*** Operacja przerwana! ***');
    writeln('Podana ścieżka nie została zdefiniowana w programie i brakuje odpowiedniej nazwy woluminu.');
    writeln('Proszę o dodatkowe zdefiniowanie nazwy woluminu za pomocą parametru "--subvolume".');
    exit;
  end;
  (* wykonuję procedurę przekonwertowania katalogu *)
  writeln('Montuję zasób główny...');
  zamontuj(_DEVICE,_MNT,'/');
  try
    writeln('Pakuję zawartość zasobu...');
    exitcode:=spakuj(sciezka);
    if exitcode<>0 then
    begin
      writeln('Wystąpił błąd nr ',exitcode,', przerywam...');
      exit;
    end;
    writeln('Usuwam zawartość zasobu...');
    exitcode:=wyczysc_zasob(sciezka);
    if exitcode<>0 then
    begin
      writeln('Wystąpił błąd nr ',exitcode,', przerywam...');
      exit;
    end;
    writeln('Tworzę nowy wolumin...');
    exitcode:=nowy_wolumin(subvolume);
    if exitcode<>0 then
    begin
      writeln('Wystąpił błąd nr ',exitcode,', przerywam...');
      exit;
    end;
    writeln('Odtwarzam zawartość woluminu...');
    try
      zamontuj(_DEVICE,sciezka_normalizacja(_MNT+'/'+_ROOT+'/'+sciezka),subvolume);
      exitcode:=rozpakuj(sciezka);
      if exitcode<>0 then
      begin
        writeln('Wystąpił błąd nr ',exitcode,', przerywam...');
        exit;
      end;
    finally
      odmontuj(sciezka_normalizacja(_MNT+'/'+_ROOT+'/'+sciezka));
    end;
    writeln('Usuwam spakowaną zawartość zasobu, która jest już nie potrzebna...');
    usun_archiwum(sciezka);
  finally
    writeln('Odmontowuję zasób główny...');
    odmontuj(_MNT);
  end;
end;

function Tdm.generuj_grub_menuitem: TStringList;
var
  b: boolean;
  i,j,a: integer;
  s: string;
begin
  if not _UPDATE_GRUB then exit;
  ss.Clear;
  ss.LoadFromFile('/boot/grub/grub.cfg');
  for i:=0 to ss.Count-1 do
  begin
    a:=pos('menuentry ',ss[0]);
    if a>0 then break;
    ss.Delete(0);
  end;
  b:=false;
  for i:=0 to ss.Count-1 do
  begin
    if b then ss.Delete(j+1) else
    begin
      j:=i;
      a:=pos('}',ss[j]);
    end;
    if a>0 then b:=true;
  end;
  s:=ss[0];
  a:=pos(''' ',s);
  insert(' ($MIGAWKA$)',s,a);
  ss.Delete(0);
  ss.Insert(0,s);
  result:=ss;
end;

function Tdm.update_grub: integer;
begin
  if not _UPDATE_GRUB then exit;
  ss.Clear;
  proc.Parameters.Clear;
  proc.Executable:='update-grub';
  if _TEST then writeln('update-grub') else proc.Execute;
  result:=proc.ExitCode;
  proc.Terminate(0);
end;

procedure Tdm.generuj_btrfs_grub_migawki;
var
  wzor,s,sciezka,nazwa,dzien: string;
  i: integer;
  err: integer;
  vol: TStringList;
begin
  if not _UPDATE_GRUB then exit;
  vol:=TStringList.Create;
  try
    vol.Assign(dm.wczytaj_woluminy);
    wzor:=dm.generuj_grub_menuitem.Text;
    ss.Clear;
    for i:=0 to vol.Count-1 do
    begin
      s:=vol[i];
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
    if _TEST then writeln('[Generowanie nowej konfiguracji GRUB]') else
    begin
      ss.SaveToFile('/etc/grub.d/10_linux_btrfs');
      fpChmod('/etc/grub.d/10_linux_btrfs',&755);
    end;
    err:=update_grub;
    if err<>0 then writeln('Błąd podczas wykonania polecenia "update-grub" nr '+IntToStr(err));
  finally
    vol.Free;
  end;
end;

procedure Tdm.wroc_do_migawki;
var
  i,id,a,new_id: integer;
  s,nazwa,wlasciciel,migawki_do_usuniecia: string;
  atr_s,atr_i,root_is_s,root_is_i,migawka: boolean;
begin
  (* zamontowanie zasobu *)
  zamontuj(_DEVICE,_MNT,'/');
  (* wczytanie woluminów i wczytanie informacji potrzebnych do wykonania operacji *)
  wczytaj_woluminy;
  if _TEST then
  begin
    writeln('Wczytany obraz woluminów jest następujący:');
    writeln(ss.Text);
  end;
  root_is_s:=false;
  root_is_i:=false;
  migawki_do_usuniecia:='';
  for i:=0 to ss.Count-1 do
  begin
    (* pobranie informacji *)
    s:=ss[i];
    a:=pos('   \> ',s);
    migawka:=a>0;
    s:=StringReplace(s,'   \> ','',[]);
    id:=StrToInt(GetLineToStr(s,2,' '));
    nazwa:=GetLineToStr(s,9,' ');
    if not migawka then wlasciciel:=nazwa;
    if pos('[SI]',s)>0 then
    begin
      atr_s:=true;
      atr_i:=true;
    end else if pos('[S]',s)>0 then
    begin
      atr_s:=true;
      atr_i:=false;
    end else if pos('[I]',s)>0 then
    begin
      atr_s:=false;
      atr_i:=true;
    end else begin
      atr_s:=false;
      atr_i:=false;
    end;
    if (nazwa=_ROOT) and atr_s then root_is_s:=true;
    if (nazwa=_ROOT) and atr_i then root_is_i:=true;
    if root_is_s and atr_i then new_id:=id;
    if migawka and (wlasciciel=_ROOT) and (not atr_i) then migawki_do_usuniecia:=migawki_do_usuniecia+nazwa+#9;
  end;
  if root_is_i then
  begin
    writeln('Wykryto, iż system uruchomiony został z głównego woluminu, nie z migawki! Przerywam...');
    odmontuj(_MNT);
    exit;
  end;
  (* ustawienie katalogu operacji *)
  proc.CurrentDirectory:=_MNT;
  (* jeśli trzeba ustawiam nowego _ROOT na [S] *)
  if root_is_s then set_default(new_id);
  (* usunięcie _ROOT *)
  proc.Parameters.Clear;
  proc.Executable:='btrfs';
  proc.Parameters.Add('subvolume');
  proc.Parameters.Add('delete');
  proc.Parameters.Add(_ROOT);
  if _TEST then writeln('btrfs subvolume delete '+_ROOT) else proc.Execute;
  proc.Terminate(0);
  (* zmiana migawki na _ROOT *)
  proc.Parameters.Clear;
  proc.Executable:='mv';
  proc.Parameters.Add(_SWIAT);
  proc.Parameters.Add(_ROOT);
  if _TEST then writeln('mv '+_SWIAT+' '+_ROOT) else proc.Execute;
  proc.Terminate(0);
  (* usunięcie niepotrzebnych migawek *)
  i:=1;
  while true do
  begin
    s:=GetLineToStr(migawki_do_usuniecia,i,#9);
    if s='' then break;
    proc.Parameters.Clear;
    proc.Executable:='btrfs';
    proc.Parameters.Add('subvolume');
    proc.Parameters.Add('delete');
    proc.Parameters.Add(s);
    if _TEST then writeln('btrfs subvolume delete '+s) else proc.Execute;
    proc.Terminate(0);
    inc(i);
  end;
  (* odtworzenie informacji startowych i wykonanie update-grub *)
  generuj_btrfs_grub_migawki;
  (* czyszczenie i odmontowanie zasobu *)
  proc.CurrentDirectory:='';
  odmontuj(_MNT);
  (* restart *)
  reboot;
end;

procedure Tdm.usun_stare_migawki;
var
  lista: TStringList;
  s: string;
  i: integer;
begin
  (* zamontowanie zasobu *)
  zamontuj(_DEVICE,_MNT,'/');
  (* wczytanie woluminów i wczytanie informacji potrzebnych do wykonania operacji *)
  wczytaj_woluminy(true,true);
  if _TEST then
  begin
    writeln('Wczytany obraz migawek woluminu root jest następujący:');
    writeln(ss.Text);
  end;
  lista:=TStringList.Create;
  try
    for i:=0 to ss.Count-1 do lista.Add(GetLineToStr(ss[i],9,' '));
    lista.Sort;
    for i:=0 to lista.Count-1 do
    begin
      s:=lista[i];
      if i+1>_MAX_COUNT_SNAPSHOTS then usun_migawke(s);
    end;
  finally
    lista.Free;
  end;
  (* czyszczenie i odmontowanie zasobu *)
  odmontuj(_MNT);
end;

procedure Tdm.autoprogram;
begin
  if not _AUTO_RUN then exit;
  zamontuj(_DEVICE,_MNT,'/');
  if is_root_active then
  begin
    nowa_migawka;
    usun_stare_migawki;
    generuj_btrfs_grub_migawki;
  end else if _TEST then writeln('Info: System uruchomiony z migawki - nic nie wykonuję!');
  odmontuj(_MNT);
end;

begin
//  SetDefEof;
//  DefConv:='cp1250';
//  DefConvOff:=false;
  TextSeparator:='"';
end.

