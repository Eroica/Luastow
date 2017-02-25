local argparse = require "argparse"
local lfs = require "lfs"

local function trim_directory (path)
	return path:sub(1, path:find("/[^/]*$") - 1)
end

local function parse_cmd_arguments ()
	local cmd_parser = argparse("script", "A portable GNU Stow implementation in Lua.")
	cmd_parser:argument("source_dir", "Source directory.")
	cmd_parser:option("-t --target", "Target directory.", trim_directory(lfs.currentdir()))
	cmd_parser:flag("-D --delete", "Delete from luastow directory.")
	cmd_parser:flag("-R --restow", "Restow source directory (remove from target directory, then stow into target directory again.")
	cmd_parser:flag("-v --verbose", "Prints debug messages.")
		:count "0-2"
		:target "verbosity"

	return cmd_parser:parse()
end

return {trim_directory = trim_directory,
		parse_cmd_arguments = parse_cmd_arguments}