return {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
        lsp = {
            override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                ["vim.lsp.util.stylize_markdown"] = true,
                ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
            },
        },
        presets = {
            bottom_search = true, -- use a classic bottom cmdline for search
            command_palette = false, -- position the cmdline and popupmenu together
            long_message_to_split = true, -- long messages will be sent to a split
            inc_rename = false,  -- enables an input dialog for inc-rename.nvim
            lsp_doc_border = false, -- add a border to hover docs and signature help
        },
        cmdline_popup = {
            position = {
                row = 5,
                col = "50%",
            },
            size = {
                width = 60,
                height = "auto",
            },
        },
        messages = {
            -- NOTE: If you enable messages, then the cmdline is enabled automatically.
            -- This is a current Neovim limitation.
            enabled = false,     -- enables the Noice messages UI
            view = "notify",    -- default view for messages
            view_error = "notify", -- view for errors
            view_warn = "notify", -- view for warnings
            view_history = "messages", -- view for :messages
            view_search = "virtualtext", -- view for search count messages. Set to `false` to disable
        },
    },
    dependencies = {
        "MunifTanjim/nui.nvim",
        "rcarriga/nvim-notify",
    },
}
