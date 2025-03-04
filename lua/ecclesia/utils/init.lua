local M = {}

--- print all information like log
--- @param ... any
function M.debug(...)
    local args = { ... }
    if #args == 0 then return end
    local date = os.date("%Y-%m-%d %H:%M:%S")
    local formated_args = { "[" .. date .. "] [DEBUG]" }
    for _, arg in ipairs(args) do
        if type(arg) == "string" then
            table.insert(formated_args, arg)
        else
            table.insert(formated_args, vim.inspect(arg))
        end
    end
    print(unpack(formated_args))
end

return M
