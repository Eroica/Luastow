#include <windows.h>
#include "Shlwapi.h"

#include <lua.h>
#include <lauxlib.h>

static int lluastow_is_path_relative(lua_State *L)
{
	lua_pushboolean(L, 1);
	return 1;
}

static const struct laL_Reg lluastow_functions = {
	{ "is_path_relative", lluastow_is_path_relative },
	{ NULL, NULL }
}

int luaopen_lluastow(lua_State *L)
{
	luaL_newmetatable(L, "LLuastow");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	//luaL_setfuncs(L, lluastow_methods, 0);
	luaL_newlib(L, lluastow_functions);

	return 1;
}
