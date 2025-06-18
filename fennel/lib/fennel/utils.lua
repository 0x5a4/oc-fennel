local view = require("fennel.view")
local version = "1.5.3"
local unpack = (table.unpack or _G.unpack)
local pack = nil
local function _1_(...)
  local _2_0 = {...}
  _2_0["n"] = select("#", ...)
  return _2_0
end
pack = (table.pack or _1_)
local maxn = nil
local function _3_(_241)
  local max = 0
  for k in pairs(_241) do
    if (("number" == type(k)) and (max < k)) then
      max = k
    else
      max = max
    end
  end
  return max
end
maxn = (table.maxn or _3_)
local function luajit_vm_3f()
  return ((nil ~= _G.jit) and (type(_G.jit) == "table") and (nil ~= _G.jit.on) and (nil ~= _G.jit.off) and (type(_G.jit.version_num) == "number"))
end
local function luajit_vm_version()
  local jit_os = nil
  if (_G.jit.os == "OSX") then
    jit_os = "macOS"
  else
    jit_os = _G.jit.os
  end
  return (_G.jit.version .. " " .. jit_os .. "/" .. _G.jit.arch)
end
local function fengari_vm_3f()
  return ((nil ~= _G.fengari) and (type(_G.fengari) == "table") and (nil ~= _G.fengari.VERSION) and (type(_G.fengari.VERSION_NUM) == "number"))
end
local function fengari_vm_version()
  return (_G.fengari.RELEASE .. " (" .. _VERSION .. ")")
end
local function lua_vm_version()
  if luajit_vm_3f() then
    return luajit_vm_version()
  elseif fengari_vm_3f() then
    return fengari_vm_version()
  else
    return ("PUC " .. _VERSION)
  end
end
local function runtime_version(_3fas_table)
  if _3fas_table then
    return {fennel = version, lua = lua_vm_version()}
  else
    return ("Fennel " .. version .. " on " .. lua_vm_version())
  end
end
local len = nil
do
  local _8_0, _9_0 = pcall(require, "utf8")
  if ((_8_0 == true) and (nil ~= _9_0)) then
    local utf8 = _9_0
    len = utf8.len
  else
    local _ = _8_0
    len = string.len
  end
end
local kv_order = {boolean = 2, number = 1, string = 3, table = 4}
local function kv_compare(a, b)
  local _11_0, _12_0 = type(a), type(b)
  if (((_11_0 == "number") and (_12_0 == "number")) or ((_11_0 == "string") and (_12_0 == "string"))) then
    return (a < b)
  else
    local function _13_()
      local a_t = _11_0
      local b_t = _12_0
      return (a_t ~= b_t)
    end
    if (((nil ~= _11_0) and (nil ~= _12_0)) and _13_()) then
      local a_t = _11_0
      local b_t = _12_0
      return ((kv_order[a_t] or 5) < (kv_order[b_t] or 5))
    else
      local _ = _11_0
      return (tostring(a) < tostring(b))
    end
  end
end
local function add_stable_keys(succ, prev_key, src, _3fpred)
  local first = prev_key
  local last = nil
  do
    local prev = prev_key
    for _, k in ipairs(src) do
      if ((prev == k) or (succ[k] ~= nil) or (_3fpred and not _3fpred(k))) then
        prev = prev
      else
        if (first == nil) then
          first = k
          prev = k
        elseif (prev ~= nil) then
          succ[prev] = k
          prev = k
        else
          prev = k
        end
      end
    end
    last = prev
  end
  return succ, last, first
end
local function stablepairs(t)
  local mt_keys = nil
  do
    local _17_0 = getmetatable(t)
    if (nil ~= _17_0) then
      _17_0 = _17_0.keys
    end
    mt_keys = _17_0
  end
  local succ, prev, first_mt = nil, nil, nil
  local function _19_(_241)
    return t[_241]
  end
  succ, prev, first_mt = add_stable_keys({}, nil, (mt_keys or {}), _19_)
  local pairs_keys = nil
  do
    local _20_0 = nil
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for k in pairs(t) do
        local val_19_ = k
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      _20_0 = tbl_17_
    end
    table.sort(_20_0, kv_compare)
    pairs_keys = _20_0
  end
  local succ0, _, first_after_mt = add_stable_keys(succ, prev, pairs_keys)
  local first = nil
  if (first_mt == nil) then
    first = first_after_mt
  else
    first = first_mt
  end
  local function stablenext(tbl, key)
    local _23_0 = nil
    if (key == nil) then
      _23_0 = first
    else
      _23_0 = succ0[key]
    end
    if (nil ~= _23_0) then
      local next_key = _23_0
      local _25_0 = tbl[next_key]
      if (_25_0 ~= nil) then
        return next_key, _25_0
      else
        return _25_0
      end
    end
  end
  return stablenext, t, nil
end
local function get_in(tbl, path)
  if (nil ~= path[1]) then
    local t = tbl
    for _, k in ipairs(path) do
      if (nil == t) then break end
      if (type(t) == "table") then
        t = t[k]
      else
      t = nil
      end
    end
    return t
  end
end
local function copy(_3ffrom, _3fto)
  local tbl_14_ = (_3fto or {})
  for k, v in pairs((_3ffrom or {})) do
    local k_15_, v_16_ = k, v
    if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
      tbl_14_[k_15_] = v_16_
    end
  end
  return tbl_14_
end
local function member_3f(x, tbl, _3fn)
  local _31_0 = tbl[(_3fn or 1)]
  if (_31_0 == x) then
    return true
  elseif (_31_0 == nil) then
    return nil
  else
    local _ = _31_0
    return member_3f(x, tbl, ((_3fn or 1) + 1))
  end
end
local function every_3f(t, predicate)
  local result = true
  for _, item in ipairs(t) do
    if not result then break end
    result = predicate(item)
  end
  return result
end
local function allpairs(tbl)
  assert((type(tbl) == "table"), "allpairs expects a table")
  local t = tbl
  local seen = {}
  local function allpairs_next(_, state)
    local next_state, value = next(t, state)
    if seen[next_state] then
      return allpairs_next(nil, next_state)
    elseif next_state then
      seen[next_state] = true
      return next_state, value
    else
      local _33_0 = getmetatable(t)
      if ((_G.type(_33_0) == "table") and true) then
        local __index = _33_0.__index
        if ("table" == type(__index)) then
          t = __index
          return allpairs_next(t)
        end
      end
    end
  end
  return allpairs_next
end
local function deref(self)
  return self[1]
end
local function list__3estring(self, _3fview, _3foptions, _3findent)
  local viewed = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i = 1, maxn(self) do
      local val_19_ = nil
      if _3fview then
        val_19_ = _3fview(self[i], _3foptions, _3findent)
      else
        val_19_ = view(self[i])
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    viewed = tbl_17_
  end
  return ("(" .. table.concat(viewed, " ") .. ")")
end
local function sym_3d(a, b)
  return ((deref(a) == deref(b)) and (getmetatable(a) == getmetatable(b)))
end
local function sym_3c(a, b)
  return (a[1] < tostring(b))
end
local symbol_mt = {"SYMBOL", __eq = sym_3d, __fennelview = deref, __lt = sym_3c, __tostring = deref}
local expr_mt = nil
local function _39_(x)
  return tostring(deref(x))
end
expr_mt = {"EXPR", __tostring = _39_}
local list_mt = {"LIST", __fennelview = list__3estring, __tostring = list__3estring}
local comment_mt = nil
local function _40_(_241)
  return _241
end
comment_mt = {"COMMENT", __eq = sym_3d, __fennelview = _40_, __lt = sym_3c, __tostring = deref}
local sequence_marker = {"SEQUENCE"}
local varg_mt = {"VARARG", __fennelview = deref, __tostring = deref}
local getenv = nil
local function _41_()
  return nil
end
getenv = ((os and os.getenv) or _41_)
local function debug_on_3f(flag)
  local level = (getenv("FENNEL_DEBUG") or "")
  return ((level == "all") or level:find(flag))
end
local function list(...)
  return setmetatable({...}, list_mt)
end
local function sym(str, _3fsource)
  local _42_
  do
    local tbl_14_ = {str}
    for k, v in pairs((_3fsource or {})) do
      local k_15_, v_16_ = nil, nil
      if (type(k) == "string") then
        k_15_, v_16_ = k, v
      else
      k_15_, v_16_ = nil
      end
      if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
        tbl_14_[k_15_] = v_16_
      end
    end
    _42_ = tbl_14_
  end
  return setmetatable(_42_, symbol_mt)
end
local function sequence(...)
  local function _45_(seq, view0, inspector, indent)
    local opts = nil
    do
      inspector["empty-as-sequence?"] = {after = inspector["empty-as-sequence?"], once = true}
      inspector["metamethod?"] = {after = inspector["metamethod?"], once = false}
      opts = inspector
    end
    return view0(seq, opts, indent)
  end
  return setmetatable({...}, {__fennelview = _45_, sequence = sequence_marker})
end
local function expr(strcode, etype)
  return setmetatable({strcode, type = etype}, expr_mt)
end
local function comment_2a(contents, _3fsource)
  local _46_ = (_3fsource or {})
  local filename = _46_["filename"]
  local line = _46_["line"]
  return setmetatable({contents, filename = filename, line = line}, comment_mt)
end
local function varg(_3fsource)
  local _47_
  do
    local tbl_14_ = {"..."}
    for k, v in pairs((_3fsource or {})) do
      local k_15_, v_16_ = nil, nil
      if (type(k) == "string") then
        k_15_, v_16_ = k, v
      else
      k_15_, v_16_ = nil
      end
      if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
        tbl_14_[k_15_] = v_16_
      end
    end
    _47_ = tbl_14_
  end
  return setmetatable(_47_, varg_mt)
end
local function expr_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == expr_mt) and x)
end
local function varg_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == varg_mt) and x)
end
local function list_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == list_mt) and x)
end
local function sym_3f(x, _3fname)
  return ((type(x) == "table") and (getmetatable(x) == symbol_mt) and ((nil == _3fname) or (x[1] == _3fname)) and x)
end
local function sequence_3f(x)
  local mt = ((type(x) == "table") and getmetatable(x))
  return (mt and (mt.sequence == sequence_marker) and x)
end
local function comment_3f(x)
  return ((type(x) == "table") and (getmetatable(x) == comment_mt) and x)
end
local function table_3f(x)
  return ((type(x) == "table") and not varg_3f(x) and (getmetatable(x) ~= list_mt) and (getmetatable(x) ~= symbol_mt) and not comment_3f(x) and x)
end
local function kv_table_3f(t)
  if table_3f(t) then
    local nxt, t0, k = pairs(t)
    local len0 = #t0
    local next_state = nil
    if (0 == len0) then
      next_state = k
    else
      next_state = len0
    end
    return ((nil ~= nxt(t0, next_state)) and t0)
  end
end
local function string_3f(x)
  if (type(x) == "string") then
    return x
  else
    return false
  end
end
local function multi_sym_3f(str)
  if sym_3f(str) then
    return multi_sym_3f(tostring(str))
  elseif (type(str) ~= "string") then
    return false
  else
    local function _53_()
      local parts = {}
      for part in str:gmatch("[^%.%:]+[%.%:]?") do
        local last_char = part:sub(-1)
        if (last_char == ":") then
          parts["multi-sym-method-call"] = true
        end
        if ((last_char == ":") or (last_char == ".")) then
          parts[(#parts + 1)] = part:sub(1, -2)
        else
          parts[(#parts + 1)] = part
        end
      end
      return (next(parts) and parts)
    end
    return ((str:match("%.") or str:match(":")) and not str:match("%.%.") and (str:byte() ~= string.byte(".")) and (str:byte() ~= string.byte(":")) and (str:byte(-1) ~= string.byte(".")) and (str:byte(-1) ~= string.byte(":")) and _53_())
  end
end
local function call_of_3f(ast, callee)
  return (list_3f(ast) and sym_3f(ast[1], callee))
end
local function quoted_3f(symbol)
  return symbol.quoted
end
local function idempotent_expr_3f(x)
  local t = type(x)
  return ((t == "string") or (t == "number") or (t == "boolean") or (sym_3f(x) and not multi_sym_3f(x)))
end
local function walk_tree(root, f, _3fcustom_iterator)
  local function walk(iterfn, parent, idx, node)
    if (f(idx, node, parent) and not sym_3f(node)) then
      for k, v in iterfn(node) do
        walk(iterfn, node, k, v)
      end
      return nil
    end
  end
  walk((_3fcustom_iterator or pairs), nil, nil, root)
  return root
end
local root = nil
local function _58_()
end
root = {chunk = nil, options = nil, reset = _58_, scope = nil}
root["set-reset"] = function(_59_0)
  local _60_ = _59_0
  local chunk = _60_["chunk"]
  local options = _60_["options"]
  local reset = _60_["reset"]
  local scope = _60_["scope"]
  root.reset = function()
    root.chunk, root.scope, root.options, root.reset = chunk, scope, options, reset
    return nil
  end
  return root.reset
end
local lua_keywords = {["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true}
local function lua_keyword_3f(str)
  local function _62_()
    local _61_0 = root.options
    if (nil ~= _61_0) then
      _61_0 = _61_0.keywords
    end
    if (nil ~= _61_0) then
      _61_0 = _61_0[str]
    end
    return _61_0
  end
  return (lua_keywords[str] or _62_())
end
local function valid_lua_identifier_3f(str)
  return (str:match("^[%a_][%w_]*$") and not lua_keyword_3f(str))
end
local propagated_options = {"allowedGlobals", "indent", "correlate", "useMetadata", "env", "compiler-env", "compilerEnv"}
local function propagate_options(options, subopts)
  local tbl_14_ = subopts
  for _, name in ipairs(propagated_options) do
    local k_15_, v_16_ = name, options[name]
    if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
      tbl_14_[k_15_] = v_16_
    end
  end
  return tbl_14_
end
local function ast_source(ast)
  if (table_3f(ast) or sequence_3f(ast)) then
    return (getmetatable(ast) or {})
  elseif ("table" == type(ast)) then
    return ast
  else
    return {}
  end
end
local function warn(msg, _3fast, _3ffilename, _3fline)
  local _67_0 = nil
  do
    local _68_0 = root.options
    if (nil ~= _68_0) then
      _68_0 = _68_0.warn
    end
    _67_0 = _68_0
  end
  if (nil ~= _67_0) then
    local opt_warn = _67_0
    return opt_warn(msg, _3fast, _3ffilename, _3fline)
  else
    local _ = _67_0
    if (_G.io and _G.io.stderr) then
      local loc = nil
      do
        local _70_0 = ast_source(_3fast)
        if ((_G.type(_70_0) == "table") and (nil ~= _70_0.filename) and (nil ~= _70_0.line)) then
          local filename = _70_0.filename
          local line = _70_0.line
          loc = (filename .. ":" .. line .. ": ")
        else
          local _0 = _70_0
          if (_3ffilename and _3fline) then
            loc = (_3ffilename .. ":" .. _3fline .. ": ")
          else
            loc = ""
          end
        end
      end
      return (_G.io.stderr):write(("--WARNING: %s%s\n"):format(loc, msg))
    end
  end
end
local warned = {}
local function check_plugin_version(_75_0)
  local _76_ = _75_0
  local plugin = _76_
  local name = _76_["name"]
  local versions = _76_["versions"]
  if (not member_3f(version:gsub("-dev", ""), (versions or {})) and not (string_3f(versions) and version:find(versions)) and not warned[plugin]) then
    warned[plugin] = true
    return warn(string.format("plugin %s does not support Fennel version %s", (name or "unknown"), version))
  end
end
local function hook_opts(event, _3foptions, ...)
  local plugins = nil
  local function _79_(...)
    local _78_0 = _3foptions
    if (nil ~= _78_0) then
      _78_0 = _78_0.plugins
    end
    return _78_0
  end
  local function _82_(...)
    local _81_0 = root.options
    if (nil ~= _81_0) then
      _81_0 = _81_0.plugins
    end
    return _81_0
  end
  plugins = (_79_(...) or _82_(...))
  if plugins then
    local result = nil
    for _, plugin in ipairs(plugins) do
      if (nil ~= result) then break end
      check_plugin_version(plugin)
      local _84_0 = plugin[event]
      if (nil ~= _84_0) then
        local f = _84_0
        result = f(...)
      else
      result = nil
      end
    end
    return result
  end
end
local function hook(event, ...)
  return hook_opts(event, root.options, ...)
end
return {["ast-source"] = ast_source, ["call-of?"] = call_of_3f, ["comment?"] = comment_3f, ["debug-on?"] = debug_on_3f, ["every?"] = every_3f, ["expr?"] = expr_3f, ["fennel-module"] = nil, ["get-in"] = get_in, ["hook-opts"] = hook_opts, ["idempotent-expr?"] = idempotent_expr_3f, ["kv-table?"] = kv_table_3f, ["list?"] = list_3f, ["lua-keyword?"] = lua_keyword_3f, ["macro-path"] = table.concat({"./?.fnl", "./?/init-macros.fnl", "./?/init.fnl", getenv("FENNEL_MACRO_PATH")}, ";"), ["member?"] = member_3f, ["multi-sym?"] = multi_sym_3f, ["propagate-options"] = propagate_options, ["quoted?"] = quoted_3f, ["runtime-version"] = runtime_version, ["sequence?"] = sequence_3f, ["string?"] = string_3f, ["sym?"] = sym_3f, ["table?"] = table_3f, ["valid-lua-identifier?"] = valid_lua_identifier_3f, ["varg?"] = varg_3f, ["walk-tree"] = walk_tree, allpairs = allpairs, comment = comment_2a, copy = copy, expr = expr, hook = hook, len = len, list = list, maxn = maxn, pack = pack, path = table.concat({"./?.fnl", "./?/init.fnl", getenv("FENNEL_PATH")}, ";"), root = root, sequence = sequence, stablepairs = stablepairs, sym = sym, unpack = unpack, varg = varg, version = version, warn = warn}
