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
            },
            sections = { lualine_x = {'encoding', 'fileformat', 'filetype', getWords} },
            extensions = { "fugitive", "mason", "oil", "fzf", "lazy" },
        })
    end,
}
