local Job = require('plenary.job')

--- @class JobResult
--- @field stdout string The standard output
--- @field stderr string The standard error
--- @field code number The exit code

--- Run a job synchronously and return the results
--- @param cmd string The command to run
--- @param args string[] The command arguments
--- @param cwd string? The working directory
--- @return JobResult
local function run_job_sync(cmd, args, cwd)
    local stdout = {}
    local stderr = {}
    local result = {}

    Job:new({
        command = cmd,
        args = args,
        cwd = cwd,
        on_stdout = function(_, line)
            table.insert(stdout, line)
        end,
        on_stderr = function(_, line)
            table.insert(stderr, line)
        end,
        on_exit = function(_, code)
            result.code = code
        end,
    }):sync()

    result.stdout = table.concat(stdout, '\n')
    result.stderr = table.concat(stderr, '\n')
    return result
end

--- @class SystemResult
--- @field stdout string The standard output
--- @field stderr string The standard error
--- @field code number The exit code

--- Execute a system command and return the result
--- @param cmd string[] The command and arguments as a table
--- @param cwd string? The working directory
--- @return SystemResult
local function system(cmd, cwd)
    local result = vim.system(cmd, {
        text = true,
        cwd = cwd,
    }):wait()

    return {
        stdout = result.stdout or '',
        stderr = result.stderr or '',
        code = result.code or -1,
    }
end

--- Get the filename from a path
--- @param path string The file path
--- @return string The filename
local function filename(path)
    return vim.fs.basename(path)
end

--- Get the directory name from a path
--- @param path string The file path
--- @return string The directory name
local function dirname(path)
    local parts = vim.split(path, '/')
    table.remove(parts)
    return table.concat(parts, '/')
end

--- Check if a buffer is valid
--- @param buffer_number number The buffer number
--- @return boolean True if the buffer is valid and loaded
local function is_valid_buffer(buffer_number)
    return buffer_number and vim.api.nvim_buf_is_valid(buffer_number) and vim.api.nvim_buf_is_loaded(buffer_number)
end

return {
    run_job_sync = run_job_sync,
    system = system,
    filename = filename,
    dirname = dirname,
    is_valid_buffer = is_valid_buffer,
}
