require "util"

function export_raw(data, player_index, requester_index)
    local player_name = game.get_player(player_index).name
    local path = "handcrafting_log_" .. player_name .. "_raw.csv"

    game.write_file(path, "tick,item,recipe\n", false, requester_index)

    local chunk_data = ""
    local chunk_counter = 0
    local line = ""
    for i, item in pairs(data) do
        line = ""
        line = line .. item.tick .. ","
        line = line .. item.name .. ","
        line = line .. item.recipe.name .. "\n"

        chunk_data = chunk_data .. line
        chunk_counter = chunk_counter + 1
        if chunk_counter == 100 then
            game.write_file(path, chunk_data, true, requester_index)
            chunk_counter = 0
            chunk_data = ""
        end
    end
    game.write_file(path, chunk_data, true, requester_index)
    chunk_data = ""

    game.get_player(requester_index).print("Exported handcrafting data to: " .. path)
end

function export_smart(data, player_index, requester_index)
    local player_name = game.get_player(player_index).name
    local path = "handcrafting_log_" .. player_name .. "_queue.csv"

    game.write_file(path, "tick,duration,count,item,recipe\n", false, requester_index)

    local chunk_data = ""
    local chunk_counter = 0
    local line = ""
    for i, item in pairs(data) do
        line = ""
        line = line .. item.start_tick .. ","
        line = line .. item.duration .. ","
        line = line .. item.count .. ","
        line = line .. item.name .. ","
        if item.recipe then
            line = line .. item.recipe.name .. "\n"
        else
            line = line .. "nil\n"
        end

        chunk_data = chunk_data .. line
        chunk_counter = chunk_counter + 1
        if chunk_counter == 100 then
            game.write_file(path, chunk_data, true, requester_index)
            chunk_counter = 0
            chunk_data = ""
        end
    end
    game.write_file(path, chunk_data, true, requester_index)
    chunk_data = ""

    game.get_player(player_index).print("Exported handcrafting data to: " .. path)
end

function export_statistics(data, player_index, requester_index)
    local player_name = game.get_player(player_index).name
    local path = "handcrafting_log_" .. player_name .. "_statistics.csv"

    game.write_file(path, "duration,count,item,recipe\n", false, requester_index)

    local chunk_data = ""
    local chunk_counter = 0
    local line = ""
    for i, item in pairs(data) do
        line = ""
        line = line .. item.duration .. ","
        line = line .. item.count .. ","
        line = line .. item.name .. ","
        line = line .. item.recipe.name .. "\n"

        chunk_data = chunk_data .. line
        chunk_counter = chunk_counter + 1
        if chunk_counter == 100 then
            game.write_file(path, chunk_data, true, requester_index)
            chunk_counter = 0
            chunk_data = ""
        end
    end
    game.write_file(path, chunk_data, true, requester_index)
    chunk_data = ""

    game.get_player(player_index).print("Exported handcrafting data to: " .. path)
end
