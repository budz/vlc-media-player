-- This script is a VLC media player extension for automatically saving and loading custom equalizer (EQ) settings for each track - now with output profiles.
-- When a track is played, the script saves the current preamp +EQ settings to a file specific to that track's URI.
-- When the same track is played again, the script loads the previously saved EQ settings, applying them automatically.

-- How to use this script:
-- 1. Save this script as in the VLC lua extensions directory.
--    For Windows: C:\Program Files\VideoLAN\VLC\lua\extensions\
--    For macOS: /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
--    For Linux: /usr/share/vlc/lua/extensions/
-- 2. Restart VLC media player.
-- 3. Enable the "Custom Equalizer Settings" extension from the VLC menu: View > Custom Equalizer Settings.
-- 4. Select Headphones or Speakers. Headphones are default.
-- 4. Play a track and adjust the EQ settings as desired. The settings will be saved automatically.
-- 5. When you play the same track again, the saved EQ settings will be loaded and applied automatically.

local current_track_uri = ""
local last_eq_settings = ""
local last_preamp_setting = ""
local eq_directory = ""
local profile = "headphones" -- Default profile
local dlg = nil

-- Descriptor for the VLC extension
function descriptor()
    return {
        title = "Custom Equalizer Settings",
        version = "1.2",
        capabilities = {"input-listener"}
    }
end

-- Initialize directories and load settings
function activate()
    current_track_uri = ""
    eq_directory = vlc.config.userdatadir() .. "/eq_settings/"
    create_directory(eq_directory)
    load_eq_settings_once()
    show_menu()
end

-- Clean up when deactivated
function deactivate()
    if dlg then
        dlg:delete()
        dlg = nil
    end
end

-- Handle meta data changes
function meta_changed()
    input_changed()
end

-- Handle input changes
function input_changed()
    save_and_load_eq_settings_once()
end

-- Save and load EQ settings
function save_and_load_eq_settings_once()
    save_eq_settings_if_changed()
    load_eq_settings_once()
end

-- Save EQ settings if they have changed
function save_eq_settings_if_changed()
    local item = vlc.input.item()
    if item then
        local uri = item:uri()
        local eq_file_path = get_eq_file_path(uri)
        local bands = vlc.var.get(vlc.object.aout(), "equalizer-bands")
        local preamp = vlc.var.get(vlc.object.aout(), "equalizer-preamp")
        if bands ~= last_eq_settings or preamp ~= last_preamp_setting then
            last_eq_settings = bands
            last_preamp_setting = preamp
            local file, err = io.open(eq_file_path, "w")
            if file then
                file:write("bands:" .. bands .. "\n")
                file:write("preamp:" .. preamp .. "\n")
                file:close()
                vlc.msg.info("EQ settings saved to " .. eq_file_path)
            else
                vlc.msg.err("Error opening file for writing: " .. eq_file_path .. " - " .. err)
            end
        end
    else
        vlc.msg.err("No item found")
    end
end

-- Load EQ settings
function load_eq_settings_once()
    local item = vlc.input.item()
    if item then
        local uri = item:uri()
        if uri ~= current_track_uri then
            current_track_uri = uri
            local eq_file_path = get_eq_file_path(uri)
            local file, err = io.open(eq_file_path, "r")
            if file then
                local bands = nil
                local preamp = nil
                for line in file:lines() do
                    if line:match("^bands:") then
                        bands = line:gsub("bands:", "")
                    elseif line:match("^preamp:") then
                        preamp = line:gsub("preamp:", "")
                    end
                end
                file:close()
                if bands and preamp then
                    vlc.var.set(vlc.object.aout(), "equalizer-bands", bands)
                    vlc.var.set(vlc.object.aout(), "equalizer-preamp", tonumber(preamp))
                    refresh_eq_sliders()
                    vlc.msg.info("EQ settings loaded from " .. eq_file_path)
                    last_eq_settings = bands
                    last_preamp_setting = preamp
                else
                    vlc.msg.err("Error reading EQ settings from file: " .. eq_file_path)
                end
            else
                vlc.msg.info("No EQ settings file found for " .. uri)
            end
        end
    else
        vlc.msg.err("No item found")
    end
end

-- Get the path for the EQ settings file
function get_eq_file_path(uri)
    local file_name = uri:gsub("[:/\\?%%*|\"<>]", "_")
    return eq_directory .. profile .. "_" .. file_name .. ".txt"
end

-- Create the directory if it doesn't exist
function create_directory(path)
    local file_attr = vlc.io.open(path, "rb")
    if not file_attr then
        os.execute("mkdir \"" .. path .. "\"")
    else
        file_attr:close()
    end
end

-- Refresh the EQ sliders
function refresh_eq_sliders()
    local aout = vlc.object.aout()
    if aout then
        vlc.var.trigger_callback(aout, "equalizer-bands")
        vlc.var.trigger_callback(aout, "equalizer-preamp")
    end
end

-- Show menu to switch between profiles
function show_menu()
    dlg = vlc.dialog("Custom Equalizer Settings")

    dlg:add_label("Select EQ Profile:", 1, 1, 1, 1)
    dlg:add_button("Headphones", switch_to_headphones, 1, 2, 1, 1)
    dlg:add_button("Speakers", switch_to_speakers, 2, 2, 1, 1)
    dlg:show()
end

-- Switch to headphones profile
function switch_to_headphones()
    profile = "headphones"
    vlc.msg.info("Switched to headphones profile")
    load_eq_settings_once() -- Reload settings for the new profile
end

-- Switch to speakers profile
function switch_to_speakers()
    profile = "speakers"
    vlc.msg.info("Switched to speakers profile")
    load_eq_settings_once() -- Reload settings for the new profile
end


