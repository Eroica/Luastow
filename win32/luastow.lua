#!/usr/bin/env lua

do

package.preload[ "lib/log" ] = assert( (loadstring or load)(
"--\
-- log.lua\
--\
-- Copyright (c) 2016 rxi\
--\
-- This library is free software; you can redistribute it and/or modify it\
-- under the terms of the MIT license. See LICENSE for details.\
--\
\
local log = { _version = \"0.1.0\" }\
\
log.usecolor = true\
log.outfile = nil\
log.level = \"trace\"\
\
\
local modes = {\
  { name = \"trace\", color = \"\\27[34m\", },\
  { name = \"debug\", color = \"\\27[36m\", },\
  { name = \"info\",  color = \"\\27[32m\", },\
  { name = \"warn\",  color = \"\\27[33m\", },\
  { name = \"error\", color = \"\\27[31m\", },\
  { name = \"fatal\", color = \"\\27[35m\", },\
}\
\
\
local levels = {}\
for i, v in ipairs(modes) do\
  levels[v.name] = i\
end\
\
\
local round = function(x, increment)\
  increment = increment or 1\
  x = x / increment\
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment\
end\
\
\
local _tostring = tostring\
\
local tostring = function(...)\
  local t = {}\
  for i = 1, select('#', ...) do\
    local x = select(i, ...)\
    if type(x) == \"number\" then\
      x = round(x, .01)\
    end\
    t[#t + 1] = _tostring(x)\
  end\
  return table.concat(t, \" \")\
end\
\
\
for i, x in ipairs(modes) do\
  local nameupper = x.name:upper()\
  log[x.name] = function(...)\
    \
    -- Return early if we're below the log level\
    if i < levels[log.level] then\
      return\
    end\
\
    local msg = tostring(...)\
    local info = debug.getinfo(2, \"Sl\")\
    local lineinfo = info.short_src .. \":\" .. info.currentline\
\
    -- Output to console\
    print(string.format(\"%s[%-6s%s]%s %s: %s\",\
                        log.usecolor and x.color or \"\",\
                        nameupper,\
                        os.date(\"%H:%M:%S\"),\
                        log.usecolor and \"\\27[0m\" or \"\",\
                        lineinfo,\
                        msg))\
\
    -- Output to log file\
    if log.outfile then\
      local fp = io.open(log.outfile, \"a\")\
      local str = string.format(\"[%-6s%s] %s: %s\\n\",\
                                nameupper, os.date(), lineinfo, msg)\
      fp:write(str)\
      fp:close()\
    end\
\
  end\
end\
\
\
return log\
"
, '@'..".\\lib/log.lua" ) )

package.preload[ "argparse" ] = assert( (loadstring or load)(
"-- The MIT License (MIT)\
\
-- Copyright (c) 2013 - 2015 Peter Melnichenko\
\
-- Permission is hereby granted, free of charge, to any person obtaining a copy of\
-- this software and associated documentation files (the \"Software\"), to deal in\
-- the Software without restriction, including without limitation the rights to\
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of\
-- the Software, and to permit persons to whom the Software is furnished to do so,\
-- subject to the following conditions:\
\
-- The above copyright notice and this permission notice shall be included in all\
-- copies or substantial portions of the Software.\
\
-- THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS\
-- FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR\
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER\
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN\
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.\
\
local function deep_update(t1, t2)\
   for k, v in pairs(t2) do\
      if type(v) == \"table\" then\
         v = deep_update({}, v)\
      end\
\
      t1[k] = v\
   end\
\
   return t1\
end\
\
-- A property is a tuple {name, callback}.\
-- properties.args is number of properties that can be set as arguments\
-- when calling an object.\
local function class(prototype, properties, parent)\
   -- Class is the metatable of its instances.\
   local cl = {}\
   cl.__index = cl\
\
   if parent then\
      cl.__prototype = deep_update(deep_update({}, parent.__prototype), prototype)\
   else\
      cl.__prototype = prototype\
   end\
\
   if properties then\
      local names = {}\
\
      -- Create setter methods and fill set of property names. \
      for _, property in ipairs(properties) do\
         local name, callback = property[1], property[2]\
\
         cl[name] = function(self, value)\
            if not callback(self, value) then\
               self[\"_\" .. name] = value\
            end\
\
            return self\
         end\
\
         names[name] = true\
      end\
\
      function cl.__call(self, ...)\
         -- When calling an object, if the first argument is a table,\
         -- interpret keys as property names, else delegate arguments\
         -- to corresponding setters in order.\
         if type((...)) == \"table\" then\
            for name, value in pairs((...)) do\
               if names[name] then\
                  self[name](self, value)\
               end\
            end\
         else\
            local nargs = select(\"#\", ...)\
\
            for i, property in ipairs(properties) do\
               if i > nargs or i > properties.args then\
                  break\
               end\
\
               local arg = select(i, ...)\
\
               if arg ~= nil then\
                  self[property[1]](self, arg)\
               end\
            end\
         end\
\
         return self\
      end\
   end\
\
   -- If indexing class fails, fallback to its parent.\
   local class_metatable = {}\
   class_metatable.__index = parent\
\
   function class_metatable.__call(self, ...)\
      -- Calling a class returns its instance.\
      -- Arguments are delegated to the instance.\
      local object = deep_update({}, self.__prototype)\
      setmetatable(object, self)\
      return object(...)\
   end\
\
   return setmetatable(cl, class_metatable)\
end\
\
local function typecheck(name, types, value)\
   for _, type_ in ipairs(types) do\
      if type(value) == type_ then\
         return true\
      end\
   end\
\
   error((\"bad property '%s' (%s expected, got %s)\"):format(name, table.concat(types, \" or \"), type(value)))\
end\
\
local function typechecked(name, ...)\
   local types = {...}\
   return {name, function(_, value) typecheck(name, types, value) end}\
end\
\
local multiname = {\"name\", function(self, value)\
   typecheck(\"name\", {\"string\"}, value)\
\
   for alias in value:gmatch(\"%S+\") do\
      self._name = self._name or alias\
      table.insert(self._aliases, alias)\
   end\
\
   -- Do not set _name as with other properties.\
   return true\
end}\
\
local function parse_boundaries(str)\
   if tonumber(str) then\
      return tonumber(str), tonumber(str)\
   end\
\
   if str == \"*\" then\
      return 0, math.huge\
   end\
\
   if str == \"+\" then\
      return 1, math.huge\
   end\
\
   if str == \"?\" then\
      return 0, 1\
   end\
\
   if str:match \"^%d+%-%d+$\" then\
      local min, max = str:match \"^(%d+)%-(%d+)$\"\
      return tonumber(min), tonumber(max)\
   end\
\
   if str:match \"^%d+%+$\" then\
      local min = str:match \"^(%d+)%+$\"\
      return tonumber(min), math.huge\
   end\
end\
\
local function boundaries(name)\
   return {name, function(self, value)\
      typecheck(name, {\"number\", \"string\"}, value)\
\
      local min, max = parse_boundaries(value)\
\
      if not min then\
         error((\"bad property '%s'\"):format(name))\
      end\
\
      self[\"_min\" .. name], self[\"_max\" .. name] = min, max\
   end}\
end\
\
local actions = {}\
\
local option_action = {\"action\", function(_, value)\
   typecheck(\"action\", {\"function\", \"string\"}, value)\
\
   if type(value) == \"string\" and not actions[value] then\
      error((\"unknown action '%s'\"):format(value))\
   end\
end}\
\
local option_init = {\"init\", function(self)\
   self._has_init = true\
end}\
\
local option_default = {\"default\", function(self, value)\
   if type(value) ~= \"string\" then\
      self._init = value\
      self._has_init = true\
      return true\
   end\
end}\
\
local add_help = {\"add_help\", function(self, value)\
   typecheck(\"add_help\", {\"boolean\", \"string\", \"table\"}, value)\
\
   if self._has_help then\
      table.remove(self._options)\
      self._has_help = false\
   end\
\
   if value then\
      local help = self:flag()\
         :description \"Show this help message and exit.\"\
         :action(function()\
            print(self:get_help())\
            os.exit(0)\
         end)\
\
      if value ~= true then\
         help = help(value)\
      end\
\
      if not help._name then\
         help \"-h\" \"--help\"\
      end\
\
      self._has_help = true\
   end\
end}\
\
local Parser = class({\
   _arguments = {},\
   _options = {},\
   _commands = {},\
   _mutexes = {},\
   _require_command = true,\
   _handle_options = true\
}, {\
   args = 3,\
   typechecked(\"name\", \"string\"),\
   typechecked(\"description\", \"string\"),\
   typechecked(\"epilog\", \"string\"),\
   typechecked(\"usage\", \"string\"),\
   typechecked(\"help\", \"string\"),\
   typechecked(\"require_command\", \"boolean\"),\
   typechecked(\"handle_options\", \"boolean\"),\
   typechecked(\"action\", \"function\"),\
   typechecked(\"command_target\", \"string\"),\
   add_help\
})\
\
local Command = class({\
   _aliases = {}\
}, {\
   args = 3,\
   multiname,\
   typechecked(\"description\", \"string\"),\
   typechecked(\"epilog\", \"string\"),\
   typechecked(\"target\", \"string\"),\
   typechecked(\"usage\", \"string\"),\
   typechecked(\"help\", \"string\"),\
   typechecked(\"require_command\", \"boolean\"),\
   typechecked(\"handle_options\", \"boolean\"),\
   typechecked(\"action\", \"function\"),\
   typechecked(\"command_target\", \"string\"),\
   add_help\
}, Parser)\
\
local Argument = class({\
   _minargs = 1,\
   _maxargs = 1,\
   _mincount = 1,\
   _maxcount = 1,\
   _defmode = \"unused\",\
   _show_default = true\
}, {\
   args = 5,\
   typechecked(\"name\", \"string\"),\
   typechecked(\"description\", \"string\"),\
   option_default,\
   typechecked(\"convert\", \"function\", \"table\"),\
   boundaries(\"args\"),\
   typechecked(\"target\", \"string\"),\
   typechecked(\"defmode\", \"string\"),\
   typechecked(\"show_default\", \"boolean\"),\
   typechecked(\"argname\", \"string\", \"table\"),\
   option_action,\
   option_init\
})\
\
local Option = class({\
   _aliases = {},\
   _mincount = 0,\
   _overwrite = true\
}, {\
   args = 6,\
   multiname,\
   typechecked(\"description\", \"string\"),\
   option_default,\
   typechecked(\"convert\", \"function\", \"table\"),\
   boundaries(\"args\"),\
   boundaries(\"count\"),\
   typechecked(\"target\", \"string\"),\
   typechecked(\"defmode\", \"string\"),\
   typechecked(\"show_default\", \"boolean\"),\
   typechecked(\"overwrite\", \"boolean\"),\
   typechecked(\"argname\", \"string\", \"table\"),\
   option_action,\
   option_init\
}, Argument)\
\
function Argument:_get_argument_list()\
   local buf = {}\
   local i = 1\
\
   while i <= math.min(self._minargs, 3) do\
      local argname = self:_get_argname(i)\
\
      if self._default and self._defmode:find \"a\" then\
         argname = \"[\" .. argname .. \"]\"\
      end\
\
      table.insert(buf, argname)\
      i = i+1\
   end\
\
   while i <= math.min(self._maxargs, 3) do\
      table.insert(buf, \"[\" .. self:_get_argname(i) .. \"]\")\
      i = i+1\
\
      if self._maxargs == math.huge then\
         break\
      end\
   end\
\
   if i < self._maxargs then\
      table.insert(buf, \"...\")\
   end\
\
   return buf\
end\
\
function Argument:_get_usage()\
   local usage = table.concat(self:_get_argument_list(), \" \")\
\
   if self._default and self._defmode:find \"u\" then\
      if self._maxargs > 1 or (self._minargs == 1 and not self._defmode:find \"a\") then\
         usage = \"[\" .. usage .. \"]\"\
      end\
   end\
\
   return usage\
end\
\
function actions.store_true(result, target)\
   result[target] = true\
end\
\
function actions.store_false(result, target)\
   result[target] = false\
end\
\
function actions.store(result, target, argument)\
   result[target] = argument\
end\
\
function actions.count(result, target, _, overwrite)\
   if not overwrite then\
      result[target] = result[target] + 1\
   end\
end\
\
function actions.append(result, target, argument, overwrite)\
   result[target] = result[target] or {}\
   table.insert(result[target], argument)\
\
   if overwrite then\
      table.remove(result[target], 1)\
   end\
end\
\
function actions.concat(result, target, arguments, overwrite)\
   if overwrite then\
      error(\"'concat' action can't handle too many invocations\")\
   end\
\
   result[target] = result[target] or {}\
\
   for _, argument in ipairs(arguments) do\
      table.insert(result[target], argument)\
   end\
end\
\
function Argument:_get_action()\
   local action, init\
\
   if self._maxcount == 1 then\
      if self._maxargs == 0 then\
         action, init = \"store_true\", nil\
      else\
         action, init = \"store\", nil\
      end\
   else\
      if self._maxargs == 0 then\
         action, init = \"count\", 0\
      else\
         action, init = \"append\", {}\
      end\
   end\
\
   if self._action then\
      action = self._action\
   end\
\
   if self._has_init then\
      init = self._init\
   end\
\
   if type(action) == \"string\" then\
      action = actions[action]\
   end\
\
   return action, init\
end\
\
-- Returns placeholder for `narg`-th argument. \
function Argument:_get_argname(narg)\
   local argname = self._argname or self:_get_default_argname()\
\
   if type(argname) == \"table\" then\
      return argname[narg]\
   else\
      return argname\
   end\
end\
\
function Argument:_get_default_argname()\
   return \"<\" .. self._name .. \">\"\
end\
\
function Option:_get_default_argname()\
   return \"<\" .. self:_get_default_target() .. \">\"\
end\
\
-- Returns label to be shown in the help message. \
function Argument:_get_label()\
   return self._name\
end\
\
function Option:_get_label()\
   local variants = {}\
   local argument_list = self:_get_argument_list()\
   table.insert(argument_list, 1, nil)\
\
   for _, alias in ipairs(self._aliases) do\
      argument_list[1] = alias\
      table.insert(variants, table.concat(argument_list, \" \"))\
   end\
\
   return table.concat(variants, \", \")\
end\
\
function Command:_get_label()\
   return table.concat(self._aliases, \", \")\
end\
\
function Argument:_get_description()\
   if self._default and self._show_default then\
      if self._description then\
         return (\"%s (default: %s)\"):format(self._description, self._default)\
      else\
         return (\"default: %s\"):format(self._default)\
      end\
   else\
      return self._description or \"\"\
   end\
end\
\
function Command:_get_description()\
   return self._description or \"\"\
end\
\
function Option:_get_usage()\
   local usage = self:_get_argument_list()\
   table.insert(usage, 1, self._name)\
   usage = table.concat(usage, \" \")\
\
   if self._mincount == 0 or self._default then\
      usage = \"[\" .. usage .. \"]\"\
   end\
\
   return usage\
end\
\
function Argument:_get_default_target()\
   return self._name\
end\
\
function Option:_get_default_target()\
   local res\
\
   for _, alias in ipairs(self._aliases) do\
      if alias:sub(1, 1) == alias:sub(2, 2) then\
         res = alias:sub(3)\
         break\
      end\
   end\
\
   res = res or self._name:sub(2)\
   return (res:gsub(\"-\", \"_\"))\
end\
\
function Option:_is_vararg()\
   return self._maxargs ~= self._minargs\
end\
\
function Parser:_get_fullname()\
   local parent = self._parent\
   local buf = {self._name}\
\
   while parent do\
      table.insert(buf, 1, parent._name)\
      parent = parent._parent\
   end\
\
   return table.concat(buf, \" \")\
end\
\
function Parser:_update_charset(charset)\
   charset = charset or {}\
\
   for _, command in ipairs(self._commands) do\
      command:_update_charset(charset)\
   end\
\
   for _, option in ipairs(self._options) do\
      for _, alias in ipairs(option._aliases) do\
         charset[alias:sub(1, 1)] = true\
      end\
   end\
\
   return charset\
end\
\
function Parser:argument(...)\
   local argument = Argument(...)\
   table.insert(self._arguments, argument)\
   return argument\
end\
\
function Parser:option(...)\
   local option = Option(...)\
\
   if self._has_help then\
      table.insert(self._options, #self._options, option)\
   else\
      table.insert(self._options, option)\
   end\
\
   return option\
end\
\
function Parser:flag(...)\
   return self:option():args(0)(...)\
end\
\
function Parser:command(...)\
   local command = Command():add_help(true)(...)\
   command._parent = self\
   table.insert(self._commands, command)\
   return command\
end\
\
function Parser:mutex(...)\
   local options = {...}\
\
   for i, option in ipairs(options) do\
      assert(getmetatable(option) == Option, (\"bad argument #%d to 'mutex' (Option expected)\"):format(i))\
   end\
\
   table.insert(self._mutexes, options)\
   return self\
end\
\
local max_usage_width = 70\
local usage_welcome = \"Usage: \"\
\
function Parser:get_usage()\
   if self._usage then\
      return self._usage\
   end\
\
   local lines = {usage_welcome .. self:_get_fullname()}\
\
   local function add(s)\
      if #lines[#lines]+1+#s <= max_usage_width then\
         lines[#lines] = lines[#lines] .. \" \" .. s\
      else\
         lines[#lines+1] = (\" \"):rep(#usage_welcome) .. s\
      end\
   end\
\
   -- This can definitely be refactored into something cleaner\
   local mutex_options = {}\
   local vararg_mutexes = {}\
\
   -- First, put mutexes which do not contain vararg options and remember those which do\
   for _, mutex in ipairs(self._mutexes) do\
      local buf = {}\
      local is_vararg = false\
\
      for _, option in ipairs(mutex) do\
         if option:_is_vararg() then\
            is_vararg = true\
         end\
\
         table.insert(buf, option:_get_usage())\
         mutex_options[option] = true\
      end\
\
      local repr = \"(\" .. table.concat(buf, \" | \") .. \")\"\
\
      if is_vararg then\
         table.insert(vararg_mutexes, repr)\
      else\
         add(repr)\
      end\
   end\
\
   -- Second, put regular options\
   for _, option in ipairs(self._options) do\
      if not mutex_options[option] and not option:_is_vararg() then\
         add(option:_get_usage())\
      end\
   end\
\
   -- Put positional arguments\
   for _, argument in ipairs(self._arguments) do\
      add(argument:_get_usage())\
   end\
\
   -- Put mutexes containing vararg options\
   for _, mutex_repr in ipairs(vararg_mutexes) do\
      add(mutex_repr)\
   end\
\
   for _, option in ipairs(self._options) do\
      if not mutex_options[option] and option:_is_vararg() then\
         add(option:_get_usage())\
      end\
   end\
\
   if #self._commands > 0 then\
      if self._require_command then\
         add(\"<command>\")\
      else\
         add(\"[<command>]\")\
      end\
\
      add(\"...\")\
   end\
\
   return table.concat(lines, \"\\n\")\
end\
\
local margin_len = 3\
local margin_len2 = 25\
local margin = (\" \"):rep(margin_len)\
local margin2 = (\" \"):rep(margin_len2)\
\
local function make_two_columns(s1, s2)\
   if s2 == \"\" then\
      return margin .. s1\
   end\
\
   s2 = s2:gsub(\"\\n\", \"\\n\" .. margin2)\
\
   if #s1 < (margin_len2-margin_len) then\
      return margin .. s1 .. (\" \"):rep(margin_len2-margin_len-#s1) .. s2\
   else\
      return margin .. s1 .. \"\\n\" .. margin2 .. s2\
   end\
end\
\
function Parser:get_help()\
   if self._help then\
      return self._help\
   end\
\
   local blocks = {self:get_usage()}\
   \
   if self._description then\
      table.insert(blocks, self._description)\
   end\
\
   local labels = {\"Arguments:\", \"Options:\", \"Commands:\"}\
\
   for i, elements in ipairs{self._arguments, self._options, self._commands} do\
      if #elements > 0 then\
         local buf = {labels[i]}\
\
         for _, element in ipairs(elements) do\
            table.insert(buf, make_two_columns(element:_get_label(), element:_get_description()))\
         end\
\
         table.insert(blocks, table.concat(buf, \"\\n\"))\
      end\
   end\
\
   if self._epilog then\
      table.insert(blocks, self._epilog)\
   end\
\
   return table.concat(blocks, \"\\n\\n\")\
end\
\
local function get_tip(context, wrong_name)\
   local context_pool = {}\
   local possible_name\
   local possible_names = {}\
\
   for name in pairs(context) do\
      if type(name) == \"string\" then\
         for i = 1, #name do\
            possible_name = name:sub(1, i - 1) .. name:sub(i + 1)\
\
            if not context_pool[possible_name] then\
               context_pool[possible_name] = {}\
            end\
\
            table.insert(context_pool[possible_name], name)\
         end\
      end\
   end\
\
   for i = 1, #wrong_name + 1 do\
      possible_name = wrong_name:sub(1, i - 1) .. wrong_name:sub(i + 1)\
\
      if context[possible_name] then\
         possible_names[possible_name] = true\
      elseif context_pool[possible_name] then\
         for _, name in ipairs(context_pool[possible_name]) do\
            possible_names[name] = true\
         end\
      end\
   end\
\
   local first = next(possible_names)\
\
   if first then\
      if next(possible_names, first) then\
         local possible_names_arr = {}\
\
         for name in pairs(possible_names) do\
            table.insert(possible_names_arr, \"'\" .. name .. \"'\")\
         end\
\
         table.sort(possible_names_arr)\
         return \"\\nDid you mean one of these: \" .. table.concat(possible_names_arr, \" \") .. \"?\"\
      else\
         return \"\\nDid you mean '\" .. first .. \"'?\"\
      end\
   else\
      return \"\"\
   end\
end\
\
local ElementState = class({\
   invocations = 0\
})\
\
function ElementState:__call(state, element)\
   self.state = state\
   self.result = state.result\
   self.element = element\
   self.target = element._target or element:_get_default_target()\
   self.action, self.result[self.target] = element:_get_action()\
   return self\
end\
\
function ElementState:error(fmt, ...)\
   self.state:error(fmt, ...)\
end\
\
function ElementState:convert(argument)\
   local converter = self.element._convert\
\
   if converter then\
      local ok, err\
\
      if type(converter) == \"function\" then\
         ok, err = converter(argument)\
      else\
         ok = converter[argument]\
      end\
\
      if ok == nil then\
         self:error(err and \"%s\" or \"malformed argument '%s'\", err or argument)\
      end\
\
      argument = ok\
   end\
\
   return argument\
end\
\
function ElementState:default(mode)\
   return self.element._defmode:find(mode) and self.element._default\
end\
\
local function bound(noun, min, max, is_max)\
   local res = \"\"\
\
   if min ~= max then\
      res = \"at \" .. (is_max and \"most\" or \"least\") .. \" \"\
   end\
\
   local number = is_max and max or min\
   return res .. tostring(number) .. \" \" .. noun ..  (number == 1 and \"\" or \"s\")\
end\
\
function ElementState:invoke(alias)\
   self.open = true\
   self.name = (\"%s '%s'\"):format(alias and \"option\" or \"argument\", alias or self.element._name)\
   self.overwrite = false\
\
   if self.invocations >= self.element._maxcount then\
      if self.element._overwrite then\
         self.overwrite = true\
      else\
         self:error(\"%s must be used %s\", self.name, bound(\"time\", self.element._mincount, self.element._maxcount, true))\
      end\
   else\
      self.invocations = self.invocations + 1\
   end\
\
   self.args = {}\
\
   if self.element._maxargs <= 0 then\
      self:close()\
   end\
\
   return self.open\
end\
\
function ElementState:pass(argument)\
   argument = self:convert(argument)\
   table.insert(self.args, argument)\
\
   if #self.args >= self.element._maxargs then\
      self:close()\
   end\
\
   return self.open\
end\
\
function ElementState:complete_invocation()\
   while #self.args < self.element._minargs do\
      self:pass(self.element._default)\
   end\
end\
\
function ElementState:close()\
   if self.open then\
      self.open = false\
\
      if #self.args < self.element._minargs then\
         if self:default(\"a\") then\
            self:complete_invocation()\
         else\
            if #self.args == 0 then\
               if getmetatable(self.element) == Argument then\
                  self:error(\"missing %s\", self.name)\
               elseif self.element._maxargs == 1 then\
                  self:error(\"%s requires an argument\", self.name)\
               end\
            end\
\
            self:error(\"%s requires %s\", self.name, bound(\"argument\", self.element._minargs, self.element._maxargs))\
         end\
      end\
\
      local args = self.args\
\
      if self.element._maxargs <= 1 then\
         args = args[1]\
      end\
\
      if self.element._maxargs == 1 and self.element._minargs == 0 and self.element._mincount ~= self.element._maxcount then\
         args = self.args\
      end\
\
      self.action(self.result, self.target, args, self.overwrite)\
   end\
end\
\
local ParseState = class({\
   result = {},\
   options = {},\
   arguments = {},\
   argument_i = 1,\
   element_to_mutexes = {},\
   mutex_to_used_option = {},\
   command_actions = {}\
})\
\
function ParseState:__call(parser, error_handler)\
   self.parser = parser\
   self.error_handler = error_handler\
   self.charset = parser:_update_charset()\
   self:switch(parser)\
   return self\
end\
\
function ParseState:error(fmt, ...)\
   self.error_handler(self.parser, fmt:format(...))\
end\
\
function ParseState:switch(parser)\
   self.parser = parser\
\
   if parser._action then\
      table.insert(self.command_actions, {action = parser._action, name = parser._name})\
   end\
\
   for _, option in ipairs(parser._options) do\
      option = ElementState(self, option)\
      table.insert(self.options, option)\
\
      for _, alias in ipairs(option.element._aliases) do\
         self.options[alias] = option\
      end\
   end\
\
   for _, mutex in ipairs(parser._mutexes) do\
      for _, option in ipairs(mutex) do\
         if not self.element_to_mutexes[option] then\
            self.element_to_mutexes[option] = {}\
         end\
\
         table.insert(self.element_to_mutexes[option], mutex)\
      end\
   end\
\
   for _, argument in ipairs(parser._arguments) do\
      argument = ElementState(self, argument)\
      table.insert(self.arguments, argument)\
      argument:invoke()\
   end\
\
   self.handle_options = parser._handle_options\
   self.argument = self.arguments[self.argument_i]\
   self.commands = parser._commands\
\
   for _, command in ipairs(self.commands) do\
      for _, alias in ipairs(command._aliases) do\
         self.commands[alias] = command\
      end\
   end\
end\
\
function ParseState:get_option(name)\
   local option = self.options[name]\
\
   if not option then\
      self:error(\"unknown option '%s'%s\", name, get_tip(self.options, name))\
   else\
      return option\
   end\
end\
\
function ParseState:get_command(name)\
   local command = self.commands[name]\
\
   if not command then\
      if #self.commands > 0 then\
         self:error(\"unknown command '%s'%s\", name, get_tip(self.commands, name))\
      else\
         self:error(\"too many arguments\")\
      end\
   else\
      return command\
   end\
end\
\
function ParseState:invoke(option, name)\
   self:close()\
\
   if self.element_to_mutexes[option.element] then\
      for _, mutex in ipairs(self.element_to_mutexes[option.element]) do\
         local used_option = self.mutex_to_used_option[mutex]\
\
         if used_option and used_option ~= option then\
            self:error(\"option '%s' can not be used together with %s\", name, used_option.name)\
         else\
            self.mutex_to_used_option[mutex] = option\
         end\
      end\
   end\
\
   if option:invoke(name) then\
      self.option = option\
   end\
end\
\
function ParseState:pass(arg)\
   if self.option then\
      if not self.option:pass(arg) then\
         self.option = nil\
      end\
   elseif self.argument then\
      if not self.argument:pass(arg) then\
         self.argument_i = self.argument_i + 1\
         self.argument = self.arguments[self.argument_i]\
      end\
   else\
      local command = self:get_command(arg)\
      self.result[command._target or command._name] = true\
\
      if self.parser._command_target then\
         self.result[self.parser._command_target] = command._name\
      end\
\
      self:switch(command)\
   end\
end\
\
function ParseState:close()\
   if self.option then\
      self.option:close()\
      self.option = nil\
   end\
end\
\
function ParseState:finalize()\
   self:close()\
\
   for i = self.argument_i, #self.arguments do\
      local argument = self.arguments[i]\
      if #argument.args == 0 and argument:default(\"u\") then\
         argument:complete_invocation()\
      else\
         argument:close()\
      end\
   end\
\
   if self.parser._require_command and #self.commands > 0 then\
      self:error(\"a command is required\")\
   end\
\
   for _, option in ipairs(self.options) do\
      local name = option.name or (\"option '%s'\"):format(option.element._name)\
\
      if option.invocations == 0 then\
         if option:default(\"u\") then\
            option:invoke(name)\
            option:complete_invocation()\
            option:close()\
         end\
      end\
\
      local mincount = option.element._mincount\
\
      if option.invocations < mincount then\
         if option:default(\"a\") then\
            while option.invocations < mincount do\
               option:invoke(name)\
               option:close()\
            end\
         elseif option.invocations == 0 then\
            self:error(\"missing %s\", name)\
         else\
            self:error(\"%s must be used %s\", name, bound(\"time\", mincount, option.element._maxcount))\
         end\
      end\
   end\
\
   for i = #self.command_actions, 1, -1 do\
      self.command_actions[i].action(self.result, self.command_actions[i].name)\
   end\
end\
\
function ParseState:parse(args)\
   for _, arg in ipairs(args) do\
      local plain = true\
\
      if self.handle_options then\
         local first = arg:sub(1, 1)\
\
         if self.charset[first] then\
            if #arg > 1 then\
               plain = false\
\
               if arg:sub(2, 2) == first then\
                  if #arg == 2 then\
                     self:close()\
                     self.handle_options = false\
                  else\
                     local equals = arg:find \"=\"\
                     if equals then\
                        local name = arg:sub(1, equals - 1)\
                        local option = self:get_option(name)\
\
                        if option.element._maxargs <= 0 then\
                           self:error(\"option '%s' does not take arguments\", name)\
                        end\
\
                        self:invoke(option, name)\
                        self:pass(arg:sub(equals + 1))\
                     else\
                        local option = self:get_option(arg)\
                        self:invoke(option, arg)\
                     end\
                  end\
               else\
                  for i = 2, #arg do\
                     local name = first .. arg:sub(i, i)\
                     local option = self:get_option(name)\
                     self:invoke(option, name)\
\
                     if i ~= #arg and option.element._maxargs > 0 then\
                        self:pass(arg:sub(i + 1))\
                        break\
                     end\
                  end\
               end\
            end\
         end\
      end\
\
      if plain then\
         self:pass(arg)\
      end\
   end\
\
   self:finalize()\
   return self.result\
end\
\
function Parser:error(msg)\
   io.stderr:write((\"%s\\n\\nError: %s\\n\"):format(self:get_usage(), msg))\
   os.exit(1)\
end\
\
-- Compatibility with strict.lua and other checkers:\
local default_cmdline = rawget(_G, \"arg\") or {}\
\
function Parser:_parse(args, error_handler)\
   return ParseState(self, error_handler):parse(args or default_cmdline)\
end\
\
function Parser:parse(args)\
   return self:_parse(args, self.error)\
end\
\
local function xpcall_error_handler(err)\
   return tostring(err) .. \"\\noriginal \" .. debug.traceback(\"\", 2):sub(2)\
end\
\
function Parser:pparse(args)\
   local parse_error\
\
   local ok, result = xpcall(function()\
      return self:_parse(args, function(_, err)\
         parse_error = err\
         error(err, 0)\
      end)\
   end, xpcall_error_handler)\
\
   if ok then\
      return true, result\
   elseif not parse_error then\
      error(result, 0)\
   else\
      return false, parse_error\
   end\
end\
\
return function(...)\
   return Parser(default_cmdline[0]):add_help(true)(...)\
end\
"
, '@'.."C:/Local/luastow/Luarocks\\systree/share/lua/5.3/argparse.lua" ) )

package.preload[ "lib/Parser" ] = assert( (loadstring or load)(
"local argparse = require \"argparse\"\
local lfs = require \"lfs\"\
\
local function trim_directory (path)\
\9path = path:gsub(\"\\\\\", \"/\")\
\9return path:sub(1, path:find(\"/[^/]*$\") - 1)\
end\
\
local function parse_cmd_arguments ()\
\9local cmd_parser = argparse(\"script\", \"A portable GNU Stow implementation in Lua.\")\
\9cmd_parser:argument(\"source_dir\", \"Source directory.\")\
\9cmd_parser:option(\"-t --target\", \"Target directory.\", trim_directory(lfs.currentdir()))\
\9cmd_parser:flag(\"-D --delete\", \"Delete from luastow directory.\")\
\9cmd_parser:flag(\"-R --restow\", \"Restow source directory (remove from target directory, then stow into target directory again.\")\
\9cmd_parser:flag(\"-g --global\", \"Looks for `source_dir' in `/usr/local' (not available on Windows)\")\
\9cmd_parser:flag(\"-v --verbose\", \"Prints debug messages.\")\
\9\9:count \"0-2\"\
\9\9:target \"verbosity\"\
\
\9return cmd_parser:parse()\
end\
\
return {trim_directory = trim_directory,\
        parse_cmd_arguments = parse_cmd_arguments}"
, '@'..".\\lib/Parser.lua" ) )

package.preload[ "lib/Stower" ] = assert( (loadstring or load)(
"local log = require \"lib/log\"\
\
local PATH_SEPARATOR = \"/\"\
local LFS_FILE_EXISTS_ERROR = \"File exists\"\
\
local function create_link (source_file, target_file)\
\9source_file = source_file:gsub(\"\\\\\", \"/\")\
\9target_file = target_file:gsub(\"\\\\\", \"/\")\
\9log.debug(\"Linking: \" .. source_file .. \" -> \" .. target_file)\
\
\9local _, error_msg = lfs.link(target_file, source_file, true)\
\9if _ == nil and error_msg ~= LFS_FILE_EXISTS_ERROR then\
\9\9log.error(error_msg)\
\9\9os.exit(-1)\
\9end\
end\
\
local function create_dir (target_dir)\
\9if lfs.attributes(target_dir) == nil then\
\9\9log.debug(\"Creating directory: \" .. target_dir)\
\
\9\9local _, error_msg = lfs.mkdir(target_dir)\
\9\9if _ == nil and error_msg ~= LFS_FILE_EXISTS_ERROR then\
\9\9\9log.error(error_msg)\
\9\9\9os.exit(-1)\
\9\9end\
\9else\
\9\9log.debug(\"Directory `\" .. target_dir .. \"' already exists! Skipping ...\")\
\9end\
end\
\
local function delete_link (link_name)\
\9log.debug(\"Deleting link: \" .. link_name)\
\
\9local _, error_msg = os.remove(link_name)\
\9if _ == nil then\
\9\9log.error(error_msg)\
\9\9os.exit(-1)\
\9end\
end\
\
local function check_file (filename, path)\
\9return filename:sub(1, 1) ~= \".\" and filename ~= \"..\"\
\9       and lfs.attributes(path .. \"/\" .. filename).mode == \"file\"\
end\
\
local function check_dir (dir_name, path)\
\9return dir_name:sub(1, 1) ~= \".\" and dir_name ~= \"..\"\
\9       and lfs.attributes(path .. \"/\" .. dir_name).mode == \"directory\"\
end\
\
\
local function substitute_path (full_path, replaced_path, new_path)\
\9return new_path .. PATH_SEPARATOR .. full_path:sub(#replaced_path + 2)\
end\
\
local function iterate_dir (dir_name, name_table)\
\9local names = name_table or {}\
\
\9local full_path\
\9for name in lfs.dir(dir_name) do\
\9\9full_path = dir_name .. \"/\" .. name\
\
\9\9if check_file(name, dir_name) then\
\9\9\9names[#names + 1] = {full_path, \"f\"}\
\9\9elseif check_dir(name, dir_name) then\
\9\9\9names[#names + 1] = {full_path, \"d\"}\
\9\9\9iterate_dir(full_path, names)\
\9\9end\
\9end\
\
\9return names\
end\
\
\
local function Stow (args)\
\9local stow_transactions = iterate_dir(args.source_dir)\
\9local dir_transactions = {}\
\9local name\
\
\9-- Put directories into dir_transactions\
\9for i=#stow_transactions, 1, -1 do\
\9\9name = stow_transactions[i]\
\9\9if name[#name] == \"d\" then\
\9\9\9table.insert(dir_transactions, 1, table.remove(stow_transactions, i))\
\9\9end\
\9end\
\
\9-- Check that no file already exists in target directory\
\9for i=1, #stow_transactions do\
\9\9name = stow_transactions[i]\
\9\9-- local target_file = args.target .. PATH_SEPARATOR .. name[1]:sub(#args.source_dir + 2)\
\9\9local target_file = substitute_path(name[1], args.source_dir, args.target)\
\9\9if lfs.attributes(target_file) ~= nil then\
\9\9\9log.error(\"File \" .. target_file .. \" already exists in target directory! Aborting all operations ...\")\
\9\9\9os.exit(-1)\
\9\9end\
\9end\
\
\9-- Create directories\
\9for i=1, #dir_transactions do\
\9\9name = dir_transactions[i]\
\9\9create_dir(substitute_path(name[1], args.source_dir, args.target))\
\9end\
\
\9-- Create links\
\9for i=1, #stow_transactions do\
\9\9name = stow_transactions[i]\
\9\9create_link(substitute_path(name[1], args.source_dir, args.target), name[1])\
\9end\
end\
\
local function Delete (args)\
\9local delete_transactions = iterate_dir(args.source_dir)\
\9local name\
\
\9-- Remove directories\
\9for i=#delete_transactions, 1, -1 do\
\9\9name = delete_transactions[i]\
\9\9if name[#name] == \"d\" then\
\9\9\9table.remove(delete_transactions, i)\
\9\9end\
\9end\
\
\9-- Check that file really exists in target location\
\9for i=1, #delete_transactions do\
\9\9name = delete_transactions[i]\
\9\9local target_link = substitute_path(name[1], args.source_dir, args.target)\
\9\9if lfs.attributes(target_link) == nil then\
\9\9\9log.error(\"Link \" .. target_link .. \" doesn't seem to exist in target directory! Aborting all operations ...\")\
\9\9\9os.exit(-1)\
\9\9end\
\9end\
\
\9-- Delete links\
\9for i=1, #delete_transactions do\
\9\9name = delete_transactions[i]\
\9\9delete_link(substitute_path(name[1], args.source_dir, args.target))\
\9end\
end\
\
return {Stow = Stow,\
        Delete = Delete}"
, '@'..".\\lib/Stower.lua" ) )

local assert = assert
local newproxy = newproxy
local getmetatable = assert( getmetatable )
local setmetatable = assert( setmetatable )
local os_tmpname = assert( os.tmpname )
local os_getenv = assert( os.getenv )
local os_remove = assert( os.remove )
local io_open = assert( io.open )
local string_match = assert( string.match )
local string_sub = assert( string.sub )
local package_loadlib = assert( package.loadlib )

local dirsep = package.config:match( "^([^\n]+)" )
local tmpdir
local function newdllname()
  local tmpname = assert( os_tmpname() )
  if dirsep == "\\" then
    if not string_match( tmpname, "[\\/][^\\/]+[\\/]" ) then
      tmpdir = tmpdir or assert( os_getenv( "TMP" ),
                                 "could not detect temp directory" )
      local first = string_sub( tmpname, 1, 1 )
      local hassep = first == "\\" or first == "/"
      tmpname = tmpdir..((hassep) and "" or "\\")..tmpname
    end
  end
  return tmpname
end
local dllnames = {}

dllnames[ "C:/Local/luastow/Luarocks\\systree/lib/lua/5.3/lfs.dll" ] = function()
  local dll = newdllname()
  local f = assert( io_open( dll, "wb" ) )
  f:write( "MZ�\0\3\0\0\0\4\0\0\0��\0\0�\0\0\0\0\0\0\0@\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\14\31�\14\0�\9�!�\1L�!This program cannot be run in DOS mode.\13\13\
$\0\0\0\0\0\0\0�;\4m�Zj>�Zj>�Zj>�\"�>�Zj>\12:k?�Zj>�\7k?�Zj>\12:i?�Zj>\12:o?�Zj>\12:n?�Zj>&;k?�Zj>�Zk>�Zj>&;n?�Zj>&;j?�Zj>&;h?�Zj>Rich�Zj>\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0PE\0\0L\1\4\0�\127�X\0\0\0\0\0\0\0\0�\0\2!\11\1\14\
\0\30\0\0\0\28\0\0\0\0\0\0�#\0\0\0\16\0\0\0000\0\0\0\0\0\16\0\16\0\0\0\2\0\0\6\0\0\0\0\0\0\0\6\0\0\0\0\0\0\0\0p\0\0\0\4\0\0\0\0\0\0\2\0@\1\0\0\16\0\0\16\0\0\0\0\16\0\0\16\0\0\0\0\0\0\16\0\0\0�8\0\0H\0\0\0\0249\0\0�\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\0\0\4\3\0\0�5\0\0\28\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0�5\0\0@\0\0\0\0\0\0\0\0\0\0\0\0000\0\0L\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0.text\0\0\0.\29\0\0\0\16\0\0\0\30\0\0\0\4\0\0\0\0\0\0\0\0\0\0\0\0\0\0 \0\0`.rdata\0\0\
\17\0\0\0000\0\0\0\18\0\0\0\"\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0@.data\0\0\0\28\4\0\0\0P\0\0\0\2\0\0\0004\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0�.reloc\0\0\4\3\0\0\0`\0\0\0\4\0\0\0006\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0B\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0V�t$\8Wj\0j\1V��\15\0\0��W�\21h0\0\16��\16��t,V�\15\0\0�\21�0\0\16�0�\21|0\0\16PWh�2\0\16V�w\15\0\0��\24�\2\0\0\0_^�j\1V�p\15\0\0��\8�\1\0\0\0_^�́�\8\1\0\0��P\0\0163ĉ�$\4\1\0\0V��$\16\1\0\0�D$\4h\4\1\0\0P�\21�0\0\16��\8��u9V�\13\15\0\0�\21�0\0\16�0�\21|0\0\16PV�\4\15\0\0��\16�\2\0\0\0^��$\4\1\0\0003��q\15\0\0��\8\1\0\0�PV��\14\0\0��$\16\1\0\0��\8�\1\0\0\0^3��L\15\0\0��\8\1\0\0����������������QSVW�|$\20�D$\12Pj\1W��\14\0\0�L$\24����\14Q�\21p0\0\16�؃�\16��u&W�r\14\0\0�\21�0\0\16�0�\21|0\0\16PW�i\14\0\0��\16�C\2_^[YË�+�\15\31�\0\0\0\0\0�\6�v\1�D1���u�K��A\1�I\1��u��X3\0\16j\0h�\0\0\4�\1�\\3\0\16j\1j\0�A\4�`3\0\16j\0�A\8f�d3\0\16h\0\0\0@Sf�A\12�\21\0040\0\16�����uU�\21\0080\0\16S���\21t0\0\16W��\13\0\0��\8��Pt �� t\27V�\21|0\0\16PW��\13\0\0��\12�\2\0\0\0_^[Y�hh3\0\16W�\13\0\0��\8�\2\0\0\0_^[Y�S�\21t0\0\16j\4W�\13\0\0ht3\0\16hع��W�0�\13\0\0j�W�\13\0\0�� �\1\0\0\0_^[Y�����������V�t$\8h\0283\0\16j\1V�\13\0\0��\12��u\12h 2\0\16h$3\0\16�\16�\0��u\21h 2\0\16h43\0\16V�\13\0\0��\0123�j\2PV��\9\0\0��\12^���S�\\$\8Uh\0283\0\16j\1S�k\13\0\0��\12��u\12h(2\0\16h$3\0\16�\16�(��u\21h(2\0\16h43\0\16S�H\13\0\0��\0123�VWj\0j\2S�\25\13\0\0j\0j\0j\3S���\23\13\0\0j\0j\0j\4S���\9\13\0\0h(2\0\16PVWUS��\6\0\0��D_^��t\19j\1S�\12\0\0��\8�\1\0\0\0][�S�l\12\0\0�\21�0\0\16�0�\21|0\0\16Ph�3\0\16S�d\12\0\0��\20�\2\0\0\0][��SVW�|$\16h\0283\0\16j\1W�\12\0\0��\12��u\12h02\0\16h$3\0\16�\16�\24��u\21h02\0\16h43\0\16W�\12\0\0��\0123�j\0j\0j\2W�d\12\0\0j\0j\0j\3W���V\12\0\0h02\0\16PVh�3\0\16SW�A\6\0\0��8��t\20j\1W��\11\0\0��\8�\1\0\0\0_^[�W�\11\0\0�\21�0\0\16�0�\21|0\0\16Ph�3\0\16W�\11\0\0��\20�\2\0\0\0_^[�����������W�|$\8W�{\11\0\0�\21�0\0\16�0�\21|0\0\16Ph�3\0\16h�2\0\16W�n\11\0\0�\21�0\0\16�\0�RPW�Q\11\0\0��$�\3\0\0\0_������������V�t$\8j\0j\1V�\11\0\0P�\21X0\0\16��\16��t*V�\19\11\0\0�\21�0\0\16�0�\21|0\0\16Ph�3\0\16V�\11\11\0\0��\20�\2\0\0\0^�j\1V�\5\11\0\0��\8�\1\0\0\0^��������V�t$\8j\0j\1V�'\11\0\0P�\21T0\0\16��\16��t*V�\
\0\0�\21�0\0\16�0�\21|0\0\16Ph�3\0\16V�\
\0\0��\20�\2\0\0\0^�j\1V�\
\0\0��\8�\1\0\0\0^��������SV�t$\12Wj\0j\1V��\
\0\0j\0hp\27\0\16V���n\
\0\0h\16\1\0\0V�{\
\0\0h�3\0\16hع��V���]\
\0\0j�V�\127\
\0\0���\3\0\0\0\0��4�C\4\0\0\0\0�Q\1f\15\31D\0\0�\1A��u�+�W��\2\1\0\0v\23h�3\0\16V�w\
\0\0��\12�\2\0\0\0_^[ÍC\8h�3\0\16P�\9\0\0��\12�\2\0\0\0_^[�������������̃�\20��P\0\0163ĉD$\16V�t$\28Wj\0j\1V�\8\
\0\0V���|\9\0\0��\16��\1u\0043��9��\8\15W��\15\17\4$j\2V��\9\0\0�f\
\0\0RPj\3V�D$(�T$,��\9\0\0�� �D$\16�T$\20�L$\8QW�\21�0\0\16��\8��t9V�F\9\0\0�\21�0\0\16�0�\21|0\0\16Ph�3\0\16V�>\9\0\0��\20�\2\0\0\0_^�L$\0163��\9\0\0��\20�j\1V�)\9\0\0�L$ ��\8�\1\0\0\0_^3��\9\0\0��\20������������̋D$\8\15�@\6f��y\14� 4\0\16�D$\8��\8\0\0�\0@\0\0t\14�(4\0\16�D$\8��\8\0\0�\0 \0\0�@4\0\16�44\0\16\15D��D$\8�\8\0\0����̋D$\8j\0�0�t$\12�\8\0\0��\12�����������̋D$\8\15�@\4�RP�t$\12�h\8\0\0��\12��������̋D$\8\15�@\8�RP�t$\12�H\8\0\0��\12��������̋D$\8\15�@\
�RP�t$\12�(\8\0\0��\12��������̋D$\8\15�@\12�RP�t$\12�\8\8\0\0��\12��������̋D$\8j\0�p\16�t$\12��\7\0\0��\12����������̋D$\8�p$�p �t$\12��\7\0\0��\12���������̋D$\8�p,�p(�t$\12�\7\0\0��\12���������̋D$\8�p4�p0�t$\12�\7\0\0��\12���������̋D$\8�p\28�p\24�t$\12�i\7\0\0��\12���������̋D$\8\15�@\6P�\2\6\0\0��\4�D$\8�H\7\0\0�������5d0\0\16�t$\8�!\0\0\0��\8�������������̸\16T\0\16����������̃�<��P\0\0163ĉD$8SV�t$LW�|$Lj\0j\1W�C\7\0\0�؍D$\24PS�փ�\20��t,W��\6\0\0ShH4\0\16W��\6\0\0��\16�\2\0\0\0_^[�L$83��:\7\0\0��<�j\2W�\6\0\0��\8��\15��\0\0\0j\0j\2W�}\6\0\0�\13\16P\0\16��\0123��؅�t9f��Ê\17:\16u\26��t\18�Q\1:P\1u\14��\2��\2��u�3��\5\27���\1��t,�\12�\24P\0\16F��u�ht4\0\16W�\6\0\0��\8_^[�L$83��\6\0\0��<ÍD$\12P�\4�\20P\0\16W�Ѓ�\8�^j\2W��\5\0\0��\8��\5t\13j\0j\0W�\27\6\0\0��\12�\16P\0\0163���t63�PW��\5\0\0�D$\20P��\20P\0\16W��j�W�\12\6\0\0�v\1��\24�\28�\0\0\0\0��\16P\0\16��űL$D�\1\0\0\0_^[3��*\6\0\0��<ËD$\12V\15�\0��rt%��\3t\28��\2t\27�t$\28hD3\0\16�t$\16��\5\0\0��\12^�3��\5�\2\0\0\0S�\\$\28W�|$\20��u\23j\2j\0W�\21�0\0\16W�\21�0\0\16��\16��j\0�t$ W�\21�0\0\16��\12SVW�\21�0\0\16��\4P�\21�0\0\16��\0123Ƀ��\15��_[��^�Vj\1�t$\12��\4\0\0����\8�>\0u\17�F\4��t\
P�\21P0\0\16��\4�\6\1\0\0\0003�^����������������V�t$\8h�3\0\16V�(\5\0\0j\0j\0V��\4\0\0j\0hp\27\0\16V�\4\0\0h�3\0\16j�V��\4\0\0j\0h�\26\0\16V�\4\0\0h\0004\0\16j�V�\4\0\0��Dh\0084\0\16j�V�\4\0\0j\0h�\26\0\16V�s\4\0\0h\0164\0\16j�V�\4\0\0��$�\1\0\0\0^��������������́�,\1\0\0��P\0\0163ĉ�$(\1\0\0VW��$8\1\0\0h�3\0\16j\1W�\4\0\0����\12�>\0t\16h�3\0\16j\1W�O\4\0\0��\12�F\4��uZ�D$\8P�F\8P�\21\\0\0\16��\8�F\4���u\127W��\3\0\0�\21�0\0\16�0�\21|0\0\16PW��\3\0\0��\16�\6\1\0\0\0�\2\0\0\0_^��$(\1\0\0003��(\4\0\0��,\1\0\0ÍL$\8QP�\21`0\0\16��\8���u+�v\4�\21P0\0\16��\4�\6\1\0\0\0003�_^��$(\1\0\0003���\3\0\0��,\1\0\0ÍD$,PW�S\3\0\0��$8\1\0\0��\8�\1\0\0\0_^3��\3\0\0��,\1\0\0���VW�|$\12h�1\0\16j\0�t$\28W�\3\0\0��\16�4��1\0\16�t$\20�\21�0\0\16��\4P�\21�0\0\16����\8���tYj\1W��\2\0\0003Ƀ�\0089\13�1\0\16t\0273�9��1\0\16t\"A�\4�\0\0\0\0���1\0\16\0u�W�\2\0\0��\4_�\2\0\0\0^��4��1\0\16W�\2\0\0��\8�\2\0\0\0_^��\21�0\0\16W�0�\2\0\0V�\21|0\0\16Ph�3\0\16W�\127\2\0\0�ƙRPW�h\2\0\0�� �\3\0\0\0_^��Vht3\0\16j\1�t$\16�\2\0\0����\12�\6���t\13P�\02180\0\16�\6����3�^���V�t$\8ht3\0\16V�\2\0\0j\0j\0V�6\2\0\0j\0hP\29\0\16V�\23\2\0\0h\0244\0\16j�V�4\2\0\0h\0084\0\16j�V�'\2\0\0j\0hP\29\0\16V��\1\0\0��Dh\0164\0\16j�V�\
\2\0\0��\12�\1\0\0\0^���������V�t$\8V�����V�\127����\15\16\5�5\0\16��\8h�\0\0\0��\8�\15\17\4$V��\1\0\0j\13j\0V�\1\0\0j\0h�1\0\16V��\1\0\0j�V�J\1\0\0h�5\0\16V�\1\0\0V�\0\0\0��<�\1\0\0\0^�������̋D$\4�\5\0P\0\16----�\5\4P\0\16----�\5\8P\0\16-�\0\1\0\0t\21�\5\0P\0\16r�\5\3P\0\16r�\5\6P\0\16r��y\21�\5\1P\0\16w�\5\4P\0\16w�\5\7P\0\16w�@�\0P\0\16t\21�\5\2P\0\16x�\5\5P\0\16x�\5\8P\0\16x��������������V�t$\8h�4\0\16V��\0\0\0h�4\0\16V�\0\0\0j�V��\0\0\0h�4\0\16V�\0\0\0h�4\0\16V�\0\0\0j�V��\0\0\0h`5\0\16V�\0\0\0hl5\0\16V�{\0\0\0��@j�V�\0\0\0��\8^���������̍D$\12Pj\0�t$\16j��t$\20�*����\8�p\4��\1Q�\21�0\0\16�����\28��\15H����%D1\0\16�%@1\0\16�%<1\0\16�%81\0\16�%41\0\16�%01\0\16�%,1\0\16�%(1\0\16�%$1\0\16�% 1\0\16�%\0281\0\16�%\0241\0\16�%\0201\0\16�%\0161\0\16�%\0121\0\16�%\0081\0\16�%\0041\0\16�%\0001\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16;\13�P\0\16�u\2����\3\4\0\0��������̃=�S\0\16\0t7U���\8����\28$�\15,\4$�Ã=�S\0\16\0t\27��\4�<$Xf��\127f��\127tӍ�$\0\0\0\0�I\0U��� ������T$\24�|$\16�l$\16�T$\24�D$\16��t<���y\30�\28$�\12$��\0\0\0������\127��\0�T$\20��\0�,�\28$�\12$�����\127��\0�T$\20��\0�\20�T$\20�����\127u��\\$\24�\\$\24��U��E\12��\0t3��\1t ��\1t\17��\1t\0053�@�0�\7\0\0�\5�_\7\0\0\15���\31�u\16�u\8�\24\0\0\0Y�\16�}\16\0\15��\15��P��\0\0\0Y]�\12\0j\16hH8\0\16��\
\0\0j\0�\7\0\0Y��u\0073���\0\0\0�\6\0\0�E�\1�]�e�\0�=�S\0\16\0t\7j\7�>\9\0\0�\5�S\0\16\1\0\0\0��\6\0\0��tM�A\
\0\0��\5\0\0�\6\6\0\0h\\1\0\16hX1\0\16�5\11\0\0YY��u)�\6\0\0��t hT1\0\16hP1\0\16�\17\11\0\0YY�\5�S\0\16\2\0\0\0002ۈ]��E������D\0\0\0��\15�d����\8\0\0���>\0t\30V��\7\0\0Y��t\19�u\12j\2�u\8�6���\19\
\0\0���\5�P\0\0163�@�R\
\0\0Ê]��u��;\8\0\0Y�j\12hh8\0\16��\9\0\0��P\0\16��\127\0043��YH��P\0\16�\5\0\0�E�e�\0�=�S\0\16\2t\7j\7�I\8\0\0�\\\6\0\0�\23\5\0\0�\9\0\0�%�S\0\16\0�E������\27\0\0\0j\0�u\8��\7\0\0YY3Ʉ�\15������\9\0\0��B\6\0\0�u��\7\0\0Y�j\12h�8\0\16�k\9\0\0�}\12��u\0159=�P\0\16\127\0073���\0\0\0�e�\0��\1t\
��\2t\5�]\16�1�]\16SW�u\8�\0\0\0���u��\15��\0\0\0SW�u\8��������u��\15��\0\0\0SW�u\8�7\4\0\0���u��\1u\"��u\30SP�u\8�\31\4\0\0SV�u\8����SV�u\8�`\0\0\0��t\5��\3uHSW�u\8�}������u��t5SW�u\8�:\0\0\0���$�M�\1Q�0h\5!\0\16�u\16�u\12�u\8�\1\5\0\0��\24Ëe�3��u��E���������\8\0\0�U��V�5�5\0\16��u\0053�@�\18�u\16���u\12�u\8�O\8\0\0��^]�\12\0U��}\12\1u\5��\2\0\0�u\16�u\12�u\8������\12]�\12\0U��j\0�\21\0160\0\16�u\8�\21\0120\0\16h\9\4\0��\21\0200\0\16P�\21\0240\0\16]�U���$\3\0\0j\23�\8\0\0��t\5j\2Y�)��Q\0\16�\13�Q\0\16�\21�Q\0\16�\29�Q\0\16�5�Q\0\16�=�Q\0\16f�\21�Q\0\16f�\13�Q\0\16f�\29�Q\0\16f�\5�Q\0\16f�%�Q\0\16f�-�Q\0\16��\5�Q\0\16�E\0��Q\0\16�E\4��Q\0\16�E\8��Q\0\16�������\5\0Q\0\16\1\0\1\0��Q\0\16��P\0\16�\5�P\0\16\9\4\0��\5�P\0\16\1\0\0\0�\5�P\0\16\1\0\0\0j\4Xk�\0ǀ�P\0\16\2\0\0\0j\4Xk�\0�\13�P\0\16�L\5�j\4X��\0�\13�P\0\16�L\5�h�5\0\16�������]�U��%�S\0\16\0��$S3�C\9\29�P\0\16j\
�}\7\0\0��\15�r\1\0\0�e�\0003��\13�P\0\16\0023�VW�\29�S\0\16�}�S\15���[�\7�w\4�O\0083ɉW\12�E܋}��E��Genu�E�5ineI�E��E�5ntel�E�3�@S\15���[�]܉\3�E�\11E�\11ǉs\4�K\8�S\12uC�E�%�?�\15=�\6\1\0t#=`\6\2\0t\28=p\6\2\0t\21=P\6\3\0t\14=`\6\3\0t\7=p\6\3\0u\17�=�S\0\16��\1�=�S\0\16�\6�=�S\0\16�}�\7�E�E�|2j\7X3�S\15���[�]܉\3�E��s\4�K\8�S\12�]���\0\2\0\0t\14��\2�=�S\0\16�\3�]�_^�\0\0\16\0tl�\13�P\0\16\4�\5�S\0\16\2\0\0\0�\0\0\0\8tT�\0\0\0\16tM3�\15\1ЉE�U��E�M���\0063Ƀ�\6u2��u.��P\0\16��\8�\5�S\0\16\3\0\0\0��P\0\16�� t\18�� �\5�S\0\16\5\0\0\0��P\0\0163�[��]�U���\20�e�\0�e�\0��P\0\16VW�N�@��\0\0��;�t\13��t\9�У�P\0\16�f�E�P�\21$0\0\16�E�3E�E��\21(0\0\0161E��\21,0\0\0161E��E�P�\02100\0\16�M��E�3M�3M�3�;�u\7�O�@��\16��u\12��\13\17G\0\0��\16\11ȉ\13�P\0\16�щ\13�P\0\16_^��]�U��}\12\1u\18�=�5\0\16\0u\9�u\8�\21 0\0\0163�@]�\12\0h�S\0\16�\21\0000\0\16�h�S\0\16�.\5\0\0Yø�S\0\16�������H\4�\8\4�H\4������H\4�\8\2�H\4�U��E\8V�H<\3�\15�A\20�Q\24\3�\15�A\6k�(\3�;�t\25�M\12;J\12r\
�B\8\3B\12;�r\12��(;�u�3�^]Ë����\4\0\0��u\0032��d�\24\0\0\0V��S\0\16�P\4�\4;�t\0163����\15�\14��u�2�^ð\1^��w\4\0\0��t\7������\24�c\4\0\0P�\4\0\0Y��t\0032���\4\0\0�\1�j\0��\0\0\0��Y\15����\4\0\0��u\0032���\4\0\0��u\7�\127\4\0\0��\1��u\4\0\0�p\4\0\0�\1�U���\15\4\0\0��u\24�}\12\1u\18�u\16�M\20P�u\8�k\3\0\0�U\20�u\28�u\24�\26\4\0\0YY]���\3\0\0��t\12h�S\0\16�\27\4\0\0Y��#\4\0\0��\15�\18\4\0\0�j\0�\16\4\0\0Y�\
\4\0\0U��}\8\0u\7�\5\9T\0\16\1�\18�����\3\0\0��u\0042�]���\3\0\0��u\
j\0��\3\0\0Y��\1]�U���\12�=\8T\0\16\0t\7�\1�\0\0\0V�u\8��t\5��\1u\127�S\3\0\0��t&��u\"h�S\0\16�\3\0\0Y��u\15h�S\0\16�v\3\0\0Y��tF2��K��P\0\16�u�W��\31��S\0\16j Y+ȃ����3\5�P\0\16�E�E��E������S\0\16�E�E��u�E����_�\5\8T\0\16\1�\1^��]�j\5��\0\0\0�j\8h�8\0\16�C\2\0\0�e�\0�MZ\0\0f9\5\0\0\0\16u]�<\0\0\16��\0\0\0\16PE\0\0uL�\11\1\0\0f9�\24\0\0\16u>�E\8�\0\0\0\16+�PQ����YY��t'�x$\0|!�E������\1�\31�E�\0003Ɂ8\5\0\0�\15����Ëe��E�����2��\12\2\0\0�U���?\2\0\0��t\15�}\8\0u\0093���S\0\16�\1]�U��=\9T\0\16\0t\6�}\12\0u\18�u\8�f\2\0\0�u\8�^\2\0\0YY�\1]ø\24T\0\16�U���$\3\0\0SVj\23��\1\0\0��t\5�M\8�)3�������h�\2\0\0VP�5\12T\0\16��\1\0\0��\12��������������������������|�����x���f������f������f��t���f��p���f��l���f��h�����������E\4�������E\4������ǅ����\1\0\1\0�@�jP�������E�VP�X\1\0\0�E\4��\12�E�\21\0\0@�E�\1\0\0\0�E��\21\0280\0\16V�X��ۍE��E�������\26ۉE����\21\0160\0\16�E�P�\21\0120\0\16��u\13\15����\27�!\5\12T\0\16^[��]�SV�88\0\16�88\0\16;�s\24W�>��t\9���8\0\0\0�׃�\4;�r�_^[�SV�@8\0\16�@8\0\16;�s\24W�>��t\9���\13\0\0\0�׃�\4;�r�_^[��%L1\0\16���h�,\0\16d�5\0\0\0\0�D$\16�l$\16�l$\16+�SVW��P\0\0161E�3�P�e��u��E��E������E��E�d�\0\0\0\0�ËM�d�\13\0\0\0\0Y__^[��]Q��U���u\20�u\16�u\12�u\8h6 \0\16h�P\0\16�)\0\0\0��\24]�3�@�3�9\5�P\0\16\15������%40\0\16�%@0\0\16�%D0\0\16�%H0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�%�0\0\16�\1�3��\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0J>\0\0$=\0\0@=\0\0P=\0\0l=\0\0�=\0\0�=\0\0`>\0\0.>\0\0\20>\0\0�=\0\0�=\0\0�=\0\0�=\0\0002=\0\0\0\0\0\0�>\0\0�>\0\0�>\0\0\0\0\0\0f?\0\0\\?\0\0R?\0\0�?\0\0�?\0\0004?\0\0H?\0\0\0\0\0\0*?\0\0\"?\0\0\0\0\0\0\22?\0\0�>\0\0X@\0\0�?\0\0�?\0\0�?\0\0�?\0\0\2@\0\0$@\0\0@@\0\0\0\0\0\0>?\0\0�>\0\0�?\0\0t?\0\0�>\0\0�>\0\0�>\0\0\0\0\0\0�?\0\0\0\0\0\0\
=\0\0�<\0\0�<\0\0�<\0\0�<\0\0�<\0\0�<\0\0�<\0\0z<\0\0d<\0\0P<\0\0B<\0\0002<\0\0\"<\0\0\18<\0\0\0<\0\0�;\0\0�;\0\0�;\0\0�;\0\0�;\0\0�;\0\0�;\0\0t;\0\0b;\0\0R;\0\0F;\0\0006;\0\0&;\0\0\24;\0\0\0\0\0\0�,\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0touch\0\0\0lock_dir\0\0\0\0\0\0\0\0\0�\0\0\0@\0\0\0162\0\16\0242\0\16\0\0\0\0\0\0\0\0�2\0\16p\24\0\16�2\0\16\0\16\0\16�2\0\16`\16\0\16�2\0\0160\21\0\01682\0\16 \20\0\16(2\0\16�\18\0\16�2\0\16p\20\0\16�2\0\16�\20\0\16�2\0\16p\24\0\16 2\0\16P\18\0\16p1\0\16�\21\0\01602\0\16`\19\0\16x1\0\16\0\17\0\16\0\0\0\0\0\0\0\0binary\0\0text\0\0\0\0setmode\0lock\0\0\0\0unlock\0\0link\0\0\0\0mode\0\0\0\0dev\0ino\0nlink\0\0\0uid\0gid\0rdev\0\0\0\0access\0\0modification\0\0\0\0change\0\0size\0\0\0\0permissions\0attributes\0\0chdir\0\0\0currentdir\0\0dir\0mkdir\0\0\0rmdir\0\0\0symlinkattributes\0\0\0%s: %s\0\0Unable to change working directory to '%s'\
%s\
\0\0FILE*\0\0\0%s: not a file\0\0%s: closed file\0%s: invalid mode\0\0\0\0/lockfile.lfs\0\0\0File exists\0lock metatable\0\0%s\0\0u\0\0\0make_link is not supported on Windows\0\0\0directory metatable\0closed directory\0\0\0\0path too long: %s\0\0\0%s/*\0\0\0\0next\0\0\0\0close\0\0\0__index\0__gc\0\0\0\0free\0\0\0\0file\0\0\0\0directory\0\0\0char device\0other\0\0\0cannot obtain information from file `%s'\0\0\0\0invalid attribute name\0\0_COPYRIGHT\0\0Copyright (C) 2003-2012 Kepler Project\0\0_DESCRIPTION\0\0\0\0LuaFileSystem is a Lua library developed to complement the set of functions related to file systems offered by the standard Lua distribution\0\0\0\0_VERSION\0\0\0\0LuaFileSystem 1.6.3\0lfs\0\0\0\0\0\0\0\0\0\0p\127@\0\0\0\0�P\0\16\0Q\0\16\0\0\0\0\0\0\0\0�\127�X\0\0\0\0\13\0\0\0\0\2\0\00046\0\0004(\0\0\0\0\0\0h\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0�P\0\01606\0\16\1\0\0\0L1\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0�,\0\0\0\0\0\0\0\16\0\0.\29\0\0.text$mn\0\0\0\0\0000\0\0L\1\0\0.idata$5\0\0\0\0L1\0\0\4\0\0\0.00cfg\0\0P1\0\0\4\0\0\0.CRT$XCA\0\0\0\0T1\0\0\4\0\0\0.CRT$XCZ\0\0\0\0X1\0\0\4\0\0\0.CRT$XIA\0\0\0\0\\1\0\0\4\0\0\0.CRT$XIZ\0\0\0\0`1\0\0\4\0\0\0.CRT$XPA\0\0\0\0d1\0\0\4\0\0\0.CRT$XPZ\0\0\0\0h1\0\0\4\0\0\0.CRT$XTA\0\0\0\0l1\0\0\4\0\0\0.CRT$XTZ\0\0\0\0p1\0\0�\4\0\0.rdata\0\00006\0\0\4\0\0\0.rdata$sxdata\0\0\00046\0\0\0\2\0\0.rdata$zzzdbg\0\0\00048\0\0\4\0\0\0.rtc$IAA\0\0\0\00088\0\0\4\0\0\0.rtc$IZZ\0\0\0\0<8\0\0\4\0\0\0.rtc$TAA\0\0\0\0@8\0\0\8\0\0\0.rtc$TZZ\0\0\0\0H8\0\0�\0\0\0.xdata$x\0\0\0\0�8\0\0H\0\0\0.edata\0\0\0249\0\0�\0\0\0.idata$2\0\0\0\0�9\0\0\20\0\0\0.idata$3\0\0\0\0�9\0\0L\1\0\0.idata$4\0\0\0\0\24;\0\0�\5\0\0.idata$6\0\0\0\0\0P\0\0�\0\0\0.data\0\0\0�P\0\0t\3\0\0.bss\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0����\0\0\0\0����\0\0\0\0����\0\0\0\0E\"\0\16\0\0\0\0����\0\0\0\0����\0\0\0\0����\0\0\0\0�\"\0\16\0\0\0\0����\0\0\0\0����\0\0\0\0�����#\0\16�#\0\16\0\0\0\0����\0\0\0\0����\0\0\0\0����f*\0\16y*\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0�\127�X\0\0\0\0\0029\0\0\1\0\0\0\1\0\0\0\1\0\0\0�8\0\0�8\0\0\0009\0\0�\29\0\0\
9\0\0\0\0lfs.dll\0luaopen_lfs\0\0\0�:\0\0\0\0\0\0\0\0\0\0\26=\0\0�0\0\0�9\0\0\0\0\0\0\0\0\0\0t>\0\0\0000\0\0\12:\0\0\0\0\0\0\0\0\0\0�>\0\0@0\0\0H:\0\0\0\0\0\0\0\0\0\0b@\0\0|0\0\0t:\0\0\0\0\0\0\0\0\0\0�@\0\0�0\0\0<:\0\0\0\0\0\0\0\0\0\0�@\0\0p0\0\0\28:\0\0\0\0\0\0\0\0\0\0�@\0\0P0\0\0�:\0\0\0\0\0\0\0\0\0\0�@\0\0�0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0J>\0\0$=\0\0@=\0\0P=\0\0l=\0\0�=\0\0�=\0\0`>\0\0.>\0\0\20>\0\0�=\0\0�=\0\0�=\0\0�=\0\0002=\0\0\0\0\0\0�>\0\0�>\0\0�>\0\0\0\0\0\0f?\0\0\\?\0\0R?\0\0�?\0\0�?\0\0004?\0\0H?\0\0\0\0\0\0*?\0\0\"?\0\0\0\0\0\0\22?\0\0�>\0\0X@\0\0�?\0\0�?\0\0�?\0\0�?\0\0\2@\0\0$@\0\0@@\0\0\0\0\0\0>?\0\0�>\0\0�?\0\0t?\0\0�>\0\0�>\0\0�>\0\0\0\0\0\0�?\0\0\0\0\0\0\
=\0\0�<\0\0�<\0\0�<\0\0�<\0\0�<\0\0�<\0\0�<\0\0z<\0\0d<\0\0P<\0\0B<\0\0002<\0\0\"<\0\0\18<\0\0\0<\0\0�;\0\0�;\0\0�;\0\0�;\0\0�;\0\0�;\0\0�;\0\0t;\0\0b;\0\0R;\0\0F;\0\0006;\0\0&;\0\0\24;\0\0\0\0\0\0E\0lua_gettop\0\0_\0lua_pushvalue\0K\0lua_isstring\0\0�\0lua_type\0\0{\0lua_tolstring\0\127\0lua_touserdata\0\0[\0lua_pushnil\0X\0lua_pushinteger\0]\0lua_pushstring\0\0W\0lua_pushfstring\0V\0lua_pushcclosure\0\0U\0lua_pushboolean\0:\0lua_getfield\0\0005\0lua_createtable\0R\0lua_newuserdata\0m\0lua_setglobal\0r\0lua_settable\0\0l\0lua_setfield\0\0f\0lua_rawset\0\0q\0lua_setmetatable\0\0\15\0luaL_checkversion_\0\0\3\0luaL_argerror\0\9\0luaL_checklstring\0\31\0luaL_optnumber\0\0\29\0luaL_optinteger\0\26\0luaL_newmetatable\0\14\0luaL_checkudata\0\16\0luaL_error\0\0\11\0luaL_checkoption\0\0%\0luaL_setfuncs\0lua53.dll\0�\0CreateFileA\0�\0CloseHandle\0Y\2GetLastError\0\0�\5UnhandledExceptionFilter\0\0[\5SetUnhandledExceptionFilter\0\18\2GetCurrentProcess\0y\5TerminateProcess\0\0{\3IsProcessorFeaturePresent\0>\4QueryPerformanceCounter\0\19\2GetCurrentProcessId\0\23\2GetCurrentThreadId\0\0�\2GetSystemTimeAsFileTime\0\26\1DisableThreadLibraryCalls\0X\3InitializeSListHead\0t\3IsDebuggerPresent\0KERNEL32.dll\0\0%\0__std_type_info_destroy_list\0\0H\0memset\0\0005\0_except_handler4_common\0VCRUNTIME140.dll\0\0#\0_errno\0\0&\0_fileno\0�\0fseek\0�\0ftell\0\13\0__stdio_common_vsprintf\0g\0strerror\0\0\24\0free\0\0\25\0malloc\0\0\31\0_stat64\0;\0_getcwd\0\2\0_chdir\0\0\25\0_mkdir\0\0\26\0_rmdir\0\0\5\0_findclose\0\0D\0_locking\0\0W\0_setmode\0\0\9\0_findfirst64i32\0\13\0_findnext64i32\0\0005\0_utime64\0\0008\0_initterm\0009\0_initterm_e\0A\0_seh_filter_dll\0\25\0_configure_narrow_argv\0\0005\0_initialize_narrow_environment\0\0006\0_initialize_onexit_table\0\0$\0_execute_onexit_table\0\23\0_cexit\0\0api-ms-win-crt-runtime-l1-1-0.dll\0api-ms-win-crt-stdio-l1-1-0.dll\0api-ms-win-crt-heap-l1-1-0.dll\0\0api-ms-win-crt-filesystem-l1-1-0.dll\0\0api-ms-win-crt-time-l1-1-0.dll\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0---------\0\0\0\0\0\0\0@2\0\16�\22\0\16H2\0\16\16\23\0\16L2\0\0160\23\0\16P2\0\16P\23\0\16X2\0\16p\23\0\16\\2\0\16�\23\0\16`2\0\16�\23\0\16h2\0\16�\23\0\16p2\0\16�\23\0\16�2\0\16\16\24\0\16�2\0\0160\24\0\16�2\0\16P\24\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0�\25�DN�@�u�\0\0\1\0\0\0����\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\16\0\0\\\1\0\0\0210(00070g0�0�0�0!161>1{1�1�1�1�1�1�1�1�1\0192 2V2j2o2|2�2�2�2�2�2�2\
3<3D3J3h3|3�3�3�3�3�3�3�3\0004-454;4@4L4�4�4�4�4�4�4�4\0035D5\\5�5�5�5O6b6j6p6�6�6�6�6r8�8�8�8\0319^9h9�9�9�9�9,:\\:c:u:�:�:�:�:�:\8;\23;\";2;A;L;w;�;�;�;�;�;\29<.<�<�<�<�<�<�<�<\3=\26=)=/=R=p=�=�=�=�=�=�=\5>,>?>f>p>z>�>�>�>�>�>�>�>�>�>�>�>�>\4?\15?\"?-?q?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?\0\0\0 \0\0\24\1\0\0\0020\0080\0140\0200\0260 0&0,02080R0n0[1�1�1�1�1�1�1�182U2_2m2\1272�2�2�2�3�3)424=4D4d4j4p4v4|4�4�4�4�4�4�4�4�4�4�4�4�4�4�4�4�4�4\0155\0315/585J5X5s5~5\0186\0276#6_6s6z6�6�6�6�6�6�6\0147\0267)727?7n7v7�7�7�7�7�7�758�8)9_9�9�9�9�9�9�9�9\4:\25: :&:8:B:�:�:�:\2;�;�;�;�;�;�;\31<$<I<Q<n<�<�<�<�<�<�<�<�<\0=\6=\12=\18=\24=\30=$=\0000\0\0X\0\0\0L1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1�1\0002\0042�5�5�5\0006\0086`8�8�8�8�8�8\0P\0\0008\0\0\0\0160\0200\0240\0280 0$0(0,0004080<0@0D0H0L0P0T0X0\\0`0d0h0l0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" )
  f:close()
  local sentinel = newproxy and newproxy( true )
                            or setmetatable( {}, { __gc = true } )
  getmetatable( sentinel ).__gc = function() os_remove( dll ) end
  dllnames[ "C:/Local/luastow/Luarocks\\systree/lib/lua/5.3/lfs.dll" ] = function()
    local _ = sentinel
    return dll
  end
  return dll
end

package.preload[ "lfs" ] = function()
  local dll = dllnames[ "C:/Local/luastow/Luarocks\\systree/lib/lua/5.3/lfs.dll" ]()
  local loader = assert( package_loadlib( dll, "luaopen_lfs" ) )
  return loader( "lfs", dll )
end

end

assert( (loadstring or load)(
"local lfs = require \"lfs\"\
local log = require \"lib/log\"\
\
local Parser = require \"lib/Parser\"\
local Stower = require \"lib/Stower\"\
\
local PATH_SEPARATOR = package.config:sub(1, 1)\
local ON_WINDOWS = PATH_SEPARATOR == \"\\\\\"\
local LUASTOW_DEFAULT_DIR = \"/usr/local/luastow\"\
\
\
local args = Parser.parse_cmd_arguments()\
\
do -- Handle command-line arguments and options\
\9if args.global then\
\9\9if ON_WINDOWS then\
\9\9\9log.error(\"Sorry but this feature isn't available on Windows!\")\
\9\9\9os.exit(-1)\
\9\9end\
\
\9\9if lfs.chdir(LUASTOW_DEFAULT_DIR) == nil then\
\9\9\9log.error(\"Default luastow directory (`/usr/local/luastow') doesn't seem to exist!\")\
\9\9\9os.exit(-1)\
\9\9else\
\9\9\9-- Go to default luastow directory, and look for a directory that matches `source_dir'\
\9\9\9local _source_dir\
\9\9\9for dir in lfs.dir(lfs.currentdir()) do\
\9\9\9\9print(\"checking \" .. dir)\
\9\9\9\9if dir:find(args.source_dir) ~= nil then\
\9\9\9\9\9_source_dir = LUASTOW_DEFAULT_DIR .. PATH_SEPARATOR .. dir\
\9\9\9\9end\
\9\9\9end\
\
\9\9\9if _source_dir == nil then\
\9\9\9\9log.error(\"Source dir `\" .. args.source_dir .. \"' was not found in \" .. LUASTOW_DEFAULT_DIR .. \"!\")\
\9\9\9\9os.exit(-1)\
\9\9\9else\
\9\9\9\9args.source_dir = _source_dir\
\9\9\9\9args.target = Parser.trim_directory(LUASTOW_DEFAULT_DIR)\
\9\9\9end\
\9\9end\
\9else\
\9\9-- Handle `source_dir' argument\
\9\9local _ = lfs.attributes(args.source_dir)\
\9\9if _ == nil then\
\9\9\9log.error(\"Source `\" .. lfs.currentdir() .. PATH_SEPARATOR .. args.source_dir .. \"' doesn't seem to exist!\")\
\9\9\9os.exit(-1)\
\9\9elseif _.mode ~= \"directory\" then\
\9\9\9log.error(\"Source must be a directory!\")\
\9\9\9os.exit(-1)\
\9\9end\
\9\9args.source_dir = lfs.currentdir() .. PATH_SEPARATOR .. args.source_dir\
\
\9\9-- Handle `--target'\
\9\9if args.target == \".\" then args.target = lfs.currentdir() end\
\9\9if args.target == \"..\" then args.target = Parser.trim_directory(lfs.currentdir()) end\
\9\9_ = lfs.attributes(args.target)\
\9\9if _ == nil then\
\9\9\9log.error(\"Target `\" .. lfs.currentdir() .. PATH_SEPARATOR .. args.target .. \"' doesn't seem to exist!\")\
\9\9\9os.exit(-1)\
\9\9elseif _.mode ~= \"directory\" then\
\9\9\9log.error(\"Target must be a directory!\")\
\9\9\9os.exit(-1)\
\9\9end\
\9end\
\
\9-- Handle `--verbose'\
\9local _verbosity_levels = {\"error\", \"debug\", \"trace\"}\
\9-- Keep in mind field `verbosity' starts at 0\
\9log.level = _verbosity_levels[args.verbosity + 1]\
\
\9-- Handle `--delete' and `--restow'\
\9if args.restow and args.delete then\
\9\9log.error(\"--delete and --restow cannot both be set to true!\")\
\9\9os.exit(-1)\
\9end\
end\
\
if args.verbosity >= 2 then\
\9log.trace(\"Starting Luastow using these options:\")\
\9local _ = {}\
\9for k, v in pairs(args) do\
\9\9_[#_ + 1] = \"\\t\" .. k .. \" = \" .. tostring(v)\
\9end\
\9print(\"{\\n\" .. table.concat(_, \"\\n\") .. \"\\n}\")\
end\
\
do -- Decide what to do\
\9if args.restow then\
\9\9Stower.Delete(args)\
\9\9Stower.Stow(args)\
\9elseif args.delete then\
\9\9Stower.Delete(args)\
\9else\
\9\9Stower.Stow(args)\
\9end\
\9log.trace(\"Thank you for using Luastow!\")\
end"
, '@'.."luastow.lua" ) )( ... )

