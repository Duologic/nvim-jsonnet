function table.shallow_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

local function getBuffer(name, filetype, opts)
    local bufnr = vim.fn.bufnr(name)
    if bufnr == -1 then
        bufnr = vim.fn.bufadd(name)
        vim.fn.win_execute(vim.fn.win_getid(1), string.format('%s sbuffer %d', opts.mods, bufnr))
        vim.api.nvim_buf_set_option(bufnr, 'buflisted', false)
        vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
        vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
        vim.api.nvim_buf_set_option(bufnr, 'filetype', filetype or '')
    end
    return bufnr
end

local function runJob(cmd, args, filetype, opts)
    local argsWithFile = table.shallow_copy(args)
    argsWithFile[#argsWithFile + 1] = vim.fn.expand('%')

    local ex = require('plenary.job'):new({
        command = cmd,
        args = argsWithFile,
        cwd = vim.loop.cwd(),
        enable_recording = true,
        enabled_recording = true,
    })

    local stdout, code = ex:sync()

    if code ~= 0 then
        local stderr = ex:stderr_result()
        vim.notify(
            ('cmd (%q) failed:\n%s'):format(cmd, vim.inspect(stderr)),
            vim.log.levels.WARN
        )
        return
    end

    local bufnr = getBuffer(cmd .. ' ' .. table.concat(args, ' '), filetype, opts)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, stdout)
end

return {
    RunCommand = runJob,
}
