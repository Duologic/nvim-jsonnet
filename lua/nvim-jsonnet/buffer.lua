---@class nvim-jsonnet.Buffer
---@field augroup number? The ID of the autocmd group
---@field buffer_number number? Buffer number
---@field config nvim-jsonnet.Config|{} Configuration options
---@field layout string? Current layout mode
---@field name string Buffer name
---@field on_buf_create fun(buf: nvim-jsonnet.Buffer)? Function to call when buffer is created
---@field private help string Help message to display
---@field private job_id number? ID of the running job
---@field source_buffer_number number? Source buffer number
---@field source_window_number number? Source window number
local Buffer = {}
Buffer.__index = Buffer

--- Create a new buffer
---@param name string The buffer name
---@param help string Help message to display
---@param on_buf_create fun(buf: nvim-jsonnet.Buffer)? Function to call when buffer is created
---@return nvim-jsonnet.Buffer
function Buffer.new(name, help, on_buf_create)
    local self = setmetatable({}, Buffer)
    self.name = name
    self.help = help
    self.on_buf_create = on_buf_create
    self.layout = nil
    self.config = {}
    self.job_id = nil

    return self
end

--- Returns whether the buffer window is visible and its window number (if it is).
---@return number|nil The window number if visible, nil otherwise
function Buffer:visible()
    if not self:buf_valid() then
        return nil
    end

    -- Check if our buffer is visible in any window
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == self.buffer_number then
            return win
        end
    end

    return nil
end
---
--- Returns whether the buffer window is focused.
---@return boolean
function Buffer:focused()
    local window_number = self:visible()

    return window_number ~= nil and vim.api.nvim_get_current_win() == window_number
end

--- Check if the buffer is valid
---@return boolean
function Buffer:buf_valid()
    return self.buffer_number ~= nil
        and vim.api.nvim_buf_is_valid(self.buffer_number)
        and vim.api.nvim_buf_is_loaded(self.buffer_number)
end

--- Validate the buffer
function Buffer:validate()
    if self:buf_valid() then
        return
    end

    self.buffer_number = self:create()
    if self.on_buf_create ~= nil then
        self:on_buf_create()
    end
end

--- Create the buffer
---@return number Buffer number
function Buffer:create()
    local buffer_number = vim.api.nvim_create_buf(false, true)
    vim.bo[buffer_number].modifiable = false
    vim.api.nvim_buf_set_name(buffer_number, 'jsonnet-output://' .. self.name)

    -- Track buffer deletion, so we can abort any running jobs
    vim.api.nvim_create_autocmd('BufDelete', {
        buffer = buffer_number,
        callback = function()
            self:cancel_running_job()
            self.buffer_number = nil
        end,
        once = true,
    })

    return buffer_number
end

--- Setup autocmds to track source buffer visibility
function Buffer:setup_source_tracking()
    if not self.source_buffer_number then
        return
    end

    if self.augroup ~= nil then
        pcall(function()
            vim.api.nvim_del_augroup_by_id(self.augroup)
        end)
    end

    self.augroup = vim.api.nvim_create_augroup('JsonnetAutoclose_' .. self.buffer_number, { clear = true })

    vim.api.nvim_create_autocmd({ 'BufWinLeave', 'BufWinEnter', 'WinClosed', 'WinEnter', 'WinLeave' }, {
        group = self.augroup,
        callback = function()
            -- Check if source buffer is visible
            local source_visible = false
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == self.source_buffer_number then
                    source_visible = true
                    break
                end
            end

            if source_visible then
                return
            end

            -- If source is not visible in any window, close the output
            self:close()
        end,
    })
end

--- Clean up any autocmds we created
function Buffer:cleanup_source_tracking()
    if self.augroup == nil then
        return
    end

    pcall(function()
        vim.api.nvim_del_augroup_by_id(self.augroup)
    end)
    self.augroup = nil
end

--- Setup floating window behavior for this buffer
---@param width number The window width
---@param height number The window height
---@param window nvim-jsonnet.Config.Window Window configuration
function Buffer:setup_float(width, height, window)
    local win_opts = {
        style = 'minimal',
        width = width,
        height = height,
        zindex = window.zindex,
        relative = window.relative,
        border = window.border,
        title = window.title,
        row = window.row or math.floor((vim.o.lines - height) / 2),
        col = window.col or math.floor((vim.o.columns - width) / 2),
        footer = self.help,
    }

    local window_number = vim.api.nvim_open_win(self.buffer_number, false, win_opts)
    vim.api.nvim_set_option_value('winblend', 10, { win = window_number })
    vim.api.nvim_set_option_value('winhl', 'Normal:FloatWindow', { win = window_number })

    local float_augroup = vim.api.nvim_create_augroup('FloatWindowBehaviour_' .. self.buffer_number, { clear = true })

    -- Close the window on any cursor movement outside the float
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'WinClosed' }, {
        group = float_augroup,
        callback = function()
            -- Only close if we're not in the floating window
            if self:focused() then
                return
            end

            self:close()

            pcall(vim.api.nvim_del_augroup_by_id, float_augroup)
        end,
    })

    -- Or when the float is explicitly closed
    vim.api.nvim_create_autocmd('BufLeave', {
        group = float_augroup,
        buffer = self.buffer_number,
        callback = function()
            self:close()

            pcall(vim.api.nvim_del_augroup_by_id, float_augroup)
        end,
    })
end

--- Setup vertical split window for this buffer
---@param width number The window width
function Buffer:setup_vertical(width)
    local orig = vim.api.nvim_get_current_win()
    local cmd = 'vsplit'
    if width ~= 0 then
        cmd = width .. cmd
    end
    if vim.api.nvim_get_option_value('splitright', {}) then
        cmd = 'botright ' .. cmd
    else
        cmd = 'topleft ' .. cmd
    end
    vim.cmd(cmd)

    local window_number = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(window_number, self.buffer_number)

    vim.api.nvim_set_current_win(orig)
end

--- Setup horizontal split window for this buffer
---@param height number The window height
function Buffer:setup_horizontal(height)
    local orig = vim.api.nvim_get_current_win()
    local cmd = 'split'
    if height ~= 0 then
        cmd = height .. cmd
    end
    if vim.api.nvim_get_option_value('splitbelow', {}) then
        cmd = 'botright ' .. cmd
    else
        cmd = 'topleft ' .. cmd
    end
    vim.cmd(cmd)

    local window_number = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(window_number, self.buffer_number)

    vim.api.nvim_set_current_win(orig)
end

--- Setup common window options
function Buffer:setup_window_options()
    local window_number = self:visible()

    if not window_number or not vim.api.nvim_win_is_valid(window_number) then
        return
    end

    vim.wo[window_number].wrap = true
    vim.wo[window_number].linebreak = true
    vim.wo[window_number].cursorline = true
    vim.wo[window_number].conceallevel = 2
    vim.wo[window_number].foldlevel = 99
end

--- Open the buffer window.
---@param window nvim-jsonnet.Config.Window Config options for the output window
function Buffer:open(window)
    self:validate()

    local layout = window.layout
    if type(layout) == 'function' then
        layout = layout()
    end

    local width = window.width > 1 and window.width or math.floor(vim.o.columns * window.width)
    local height = window.height > 1 and window.height or math.floor(vim.o.lines * window.height)

    -- If layout changed or window isn't visible, we'll close and reopen
    if self.layout ~= layout or not self:visible() then
        self:close()
    end

    self.layout = layout

    if self:visible() then
        return
    end

    if layout == 'float' then
        self:setup_float(width, height, window)
    elseif layout == 'vertical' then
        self:setup_vertical(width)
    elseif layout == 'horizontal' then
        self:setup_horizontal(height)
    elseif layout == 'replace' then
        local current_window_number = vim.api.nvim_get_current_win()
        local current_buffer_number = vim.api.nvim_win_get_buf(current_window_number)

        -- Save where we came from
        self.source_window_number = current_window_number
        self.source_buffer_number = current_buffer_number

        -- Replace the buffer in the current window
        vim.api.nvim_win_set_buf(current_window_number, self.buffer_number)
    end

    if layout ~= 'replace' then
        self:setup_source_tracking()
    end

    self:setup_window_options()
end

--- Close the buffer window.
function Buffer:close()
    local window_number = self:visible()

    if not window_number then
        return
    end

    if self:focused() then
        local mode = vim.fn.mode():lower()
        if mode:find('v') then
            vim.cmd([[execute "normal! \<Esc>"]])
        elseif mode ~= 'n' then
            vim.cmd('stopinsert')
        end
    end

    if self.layout == 'replace' then
        self:restore()
        return
    end

    -- Check if window is still valid before trying to close it
    if window_number and vim.api.nvim_win_is_valid(window_number) then
        vim.api.nvim_win_close(window_number, true)
    end

    self:cleanup_source_tracking()
end

--- Toggle the buffer window.
---@param window nvim-jsonnet.Config.Window
function Buffer:toggle(window)
    if self:visible() then
        self:close()
    else
        self:open(window)
    end
end

--- Focus the buffer window.
function Buffer:focus()
    local window_number = self:visible()

    if not window_number then
        return
    end

    vim.api.nvim_set_current_win(window_number)
end

--- Restore the original buffer
function Buffer:restore()
    if not self.source_window_number or not self.source_buffer_number then
        return
    end

    if not vim.api.nvim_win_is_valid(self.source_window_number) then
        return
    end

    vim.api.nvim_win_set_buf(self.source_window_number, self.source_buffer_number)
    vim.api.nvim_win_set_hl_ns(self.source_window_number, 0)

    -- Manually trigger BufEnter event as nvim_win_set_buf does not trigger it
    vim.schedule(function()
        vim.cmd(string.format('doautocmd <nomodeline> BufEnter %s', self.source_buffer_number))
    end)
end

--- Set the buffer content
---@param content string
---@param filetype string
function Buffer:set_content(content, filetype)
    self:validate()

    vim.bo[self.buffer_number].modifiable = true
    vim.api.nvim_buf_set_lines(self.buffer_number, 0, -1, false, vim.split(content, '\n'))
    vim.bo[self.buffer_number].modifiable = false

    vim.bo[self.buffer_number].filetype = filetype
end

--- Run a command and show the output in this buffer
---@param cmd string The command to run
---@param args string[] The arguments to pass to the command
---@param cwd string? The working directory
---@param filetype string The filetype to set for the buffer
---@param window nvim-jsonnet.Config.Window The window configuration, if a new buffer needs to be created
---@param return_focus boolean Whether to return focus to the source window after running the command
function Buffer:run_command(cmd, args, cwd, filetype, window, return_focus)
    self:validate()

    self:cancel_running_job()

    local output_lines = {}
    local error_lines = {}

    self.job_id = vim.fn.jobstart({ cmd, unpack(args) }, {
        stdout_buffered = false,
        stderr_buffered = false,
        cwd = cwd,

        on_stdout = function(_, data)
            if not data or #data == 0 then
                return
            end

            for _, line in ipairs(data) do
                if line ~= '' then
                    table.insert(output_lines, line)
                end
            end
        end,

        on_stderr = function(_, data)
            if not data or #data == 0 then
                return
            end

            for _, line in ipairs(data) do
                if line ~= '' then
                    table.insert(error_lines, line)
                end
            end
        end,

        on_exit = function(_, exit_code)
            self.job_id = nil

            if not self:buf_valid() then
                return
            end

            if exit_code ~= 0 then
                -- Format error message for notification
                local error_header = 'Command `'
                    .. cmd
                    .. ' '
                    .. table.concat(args, ' ')
                    .. '` failed with exit code: '
                    .. exit_code
                local error_msg = error_header .. '\n' .. table.concat(error_lines, '\n')

                -- Display error notification
                vim.notify(error_msg, vim.log.levels.ERROR)

                return
            end

            self:set_content(table.concat(output_lines, '\n'), filetype)

            -- Force close and reopen to ensure proper window state
            self:close()
            self:open(window)

            if return_focus and self.source_window_number and vim.api.nvim_win_is_valid(self.source_window_number) then
                vim.api.nvim_set_current_win(self.source_window_number)
            end
        end,
    })

    if self.job_id <= 0 then
        vim.notify('Failed to start command: ' .. cmd .. ' ' .. table.concat(args, ' '), vim.log.levels.ERROR)
        self:close()
        self.job_id = nil
    end
end

--- Cancel the running job if there is one
function Buffer:cancel_running_job()
    if not self.job_id then
        return
    end

    vim.fn.jobstop(self.job_id)
    self.job_id = nil
end

return Buffer
