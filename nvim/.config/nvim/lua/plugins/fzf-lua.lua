return {
    "ibhagwan/fzf-lua",
    -- optional for icon support
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        -- calling `setup` is optional for customization
        local fzf = require("fzf-lua")
        fzf.setup({
            keymap = {
                fzf = {
                    ["ctrl-q"] = "select-all+accept",
                },
            }
        })
        vim.keymap.set("n", "<leader>ff", fzf.files, {})
        vim.keymap.set("n", "<leader>fg", fzf.live_grep, {})
        vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Find Buffers" })
        vim.keymap.set("n", "<leader>fh", fzf.helptags, { desc = "Find Help Tags" })
        vim.keymap.set("n", "<leader>fs", fzf.lsp_document_symbols, { desc = "Find Symbols" })
    end,
}
