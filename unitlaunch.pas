{ ----------------------------------------------------------------------------
  Window resizer tool for Windows
  https://zipplet.co.uk/
  Copyright (c) Michael Nixon 2018.

  Launcher unit

  Licensed under the MIT license; please see the LICENSE file for full license
  terms and conditions.
  ---------------------------------------------------------------------------- }
unit unitlaunch;

interface

uses unitcommon;

procedure LaunchProgram;
function TryWindowResize(movewindow: boolean): boolean;
function EnsureWindowLock(movewindow: boolean): boolean;
function FindProgramWindow(matchPID: boolean; pid: cardinal; matchName: boolean; name: ansistring): tHWND;
function WindowTitlesMatch(windowtitle: ansistring; mask: ansistring): boolean;
function NeedToFindWindow: boolean;
function DoFindWindow: boolean;
procedure GetDisplaySize;
function MoveAndResizeWindow(movewindow: boolean): boolean;
procedure CalculateDesiredWindowSize;

implementation

uses sysutils, windows, shellapi, mmsystem;

{ ----------------------------------------------------------------------------
  Calculate the desired size to resize the application window to
  ---------------------------------------------------------------------------- }
procedure CalculateDesiredWindowSize;
var
  fw, fh: single;
begin
  case _settings.scalingMethod of
    esDefined: begin
      _state.desiredWindowWidth := _settings.windowWidth;
      _state.desiredWindowHeight := _settings.windowHeight;
    end;
    esWindowScale: begin
      fw := (_state.originalWindowWidth / 100) * _settings.scale;
      fh := (_state.originalWindowHeight / 100) * _settings.scale;
      _state.desiredWindowWidth := round(fw);
      _state.desiredWindowHeight := round(fh);
    end;
    esDisplayScale: begin
    end;
  end;

  // In client resize mode, add the border sizes to the desired size so that we
  // are adjusting the size of the client area.
  if _settings.clientResize then begin
    inc(_state.desiredWindowWidth, _state.borderWidth);
    inc(_state.desiredWindowHeight, _state.borderHeight);
  end;

  DebugOut('Desired window size: ' + inttostr(_state.desiredWindowWidth) + ' x ' + inttostr(_state.desiredWindowHeight));

  // Crop window if too large
  if _state.desiredWindowWidth > _state.displayWidth then begin
    DebugOut('Warning: Desired window width is wider than the display; cropping');
    _state.desiredWindowWidth := _state.displayWidth;
  end;

  if _state.desiredWindowHeight > _state.displayHeight then begin
    DebugOut('Warning: Desired window height is taller than the display; cropping');
    _state.desiredWindowHeight := _state.displayHeight;
  end;
end;

{ ----------------------------------------------------------------------------
  Resizes the application window to the desired size.
  If <movewindow> is true, the window is also moved.
  Returns TRUE on success, FALSE on failure.
  ---------------------------------------------------------------------------- }
function MoveAndResizeWindow(movewindow: boolean): boolean;
var
  newx, newy: longint;
  windowrect: trect;
begin
  result := false;

  // Need to initialise newx / newy with something even if we don't move the window
  newx := 0;
  newy := 0;

  if movewindow then begin
    if _settings.moveWindow = emFixed then begin
      newx := _settings.windowX;
      newy := _settings.windowY;
    end else if _settings.moveWindow = emCentre then begin
      newx := (_state.displayWidth div 2) - (_state.desiredWindowWidth div 2);
      newy := (_state.displayHeight div 2) - (_state.desiredWindowHeight div 2);
      if (newx < 0) then begin
        DebugOut('Warning: Window would have been offscreen (new X position = ' + inttostr(newx));
        newx := 0;
      end;
      if (newy < 0) then begin
        DebugOut('Warning: Window would have been offscreen (new Y position = ' + inttostr(newy));
        newy := 0;
      end;
    end else begin
      ErrorMessage('Internal error in MoveAndResizeWindow: movewindow mode invalid');
      halt;
    end;
    if SetWindowPos(_state.windowHandle, HWND_TOP, newx, newy, _state.desiredWindowWidth, _state.desiredWindowHeight, SWP_NOACTIVATE or SWP_NOZORDER) then begin
      result := true;
    end else begin
      // Lost window handle
      _state.windowHandle := INVALID_HANDLE_VALUE;
    end;
  end else begin
    if SetWindowPos(_state.windowHandle, HWND_TOP, 0, 0, _state.desiredWindowWidth, _state.desiredWindowHeight, SWP_NOMOVE or SWP_NOACTIVATE or SWP_NOZORDER) then begin
      result := true;
    end else begin
      // Lost window handle
      _state.windowHandle := INVALID_HANDLE_VALUE;
    end;
  end;

  // Get and save new window size
  GetWindowRect(_state.windowHandle, windowrect);
  _state.windowX := windowrect.Left;
  _state.windowY := windowrect.Top;
  _state.windowWidth := windowrect.Right - windowrect.Left;
  _state.windowHeight := windowrect.Bottom - windowrect.Top;
end;

{ ----------------------------------------------------------------------------
  Get the display size and set _state.displayWidth / _state.displayHeight
  ---------------------------------------------------------------------------- }
procedure GetDisplaySize;
begin
  _state.displayWidth := GetSystemMetrics(SM_CXFULLSCREEN);
  _state.displayHeight := GetSystemMetrics(SM_CYFULLSCREEN);
end;

{ ----------------------------------------------------------------------------
  Do we need to find the target window?
  Returns TRUE if we do, FALSE if we don't.
  ---------------------------------------------------------------------------- }
function NeedToFindWindow: boolean;
begin
  if _state.windowHandle <> INVALID_HANDLE_VALUE then begin
    // There is no point calling IsWindow() to check if the handle exists as we
    // open ourselves to a race condition. Instead we will detect window loss
    // later on.
    result := false;
  end else begin
    result := true;
  end;
end;

{ ----------------------------------------------------------------------------
  Try to find the target window.
  If successful, sets _state.windowHandle and returns TRUE.
  ---------------------------------------------------------------------------- }
function DoFindWindow: boolean;
var
  handle: hwnd;
  windowrect: trect;
  windowrectclient: trect;
begin
  result := false;
  _state.windowHandle := INVALID_HANDLE_VALUE;
  _state.borderSizeKnown := false;

  handle := FindProgramWindow(_settings.matchPID,
                              _state.pid,
                              _settings.matchName,
                              _settings.windowNameMask);

  if handle = INVALID_HANDLE_VALUE then begin
    // Window probably temporarily absent (being recreated)
    exit;
  end;

  // Get window border dimensions
  // Used for client dimension resizing mode
  GetWindowRect(handle, windowrect);
  GetClientRect(handle, windowrectclient);
  _state.borderWidth := (windowrect.Right - windowrect.Left) - (windowrectclient.Right - windowrectclient.Left);
  _state.borderHeight := (windowrect.Bottom - windowrect.Top) - (windowrectclient.Bottom - windowrectclient.Top);
  DebugOut('Border size: ' + inttostr(_state.borderWidth) + ' x ' + inttostr(_state.borderHeight));

  if not _state.originalSizeKnown then begin
    // Save original window size
    _state.originalWindowWidth := windowrect.Right - windowrect.Left;
    _state.originalWindowHeight := windowrect.Bottom - windowrect.Top;
    DebugOut('Original window size: ' + inttostr(_state.originalWindowWidth) + ' x ' + inttostr(_state.originalWindowHeight));
  end;

  // Recalculate desired window size
  CalculateDesiredWindowSize;

  // Successfully retrieved window properties
  _state.windowHandle := handle;
  result := true;
end;

{ ----------------------------------------------------------------------------
  Launch the program and resize the window as required
  ---------------------------------------------------------------------------- }
procedure LaunchProgram;
const
  TICK_INTERVAL = 10;
var
  processExitCode: dword;
  currenttime: longint;
  firstResize: boolean;
  abortResize: boolean;
  shouldMoveWindow: boolean;

  startupinfo: tstartupinfoa;
  processinfo: tprocessinformation;
  canTryResize: boolean;
begin
  startupinfo := Default(tstartupinfoa);
  startupinfo.cb := sizeof(startupinfo);

  if not CreateProcessA(pansichar(_settings.programFileName),
                        pansichar(_settings.programParameters),
                        nil,
                        nil,
                        false,
                        0,
                        nil,
                        pansichar(_settings.programPath),
                        startupinfo,
                        processinfo
         ) then begin
    ErrorMessage('Failed to execute program: ' + _settings.programFileName);
    exit;
  end;

  // Record PID for later
  _state.pid := processinfo.dwProcessId;

  DebugOut('Program started, PID = ' + inttostr(_state.pid));
  currenttime := 0;

  // Waiting for first resize
  firstResize := true;

  // Used to stop future resize attempts
  abortResize := false;

  // Should we move the window on the first attempt?
  if _settings.moveWindow <> emNone then begin
    shouldMoveWindow := true;
  end else begin
    shouldMoveWindow := false;
  end;

  if _settings.lockWindow then begin
    DebugOut('Will lock window size');
  end;
  if _settings.alwaysMoveWindow then begin
    DebugOut('Will lock window position');
  end;

  // Request high resolution system timer
  timebeginperiod(1);

  while WaitForSingleObject(processinfo.hProcess, 1) > 0 do begin
    // Note: The timing is not exact, but it's enough for our purposes.
    // I didn't want to pull in more external dependencies.
    sleep(TICK_INTERVAL);
    inc(currenttime, TICK_INTERVAL);

    // Assume we cannot attempt to resize the window.
    // We will set this to true if the window has already been found *or* we
    // successfully find it.
    canTryResize := false;

    if not abortResize then begin
      // If we need to find the window to resize, attempt to do so
      if NeedToFindWindow then begin
        DebugOut('NeedToFindWindow!');
        if not DoFindWindow then begin
          DebugOut('FindWindow failed');
        end else begin
          DebugOut('FindWindow succeeded');
          canTryResize := true;
        end;
      end else begin
        // We *should* have the window handle.
        canTryResize := true;
      end;

      if canTryResize then begin
        if firstResize then begin
          if currenttime >= _settings.firstResizeDelayMS then begin
            DebugOut('Trying to resize window (first time)');
            if TryWindowResize(shouldMoveWindow) then begin
              // Successfully completed first window resize.
              firstResize := false;
              DebugOut('First window resize successful');
              if not _settings.alwaysMoveWindow then begin
                // Don't move the window anymore
                shouldMoveWindow := false;
                DebugOut('No longer repositioning the window');
              end;
            end;
          end;
          if currenttime >= _settings.firstResizeTimeoutMS then begin
            // Resize timeout!
            DebugOut('Timed out resizing window (first time)');
            ErrorMessage('Failed to resize the target window, timed out. Giving up.');
            // Allow the application to keep running, but don't try to resize anymore
            abortResize := true;
          end;
        end else begin
          if _settings.lockWindow then begin
            // Ensure the window remains locked to the correct position
            EnsureWindowLock(shouldMoveWindow);
          end;
        end;
      end;
    end;
  end;

  // Finish using high resolution timer / task switching
  timeendperiod(1);

  GetExitCodeProcess(processinfo.hProcess, processExitCode);
  DebugOut('Program stopped with exit code: ' + inttostr(processExitCode));

  CloseHandle(processinfo.hProcess);
  CloseHandle(processinfo.hThread);
end;

{ ----------------------------------------------------------------------------
  Try to resize the target window. Returns TRUE on success.
  ---------------------------------------------------------------------------- }
function TryWindowResize(movewindow: boolean): boolean;
begin
  // Move and resize application window
  result := MoveAndResizeWindow(movewindow);
  DebugOut('New window position: ' + inttostr(_state.windowX) + ', ' + inttostr(_state.windowY) + ' - ' + inttostr(_state.windowWidth) + ' x ' + inttostr(_state.windowHeight));
end;

{ ----------------------------------------------------------------------------
  Try to locate a target window. Returns the window handle if successful.
  ---------------------------------------------------------------------------- }
function FindProgramWindow(matchPID: boolean; pid: cardinal; matchName: boolean; name: ansistring): tHWND;
const
  MAX_TITLE_LEN = 1024;
var
  temphandle: HWND;
  windowtitletemp: array[0..MAX_TITLE_LEN - 1] of ansichar;
  windowtitlelength: longint;
  windowtitle: ansistring;
  windowpid: cardinal;
begin
  result := INVALID_HANDLE_VALUE;

  // Enumerate all windows
  temphandle := FindWindow(nil, nil);
  while temphandle <> 0 do begin
    windowtitlelength := GetWindowTextA(temphandle, windowtitletemp, MAX_TITLE_LEN);
    windowtitle := windowtitletemp;
    windowtitle := copy(windowtitle, 1, windowtitlelength);
    windowpid := 0;
    GetWindowThreadProcessId(temphandle, windowpid);

    // Matching on PID only?
    if _settings.matchPID and (not _settings.matchName) then begin
      if windowpid = pid then begin
        // Found our window.
        result := temphandle;
        exit;
      end;
    end;

    // Matching on PID and name?
    if _settings.matchPID and _settings.matchName then begin
      if WindowTitlesMatch(windowtitle, _settings.windowNameMask) and (windowpid = pid) then begin
        // Found our window.
        result := temphandle;
        exit;
      end;
    end;

    // Match on name only
    if (not _settings.matchPID) and (_settings.matchName) then begin
      if WindowTitlesMatch(windowtitle, _settings.windowNameMask) then begin
        // Found our window.
        result := temphandle;
        exit;
      end;
    end;

    temphandle := GetWindow(temphandle, GW_HWNDNEXT);
  end;
end;

{ ----------------------------------------------------------------------------
  Returns true if <windowtitle> matches the <mask>.
  The mask can be a full name, or begin/end with * to match a partial title.
  ---------------------------------------------------------------------------- }
function WindowTitlesMatch(windowtitle: ansistring; mask: ansistring): boolean;
var
  s: ansistring;
begin
  result := false;

  // Impossible
  if length(mask) < 1 then exit;

  // Always match
  if mask = '*' then begin
    result := true;
    exit;
  end;

  // Special 1 char case
  if length(mask) = 1 then begin
    if windowtitle = mask then begin
      // Match.
      result := true;
      exit;
    end;
  end;

  // Check for *middle* match
  if length(mask) >= 3 then begin
    if (mask[1] = '*') and (mask[length(mask)] = '*') then begin
      s := copy(mask, 2, length(mask) - 2);
      if pos(s, windowtitle) <> 0 then begin
        // Match.
        result := true;
        exit;
      end;
    end;
  end;

  // No match yet, but mask is >= 2 so safe to assume that.

  // Windowtitle ends with mask
  if mask[1] = '*' then begin
    s := copy(mask, 2, length(mask) - 1);
    if length(windowtitle) < length(s) then exit;
    if copy(windowtitle, length(windowtitle) - length(s) + 1, length(s)) = s then begin
      // Match.
      result := true;
      exit;
    end;
  end;

  // Windowtitle begins with mask
  if mask[length(mask)] = '*' then begin
    s := copy(mask, 1, length(mask) - 1);
    if length(windowtitle) < length(s) then exit;
    if copy(windowtitle, 1, length(s)) = s then begin
      // Match.
      result := true;
      exit;
    end;
  end;

  // Windowtitle is mask
  if windowtitle = mask then begin
    // Match.
    result := true;
    exit;
  end;
end;

{ ----------------------------------------------------------------------------
  Check if the program window has been resized/moved, and fix if required.
  ---------------------------------------------------------------------------- }
function EnsureWindowLock(movewindow: boolean): boolean;
var
  windowrect: trect;
  needAdjustment: boolean;
begin
  result := false;

  needAdjustment := false;

  // Get current window size
  GetWindowRect(_state.windowHandle, windowrect);

  // Do we need to move the window?
  if movewindow then begin
    if (windowrect.Left <> _state.windowX) or (windowrect.Top <> _state.windowY) then begin
      needAdjustment := true;
    end;
  end;

  // Do we need to resize the window?
  if ((windowrect.Right - windowrect.Left) <> _state.windowWidth) or ((windowrect.Bottom - windowrect.Top) <> _state.windowHeight) then begin
    needAdjustment := true;
  end;

  // If we don't need to do anything, bail
  if not needAdjustment then exit;

  // Move and resize application window
  result := MoveAndResizeWindow(movewindow);
end;

end.
