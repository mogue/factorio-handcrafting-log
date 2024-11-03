require "util"
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
    local log = storage.crafting_log[player_index]
    if not log.raw then
        return
    end

    for i = log.process_stats_index, #log.raw, 1 do
        local item = log.raw[i]
        local n    = item.name
        if not log.stats_counts[n] then
            log.stats_counts[n] = 0
            log.stats_recipe_lookup[n] = item.recipe
        end
        log.stats_counts[n] = log.stats_counts[n] + 1
        log.process_stats_index = log.process_stats_index + 1
    end
    log.stats_sorted =  { }
    for name, count in pairs(log.stats_counts) do
        table.insert(log.stats_sorted, {
            name     = name,
            count    = count,
            duration = count * log.stats_recipe_lookup[name].energy * 60.,
            recipe   = log.stats_recipe_lookup[name]
        })
    end
    log.stats_sorted = sort_by_duration(log.stats_sorted)
end

local function process_smart(player_index)
    local log = storage.crafting_log[player_index]
    if not log.raw then
        return
    end

    local q = #log.queue
    for i = log.process_smart_index, #log.raw, 1 do
        local item = log.raw[i]
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
                duration = item.recipe.energy * 60,
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
                duration = batch.recipe.energy * 60,
                recipe = item.recipe,
                start_tick = start_tick
            })
            q = q + 1
        end
        log.process_smart_index = log.process_smart_index + 1
    end
end

---------
-- GUI --
---------

local list_count = 20

local function get_smart(flow, data)
    local frame = flow.add { type="scroll-pane", name = "container", direction ="horizontal" }
    frame.style.width  = 450
    frame.style.height = math.min(data.rows_per_page * 24, 480)
    local tbl  = frame.add { type = "table", name = "tbl", column_count = 3 }

    local from = ((data.page_index-1)*data.rows_per_page)+1
    local to   = data.page_index*data.rows_per_page
    local cnt  = 1

    if data.selected_sort_order == 1 then
        from = table_size(data.queue) - from + 1
        to   = table_size(data.queue) - to + 1
        cnt  = -1
    end

    for i = from, to, cnt do
        local r = data.queue[i]
        if r then
            local localised = "Idle"
            local iconized = ""
            if not (r.name == "idle-time") then
                localised = prototypes.item[r.name].localised_name
                iconized = "[item=" .. r.name .. "] " .. r.count .. "x "
            end
            tbl.add{
                type = "label", 
                caption = tick_to_timestring(r.start_tick) .. " (" .. tick_to_secondstring(r.duration-r.count) .. "s) "
            }
            tbl.add{
                type = "label",
                caption = iconized,
                style = "caption_label"
            }
            tbl.add{
                type = "label", 
                caption = localised,
                style = "caption_label"
            }
        end
    end
end

local function get_raw(flow, data)
    local frame = flow.add { type="scroll-pane", name = "container" }
    frame.style.width  = 450
    frame.style.height = math.min(data.rows_per_page * 24, 480)
    local tbl  = frame.add { type = "table", name = "tbl", column_count = 3 }

    local from = ((data.page_index-1)*data.rows_per_page)+1
    local to = data.page_index*data.rows_per_page
    local cnt  = 1

    if data.selected_sort_order == 1 then
        from = table_size(data.raw) - from + 1
        to   = table_size(data.raw) - to + 1
        cnt  = -1
    end

    for i = from, to, cnt do
        local r = data.raw[i]
        if r then
            local localised = prototypes.item[r.name].localised_name
            tbl.add{
                type = "label", 
                caption = "" .. tick_to_timestring(r.tick) .. " "
            }
            tbl.add{
                type = "label", 
                caption = "[item=" .. r.name .. "] ", 
                style = "caption_label"
            }
            tbl.add{
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

    local frame = flow.add { type="scroll-pane", name = "container" }
    frame.style.width  = 450
    frame.style.height = math.min(data.rows_per_page * 24, 480)
    local tbl  = frame.add { type = "table", name = "tbl", column_count = 4 }

    local from = ((data.page_index-1)*data.rows_per_page)+1
    local to = data.page_index*data.rows_per_page

    for i = from, to, 1 do
        local r = data.stats_sorted[i]
        if r then
            local localised = prototypes.item[r.name].localised_name
            tbl.add{
                type = "label", 
                caption = tick_to_timestring(r.duration) .. " "
            }
            tbl.add{
                type = "label",
                caption = "(" .. r.count .. ") "
            }
            tbl.add{
                type = "label", 
                caption = "[item=" .. r.name .. "] ", 
                style = "caption_label"
            }
            tbl.add{
                type = "label", 
                caption = localised, 
                style = "caption_label"
            }
        end
    end
end

local function get_jump(player_index, data)
    local flow = data.gui_flow
    if flow.foot.jump_page then
        flow.foot.jump_page.destroy()
    end
    local pagination = flow.foot.add { type="textfield", index=2, text = data.page_index, numeric = true, lose_focus_on_confirm = true, name = "jump_page_nr" }
    pagination.style.width = 230
    pagination.style.horizontal_align = "center"
    pagination.select_all()
    pagination.focus()
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
        pcount = page_count(data.queue, data.rows_per_page)
        data.page_index = math.max(1, math.min(pcount, data.page_index) )
        get_smart(flow, data)

    elseif data.selected_mode == 2 then
        pcount = page_count(data.raw, data.rows_per_page)
        data.page_index = math.max(1, math.min(pcount, data.page_index) )
        get_raw(flow, data)

    elseif data.selected_mode == 3 then
        pcount = page_count(data.stats_sorted, data.rows_per_page)
        data.page_index = math.max(1, math.min(pcount, data.page_index) )
        get_statistics(flow, data)

    end
    -- flow.container.style.height = 480

    local foot = flow.add{ type="flow", name="foot", direction = "horizontal" }
    foot.style.top_padding = 8
    foot.add { type="button", caption ="<<", name = "previous_page", enabled = (data.page_index > 1) }
    local pagination = foot.add { type="button", caption = data.page_index .. "/" .. pcount, name = "jump_page" } --  style = "caption_label"
    pagination.style.width = 230
    pagination.style.horizontal_align = "center"
    foot.add { type="button", caption =">>", name ="next_page", enabled = (data.page_index < pcount) }
end

local confirm_delete = false
local function get_settings(player_index, data)
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
    confirm_delete = false
    local frame = flow.add { type="flow", name = "container", direction ="vertical" }

    local spacer = frame.add { type ="empty-widget" }
    spacer.style.height = 5

    local tbl = frame.add { type="table", name = "tbl_align", column_count=2 }
    -- tbl.style.width = 480

    tbl.add { type = "label", caption = "List order: " }
    tbl.add { type="drop-down", name="sort_order_select", selected_index = storage.crafting_log[player_index].selected_sort_order, items = { "Newest first", "Oldest first" }  }

    tbl.add { type = "label", caption = "Items per page: "}
    local list_count_field = tbl.add { type="textfield", text = data.rows_per_page, numeric = true, lose_focus_on_confirm = true, name = "rows_per_page_nr" }
    list_count_field.style.width = 80
    list_count_field.style.horizontal_align = "center"

    tbl.add { type = "label", caption = "Player log enabled: "}
    tbl.add { type="checkbox", name="settings_enabled", state = (data.logging_enabled == true) }

    tbl.add { type = "label", caption = "Delete handcrafting log data: " }
    tbl.add { type="button", caption="Reset player log", name="settings_reset", style="red_button" }

    -- Column Width
    tbl.children[1].style.width = 300
    for i, child in ipairs(tbl.children) do
        if i % 2 == 0 then
            child.style.width = 140
            child.style.height = 32
        end
    end
end

local function display_log(event)
    local player = game.get_player(event.player_index)
    local data = storage.crafting_log[event.player_index]
    local flow = player.gui.top
    if flow.HandcraftingLog then
        flow.HandcraftingLog.destroy()
        data.gui_flow = nil
        return
    end
    process_stats(data.view_player_index)
    process_smart(data.view_player_index)

    local frame = flow.add { type = "frame", name = "HandcraftingLog", direction = "vertical" }
    
    frame.style.width = 480

    local head = frame.add { type="flow", name= "head", direction = "horizontal" }
    local title = head.add { type="label", caption="Handcrafting Log", style = "caption_label" }
    title.style.width = 160
    local player_names =  {}
    for i = 1, #game.players, 1 do
        table.insert(player_names, game.get_player(i).name)
    end
    head.add { type="drop-down", name="player_select", selected_index = storage.crafting_log[event.player_index].view_player_index, items = player_names }
    head.add { type="drop-down", name="mode_select", selected_index = storage.crafting_log[event.player_index].selected_mode, items = { "Queue", "Raw", "Totals", "Settings" } }
    local export_button = head.add { type="button", caption = "CSV", name ="export_csv" }
    export_button.style.width = 50

    local list = frame.add { type= "flow", name = "list", direction = "vertical" }
    data.gui_flow = list
    if data.selected_mode == 4 then
        get_settings(event.player_index, data)
    else
        get_page(event.player_index, data)
    end
end

local function update_gui(player_index, data)
    local pcount = 1
    if data.selected_mode == 1 then
        process_smart(data.view_player_index)
        pcount = page_count(data.queue, list_count)

    elseif data.selected_mode == 2 then
        pcount = page_count(data.queue, list_count)
        --[[
        if (data.page_index == pcount-1 and
             then
        end ]]--

    elseif data.selected_mode == 3 then
        process_stats(data.view_player_index)
    elseif data.selected_mode == 4 then
        return false
        
    end
    
    get_page(player_index, data)
end

------------
-- EVENTS --
------------

local function gui_click(event)
    local player = game.players[event.player_index]
    local e = event.element
    if e.valid then
        if e.name == "next_page" then
            local data = storage.crafting_log[event.player_index]
            data.page_index = data.page_index + 1
            get_page(event.player_index, data)
        elseif e.name == "previous_page" then
            local data = storage.crafting_log[event.player_index]
            data.page_index = data.page_index - 1
            get_page(event.player_index, data)
        elseif e.name == "export_csv" then
            local data = storage.crafting_log[event.player_index]
            if  data.selected_mode == 1 then
                export_smart(data.queue, data.view_player_index, event.player_index)
            elseif data.selected_mode == 2 then
                export_raw(data.raw, data.view_player_index, event.player_index)
            elseif data.selected_mode == 3 then
                export_statistics(data.stats_sorted, data.view_player_index, event.player_index)
            end
        elseif e.name == "settings_reset" then
            local data = storage.crafting_log[event.player_index]
            if confirm_delete then
                reset_player_data(data.view_player_index)
                game.get_player(event.player_index).print("Deleted handcrafting log for " .. game.get_player(data.view_player_index).name)
            else
                confirm_delete = true
                e.style = 'green_button'
                e.style.width = 140
                e.style.height = 32
                e.caption = "Delete?"
            end
        elseif e.name == "jump_page" then
            local data = storage.crafting_log[event.player_index]
            get_jump(event.player_index, data)
        end
    end
end

local function gui_selection_state_changed (event)
    local player = game.players[event.player_index]
    local e = event.element
    if e.valid then
        if e.name == "mode_select" then
            local data = storage.crafting_log[event.player_index]
            data.page_index = 1
            data.selected_mode = e.selected_index
            if data.selected_mode == 1 then
                process_smart(data.view_player_index)
                get_page(event.player_index, data)
            elseif data.selected_mode == 2 then
                get_page(event.player_index, data)
            elseif data.selected_mode == 3 then
                process_stats(data.view_player_index)
                get_page(event.player_index, data)
            elseif data.selected_mode == 4 then
                get_settings(event.player_index, data)
            end
        elseif e.name == "player_select" then
            local data = storage.crafting_log[event.player_index]
            data.page_index = 1
            data.view_player_index = e.selected_index
            if data.selected_mode <= 3 then
                get_page(event.player_index, data)
            elseif data.selected_mode == 4 then
                get_settings(event.player_index, data)
            end
        elseif e.name == "sort_order_select" then
            local data = storage.crafting_log[event.player_index]
            data.selected_sort_order = e.selected_index
        end
    end
end

local function gui_checked_state_changed (event)
    local player = game.players[event.player_index]
    local e = event.element
    if e.valid then
        if e.name == "settings_enabled" then
            local data = storage.crafting_log[event.player_index]
            storage.crafting_log[data.view_player_index].logging_enabled = e.state
        end
    end
end

local function gui_confirmed(event)
    local player = game.players[event.player_index]
    local e = event.element
    if e.valid then
        if e.name == "jump_page_nr" then
            local data = storage.crafting_log[event.player_index]
            data.page_index = e.text + 0
            get_page(event.player_index, data)
	    elseif e.name == "rows_per_page_nr" then
            local data = storage.crafting_log[event.player_index]
            data.rows_per_page = e.text + 0
        end
    end
end

local function gui_text_changed(event)
    local player = game.players[event.player_index]
    local e = event.element
    if e.valid then
        if e.name == "rows_per_page_nr" then
            local data = storage.crafting_log[event.player_index]
            data.rows_per_page = e.text + 0
        end
    end
end

local function initialize(event)
    if not storage.crafting_log then
        storage.crafting_log = {}
    end
end

function reset_player_data(player_index)
    local log = storage.crafting_log[player_index]
    log.raw     = {}
    log.queue   = {}

    log.stats_counts        = {}
    log.stats_recipe_lookup = {}
    log.stats_sorted        = {}

    log.total_times = {
        idle  = 0,
        craft = 0
    }

    log.process_smart_index = 1
    log.process_stats_index = 1
end

local function player_init(event)
    if not storage.crafting_log[event.player_index] then
        storage.crafting_log[event.player_index] = {
            logging_enabled = true,

            page_index = 1,
            view_player_index = event.player_index,
            selected_mode = 1,
            selected_sort_order = 1,
            rows_per_page = 20,

            gui_flow = nil
        }
        reset_player_data(event.player_index)
    end
end

local function crafting_complete(event)
    local log = storage.crafting_log[event.player_index]
    if not log.logging_enabled then
        return
    end
    local n = event.item_stack.name
    table.insert(log.raw, {
        name = event.item_stack.name,
        recipe = event.recipe,
        tick = event.tick
    })
    if log.gui_flow ~= nil then
        update_gui(event.player_index, log)
    end
end

local function lua_shortcut(event)
    if event.prototype_name == 'handcrafting-queue-log-shortcut' then
        display_log(event)
    end
end

script.on_init(initialize)

script.on_event(defines.events.on_gui_click, gui_click)
script.on_event(defines.events.on_gui_selection_state_changed, gui_selection_state_changed)
script.on_event(defines.events.on_gui_checked_state_changed, gui_checked_state_changed)
script.on_event(defines.events.on_gui_confirmed, gui_confirmed)
script.on_event(defines.events.on_gui_text_changed, gui_text_changed)

script.on_event(defines.events.on_player_created, player_init)
script.on_event(defines.events.on_player_crafted_item, crafting_complete)

script.on_event("handcrafting-queue-log", display_log)
script.on_event(defines.events.on_lua_shortcut, lua_shortcut)