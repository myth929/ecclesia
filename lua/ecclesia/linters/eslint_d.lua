local binary_name = "eslint_d"
local severities = {
    vim.diagnostic.severity.WARN,
    vim.diagnostic.severity.ERROR,
}

return {
    cmd = function()
        local local_binary = vim.fn.fnamemodify("./node_modules/.bin/" .. binary_name, ":p")
        return vim.uv.fs_stat(local_binary) and local_binary or binary_name
    end,
    args = {
        "--format",
        "json",
        function() return vim.api.nvim_buf_get_name(0) end,
    },
    stdin = true,
    stream = "stdout",
    ignore_exitcode = true,
    parser = function(output, bufnr)
        local trimmed_output = vim.trim(output)
        if trimmed_output == "" then return {} end
        local decode_opts = { luanil = { object = true, array = true } }
        local ok, data = pcall(vim.json.decode, output, decode_opts)
        if string.find(trimmed_output, "No ESLint configuration found") then
            vim.notify_once(trimmed_output, vim.log.levels.WARN)
            return {}
        end
        if not ok then
            return {
                {
                    bufnr = bufnr,
                    lnum = 0,
                    col = 0,
                    message = "Could not parse linter output due to: " .. data .. "\noutput: " .. output,
                },
            }
        end
        -- See https://eslint.org/docs/latest/use/formatters/#json
        local diagnostics = {}
        for _, result in ipairs(data or {}) do
            for _, msg in ipairs(result.messages or {}) do
                table.insert(diagnostics, {
                    lnum = msg.line and (msg.line - 1) or 0,
                    end_lnum = msg.endLine and (msg.endLine - 1) or nil,
                    col = msg.column and (msg.column - 1) or 0,
                    end_col = msg.endColumn and (msg.endColumn - 1) or nil,
                    message = msg.message,
                    code = msg.ruleId,
                    severity = severities[msg.severity],
                    source = binary_name,
                })
            end
        end
        return diagnostics
    end,
}
