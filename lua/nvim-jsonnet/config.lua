local utils = require('nvim-jsonnet.utils')

---@alias nvim-jsonnet.config.Layout 'vertical'|'horizontal'|'float'|'replace'

---@class nvim-jsonnet.config.KeyMapping
---@field key string The key sequence (e.g., 'j', '<leader>j')
---@field filetype? string|table<string> Filetype(s) for the mapping
---@field desc string Description shown in help/which-key
---@field mode 'n'|'v'|'i'|'x' The mode(s) for the mapping
---@field cmd string|fun(nvim_jsonnet: nvim-jsonnet) The command string or Lua function to execute
---@field enabled boolean Whether the mapping is enabled

---@class nvim-jsonnet.config.KeyMappingGroup: table<string, nvim-jsonnet.config.KeyMapping>

---@class nvim-jsonnet.config.KeysConfig: nvim-jsonnet.config.KeyMappingGroup
---@field eval? nvim-jsonnet.config.KeyMapping Mapping for evaluation
---@field eval_string? nvim-jsonnet.config.KeyMapping Mapping for string evaluation
---@field format? nvim-jsonnet.config.KeyMapping Mapping for formatting

---@class nvim-jsonnet.config.OutputKeysConfig: nvim-jsonnet.config.KeyMappingGroup
---@field toggle_output? nvim-jsonnet.config.KeyMapping Mapping for toggling output
---@field close? nvim-jsonnet.config.KeyMapping Mapping for closing output buffer

---@class nvim-jsonnet.Config.Window
---@field layout nvim-jsonnet.config.Layout|fun():string Layout mode of the output window
---@field width number Fractional width (when <= 1) or absolute columns (when > 1)
---@field height number Fractional height (when <= 1) or absolute rows (when > 1)
---@field relative 'editor'|'win'|'cursor'|'mouse' Position relative to (floating windows only)
---@field border 'none'|'single'|'double'|'rounded'|'solid'|'shadow' Window border style (floating windows only)
---@field row? number Row position of the window, centered by default (floating windows only)
---@field col? number Column position of the window, centered by default (floating windows only)
---@field title? string Title of the output window (floating windows only)
---@field footer? string Footer of the output window (floating windows only)
---@field zindex? number Z-index for floating windows (floating windows only)

---@class nvim-jsonnet.Config
---@field jsonnet_bin string Path to jsonnet executable
---@field jsonnet_args string[] Arguments for jsonnet command
---@field jsonnet_string_bin string Path to jsonnet executable for string output
---@field jsonnet_string_args string[] Arguments for jsonnet string command
---@field use_tanka_if_possible boolean Whether to use Tanka if available
---@field load_lsp_config boolean Whether to load LSP configuration
---@field capabilities table LSP capabilities
---@field load_dap_config boolean Whether to load DAP configuration
---@field jsonnet_debugger_bin string Path to jsonnet debugger executable
---@field jsonnet_debugger_args string[] Arguments for jsonnet debugger
---@field output_filetype string Filetype for the output buffer
---@field return_focus boolean Whether to return focus to source window after evaluation
---@field show_errors_in_buffer boolean Whether to show errors in the output buffer (true) or as notifications (false)
---@field key_prefix string Prefix for key mappings
---@field keys? nvim-jsonnet.config.KeysConfig Key mapping configuration
---@field output_keys? nvim-jsonnet.config.OutputKeysConfig Key mapping configuration for jsonnet and the output buffer
---@field setup_mappings boolean Whether to set up mappings automatically
---@field window? nvim-jsonnet.Config.Window Window configuration options

---@type nvim-jsonnet.Config
local config = {
    jsonnet_bin = os.getenv('JSONNET_BIN') or 'jsonnet',
    jsonnet_args = { '-J', 'vendor', '-J', 'lib' },
    jsonnet_string_bin = os.getenv('JSONNET_BIN') or 'jsonnet',
    jsonnet_string_args = { '-S', '-J', 'vendor', '-J', 'lib' },
    use_tanka_if_possible = utils.stringtoboolean[os.getenv('NVIM_JSONNET_USE_TANKA') or 'true'],

    load_lsp_config = false,
    capabilities = vim.lsp.protocol.make_client_capabilities(),

    load_dap_config = false,
    jsonnet_debugger_bin = 'jsonnet-debugger',
    jsonnet_debugger_args = { '-s', '-d', '-J', 'vendor', '-J', 'lib' },

    output_filetype = 'json', -- Default output filetype for evaluation
    return_focus = true, -- Whether to return focus to source window after evaluation
    show_errors_in_buffer = false, -- Whether to show errors in buffer (true) or as notifications (false)

    -- A prefix prepended to all key mappings
    key_prefix = '<leader>',

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
            cmd = '<cmd>JsonnetFormat<cr>',
            enabled = true,
        },
    },

    -- These keybindings are active in both `jsonnet` files and also the output
    -- window
    output_keys = {
        toggle_output = {
            key = 'o',
            desc = 'Toggle Jsonnet output buffer',
            mode = 'n',
            cmd = '<cmd>JsonnetToggle<cr>',
            enabled = true,
        },
        close = {
            key = 'q',
            desc = 'Close Jsonnet output buffer',
            mode = 'n',
            cmd = function(nvim_jsonnet)
                if nvim_jsonnet.output_buffer == nil then
                    return
                end

                nvim_jsonnet.output_buffer:close()
            end,
            enabled = true,
        },
    },

    setup_mappings = true,

    window = {
        layout = 'vertical', -- 'vertical', 'horizontal', 'float', 'replace'
        width = 0.5, -- fractional width of parent, or absolute width in columns when > 1
        height = 0.5, -- fractional height of parent, or absolute height in rows when > 1
        -- Options below only apply to floating windows
        relative = 'editor', -- 'editor', 'win', 'cursor', 'mouse'
        border = 'single', -- 'none', 'single', 'double', 'rounded', 'solid', 'shadow'
        -- row = nil,
        -- col = nil,
        title = 'Jsonnet Output', -- title of output window
        -- footer = nil,
        zindex = 1, -- determines if window is on top or below other floating windows
    },
}

return config
