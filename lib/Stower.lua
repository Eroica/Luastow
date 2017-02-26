local log = require "lib/log"

local PATH_SEPARATOR = "/"
local LFS_FILE_EXISTS_ERROR = "File exists"

local function create_link (source_file, target_file)
	log.debug("Linking: " .. source_file .. " -> " .. target_file)

	local _, error_msg = lfs.link(target_file, source_file, true)
	if _ == nil and error_msg ~= LFS_FILE_EXISTS_ERROR then
		log.error(error_msg)
		os.exit(-1)
	end
end

local function create_dir (target_dir)
	if lfs.attributes(target_dir) == nil then
		log.debug("Creating directory: " .. target_dir)

		local _, error_msg = lfs.mkdir(target_dir)
		if _ == nil and error_msg ~= LFS_FILE_EXISTS_ERROR then
			log.error(error_msg)
			os.exit(-1)
		end
	else
		log.debug("Directory `" .. target_dir .. "' already exists! Skipping ...")
	end
end

local function delete_link (link_name)
	log.debug("Deleting link: " .. link_name)

	local _, error_msg = os.remove(link_name)
	if _ == nil then
		log.error(error_msg)
		os.exit(-1)
	end
end

local function check_file (filename, path)
	return filename:sub(1, 1) ~= "." and filename ~= ".."
	       and lfs.attributes(path .. "/" .. filename).mode == "file"
end

local function check_dir (dir_name, path)
	return dir_name:sub(1, 1) ~= "." and dir_name ~= ".."
	       and lfs.attributes(path .. "/" .. dir_name).mode == "directory"
end


local function substitute_path (full_path, replaced_path, new_path)
	return new_path .. PATH_SEPARATOR .. full_path:sub(#replaced_path + 2)
end

local function iterate_dir (dir_name, name_table)
	local names = name_table or {}

	local full_path
	for name in lfs.dir(dir_name) do
		full_path = dir_name .. "/" .. name

		if check_file(name, dir_name) then
			names[#names + 1] = {full_path, "f"}
		elseif check_dir(name, dir_name) then
			names[#names + 1] = {full_path, "d"}
			iterate_dir(full_path, names)
		end
	end

	return names
end


local function Stow (args)
	local stow_transactions = iterate_dir(args.source_dir)
	local dir_transactions = {}
	local name

	-- Put directories into dir_transactions
	for i=#stow_transactions, 1, -1 do
		name = stow_transactions[i]
		if name[#name] == "d" then
			table.insert(dir_transactions, 1, table.remove(stow_transactions, i))
		end
	end

	-- Check that no file already exists in target directory
	for i=1, #stow_transactions do
		name = stow_transactions[i]
		-- local target_file = args.target .. PATH_SEPARATOR .. name[1]:sub(#args.source_dir + 2)
		local target_file = substitute_path(name[1], args.source_dir, args.target)
		if lfs.attributes(target_file) ~= nil then
			log.error("File " .. target_file .. " already exists in target directory! Aborting all operations ...")
			os.exit(-1)
		end
	end

	-- Create directories
	for i=1, #dir_transactions do
		name = dir_transactions[i]
		create_dir(substitute_path(name[1], args.source_dir, args.target))
	end

	-- Create links
	for i=1, #stow_transactions do
		name = stow_transactions[i]
		create_link(substitute_path(name[1], args.source_dir, args.target), name[1])
	end
end

local function Delete (args)
	local delete_transactions = iterate_dir(args.source_dir)
	local name

	-- Remove directories
	for i=#delete_transactions, 1, -1 do
		name = delete_transactions[i]
		if name[#name] == "d" then
			table.remove(delete_transactions, i)
		end
	end

	-- Check that file really exists in target location
	for i=1, #delete_transactions do
		name = delete_transactions[i]
		local target_link = substitute_path(name[1], args.source_dir, args.target)
		if lfs.attributes(target_link) == nil then
			log.error("Link " .. target_link .. " doesn't seem to exist in target directory! Aborting all operations ...")
			os.exit(-1)
		end
	end

	-- Delete links
	for i=1, #delete_transactions do
		name = delete_transactions[i]
		delete_link(substitute_path(name[1], args.source_dir, args.target))
	end
end

return {Stow = Stow,
        Delete = Delete}