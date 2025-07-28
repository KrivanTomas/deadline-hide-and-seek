-- Deadline autoload script for a 'Hide and Seek' game
-- author: KrivanTomas (Github)

-- variables ------------------------------------------
local role = "SPECTATOR"
local game_stage = "INTERMISSION"
local remaining_time = 0
local remaining_time_string = "00:00"

local all_players = {}
local alive_players = {}
local hunters = {}
local prey = {}

local hunter_alive_count = 0
local prey_alive_count = 0


local allow_non_vip_config = false
local sconfig = {
    hunter_max_count = 1,
    hide_interval = 120,
    seek_interval = 240,
    pre_seek_interval = 5,
    end_game_interval = 15,
    env_start_lighting = "claustrophobic_legacy",
    env_start_time = 12,
    env_seek_lighting = "darkworld",
    env_seek_time = 2
}

-- functions ------------------------------------------
function handle_server_request(args)
    if args[1] == "sync_clock" then
        remaining_time = args[2]
        return
    end
    if args[1] == "role_update" then
        role = args[2]
        return
    end
    if args[1] == "game_stage_update" then
        game_stage = args[2]
        return
    end
    if args[1] == "sync_all_players" then
        all_players = args[2]
        return
    end 
    if args[1] == "sync_alive_players" then
        alive_players = args[2]
        recount_players()
        return
    end 
    if args[1] == "sync_prey" then
        prey = args[2]
        recount_players()
        return
    end
    if args[1] == "sync_hunters" then
        hunters = args[2]
        recount_players()
        return
    end
    if args[1] == "update_sconfig" then
        sconfig = args[2]
        redraw_ui()
        return
    end
    if args[1] == "update_allow_non_vip_config" then
        allow_non_vip_config = (args[2] == "true")
        redraw_ui()
        return
    end
    print(`ERROR unkown request '{args[1]}'`)
end

function recount_players()
    hunter_alive_count = 0
    prey_alive_count = 0
    for name, id in alive_players do
        if hunters[name] ~= nil then
            hunter_alive_count += 1
        elseif prey[name] ~= nil then
            prey_alive_count += 1
        end
    end
end

-- ui ------------------------------------------

function redraw_ui()
    ui.clear()
    ui.render({
        {
            type = "widget",
            id = "hide_and_seek",
            title = "Hide and Seek",
            members = {
                {
                    type = "button",
                    text = "Force Sync",
                    callback = function()
                        fire_server("sync_me_pls")
                    end,
                },
                {
                    type = "button",
                    text = "Force start game (owner only)",
                    callback = function()
                        fire_server("force_start_game")
                    end,
                },
                {
                    type = "text",
                    text = "Allow other players to edit this config (owner only)",
                },
                {
                    type = "button",
                    text = `allow_non_vip_config: {allow_non_vip_config}`,
                    callback = function()
                        allow_non_vip_config = not allow_non_vip_config
                        fire_server("update_allow_non_vip_config", allow_non_vip_config and "true" or "false")
                    end,
                },
                {
                    type = "text",
                    text = "Game times",
                },
                {
                    type = "text",
                    text = "hide_interval",
                },
                {
                    type = "textbox",
                    text = sconfig.hide_interval,
                    changed = function(value)
                        sconfig.hide_interval = tonumber(value)
                    end,
                },
                {
                    type = "text",
                    text = "seek_interval",
                },
                {
                    type = "textbox",
                    text = sconfig.seek_interval,
                    changed = function(value)
                        sconfig.seek_interval = tonumber(value)
                    end,
                },
                {
                    type = "text",
                    text = "pre_seek_interval",
                },
                {
                    type = "textbox",
                    text = sconfig.pre_seek_interval,
                    changed = function(value)
                        sconfig.pre_seek_interval = tonumber(value)
                    end,
                },
                {
                    type = "text",
                    text = "end_game_interval",
                },
                {
                    type = "textbox",
                    text = sconfig.end_game_interval,
                    changed = function(value)
                        sconfig.end_game_interval = tonumber(value)
                    end,
                },
                {
                    type = "text",
                    text = "Game atmosphere",
                },
                {
                    type = "text",
                    text = "env_start_time",
                },
                {
                    type = "textbox",
                    text = sconfig.env_start_time,
                    changed = function(value)
                        sconfig.env_start_time = tonumber(value)
                    end,
                },
                {
                    type = "text",
                    text = "env_start_lighting",
                },
                {
                    type = "textbox",
                    text = sconfig.env_start_lighting,
                    changed = function(value)
                        sconfig.env_start_lighting = value
                    end,
                },
                {
                    type = "text",
                    text = "env_seek_time",
                },
                {
                    type = "textbox",
                    text = sconfig.env_seek_time,
                    changed = function(value)
                        sconfig.env_seek_time = tonumber(value)
                    end,
                },
                {
                    type = "text",
                    text = "env_seek_lighting",
                },
                {
                    type = "textbox",
                    text = sconfig.env_seek_lighting,
                    changed = function(value)
                        sconfig.env_seek_lighting = value
                    end,
                },
                {
                    type = "button",
                    text = "Save changes",
                    callback = function()
                        fire_server("update_sconfig", sconfig)
                    end,
                },
            },
        },
    })
end


iris:Connect(function()
    iris.Window({ "Hide and Seek", true})
        iris.Text({"=== Stage: " .. game_stage .. " ==="})
        if game_stage ~= "INTERMISSION" then
            iris.Text({"Remaining time: " .. remaining_time_string})
        end
        iris.Text({"=== Current players ===\nHunters: " .. hunter_alive_count .. "\nPrey: " .. prey_alive_count})
        iris.Tree("Players")
            for name, id in all_players do
                local role_string = "SPECTATOR"
                if alive_players[name] ~= nil then
                    if hunters[name] ~= nil then
                        role_string = "HUNTER"
                    elseif prey[name] ~= nil then
                        role_string = "PREY"
                    end
                else
                    if hunters[name] ~= nil then
                        role_string = "SPECTATOR (HUNTER)"
                    elseif prey[name] ~= nil then
                        role_string = "SPECTATOR (PREY)"
                    end
                end
                iris.Text({name .. ": " .. role_string})
            end
        iris.End()
        iris.Text({ "=== Your role: " .. role .. " ===" })

        if role == "SPECTATOR" and not framework.character.is_alive() and iris.Button({"Spectate"}).clicked() then
            print("Spectate request")
            fire_server("spectate")
        end
    iris.End()
end)

-- events ------------------------------------------

on_server_event:Connect(function(args)
    print("Request from server: ", args[1])
    handle_server_request(args)
end)

-- start ------------------------------------------
--fire_server("sync_me_pls")

local timer = Timer.new(1)
local connection;

connection = time.renderstep("timer", function(delta_time)
    if remaining_time ~= 0 and timer:expired() then
        timer:reset()
        remaining_time -= 1
        remaining_time_string = string.format("%02d:%02d", remaining_time // 60, remaining_time % 60)
    end
end)
