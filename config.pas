unit config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  _DEBUG = false;
  _CONF = '/etc/default/btrfs-tools-snapshots';

var
  _MONTOWANIE_RECZNE: boolean = false;
  _DEVICE: string;
  _ROOT: string = '@';
  _MNT: string = '/mnt';
  _MNT_COUNT: integer = 0;

implementation

end.

