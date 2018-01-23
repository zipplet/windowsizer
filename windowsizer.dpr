{ ----------------------------------------------------------------------------
  Window resizer tool for Windows
  https://zipplet.co.uk/
  Copyright (c) Michael Nixon 2018.

  Compiles with:
    - Delphi 2010 onwards (tested with XE5)
    - Freepascal v3.x

  Licensed under the MIT license; please see the LICENSE file for full license
  terms and conditions.
  ---------------------------------------------------------------------------- }
program windowsizer;

{$ifdef debug}
  {$APPTYPE CONSOLE}
{$else}
  {$ifdef fpc}
    // Freepascal needs to be explicitly told to generate a non console program
    {$APPTYPE GUI}
  {$endif}
{$endif}

{$R *.res}

uses
  SysUtils,
  windows,
  unitcommon in 'unitcommon.pas',
  unitlaunch in 'unitlaunch.pas';

{ ----------------------------------------------------------------------------
  Program entrypoint
  ---------------------------------------------------------------------------- }
begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
    if not LoadSettings then begin
      ErrorMessage('Failed to load settings; please check the configuration file.');
      halt;
    end;
    GetDisplaySize;
    DebugOut('Useable display area: ' + inttostr(_state.displayWidth) + ' x ' + inttostr(_state.displayHeight));
    DebugOut('*** Launching program ***');
    LaunchProgram;
    DebugOut('*** Program finished, exiting ***');
  except
    on E: Exception do
      ErrorMessage('Internal exception, please contact the developer:' + #13#10 +
        E.ClassName + ': ' + E.Message);
  end;
end.

