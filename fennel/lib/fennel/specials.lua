local _1_ = require("fennel.utils")
local utils = _1_
local pack = _1_["pack"]
local unpack = _1_["unpack"]
local view = require("fennel.view")
local parser = require("fennel.parser")
local compiler = require("fennel.compiler")
local SPECIALS = compiler.scopes.global.specials
local function str1(x)
  return tostring(x[1])
end
local function wrap_env(env)
  local function _2_(_, key)
    if utils["string?"](key) then
      return env[compiler["global-unmangling"](key)]
    else
      return env[key]
    end
  end
  local function _4_(_, key, value)
    if utils["string?"](key) then
      env[compiler["global-unmangling"](key)] = value
      return nil
    else
      env[key] = value
      return nil
    end
  end
  local function _6_()
    local _7_
    do
      local tbl_14_ = {}
      for k, v in utils.stablepairs(env) do
        local k_15_, v_16_ = nil, nil
        local _8_
        if utils["string?"](k) then
          _8_ = compiler["global-unmangling"](k)
        else
          _8_ = k
        end
        k_15_, v_16_ = _8_, v
        if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
          tbl_14_[k_15_] = v_16_
        end
      end
      _7_ = tbl_14_
    end
    return next, _7_, nil
  end
  return setmetatable({}, {__index = _2_, __newindex = _4_, __pairs = _6_})
end
local function fennel_module_name()
  return (utils.root.options.moduleName or "fennel")
end
local function current_global_names(_3fenv)
  local mt = nil
  do
    local _11_0 = getmetatable(_3fenv)
    if ((_G.type(_11_0) == "table") and (nil ~= _11_0.__pairs)) then
      local mtpairs = _11_0.__pairs
      local tbl_14_ = {}
      for k, v in mtpairs(_3fenv) do
        local k_15_, v_16_ = k, v
        if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
          tbl_14_[k_15_] = v_16_
        end
      end
      mt = tbl_14_
    elseif (_11_0 == nil) then
      mt = (_3fenv or _G)
    else
    mt = nil
    end
  end
  local function _14_()
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for k in utils.stablepairs(mt) do
      local val_19_ = compiler["global-unmangling"](k)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    return tbl_17_
  end
  return (mt and _14_())
end
local function load_code(code, _3fenv, _3ffilename)
  local env = (_3fenv or rawget(_G, "_ENV") or _G)
  local _16_0, _17_0 = rawget(_G, "setfenv"), rawget(_G, "loadstring")
  if ((nil ~= _16_0) and (nil ~= _17_0)) then
    local setfenv = _16_0
    local loadstring = _17_0
    local f = assert(loadstring(code, _3ffilename))
    setfenv(f, env)
    return f
  else
    local _ = _16_0
    return assert(load(code, _3ffilename, "t", env))
  end
end
local function v__3edocstring(tgt)
  return (((compiler.metadata):get(tgt, "fnl/docstring") or "#<undocumented>")):gsub("\n$", ""):gsub("\n", "\n  ")
end
local function doc_2a(tgt, name)
  assert(("string" == type(name)), "name must be a string")
  if not tgt then
    return (name .. " not found")
  else
    local function _20_()
      local _19_0 = getmetatable(tgt)
      if ((_G.type(_19_0) == "table") and true) then
        local __call = _19_0.__call
        return ("function" == type(__call))
      end
    end
    if ((type(tgt) == "function") or _20_()) then
      local elts = {name, unpack(((compiler.metadata):get(tgt, "fnl/arglist") or {"#<unknown-arguments>"}))}
      return string.format("(%s)\n  %s", table.concat(elts, " "), v__3edocstring(tgt))
    else
      return string.format("%s\n  %s", name, v__3edocstring(tgt))
    end
  end
end
local function doc_special(name, arglist, docstring, body_form_3f)
  compiler.metadata[SPECIALS[name]] = {["fnl/arglist"] = arglist, ["fnl/body-form?"] = body_form_3f, ["fnl/docstring"] = docstring}
  return nil
end
local function compile_do(ast, scope, parent, _3fstart)
  local start = (_3fstart or 2)
  local len = #ast
  local sub_scope = compiler["make-scope"](scope)
  for i = start, len do
    compiler.compile1(ast[i], sub_scope, parent, {nval = 0})
  end
  return nil
end
SPECIALS["do"] = function(ast, scope, parent, opts, _3fstart, _3fchunk, _3fsub_scope, _3fpre_syms)
  local start = (_3fstart or 2)
  local sub_scope = (_3fsub_scope or compiler["make-scope"](scope))
  local chunk = (_3fchunk or {})
  local len = #ast
  local retexprs = {returned = true}
  utils.hook("pre-do", ast, sub_scope)
  local function compile_body(outer_target, outer_tail, outer_retexprs)
    for i = start, len do
      local subopts = {nval = (((i ~= len) and 0) or opts.nval), tail = (((i == len) and outer_tail) or nil), target = (((i == len) and outer_target) or nil)}
      local _ = utils["propagate-options"](opts, subopts)
      local subexprs = compiler.compile1(ast[i], sub_scope, chunk, subopts)
      if (i ~= len) then
        compiler["keep-side-effects"](subexprs, parent, nil, ast[i])
      end
    end
    compiler.emit(parent, chunk, ast)
    compiler.emit(parent, "end", ast)
    utils.hook("do", ast, sub_scope)
    return (outer_retexprs or retexprs)
  end
  if (opts.target or (opts.nval == 0) or opts.tail) then
    compiler.emit(parent, "do", ast)
    return compile_body(opts.target, opts.tail)
  elseif opts.nval then
    local syms = {}
    for i = 1, opts.nval do
      local s = ((_3fpre_syms and _3fpre_syms[i]) or compiler.gensym(scope))
      syms[i] = s
      retexprs[i] = utils.expr(s, "sym")
    end
    local outer_target = table.concat(syms, ", ")
    compiler.emit(parent, string.format("local %s", outer_target), ast)
    compiler.emit(parent, "do", ast)
    return compile_body(outer_target, opts.tail)
  else
    local fname = compiler.gensym(scope)
    local fargs = nil
    if scope.vararg then
      fargs = "..."
    else
      fargs = ""
    end
    compiler.emit(parent, string.format("local function %s(%s)", fname, fargs), ast)
    return compile_body(nil, true, utils.expr((fname .. "(" .. fargs .. ")"), "statement"))
  end
end
doc_special("do", {"..."}, "Evaluate multiple forms; return last value.", true)
local function iter_args(ast)
  local ast0, len, i = ast, #ast, 1
  local function _26_()
    i = (1 + i)
    while ((i == len) and utils["call-of?"](ast0[i], "values")) do
      ast0 = ast0[i]
      len = #ast0
      i = 2
    end
    return ast0[i], (nil == ast0[(i + 1)])
  end
  return _26_
end
SPECIALS.values = function(ast, scope, parent)
  local exprs = {}
  for subast, last_3f in iter_args(ast) do
    local subexprs = compiler.compile1(subast, scope, parent, {nval = (not last_3f and 1)})
    table.insert(exprs, subexprs[1])
    if last_3f then
      for j = 2, #subexprs do
        table.insert(exprs, subexprs[j])
      end
    end
  end
  return exprs
end
doc_special("values", {"..."}, "Return multiple values from a function. Must be in tail position.")
local function __3estack(stack, tbl)
  for k, v in pairs(tbl) do
    table.insert(stack, k)
    table.insert(stack, v)
  end
  return stack
end
local function literal_3f(val)
  local res = true
  if utils["list?"](val) then
    res = false
  elseif utils["table?"](val) then
    local stack = __3estack({}, val)
    for _, elt in ipairs(stack) do
      if not res then break end
      if utils["list?"](elt) then
        res = false
      elseif utils["table?"](elt) then
        __3estack(stack, elt)
      end
    end
  end
  return res
end
local function compile_value(v)
  local opts = {nval = 1, tail = false}
  local scope = compiler["make-scope"]()
  local chunk = {}
  local _30_ = compiler.compile1(v, scope, chunk, opts)
  local _31_ = _30_[1]
  local v0 = _31_[1]
  return v0
end
local function insert_meta(meta, k, v)
  local view_opts = {["escape-newlines?"] = true, ["line-length"] = math.huge, ["one-line?"] = true}
  compiler.assert((type(k) == "string"), ("expected string keys in metadata table, got: %s"):format(view(k, view_opts)))
  compiler.assert(literal_3f(v), ("expected literal value in metadata table, got: %s %s"):format(view(k, view_opts), view(v, view_opts)))
  table.insert(meta, view(k))
  local function _32_()
    if ("string" == type(v)) then
      return view(v, view_opts)
    else
      return compile_value(v)
    end
  end
  table.insert(meta, _32_())
  return meta
end
local function insert_arglist(meta, arg_list)
  local opts = {["escape-newlines?"] = true, ["line-length"] = math.huge, ["one-line?"] = true}
  local view_args = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _, arg in ipairs(arg_list) do
      local val_19_ = view(view(arg, opts))
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    view_args = tbl_17_
  end
  table.insert(meta, "\"fnl/arglist\"")
  table.insert(meta, ("{" .. table.concat(view_args, ", ") .. "}"))
  return meta
end
local function set_fn_metadata(f_metadata, parent, fn_name)
  if utils.root.options.useMetadata then
    local meta_fields = {}
    for k, v in utils.stablepairs(f_metadata) do
      if (k == "fnl/arglist") then
        insert_arglist(meta_fields, v)
      else
        insert_meta(meta_fields, k, v)
      end
    end
    if (type(utils.root.options.useMetadata) == "string") then
      return compiler.emit(parent, ("%s:setall(%s, %s)"):format(utils.root.options.useMetadata, fn_name, table.concat(meta_fields, ", ")))
    else
      local meta_str = ("require(\"%s\").metadata"):format(fennel_module_name())
      return compiler.emit(parent, ("pcall(function() %s:setall(%s, %s) end)"):format(meta_str, fn_name, table.concat(meta_fields, ", ")))
    end
  end
end
local function get_fn_name(ast, scope, fn_name, multi)
  if (fn_name and (fn_name[1] ~= "nil")) then
    local _37_
    if not multi then
      _37_ = compiler["declare-local"](fn_name, scope, ast)
    else
      _37_ = compiler["symbol-to-expression"](fn_name, scope)[1]
    end
    return _37_, not multi, 3
  else
    return nil, true, 2
  end
end
local function compile_named_fn(ast, f_scope, f_chunk, parent, index, fn_name, local_3f, arg_name_list, f_metadata)
  utils.hook("pre-fn", ast, f_scope, parent)
  for i = (index + 1), #ast do
    compiler.compile1(ast[i], f_scope, f_chunk, {nval = (((i ~= #ast) and 0) or nil), tail = (i == #ast)})
  end
  local _40_
  if local_3f then
    _40_ = "local function %s(%s)"
  else
    _40_ = "%s = function(%s)"
  end
  compiler.emit(parent, string.format(_40_, fn_name, table.concat(arg_name_list, ", ")), ast)
  compiler.emit(parent, f_chunk, ast)
  compiler.emit(parent, "end", ast)
  set_fn_metadata(f_metadata, parent, fn_name)
  utils.hook("fn", ast, f_scope, parent)
  return utils.expr(fn_name, "sym")
end
local function compile_anonymous_fn(ast, f_scope, f_chunk, parent, index, arg_name_list, f_metadata, scope)
  local fn_name = compiler.gensym(scope)
  return compile_named_fn(ast, f_scope, f_chunk, parent, index, fn_name, true, arg_name_list, f_metadata)
end
local function maybe_metadata(ast, pred, handler, mt, index)
  local index_2a = (index + 1)
  local index_2a_before_ast_end_3f = (index_2a < #ast)
  local expr = ast[index_2a]
  if (index_2a_before_ast_end_3f and pred(expr)) then
    return handler(mt, expr), index_2a
  else
    return mt, index
  end
end
local function get_function_metadata(ast, arg_list, index)
  local function _43_(_241, _242)
    local tbl_14_ = _241
    for k, v in pairs(_242) do
      local k_15_, v_16_ = k, v
      if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
        tbl_14_[k_15_] = v_16_
      end
    end
    return tbl_14_
  end
  local function _45_(_241, _242)
    _241["fnl/docstring"] = _242
    return _241
  end
  return maybe_metadata(ast, utils["kv-table?"], _43_, maybe_metadata(ast, utils["string?"], _45_, {["fnl/arglist"] = arg_list}, index))
end
SPECIALS.fn = function(ast, scope, parent, opts)
  local f_scope = nil
  do
    local _46_0 = compiler["make-scope"](scope)
    _46_0["vararg"] = false
    f_scope = _46_0
  end
  local f_chunk = {}
  local fn_sym = utils["sym?"](ast[2])
  local multi = (fn_sym and utils["multi-sym?"](fn_sym[1]))
  local fn_name, local_3f, index = get_fn_name(ast, scope, fn_sym, multi, opts)
  local arg_list = compiler.assert(utils["table?"](ast[index]), "expected parameters table", ast)
  compiler.assert((not multi or not multi["multi-sym-method-call"]), ("unexpected multi symbol " .. tostring(fn_name)), fn_sym)
  if (multi and not scope.symmeta[multi[1]] and not compiler["global-allowed?"](multi[1])) then
    compiler.assert(nil, ("expected local table " .. multi[1]), ast[2])
  end
  local function destructure_arg(arg)
    local raw = utils.sym(compiler.gensym(scope))
    local declared = compiler["declare-local"](raw, f_scope, ast)
    compiler.destructure(arg, raw, ast, f_scope, f_chunk, {declaration = true, nomulti = true, symtype = "arg"})
    return declared
  end
  local function destructure_amp(i)
    compiler.assert((i == (#arg_list - 1)), "expected rest argument before last parameter", arg_list[(i + 1)], arg_list)
    f_scope.vararg = true
    compiler.destructure(arg_list[#arg_list], {utils.varg()}, ast, f_scope, f_chunk, {declaration = true, nomulti = true, symtype = "arg"})
    return "..."
  end
  local function get_arg_name(arg, i)
    if f_scope.vararg then
      return nil
    elseif utils["varg?"](arg) then
      compiler.assert((arg == arg_list[#arg_list]), "expected vararg as last parameter", ast)
      f_scope.vararg = true
      return "..."
    elseif utils["sym?"](arg, "&") then
      return destructure_amp(i)
    elseif (utils["sym?"](arg) and (tostring(arg) ~= "nil") and not utils["multi-sym?"](tostring(arg))) then
      return compiler["declare-local"](arg, f_scope, ast)
    elseif utils["table?"](arg) then
      return destructure_arg(arg)
    else
      return compiler.assert(false, ("expected symbol for function parameter: %s"):format(tostring(arg)), ast[index])
    end
  end
  local arg_name_list = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i, a in ipairs(arg_list) do
      local val_19_ = get_arg_name(a, i)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    arg_name_list = tbl_17_
  end
  local f_metadata, index0 = get_function_metadata(ast, arg_list, index)
  if fn_name then
    return compile_named_fn(ast, f_scope, f_chunk, parent, index0, fn_name, local_3f, arg_name_list, f_metadata)
  else
    return compile_anonymous_fn(ast, f_scope, f_chunk, parent, index0, arg_name_list, f_metadata, scope)
  end
end
doc_special("fn", {"name?", "args", "docstring?", "..."}, "Function syntax. May optionally include a name and docstring or a metadata table.\nIf a name is provided, the function will be bound in the current scope.\nWhen called with the wrong number of args, excess args will be discarded\nand lacking args will be nil, use lambda for arity-checked functions.", true)
SPECIALS.lua = function(ast, _, parent)
  compiler.assert(((#ast == 2) or (#ast == 3)), "expected 1 or 2 arguments", ast)
  local _52_
  do
    local _51_0 = utils["sym?"](ast[2])
    if (nil ~= _51_0) then
      _52_ = tostring(_51_0)
    else
      _52_ = _51_0
    end
  end
  if ("nil" ~= _52_) then
    table.insert(parent, {ast = ast, leaf = tostring(ast[2])})
  end
  local _56_
  do
    local _55_0 = utils["sym?"](ast[3])
    if (nil ~= _55_0) then
      _56_ = tostring(_55_0)
    else
      _56_ = _55_0
    end
  end
  if ("nil" ~= _56_) then
    return tostring(ast[3])
  end
end
local function dot(ast, scope, parent)
  compiler.assert((1 < #ast), "expected table argument", ast)
  local len = #ast
  local lhs_node = compiler.macroexpand(ast[2], scope)
  local _59_ = compiler.compile1(lhs_node, scope, parent, {nval = 1})
  local lhs = _59_[1]
  if (len == 2) then
    return tostring(lhs)
  else
    local indices = {}
    for i = 3, len do
      local index = ast[i]
      if (utils["string?"](index) and utils["valid-lua-identifier?"](index)) then
        table.insert(indices, ("." .. index))
      else
        local _60_ = compiler.compile1(index, scope, parent, {nval = 1})
        local index0 = _60_[1]
        table.insert(indices, ("[" .. tostring(index0) .. "]"))
      end
    end
    if (not (utils["sym?"](lhs_node) or utils["list?"](lhs_node)) or ("nil" == tostring(lhs_node))) then
      return ("(" .. tostring(lhs) .. ")" .. table.concat(indices))
    else
      return (tostring(lhs) .. table.concat(indices))
    end
  end
end
SPECIALS["."] = dot
doc_special(".", {"tbl", "key1", "..."}, "Look up key1 in tbl table. If more args are provided, do a nested lookup.")
SPECIALS.global = function(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {forceglobal = true, nomulti = true, symtype = "global"})
  return nil
end
doc_special("global", {"name", "val"}, "Set name as a global with val. Deprecated.")
SPECIALS.set = function(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {noundef = true, symtype = "set"})
  return nil
end
doc_special("set", {"name", "val"}, "Set a local variable to a new value. Only works on locals using var.")
local function set_forcibly_21_2a(ast, scope, parent)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {forceset = true, symtype = "set"})
  return nil
end
SPECIALS["set-forcibly!"] = set_forcibly_21_2a
local function local_2a(ast, scope, parent, opts)
  compiler.assert(((0 == opts.nval) or opts.tail), "can't introduce local here", ast)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {declaration = true, nomulti = true, symtype = "local"})
  return nil
end
SPECIALS["local"] = local_2a
doc_special("local", {"name", "val"}, "Introduce new top-level immutable local.")
SPECIALS.var = function(ast, scope, parent, opts)
  compiler.assert(((0 == opts.nval) or opts.tail), "can't introduce var here", ast)
  compiler.assert((#ast == 3), "expected name and value", ast)
  compiler.destructure(ast[2], ast[3], ast, scope, parent, {declaration = true, isvar = true, nomulti = true, symtype = "var"})
  return nil
end
doc_special("var", {"name", "val"}, "Introduce new mutable local.")
local function kv_3f(t)
  local _64_
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for k in pairs(t) do
      local val_19_ = nil
      if ("number" ~= type(k)) then
        val_19_ = k
      else
      val_19_ = nil
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    _64_ = tbl_17_
  end
  return _64_[1]
end
SPECIALS.let = function(_67_0, scope, parent, opts)
  local _68_ = _67_0
  local _ = _68_[1]
  local bindings = _68_[2]
  local ast = _68_
  compiler.assert((utils["table?"](bindings) and not kv_3f(bindings)), "expected binding sequence", (bindings or ast[1]))
  compiler.assert(((#bindings % 2) == 0), "expected even number of name/value bindings", bindings)
  compiler.assert((3 <= #ast), "expected body expression", ast[1])
  local pre_syms = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _0 = 1, (opts.nval or 0) do
      local val_19_ = compiler.gensym(scope)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    pre_syms = tbl_17_
  end
  local sub_scope = compiler["make-scope"](scope)
  local sub_chunk = {}
  for i = 1, #bindings, 2 do
    compiler.destructure(bindings[i], bindings[(i + 1)], ast, sub_scope, sub_chunk, {declaration = true, nomulti = true, symtype = "let"})
  end
  return SPECIALS["do"](ast, scope, parent, opts, 3, sub_chunk, sub_scope, pre_syms)
end
doc_special("let", {"[name1 val1 ... nameN valN]", "..."}, "Introduces a new scope in which a given set of local bindings are used.", true)
local function get_prev_line(parent)
  if ("table" == type(parent)) then
    return get_prev_line((parent.leaf or parent[#parent]))
  else
    return (parent or "")
  end
end
local function needs_separator_3f(root, prev_line)
  return (root:match("^%(") and prev_line and not prev_line:find(" end$"))
end
SPECIALS.tset = function(ast, scope, parent)
  compiler.assert((3 < #ast), "expected table, key, and value arguments", ast)
  compiler.assert(((type(ast[2]) ~= "boolean") and (type(ast[2]) ~= "number")), "cannot set field of literal value", ast)
  local root = str1(compiler.compile1(ast[2], scope, parent, {nval = 1}))
  local root0 = nil
  if root:match("^[.{\"]") then
    root0 = string.format("(%s)", root)
  else
    root0 = root
  end
  local keys = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i = 3, (#ast - 1) do
      local val_19_ = str1(compiler.compile1(ast[i], scope, parent, {nval = 1}))
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    keys = tbl_17_
  end
  local value = str1(compiler.compile1(ast[#ast], scope, parent, {nval = 1}))
  local fmtstr = nil
  if needs_separator_3f(root0, get_prev_line(parent)) then
    fmtstr = "do end %s[%s] = %s"
  else
    fmtstr = "%s[%s] = %s"
  end
  return compiler.emit(parent, fmtstr:format(root0, table.concat(keys, "]["), value), ast)
end
doc_special("tset", {"tbl", "key1", "...", "keyN", "val"}, "Set the value of a table field. Deprecated in favor of set.")
local function calculate_if_target(scope, opts)
  if not (opts.tail or opts.target or opts.nval) then
    return "iife", true, nil
  elseif (opts.nval and (opts.nval ~= 0) and not opts.target) then
    local accum = {}
    local target_exprs = {}
    for i = 1, opts.nval do
      local s = compiler.gensym(scope)
      accum[i] = s
      target_exprs[i] = utils.expr(s, "sym")
    end
    return "target", opts.tail, table.concat(accum, ", "), target_exprs
  else
    return "none", opts.tail, opts.target
  end
end
local function if_2a(ast, scope, parent, opts)
  compiler.assert((2 < #ast), "expected condition and body", ast)
  if ((1 == (#ast % 2)) and (ast[(#ast - 1)] == true)) then
    table.remove(ast, (#ast - 1))
  end
  if (1 == (#ast % 2)) then
    table.insert(ast, utils.sym("nil"))
  end
  if (#ast == 2) then
    return SPECIALS["do"](utils.list(utils.sym("do"), ast[2]), scope, parent, opts)
  else
    local do_scope = compiler["make-scope"](scope)
    local branches = {}
    local wrapper, inner_tail, inner_target, target_exprs = calculate_if_target(scope, opts)
    local body_opts = {nval = opts.nval, tail = inner_tail, target = inner_target}
    local function compile_body(i)
      local chunk = {}
      local cscope = compiler["make-scope"](do_scope)
      compiler["keep-side-effects"](compiler.compile1(ast[i], cscope, chunk, body_opts), chunk, nil, ast[i])
      return {chunk = chunk, scope = cscope}
    end
    for i = 2, (#ast - 1), 2 do
      local condchunk = {}
      local _77_ = compiler.compile1(ast[i], do_scope, condchunk, {nval = 1})
      local cond = _77_[1]
      local branch = compile_body((i + 1))
      branch.cond = cond
      branch.condchunk = condchunk
      branch.nested = ((i ~= 2) and (next(condchunk, nil) == nil))
      table.insert(branches, branch)
    end
    local else_branch = compile_body(#ast)
    local s = compiler.gensym(scope)
    local buffer = {}
    local last_buffer = buffer
    for i = 1, #branches do
      local branch = branches[i]
      local fstr = nil
      if not branch.nested then
        fstr = "if %s then"
      else
        fstr = "elseif %s then"
      end
      local cond = tostring(branch.cond)
      local cond_line = fstr:format(cond)
      if branch.nested then
        compiler.emit(last_buffer, branch.condchunk, ast)
      else
        for _, v in ipairs(branch.condchunk) do
          compiler.emit(last_buffer, v, ast)
        end
      end
      compiler.emit(last_buffer, cond_line, ast)
      compiler.emit(last_buffer, branch.chunk, ast)
      if (i == #branches) then
        compiler.emit(last_buffer, "else", ast)
        compiler.emit(last_buffer, else_branch.chunk, ast)
        compiler.emit(last_buffer, "end", ast)
      elseif not branches[(i + 1)].nested then
        local next_buffer = {}
        compiler.emit(last_buffer, "else", ast)
        compiler.emit(last_buffer, next_buffer, ast)
        compiler.emit(last_buffer, "end", ast)
        last_buffer = next_buffer
      end
    end
    if (wrapper == "iife") then
      local iifeargs = ((scope.vararg and "...") or "")
      compiler.emit(parent, ("local function %s(%s)"):format(tostring(s), iifeargs), ast)
      compiler.emit(parent, buffer, ast)
      compiler.emit(parent, "end", ast)
      return utils.expr(("%s(%s)"):format(tostring(s), iifeargs), "statement")
    elseif (wrapper == "none") then
      for i = 1, #buffer do
        compiler.emit(parent, buffer[i], ast)
      end
      return {returned = true}
    else
      compiler.emit(parent, ("local %s"):format(inner_target), ast)
      for i = 1, #buffer do
        compiler.emit(parent, buffer[i], ast)
      end
      return target_exprs
    end
  end
end
SPECIALS["if"] = if_2a
doc_special("if", {"cond1", "body1", "...", "condN", "bodyN"}, "Conditional form.\nTakes any number of condition/body pairs and evaluates the first body where\nthe condition evaluates to truthy. Similar to cond in other lisps.")
local function clause_3f(v)
  return (utils["string?"](v) or (utils["sym?"](v) and not utils["multi-sym?"](v) and tostring(v):match("^&(.+)")))
end
local function remove_until_condition(bindings, ast)
  local _until = nil
  for i = (#bindings - 1), 3, -1 do
    local _83_0 = clause_3f(bindings[i])
    if ((_83_0 == false) or (_83_0 == nil)) then
    elseif (nil ~= _83_0) then
      local clause = _83_0
      compiler.assert(((clause == "until") and not _until), ("unexpected iterator clause: " .. clause), ast)
      table.remove(bindings, i)
      _until = table.remove(bindings, i)
    end
  end
  return _until
end
local function compile_until(_3fcondition, scope, chunk)
  if _3fcondition then
    local _85_ = compiler.compile1(_3fcondition, scope, chunk, {nval = 1})
    local condition_lua = _85_[1]
    return compiler.emit(chunk, ("if %s then break end"):format(tostring(condition_lua)), utils.expr(_3fcondition, "expression"))
  end
end
local function iterator_bindings(ast)
  local bindings = utils.copy(ast)
  local _3funtil = remove_until_condition(bindings, ast)
  local iter = table.remove(bindings)
  local bindings0 = nil
  if (1 == #bindings) then
    bindings0 = (utils["list?"](bindings[1]) or bindings)
  else
    for _, b in ipairs(bindings) do
      if utils["list?"](b) then
        utils.warn("unexpected parens in iterator", b)
      end
    end
    bindings0 = bindings
  end
  return bindings0, iter, _3funtil
end
SPECIALS.each = function(ast, scope, parent)
  compiler.assert((3 <= #ast), "expected body expression", ast[1])
  compiler.assert(utils["table?"](ast[2]), "expected binding table", ast)
  local sub_scope = compiler["make-scope"](scope)
  local binding, iter, _3funtil_condition = iterator_bindings(ast[2])
  local destructures = {}
  local deferred_scope_changes = {manglings = {}, symmeta = {}}
  utils.hook("pre-each", ast, sub_scope, binding, iter, _3funtil_condition)
  local function destructure_binding(v)
    if utils["sym?"](v) then
      return compiler["declare-local"](v, sub_scope, ast, nil, deferred_scope_changes)
    else
      local raw = utils.sym(compiler.gensym(sub_scope))
      destructures[raw] = v
      return compiler["declare-local"](raw, sub_scope, ast)
    end
  end
  local bind_vars = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _, b in ipairs(binding) do
      local val_19_ = destructure_binding(b)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    bind_vars = tbl_17_
  end
  local vals = compiler.compile1(iter, scope, parent)
  local val_names = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _, v in ipairs(vals) do
      local val_19_ = tostring(v)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    val_names = tbl_17_
  end
  local chunk = {}
  compiler.assert(bind_vars[1], "expected binding and iterator", ast)
  compiler.emit(parent, ("for %s in %s do"):format(table.concat(bind_vars, ", "), table.concat(val_names, ", ")), ast)
  for raw, args in utils.stablepairs(destructures) do
    compiler.destructure(args, raw, ast, sub_scope, chunk, {declaration = true, nomulti = true, symtype = "each"})
  end
  compiler["apply-deferred-scope-changes"](sub_scope, deferred_scope_changes, ast)
  compile_until(_3funtil_condition, sub_scope, chunk)
  compile_do(ast, sub_scope, chunk, 3)
  compiler.emit(parent, chunk, ast)
  return compiler.emit(parent, "end", ast)
end
doc_special("each", {"[key value (iterator)]", "..."}, "Runs the body once for each set of values provided by the given iterator.\nMost commonly used with ipairs for sequential tables or pairs for  undefined\norder, but can be used with any iterator.", true)
local function while_2a(ast, scope, parent)
  local len1 = #parent
  local condition = compiler.compile1(ast[2], scope, parent, {nval = 1})[1]
  local len2 = #parent
  local sub_chunk = {}
  if (len1 ~= len2) then
    for i = (len1 + 1), len2 do
      table.insert(sub_chunk, parent[i])
      parent[i] = nil
    end
    compiler.emit(parent, "while true do", ast)
    compiler.emit(sub_chunk, ("if not %s then break end"):format(condition[1]), ast)
  else
    compiler.emit(parent, ("while " .. tostring(condition) .. " do"), ast)
  end
  compile_do(ast, compiler["make-scope"](scope), sub_chunk, 3)
  compiler.emit(parent, sub_chunk, ast)
  return compiler.emit(parent, "end", ast)
end
SPECIALS["while"] = while_2a
doc_special("while", {"condition", "..."}, "The classic while loop. Evaluates body until a condition is non-truthy.", true)
local function for_2a(ast, scope, parent)
  compiler.assert(utils["table?"](ast[2]), "expected binding table", ast)
  local ranges = setmetatable(utils.copy(ast[2]), getmetatable(ast[2]))
  local until_condition = remove_until_condition(ranges, ast)
  local binding_sym = table.remove(ranges, 1)
  local sub_scope = compiler["make-scope"](scope)
  local range_args = {}
  local chunk = {}
  compiler.assert(utils["sym?"](binding_sym), ("unable to bind %s %s"):format(type(binding_sym), tostring(binding_sym)), ast[2])
  compiler.assert((3 <= #ast), "expected body expression", ast[1])
  compiler.assert((#ranges <= 3), "unexpected arguments", ranges)
  compiler.assert((1 < #ranges), "expected range to include start and stop", ranges)
  utils.hook("pre-for", ast, sub_scope, binding_sym)
  for i = 1, math.min(#ranges, 3) do
    range_args[i] = str1(compiler.compile1(ranges[i], scope, parent, {nval = 1}))
  end
  compiler.emit(parent, ("for %s = %s do"):format(compiler["declare-local"](binding_sym, sub_scope, ast), table.concat(range_args, ", ")), ast)
  compile_until(until_condition, sub_scope, chunk)
  compile_do(ast, sub_scope, chunk, 3)
  compiler.emit(parent, chunk, ast)
  return compiler.emit(parent, "end", ast)
end
SPECIALS["for"] = for_2a
doc_special("for", {"[index start stop step?]", "..."}, "Numeric loop construct.\nEvaluates body once for each value between start and stop (inclusive).", true)
local function method_special_type(ast)
  if (utils["string?"](ast[3]) and utils["valid-lua-identifier?"](ast[3])) then
    return "native"
  elseif utils["sym?"](ast[2]) then
    return "nonnative"
  else
    return "binding"
  end
end
local function native_method_call(ast, _scope, _parent, target, args)
  local _94_ = ast
  local _ = _94_[1]
  local _0 = _94_[2]
  local method_string = _94_[3]
  local call_string = nil
  if ((target.type == "literal") or (target.type == "varg") or ((target.type == "expression") and not (target[1]):match("[%)%]]$") and not (target[1]):match("%.[%a_][%w_]*$"))) then
    call_string = "(%s):%s(%s)"
  else
    call_string = "%s:%s(%s)"
  end
  return utils.expr(string.format(call_string, tostring(target), method_string, table.concat(args, ", ")), "statement")
end
local function nonnative_method_call(ast, scope, parent, target, args)
  local method_string = str1(compiler.compile1(ast[3], scope, parent, {nval = 1}))
  local args0 = {tostring(target), unpack(args)}
  return utils.expr(string.format("%s[%s](%s)", tostring(target), method_string, table.concat(args0, ", ")), "statement")
end
local function binding_method_call(ast, scope, parent, target, args)
  local method_string = str1(compiler.compile1(ast[3], scope, parent, {nval = 1}))
  local target_local = compiler.gensym(scope, "tgt")
  local args0 = {target_local, unpack(args)}
  compiler.emit(parent, string.format("local %s = %s", target_local, tostring(target)))
  return utils.expr(string.format("(%s)[%s](%s)", target_local, method_string, table.concat(args0, ", ")), "statement")
end
local function method_call(ast, scope, parent)
  compiler.assert((2 < #ast), "expected at least 2 arguments", ast)
  local _96_ = compiler.compile1(ast[2], scope, parent, {nval = 1})
  local target = _96_[1]
  local args = {}
  for i = 4, #ast do
    local subexprs = nil
    local _97_
    if (i ~= #ast) then
      _97_ = 1
    else
    _97_ = nil
    end
    subexprs = compiler.compile1(ast[i], scope, parent, {nval = _97_})
    local tbl_17_ = args
    local i_18_ = #tbl_17_
    for _, subexpr in ipairs(subexprs) do
      local val_19_ = tostring(subexpr)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
  end
  local _100_0 = method_special_type(ast)
  if (_100_0 == "native") then
    return native_method_call(ast, scope, parent, target, args)
  elseif (_100_0 == "nonnative") then
    return nonnative_method_call(ast, scope, parent, target, args)
  elseif (_100_0 == "binding") then
    return binding_method_call(ast, scope, parent, target, args)
  end
end
SPECIALS[":"] = method_call
doc_special(":", {"tbl", "method-name", "..."}, "Call the named method on tbl with the provided args.\nMethod name doesn't have to be known at compile-time; if it is, use\n(tbl:method-name ...) instead.")
SPECIALS.comment = function(ast, _, parent)
  local c = nil
  local _102_
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i, elt in ipairs(ast) do
      local val_19_ = nil
      if (i ~= 1) then
        val_19_ = view(elt, {["one-line?"] = true})
      else
      val_19_ = nil
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    _102_ = tbl_17_
  end
  c = table.concat(_102_, " "):gsub("%]%]", "]\\]")
  return compiler.emit(parent, ("--[[ " .. c .. " ]]"), ast)
end
doc_special("comment", {"..."}, "Comment which will be emitted in Lua output.", true)
local function hashfn_max_used(f_scope, i, max)
  local max0 = nil
  if f_scope.symmeta[("$" .. i)].used then
    max0 = i
  else
    max0 = max
  end
  if (i < 9) then
    return hashfn_max_used(f_scope, (i + 1), max0)
  else
    return max0
  end
end
SPECIALS.hashfn = function(ast, scope, parent)
  compiler.assert((#ast == 2), "expected one argument", ast)
  local f_scope = nil
  do
    local _107_0 = compiler["make-scope"](scope)
    _107_0["vararg"] = false
    _107_0["hashfn"] = true
    f_scope = _107_0
  end
  local f_chunk = {}
  local name = compiler.gensym(scope)
  local symbol = utils.sym(name)
  local args = {}
  compiler["declare-local"](symbol, scope, ast)
  for i = 1, 9 do
    args[i] = compiler["declare-local"](utils.sym(("$" .. i)), f_scope, ast)
  end
  local function walker(idx, node, _3fparent_node)
    if utils["sym?"](node, "$...") then
      f_scope.vararg = true
      if _3fparent_node then
        _3fparent_node[idx] = utils.varg()
        return nil
      else
        return utils.varg()
      end
    else
      return ((utils["list?"](node) and (not _3fparent_node or not utils["sym?"](node[1], "hashfn"))) or utils["table?"](node))
    end
  end
  utils["walk-tree"](ast, walker)
  compiler.compile1(ast[2], f_scope, f_chunk, {tail = true})
  local max_used = hashfn_max_used(f_scope, 1, 0)
  if f_scope.vararg then
    compiler.assert((max_used == 0), "$ and $... in hashfn are mutually exclusive", ast)
  end
  local arg_str = nil
  if f_scope.vararg then
    arg_str = tostring(utils.varg())
  else
    arg_str = table.concat(args, ", ", 1, max_used)
  end
  compiler.emit(parent, string.format("local function %s(%s)", name, arg_str), ast)
  compiler.emit(parent, f_chunk, ast)
  compiler.emit(parent, "end", ast)
  return utils.expr(name, "sym")
end
doc_special("hashfn", {"..."}, "Function literal shorthand; args are either $... OR $1, $2, etc.")
local function comparator_special_type(ast)
  if (3 == #ast) then
    return "native"
  elseif utils["every?"]({unpack(ast, 3, (#ast - 1))}, utils["idempotent-expr?"]) then
    return "idempotent"
  else
    return "binding"
  end
end
local function short_circuit_safe_3f(x, scope)
  if (("table" ~= type(x)) or utils["sym?"](x) or utils["varg?"](x)) then
    return true
  elseif utils["table?"](x) then
    local ok = true
    for k, v in pairs(x) do
      if not ok then break end
      ok = (short_circuit_safe_3f(v, scope) and short_circuit_safe_3f(k, scope))
    end
    return ok
  elseif utils["list?"](x) then
    if utils["sym?"](x[1]) then
      local _113_0 = str1(x)
      if ((_113_0 == "fn") or (_113_0 == "hashfn") or (_113_0 == "let") or (_113_0 == "local") or (_113_0 == "var") or (_113_0 == "set") or (_113_0 == "tset") or (_113_0 == "if") or (_113_0 == "each") or (_113_0 == "for") or (_113_0 == "while") or (_113_0 == "do") or (_113_0 == "lua") or (_113_0 == "global")) then
        return false
      elseif (((_113_0 == "<") or (_113_0 == ">") or (_113_0 == "<=") or (_113_0 == ">=") or (_113_0 == "=") or (_113_0 == "not=") or (_113_0 == "~=")) and (comparator_special_type(x) == "binding")) then
        return false
      else
        local function _114_()
          return (1 ~= x[2])
        end
        if ((_113_0 == "pick-values") and _114_()) then
          return false
        else
          local function _115_()
            local call = _113_0
            return scope.macros[call]
          end
          if ((nil ~= _113_0) and _115_()) then
            local call = _113_0
            return false
          else
            local function _116_()
              return (method_special_type(x) == "binding")
            end
            if ((_113_0 == ":") and _116_()) then
              return false
            else
              local _ = _113_0
              local ok = true
              for i = 2, #x do
                if not ok then break end
                ok = short_circuit_safe_3f(x[i], scope)
              end
              return ok
            end
          end
        end
      end
    else
      local ok = true
      for _, v in ipairs(x) do
        if not ok then break end
        ok = short_circuit_safe_3f(v, scope)
      end
      return ok
    end
  end
end
local function operator_special_result(ast, zero_arity, unary_prefix, padded_op, operands)
  local _120_0 = #operands
  if (_120_0 == 0) then
    if zero_arity then
      return utils.expr(zero_arity, "literal")
    else
      return compiler.assert(false, "Expected more than 0 arguments", ast)
    end
  elseif (_120_0 == 1) then
    if unary_prefix then
      return ("(" .. unary_prefix .. padded_op .. operands[1] .. ")")
    else
      return operands[1]
    end
  else
    local _ = _120_0
    return ("(" .. table.concat(operands, padded_op) .. ")")
  end
end
local function emit_short_circuit_if(ast, scope, parent, name, subast, accumulator, expr_string, setter)
  if (accumulator ~= expr_string) then
    compiler.emit(parent, string.format(setter, accumulator, expr_string), ast)
  end
  local function _125_()
    if (name == "and") then
      return accumulator
    else
      return ("not " .. accumulator)
    end
  end
  compiler.emit(parent, ("if %s then"):format(_125_()), subast)
  do
    local chunk = {}
    compiler.compile1(subast, scope, chunk, {nval = 1, target = accumulator})
    compiler.emit(parent, chunk)
  end
  return compiler.emit(parent, "end")
end
local function operator_special(name, zero_arity, unary_prefix, ast, scope, parent)
  compiler.assert(not ((#ast == 2) and utils["varg?"](ast[2])), "tried to use vararg with operator", ast)
  local padded_op = (" " .. name .. " ")
  local operands, accumulator = {}
  if utils["call-of?"](ast[#ast], "values") then
    utils.warn("multiple values in operators are deprecated", ast)
  end
  for subast in iter_args(ast) do
    if ((nil ~= next(operands)) and ((name == "or") or (name == "and")) and not short_circuit_safe_3f(subast, scope)) then
      local expr_string = table.concat(operands, padded_op)
      local setter = nil
      if accumulator then
        setter = "%s = %s"
      else
        setter = "local %s = %s"
      end
      if not accumulator then
        accumulator = compiler.gensym(scope, name)
      end
      emit_short_circuit_if(ast, scope, parent, name, subast, accumulator, expr_string, setter)
      operands = {accumulator}
    else
      table.insert(operands, str1(compiler.compile1(subast, scope, parent, {nval = 1})))
    end
  end
  return operator_special_result(ast, zero_arity, unary_prefix, padded_op, operands)
end
local function define_arithmetic_special(name, zero_arity, unary_prefix, _3flua_name)
  local _131_
  do
    local _130_0 = (_3flua_name or name)
    local function _132_(...)
      return operator_special(_130_0, zero_arity, unary_prefix, ...)
    end
    _131_ = _132_
  end
  SPECIALS[name] = _131_
  return doc_special(name, {"a", "b", "..."}, "Arithmetic operator; works the same as Lua but accepts more arguments.")
end
define_arithmetic_special("+", "0", "0")
define_arithmetic_special("..", "''")
define_arithmetic_special("^")
define_arithmetic_special("-", nil, "")
define_arithmetic_special("*", "1", "1")
define_arithmetic_special("%")
define_arithmetic_special("/", nil, "1")
define_arithmetic_special("//", nil, "1")
SPECIALS["or"] = function(ast, scope, parent)
  return operator_special("or", "false", nil, ast, scope, parent)
end
SPECIALS["and"] = function(ast, scope, parent)
  return operator_special("and", "true", nil, ast, scope, parent)
end
doc_special("and", {"a", "b", "..."}, "Boolean operator; works the same as Lua but accepts more arguments.")
doc_special("or", {"a", "b", "..."}, "Boolean operator; works the same as Lua but accepts more arguments.")
local function bitop_special(native_name, lib_name, zero_arity, unary_prefix, ast, scope, parent)
  if (#ast == 1) then
    return compiler.assert(zero_arity, "Expected more than 0 arguments.", ast)
  else
    local len = #ast
    local operands = {}
    local padded_native_name = (" " .. native_name .. " ")
    local prefixed_lib_name = ("bit." .. lib_name)
    for i = 2, len do
      local subexprs = nil
      local _133_
      if (i ~= len) then
        _133_ = 1
      else
      _133_ = nil
      end
      subexprs = compiler.compile1(ast[i], scope, parent, {nval = _133_})
      local tbl_17_ = operands
      local i_18_ = #tbl_17_
      for _, s in ipairs(subexprs) do
        local val_19_ = tostring(s)
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
    end
    if (#operands == 1) then
      if utils.root.options.useBitLib then
        return (prefixed_lib_name .. "(" .. unary_prefix .. ", " .. operands[1] .. ")")
      else
        return ("(" .. unary_prefix .. padded_native_name .. operands[1] .. ")")
      end
    else
      if utils.root.options.useBitLib then
        return (prefixed_lib_name .. "(" .. table.concat(operands, ", ") .. ")")
      else
        return ("(" .. table.concat(operands, padded_native_name) .. ")")
      end
    end
  end
end
local function define_bitop_special(name, zero_arity, unary_prefix, native)
  local function _140_(...)
    return bitop_special(native, name, zero_arity, unary_prefix, ...)
  end
  SPECIALS[name] = _140_
  return nil
end
define_bitop_special("lshift", nil, "1", "<<")
define_bitop_special("rshift", nil, "1", ">>")
define_bitop_special("band", "-1", "-1", "&")
define_bitop_special("bor", "0", "0", "|")
define_bitop_special("bxor", "0", "0", "~")
doc_special("lshift", {"x", "n"}, "Bitwise logical left shift of x by n bits.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("rshift", {"x", "n"}, "Bitwise logical right shift of x by n bits.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("band", {"x1", "x2", "..."}, "Bitwise AND of any number of arguments.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("bor", {"x1", "x2", "..."}, "Bitwise OR of any number of arguments.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("bxor", {"x1", "x2", "..."}, "Bitwise XOR of any number of arguments.\nOnly works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
SPECIALS.bnot = function(ast, scope, parent)
  compiler.assert((#ast == 2), "expected one argument", ast)
  local _141_ = compiler.compile1(ast[2], scope, parent, {nval = 1})
  local value = _141_[1]
  if utils.root.options.useBitLib then
    return ("bit.bnot(" .. tostring(value) .. ")")
  else
    return ("~(" .. tostring(value) .. ")")
  end
end
doc_special("bnot", {"x"}, "Bitwise negation; only works in Lua 5.3+ or LuaJIT with the --use-bit-lib flag.")
doc_special("..", {"a", "b", "..."}, "String concatenation operator; works the same as Lua but accepts more arguments.")
local function native_comparator(op, _143_0, scope, parent)
  local _144_ = _143_0
  local _ = _144_[1]
  local lhs_ast = _144_[2]
  local rhs_ast = _144_[3]
  local _145_ = compiler.compile1(lhs_ast, scope, parent, {nval = 1})
  local lhs = _145_[1]
  local _146_ = compiler.compile1(rhs_ast, scope, parent, {nval = 1})
  local rhs = _146_[1]
  return string.format("(%s %s %s)", tostring(lhs), op, tostring(rhs))
end
local function idempotent_comparator(op, chain_op, ast, scope, parent)
  local vals = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i = 2, #ast do
      local val_19_ = str1(compiler.compile1(ast[i], scope, parent, {nval = 1}))
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    vals = tbl_17_
  end
  local comparisons = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i = 1, (#vals - 1) do
      local val_19_ = string.format("(%s %s %s)", vals[i], op, vals[(i + 1)])
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    comparisons = tbl_17_
  end
  local chain = string.format(" %s ", (chain_op or "and"))
  return ("(" .. table.concat(comparisons, chain) .. ")")
end
local function binding_comparator(op, chain_op, ast, scope, parent)
  local binding_left = {}
  local binding_right = {}
  local vals = {}
  local chain = string.format(" %s ", (chain_op or "and"))
  for i = 2, #ast do
    local compiled = str1(compiler.compile1(ast[i], scope, parent, {nval = 1}))
    if (utils["idempotent-expr?"](ast[i]) or (i == 2) or (i == #ast)) then
      table.insert(vals, compiled)
    else
      local my_sym = compiler.gensym(scope)
      table.insert(binding_left, my_sym)
      table.insert(binding_right, compiled)
      table.insert(vals, my_sym)
    end
  end
  compiler.emit(parent, string.format("local %s = %s", table.concat(binding_left, ", "), table.concat(binding_right, ", "), ast))
  local _150_
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i = 1, (#vals - 1) do
      local val_19_ = string.format("(%s %s %s)", vals[i], op, vals[(i + 1)])
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    _150_ = tbl_17_
  end
  return ("(" .. table.concat(_150_, chain) .. ")")
end
local function define_comparator_special(name, _3flua_op, _3fchain_op)
  do
    local op = (_3flua_op or name)
    local function opfn(ast, scope, parent)
      compiler.assert((2 < #ast), "expected at least two arguments", ast)
      local _152_0 = comparator_special_type(ast)
      if (_152_0 == "native") then
        return native_comparator(op, ast, scope, parent)
      elseif (_152_0 == "idempotent") then
        return idempotent_comparator(op, _3fchain_op, ast, scope, parent)
      elseif (_152_0 == "binding") then
        return binding_comparator(op, _3fchain_op, ast, scope, parent)
      else
        local _ = _152_0
        return error("internal compiler error. please report this to the fennel devs.")
      end
    end
    SPECIALS[name] = opfn
  end
  return doc_special(name, {"a", "b", "..."}, "Comparison operator; works the same as Lua but accepts more arguments.")
end
define_comparator_special(">")
define_comparator_special("<")
define_comparator_special(">=")
define_comparator_special("<=")
define_comparator_special("=", "==")
define_comparator_special("not=", "~=", "or")
local function define_unary_special(op, _3frealop)
  local function opfn(ast, scope, parent)
    compiler.assert((#ast == 2), "expected one argument", ast)
    local tail = compiler.compile1(ast[2], scope, parent, {nval = 1})
    return ((_3frealop or op) .. str1(tail))
  end
  SPECIALS[op] = opfn
  return nil
end
define_unary_special("not", "not ")
doc_special("not", {"x"}, "Logical operator; works the same as Lua.")
define_unary_special("length", "#")
doc_special("length", {"x"}, "Returns the length of a table or string.")
SPECIALS["~="] = SPECIALS["not="]
SPECIALS["#"] = SPECIALS.length
local function compile_time_3f(scope)
  return ((scope == compiler.scopes.compiler) or (scope.parent and compile_time_3f(scope.parent)))
end
SPECIALS.quote = function(ast, scope, parent)
  compiler.assert((#ast == 2), "expected one argument", ast)
  return compiler["do-quote"](ast[2], scope, parent, not compile_time_3f(scope))
end
doc_special("quote", {"x"}, "Quasiquote the following form. Only works in macro/compiler scope.")
local macro_loaded = {}
local function safe_getmetatable(tbl)
  local mt = getmetatable(tbl)
  assert((mt ~= getmetatable("")), "Illegal metatable access!")
  return mt
end
local safe_require = nil
local function safe_compiler_env()
  local _155_
  do
    local _154_0 = rawget(_G, "utf8")
    if (nil ~= _154_0) then
      _155_ = utils.copy(_154_0)
    else
      _155_ = _154_0
    end
  end
  return {_VERSION = _VERSION, assert = assert, bit = rawget(_G, "bit"), error = error, getmetatable = safe_getmetatable, ipairs = ipairs, math = utils.copy(math), next = next, pairs = utils.stablepairs, pcall = pcall, print = print, rawequal = rawequal, rawget = rawget, rawlen = rawget(_G, "rawlen"), rawset = rawset, require = safe_require, select = select, setmetatable = setmetatable, string = utils.copy(string), table = utils.copy(table), tonumber = tonumber, tostring = tostring, type = type, utf8 = _155_, xpcall = xpcall}
end
local function combined_mt_pairs(env)
  local combined = {}
  local _157_ = getmetatable(env)
  local __index = _157_["__index"]
  if ("table" == type(__index)) then
    for k, v in pairs(__index) do
      combined[k] = v
    end
  end
  for k, v in next, env, nil do
    combined[k] = v
  end
  return next, combined, nil
end
local function make_compiler_env(ast, scope, parent, _3fopts)
  local provided = nil
  do
    local _159_0 = (_3fopts or utils.root.options)
    if ((_G.type(_159_0) == "table") and (_159_0["compiler-env"] == "strict")) then
      provided = safe_compiler_env()
    elseif ((_G.type(_159_0) == "table") and (nil ~= _159_0.compilerEnv)) then
      local compilerEnv = _159_0.compilerEnv
      provided = compilerEnv
    elseif ((_G.type(_159_0) == "table") and (nil ~= _159_0["compiler-env"])) then
      local compiler_env = _159_0["compiler-env"]
      provided = compiler_env
    else
      local _ = _159_0
      provided = safe_compiler_env()
    end
  end
  local env = nil
  local function _161_()
    return compiler.scopes.macro
  end
  local function _162_(symbol)
    compiler.assert(compiler.scopes.macro, "must call from macro", ast)
    return compiler.scopes.macro.manglings[tostring(symbol)]
  end
  local function _163_(base)
    return utils.sym(compiler.gensym((compiler.scopes.macro or scope), base))
  end
  local function _164_(form)
    compiler.assert(compiler.scopes.macro, "must call from macro", ast)
    return compiler.macroexpand(form, compiler.scopes.macro)
  end
  env = {["assert-compile"] = compiler.assert, ["ast-source"] = utils["ast-source"], ["comment?"] = utils["comment?"], ["fennel-module-name"] = fennel_module_name, ["get-scope"] = _161_, ["in-scope?"] = _162_, ["list?"] = utils["list?"], ["macro-loaded"] = macro_loaded, ["multi-sym?"] = utils["multi-sym?"], ["sequence?"] = utils["sequence?"], ["sym?"] = utils["sym?"], ["table?"] = utils["table?"], ["varg?"] = utils["varg?"], _AST = ast, _CHUNK = parent, _IS_COMPILER = true, _SCOPE = scope, _SPECIALS = compiler.scopes.global.specials, _VARARG = utils.varg(), comment = utils.comment, gensym = _163_, list = utils.list, macroexpand = _164_, pack = pack, sequence = utils.sequence, sym = utils.sym, unpack = unpack, version = utils.version, view = view}
  env._G = env
  return setmetatable(env, {__index = provided, __newindex = provided, __pairs = combined_mt_pairs})
end
local function _165_(...)
  local tbl_17_ = {}
  local i_18_ = #tbl_17_
  for c in string.gmatch((package.config or ""), "([^\n]+)") do
    local val_19_ = c
    if (nil ~= val_19_) then
      i_18_ = (i_18_ + 1)
      tbl_17_[i_18_] = val_19_
    end
  end
  return tbl_17_
end
local _167_ = _165_(...)
local dirsep = _167_[1]
local pathsep = _167_[2]
local pathmark = _167_[3]
local pkg_config = {dirsep = (dirsep or "/"), pathmark = (pathmark or "?"), pathsep = (pathsep or ";")}
local function escapepat(str)
  return string.gsub(str, "[^%w]", "%%%1")
end
local function search_module(modulename, _3fpathstring)
  local pathsepesc = escapepat(pkg_config.pathsep)
  local pattern = ("([^%s]*)%s"):format(pathsepesc, pathsepesc)
  local no_dot_module = modulename:gsub("%.", pkg_config.dirsep)
  local fullpath = ((_3fpathstring or utils["fennel-module"].path) .. pkg_config.pathsep)
  local function try_path(path)
    local filename = path:gsub(escapepat(pkg_config.pathmark), no_dot_module)
    local _168_0 = io.open(filename)
    if (nil ~= _168_0) then
      local file = _168_0
      file:close()
      return filename
    else
      local _ = _168_0
      return nil, ("no file '" .. filename .. "'")
    end
  end
  local function find_in_path(start, _3ftried_paths)
    local _170_0 = fullpath:match(pattern, start)
    if (nil ~= _170_0) then
      local path = _170_0
      local _171_0, _172_0 = try_path(path)
      if (nil ~= _171_0) then
        local filename = _171_0
        return filename
      elseif ((_171_0 == nil) and (nil ~= _172_0)) then
        local error = _172_0
        local function _174_()
          local _173_0 = (_3ftried_paths or {})
          table.insert(_173_0, error)
          return _173_0
        end
        return find_in_path((start + #path + 1), _174_())
      end
    else
      local _ = _170_0
      local function _176_()
        local tried_paths = table.concat((_3ftried_paths or {}), "\n\9")
        if (_VERSION < "Lua 5.4") then
          return ("\n\9" .. tried_paths)
        else
          return tried_paths
        end
      end
      return nil, _176_()
    end
  end
  return find_in_path(1)
end
local function make_searcher(_3foptions)
  local function _179_(module_name)
    local opts = utils.copy(utils.root.options)
    for k, v in pairs((_3foptions or {})) do
      opts[k] = v
    end
    opts["module-name"] = module_name
    local _180_0, _181_0 = search_module(module_name)
    if (nil ~= _180_0) then
      local filename = _180_0
      local function _182_(...)
        return utils["fennel-module"].dofile(filename, opts, ...)
      end
      return _182_, filename
    elseif ((_180_0 == nil) and (nil ~= _181_0)) then
      local error = _181_0
      return error
    end
  end
  return _179_
end
local function dofile_with_searcher(fennel_macro_searcher, filename, opts, ...)
  local searchers = (package.loaders or package.searchers or {})
  local _ = table.insert(searchers, 1, fennel_macro_searcher)
  local m = utils["fennel-module"].dofile(filename, opts, ...)
  table.remove(searchers, 1)
  return m
end
local function fennel_macro_searcher(module_name)
  local opts = nil
  do
    local _184_0 = utils.copy(utils.root.options)
    _184_0["module-name"] = module_name
    _184_0["env"] = "_COMPILER"
    _184_0["requireAsInclude"] = false
    _184_0["allowedGlobals"] = nil
    opts = _184_0
  end
  local _185_0 = search_module(module_name, utils["fennel-module"]["macro-path"])
  if (nil ~= _185_0) then
    local filename = _185_0
    local _186_
    if (opts["compiler-env"] == _G) then
      local function _187_(...)
        return dofile_with_searcher(fennel_macro_searcher, filename, opts, ...)
      end
      _186_ = _187_
    else
      local function _188_(...)
        return utils["fennel-module"].dofile(filename, opts, ...)
      end
      _186_ = _188_
    end
    return _186_, filename
  end
end
local function lua_macro_searcher(module_name)
  local _191_0 = search_module(module_name, package.path)
  if (nil ~= _191_0) then
    local filename = _191_0
    local code = nil
    do
      local f = io.open(filename)
      local function close_handlers_10_(ok_11_, ...)
        f:close()
        if ok_11_ then
          return ...
        else
          return error(..., 0)
        end
      end
      local function _193_()
        return assert(f:read("*a"))
      end
      code = close_handlers_10_(_G.xpcall(_193_, (package.loaded.fennel or debug).traceback))
    end
    local chunk = load_code(code, make_compiler_env(), filename)
    return chunk, filename
  end
end
local macro_searchers = {fennel_macro_searcher, lua_macro_searcher}
local function search_macro_module(modname, n)
  local _195_0 = macro_searchers[n]
  if (nil ~= _195_0) then
    local f = _195_0
    local _196_0, _197_0 = f(modname)
    if ((nil ~= _196_0) and true) then
      local loader = _196_0
      local _3ffilename = _197_0
      return loader, _3ffilename
    else
      local _ = _196_0
      return search_macro_module(modname, (n + 1))
    end
  end
end
local function sandbox_fennel_module(modname)
  if ((modname == "fennel.macros") or (package and package.loaded and ("table" == type(package.loaded[modname])) and (package.loaded[modname].metadata == compiler.metadata))) then
    local function _200_(_, ...)
      return (compiler.metadata):setall(...)
    end
    return {metadata = {setall = _200_}, view = view}
  end
end
local function _202_(modname)
  local function _203_()
    local loader, filename = search_macro_module(modname, 1)
    compiler.assert(loader, (modname .. " module not found."))
    macro_loaded[modname] = loader(modname, filename)
    return macro_loaded[modname]
  end
  return (macro_loaded[modname] or sandbox_fennel_module(modname) or _203_())
end
safe_require = _202_
local function add_macros(macros_2a, ast, scope)
  compiler.assert(utils["table?"](macros_2a), "expected macros to be table", ast)
  for k, v in pairs(macros_2a) do
    compiler.assert((type(v) == "function"), "expected each macro to be function", ast)
    compiler["check-binding-valid"](utils.sym(k), scope, ast, {["macro?"] = true})
    scope.macros[k] = v
  end
  return nil
end
local function resolve_module_name(_204_0, _scope, _parent, opts)
  local _205_ = _204_0
  local second = _205_[2]
  local filename = _205_["filename"]
  local filename0 = (filename or (utils["table?"](second) and second.filename))
  local module_name = utils.root.options["module-name"]
  local modexpr = compiler.compile(second, opts)
  local modname_chunk = load_code(modexpr)
  return modname_chunk(module_name, filename0)
end
SPECIALS["require-macros"] = function(ast, scope, parent, _3freal_ast)
  compiler.assert((#ast == 2), "Expected one module name argument", (_3freal_ast or ast))
  local modname = resolve_module_name(ast, scope, parent, {})
  compiler.assert(utils["string?"](modname), "module name must compile to string", (_3freal_ast or ast))
  if not macro_loaded[modname] then
    local loader, filename = search_macro_module(modname, 1)
    compiler.assert(loader, (modname .. " module not found."), ast)
    macro_loaded[modname] = compiler.assert(utils["table?"](loader(modname, filename)), "expected macros to be table", (_3freal_ast or ast))
  end
  if ("import-macros" == str1(ast)) then
    return macro_loaded[modname]
  else
    return add_macros(macro_loaded[modname], ast, scope)
  end
end
doc_special("require-macros", {"macro-module-name"}, "Load given module and use its contents as macro definitions in current scope.\nDeprecated.")
local function emit_included_fennel(src, path, opts, sub_chunk)
  local subscope = compiler["make-scope"](utils.root.scope.parent)
  local forms = {}
  if utils.root.options.requireAsInclude then
    subscope.specials.require = compiler["require-include"]
  end
  for _, val in parser.parser(parser["string-stream"](src), path) do
    table.insert(forms, val)
  end
  for i = 1, #forms do
    local subopts = nil
    if (i == #forms) then
      subopts = {tail = true}
    else
      subopts = {nval = 0}
    end
    utils["propagate-options"](opts, subopts)
    compiler.compile1(forms[i], subscope, sub_chunk, subopts)
  end
  return nil
end
local function include_path(ast, opts, path, mod, fennel_3f)
  utils.root.scope.includes[mod] = "fnl/loading"
  local src = nil
  do
    local f = assert(io.open(path))
    local function close_handlers_10_(ok_11_, ...)
      f:close()
      if ok_11_ then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _211_()
      return assert(f:read("*all")):gsub("[\13\n]*$", "")
    end
    src = close_handlers_10_(_G.xpcall(_211_, (package.loaded.fennel or debug).traceback))
  end
  local ret = utils.expr(("require(\"" .. mod .. "\")"), "statement")
  local target = ("package.preload[%q]"):format(mod)
  local preload_str = (target .. " = " .. target .. " or function(...)")
  local temp_chunk, sub_chunk = {}, {}
  compiler.emit(temp_chunk, preload_str, ast)
  compiler.emit(temp_chunk, sub_chunk)
  compiler.emit(temp_chunk, "end", ast)
  for _, v in ipairs(temp_chunk) do
    table.insert(utils.root.chunk, v)
  end
  if fennel_3f then
    emit_included_fennel(src, path, opts, sub_chunk)
  else
    compiler.emit(sub_chunk, src, ast)
  end
  utils.root.scope.includes[mod] = ret
  return ret
end
local function include_circular_fallback(mod, modexpr, fallback, ast)
  if (utils.root.scope.includes[mod] == "fnl/loading") then
    compiler.assert(fallback, "circular include detected", ast)
    return fallback(modexpr)
  end
end
SPECIALS.include = function(ast, scope, parent, opts)
  compiler.assert((#ast == 2), "expected one argument", ast)
  local modexpr = nil
  do
    local _214_0, _215_0 = pcall(resolve_module_name, ast, scope, parent, opts)
    if ((_214_0 == true) and (nil ~= _215_0)) then
      local modname = _215_0
      modexpr = utils.expr(string.format("%q", modname), "literal")
    else
      local _ = _214_0
      modexpr = compiler.compile1(ast[2], scope, parent, {nval = 1})[1]
    end
  end
  if ((modexpr.type ~= "literal") or ((modexpr[1]):byte() ~= 34)) then
    if opts.fallback then
      return opts.fallback(modexpr)
    else
      return compiler.assert(false, "module name must be string literal", ast)
    end
  else
    local mod = load_code(("return " .. modexpr[1]))()
    local oldmod = utils.root.options["module-name"]
    local _ = nil
    utils.root.options["module-name"] = mod
    _ = nil
    local res = nil
    local function _219_()
      local _218_0 = search_module(mod)
      if (nil ~= _218_0) then
        local fennel_path = _218_0
        return include_path(ast, opts, fennel_path, mod, true)
      else
        local _0 = _218_0
        local lua_path = search_module(mod, package.path)
        if lua_path then
          return include_path(ast, opts, lua_path, mod, false)
        elseif opts.fallback then
          return opts.fallback(modexpr)
        else
          return compiler.assert(false, ("module not found " .. mod), ast)
        end
      end
    end
    res = ((utils["member?"](mod, (utils.root.options.skipInclude or {})) and opts.fallback(modexpr, true)) or include_circular_fallback(mod, modexpr, opts.fallback, ast) or utils.root.scope.includes[mod] or _219_())
    utils.root.options["module-name"] = oldmod
    return res
  end
end
doc_special("include", {"module-name-literal"}, "Like require but load the target module during compilation and embed it in the\nLua output. The module must be a string literal and resolvable at compile time.")
local function eval_compiler_2a(ast, scope, parent)
  local env = make_compiler_env(ast, scope, parent)
  local opts = utils.copy(utils.root.options)
  opts.scope = compiler["make-scope"](compiler.scopes.compiler)
  opts.allowedGlobals = current_global_names(env)
  return assert(load_code(compiler.compile(ast, opts), wrap_env(env)))(opts["module-name"], ast.filename)
end
SPECIALS.macros = function(ast, scope, parent)
  compiler.assert((#ast == 2), "Expected one table argument", ast)
  local macro_tbl = eval_compiler_2a(ast[2], scope, parent)
  compiler.assert(utils["table?"](macro_tbl), "Expected one table argument", ast)
  return add_macros(macro_tbl, ast, scope)
end
doc_special("macros", {"{:macro-name-1 (fn [...] ...) ... :macro-name-N macro-body-N}"}, "Define all functions in the given table as macros local to the current scope.")
SPECIALS["tail!"] = function(ast, scope, parent, opts)
  compiler.assert((#ast == 2), "Expected one argument", ast)
  local call = utils["list?"](compiler.macroexpand(ast[2], scope))
  local callee = tostring((call and utils["sym?"](call[1])))
  compiler.assert((call and not scope.specials[callee]), "Expected a function call as argument", ast)
  compiler.assert(opts.tail, "Must be in tail position", ast)
  return compiler.compile1(call, scope, parent, opts)
end
doc_special("tail!", {"body"}, "Assert that the body being called is in tail position.")
SPECIALS["pick-values"] = function(ast, scope, parent)
  local n = ast[2]
  local vals = utils.list(utils.sym("values"), unpack(ast, 3))
  compiler.assert((("number" == type(n)) and (0 <= n) and (n == math.floor(n))), ("Expected n to be an integer >= 0, got " .. tostring(n)))
  if (1 == n) then
    local _223_ = compiler.compile1(vals, scope, parent, {nval = 1})
    local _224_ = _223_[1]
    local expr = _224_[1]
    return {("(" .. expr .. ")")}
  elseif (0 == n) then
    for i = 3, #ast do
      compiler["keep-side-effects"](compiler.compile1(ast[i], scope, parent, {nval = 0}), parent, nil, ast[i])
    end
    return {}
  else
    local syms = nil
    do
      local tbl_17_ = utils.list()
      local i_18_ = #tbl_17_
      for _ = 1, n do
        local val_19_ = utils.sym(compiler.gensym(scope, "pv"))
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      syms = tbl_17_
    end
    compiler.destructure(syms, vals, ast, scope, parent, {declaration = true, nomulti = true, noundef = true, symtype = "pv"})
    return syms
  end
end
doc_special("pick-values", {"n", "..."}, "Evaluate to exactly n values.\n\nFor example,\n  (pick-values 2 ...)\nexpands to\n  (let [(_0_ _1_) ...]\n    (values _0_ _1_))")
SPECIALS["eval-compiler"] = function(ast, scope, parent)
  local old_first = ast[1]
  ast[1] = utils.sym("do")
  local val = eval_compiler_2a(ast, scope, parent)
  ast[1] = old_first
  return val
end
doc_special("eval-compiler", {"..."}, "Evaluate the body at compile-time. Use the macro system instead if possible.", true)
SPECIALS.unquote = function(ast)
  return compiler.assert(false, "tried to use unquote outside quote", ast)
end
doc_special("unquote", {"..."}, "Evaluate the argument even if it's in a quoted form.")
return {["current-global-names"] = current_global_names, ["get-function-metadata"] = get_function_metadata, ["load-code"] = load_code, ["macro-loaded"] = macro_loaded, ["macro-searchers"] = macro_searchers, ["make-compiler-env"] = make_compiler_env, ["make-searcher"] = make_searcher, ["search-module"] = search_module, ["wrap-env"] = wrap_env, doc = doc_2a}
