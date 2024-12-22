function R(name)
	require("plenary.reload").reload_module(name)
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("wrap_spell", { clear = true }),
	pattern = { "gitcommit", "markdown" },
	callback = function()
		vim.opt_local.textwidth = 80
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
		vim.opt_local.tabstop = 2
		vim.opt_local.softtabstop = 2
		vim.opt_local.shiftwidth = 2
		vim.opt_local.expandtab = true
	end,
})

-- add autosave
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
	callback = function()
		if vim.bo.modified and not vim.bo.readonly and vim.fn.expand("%") ~= "" and vim.bo.buftype == "" then
			vim.api.nvim_command("silent update")
		end
	end,
})

vim.filetype.add({
	extension = {
		templ = "templ",
	},
})

vim.api.nvim_create_augroup("HighlightYank", {})
vim.api.nvim_create_autocmd("TextYankPost", {
	group = "HighlightYank",
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({
			higroup = "IncSearch",
			timeout = 40,
		})
	end,
})

-- oil fix relative path
vim.api.nvim_create_augroup("OilRelPathFix", {})
vim.api.nvim_create_autocmd("BufLeave", {
	group = "OilRelPathFix",
	pattern = "oil:///*",
	callback = function()
		vim.cmd("cd .")
	end,
})

vim.api.nvim_create_augroup("StringReplacer", {})
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
	group = "StringReplacer",
	pattern = "*",
	command = [[%s/\s\+$//e]],
})

