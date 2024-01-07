local posix = require("posix")

local STDIN = 0

local orig_termios = assert(posix.tcgetattr(0))

local mode = {
    Normal = 0,
    Insert = 1,
}

local function get_window_size()
    local handle = assert(io.popen("stty size", "r"))
    local result = handle:read("*a")
    handle:close()
    local rows, cols = result:match("(%d+) (%d+)")
    return tonumber(rows), tonumber(cols)
end

local rows, cols = get_window_size()

local state = {
    cursor_x = 0,
    cursor_y = 0,
    offset = 0,
    rows = rows,
    cols = cols,
    file_name = arg[1],
    mode = mode.Normal,
    insert_buffer = "",
}

local function buffer_from_file(file_name)
    local buffer = {
    }

    local file = assert(io.open(file_name, "r"))

    for line in file:lines() do
        buffer[#buffer + 1] = line
    end

    file:close()
    return buffer
end

local function enable_raw_mode()
    -- Turn off cannonical and echo mode in the terminal
    local raw = { lflag = orig_termios.lflag & ~(posix.ECHO + posix.ICANON) }
    raw.cc = orig_termios.cc
    -- Disable ctrl C
    --raw.cc[posix.VINTR] = posix._POSIX_VDISABLE

    assert(posix.tcsetattr(STDIN, posix.TCSAFLUSH, raw))
end

local function disable_raw_mode()
    assert(posix.tcsetattr(STDIN, posix.TCSAFLUSH, orig_termios))
end

local function read_keypress()
    return posix.read(0, 1)
end

local function insert_line(buffer)
    local line = buffer[state.cursor_y]
    buffer[state.cursor_y] = line:sub(1, state.cursor_x - 1) .. state.insert_buffer .. line:sub(state.cursor_x)
    state.insert_buffer = ""
end

local function handle_keypress(buffer)
    local c = read_keypress()
    local half_height = state.rows / 2

    if state.mode == mode.Insert then
        if c == "o" then
            insert_line(buffer)
            state.mode = mode.Normal
            return true
        end
        state.insert_buffer = state.insert_buffer..c
        return true
    end

    if c == "h" then
        if state.cursor_x > 0 then
            state.cursor_x = state.cursor_x - 1
        end
    elseif c == "j" then
        if state.cursor_y < state.rows then
            state.cursor_y = state.cursor_y + 1
        elseif state.offset < state.cols then
            state.offset = state.offset + 1
        end
    elseif c == "k" then
        if state.cursor_y > 0 then
            state.cursor_y = state.cursor_y - 1
        elseif state.offset > 0 then
            state.offset = state.offset - 1
        end
    elseif c == "l" then
        if state.cursor_x < state.rows then
            state.cursor_x = state.cursor_x + 1
        end
    elseif c == "i" then
        state.mode = mode.Insert
    elseif c == "x" then
    elseif c == "d" then
        if state.cursor_y + half_height > state.rows then
            state.cursor_y = state.rows
        else
            state.cursor_y = state.cursor_y + half_height
        end
    elseif c == "u" then
        if state.cursor_y >= half_height then
            state.cursor_y = state.cursor_y - half_height
        else
            state.cursor_y = 0
        end
        -- TODO: How to get combined key presses?
    elseif c == "q" then
        return false
    end

    return true
end

local function clear_screen()
    io.write("\27[2J")
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
    for i = offset, state.rows - 1 do
        move_cursor(0, i - 1)
        io.write("\n~")
    end
end

local function draw_status_line()
    move_cursor(0, state.rows)
    local status_line =
        string.format(" Normal | %s | %d:%d ", state.file_name, state.cursor_y, state.cursor_x)
    io.write(status_line)
end

local function draw_buffer(buffer)
    move_cursor(0, 0)
    for i, line in ipairs(buffer) do
        move_cursor(0, i)
        io.write(line.."\n")
        if i == state.rows - 1 then
            break
        end
    end
end

local function update_screen(buffer)
    draw_empty_space(#buffer)
    draw_buffer(buffer)
    draw_status_line()

    move_cursor(state.cursor_x, state.cursor_y)
    io.flush()
end

if #arg ~= 1 then
    error("please provide a single file name as an argument")
    os.exit(1)
end
local buffer = buffer_from_file(state.file_name)
enable_raw_mode()
clear_screen()
update_screen(buffer)
while handle_keypress(buffer) do
    update_screen(buffer)
end
clear_screen()
disable_raw_mode()
