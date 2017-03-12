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
  f:write( "MZ\0\3\0\0\0\4\0\0\0ÿÿ\0\0¸\0\0\0\0\0\0\0@\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\14\31º\14\0´\9Í!¸\1LÍ!This program cannot be run in DOS mode.\13\13\
$\0\0\0\0\0\0\0Û;\4mŸZj>ŸZj>ŸZj>–\"ù>•Zj>\12:k?Zj>ò\7k?Zj>\12:i?Zj>\12:o?”Zj>\12:n?”Zj>&;k?œZj>ŸZk>ÎZj>&;n?Zj>&;j?Zj>&;h?Zj>RichŸZj>\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0PE\0\0L\1\4\0›\127ÀX\0\0\0\0\0\0\0\0à\0\2!\11\1\14\
\0\30\0\0\0\28\0\0\0\0\0\0ÿ#\0\0\0\16\0\0\0000\0\0\0\0\0\16\0\16\0\0\0\2\0\0\6\0\0\0\0\0\0\0\6\0\0\0\0\0\0\0\0p\0\0\0\4\0\0\0\0\0\0\2\0@\1\0\0\16\0\0\16\0\0\0\0\16\0\0\16\0\0\0\0\0\0\16\0\0\0Ğ8\0\0H\0\0\0\0249\0\0´\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0`\0\0\4\3\0\0 5\0\0\28\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0À5\0\0@\0\0\0\0\0\0\0\0\0\0\0\0000\0\0L\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0.text\0\0\0.\29\0\0\0\16\0\0\0\30\0\0\0\4\0\0\0\0\0\0\0\0\0\0\0\0\0\0 \0\0`.rdata\0\0\
\17\0\0\0000\0\0\0\18\0\0\0\"\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0@.data\0\0\0\28\4\0\0\0P\0\0\0\2\0\0\0004\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0À.reloc\0\0\4\3\0\0\0`\0\0\0\4\0\0\0006\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0B\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0V‹t$\8Wj\0j\1Vèö\15\0\0‹øWÿ\21h0\0\16ƒÄ\16…Àt,Vè€\15\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16PWhì2\0\16Vèw\15\0\0ƒÄ\24¸\2\0\0\0_^Ãj\1Vèp\15\0\0ƒÄ\8¸\1\0\0\0_^ÃÌì\8\1\0\0¡„P\0\0163Ä‰„$\4\1\0\0V‹´$\16\1\0\0D$\4h\4\1\0\0Pÿ\21¨0\0\16ƒÄ\8…Àu9Vè\13\15\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16PVè\4\15\0\0ƒÄ\16¸\2\0\0\0^‹Œ$\4\1\0\0003Ìèq\15\0\0Ä\8\1\0\0ÃPVèß\14\0\0‹Œ$\16\1\0\0ƒÄ\8¸\1\0\0\0^3ÌèL\15\0\0Ä\8\1\0\0ÃÌÌÌÌÌÌÌÌÌÌÌÌÌÌÌQSVW‹|$\20D$\12Pj\1Wèñ\14\0\0‹L$\24‹ğƒÁ\14Qÿ\21p0\0\16‹ØƒÄ\16…Ûu&Wèr\14\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16PWèi\14\0\0ƒÄ\16C\2_^[YÃ‹Ë+Î\15\31„\0\0\0\0\0Š\6v\1ˆD1ÿ„ÀuóKÿŠA\1I\1„Àuö¡X3\0\16j\0h€\0\0\4‰\1¡\\3\0\16j\1j\0‰A\4¡`3\0\16j\0‰A\8f¡d3\0\16h\0\0\0@Sf‰A\12ÿ\21\0040\0\16‹ğƒşÿuUÿ\21\0080\0\16S‹ğÿ\21t0\0\16WèÖ\13\0\0ƒÄ\8ƒşPt ƒş t\27Vÿ\21|0\0\16PWèÇ\13\0\0ƒÄ\12¸\2\0\0\0_^[YÃhh3\0\16Wè¯\13\0\0ƒÄ\8¸\2\0\0\0_^[YÃSÿ\21t0\0\16j\4Wè·\13\0\0ht3\0\16hØ¹ğÿW‰0è™\13\0\0jşWè»\13\0\0ƒÄ ¸\1\0\0\0_^[YÃÌÌÌÌÌÌÌÌÌÌV‹t$\8h\0283\0\16j\1Vè¼\13\0\0ƒÄ\12…Àu\12h 2\0\16h$3\0\16ë\16‹\0…Àu\21h 2\0\16h43\0\16Vè™\13\0\0ƒÄ\0123Àj\2PVèç\9\0\0ƒÄ\12^ÃÌÌS‹\\$\8Uh\0283\0\16j\1Sèk\13\0\0ƒÄ\12…Àu\12h(2\0\16h$3\0\16ë\16‹(…íu\21h(2\0\16h43\0\16SèH\13\0\0ƒÄ\0123íVWj\0j\2Sè\25\13\0\0j\0j\0j\3S‹øè\23\13\0\0j\0j\0j\4S‹ğè\9\13\0\0h(2\0\16PVWUSèø\6\0\0ƒÄD_^…Àt\19j\1Sè›\12\0\0ƒÄ\8¸\1\0\0\0][ÃSèl\12\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16Ph„3\0\16Sèd\12\0\0ƒÄ\20¸\2\0\0\0][ÃÌSVW‹|$\16h\0283\0\16j\1Wèª\12\0\0ƒÄ\12…Àu\12h02\0\16h$3\0\16ë\16‹\24…Ûu\21h02\0\16h43\0\16Wè‡\12\0\0ƒÄ\0123Ûj\0j\0j\2Wèd\12\0\0j\0j\0j\3W‹ğèV\12\0\0h02\0\16PVhˆ3\0\16SWèA\6\0\0ƒÄ8…Àt\20j\1Wèæ\11\0\0ƒÄ\8¸\1\0\0\0_^[ÃWè¶\11\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16Ph„3\0\16Wè®\11\0\0ƒÄ\20¸\2\0\0\0_^[ÃÌÌÌÌÌÌÌÌÌÌW‹|$\8Wè{\11\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16PhŒ3\0\16hä2\0\16Wèn\11\0\0ÿ\21€0\0\16‹\0™RPWèQ\11\0\0ƒÄ$¸\3\0\0\0_ÃÌÌÌÌÌÌÌÌÌÌÌV‹t$\8j\0j\1Vè‡\11\0\0Pÿ\21X0\0\16ƒÄ\16…Àt*Vè\19\11\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16Ph„3\0\16Vè\11\11\0\0ƒÄ\20¸\2\0\0\0^Ãj\1Vè\5\11\0\0ƒÄ\8¸\1\0\0\0^ÃÌÌÌÌÌÌÌV‹t$\8j\0j\1Vè'\11\0\0Pÿ\21T0\0\16ƒÄ\16…Àt*Vè³\
\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16Ph„3\0\16Vè«\
\0\0ƒÄ\20¸\2\0\0\0^Ãj\1Vè¥\
\0\0ƒÄ\8¸\1\0\0\0^ÃÌÌÌÌÌÌÌSV‹t$\12Wj\0j\1VèÅ\
\0\0j\0hp\27\0\16V‹øèn\
\0\0h\16\1\0\0Vè{\
\0\0h´3\0\16hØ¹ğÿV‹Øè]\
\0\0jşVè\127\
\0\0‹ÏÇ\3\0\0\0\0ƒÄ4ÇC\4\0\0\0\0Q\1f\15\31D\0\0Š\1A„Àuù+ÊWù\2\1\0\0v\23hÜ3\0\16Vèw\
\0\0ƒÄ\12¸\2\0\0\0_^[ÃC\8hğ3\0\16Pè‰\9\0\0ƒÄ\12¸\2\0\0\0_^[ÃÌÌÌÌÌÌÌÌÌÌÌÌÌƒì\20¡„P\0\0163Ä‰D$\16V‹t$\28Wj\0j\1Vè\8\
\0\0V‹øè|\9\0\0ƒÄ\16ƒø\1u\0043Éë9ƒì\8\15WÀò\15\17\4$j\2Vèç\9\0\0èf\
\0\0RPj\3V‰D$(‰T$,èÖ\9\0\0ƒÄ ‰D$\16‰T$\20L$\8QWÿ\21È0\0\16ƒÄ\8…Àt9VèF\9\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16Ph„3\0\16Vè>\9\0\0ƒÄ\20¸\2\0\0\0_^‹L$\0163Ìè§\9\0\0ƒÄ\20Ãj\1Vè)\9\0\0‹L$ ƒÄ\8¸\1\0\0\0_^3Ìè†\9\0\0ƒÄ\20ÃÌÌÌÌÌÌÌÌÌÌÌÌ‹D$\8\15·@\6f…Ày\14¸ 4\0\16‰D$\8é×\8\0\0©\0@\0\0t\14¸(4\0\16‰D$\8éÂ\8\0\0©\0 \0\0¹@4\0\16¸44\0\16\15DÁ‰D$\8é§\8\0\0ÌÌÌÌÌ‹D$\8j\0ÿ0ÿt$\12è‹\8\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌÌÌÌ‹D$\8\15·@\4™RPÿt$\12èh\8\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌ‹D$\8\15¿@\8™RPÿt$\12èH\8\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌ‹D$\8\15¿@\
™RPÿt$\12è(\8\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌ‹D$\8\15¿@\12™RPÿt$\12è\8\8\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌ‹D$\8j\0ÿp\16ÿt$\12èê\7\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌÌÌ‹D$\8ÿp$ÿp ÿt$\12èÉ\7\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌÌ‹D$\8ÿp,ÿp(ÿt$\12è©\7\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌÌ‹D$\8ÿp4ÿp0ÿt$\12è‰\7\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌÌ‹D$\8ÿp\28ÿp\24ÿt$\12èi\7\0\0ƒÄ\12ÃÌÌÌÌÌÌÌÌÌ‹D$\8\15·@\6Pè\2\6\0\0ƒÄ\4‰D$\8éH\7\0\0ÌÌÌÌÌÌÿ5d0\0\16ÿt$\8è!\0\0\0ƒÄ\8ÃÌÌÌÌÌÌÌÌÌÌÌÌÌ¸\16T\0\16ÃÌÌÌÌÌÌÌÌÌÌƒì<¡„P\0\0163Ä‰D$8SV‹t$LW‹|$Lj\0j\1WèC\7\0\0‹ØD$\24PSÿÖƒÄ\20…Àt,WèÌ\6\0\0ShH4\0\16WèÒ\6\0\0ƒÄ\16¸\2\0\0\0_^[‹L$83Ìè:\7\0\0ƒÄ<Ãj\2Wè†\6\0\0ƒÄ\8…À\15„ˆ\0\0\0j\0j\2Wè}\6\0\0‹\13\16P\0\16ƒÄ\0123ö‹Ø…Ét9f‹ÃŠ\17:\16u\26„Òt\18ŠQ\1:P\1u\14ƒÁ\2ƒÀ\2„Òuä3Àë\5\27ÀƒÈ\1…Àt,‹\12õ\24P\0\16F…ÉuÉht4\0\16Wè²\6\0\0ƒÄ\8_^[‹L$83Ìè³\6\0\0ƒÄ<ÃD$\12P‹\4õ\20P\0\16WÿĞƒÄ\8ë^j\2Wèñ\5\0\0ƒÄ\8ƒø\5t\13j\0j\0Wè\27\6\0\0ƒÄ\12¡\16P\0\0163ö…Àt63ÛPWèæ\5\0\0D$\20P‹ƒ\20P\0\16WÿĞjıWè\12\6\0\0v\1ƒÄ\24\28õ\0\0\0\0‹ƒ\16P\0\16…ÀuÌ‹L$D¸\1\0\0\0_^[3Ìè*\6\0\0ƒÄ<Ã‹D$\12V\15¾\0ƒèrt%ƒè\3t\28ƒè\2t\27ÿt$\28hD3\0\16ÿt$\16èë\5\0\0ƒÄ\12^Ã3öë\5¾\2\0\0\0S‹\\$\28W‹|$\20…Ûu\23j\2j\0Wÿ\21À0\0\16Wÿ\21¬0\0\16ƒÄ\16‹Øj\0ÿt$ Wÿ\21À0\0\16ƒÄ\12SVWÿ\21¼0\0\16ƒÄ\4Pÿ\21´0\0\16ƒÄ\0123Éƒøÿ\15•Á_[‹Á^ÃVj\1ÿt$\12èô\4\0\0‹ğƒÄ\8ƒ>\0u\17‹F\4…Àt\
Pÿ\21P0\0\16ƒÄ\4Ç\6\1\0\0\0003À^ÃÌÌÌÌÌÌÌÌÌÌÌÌÌÌÌV‹t$\8h´3\0\16Vè(\5\0\0j\0j\0VèÖ\4\0\0j\0hp\27\0\16Vè·\4\0\0hø3\0\16jşVèÔ\4\0\0j\0h \26\0\16Vè\4\0\0h\0004\0\16jşVèº\4\0\0ƒÄDh\0084\0\16jşVèª\4\0\0j\0h \26\0\16Vès\4\0\0h\0164\0\16jşVè\4\0\0ƒÄ$¸\1\0\0\0^ÃÌÌÌÌÌÌÌÌÌÌÌÌÌÌì,\1\0\0¡„P\0\0163Ä‰„$(\1\0\0VW‹¼$8\1\0\0h´3\0\16j\1Wè„\4\0\0‹ğƒÄ\12ƒ>\0t\16hÈ3\0\16j\1WèO\4\0\0ƒÄ\12‹F\4…ÀuZD$\8PF\8Pÿ\21\\0\0\16ƒÄ\8‰F\4ƒøÿu\127WèË\3\0\0ÿ\21€0\0\16ÿ0ÿ\21|0\0\16PWèÂ\3\0\0ƒÄ\16Ç\6\1\0\0\0¸\2\0\0\0_^‹Œ$(\1\0\0003Ìè(\4\0\0Ä,\1\0\0ÃL$\8QPÿ\21`0\0\16ƒÄ\8ƒøÿu+ÿv\4ÿ\21P0\0\16ƒÄ\4Ç\6\1\0\0\0003À_^‹Œ$(\1\0\0003Ìèé\3\0\0Ä,\1\0\0ÃD$,PWèS\3\0\0‹Œ$8\1\0\0ƒÄ\8¸\1\0\0\0_^3Ìè¿\3\0\0Ä,\1\0\0ÃÌÌVW‹|$\12h1\0\16j\0ÿt$\28Wè“\3\0\0ƒÄ\16ÿ4…ˆ1\0\16ÿt$\20ÿ\21¼0\0\16ƒÄ\4Pÿ\21°0\0\16‹ğƒÄ\8ƒşÿtYj\1Wèı\2\0\0003ÉƒÄ\0089\131\0\16t\0273À9°ˆ1\0\16t\"A\4\0\0\0\0ƒ¸1\0\16\0uçWè±\2\0\0ƒÄ\4_¸\2\0\0\0^Ãÿ41\0\16Wè¥\2\0\0ƒÄ\8¸\2\0\0\0_^Ãÿ\21€0\0\16W‹0è€\2\0\0Vÿ\21|0\0\16Ph„3\0\16Wè\127\2\0\0‹Æ™RPWèh\2\0\0ƒÄ ¸\3\0\0\0_^ÃÌVht3\0\16j\1ÿt$\16è½\2\0\0‹ğƒÄ\12‹\6ƒøÿt\13Pÿ\02180\0\16Ç\6ÿÿÿÿ3À^ÃÌÌV‹t$\8ht3\0\16Vèˆ\2\0\0j\0j\0Vè6\2\0\0j\0hP\29\0\16Vè\23\2\0\0h\0244\0\16jşVè4\2\0\0h\0084\0\16jşVè'\2\0\0j\0hP\29\0\16Vèğ\1\0\0ƒÄDh\0164\0\16jşVè\
\2\0\0ƒÄ\12¸\1\0\0\0^ÃÌÌÌÌÌÌÌÌV‹t$\8VèåüÿÿVè\127ÿÿÿò\15\16\5ˆ5\0\16ƒÄ\8hˆ\0\0\0ƒì\8ò\15\17\4$VèÛ\1\0\0j\13j\0Vè§\1\0\0j\0h 1\0\16Vèú\1\0\0jÿVèJ\1\0\0h€5\0\16Vè“\1\0\0Vè‘\0\0\0ƒÄ<¸\1\0\0\0^ÃÌÌÌÌÌÌÌ‹D$\4Ç\5\0P\0\16----Ç\5\4P\0\16----Æ\5\8P\0\16-©\0\1\0\0t\21Æ\5\0P\0\16rÆ\5\3P\0\16rÆ\5\6P\0\16r„Ày\21Æ\5\1P\0\16wÆ\5\4P\0\16wÆ\5\7P\0\16w¨@¸\0P\0\16t\21Æ\5\2P\0\16xÆ\5\5P\0\16xÆ\5\8P\0\16xÃÌÌÌÌÌÌÌÌÌÌÌÌÌV‹t$\8hŒ4\0\16VèÂ\0\0\0h˜4\0\16Vè·\0\0\0jıVèß\0\0\0hÀ4\0\16Vè¤\0\0\0hĞ4\0\16Vè™\0\0\0jıVèÁ\0\0\0h`5\0\16Vè†\0\0\0hl5\0\16Vè{\0\0\0ƒÄ@jıVè \0\0\0ƒÄ\8^ÃÌÌÌÌÌÌÌÌÌD$\12Pj\0ÿt$\16jÿÿt$\20è*ùÿÿ‹\8ÿp\4ƒÉ\1Qÿ\21¸0\0\16ƒÉÿƒÄ\28…À\15HÁÃÌÿ%D1\0\16ÿ%@1\0\16ÿ%<1\0\16ÿ%81\0\16ÿ%41\0\16ÿ%01\0\16ÿ%,1\0\16ÿ%(1\0\16ÿ%$1\0\16ÿ% 1\0\16ÿ%\0281\0\16ÿ%\0241\0\16ÿ%\0201\0\16ÿ%\0161\0\16ÿ%\0121\0\16ÿ%\0081\0\16ÿ%\0041\0\16ÿ%\0001\0\16ÿ%ü0\0\16ÿ%ø0\0\16ÿ%ô0\0\16ÿ%ğ0\0\16ÿ%ì0\0\16ÿ%è0\0\16ÿ%ä0\0\16ÿ%à0\0\16ÿ%Ü0\0\16ÿ%Ø0\0\16ÿ%Ô0\0\16ÿ%Ğ0\0\16;\13„P\0\16òu\2òÃòé\3\4\0\0ÌÌÌÌÌÌÌÌÌƒ=ÌS\0\16\0t7U‹ìƒì\8ƒäøİ\28$ò\15,\4$ÉÃƒ=ÌS\0\16\0t\27ƒì\4Ù<$Xfƒà\127fƒø\127tÓ¤$\0\0\0\0I\0U‹ìƒì ƒäğÙÀÙT$\24ß|$\16ßl$\16‹T$\24‹D$\16…Àt<Şé…Òy\30Ù\28$‹\12$ñ\0\0\0€Áÿÿÿ\127ƒĞ\0‹T$\20ƒÒ\0ë,Ù\28$‹\12$Áÿÿÿ\127ƒØ\0‹T$\20ƒÚ\0ë\20‹T$\20÷Âÿÿÿ\127u¸Ù\\$\24Ù\\$\24ÉÃU‹ì‹E\12ƒè\0t3ƒè\1t ƒè\1t\17ƒè\1t\0053À@ë0è…\7\0\0ë\5è_\7\0\0\15¶Àë\31ÿu\16ÿu\8è\24\0\0\0Yë\16ƒ}\16\0\15•À\15¶ÀPèÿ\0\0\0Y]Â\12\0j\16hH8\0\16èì\
\0\0j\0è³\7\0\0Y„Àu\0073ÀéÈ\0\0\0è¥\6\0\0ˆEã³\1ˆ]çƒeü\0ƒ=èS\0\16\0t\7j\7è>\9\0\0Ç\5èS\0\16\1\0\0\0èÚ\6\0\0„ÀtMèA\
\0\0èí\5\0\0è\6\6\0\0h\\1\0\16hX1\0\16è5\11\0\0YY…Àu)è‚\6\0\0„Àt hT1\0\16hP1\0\16è\17\11\0\0YYÇ\5èS\0\16\2\0\0\0002Ûˆ]çÇEüşÿÿÿèD\0\0\0„Û\15…dÿÿÿè¿\8\0\0‹ğƒ>\0t\30Vèã\7\0\0Y„Àt\19ÿu\12j\2ÿu\8‹6‹Îè\19\
\0\0ÿÖÿ\5¨P\0\0163À@èR\
\0\0ÃŠ]çÿuãè;\8\0\0YÃj\12hh8\0\16èò\9\0\0¡¨P\0\16…À\127\0043ÀëYH£¨P\0\16è«\5\0\0ˆEäƒeü\0ƒ=èS\0\16\2t\7j\7èI\8\0\0è\\\6\0\0è\23\5\0\0è€\9\0\0ƒ%èS\0\16\0ÇEüşÿÿÿè\27\0\0\0j\0ÿu\8èï\7\0\0YY3É„À\15•Á‹ÁèÍ\9\0\0ÃèB\6\0\0ÿuäè´\7\0\0YÃj\12hˆ8\0\16èk\9\0\0‹}\12…ÿu\0159=¨P\0\16\127\0073ÀéÔ\0\0\0ƒeü\0ƒÿ\1t\
ƒÿ\2t\5‹]\16ë1‹]\16SWÿu\8èº\0\0\0‹ğ‰uä…ö\15„\0\0\0SWÿu\8èÓıÿÿ‹ğ‰uä…ö\15„‡\0\0\0SWÿu\8è7\4\0\0‹ğ‰uäƒÿ\1u\"…öu\30SPÿu\8è\31\4\0\0SVÿu\8èšıÿÿSVÿu\8è`\0\0\0…ÿt\5ƒÿ\3uHSWÿu\8è}ıÿÿ‹ğ‰uä…öt5SWÿu\8è:\0\0\0‹ğë$‹Mì‹\1Qÿ0h\5!\0\16ÿu\16ÿu\12ÿu\8è\1\5\0\0ƒÄ\24Ã‹eè3ö‰uäÇEüşÿÿÿ‹ÆèÂ\8\0\0ÃU‹ìV‹55\0\16…öu\0053À@ë\18ÿu\16‹Îÿu\12ÿu\8èO\8\0\0ÿÖ^]Â\12\0U‹ìƒ}\12\1u\5è×\2\0\0ÿu\16ÿu\12ÿu\8è¾şÿÿƒÄ\12]Â\12\0U‹ìj\0ÿ\21\0160\0\16ÿu\8ÿ\21\0120\0\16h\9\4\0Àÿ\21\0200\0\16Pÿ\21\0240\0\16]ÃU‹ìì$\3\0\0j\23è†\8\0\0…Àt\5j\2YÍ)£°Q\0\16‰\13¬Q\0\16‰\21¨Q\0\16‰\29¤Q\0\16‰5 Q\0\16‰=œQ\0\16fŒ\21ÈQ\0\16fŒ\13¼Q\0\16fŒ\29˜Q\0\16fŒ\5”Q\0\16fŒ%Q\0\16fŒ-ŒQ\0\16œ\5ÀQ\0\16‹E\0£´Q\0\16‹E\4£¸Q\0\16E\8£ÄQ\0\16‹…ÜüÿÿÇ\5\0Q\0\16\1\0\1\0¡¸Q\0\16£¼P\0\16Ç\5°P\0\16\9\4\0ÀÇ\5´P\0\16\1\0\0\0Ç\5ÀP\0\16\1\0\0\0j\4XkÀ\0Ç€ÄP\0\16\2\0\0\0j\4XkÀ\0‹\13„P\0\16‰L\5øj\4XÁà\0‹\13€P\0\16‰L\5øh”5\0\16èáşÿÿ‹å]ÃU‹ìƒ%ÌS\0\16\0ƒì$S3ÛC\9\29ŒP\0\16j\
è}\7\0\0…À\15„r\1\0\0ƒeğ\0003Àƒ\13ŒP\0\16\0023ÉVW‰\29ÌS\0\16}ÜS\15¢‹ó[‰\7‰w\4‰O\0083É‰W\12‹EÜ‹}à‰Eô÷Genu‹Eè5ineI‰Eø‹Eä5ntel‰Eü3À@S\15¢‹ó[]Ü‰\3‹Eü\11Eø\11Ç‰s\4‰K\8‰S\12uC‹EÜ%ğ?ÿ\15=À\6\1\0t#=`\6\2\0t\28=p\6\2\0t\21=P\6\3\0t\14=`\6\3\0t\7=p\6\3\0u\17‹=ĞS\0\16ƒÏ\1‰=ĞS\0\16ë\6‹=ĞS\0\16ƒ}ô\7‹Eä‰Eü|2j\7X3ÉS\15¢‹ó[]Ü‰\3‹Eü‰s\4‰K\8‰S\12‹]à÷Ã\0\2\0\0t\14ƒÏ\2‰=ĞS\0\16ë\3‹]ğ_^©\0\0\16\0tlƒ\13ŒP\0\16\4Ç\5ÌS\0\16\2\0\0\0©\0\0\0\8tT©\0\0\0\16tM3É\15\1Ğ‰Eì‰Uğ‹Eì‹Mğƒà\0063Éƒø\6u2…Éu.¡ŒP\0\16ƒÈ\8Ç\5ÌS\0\16\3\0\0\0£ŒP\0\16öÃ t\18ƒÈ Ç\5ÌS\0\16\5\0\0\0£ŒP\0\0163À[‹å]ÃU‹ìƒì\20ƒeô\0ƒeø\0¡„P\0\16VW¿Næ@»¾\0\0ÿÿ;Çt\13…Æt\9÷Ğ£€P\0\16ëfEôPÿ\21$0\0\16‹Eø3Eô‰Eüÿ\21(0\0\0161Eüÿ\21,0\0\0161EüEìPÿ\02100\0\16‹MğEü3Mì3Mü3È;Ïu\7¹Oæ@»ë\16…Îu\12‹Á\13\17G\0\0Áà\16\11È‰\13„P\0\16÷Ñ‰\13€P\0\16_^‹å]ÃU‹ìƒ}\12\1u\18ƒ=5\0\16\0u\9ÿu\8ÿ\21 0\0\0163À@]Â\12\0hØS\0\16ÿ\21\0000\0\16ÃhØS\0\16è.\5\0\0YÃ¸àS\0\16ÃèËğÿÿ‹H\4ƒ\8\4‰H\4èçÿÿÿ‹H\4ƒ\8\2‰H\4ÃU‹ì‹E\8V‹H<\3È\15·A\20Q\24\3Ğ\15·A\6kğ(\3ò;Öt\25‹M\12;J\12r\
‹B\8\3B\12;Èr\12ƒÂ(;Öuê3À^]Ã‹Âëùè¬\4\0\0…Àu\0032ÀÃd¡\24\0\0\0V¾ìS\0\16‹P\4ë\4;Ğt\0163À‹Êğ\15±\14…Àuğ2À^Ã°\1^Ãèw\4\0\0…Àt\7èáüÿÿë\24èc\4\0\0Pè™\4\0\0Y…Àt\0032ÀÃè’\4\0\0°\1Ãj\0èÏ\0\0\0„ÀY\15•ÀÃè”\4\0\0„Àu\0032ÀÃèˆ\4\0\0„Àu\7è\127\4\0\0ëí°\1Ãèu\4\0\0èp\4\0\0°\1ÃU‹ìè\15\4\0\0…Àu\24ƒ}\12\1u\18ÿu\16‹M\20Pÿu\8èk\3\0\0ÿU\20ÿu\28ÿu\24è\26\4\0\0YY]Ãèß\3\0\0…Àt\12hğS\0\16è\27\4\0\0YÃè#\4\0\0…À\15„\18\4\0\0Ãj\0è\16\4\0\0Yé\
\4\0\0U‹ìƒ}\8\0u\7Æ\5\9T\0\16\1è\18üÿÿèğ\3\0\0„Àu\0042À]Ãèã\3\0\0„Àu\
j\0èØ\3\0\0Yëé°\1]ÃU‹ìƒì\12€=\8T\0\16\0t\7°\1éˆ\0\0\0V‹u\8…öt\5ƒş\1u\127èS\3\0\0…Àt&…öu\"hğS\0\16è…\3\0\0Y…Àu\15hüS\0\16èv\3\0\0Y…ÀtF2ÀëK¡„P\0\16uôWƒà\31¿ğS\0\16j Y+ÈƒÈÿÓÈ3\5„P\0\16‰Eô‰Eø‰Eü¥¥¥¿üS\0\16‰Eô‰Eøuô‰Eü¥¥¥_Æ\5\8T\0\16\1°\1^‹å]Ãj\5èÖ\0\0\0Ìj\8h¨8\0\16èC\2\0\0ƒeü\0¸MZ\0\0f9\5\0\0\0\16u]¡<\0\0\16¸\0\0\0\16PE\0\0uL¹\11\1\0\0f9ˆ\24\0\0\16u>‹E\8¹\0\0\0\16+ÁPQèıÿÿYY…Àt'ƒx$\0|!ÇEüşÿÿÿ°\1ë\31‹Eì‹\0003É8\5\0\0À\15”Á‹ÁÃ‹eèÇEüşÿÿÿ2Àè\12\2\0\0ÃU‹ìè?\2\0\0…Àt\15€}\8\0u\0093À¹ìS\0\16‡\1]ÃU‹ì€=\9T\0\16\0t\6€}\12\0u\18ÿu\8èf\2\0\0ÿu\8è^\2\0\0YY°\1]Ã¸\24T\0\16ÃU‹ìì$\3\0\0SVj\23èø\1\0\0…Àt\5‹M\8Í)3ö…ÜüÿÿhÌ\2\0\0VP‰5\12T\0\16èá\1\0\0ƒÄ\12‰…Œıÿÿ‰ˆıÿÿ‰•„ıÿÿ‰€ıÿÿ‰µ|ıÿÿ‰½xıÿÿfŒ•¤ıÿÿfŒ˜ıÿÿfŒtıÿÿfŒ…pıÿÿfŒ¥lıÿÿfŒ­hıÿÿœ…œıÿÿ‹E\4‰…”ıÿÿE\4‰… ıÿÿÇ…Üüÿÿ\1\0\1\0‹@üjP‰…ıÿÿE¨VPèX\1\0\0‹E\4ƒÄ\12ÇE¨\21\0\0@ÇE¬\1\0\0\0‰E´ÿ\21\0280\0\16VXÿ÷ÛE¨‰Eø…Üüÿÿ\26Û‰EüşÃÿ\21\0160\0\16EøPÿ\21\0120\0\16…Àu\13\15¶Ã÷Ø\27À!\5\12T\0\16^[‹å]ÃSV¾88\0\16»88\0\16;ós\24W‹>…ÿt\9‹Ïè8\0\0\0ÿ×ƒÆ\4;órê_^[ÃSV¾@8\0\16»@8\0\16;ós\24W‹>…ÿt\9‹Ïè\13\0\0\0ÿ×ƒÆ\4;órê_^[Ãÿ%L1\0\16ÌÌÌh«,\0\16dÿ5\0\0\0\0‹D$\16‰l$\16l$\16+àSVW¡„P\0\0161Eü3ÅP‰eèÿuø‹EüÇEüşÿÿÿ‰EøEğd£\0\0\0\0òÃ‹Mğd‰\13\0\0\0\0Y__^[‹å]QòÃU‹ìÿu\20ÿu\16ÿu\12ÿu\8h6 \0\16h„P\0\16è)\0\0\0ƒÄ\24]Ã3À@Ã3À9\5 P\0\16\15•ÀÃÃÌÿ%40\0\16ÿ%@0\0\16ÿ%D0\0\16ÿ%H0\0\16ÿ%ˆ0\0\16ÿ%Œ0\0\16ÿ%0\0\16ÿ%”0\0\16ÿ%˜0\0\16ÿ%œ0\0\16ÿ% 0\0\16ÿ%„0\0\16°\1Ã3ÀÃ\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0J>\0\0$=\0\0@=\0\0P=\0\0l=\0\0Š=\0\0=\0\0`>\0\0.>\0\0\20>\0\0ş=\0\0è=\0\0Î=\0\0²=\0\0002=\0\0\0\0\0\0‚>\0\0¢>\0\0¬>\0\0\0\0\0\0f?\0\0\\?\0\0R?\0\0Œ?\0\0?\0\0004?\0\0H?\0\0\0\0\0\0*?\0\0\"?\0\0\0\0\0\0\22?\0\0Ø>\0\0X@\0\0¼?\0\0È?\0\0Ö?\0\0è?\0\0\2@\0\0$@\0\0@@\0\0\0\0\0\0>?\0\0ô>\0\0€?\0\0t?\0\0ü>\0\0â>\0\0ì>\0\0\0\0\0\0°?\0\0\0\0\0\0\
=\0\0ö<\0\0è<\0\0Ö<\0\0Â<\0\0°<\0\0<\0\0Š<\0\0z<\0\0d<\0\0P<\0\0B<\0\0002<\0\0\"<\0\0\18<\0\0\0<\0\0î;\0\0Ş;\0\0Ì;\0\0¸;\0\0¦;\0\0”;\0\0‚;\0\0t;\0\0b;\0\0R;\0\0F;\0\0006;\0\0&;\0\0\24;\0\0\0\0\0\0Ş,\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0touch\0\0\0lock_dir\0\0\0\0\0\0\0\0\0€\0\0\0@\0\0\0162\0\16\0242\0\16\0\0\0\0\0\0\0\0œ2\0\16p\24\0\16¨2\0\16\0\16\0\16°2\0\16`\16\0\16¼2\0\0160\21\0\01682\0\16 \20\0\16(2\0\16 \18\0\16À2\0\16p\20\0\16È2\0\16Ğ\20\0\16Ğ2\0\16p\24\0\16 2\0\16P\18\0\16p1\0\16à\21\0\01602\0\16`\19\0\16x1\0\16\0\17\0\16\0\0\0\0\0\0\0\0binary\0\0text\0\0\0\0setmode\0lock\0\0\0\0unlock\0\0link\0\0\0\0mode\0\0\0\0dev\0ino\0nlink\0\0\0uid\0gid\0rdev\0\0\0\0access\0\0modification\0\0\0\0change\0\0size\0\0\0\0permissions\0attributes\0\0chdir\0\0\0currentdir\0\0dir\0mkdir\0\0\0rmdir\0\0\0symlinkattributes\0\0\0%s: %s\0\0Unable to change working directory to '%s'\
%s\
\0\0FILE*\0\0\0%s: not a file\0\0%s: closed file\0%s: invalid mode\0\0\0\0/lockfile.lfs\0\0\0File exists\0lock metatable\0\0%s\0\0u\0\0\0make_link is not supported on Windows\0\0\0directory metatable\0closed directory\0\0\0\0path too long: %s\0\0\0%s/*\0\0\0\0next\0\0\0\0close\0\0\0__index\0__gc\0\0\0\0free\0\0\0\0file\0\0\0\0directory\0\0\0char device\0other\0\0\0cannot obtain information from file `%s'\0\0\0\0invalid attribute name\0\0_COPYRIGHT\0\0Copyright (C) 2003-2012 Kepler Project\0\0_DESCRIPTION\0\0\0\0LuaFileSystem is a Lua library developed to complement the set of functions related to file systems offered by the standard Lua distribution\0\0\0\0_VERSION\0\0\0\0LuaFileSystem 1.6.3\0lfs\0\0\0\0\0\0\0\0\0\0p\127@\0\0\0\0°P\0\16\0Q\0\16\0\0\0\0\0\0\0\0›\127ÀX\0\0\0\0\13\0\0\0\0\2\0\00046\0\0004(\0\0\0\0\0\0h\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0„P\0\01606\0\16\1\0\0\0L1\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0«,\0\0\0\0\0\0\0\16\0\0.\29\0\0.text$mn\0\0\0\0\0000\0\0L\1\0\0.idata$5\0\0\0\0L1\0\0\4\0\0\0.00cfg\0\0P1\0\0\4\0\0\0.CRT$XCA\0\0\0\0T1\0\0\4\0\0\0.CRT$XCZ\0\0\0\0X1\0\0\4\0\0\0.CRT$XIA\0\0\0\0\\1\0\0\4\0\0\0.CRT$XIZ\0\0\0\0`1\0\0\4\0\0\0.CRT$XPA\0\0\0\0d1\0\0\4\0\0\0.CRT$XPZ\0\0\0\0h1\0\0\4\0\0\0.CRT$XTA\0\0\0\0l1\0\0\4\0\0\0.CRT$XTZ\0\0\0\0p1\0\0À\4\0\0.rdata\0\00006\0\0\4\0\0\0.rdata$sxdata\0\0\00046\0\0\0\2\0\0.rdata$zzzdbg\0\0\00048\0\0\4\0\0\0.rtc$IAA\0\0\0\00088\0\0\4\0\0\0.rtc$IZZ\0\0\0\0<8\0\0\4\0\0\0.rtc$TAA\0\0\0\0@8\0\0\8\0\0\0.rtc$TZZ\0\0\0\0H8\0\0ˆ\0\0\0.xdata$x\0\0\0\0Ğ8\0\0H\0\0\0.edata\0\0\0249\0\0 \0\0\0.idata$2\0\0\0\0¸9\0\0\20\0\0\0.idata$3\0\0\0\0Ì9\0\0L\1\0\0.idata$4\0\0\0\0\24;\0\0ò\5\0\0.idata$6\0\0\0\0\0P\0\0¨\0\0\0.data\0\0\0¨P\0\0t\3\0\0.bss\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0şÿÿÿ\0\0\0\0Ğÿÿÿ\0\0\0\0şÿÿÿ\0\0\0\0E\"\0\16\0\0\0\0şÿÿÿ\0\0\0\0Ôÿÿÿ\0\0\0\0şÿÿÿ\0\0\0\0Ê\"\0\16\0\0\0\0şÿÿÿ\0\0\0\0Ôÿÿÿ\0\0\0\0şÿÿÿŸ#\0\16¾#\0\16\0\0\0\0şÿÿÿ\0\0\0\0Øÿÿÿ\0\0\0\0şÿÿÿf*\0\16y*\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0›\127ÀX\0\0\0\0\0029\0\0\1\0\0\0\1\0\0\0\1\0\0\0ø8\0\0ü8\0\0\0009\0\0ğ\29\0\0\
9\0\0\0\0lfs.dll\0luaopen_lfs\0\0\0œ:\0\0\0\0\0\0\0\0\0\0\26=\0\0Ğ0\0\0Ì9\0\0\0\0\0\0\0\0\0\0t>\0\0\0000\0\0\12:\0\0\0\0\0\0\0\0\0\0Æ>\0\0@0\0\0H:\0\0\0\0\0\0\0\0\0\0b@\0\0|0\0\0t:\0\0\0\0\0\0\0\0\0\0„@\0\0¨0\0\0<:\0\0\0\0\0\0\0\0\0\0¤@\0\0p0\0\0\28:\0\0\0\0\0\0\0\0\0\0Ä@\0\0P0\0\0”:\0\0\0\0\0\0\0\0\0\0ê@\0\0È0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0J>\0\0$=\0\0@=\0\0P=\0\0l=\0\0Š=\0\0=\0\0`>\0\0.>\0\0\20>\0\0ş=\0\0è=\0\0Î=\0\0²=\0\0002=\0\0\0\0\0\0‚>\0\0¢>\0\0¬>\0\0\0\0\0\0f?\0\0\\?\0\0R?\0\0Œ?\0\0?\0\0004?\0\0H?\0\0\0\0\0\0*?\0\0\"?\0\0\0\0\0\0\22?\0\0Ø>\0\0X@\0\0¼?\0\0È?\0\0Ö?\0\0è?\0\0\2@\0\0$@\0\0@@\0\0\0\0\0\0>?\0\0ô>\0\0€?\0\0t?\0\0ü>\0\0â>\0\0ì>\0\0\0\0\0\0°?\0\0\0\0\0\0\
=\0\0ö<\0\0è<\0\0Ö<\0\0Â<\0\0°<\0\0<\0\0Š<\0\0z<\0\0d<\0\0P<\0\0B<\0\0002<\0\0\"<\0\0\18<\0\0\0<\0\0î;\0\0Ş;\0\0Ì;\0\0¸;\0\0¦;\0\0”;\0\0‚;\0\0t;\0\0b;\0\0R;\0\0F;\0\0006;\0\0&;\0\0\24;\0\0\0\0\0\0E\0lua_gettop\0\0_\0lua_pushvalue\0K\0lua_isstring\0\0€\0lua_type\0\0{\0lua_tolstring\0\127\0lua_touserdata\0\0[\0lua_pushnil\0X\0lua_pushinteger\0]\0lua_pushstring\0\0W\0lua_pushfstring\0V\0lua_pushcclosure\0\0U\0lua_pushboolean\0:\0lua_getfield\0\0005\0lua_createtable\0R\0lua_newuserdata\0m\0lua_setglobal\0r\0lua_settable\0\0l\0lua_setfield\0\0f\0lua_rawset\0\0q\0lua_setmetatable\0\0\15\0luaL_checkversion_\0\0\3\0luaL_argerror\0\9\0luaL_checklstring\0\31\0luaL_optnumber\0\0\29\0luaL_optinteger\0\26\0luaL_newmetatable\0\14\0luaL_checkudata\0\16\0luaL_error\0\0\11\0luaL_checkoption\0\0%\0luaL_setfuncs\0lua53.dll\0À\0CreateFileA\0„\0CloseHandle\0Y\2GetLastError\0\0š\5UnhandledExceptionFilter\0\0[\5SetUnhandledExceptionFilter\0\18\2GetCurrentProcess\0y\5TerminateProcess\0\0{\3IsProcessorFeaturePresent\0>\4QueryPerformanceCounter\0\19\2GetCurrentProcessId\0\23\2GetCurrentThreadId\0\0á\2GetSystemTimeAsFileTime\0\26\1DisableThreadLibraryCalls\0X\3InitializeSListHead\0t\3IsDebuggerPresent\0KERNEL32.dll\0\0%\0__std_type_info_destroy_list\0\0H\0memset\0\0005\0_except_handler4_common\0VCRUNTIME140.dll\0\0#\0_errno\0\0&\0_fileno\0‡\0fseek\0‰\0ftell\0\13\0__stdio_common_vsprintf\0g\0strerror\0\0\24\0free\0\0\25\0malloc\0\0\31\0_stat64\0;\0_getcwd\0\2\0_chdir\0\0\25\0_mkdir\0\0\26\0_rmdir\0\0\5\0_findclose\0\0D\0_locking\0\0W\0_setmode\0\0\9\0_findfirst64i32\0\13\0_findnext64i32\0\0005\0_utime64\0\0008\0_initterm\0009\0_initterm_e\0A\0_seh_filter_dll\0\25\0_configure_narrow_argv\0\0005\0_initialize_narrow_environment\0\0006\0_initialize_onexit_table\0\0$\0_execute_onexit_table\0\23\0_cexit\0\0api-ms-win-crt-runtime-l1-1-0.dll\0api-ms-win-crt-stdio-l1-1-0.dll\0api-ms-win-crt-heap-l1-1-0.dll\0\0api-ms-win-crt-filesystem-l1-1-0.dll\0\0api-ms-win-crt-time-l1-1-0.dll\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0---------\0\0\0\0\0\0\0@2\0\16À\22\0\16H2\0\16\16\23\0\16L2\0\0160\23\0\16P2\0\16P\23\0\16X2\0\16p\23\0\16\\2\0\16\23\0\16`2\0\16°\23\0\16h2\0\16Ğ\23\0\16p2\0\16ğ\23\0\16€2\0\16\16\24\0\16ˆ2\0\0160\24\0\162\0\16P\24\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0±\25¿DNæ@»u˜\0\0\1\0\0\0ÿÿÿÿ\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\16\0\0\\\1\0\0\0210(00070g0ˆ0›0£0!161>1{1‰1•1 1°1½1Æ1à1ù1\0192 2V2j2o2|22§2»2À2Í2Ò2\
3<3D3J3h3|333“3½3Ä3ò3ú3\0004-454;4@4L4‚4•44£4â4õ4ı4\0035D5\\5£5½5ä5O6b6j6p6Î6ã6ö6û6r8‘8¤8Ü8\0319^9h99¹9Ó9ñ9,:\\:c:u::‹:À:æ:ı:\8;\23;\";2;A;L;w;;¥;Æ;İ;å;\29<.<‡<<§<±<Î<Ø<è<\3=\26=)=/=R=p=†==¨=µ=Ä=Ò=\5>,>?>f>p>z>ˆ>>–>¡>¨>¯>·>¿>Æ>Í>æ>ñ>\4?\15?\"?-?q?„?Š??–?œ?¢?¨?®?´?º?À?Æ?Ì?Ò?Ø?Ş?ä?ê?ğ?ö?ü?\0\0\0 \0\0\24\1\0\0\0020\0080\0140\0200\0260 0&0,02080R0n0[1Š1š1»1À1Ù1Ş1ë182U2_2m2\12722Ü2î2¨3Û3)424=4D4d4j4p4v4|4‚4‰44—44¥4¬4³4»4Ã4Ë4×4à4å4ë4õ4ÿ4\0155\0315/585J5X5s5~5\0186\0276#6_6s6z6°6¹6Â6Ğ6Ù6ó6\0147\0267)727?7n7v7‹7—7£7©7¯7»758ø8)9_9ˆ9—9ª9¶9Æ9×9í9\4:\25: :&:8:B: :­:Ñ:\2;­;Ì;Ö;ç;ô;ù;\31<$<I<Q<n<»<À<Ö<â<è<î<ô<ú<\0=\6=\12=\18=\24=\30=$=\0000\0\0X\0\0\0L11”1 1¤1¨1¬1°1´1¸1¼1À1Ä1È1Ì1Ğ1Ô1Ø1Ü1à1ä1è1ì1ğ1ô1ø1ü1\0002\0042”5˜5ü5\0006\0086`8€8œ8 8¼8À8\0P\0\0008\0\0\0\0160\0200\0240\0280 0$0(0,0004080<0@0D0H0L0P0T0X0\\0`0d0h0l0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" )
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

