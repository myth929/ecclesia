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

function M.with_cwd(cwd, fn, ...)
    local curcwd = vim.fn.getcwd()
    if curcwd == cwd then
        return fn(...)
    else
        local mods = { noautocmd = true }
        vim.cmd.cd({ cwd, mods = mods })
        local ok, result = pcall(fn, ...)
        vim.cmd.cd({ curcwd, mods = mods })
        if ok then return result end
        error(result)
    end
end

return M
