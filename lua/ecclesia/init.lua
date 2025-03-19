local Utils = require("ecclesia.utils")
local uv = vim.loop
local api = vim.api

local M = {}

local function eval_fn_or_id(x)
    if type(x) == "function" then
        return x()
    else
        return x
    end
end

M.linters_map = {
    javascript = { "eslint_d" },
    typescript = { "eslint_d" },
}

function M.linters(key)
    -- Utils.debug("ecclesia.linters." .. key)
    local ok, linter = pcall(require, "ecclesia.linters." .. key)
    if ok then return linter end
    return nil
end

local namespaces = setmetatable({}, {
    __index = function(tbl, key)
        local ns = api.nvim_create_namespace(key)
        rawset(tbl, key, ns)
        return ns
    end,
})

function M.run_lint(linter, opts)
    assert(linter, "lint must be called with a linter")
    local stdin = assert(uv.new_pipe(false), "Must be able to create pipe")
    local stdout = assert(uv.new_pipe(false), "Must be able to create pipe")
    local stderr = assert(uv.new_pipe(false), "Must be able to create pipe")
    local handle
    local env
    local pid_or_err
    local args = {}
    local bufnr = api.nvim_get_current_buf()
    opts = opts or {}
    local cwd = opts.cwd or linter.cwd or vim.fn.getcwd()

    local function eval(...) return Utils.with_cwd(cwd, eval_fn_or_id, ...) end

    if linter.args then vim.list_extend(args, vim.tbl_map(eval, linter.args)) end
    if not linter.stdin and linter.append_fname ~= false then table.insert(args, api.nvim_buf_get_name(bufnr)) end
    if linter.env then
        env = {}
        if not linter.env["PATH"] then
            -- Always include PATH as we need it to execute the linter command
            table.insert(env, "PATH=" .. os.getenv("PATH"))
        end
        for k, v in pairs(linter.env) do
            table.insert(env, k .. "=" .. v)
        end
    end
    local linter_opts = {
        args = args,
        stdio = { stdin, stdout, stderr },
        env = env,
        cwd = cwd,
    }
    local cmd = eval(linter.cmd)
    assert(cmd, "Linter definition must have a `cmd` set: " .. vim.inspect(linter))
    handle, pid_or_err = uv.spawn(cmd, linter_opts, function(code)
        if handle and not handle:is_closing() then
            local procs = {}
            -- Only cleanup if there has not been another procs in between
            local proc = procs[linter.name] or {}
            if handle == proc.handle then procs[linter.name] = nil end
            handle:close()
        end
        if code ~= 0 and not linter.ignore_exitcode then
            vim.schedule(
                function() vim.notify("Linter command `" .. cmd .. "` exited with code: " .. code, vim.log.levels.WARN) end
            )
        end
    end)
    if not handle then
        stdout:close()
        stderr:close()
        stdin:close()
        if not opts.ignore_errors then
            vim.notify("Error running " .. cmd .. ": " .. pid_or_err, vim.log.levels.ERROR)
        end
        return nil
    end
    local state = {
        bufnr = bufnr,
        stdout = stdout,
        stderr = stderr,
        handle = handle,
        linter = linter,
        cwd = linter_opts.cwd,
        ns = namespaces[linter.name],
        cancelled = false,
    }
    local linter_proc = setmetatable(state, {})
    Utils.printTable(linter_proc)
    return {}
end

function M.lint()
    local names = M.linters_map[vim.bo.filetype]
    local opts = {}

    local lookup_linter = function(name)
        local linter = M.linters(name)
        assert(linter, "Linter with name `" .. name .. "` not available")
        if type(linter) == "function" then linter = linter() end
        linter.name = linter.name or name
        return linter
    end

    for _, linter_name in pairs(names) do
        local linter = lookup_linter(linter_name)

        local ok, lintproc_or_error = pcall(M.run_lint, linter, opts)
        -- Utils.debug(opts)
        if ok then
            -- Utils.debug("lint start")
        else
            -- Utils.debug(lintproc_or_error)
        end
    end
end

-- init plugin
function M.setup()
    if vim.fn.has("nvim-0.10") == 1 then
        local async, message = vim.uv.new_async(function()
            vim.schedule(function() vim.notify("run success !!!", vim.log.levels.INFO, {}) end)
        end)
        if async then
            async:send()
        else
            -- Utils.debug(string.format("err,%s", message))
        end
    else
        -- Utils.debug("The version of neovim needs to be at least 0.10!! you can use branch legacy")
    end
end

return M
