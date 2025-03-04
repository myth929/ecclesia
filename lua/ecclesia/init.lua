local Utils = require("ecclesia.utils")

return {
    -- init plugin
    setup = function()
        if vim.fn.has("nvim-0.10") == 1 then
            local async, message = vim.uv.new_async(function()
                Utils.debug("run success")
                vim.schedule(function() vim.notify("run success !!!", vim.log.levels.INFO, {}) end)
            end)
            if async then
                async:send()
            else
                Utils.debug(string.format("err,%s", message))
            end
        else
            Utils.debug("The version of neovim needs to be at least 0.10!! you can use branch legacy")
        end
    end,
}
