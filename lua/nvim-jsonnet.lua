local utils = require('jsonnet.utils')
local stringtoboolean = { ['true'] = true, ['false'] = false }

local M = {}

local defaults = {
    jsonnet_bin = os.getenv('JSONNET_BIN') or 'jsonnet',
    jsonnet_args = { '-J', 'vendor', '-J', 'lib' },
    jsonnet_string_bin = os.getenv('JSONNET_BIN') or 'jsonnet',
    jsonnet_string_args = { '-S', '-J', 'vendor', '-J', 'lib' },
    use_tanka_if_possible = stringtoboolean[os.getenv('NVIM_JSONNET_USE_TANKA') or 'true'],

    load_lsp_config = false,
    capabilities = vim.lsp.protocol.make_client_capabilities(),

    -- default to false to not break existing installs
    load_dap_config = false,
    jsonnet_debugger_bin = 'jsonnet-debugger',
    jsonnet_debugger_args = { '-s', '-d', '-J', 'vendor', '-J', 'lib' },
}

M.setup = function(options)
    M.options = vim.tbl_deep_extend('force', {}, defaults, options or {})

    if M.options.use_tanka_if_possible then
        -- Use Tanka if `tk tool jpath` works.
        local _ = vim.fn.system('tk tool jpath ' .. vim.fn.shellescape(vim.fn.expand('%')))
        if vim.api.nvim_get_vvar('shell_error') == 0 then
            M.options.jsonnet_bin = 'tk'
            M.options.jsonnet_args = { 'eval' }
        end
    end

    vim.api.nvim_create_user_command(
        'JsonnetPrintConfig',
        function()
            print(vim.inspect(M.options))
        end, {})

    vim.api.nvim_create_user_command(
        'JsonnetEval',
        function(opts)
            utils.RunCommand(M.options.jsonnet_bin, M.options.jsonnet_args, 'json', opts)
        end,
        { nargs = '?' })

    vim.api.nvim_create_user_command(
        'JsonnetEvalString',
        function(opts)
            utils.RunCommand(M.options.jsonnet_string_bin, M.options.jsonnet_string_args, '', opts)
        end,
        { nargs = '?' })

    vim.api.nvim_create_autocmd(
        'FileType',
        {
            pattern = { 'jsonnet' },
            callback = function()
                vim.keymap.set('n', '<leader>j', '<cmd>JsonnetEval<cr>')
                vim.keymap.set('n', '<leader>k', '<cmd>JsonnetEvalString<cr>')
                vim.keymap.set('n', '<leader>l', '<esc>:<\',\'>!jsonnetfmt -<cr>')
                vim.opt_local.foldlevelstart = 1
            end,
        })

    local hasLspconfig, lspconfig = pcall(require, 'lspconfig')
    if M.options.load_lsp_config and hasLspconfig then
        lspconfig.jsonnet_ls.setup {
            capabilities = M.options.capabilities,
            settings = {
                formatting = {
                    UseImplicitPlus = stringtoboolean[os.getenv('JSONNET_IMPLICIT_PLUS')] or false
                }
            }
        }
    end

    local hasDap, dap = pcall(require, 'dap')
    if M.options.load_dap_config and hasDap then
        dap.adapters.jsonnet = {
            type = 'executable',
            command = M.options.jsonnet_debugger_bin,
            args = M.options.jsonnet_debugger_args,
        }
        dap.configurations.jsonnet = {
            {
                type = 'jsonnet',
                request = 'launch',
                name = 'debug',
                program = '${file}',
            }
        }
    end
end

return M
