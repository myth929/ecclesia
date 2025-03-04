local Utils = require("ecclesia.utils")
local api = vim.api

return {
    -- init plugin
    setup = function()
        if vim.fn.has("nvim-0.10") == 1 then
            local async, message = vim.uv.new_async(function() Utils.debug("run success") end)
            if async then
                async:send()
            else
                Utils.debug(string.format("err,%s", message))
            end
        else
            Utils.debug("The version of neovim needs to be at least 0.10!! you can use branch legacy")
            api.nvim_notify(
                "The version of neovim needs to be at least 0.10!! you can use branch legacy",
                vim.log.levels.WARN,
                {}
            )
        end
    end,
}
