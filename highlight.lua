local M = {}

local lua_keywords = {
    "and",
    "break",
    "do",
    "else",
    "elseif",
    "end",
    "false",
    "for",
    "function",
    "goto",
    "if",
    "in",
    "local",
    "nil",
    "not",
    "or",
    "repeat",
    "return",
    "then",
    "true",
    "until",
    "while",
}

function M.highlight_syntax(line)
    local red = "\27[31m"
    local default = "\27[0m"
    local result = line
    for _, keyword in ipairs(lua_keywords) do
        local pattern = "%f[%a]" .. keyword .. "%f[^%a]"
        result = result:gsub(pattern, red .. keyword .. default)
    end
    return result
end

return M
