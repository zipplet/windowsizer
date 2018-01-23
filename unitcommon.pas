{ ----------------------------------------------------------------------------
  Window resizer tool for Windows
  https://zipplet.co.uk/
  Copyright (c) Michael Nixon 2018.

  Common / global functions and types unit

  Licensed under the MIT license; please see the LICENSE file for full license
  terms and conditions.
  ---------------------------------------------------------------------------- }
unit unitcommon;

interface

uses SysUtils, windows;

type
  tHWND = LongWord;

  // Window positioning options
  eMoveWindow = (emCentre, emFixed, emNone);

  // Scaling options
  eScaling = (esDefined, esWindowScale, esDisplayScale);

  rSettings = record
    configFileName: ansistring;
    programPath: ansistring;
    programName: ansistring;
    programParameters: ansistring;
    programFileName: ansistring;
    matchPID: boolean;
    matchName: boolean;
    windowNameMask: ansistring;
    firstResizeDelayMS: longint;
    firstResizeTimeoutMS: longint;
    windowWidth: longint;
    windowHeight: longint;
    lockWindow: boolean;
    moveWindow: eMoveWindow;
    alwaysMoveWindow: boolean;
    windowX: longint;
    windowY: longint;
    clientResize: boolean;
    scalingMethod: eScaling;
    scale: longint;
  end;

  rState = record
    windowX: longint;
    windowY: longint;
    windowWidth: longint;
    windowHeight: longint;
    borderWidth: longint;
    borderHeight: longint;
    borderSizeKnown: boolean;
    windowHandle: tHWND;
    pid: cardinal;
    displayWidth, displayHeight: longint;
    desiredWindowWidth, desiredWindowHeight: longint;
  end;

var
  _settings: rSettings;
  _state: rState;

procedure ErrorMessage(s: ansistring);
procedure DebugOut(s: ansistring); inline;
function LoadSettings: boolean;

implementation

uses inifiles;

{ ----------------------------------------------------------------------------
  Output a debug message to the console if running in debug mode.
  Inlined so the compiler will optimise it away if not running with a console.
  ---------------------------------------------------------------------------- }
procedure DebugOut(s: ansistring); inline;
begin
  {$ifdef debug}
    writeln(s);
  {$endif}
end;

{ ----------------------------------------------------------------------------
  Display an error message box.
  ---------------------------------------------------------------------------- }
procedure ErrorMessage(s: ansistring);
begin
  // Must use ansi version of the function
  messageboxa(0, pansichar(s), 'Window Resizer Tool', MB_OK or MB_ICONSTOP);
end;

{ ----------------------------------------------------------------------------
  Load configuration settings.
  Returns TRUE on success, FALSE on failure. Displays messages boxes if errors
  are found to inform the user of the problem.
  ---------------------------------------------------------------------------- }
function LoadSettings: boolean;
var
  ini: tinifile;
  s: ansistring;
begin
  result := false;

  DebugOut('Loading settings from: ' + _settings.configFileName);
  if not fileexists(_settings.configFileName) then begin
    ErrorMessage('Cannot find the configuration file: ' + _settings.configFileName);
    exit;
  end;

  ini := tinifile.Create(_settings.configFileName);

  _settings.programPath := ini.ReadString('program', 'path', GetCurrentDir);
  _settings.programName := ini.ReadString('program', 'name', '');
  _settings.programParameters := ini.ReadString('program', 'parameters', '');
  _settings.windowNameMask := ini.ReadString('windowresize', 'namemask', '');

  s := lowercase(ini.ReadString('windowresize', 'windowfindmethod', ''));
  if s = 'pidonly' then begin
    DebugOut('Window find method: PID only');
    _settings.matchPID := true;
    _settings.matchName := false;
  end else if s = 'pidandname' then begin
    DebugOut('Window find method: PID and name');
    _settings.matchPID := true;
    _settings.matchName := true;
    if _settings.windowNameMask = '' then begin
      ErrorMessage('Invalid settings: windowresize->namemask is empty but required for windowfindmethod=pidandname');
      freeandnil(ini);
      exit;
    end;
  end else if s = 'nameonly' then begin
    DebugOut('Window find method: Name only');
    _settings.matchPID := false;
    _settings.matchName := true;
    if _settings.windowNameMask = '' then begin
      ErrorMessage('Invalid settings: windowresize->namemask is empty but required for windowfindmethod=nameonly');
      freeandnil(ini);
      exit;
    end;
  end else begin
    ErrorMessage('Invalid settings: windowresize->windowfindmethod is not a legal value');
    freeandnil(ini);
    exit;
  end;

  _settings.firstResizeDelayMS := ini.ReadInteger('windowresize', 'firstresizedelayms', 0);
  _settings.firstResizeTimeoutMS := ini.ReadInteger('windowresize', 'firstresizetimeoutms', 0);
  _settings.windowWidth := ini.ReadInteger('windowresize', 'windowwidth', 0);
  _settings.windowHeight := ini.ReadInteger('windowresize', 'windowheight', 0);
  _settings.lockWindow := ini.ReadBool('windowresize', 'lockwindow', false);

  s := lowercase(ini.ReadString('windowresize', 'movewindow', ''));
  if s = 'centre' then begin
    _settings.moveWindow := emCentre;
  end else if s = 'fixed' then begin
    _settings.moveWindow := emFixed;
  end else if s = 'none' then begin
    _settings.moveWindow := emNone;
  end else begin
    ErrorMessage('Invalid settings: windowresize->movewindow is not a legal value');
    freeandnil(ini);
    exit;
  end;

  _settings.alwaysMoveWindow := ini.ReadBool('windowresize', 'alwaysmovewindow', false);
  _settings.windowX := ini.ReadInteger('windowresize', 'windowx', 0);
  _settings.windowY := ini.ReadInteger('windowresize', 'windowy', 0);
  _settings.clientResize := ini.ReadBool('windowresize', 'clientresize', false);

  _settings.scale := ini.ReadInteger('windowresize', 'scale', 0);
  s := lowercase(ini.ReadString('windowresize', 'scalingmethod', ''));
  if s = 'defined' then begin
    _settings.scalingMethod := esDefined;
  end else if s = 'windowscale' then begin
    _settings.scalingMethod := esWindowScale;
    if _settings.scale < 1 then begin
      ErrorMessage('Invalid settings: windowresize->scale is not a legal value or not set (and required for scalingmethod=windowscale)');
      freeandnil(ini);
      exit;
    end;
  end else if s = 'displayscale' then begin
    _settings.scalingMethod := esDisplayScale;
    if _settings.scale < 1 then begin
      ErrorMessage('Invalid settings: windowresize->scale is not a legal value or not set (and required for scalingmethod=displayscale)');
      freeandnil(ini);
      exit;
    end;
  end else begin
    ErrorMessage('Invalid settings: windowresize->scalingmethod is not a legal value');
    freeandnil(ini);
    exit;
  end;

  freeandnil(ini);

  // If the key was defined but is empty, it will not be set to GetCurrentDir()
  if _settings.programPath = '' then begin
    _settings.programPath := GetCurrentDir;
  end;
  _settings.programFileName := _settings.programPath + PathDelim + _settings.programName;

  // Sanity check
  if _settings.programName = '' then begin
    ErrorMessage('Invalid settings: program->name is missing');
    exit;
  end;
  if not directoryexists(_settings.programPath) then begin
    ErrorMessage('Invalid settings: program->path does not point to a valid directory (' +
      _settings.programPath + ')');
    exit;
  end;
  if not fileexists(_settings.programFileName) then begin
    ErrorMessage('Invalid settings: Cannot find the program (' +
      _settings.programFileName + ')');
    exit;
  end;
  if _settings.firstResizeDelayMS <= 0 then begin
    ErrorMessage('Invalid settings: windowresize->firstresizedelayms is not greater than 0');
    exit;
  end;
  if _settings.firstResizeTimeoutMS <= _settings.firstResizeDelayMS then begin
    ErrorMessage('Invalid settings: windowresize->firstresizetimeoutms is not greater than windowresize->firstresizedelayms');
    exit;
  end;
  if _settings.windowWidth <= 0 then begin
    ErrorMessage('Invalid settings: windowresize->windowwidth is not greater than 0');
    exit;
  end;
  if _settings.windowHeight <= 0 then begin
    ErrorMessage('Invalid settings: windowresize->windowheight is not greater than 0');
    exit;
  end;

  // No need to validate windowx/windowy, they are allowed to be zero or negative

  result := true;
end;

{ ----------------------------------------------------------------------------
  Unit initialization
  ---------------------------------------------------------------------------- }
initialization
  _settings.configFileName := GetCurrentDir + PathDelim + 'windowsizer.ini';
  _settings.programPath := '';
  _settings.programName := '';
  _settings.programParameters := '';
  _settings.programFileName := '';
  _settings.matchPID := false;
  _settings.matchName := false;
  _settings.windowNameMask := '';
  _settings.firstResizeDelayMS := 0;
  _settings.firstResizeTimeoutMS := 0;
  _settings.windowWidth := 0;
  _settings.windowHeight := 0;
  _settings.lockWindow := false;
  _settings.clientResize := false;
  _settings.scalingMethod := esDefined;
  _settings.scale := 0;

  _state.windowX := 0;
  _state.windowY := 0;
  _state.windowWidth := 0;
  _state.windowHeight := 0;
  _state.borderWidth := 0;
  _state.borderHeight := 0;
  _state.borderSizeKnown := false;
  _state.windowHandle := INVALID_HANDLE_VALUE;
  _state.pid := 0;
  _state.desiredWindowWidth := 0;
  _state.desiredWindowHeight := 0;
end.
