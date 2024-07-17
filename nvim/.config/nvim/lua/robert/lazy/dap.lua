return {
    "mfussenegger/nvim-dap",
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    "leoluz/nvim-dap-go",

    dependencies = {
        "nvim-neotest/nvim-nio"
    },
    config = function ()
        vim.fn.sign_define('DapBreakpoint', { text='🔴', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl='DapBreakpoint' })
        vim.keymap.set("n", "<leader>dt", ":DapUiToggle<CR>", {noremap=true})
        vim.keymap.set("n", "<leader>db", ":DapToggleBreakpoint<CR>", {noremap=true})
        vim.keymap.set("n", "<leader>dc", ":DapContinue<CR>", {noremap=true})
        vim.keymap.set("n", "<leader>dr", ":lua require('dapui').open({reset = true})<CR>", {noremap=true})
    end
}
