program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, Interfaces, Forms, Dialogs,
  ecode, datamodule, config, main;

type

  { TBtrfsTools }

  TBtrfsTools = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Apps: TBtrfsTools;

{ TBtrfsTools }

procedure TBtrfsTools.DoRun;
var
  id,i: integer;
  force,migawka: boolean;
  user,nazwa,pom: string;
  ss: TStringList;
begin
  user:=dm.whoami;
  dm.params.Execute;
  if dm.params.IsParam('help') then
  begin
    writeln('Btrfs Tools - by Jacek Leszczyński (Kraków, 2018)');
    writeln;
    writeln('  Składnia: btrfs_tools <polecenie>');
    writeln;
    writeln('  Dozwolone polecenia:');
    writeln('    --help                        - wywołanie pomocy');
    writeln('    --ver                         - wersja programu');
    writeln('    --set-root [nazwa woluminu]   - ustawienie woluminu root');
    writeln('    --device <urządzenie>         - tymczasowe ustawienie niestandardowego urządzenia');
    writeln('    --root <nazwa woluminu>       - tymczasowe ustawienie niestandardowego woluminu root');
    writeln('    --force                       - wymuszenie wykonania');
    writeln('    --list                        - wylistowanie wszystkich migawek');
    writeln('    --get-default                 - podaj ID domyślnego woluminu');
    writeln('    --set-default <ID>            - ustaw wolumin ID jako domyślny');
    writeln('    --gen                         - utwórz migawkę na dziś, jeśli istnieje, skasuj i utwórz');
    writeln('    --del <nazwa>                 - usunięcie istniejącej migawki');
    writeln('    --update-grub                 - generuj i aktualizuj grub');
    writeln('    --gui                         - uruchomienie w środowisku graficznym');
    writeln;
    writeln('  Operacje do wykonywania tylko w trybie ratunkowym (init 1):');
    writeln('  (UWAGA: Nie próbuj tego wykonywać w normalnie pracującym systemie!)');
    writeln('    --convert-partition <patch>   - przekonwertuj podany katalog do woluminu w locie');
    writeln('    --subvolume <nazwa>           - w konwersji użyj podanej nazwy woluminu');
    writeln;
    Terminate;
    exit;
  end;
  if dm.params.IsParam('ver') then
  begin
    writeln(dm.wersja);
    Terminate;
    exit;
  end;
  if dm.params.IsParam('gui') then
  begin
    if user<>'root' then
    begin
      ShowMessage('Uwaga: Program wymaga uprawnień użytkownika root!'+#13#10+'Wychodzę...');
      Terminate;
      exit;
    end;
    if not dm.init then
    begin
      ShowMessage('UWAGA - NIEZNANE URZĄDZENIE - WYCHODZĘ!');
      Terminate;
      exit;
    end;
    _MONTOWANIE_RECZNE:=true;
    dm.zamontuj(_DEVICE,_MNT,'/',true);
    FMain:=TFMain.Create(Application);
    RequireDerivedFormResource:=true;
    Application.Scaled:=true;
    Application.Initialize;
    Application.CreateForm(TFmain,FMain);
    Application.Title:=Apps.Title;
    Application.Run;
    dm.odmontuj(_MNT,true);
    Terminate;
    exit;
  end;
  if user<>'root' then
  begin
    writeln('-------------------------------------------------');
    writeln('Uwaga: Program wymaga uprawnień użytkownika root!');
    writeln('-------------------------------------------------');
    Terminate;
    exit;
  end;
  if dm.params.IsParam('set-root') then
  begin
    pom:=dm.params.GetValue('set-root');
    if pom='' then dm.ini.WriteString('config','root','@') else dm.ini.WriteString('config','root',pom);
    Terminate;
    exit;
  end;
  if not dm.init then
  begin
    Terminate;
    exit;
  end;
  force:=dm.params.IsParam('force');
  if dm.params.IsParam('get-default') then
  begin
    dm.get_default(id,nazwa,migawka);
    writeln('Domyślnym woluminem jest:');
    if migawka then writeln('Migawka:  ID: ',id,', NAME: ',nazwa,', DATE: ',GetLineToStr(nazwa,2,'_'))
               else writeln('Wolumin:  ID: ',id,', NAME: ',nazwa);
  end;
  if dm.params.IsParam('list') then
  begin
    ss:=TStringList.Create;
    try
      ss.Assign(dm.wczytaj_woluminy);
      for i:=0 to ss.Count-1 do writeln(ss[i]);
    finally
      ss.Free;
    end;
  end;
  if dm.params.IsParam('gen') then dm.nowa_migawka(force);
  if dm.params.IsParam('del') then dm.usun_migawke(dm.params.GetValue('del'));
  if dm.params.IsParam('update-grub') then dm.generuj_btrfs_grub_migawki;
  if dm.params.IsParam('convert-partition') then dm.convert_partition(dm.params.GetValue('convert-partition'),dm.params.GetValue('subvolume'));
  if _MNT_COUNT>0 then dm.odmontuj(_MNT,true);
  Terminate;
end;

constructor TBtrfsTools.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  dm:=Tdm.Create(self);
  StopOnException:=True;
end;

destructor TBtrfsTools.Destroy;
begin
  dm.Free;
  inherited Destroy;
end;

{$R *.res}

begin
  Application.Title:='BtrfsTools';
  Apps:=TBtrfsTools.Create(nil);
  Apps.Title:='BtrfsTools';
  Apps.Run;
  Apps.Free;
end.

