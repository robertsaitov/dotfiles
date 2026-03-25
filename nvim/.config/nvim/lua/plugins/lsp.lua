return {
	"neovim/nvim-lspconfig",
	lazy = true,
	event = { "BufReadPre", "BufNewFile", "BufWritePost" },
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"saghen/blink.cmp", -- autocomplete
		"j-hui/fidget.nvim", -- lsp loader messages
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},

	config = function()
		require("fidget").setup()
		require("mason").setup()
		require("blink.cmp").get_lsp_capabilities()
		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
				"rust_analyzer",
				"vtsls",
				"html",
				"cssls",
				"pyright",
				"clangd",
				"ansiblels",
				"bashls",
				"jsonls",
				"marksman",
			},
			automatic_installation = true,
		})

        -- ignore Fugitive buffers
		vim.lsp.start = (function()
			local old_lsp_start = vim.lsp.start
			return function(...)
				local opt = select(2, ...)
				if opt and opt.bufnr then
					if
						not vim.api.nvim_buf_is_valid(opt.bufnr)
						or vim.b[opt.bufnr].fugitive_type
						or vim.startswith(vim.api.nvim_buf_get_name(opt.bufnr), "fugitive://")
					then
						return
					end
				end
				old_lsp_start(...)
			end
		end)()

		vim.lsp.config("ansiblels", {
			filetypes = { "yaml", "yml", "yaml.ansible" },
			settings = {
				ansible = {
					executionEnvironment = {
						enabled = false,
					},
				},
			},
		})

		vim.lsp.config("basedpyright", {
			settings = {
				basedpyright = {
					analysis = {
						typeCheckingMode = "basic",
					},
				},
			},
		})

		vim.lsp.config("clangd", {
			filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto", "hpp" },
			cmd = {
				"clangd",
				"--clang-tidy",
				"--header-insertion=iwyu",
				"--background-index",
			},
			init_options = {
				fallbackFlags = { "--std=c++23" },
				usePlaceholders = true,
				completeUnimported = true,
				clangdFileStatus = true,
			},
		})

		vim.lsp.config("lua_ls", {
			settings = {
				Lua = {
					runtime = {
						version = "LuaJIT",
					},
					diagnostics = {
						globals = { "vim", "require", "it", "describe", "before_each", "after_each" },
					},
				},
			},
		})

		local function quickfix()
			vim.lsp.buf.code_action({
				filter = function(a)
					return a.isPreferred
				end,
				apply = true,
			})
		end

		vim.lsp.inlay_hint.enable(true, { 0 })
		vim.keymap.set("n", "<leader>qf", quickfix, { noremap = true, silent = true })
		vim.keymap.set("n", "gd", function()
			vim.lsp.buf.definition()
		end)
		vim.keymap.set("n", "K", function()
			vim.lsp.buf.hover()
		end)
		vim.keymap.set("n", "<leader>vws", function()
			vim.lsp.buf.workspace_symbol()
		end)
		vim.keymap.set("n", "<leader>e", function()
			vim.diagnostic.open_float()
		end)
		vim.keymap.set("n", "<leader>vca", function()
			vim.lsp.buf.code_action()
		end)
		vim.keymap.set("n", "<leader>vrr", function()
			vim.lsp.buf.references()
		end)
		vim.keymap.set("n", "<leader>vrn", function()
			vim.lsp.buf.rename()
		end)
		vim.keymap.set("i", "<C-h>", function()
			vim.lsp.buf.signature_help()
		end)
		vim.keymap.set("n", "[d", function()
			vim.diagnostic.goto_next()
		end)
		vim.keymap.set("n", "]d", function()
			vim.diagnostic.goto_prev()
		end)

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
