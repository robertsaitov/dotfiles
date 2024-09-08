return {
    "rcarriga/nvim-notify",
    opts = {
        background_colour = "#000000",
    },
    config = true,
    vim.keymap.set("n", "<Esc>", function()
        require("notify").dismiss()
    end, { desc = "dismiss notify popup and clear hlsearch" }),
}
