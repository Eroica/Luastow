local inspect = require "inspect"
local lfs = require "lfs"
local log = require "lib/log"

local Parser = require "lib/Parser"
local Stower = require "lib/Stower"


local args = Parser.parse_cmd_arguments()

do -- Handle command-line arguments and options
	-- Handle `source_dir' argument
	local _ = lfs.attributes(args.source_dir)
	if _ == nil then
		log.error("Source `" .. lfs.currentdir() .. PATH_SEPARATOR .. args.source_dir .. "' doesn't seem to exist!")
		os.exit(-1)
	elseif _.mode ~= "directory" then
		log.error("Source must be a directory!")
		os.exit(-1)
	end

	-- Handle `--target'
	if args.target == "." then args.target = lfs.currentdir() end
	if args.target == ".." then args.target = Parser.trim_directory(lfs.currentdir()) end
	_ = lfs.attributes(args.target)
	if _ == nil then
		log.error("Target `" .. lfs.currentdir() .. PATH_SEPARATOR .. args.target .. "' doesn't seem to exist!")
		os.exit(-1)
	elseif _.mode ~= "directory" then
		log.error("Target must be a directory!")
		os.exit(-1)
	end

	-- Handle `--verbose'
	-- Keep in mind field `verbosity' starts at 0
	local _verbosity_levels = {"error", "debug", "trace"}
	log.level = _verbosity_levels[args.verbosity + 1]

	-- Handle `--delete' and `--restow'
	if args.restow and args.delete then
		log.error("--delete and --restow cannot both be set to true!")
		os.exit(-1)
	end
end

log.trace([[Starting Luastow using this state:
]] .. inspect(args))

do -- Decide what to do
	if args.restow then
		Stower.Delete(args)
		Stower.Stow(args)
	elseif args.delete then
		Stower.Delete(args)
	else
		Stower.Stow(args)
	end
	log.trace("Thank you for using Luastow!")
end