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
	},
	-- Optional dependencies
	-- dependencies = { { "echasnovski/mini.icons", opts = {} } },
	dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
	vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" }),
}
