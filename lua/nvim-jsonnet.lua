local utils = require('jsonnet.utils')

local M = {}

local defaults = {
    jsonnet_bin = 'jsonnet',
    jsonnet_args = { '-J', 'vendor', '-J', 'lib' },
    jsonnet_string_bin = 'jsonnet',
    jsonnet_string_args = { '-S', '-J', 'vendor', '-J', 'lib' },
    use_tanka_if_possible = true
}

M.setup = function(options)
    M.options = vim.tbl_deep_extend('force', {}, defaults, options or {})

    if os.getenv('JSONNET_BIN') ~= nil and os.getenv('JSONNET_BIN') ~= '' then
        M.options.jsonnet_bin = os.getenv('JSONNET_BIN')
        M.options.jsonnet_string_bin = os.getenv('JSONNET_BIN')
    end

    if M.options.use_tanka_if_possible then
        -- Use Tanka if `tk tool jpath` works.
        local _ = vim.fn.system('tk tool jpath ' .. vim.fn.shellescape(vim.fn.expand('%')))
        if vim.api.nvim_get_vvar('shell_error') == 0 then
            M.options.jsonnet_bin = 'tk'
            M.options.jsonnet_args = { 'eval' }
        end
    end

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
                vim.opt_local.foldlevelstart = 1
            end,
        })
end

return M
