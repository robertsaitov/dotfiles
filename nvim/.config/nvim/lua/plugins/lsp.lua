return {
	"neovim/nvim-lspconfig",
	lazy = true,
	event = { "BufReadPre", "BufNewFile", "BufWritePost" },
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"nvimtools/none-ls.nvim",
		"jay-babu/mason-null-ls.nvim",
		"MunifTanjim/prettier.nvim",
        "saghen/blink.cmp",
		-- "hrsh7th/cmp-nvim-lsp",
		-- "hrsh7th/cmp-buffer",
		-- "hrsh7th/cmp-path",
		-- "hrsh7th/cmp-cmdline",
		-- "hrsh7th/nvim-cmp",
		"j-hui/fidget.nvim",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},

	config = function()
		-- local cmp = require("cmp")
		-- local cmp_lsp = require("cmp_nvim_lsp")
		-- local capabilities = vim.tbl_deep_extend(
		-- 	"force",
		-- 	{},
		-- 	vim.lsp.protocol.make_client_capabilities(),
		-- 	cmp_lsp.default_capabilities()
		-- )

		local mason_null_ls = require("mason-null-ls")

		local null_ls = require("null-ls")

		local null_ls_utils = require("null-ls.utils")

		mason_null_ls.setup({
			ensure_installed = {
				"prettier", -- prettier formatter
				"stylua", -- lua formatter
				"black", -- python formatter
				"mypy", -- static type checking
				"isort", -- python imports sort
				"eslint_d", -- js linter
				"jq", -- json formatter
			},
		})

		-- configure null_ls
		null_ls.setup({
			-- add package.json as identifier for root (for typescript monorepos)
			root_dir = null_ls_utils.root_pattern(
				".null-ls-root",
				"lazy-lock.json",
				"Makefile",
				".git",
				"package.json"
			),
		})

		require("fidget").setup({})
		require("mason").setup()
        local capabilities = require('blink.cmp').get_lsp_capabilities()
		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
				"rust_analyzer",
				"vtsls",
				"html",
				"cssls",
				"jedi_language_server", -- python
				"clangd",
				"ansiblels",
				"angularls",
				"cmake",
				"bashls",
				"jsonls",
			},
			handlers = {
				function(server_name) -- default handler (optional)
					require("lspconfig")[server_name].setup({
						capabilities = capabilities,
					})
				end,

				["lua_ls"] = function()
					local lspconfig = require("lspconfig")
					lspconfig.lua_ls.setup({
						capabilities = capabilities,
						settings = {
							Lua = {
								diagnostics = {
									globals = { "vim", "it", "describe", "before_each", "after_each" },
								},
							},
						},
					})
				end,
			},
			automatic_installation = true,
		})

		-- local cmp_select = { behavior = cmp.SelectBehavior.Select }
		--
		-- -- path completion
		-- cmp.setup({
		-- 	sources = {
		-- 		{ name = "path" },
		-- 	},
		-- })
		--
		-- cmp.setup.cmdline("/", {
		-- 	mapping = cmp.mapping.preset.cmdline(),
		-- 	sources = {
		-- 		{ name = "buffer" },
		-- 	},
		-- })
		--
		-- -- `:` cmdline setup.
		-- cmp.setup.cmdline(":", {
		-- 	mapping = cmp.mapping.preset.cmdline(),
		-- 	sources = cmp.config.sources({
		-- 		{ name = "path" },
		-- 	}, {
		-- 		{
		-- 			name = "cmdline",
		-- 			option = {
		-- 				ignore_cmds = { "Man", "!" },
		-- 			},
		-- 		},
		-- 	}),
		-- })
		-- cmp.setup({
		-- 	mapping = cmp.mapping.preset.insert({
		-- 		["<C-l>"] = cmp.mapping.select_prev_item(cmp_select),
		-- 		["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
		-- 		["<C-y>"] = cmp.mapping.confirm({
		-- 			behavior = cmp.ConfirmBehavior.Replace,
		-- 			select = true,
		-- 		}),
		-- 		["<C-Space>"] = cmp.mapping.complete(),
		-- 	}),
		-- 	sources = cmp.config.sources({
		-- 		{ name = "nvim_lsp" },
		-- 	}, {
		-- 		{ name = "buffer" },
		-- 	}),
		-- })

		local function quickfix()
			vim.lsp.buf.code_action({
				filter = function(a)
					return a.isPreferred
				end,
				apply = true,
			})
		end

		vim.keymap.set("n", "<leader>qf", quickfix, { noremap = true, silent = true })
		vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end)
		vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end)
		vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end)
		vim.keymap.set("n", "<leader>e", function() vim.diagnostic.open_float() end)
		vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end)
		vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end)
		vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end)
		vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end)
		vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end)
		vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end)

		vim.diagnostic.config({
			-- update_in_insert = true,
			float = {
				focusable = false,
				style = "minimal",
				border = "rounded",
				source = "always",
				header = "",
				prefix = "",
			},
		})
	end,
}
