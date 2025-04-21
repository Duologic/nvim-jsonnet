# nvim-jsonnet

Features:
* Provide functions to evaluate Jsonnet code inside a split view
* Extend nvim-treesitter highlighting with references and linting

## Usage

```lua
require('nvim-jsonnet').setup({
    -- Opinionated defaults
    jsonnet_bin = 'jsonnet',
    jsonnet_args = { '-J', 'vendor', '-J', 'lib' },
    jsonnet_string_bin = 'jsonnet',
    jsonnet_string_args = { '-S', '-J', 'vendor', '-J', 'lib' },
    use_tanka_if_possible = true

    -- default to false to not break existing installs
    load_lsp_config = false
    -- Pass along nvim-cmp capabilities if you use that.
    capabilities = require('cmp_nvim_lsp').default_capabilities(),

    -- default to false to not break existing installs
    load_dap_config = false,
    jsonnet_debugger_bin = 'jsonnet-debugger',
    jsonnet_debugger_args = { '-s', '-d', '-J', 'vendor', '-J', 'lib' },
})
```

If the environment variable `JSONNET_BIN` is set, it will use that instead of the configured values. This allows us to override the binary at a project level.

When `use_tanka_if_possible`, it will check whether Tanka can resolve the JPATH and attempt to use `tk eval` instead of configured values.

By default, `:JsonnetEval` will open in a horizontal split, use `:vertical JsonnetEval` to launch the split vertically.

## Differences from vim-jsonnet

This plugin does not provide syntax highlighting, folding, formatting or linting. Please rely on LSP, Treesitter and other plugins to aid with this.

You should not install both `vim-jsonnet` and this plugin, since they both provide the `JsonnetEval` command.

### LSP Config

LSP with jsonnet-language-server provides formatting and linting out of the box, this config uses [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig/).

See [Usage](#Usage) to enable opinionated setup.

Tip: configure format on save for all LSP buffers:
```lua
-- Format on save
vim.api.nvim_create_autocmd(
    'BufWritePre',
    {
        buffer = buffer,
        callback = function()
            vim.lsp.buf.format { async = false }
        end
    }
)
```

### DAP

[nvim-dap](https://github.com/mfussenegger/nvim-dap) provides a way to run the [jsonnet-debugger](https://github.com/grafana/jsonnet-debugger), this works great in combination with [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui).

Install the debugger with `go install github.com/grafana/jsonnet-debugger@v0.1.0` and see [Usage](#Usage) to enable.

### Treesitter

Treesitter provides better highlighting and folding capabilities, this config uses [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter).

Minimal configuration:

```lua
require 'nvim-treesitter'.setup()
require 'nvim-treesitter.configs'.setup({
    highlight = { enable = true },
})

vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.wo.foldlevel  = 1000
```

### null-ls/cbfmt

For formatting code blocks inside Markdown you can use null-ls with `cbfmt`.

TODO: null-ls has been archived, look for replacement.

```lua
local null_ls = require('null-ls')

local function getFileType()
    local ft = vim.bo.filetype
    for index, value in ipairs({ 'markdown', 'org', 'restructuredtext' }) do
        if value == ft then
            return ft
        end
    end
    return 'markdown' -- fallback
end

null_ls.setup({
    sources = {
        null_ls.builtins.formatting.cbfmt.with({
            filetypes = { 'markdown', 'org', 'restructuredtext' },
            extra_args = {
                '--config', vim.fn.expand('~/.config/nvim/cbfmt.toml'),
                '--parser', getFileType(),
            }
        }),
    },
})
```

```toml
# ~/.config/nvim/cbfmt.toml
[languages]
jsonnet = ["jsonnetfmt --no-use-implicit-plus -"]
```
