return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local treesitter = require("nvim-treesitter")
        treesitter.setup({})
        local parsers = {
            "vimdoc", "javascript", "typescript", "c", "cpp",
            "lua", "rust", "jsdoc", "bash", "dockerfile",
        }

        local installing = {}
        for _, lang in ipairs(parsers) do
            installing[lang] = {}
        end
        local function enable(buf, lang)
            if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
                return
            end
            if vim.treesitter.language.get_lang(vim.bo[buf].filetype) ~= lang then
                return
            end
            if pcall(vim.treesitter.start, buf, lang) then
                vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                -- Keep regex syntax alongside Tree-sitter for Markdown.
                if vim.bo[buf].filetype == "markdown" then
                    vim.bo[buf].syntax = "markdown"
                end
            end
        end

        treesitter.install(parsers):await(function(err, success)
            vim.schedule(function()
                for _, lang in ipairs(parsers) do
                    local buffers = installing[lang]
                    installing[lang] = nil
                    if not err then
                        for buf in pairs(buffers) do
                            enable(buf, lang)
                        end
                    end
                end
            end)
        end)

        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("TreesitterFeatures", { clear = true }),
            callback = function(event)
                local buf = event.buf
                local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
                if not lang or vim.bo[buf].buftype ~= "" then
                    return
                end
                if pcall(vim.treesitter.language.add, lang) then
                    enable(buf, lang)
                elseif require("nvim-treesitter.parsers")[lang] then
                    -- Share one install among buffers requesting the same parser.
                    if installing[lang] then
                        installing[lang][buf] = true
                        return
                    end
                    installing[lang] = { [buf] = true }
                    treesitter.install({ lang }):await(function(err, success)
                        vim.schedule(function()
                            local buffers = installing[lang]
                            installing[lang] = nil
                            if not err and success then
                                for waiting_buf in pairs(buffers) do
                                    enable(waiting_buf, lang)
                                end
                            end
                        end)
                    end)
                end
            end,
        })
    end,
}
