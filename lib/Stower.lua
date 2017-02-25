local log = require "lib/log"

local PATH_SEPARATOR = "/"
local LFS_FILE_EXISTS_ERROR = "File exists"

local function create_link_function (source_file, target_dir, filename)
	log.trace("Will create link: " .. target_dir .. PATH_SEPARATOR .. filename)
	return function ()
		log.debug("Linking " .. source_file .. " -> " .. target_dir .. PATH_SEPARATOR .. filename)

		local _, error_msg = lfs.link(source_file,
									  target_dir .. PATH_SEPARATOR .. filename,
									  true)
		if _ == nil and error_msg ~= LFS_FILE_EXISTS_ERROR then
			log.error(error_msg)
			os.exit(-1)
		end
	end
end

local function delete_link_function (link_name)
	log.trace("Will delete link: " .. link_name)
	return function ()
		log.debug("Deleting link: " .. link_name)

		local _, error_msg = os.remove(link_name)
		if _ == nil then
			log.error(error_msg)
			os.exit(-1)
		end
	end
end

local function create_dir_function (dir_name, target_dir)
	log.trace("Will create directory: " .. target_dir .. PATH_SEPARATOR .. dir_name)
	return function ()
		log.debug("Creating directory " .. target_dir .. PATH_SEPARATOR .. dir_name)

		lfs.chdir(target_dir)
		local _, error_msg = lfs.mkdir(dir_name)
		if _ == nil and error_msg ~= LFS_FILE_EXISTS_ERROR then
			log.error(error_msg)
			os.exit(-1)
		end
	end
end

local function create_stow_transactions (dir, target_dir, STOW_TRANSACTIONS)
	lfs.chdir(dir)
	local current_dir = lfs.currentdir()
	for file in lfs.dir(lfs.currentdir()) do
		if file:sub(1, 1) ~= "." and file ~= ".." and lfs.attributes(file).mode == "file" then
			STOW_TRANSACTIONS[#STOW_TRANSACTIONS + 1] = create_link_function(current_dir .. PATH_SEPARATOR .. file, target_dir, file)
		elseif file ~= "." and file ~= ".." and lfs.attributes(file).mode == "directory" then
			STOW_TRANSACTIONS[#STOW_TRANSACTIONS + 1] = create_dir_function(file, target_dir)
			create_stow_transactions(file, target_dir .. PATH_SEPARATOR .. file, STOW_TRANSACTIONS)
		end
	end
	lfs.chdir("..")
end

local function create_delete_transactions (dir, target_dir, DELETE_TRANSACTIONS)
	lfs.chdir(dir)
	local current_dir = lfs.currentdir()
	for file in lfs.dir(lfs.currentdir()) do
		if file:sub(1, 1) ~= "." and file ~= ".." and lfs.attributes(file).mode == "file" then
			DELETE_TRANSACTIONS[#DELETE_TRANSACTIONS + 1] = delete_link_function(target_dir .. PATH_SEPARATOR .. file)
		elseif file ~= "." and file ~= ".." and lfs.attributes(file).mode == "directory" then
			create_delete_transactions(file, target_dir .. PATH_SEPARATOR .. file, DELETE_TRANSACTIONS)
		end
	end
	lfs.chdir("..")
end

local function Stow (args)
	local STOW_TRANSACTIONS = {}
	create_stow_transactions(args.source_dir, args.target, STOW_TRANSACTIONS)

	for i=1, #STOW_TRANSACTIONS do
		STOW_TRANSACTIONS[i]()
	end
end

local function Delete (args)
	local DELETE_TRANSACTIONS = {}
	create_delete_transactions(args.source_dir, args.target, DELETE_TRANSACTIONS)

	for i=1, #DELETE_TRANSACTIONS do
		DELETE_TRANSACTIONS[i]()
	end
end


return {Stow = Stow,
		Delete = Delete}