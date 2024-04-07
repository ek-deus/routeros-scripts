#!rsc by RouterOS
# RouterOS script: backup-cloud
# Copyright (c) 2013-2024 Christian Hesse <mail@eworm.de>
# https://git.eworm.de/cgit/routeros-scripts/about/COPYING.md
#
# provides: backup-script, order=40
# requires RouterOS, version=7.13
#
# upload backup to MikroTik cloud
# https://git.eworm.de/cgit/routeros-scripts/about/doc/backup-cloud.md

:global GlobalFunctionsReady;
:while ($GlobalFunctionsReady != true) do={ :delay 500ms; }

:do {
  :local ScriptName [ :jobname ];

  :global BackupRandomDelay;
  :global Identity;
  :global PackagesUpdateBackupFailure;

  :global DeviceInfo;
  :global FormatLine;
  :global HumanReadableNum;
  :global LogPrint;
  :global MkDir;
  :global RandomDelay;
  :global ScriptFromTerminal;
  :global ScriptLock;
  :global SendNotification2;
  :global SymbolForNotification;
  :global WaitForFile;
  :global WaitFullyConnected;

  :if ([ $ScriptLock $ScriptName ] = false) do={
    :set PackagesUpdateBackupFailure true;
    :error false;
  }
  $WaitFullyConnected;

  :if ([ $ScriptFromTerminal $ScriptName ] = false && $BackupRandomDelay > 0) do={
    $RandomDelay $BackupRandomDelay;
  }

  :if ([ $MkDir ("tmpfs/backup-cloud") ] = false) do={
    $LogPrint error $ScriptName ("Failed creating directory!");
    :error false;
  }

  :execute {
    :global BackupPassword;
    # we are not interested in output, but print is
    # required to fetch information from cloud
    /system/backup/cloud/print as-value;
    :delay 20ms;
    :if ([ :len [ /system/backup/cloud/find ] ] > 0) do={
      /system/backup/cloud/upload-file action=create-and-upload \
          password=$BackupPassword replace=[ get ([ find ]->0) name ];
    } else={
      /system/backup/cloud/upload-file action=create-and-upload \
          password=$BackupPassword;
    }
    /file/add name="tmpfs/backup-cloud/done";
  } as-string;

  :if ([ $WaitForFile "tmpfs/backup-cloud/done" ] = true) do={
    :local Cloud [ /system/backup/cloud/get ([ find ]->0) ];

    $SendNotification2 ({ origin=$ScriptName; \
      subject=([ $SymbolForNotification "floppy-disk,cloud" ] . "Cloud backup"); \
      message=("Uploaded backup for " . $Identity . " to cloud.\n\n" . \
        [ $DeviceInfo ] . "\n\n" . \
        [ $FormatLine "Name" ($Cloud->"name") ] . "\n" . \
        [ $FormatLine "Size" ([ $HumanReadableNum ($Cloud->"size") 1024 ] . "B") ] . "\n" . \
        [ $FormatLine "Download key" ($Cloud->"secret-download-key") ]); silent=true });
  } else={
    $SendNotification2 ({ origin=$ScriptName; \
      subject=([ $SymbolForNotification "floppy-disk,warning-sign" ] . "Cloud backup failed"); \
      message=("Failed uploading backup for " . $Identity . " to cloud!\n\n" . [ $DeviceInfo ]) });
    $LogPrint error $ScriptName ("Failed uploading backup for " . $Identity . " to cloud!");
    :set PackagesUpdateBackupFailure true;
    :error false;
  }
  /file/remove "tmpfs/backup-cloud";
} on-error={ }
