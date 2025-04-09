local utils = require('nvim-jsonnet.utils')
local stringtoboolean = { ['true'] = true, ['false'] = false }

local M = {
    did_setup = false,
}

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

    -- A prefix prepended to all key mappings
    key_prefix = '<leader>',

    -- Keymap configuration. Each key can be individually overridden. Each binding
    -- will have `key_prefix` prepended.
    keys = {
        eval = {
            key = 'j',
            desc = 'Evaluate Jsonnet file',
            mode = 'n',
            cmd = '<cmd>JsonnetEval<cr>',
            enabled = true,
        },
        eval_string = {
            key = 'k',
            desc = 'Evaluate Jsonnet file as string',
            mode = 'n',
            cmd = '<cmd>JsonnetEvalString<cr>',
            enabled = true,
        },
        format = {
            key = 'l',
            desc = 'Format Jsonnet file',
            mode = 'n',
            cmd = '<cmd>!jsonnetfmt %<cr>',
            enabled = true,
        },
    },

    -- Set to false to disable all default key mappings
    setup_mappings = true,
}

local function apply_mappings()
    if not M.options.setup_mappings then
        return
    end

    for _, mapping_config in pairs(M.options.keys) do
        if mapping_config.enabled then
            vim.keymap.set(
                mapping_config.mode,
                M.options.key_prefix .. mapping_config.key,
                mapping_config.cmd,
                { desc = mapping_config.desc, silent = true, noremap = true }
            )
        end
    end
end

local function eval_jsonnet(opts)
    utils.RunCommand(M.options.jsonnet_bin, M.options.jsonnet_args, 'json', opts)
end

local function eval_jsonnet_string(opts)
    utils.RunCommand(M.options.jsonnet_string_bin, M.options.jsonnet_string_args, '', opts)
end

local function format_jsonnet()
    vim.cmd('!jsonnetfmt %')
end

local function do_setup(options)
    if M.did_setup then
        return
    end

    M.did_setup = true

    -- Merge user options with defaults
    M.options = vim.tbl_deep_extend('force', {}, defaults, options or {})

    if M.options.use_tanka_if_possible then
        -- Use Tanka if `tk tool jpath` works.
        local _ = vim.fn.system('tk tool jpath ' .. vim.fn.shellescape(vim.fn.expand('%')))
        if vim.api.nvim_get_vvar('shell_error') == 0 then
            M.options.jsonnet_bin = 'tk'
            M.options.jsonnet_args = { 'eval' }
        end
    end

    M.eval_jsonnet = eval_jsonnet
    M.eval_jsonnet_string = eval_jsonnet_string
    M.format_jsonnet = format_jsonnet

    vim.api.nvim_create_user_command('JsonnetPrintConfig', function()
        print(vim.inspect(M.options))
    end, { desc = 'Print Jsonnet plugin configuration' })

    vim.api.nvim_create_user_command('JsonnetEval', function(opts)
        M.eval_jsonnet(opts)
    end, { nargs = '?', desc = 'Evaluate Jsonnet file' })

    vim.api.nvim_create_user_command('JsonnetEvalString', function(opts)
        M.eval_jsonnet_string(opts)
    end, { nargs = '?', desc = 'Evaluate Jsonnet file as string' })

    vim.api.nvim_create_user_command('JsonnetFormat', function()
        M.format_jsonnet()
    end, { desc = 'Format Jsonnet file' })

    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'jsonnet' },
        callback = apply_mappings,
    })

    local hasLspconfig, lspconfig = pcall(require, 'lspconfig')
    if M.options.load_lsp_config and hasLspconfig then
        lspconfig.jsonnet_ls.setup({
            capabilities = M.options.capabilities,
            settings = {
                formatting = {
                    UseImplicitPlus = stringtoboolean[os.getenv('JSONNET_IMPLICIT_PLUS')] or false,
                },
            },
        })
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
            },
        }
    end
end

M.setup = function(options)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'jsonnet' },
        callback = function(_)
            do_setup(options)

            apply_mappings()

            -- Set folding options
            vim.opt_local.foldlevelstart = 1
        end,
    })
end

return M
