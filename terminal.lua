local posix = require("posix")

local M = {}

local STDIN = 0
local orig_termios = assert(posix.tcgetattr(0))
print("test")
function M.get_window_size()
    local handle = assert(io.popen("stty size", "r"))
    local result = handle:read("*a")
    handle:close()
    local rows, cols = result:match("(%d+) (%d+)")
    return tonumber(rows), tonumber(cols)
end

function M.enable_raw_mode()
    -- Turn off cannonical and echo mode in the terminal
    local raw = { lflag = orig_termios.lflag & ~(posix.ECHO + posix.ICANON) }
    raw.cc = orig_termios.cc
    -- Disable ctrl C
    --raw.cc[posix.VINTR] = posix._POSIX_VDISABLE

    assert(posix.tcsetattr(STDIN, posix.TCSAFLUSH, raw))
end

function M.disable_raw_mode()
    assert(posix.tcsetattr(STDIN, posix.TCSAFLUSH, orig_termios))
end

function M.read_keypress()
    return posix.read(0, 1)
end

function M.clear_screen()
    io.write("\27[2J")
end

function M.clear_line()
    io.write("\27[2K")
end

return M
