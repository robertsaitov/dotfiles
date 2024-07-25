return {
    "stevearc/oil.nvim",
    opts = {
        default_file_explorer = true,
        -- win_options = {
        --     signcolumn = "yes:2",
        -- },
        view_options = {
            -- Show files and directories that start with "."
            show_hidden = true,
        },
        lsp_file_methods = {
            -- Time to wait for LSP file operations to complete before skipping
            timeout_ms = 1000,
            -- Set to true to autosave buffers that are updated with LSP willRenameFiles
            -- Set to "unmodified" to only save unmodified buffers
            autosave_changes = true,
        },
    },
    -- Optional dependencies
    -- dependencies = { { "echasnovski/mini.icons", opts = {} } },
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
    vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" }),
}
