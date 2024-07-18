-- This script is a VLC media player extension for automatically saving and loading custom equalizer (EQ) settings for each track.
-- When a track is played, the script saves the current EQ settings to a file specific to that track's URI.
-- When the same track is played again, the script loads the previously saved EQ settings, applying them automatically.

-- How to use this script:
-- 1. Save this script as in the VLC lua extensions directory.
--    For Windows: C:\Program Files\VideoLAN\VLC\lua\extensions\
--    For macOS: /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
--    For Linux: /usr/share/vlc/lua/extensions/
-- 2. Restart VLC media player.
-- 3. Enable the "Custom Equalizer Settings" extension from the VLC menu: View > Custom Equalizer Settings.
-- 4. Play a track and adjust the EQ settings as desired. The settings will be saved automatically.
-- 5. When you play the same track again, the saved EQ settings will be loaded and applied automatically.

local current_track_uri = ""
local last_eq_settings = ""
local eq_directory = ""

function descriptor()
    return {
        title = "Custom Equalizer Settings",
        version = "1.0",
        capabilities = {"input-listener"}
    }
end

function activate()
    current_track_uri = ""
    eq_directory = vlc.config.userdatadir() .. "/eq_settings/"
    create_directory(eq_directory)
    load_eq_settings_once()
end

function deactivate()
end

function meta_changed()
    input_changed()
end

function input_changed()
    save_and_load_eq_settings_once()
end

function save_and_load_eq_settings_once()
    save_eq_settings_if_changed()
    load_eq_settings_once()
end

function save_eq_settings_if_changed()
    local item = vlc.input.item()
    if item then
        local uri = item:uri()
        local eq_file_path = get_eq_file_path(uri)
        local bands = vlc.var.get(vlc.object.aout(), "equalizer-bands")
        if bands ~= last_eq_settings then
            last_eq_settings = bands
            local file, err = io.open(eq_file_path, "w")
            if file then
                file:write(bands)
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

function load_eq_settings_once()
    local item = vlc.input.item()
    if item then
        local uri = item:uri()
        if uri ~= current_track_uri then
            current_track_uri = uri
            local eq_file_path = get_eq_file_path(uri)
            local file, err = io.open(eq_file_path, "r")
            if file then
                local content = file:read("*all")
                file:close()
                if content then
                    vlc.var.set(vlc.object.aout(), "equalizer-bands", content)
                    vlc.var.set(vlc.object.aout(), "equalizer-preamp", 1) -- Ensures the equalizer is enabled
                    vlc.msg.info("EQ settings loaded from " .. eq_file_path)
                    last_eq_settings = content
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

function get_eq_file_path(uri)
    local file_name = uri:gsub("[:/\\?%%*|\"<>]", "_")
    return eq_directory .. file_name .. ".txt"
end

function create_directory(path)
    local file_attr = vlc.io.open(path, "rb")
    if not file_attr then
        os.execute("mkdir \"" .. path .. "\"")
    else
        file_attr:close()
    end
end
