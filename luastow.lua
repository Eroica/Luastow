local lfs = require "lfs"
local log = require "lib/log"

local Parser = require "lib/Parser"
local Stower = require "lib/Stower"

local PATH_SEPARATOR = package.config:sub(1, 1)
local ON_WINDOWS = PATH_SEPARATOR == "\\"
local LUASTOW_DEFAULT_DIR = "/usr/local/luastow"


local args = Parser.parse_cmd_arguments()

do -- Handle command-line arguments and options
	if args.global then
		if ON_WINDOWS then
			log.error("Sorry but this feature isn't available on Windows!")
			os.exit(-1)
		end

		if lfs.chdir(LUASTOW_DEFAULT_DIR) == nil then
			log.error("Default luastow directory (`/usr/local/luastow') doesn't seem to exist!")
			os.exit(-1)
		else
			-- Go to default luastow directory, and look for a directory that matches `source_dir'
			local _source_dir
			for dir in lfs.dir(lfs.currentdir()) do
				print("checking " .. dir)
				if dir:find(args.source_dir) ~= nil then
					_source_dir = LUASTOW_DEFAULT_DIR .. PATH_SEPARATOR .. dir
				end
			end

			if _source_dir == nil then
				log.error("Source dir `" .. args.source_dir .. "' was not found in " .. LUASTOW_DEFAULT_DIR .. "!")
				os.exit(-1)
			else
				args.source_dir = _source_dir
				args.target = Parser.trim_directory(LUASTOW_DEFAULT_DIR)
			end
		end
	else
		-- Handle `source_dir' argument
		local _ = lfs.attributes(args.source_dir)
		if _ == nil then
			log.error("Source `" .. args.source_dir .. "' doesn't seem to exist!")
			os.exit(-1)
		elseif _.mode ~= "directory" then
			log.error("Source must be a directory!")
			os.exit(-1)
		end
		if args.source_dir:sub(1, 1) ~= "/" and args.source_dir:sub(2, 3) ~= ":\\" then
			args.source_dir = lfs.currentdir() .. PATH_SEPARATOR .. args.source_dir
		end
		print(args.source_dir)

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
	end

	-- Handle `--verbose'
	local _verbosity_levels = {"error", "debug", "trace"}
	-- Keep in mind field `verbosity' starts at 0
	log.level = _verbosity_levels[args.verbosity + 1]

	-- Handle `--delete' and `--restow'
	if args.restow and args.delete then
		log.error("--delete and --restow cannot both be set to true!")
		os.exit(-1)
	end
end

if args.verbosity >= 2 then
	log.trace("Starting Luastow using these options:")
	local _ = {}
	for k, v in pairs(args) do
		_[#_ + 1] = "\t" .. k .. " = " .. tostring(v)
	end
	print("{\n" .. table.concat(_, "\n") .. "\n}")
end

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