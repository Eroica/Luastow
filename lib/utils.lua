local PATH_SEPARATOR = package.config:sub(1, 1)
local ON_WINDOWS = PATH_SEPARATOR == "\\"

local function is_path_relative_win32 (path)
	return false
end

local function is_path_relative (path)
	if ON_WINDOWS then
		return is_path_relative_win32(path)
	else
		return path:sub(1, 1) ~= PATH_SEPARATOR
	end
end

return {
	is_path_relative = is_path_relative
}
