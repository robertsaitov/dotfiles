return {
    "mfussenegger/nvim-dap",
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    "leoluz/nvim-dap-go",

    dependencies = {
        "mxsdev/nvim-dap-vscode-js",
        "nvim-neotest/nvim-nio"
    },
    config = function ()
        require("dapui").setup()
        local dap, dapui = require("dap"), require("dapui")
        vim.fn.sign_define('DapBreakpoint', { text='🔴', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl='DapBreakpoint' })
        vim.keymap.set("n", "<leader>dt", ":DapUiToggle<CR>", {noremap=true})
        vim.keymap.set("n", "<leader>db", ":DapToggleBreakpoint<CR>", {noremap=true})
        vim.keymap.set("n", "<leader>dc", ":DapContinue<CR>", {noremap=true})
        vim.keymap.set("n", "<leader>dr", ":lua require('dapui').open({reset = true})<CR>", {noremap=true})
        dap.listeners.before.attach.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
        end
        require("dap-vscode-js").setup({
           debugger_path = vim.fn.stdpath('data') .. "/lazy/vscode-js-debug",
           adapters = { 'chrome', 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost', 'node', 'chrome' },
        })
        local js_based_languages = { "typescript", "javascript", "typescriptreact" }

        for _, language in ipairs(js_based_languages) do
            dap.configurations[language] = {
                {
                  type = "pwa-node",
                  request = "launch",
                  name = "Launch file",
                  program = "${file}",
                  cwd = "${workspaceFolder}",
                },
                {
                  type = "pwa-node",
                  request = "attach",
                  name = "Attach",
                  processId = require 'dap.utils'.pick_process,
                  cwd = "${workspaceFolder}",
                },
                {
                  type = "pwa-chrome",
                  request = "launch",
                  name = "Start Chrome with \"localhost\"",
                  url = "http://localhost:3000",
                  webRoot = "${workspaceFolder}",
                  userDataDir = "${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir"
                }
            }
        end
    end
}
