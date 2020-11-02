require "util"
require "mod-gui"
require "export_csv"


local function tick_to_timestring(tick)
    if not tick then
        return "00:00:00"
    end
    local h = string.format("%02d", math.floor(tick/216000))
    local m = string.format("%02d", math.floor(tick%216000/3600))
    local s = string.format("%02d", math.floor(tick%3600/60))
--    local ms = string.format("%02d", math.floor(tick%60/60*100.))
    return h .. ":" .. m .. ":" .. s
end

local function tick_to_secondstring(tick)
    if not tick then
        return "00.00"
    end
    local s = string.format("%02d", math.floor(tick/60))
    local ms = string.format("%02d", math.floor(tick%60/60*100.))
    return s .. "." .. ms
end

local function page_count(array, page_size)
    if not array then
        return 1
    end
    return math.ceil( table_size(array) / page_size )
end

local function sort_by_duration(list)
    table.sort(list, function (left, right)
        return left.duration > right.duration
    end)
    return list
end

local function process_stats(player_index)
    local log = global.crafting_log[player_index]
    if not log.raw then
        return
    end

    local recipe_lookup = {}

    log.statistics = {}
    for i, item in pairs(log.raw) do
        local n = item.name
        if not log.statistics[n] then
            log.statistics[n] = 0
            recipe_lookup[n] = item.recipe
        end
        log.statistics[n] = log.statistics[n] + 1
    end
    log.sorted_stats =  {}
    for name, count in pairs(log.statistics) do
        table.insert(log.sorted_stats, {
            name = name,
            count = count,
            duration = count * recipe_lookup[name].energy * 60.,
            recipe = recipe_lookup[name]
        })
    end
    log.sorted_stats = sort_by_duration(log.sorted_stats)
end

local function process_smart(player_index)
    local log = global.crafting_log[player_index]
    if not log.raw then
        return
    end

    log.queue = { }
    local q = 0
    for i, item in pairs(log.raw) do
        local batch = log.queue[q]
        local exit_tick = 0
        local start_tick = item.tick - (item.recipe.energy*60)

        if batch and not (batch.name == 'idle-time') then
            batch.duration = batch.count * batch.recipe.energy * 60.
            batch.duration = batch.duration + batch.count
            exit_tick = batch.start_tick + batch.duration
        end

        if start_tick > exit_tick then
            table.insert(log.queue, {
                name = "idle-time",
                count = 1,
                duration = start_tick - exit_tick,
                recipe = nil,
                start_tick = exit_tick
            })
            log.total_times.idle = log.total_times.idle + (start_tick - exit_tick)
            if batch and not (batch.name == 'idle-time') then
                log.total_times.craft = log.total_times.craft + batch.duration
            end
            table.insert(log.queue, {
                name = item.name,
                count = 1,
                duration = 0,
                recipe = item.recipe,
                start_tick = start_tick
            })
            q = q + 2
        elseif batch and batch.name == item.name then
            batch.count = batch.count + 1
        else
            if batch and not (batch.name == 'idle-time') then
                log.total_times.craft = log.total_times.craft + batch.duration
            end
            table.insert(log.queue, {
                name = item.name,
                count = 1,
                duration = 0,
                recipe = item.recipe,
                start_tick = start_tick
            })
            q = q + 1
        end
    end
end

---------
-- GUI --
---------

local list_count = 20

local function get_smart(flow, data)
    local frame = flow.add { type="flow", name = "container", direction ="horizontal" }
    local colA = frame.add { type="flow", name = "colA", direction = "vertical" }
    local colB = frame.add { type="flow", name = "colB", direction = "vertical" }
    local colC = frame.add { type="flow", name = "colC", direction = "vertical" }

    local from = ((data.page_index-1)*list_count)+1
    local to = data.page_index*list_count

    for i = from, to, 1 do
        local r = data.queue[i]
        if r then
            local localised = "Idle"
            local iconized = ""
            if not (r.name == "idle-time") then
                localised = game.item_prototypes[r.name].localised_name
                iconized = "[item=" .. r.name .. "] " .. r.count .. "x "
            end
            colA.add{
                type = "label", 
                caption = tick_to_timestring(r.start_tick) .. " (" .. tick_to_secondstring(r.duration-r.count) .. "s) "
            }
            colB.add{
                type = "label",
                caption = iconized,
                style = "caption_label"
            }
            colC.add{
                type = "label", 
                caption = localised,
                style = "caption_label"
            }
        end
    end
end

local function get_raw(flow, data)
    local frame = flow.add { type="flow", name = "container", direction ="horizontal" }

    local colA = frame.add { type="flow", name = "colA", direction = "vertical" }
    local colB = frame.add { type="flow", name = "colB", direction = "vertical" }
    local colC = frame.add { type="flow", name = "colC", direction = "vertical" }

    local from = ((data.page_index-1)*list_count)+1
    local to = data.page_index*list_count

    for i = from, to, 1 do
        local r = data.raw[i]
        if r then
            local localised = game.item_prototypes[r.name].localised_name
            colA.add{
                type = "label", 
                caption = "" .. tick_to_timestring(r.tick) .. " "
            }
            colB.add{
                type = "label", 
                caption = "[item=" .. r.name .. "] ", 
                style = "caption_label"
            }
            colC.add{
                type = "label", 
                caption = localised, 
                style = "caption_label"
            }
        end
    end
end

local function get_statistics(flow, data)
    local top = flow.add { type="flow", name = "top", direction="horizontal" }
    top.add{ type ="label", caption="Idle time: ", style ="caption_label" }
    top.add{ type ="label", caption=tick_to_timestring(data.total_times.idle) .. "   "}
    top.add{ type ="label", caption="Craft time: ", style ="caption_label" }
    top.add{ type ="label", caption=tick_to_timestring(data.total_times.craft) .. "   "}
    top.add{ type ="label", caption="Game time: ", style ="caption_label" }
    top.add{ type ="label", caption=tick_to_timestring(game.ticks_played)}

    local frame = flow.add { type="flow", name = "container", direction ="horizontal" }
    local colA = frame.add { type="flow", name = "colA", direction = "vertical" }
    local colB = frame.add { type="flow", name = "colB", direction = "vertical" }
    local colC = frame.add { type="flow", name = "colC", direction = "vertical" }
    local colD = frame.add { type="flow", name = "colD", direction = "vertical" }


    local from = ((data.page_index-1)*list_count)+1
    local to = data.page_index*list_count

    for i = from, to, 1 do
        local r = data.sorted_stats[i]
        if r then
            local localised = game.item_prototypes[r.name].localised_name
            colA.add{
                type = "label", 
                caption = tick_to_timestring(r.duration) .. " "
            }
            colB.add{
                type = "label",
                caption = "(" .. r.count .. ") "
            }
            colC.add{
                type = "label", 
                caption = "[item=" .. r.name .. "] ", 
                style = "caption_label"
            }
            colD.add{
                type = "label", 
                caption = localised, 
                style = "caption_label"
            }
        end
    end
end

local function get_page(player_index, data)
    local flow = data.gui_flow
    if flow.container then
        flow.container.destroy()
    end
    if flow.top then
        flow.top.destroy()
    end
    if flow.foot then
        flow.foot.destroy()
    end

    local pcount = 1

    if data.selected_mode == 1 then
--        process_smart(player_index)
        pcount = page_count(data.queue, list_count)
        get_smart(flow, data)

    elseif data.selected_mode == 2 then
        pcount = page_count(data.raw, list_count)
        get_raw(flow, data)

    elseif data.selected_mode == 3 then
--        process_smart(player_index)
        pcount = page_count(data.sorted_stats, list_count)
        get_statistics(flow, data)

    end
    flow.container.style.height = 480

    local foot = flow.add{ type="flow", name="foot", direction = "horizontal" }
    foot.style.top_padding = 8
    foot.add { type="button", caption ="<<", name = "previous_page", enabled = (data.page_index > 1) }
    local pagination = foot.add { type="label", caption = data.page_index .. "/" .. pcount, style = "caption_label" }
    pagination.style.width = 230
    pagination.style.horizontal_align = "center"
    foot.add { type="button", caption =">>", name ="next_page", enabled = (data.page_index < pcount) }
end

local function display_log(event)
    local player = game.get_player(event.player_index)
    local flow = mod_gui.get_frame_flow(player)
    if flow.HandcraftingLog then
        flow.HandcraftingLog.destroy()
        return
    end
    process_stats(event.player_index)
    process_smart(event.player_index)

    local data = global.crafting_log[event.player_index]
    local frame = flow.add { type = "frame", name = "HandcraftingLog", direction = "vertical" }
    
    frame.style.width = 480

    local head = frame.add { type="flow", name= "head", direction = "horizontal" }
    local title = head.add { type="label", caption="Handcrafting Log", style = "caption_label" }
    title.style.width = 160
    local player_names =  {}
    for i = 1, table_size(game.players), 1 do
        table.insert(player_names, game.get_player(i).name)
    end
    head.add { type="drop-down", name="player_select", selected_index = global.crafting_log[event.player_index].view_player_index, items = player_names }
    head.add { type="drop-down", name="mode_select", selected_index = global.crafting_log[event.player_index].selected_mode, items = { "Queue", "Raw", "Totals" } }
    local export_button = head.add { type="button", caption = "CSV", name ="export_csv" }
    export_button.style.width = 50

    local list = frame.add { type= "flow", name = "list", direction = "vertical" }
    data.gui_flow = list

    get_page(event.player_index, data)
end

------------
-- EVENTS --
------------

local function gui_click(event)
    local player = game.players[event.player_index]
    local e = event.element
    if e.valid then
        if e.name == "next_page" then
            local data = global.crafting_log[event.player_index]
            data.page_index = data.page_index + 1
            get_page(event.player_index, data)
        elseif e.name == "previous_page" then
            local data = global.crafting_log[event.player_index]
            data.page_index = data.page_index - 1
            get_page(event.player_index, data)
        elseif e.name == "export_csv" then
            local data = global.crafting_log[event.player_index]
            if  data.selected_mode == 1 then
                export_smart(data.queue, data.view_player_index, event.player_index)
            elseif data.selected_mode == 2 then
                export_raw(data.raw, data.view_player_index, event.player_index)
            elseif data.selected_mode == 3 then
                export_statistics(data.sorted_stats, data.view_player_index, event.player_index)
            end
        end
    end
end

local function gui_selection_state_changed (event)
    local player = game.players[event.player_index]
    local e = event.element
    if e.valid then
        if e.name == "mode_select" then
            local data = global.crafting_log[event.player_index]
            data.page_index = 1
            data.selected_mode = e.selected_index
            get_page(event.player_index, data)
        elseif e.name == "player_select" then
            local data = global.crafting_log[event.player_index]
            data.page_index = 1
            data.view_player_index = e.selected_index
            get_page(event.player_index, data)
        end
    end
end

local function initialize(event)
    if not global.crafting_log then
        global.crafting_log = {}
    end
end

local function player_init(event)
    if not global.crafting_log[event.player_index] then
        global.crafting_log[event.player_index] =  {
            raw = {},
            queue = {},
            statistics = {},
            sorted_stats = {},
            total_times = {
                idle = 0,
                craft = 0
            },

            page_index = 1,
            view_player_index = event.player_index,
            selected_mode = 1,
            gui_flow = nil
        }
    end
end

local function crafting_complete(event)
    local log = global.crafting_log[event.player_index]
    local n = event.item_stack.name
    table.insert(log.raw,
        {
            name = event.item_stack.name,
            recipe = event.recipe,
            tick = event.tick
        })
end

script.on_init(initialize)
script.on_event(defines.events.on_gui_click, gui_click)
script.on_event(defines.events.on_gui_selection_state_changed, gui_selection_state_changed)
script.on_event(defines.events.on_player_created, player_init)
script.on_event(defines.events.on_player_crafted_item, crafting_complete)
-- script.on_nth_tick(60, executeQueue)
-- script.on_event(defines.events.on_player_cursor_stack_changed, displayPatrols)

script.on_event("handcrafting-queue-log", display_log)
