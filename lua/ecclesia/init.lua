local Utils = require("ecclesia.utils")
local uv = vim.uv

local M = {}

M.linters_map = {
    javascript = { "eslint_d" },
    typescript = { "eslint_d" },
}

function M.linters(key)
    local ok, linter = pcall(require, "ecclesia.linters." .. key)
    if ok then return linter end
    return nil
end

local function read_output(cwd, parser, publish_fn)
    return function(err, chunk)
        Utils.debug(Utils.debug(chunk), chunk)
        assert(not err, err)
        if chunk then
            parser.on_chunk(chunk)
        else
            parser.on_done(publish_fn, cwd)
        end
    end
end

function M.run_lint(linter)
    local stdin = assert(uv.new_pipe(false), "Must be able to create pipe")
    local stdout = assert(uv.new_pipe(false), "Must be able to create pipe")
    local stderr = assert(uv.new_pipe(false), "Must be able to create pipe")
    local handle
    local pid_or_err
    local args = {}
    local opts = {}
    local cwd = linter.cwd or vim.fn.getcwd()

    local function eval(...) return Utils.with_cwd(cwd, ...) end

    vim.list_extend(args, vim.tbl_map(eval, linter.args))

    local linter_opts = {
        args = args,
        stdio = { stdin, stdout, stderr },
        cwd = cwd,
        detached = true
    }

    local cmd = eval(linter.cmd)

    handle, pid_or_err = uv.spawn(cmd, linter_opts, function(code)
        Utils.debug("进程退出码:", code)
    end)

    if handle then
        Utils.debug(pid_or_err)
        Utils.debug(cmd, linter_opts)
    else
        Utils.debug("子进程启动失败！")
        stdout:close()
        stderr:close()
        stdin:close()
        if not opts.ignore_errors then
            vim.notify("Error running " .. cmd .. ": " .. pid_or_err, vim.log.levels.ERROR)
        end
        return nil
    end

    local timer = uv.new_timer()
    timer:start(20000, 0, function()
        if handle and not handle:is_closing() then
            handle:kill("sigkill")
            Utils.debug("超时强制终止进程")
        end
        timer:close()
    end)

    local parser = Utils.accumulate_chunks(linter.parser)

    local publish = function(diagnostics)
        Utils.debug(type(diagnostics), diagnostics)
    end

    local stream = linter.stream

    if not stream or stream == 'stdout' then
        stdout:read_start(function(err, chunk)
            Utils.debug(err)
            xpcall(function()
                assert(not err, err)
                if chunk then
                    parser.on_chunk(chunk)
                else
                    parser.on_done(publish, cwd)
                end
            end, function(e)
                print("回调出错:", e)
            end)
        end)
    elseif stream == 'stderr' then
        stderr:read_start(read_output(cwd, parser, publish))
    else
        error('Invalid `stream` setting: ' .. stream)
    end

    return {}
end

function M.init_lint()
    local names = M.linters_map[vim.bo.filetype]

    if not names then return end

    local lookup_linter = function(name)
        local linter = M.linters(name)
        assert(linter, "Linter with name `" .. name .. "` not available")
        linter.name = linter.name or name
        return linter
    end

    for _, linter_name in pairs(names) do
        local linter = lookup_linter(linter_name)

        local ok, lintproc_or_error = pcall(M.run_lint, linter)
    end
end

-- init plugin
function M.setup(opts)
    if opts.run_lint then
        vim.keymap.set(
            "n",
            opts.run_lint,
            function() M.init_lint() end,
            { desc = "Trigger linting for current file" }
        )
    end
end

return M
