return {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html",
    dependencies = {
        "MunifTanjim/nui.nvim",

        -- optional
        "nvim-treesitter/nvim-treesitter",
        "rcarriga/nvim-notify",
        "nvim-tree/nvim-web-devicons",
    },
    opts = {
        lang = "typescript",        -- configuration goes here
    },
}
