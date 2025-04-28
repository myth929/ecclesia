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

function M.eval_fn(x)
    if type(x) == 'function' then
        return x()
    else
        return x
    end
end

function M.with_cwd(cwd, ...)
    local curcwd = vim.fn.getcwd()
    if curcwd == cwd then
        return M.eval_fn(...)
    else
        local mods = { noautocmd = true }
        vim.cmd.cd({ cwd, mods = mods })
        local ok, result = pcall(M.eval_fn, ...)
        vim.cmd.cd({ curcwd, mods = mods })
        if ok then return result end
        error(result)
    end
end

function M.accumulate_chunks(parse)
    local chunks = {}
    local parse_failure_msg = [[Parser failed. Error message: %s; Output from linter: %s]]
    return {
        on_chunk = function(chunk)
            table.insert(chunks, chunk)
        end,
        on_done = function(publish, linter_cwd)
            vim.schedule(function()
                local output = table.concat(chunks)
                if output ~= "" then
                    local ok, diagnostics = pcall(parse, output, linter_cwd)
                    if not ok then
                        local err = diagnostics
                        diagnostics = {
                            {
                                lnum = 0,
                                col = 0,
                                message = string.format(parse_failure_msg, err, output),
                                severity = vim.diagnostic.severity.ERROR
                            }
                        }
                    end
                    publish(diagnostics)
                else
                    publish({})
                end
            end)
        end,
    }
end

return M
