-- @description Toggle show editing guide line on item under mouse cursor in Main Window or in MIDI Editor
-- @author amagalma
-- @version 1.25
-- @about
--   # Displays a guide line on the item under the mouse cursor for easier editing in the Main Window, or a tall line in the focused MIDI Editor
--   - Recommended for a toolbar action
--   - Set line color inside the script (default is white)
--   - When prompted by Reaper, choose to "Terminate instance" and to remember your choice
--   - Requires JS_ReaScriptAPI 1.000 and higher
-- @changelog - Improvement: script starts with the correct line size set by the helper script
-- - Fixed incorrect line size when changing vertical zoom
-- - Immediately show correct line size after toggling size with the helper script

-- Many thanks to juliansader :)

-------------------------------------------------------------------

-- SET LINE COLOR HERE -- (0-255)
local red = 255
local green = 255
local blue = 255

-------------------------------------------------------------------

-- Check if JS_ReaScriptAPI >1.000 is installed
if not reaper.APIExists("JS_ReaScriptAPI_Version") then
  local answer = reaper.MB( "You have to install JS_ReaScriptAPI for this script to work. Would you like to open the relative web page in your browser?", "JS_ReaScriptAPI not installed", 4 )
  if answer == 6 then
    local url = "https://forum.cockos.com/showthread.php?t=212174"
     reaper.CF_ShellExecute( url )
  end
  return reaper.defer(function() end)
else
  local version = reaper.JS_ReaScriptAPI_Version()
  if version < 1 then
    reaper.MB( "Your JS_ReaScriptAPI version is " .. version .. "\nPlease update to version 1.000 or higher.", "Older version is installed", 0 )
    return reaper.defer(function() end)
  end
end

-------------------------------------------------------------------

local reaper = reaper
local debug = false
local MainHwnd = reaper.GetMainHwnd()
local Foreground = reaper.JS_Window_GetForeground()
local MidiWindow
local master = reaper.GetMasterTrack(0)
local trackview = reaper.JS_Window_FindChildByID(MainHwnd, 1000)
local _, trackview_w, trackview_h = reaper.JS_Window_GetClientSize( trackview )
local bigLine, prev_x, prev_y, prev_item, track_y, item_h, set_window
local bm = reaper.JS_LICE_CreateBitmap(true, 1, 1)
red = red and (red < 0 and 0 or (red > 255 and 255 or red)) or 0
green = green and (green < 0 and 0 or (green > 255 and 255 or green)) or 0
blue = blue and (blue < 0 and 0 or (blue > 255 and 255 or blue)) or 0
reaper.JS_LICE_Clear(bm, reaper.ColorToNative( blue, green, red ))
local toggleCmd = reaper.NamedCommandLookup('_RS723f1ed6da61cd868278d4d78b1c1531edc946f4') -- Script: Toggle guide line size 
local bigLine = reaper.GetToggleCommandState( toggleCmd ) == 1 and true or false
local prev_bigLine = reaper.GetToggleCommandState( toggleCmd ) == 1 and true or false
local start = reaper.time_precise()
local prev_vis_tracks_time = start
local continue = true
local change = false
-- Refresh toolbar
local _, _, section, cmdID = reaper.get_action_context()
reaper.SetToggleCommandState( section, cmdID, 1 )
reaper.RefreshToolbar2( section, cmdID )

-------------------------------------------------------------------

function Msg(string)
  if debug then return reaper.ShowConsoleMsg(string) end
end

function exit()
  if bm then reaper.JS_LICE_DestroyBitmap(bm) end
  reaper.SetToggleCommandState( section, cmdID, 0 )
  reaper.RefreshToolbar2( section, cmdID )
  reaper.defer(function() end)
end

function visibletracksheight()
  local tr_cnt = reaper.CountTracks( 0 )
  if tr_cnt < 1 then return 0 end
  local last_track = 0
  for i = 0, tr_cnt-1 do
    local track = reaper.GetTrack( 0, i )
    if reaper.IsTrackVisible(track, false) then
      last_track = track
    end
  end
  local max = reaper.GetMediaTrackInfo_Value(last_track, "I_WNDH") + reaper.GetMediaTrackInfo_Value(last_track, "I_TCPY")
  return max <= trackview_h and max or trackview_h
end
local vis_tracks_h = visibletracksheight()
local prev_vis_tracks_h = vis_tracks_h

-------------------------------------------------------------------

function main()
  local now = reaper.time_precise()
  if now - start >= 0.3 then
    bigLine = reaper.GetToggleCommandState( toggleCmd ) == 1 and true or false
    Foreground = reaper.JS_Window_GetForeground()
    _, trackview_w, trackview_h = reaper.JS_Window_GetClientSize( trackview )
    if bigLine ~= prev_bigLine then
      Msg("Changed guide line size\n")
      prev_bigLine = bigLine
      change = true
    end
    start = now
  end
  if Foreground == MainHwnd then
    if set_window ~= 1 then
      if debug then reaper.ClearConsole() end
      Msg("Foreground is Main Window\n")
      set_window = 1 -- 1 is Main
      bm_size = 0
    end
  else
    MidiWindow = reaper.MIDIEditor_GetActive()
    if MidiWindow and Foreground == MidiWindow then
      if set_window ~= 0 then
        if debug then reaper.ClearConsole() end
        Msg("Foreground is MIDI Window\n")
        set_window = 0 -- 0 is MIDI
        bm_size = -1
      end
    end
  end
  local x, y = reaper.GetMousePosition() -- screen
  -- Main Window
  if set_window == 1 then
    vis_tracks_h = visibletracksheight()
    if vis_tracks_h ~= prev_vis_tracks_h then
      prev_vis_tracks_h = vis_tracks_h
      prev_vis_tracks_time = now
      continue = false
      if bm_size ~= 2 then
        Msg("Changing zoom...\n")
        reaper.JS_Composite(trackview, 0, 0, 0, 0, bm, 0, 0, 1, 1)
        bm_size = 2
        prev_item = nil
      end
    elseif vis_tracks_h == prev_vis_tracks_h and now - prev_vis_tracks_time >= 0.4 then
      if bm_size == 2 then
        Msg("Finished changing zoom\n")
        bm_size = 0
        continue = true
      end
    end
    if continue then
      if change or (x ~= prev_x or y ~= prev_y) then
        prev_x, prev_y = x, y
        change = false
        if bigLine then
          x, y = reaper.JS_Window_ScreenToClient(trackview, x, y)
          if 0 <= x and x <= trackview_w and 0 <= y and y <= trackview_h then
            Msg("draw big line at " .. x .. "\n")
            reaper.JS_Composite(trackview, x, 0, 1, vis_tracks_h, bm, 0, 0, 1, 1)
            bm_size = 1
          elseif bm_size == 1 then
            Msg("make line disappear\n")
            reaper.JS_Composite(trackview, 0, 0, 0, 0, bm, 0, 0, 1, 1)
            bm_size = 0
          end
        else
          local item = reaper.GetItemFromPoint( x, y, true )
          if item then
            if item ~= prev_item then
              prev_item = item
              track_y = reaper.GetMediaTrackInfo_Value( reaper.GetMediaItem_Track( item ), "I_TCPY" )
                    + reaper.GetMediaItemInfo_Value( item, "I_LASTY" ) -- client
              item_h = reaper.GetMediaItemInfo_Value( item, "I_LASTH" )
            end
            Msg("draw line at " .. x .. "\n")
            x, y = reaper.JS_Window_ScreenToClient(trackview, x, y)
            reaper.JS_Composite(trackview, x, track_y, 1, item_h, bm, 0, 0, 1, 1)
            bm_size = 1
          elseif bm_size == 1 then
            Msg("make line disappear\n")
            reaper.JS_Composite(trackview, 0, 0, 0, 0, bm, 0, 0, 1, 1)
            bm_size = 0
          end
        end
      end
    end
  -- MIDI Editor
  elseif set_window == 0 then
    if MidiWindow then
      if x ~= prev_x or y ~= prev_y then
        prev_x, prev_y = x, y
        local midiview = reaper.JS_Window_FindChildByID(MidiWindow, 1001)
        x, y = reaper.JS_Window_ScreenToClient(midiview, x, y)
        local _, mwidth, mheight = reaper.JS_Window_GetClientSize( midiview )
        if x >= 0 and x <= mwidth and y >= 64 and y <= mheight then
          Msg("draw line in Midi Editor at " ..x .. "\n")
          reaper.JS_Composite(midiview, x, 64, 1, mheight-64, bm, 0, 0, 1, 1)
          bm_size = 1
        else
          if bm_size == 1 then
            Msg("make line in Midi Editor disappear\n")
            reaper.JS_Composite(midiview, 0, 0, 0, 0, bm, 0, 0, 1, 1)
            bm_size = 0
          end
        end
      end
    end
  end
  reaper.defer(main)
end

-------------------------------------------------------------------

reaper.atexit(exit) 
main()