-- Deadline autoload script for a 'Hide and Seek' game
-- author: KrivanTomas (Github)

-- config ------------------------------------------
allow_non_vip_config = false
local sconfig = {
    hunter_max_count = 1,
    hide_interval = 120,
    seek_interval = 240,
    pre_seek_interval = 5,
    end_game_interval = 15,
    env_start_lighting = "claustrophobic_legacy",
    env_start_time = 12,
    env_seek_lighting = "darkworld",
    env_seek_time = 2,
}

-- variables ------------------------------------------
local all_players = {}
local player_count = 0
local alive_players = {}
local hunters = {} -- attackers
local prey = {} -- defenders
local game_id = 0 -- incrementing id for disabling invalid delays

-- functions ------------------------------------------
function setup_server()
    chat.set_spawning_disabled_reason("The game has not started yet")
    sharedvars.sv_spawning_enabled = false
    sharedvars.chat_tips_enabled = false
    sharedvars.gm_team_balancing_threshold = 0
    sharedvars.plr_explosion_damage_multiplier = 0
    sharedvars.plr_disable_nvg = true
    sharedvars.plr_enable_markers = false -- disabled due to bug
end

function reload_players()
    print("Loading players ...")
    all_players = {}
    alive_players = {}
    for i, player in players.get_all() do 
        print(player.name, player.id)
        all_players[player.name] = player.id
    end
    recount_players()
end


function print_players(list)
    for name, id in list do
        print(name, id)
    end
end

function recount_players()
    player_count = 0
    for name, id in all_players do
        player_count += 1
    end
end

function assign_hunters()
    hunters = {}
    local hunterIndex = math.random(1, player_count)
    local index = 1
    for name, id in all_players do
        if index == hunterIndex then
            hunters[name] = id
            local player = players.get(name)
            player.fire_client("role_update", "HUNTER")
            player.set_team("attacker")
        end
        index += 1
    end
end

function assign_remaining_prey()
    for name, id in all_players do
        if hunters[name] == nil then
            prey[name] = id
            local player = players.get(name)
            player.fire_client("role_update", "PREY")
            player.set_team("defender")
        end
    end
end

function sync_clients()
    --print("all")
    --print_players(all_players)
    --print("alive")
    --print_players(alive_players)
    for i, player in players.get_all() do 
        player.fire_client("sync_all_players", all_players)
        player.fire_client("sync_alive_players", alive_players)
        player.fire_client("sync_hunters", hunters)
        player.fire_client("sync_prey", prey)
        player.fire_client("update_allow_non_vip_config", allow_non_vip_config and "true" or "false")
        player.fire_client("update_sconfig", sconfig)
    end
end

function spawn_prey()
    for name, id in all_players do
        if prey[name] ~= nil then
            alive_players[name] = id
            local player = players.get(name)
            player.set_camera_mode("Default")
            player.spawn()
            player.set_weapon("primary", "nothing", {})
            player.set_weapon("secondary", "nothing", {})
            player.set_weapon("throwable1", "nothing", {})
            player.set_weapon("throwable2", "nothing", {})
        end
    end
end

function spawn_hunters()
    for name, id in all_players do
        if hunters[name] ~= nil then
            alive_players[name] = id
            local player = players.get(name)
            local setup = weapons.get_setup_from_code("fm15-0242-m5e1-e25z-a4hf-zf8q-gcww-70fm")
            player.set_camera_mode("Default")
            player.spawn()
            player.set_weapon("primary", "Remington870", setup.data.data)
            player.set_weapon("secondary", "M11_EOD", {})
            player.set_weapon("throwable1", "nothing", {})
            player.set_weapon("throwable2", "nothing", {})
            player.equip_weapon("primary", true)
        end
    end
end

function start_game()
    map.set_time(sconfig.env_start_time)
    map.set_preset(sconfig.env_start_lighting)
    chat.set_spawning_disabled_reason("Game already in progress")

    alive_players = {}
    assign_hunters()
    assign_remaining_prey()
    spawn_prey()
    sync_clients()
    for name, id in all_players do
        local player = players.get(name)
        player.fire_client("game_stage_update", "HIDE")
        player.fire_client("sync_clock", sconfig.hide_interval)
    end
    time.delay(math.max(sconfig.hide_interval - sconfig.pre_seek_interval, 0), function()
        map.set_time(sconfig.env_seek_time)
        map.set_preset(sconfig.env_seek_lighting)
        map.kill_map_lights()
    end)
    time.delay(sconfig.hide_interval, function()
        spawn_hunters()
        sync_clients()
        for name, id in all_players do
            local player = players.get(name)
            player.fire_client("game_stage_update", "SEEK")
            player.fire_client("sync_clock", sconfig.seek_interval)
        end
        local past_game_id = game_id
        time.delay(sconfig.seek_interval, function()
            if game_id == past_game_id then
                chat.send_ingame_notification("PREY WINS")
                end_game()
            end
        end)
    end)
end

function check_win_conditions()
    local hunter_alive_count = 0
    local prey_alive_count = 0

    for name, id in alive_players do
        if hunters[name] ~= nil then
            hunter_alive_count += 1
        elseif prey[name] ~= nil then
            prey_alive_count += 1
        end
    end

    if hunter_alive_count == 0 then
        chat.send_ingame_notification("PREY WINS (the hunters died somehow)")
        end_game()
        return
    elseif prey_alive_count == 0 then
        chat.send_ingame_notification("HUNTERS WIN")
        end_game()
        return
    end 

    if prey_alive_count == 1 then
        for name, id in prey do
            local player = players.get(name)
            player.set_weapon("primary", "TestFlash", {})
            player.equip_weapon("primary", true)
        end
    end
end

function end_game()
    game_id += 1
    chat.set_spawning_disabled_reason("The game has not started yet")
    map.set_time(sconfig.env_start_time)
    map.set_preset(sconfig.env_start_lighting)
    
    for name, id in all_players do
        local player = players.get(name)
        player.fire_client("game_stage_update", "GAME END")
        player.fire_client("sync_clock", sconfig.end_game_interval)
    end

    time.delay(sconfig.end_game_interval, function()
        hunters = {}
        prey = {}
        alive_players = {}
        for name, id in all_players do
            local player = players.get(name)
            player.kill()
            player.fire_client("game_stage_update", "INTERMISSION")
        end
        sync_clients()
        players.reset_ragdolls()
    end)
end

function force_end_game()
    game_id += 1
    chat.set_spawning_disabled_reason("The game has not started yet")
    map.set_time(sconfig.env_start_time)
    map.set_preset(sconfig.env_start_lighting)
    
    hunters = {}
    prey = {}
    alive_players = {}
    for name, id in all_players do
        local player = players.get(name)
        player.fire_client("game_stage_update", "INTERMISSION")
        player.kill()
        sync_clients()
        players.reset_ragdolls()
    end
end

function handle_client_request(player_name, args)
    if args[1] == "spectate" then
        if alive_players[player_name] == nil then
            spectate(players.get(player_name))
        end
        return
    end
    if args[1] == "sync_me_pls" then
        local player = players.get(player_name)
        sync_clients()
        return
    end
    if args[1] == "force_start_game" then
        if player_name == sharedvars.vip_owner then
            force_end_game()
            start_game()
        end
        return
    end
    if args[1] == "update_allow_non_vip_config" then
        if player_name == sharedvars.vip_owner then
            allow_non_vip_config = (args[2] == "true")
            for name, id in all_players do 
                players.get(name).fire_client("update_allow_non_vip_config", args[2])
            end
        end
        return
    end
    if args[1] == "update_sconfig" then
        if allow_non_vip_config or player_name == sharedvars.vip_owner then
            sconfig = args[2]
            for name, id in all_players do 
                players.get(name).fire_client("update_sconfig", sconfig)
            end
        end
        return
    end
    print(`ERROR unkown request '{args[1]}'`)
end

function spectate(player)
    player.set_camera_mode("Freecam")
    player.spawn()
    player.set_health(10000)
end

-- setup ------------------------------------------
setup_server()
reload_players()
sync_clients()

-- events ------------------------------------------

on_client_event:Connect(function(player, args)
    print("Request from client: ", player, args[1])
    handle_client_request(player, args)
end)

on_player_died:Connect(function(name, position, killer_data, stats_counted)
    local player = players.get(name)
    if alive_players[name] ~= nil then
        alive_players[name] = nil
        sync_clients()
        recount_players()
        check_win_conditions()
        player.fire_client("role_update", "SPECTATOR")
        time.delay(3, function()
            spectate(player)
        end)
    end
end)

on_player_joined:Connect(function(name)
    local player = players.get(name)
    all_players[player.name] = player.id
    sync_clients()
    recount_players()
end)

on_player_left:Connect(function(name)
    all_players[name] = nil
    alive_players[name] = nil
    hunters[name] = nil
    prey[name] = nil
    sync_clients()
    recount_players()
    check_win_conditions()
end)