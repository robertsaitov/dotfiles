return {
    "tpope/vim-fugitive",
    dependencies = {
       "lewis6991/gitsigns.nvim",
       "barrettruth/diffs.nvim"
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("gitsigns").setup()
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git)

        vim.api.nvim_create_augroup("Fugitive", {})
        vim.api.nvim_create_autocmd("BufWinEnter", {
            group = "Fugitive",
            pattern = "*",
            callback = function()
                if vim.bo.ft ~= "fugitive" then
                    return
                end

                local bufnr = vim.api.nvim_get_current_buf()
                local opts = { buffer = bufnr, remap = false }
                vim.keymap.set("n", "<leader>p", function()
                    vim.cmd.Git('push')
                end, opts)

                -- rebase always
                vim.keymap.set("n", "<leader>P", function()
                    vim.cmd.Git('pull')
                end, opts)

                vim.keymap.set("n", "<leader>t", ":Git push -u origin ", opts);
            end,
        })

        vim.keymap.set("n", "gu", "<cmd>diffget //2<CR>")
        vim.keymap.set("n", "gh", "<cmd>diffget //3<CR>")
    end
}
