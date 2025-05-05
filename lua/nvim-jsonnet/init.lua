local Buffer = require('nvim-jsonnet.buffer')
local job = require('nvim-jsonnet.job')
local utils = require('nvim-jsonnet.utils')

--- A custom filetype, mapped to `json`, used by `edgy.nvim` to manage the
--- output buffer.
local filetype = 'jsonnet-output'

--- @class nvim-jsonnet
--- @field did_setup boolean Indicates if the plugin has been set up
--- @field output_buffer? nvim-jsonnet.Buffer The reusable output buffer for jsonnet evaluation
--- @field options nvim-jsonnet.Config The configuration options for the plugin
local M = {
    did_setup = false,
    output_buffer = nil,
}

--- Set key mappings
---@param mappings nvim-jsonnet.config.KeyMappingGroup The mappings to set
local function apply_mappings(mappings)
    if not M.options.setup_mappings then
        return
    end

    for _, mapping_config in pairs(mappings) do
        if not mapping_config.enabled then
            goto continue
        end

        local cmd = type(mapping_config.cmd) == 'function' and function()
            mapping_config.cmd(M)
        end or mapping_config.cmd

        vim.keymap.set(
            mapping_config.mode,
            M.options.key_prefix .. mapping_config.key,
            cmd,
            { desc = mapping_config.desc, silent = true, noremap = true, buffer = true }
        )

        ::continue::
    end
end

--- Get the current buffer's filepath
--- @return string path, string dir
local function get_buffer_path()
    local bufname = vim.api.nvim_buf_get_name(0)
    local path = vim.fn.fnamemodify(bufname, ':p')
    local dir = vim.fn.fnamemodify(path, ':h')
    return path, dir
end

--- Initialise the output buffer if not already created
local function ensure_output_buffer()
    if M.output_buffer then
        return
    end

    local how_to_close = {
        'Perform any movement',
    }

    if M.options.setup_mappings and M.options.output_keys.close.enabled then
        table.insert(how_to_close, 'press ' .. M.options.key_prefix .. M.options.output_keys.close.key)
    end

    local close_message = table.concat(how_to_close, ' or ') .. ' to close this buffer'

    M.output_buffer = Buffer.new('jsonnet-output', close_message, function(buf)
        M.output_buffer = buf
    end)
end

-- Run the given jsonnet command and output to our shared buffer
local function run_jsonnet(jsonnet, args, ft)
    ensure_output_buffer()

    -- Get file path and directory
    local path, dir = get_buffer_path()

    -- Build command arguments
    local args_copy = vim.deepcopy(args)
    table.insert(args_copy, path)

    -- Open output buffer and run command
    M.output_buffer:run_command(jsonnet, args_copy, dir, ft, M.options.window, M.options.return_focus)
end

-- Evaluate the current buffer as Jsonnet
local function eval_jsonnet()
    run_jsonnet(M.options.jsonnet_bin, M.options.jsonnet_args, filetype)
end

-- Evaluate the current buffer as Jsonnet string
local function eval_jsonnet_string()
    run_jsonnet(M.options.jsonnet_string_bin, M.options.jsonnet_string_args, 'text')
end

-- Format the current buffer using jsonnetfmt
local function format_jsonnet()
    vim.cmd('!jsonnetfmt %')
end

local function do_setup(options)
    if M.did_setup then
        return
    end

    M.did_setup = true

    -- Merge user options with defaults
    M.options = vim.tbl_deep_extend('force', {}, require('nvim-jsonnet.config'), options or {})

    if M.options.use_tanka_if_possible then
        -- Use Tanka if `tk tool jpath` works.
        local result = job.system({ 'tk', 'tool', 'jpath', vim.fn.expand('%') })
        if result.code == 0 then
            M.options.jsonnet_bin = 'tk'
            M.options.jsonnet_args = { 'eval' }
        end
    end

    M.eval_jsonnet = eval_jsonnet
    M.eval_jsonnet_string = eval_jsonnet_string
    M.format_jsonnet = format_jsonnet

    -- Create user commands
    vim.api.nvim_create_user_command('JsonnetPrintConfig', function()
        print(vim.inspect(M.options))
    end, { desc = 'Print Jsonnet plugin configuration' })

    vim.api.nvim_create_user_command('JsonnetEval', eval_jsonnet, { nargs = '?', desc = 'Evaluate Jsonnet file' })

    vim.api.nvim_create_user_command(
        'JsonnetEvalString',
        eval_jsonnet_string,
        { nargs = '?', desc = 'Evaluate Jsonnet file as string' }
    )

    vim.api.nvim_create_user_command('JsonnetFormat', format_jsonnet, { desc = 'Format Jsonnet file' })

    vim.api.nvim_create_user_command('JsonnetToggle', function()
        ensure_output_buffer()
        M.output_buffer:toggle(M.options.window)
    end, { desc = 'Toggle Jsonnet output buffer' })

    -- Set up LSP if requested
    local hasLspconfig, lspconfig = pcall(require, 'lspconfig')
    if M.options.load_lsp_config and hasLspconfig then
        lspconfig.jsonnet_ls.setup({
            capabilities = M.options.capabilities,
            settings = {
                formatting = {
                    UseImplicitPlus = utils.stringtoboolean[os.getenv('JSONNET_IMPLICIT_PLUS')] or false,
                },
            },
        })
    end

    -- Set up DAP if requested
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

    -- Register type with treesitter, for `edgy.nvim` support
    vim.treesitter.language.register('json', filetype)
end

M.setup = function(options)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'jsonnet' },
        callback = function(_)
            do_setup(options)

            apply_mappings(M.options.keys)
            apply_mappings(M.options.output_keys)
        end,
    })

    vim.api.nvim_create_autocmd('FileType', {
        pattern = { filetype },
        callback = function(_)
            apply_mappings(M.options.output_keys)
        end,
    })
end

return M
