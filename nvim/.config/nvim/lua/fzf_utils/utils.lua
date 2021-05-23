local M = {}
local fn = vim.fn

function M.get_leading_num(str)
	return tonumber(string.match(str, "%d+"))
end

local function preview_lines(path, line, fzf_preview_lines)
	local half_preview_lines = fzf_preview_lines / 2
	local start_line = line - half_preview_lines
	local end_line = line + half_preview_lines

	if start_line < 0 then
		end_line = end_line - start_line
		start_line = 0
	end

	local cmd = string.format("bat --theme gruvbox-dark -H %i --color always --style numbers --pager never -r %i:%i %s",
				line, start_line, end_line, path)
	return fn.system(cmd)
end

M.vimgrep_preview = "--expect=ctrl-v --preview="..require('fzf.actions').action(function(selections, fzf_preview_lines, _)
	local parsed_content = {string.match(selections[1], "(.-):(%d+):.*")}
	return preview_lines(parsed_content[1], parsed_content[2], fzf_preview_lines)
end)

-- get preview action that has result starting with line number
function M.get_preview_action(path)
	local shell = require('fzf.actions').action(function(selections, fzf_preview_lines, _)
		if selections ~= nil then
			local line_nr = M.get_leading_num(selections[1])
			return preview_lines(path, line_nr, fzf_preview_lines)
		end
	end)
	return shell
end

local function cmdedit(tabcmd, path, row, col)
	vim.cmd(string.format(tabcmd, path))
	if col ~= nil and row ~= nil then
		vim.api.nvim_win_set_cursor(0, {row, col})
		vim.cmd("normal! zz")
	end
end

function M.tabedit(path, row, col)
	cmdedit("tab drop %s", path, row, col)
end

function M.vsplitedit(path, row, col)
	cmdedit("vsplit %s", path, row, col)
end

local function coroutine_callback(func)
	local co = coroutine.running()
	local callback = function(...)
		coroutine.resume(co, ...)
	end
	func(callback)
	return coroutine.yield()
end

function M.coroutinify(func)
	return function (...)
		local args = {...}
		return coroutine_callback(function (cb)
			table.insert(args, cb)
			func(unpack(args))
		end)
	end
end

-- file operation
local uv = vim.loop
M.open = M.coroutinify(uv.fs_open)
M.close = M.coroutinify(uv.fs_close)
M.stat = M.coroutinify(uv.fs_fstat)
M.read = M.coroutinify(uv.fs_read)
M.write = M.coroutinify(uv.fs_write)

-- readfile in coroutine
function M.readfile(path)
	local _, fd = M.open(path, 'r', 438)
	if fd == nil then
		return nil
	end
	local _, s = M.stat(fd)
	local _, data = M.read(fd, s.size, 0)
	M.close(fd)
	return data
end

return M
