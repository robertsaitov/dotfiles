return {
	"MagicDuck/grug-far.nvim",
	config = function()
		require("grug-far").setup({
			-- options, see Configuration section below
			-- there are no required options atm
		})
	end,
	keys = {
		{ "<leader>sr", ":GrugFar<cr>", desc = "[s]earch and [r]eplace (grug-far)" },
		{ "<leader>sr", ":GrugFarWithin<cr>", mode = "v", desc = "[s]earch and [r]eplace in selection (grug-far)" },
	},
}

