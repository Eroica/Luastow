#include <stdio.h>
#include <string.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "Shlwapi.h"


static int l_link (lua_State *L) {
	const char *linkname = luaL_checkstring(L, 1);
	const char *target = luaL_checkstring(L, 2);
	int symlink = lua_toboolean(L, 3);
	int is_dir = PathIsDirectory(linkname) == FILE_ATTRIBUTE_DIRECTORY;
	if (is_dir && !symlink) {
		lua_pushnil(L); lua_pushstring(L, "hard links to directories are not supported on Windows");
		return 2;
	}

	int result = symlink ? CreateSymbolicLink(target, linkname, is_dir)
	                     : CreateHardLink(target, linkname, NULL);

	if (result) {
		lua_pushboolean(L, 1);
		return 1;
	} else {
		lua_pushnil(L); lua_pushstring(L, symlink ? "CreateSymbolicLink() failed"
		                                          : "CreateHardLink() failed");
		return 2;
	}
}

static const struct luaL_Reg mylib [] = {
	{"link", l_link},
	{NULL, NULL}
};

int __declspec(dllexport) luaopen_link (lua_State *L) {
	luaL_newlib(L, mylib);
	return 1;
}
