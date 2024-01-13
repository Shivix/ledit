local hl = require("highlight")
local term = require("terminal")

local mode = {
    Normal = 0,
    Insert = 1,
}

local rows, cols = term.get_window_size()

local state = {
    cursor_x = 0,
    cursor_y = 0,
    offset = 0,
    rows = rows,
    cols = cols,
    file_name = arg[1],
    mode = mode.Normal,
    insert_buffer = "",
    message_queue = {},
}

local pos = {
    top = 0,
    -- - 1 for status line
    bottom = state.rows - 1,
    current_line = function()
        return state.cursor_y + state.offset
    end,
}

local function write_buffer(buffer)
    local file = assert(io.open(state.file_name, "w"))
    for _, line in ipairs(buffer) do
        file:write(line, "\n")
    end
    file:close()
end

local function buffer_from_file(file_name)
    local buffer = {}

    local file = assert(io.open(file_name, "r"))

    for line in file:lines() do
        buffer[#buffer + 1] = line
    end

    file:close()
    return buffer
end

local function insert_line(buffer)
    local line = buffer[pos.current_line()]
    buffer[pos.current_line()] = line:sub(1, state.cursor_x - 1)
        .. state.insert_buffer
        .. line:sub(state.cursor_x)
    state.insert_buffer = ""
end

local function move_cursor(x, y)
    io.write("\x1b[" .. y .. ";" .. x .. "H")
end

local function draw_empty_space(offset)
    if offset > state.rows then
        return
    end
    move_cursor(0, offset)
    io.write("~")
    for i = offset, pos.bottom do
        move_cursor(0, i - 1)
        io.write("\n~")
    end
end

local function draw_status_line()
    move_cursor(0, state.rows)
    term.clear_line()
    if #state.message_queue > 0 then
        io.write(table.remove(state.message_queue, #state.message_queue))
        return
    end

    local status_line =
        string.format(" Normal | %s | %d:%d ", state.file_name, state.cursor_y, state.cursor_x)
    io.write(status_line)
end

local function draw_message(msg)
    table.insert(state.message_queue, msg)
end

local function draw_buffer(buffer)
    term.clear_screen()
    move_cursor(0, 0)
    local max_lines = state.rows + state.offset
    if #buffer < state.rows + state.offset then
        max_lines = #buffer
    end
    local a = 0
    for i = state.offset + 1, max_lines do
        a = a + 1
        move_cursor(0, a)
        io.write(hl.highlight_syntax(buffer[i]))
    end
end

local function draw_current_line(buffer)
    move_cursor(0, state.cursor_y)
    local line = buffer[pos.current_line()]
    io.write(hl.highlight_syntax(line))
end

local ctrl = {
    d = string.char(4),
    o = string.char(15),
    u = string.char(21),
}

local normal_keymap = {
    ["h"] = function()
        if state.cursor_x > 0 then
            state.cursor_x = state.cursor_x - 1
        end
    end,
    ["j"] = function(buffer)
        if state.cursor_y ~= pos.bottom then
            state.cursor_y = state.cursor_y + 1
        elseif state.offset ~= #buffer - 1 then
            state.offset = state.offset + 1
            draw_buffer(buffer)
        end
    end,
    ["k"] = function(buffer)
        if state.cursor_y ~= 0 then
            state.cursor_y = state.cursor_y - 1
        elseif state.offset ~= 0 then
            state.offset = state.offset - 1
            draw_buffer(buffer)
        end
    end,
    ["l"] = function()
        if state.cursor_x < state.rows then
            state.cursor_x = state.cursor_x + 1
        end
    end,
    [ctrl.d] = function(buffer)
        local half_height = math.floor(state.rows / 2)
        if state.cursor_y + half_height < state.rows then
            state.cursor_y = state.cursor_y + half_height
        elseif state.offset + half_height < #buffer - 1 then
            state.offset = state.offset + half_height
            draw_buffer(buffer)
            state.cursor_y = pos.bottom
        end
    end,
    [ctrl.u] = function(buffer)
        local half_height = math.floor(state.rows / 2)
        if state.cursor_y >= half_height then
            state.cursor_y = state.cursor_y - half_height
        elseif state.offset > half_height then
            state.offset = state.offset - half_height
            draw_buffer(buffer)
            state.cursor_y = pos.top
        else
            state.offset = 0
            draw_buffer(buffer)
            state.cursor_y = pos.top
        end
    end,
    ["i"] = function()
        state.mode = mode.Insert
    end,
    ["x"] = function(buffer)
        local line = buffer[pos.current_line()]
        buffer[pos.current_line()] = line:sub(1, state.cursor_x - 1) .. line:sub(state.cursor_x + 1)
        draw_buffer(buffer)
    end,
    ["w"] = function(buffer)
        write_buffer(buffer)
        draw_message(state.file_name .. " written!")
    end,
}

local function handle_keypress(buffer)
    local c = term.read_keypress()

    if state.mode == mode.Insert then
        if c == ctrl.o then
            insert_line(buffer)
            draw_current_line(buffer)
            state.mode = mode.Normal
            return true
        end
        state.insert_buffer = state.insert_buffer .. c
        return true
    end

    if c == "q" then
        return false
    end

    local func = normal_keymap[c]
    if func then
        func(buffer)
    end
    return true
end

local function update_screen()
    draw_status_line()
    move_cursor(state.cursor_x, state.cursor_y)
    io.flush()
end

if #arg ~= 1 then
    error("please provide a single file name as an argument")
    os.exit(1)
end
local buffer = buffer_from_file(state.file_name)
term.enable_raw_mode()
term.clear_screen()
draw_empty_space(#buffer)
draw_buffer(buffer)
while handle_keypress(buffer) do
    update_screen()
end
term.clear_screen()
term.disable_raw_mode()
