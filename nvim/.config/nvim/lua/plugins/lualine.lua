local function getWords()
    return vim.fn.wordcount().words .. ' words'
end
return {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        require("lualine").setup({
            options = {
                theme = "nord",
                always_show_tabline = false,
            },
            sections = { lualine_x = {'encoding', 'fileformat', 'filetype', getWords} },
            tabline = {
                lualine_a = {
                    {
                        "tabs",
                        mode = 2,
                        path = 0,
                        max_length = function()
                            return vim.o.columns
                        end,
                        tab_max_length = 0,
                    },
                },
            },
            extensions = { "fugitive", "mason", "oil", "fzf", "lazy" },
        })
    end,
}
