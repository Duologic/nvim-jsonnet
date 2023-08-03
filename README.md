# nvim-jsonnet

Provide functions to evaluate Jsonnet code inside a split view.

## Usage

```lua
require('nvim-jsonnet').setup({
    -- Opinionated defaults
    jsonnet_bin = 'jsonnet',
    jsonnet_args = { '-J', 'vendor', '-J', 'lib' },
    jsonnet_string_bin = 'jsonnet',
    jsonnet_string_args = { '-S', '-J', 'vendor', '-J', 'lib' },
    use_tanka_if_possible = true
})
```

If the environment variable `JSONNET_BIN` is set, it will use that instead of the configured values. This allows us to override the binary at a project level.

When `use_tanka_if_possible`, it will check whether Tanka can resolve the JPATH and attempt to use `tk eval` instead of configured values.

By default, `:JsonnetEval` will open in a horizontal split, use `:vertical JsonnetEval` to launch the split vertically.

## Differences from vim-jsonnet

This plugin does not provide syntax highlighting, folding, formatting or linting. Please rely on LSP, Treesitter and other plugins to aid with this.

### LSP Config

LSP with jsonnet-language-server provides formatting and linting out of the box, this config uses [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig/):

```lua
require('lspconfig').jsonnet_ls.setup({
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    flags = {
        debounce_text_changes = 150,
    },
    cmd = { 'jsonnet-language-server', '--lint' }, -- Linting can be noisy
    settings = {
        formatting = {
            UseImplicitPlus = true, -- Recommended but might conflict with project-level jsonnetfmt settings
        }
    }
})

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

### null-ls/cbfmt
 For formatting code blocks inside Markdown you can use null-ls with `cbfmt`.

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

### Treesitter

Treesitter provides better highlighting and folding capabilities, this config uses [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter):

> *NOTE*
>
> I'm currently relying on my [own fork](https://github.com/Duologic/tree-sitter-jsonnet) awaiting upstream pull requests.
>
> The queries that currently ship with `nvim-treesitter` do not work with this fork, you might want to temporarily remove the queries in nvim-treesitter to avoid the conflict. This plugin contains queries in `after/queries/` that work with the fork.

```lua
local parser_config = require 'nvim-treesitter.parsers'.get_parser_configs()
parser_config.jsonnet = {
    install_info = {
        url = 'https://github.com/Duologic/tree-sitter-jsonnet',
        branch = 'fork'
        files = { 'src/parser.c', 'src/scanner.c' },
        -- Generate parser locally for the time being
        generate_requires_npm = true,
        requires_generate_from_grammar = true,
    },
}

require 'nvim-treesitter'.setup()
require 'nvim-treesitter.configs'.setup({
    highlight = { enable = true },
})

vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.wo.foldlevel  = 1000
```
