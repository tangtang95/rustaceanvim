local compat = require('rustaceanvim.compat')
local rust_analyzer = require('rustaceanvim.rust_analyzer')
local joinpath = compat.joinpath

local cargo = {}

---Checks if there is an active client for file_name and returns its root directory if found.
---@param file_name string
---@return string | nil root_dir The root directory of the active client for file_name (if there is one)
local function get_mb_active_client_root(file_name)
  ---@diagnostic disable-next-line: missing-parameter
  local cargo_home = compat.uv.os_getenv('CARGO_HOME') or joinpath(vim.env.HOME, '.cargo')
  local registry = joinpath(cargo_home, 'registry', 'src')

  ---@diagnostic disable-next-line: missing-parameter
  local rustup_home = compat.uv.os_getenv('RUSTUP_HOME') or joinpath(vim.env.HOME, '.rustup')
  local toolchains = joinpath(rustup_home, 'toolchains')

  for _, item in ipairs { toolchains, registry } do
    if file_name:sub(1, #item) == item then
      local clients = rust_analyzer.get_active_rustaceanvim_clients()
      return clients and #clients > 0 and clients[#clients].config.root_dir or nil
    end
  end
end

---@param file_name string
---@return string | nil root_dir
function cargo.get_root_dir(file_name)
  local reuse_active = get_mb_active_client_root(file_name)
  if reuse_active then
    return reuse_active
  end
  local path = vim.fs.dirname(file_name)
  if not path then
    return nil
  end
  ---@diagnostic disable-next-line: missing-fields
  local cargo_crate_dir = vim.fs.dirname(vim.fs.find({ 'Cargo.toml' }, {
    upward = true,
    path = path,
  })[1])
  local cargo_workspace_dir = nil
  if vim.fn.executable('cargo') == 1 then
    local cmd = { 'cargo', 'metadata', '--no-deps', '--format-version', '1' }
    if cargo_crate_dir ~= nil then
      cmd[#cmd + 1] = '--manifest-path'
      cmd[#cmd + 1] = joinpath(cargo_crate_dir, 'Cargo.toml')
    end
    local cargo_metadata = ''
    local cm = vim.fn.jobstart(cmd, {
      on_stdout = function(_, d, _)
        cargo_metadata = table.concat(d, '\n')
      end,
      stdout_buffered = true,
      cwd = path,
    })
    if cm > 0 then
      cm = vim.fn.jobwait({ cm })[1]
    else
      cm = -1
    end
    if cm == 0 then
      cargo_workspace_dir = vim.fn.json_decode(cargo_metadata)['workspace_root']
      ---@cast cargo_workspace_dir string
    end
  end
  return cargo_workspace_dir
    or cargo_crate_dir
    ---@diagnostic disable-next-line: missing-fields
    or vim.fs.dirname(vim.fs.find({ 'rust-project.json' }, {
      upward = true,
      path = path,
    })[1])
end

return cargo
