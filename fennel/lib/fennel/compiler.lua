local _1_ = require("fennel.utils")
local utils = _1_
local unpack = _1_["unpack"]
local parser = require("fennel.parser")
local friend = require("fennel.friend")
local view = require("fennel.view")
local scopes = {compiler = nil, global = nil, macro = nil}
local function make_scope(_3fparent)
  local parent = (_3fparent or scopes.global)
  local _2_
  if parent then
    _2_ = ((parent.depth or 0) + 1)
  else
    _2_ = 0
  end
  return {["gensym-base"] = setmetatable({}, {__index = (parent and parent["gensym-base"])}), autogensyms = setmetatable({}, {__index = (parent and parent.autogensyms)}), depth = _2_, gensyms = setmetatable({}, {__index = (parent and parent.gensyms)}), hashfn = (parent and parent.hashfn), includes = setmetatable({}, {__index = (parent and parent.includes)}), macros = setmetatable({}, {__index = (parent and parent.macros)}), manglings = setmetatable({}, {__index = (parent and parent.manglings)}), parent = parent, refedglobals = {}, specials = setmetatable({}, {__index = (parent and parent.specials)}), symmeta = setmetatable({}, {__index = (parent and parent.symmeta)}), unmanglings = setmetatable({}, {__index = (parent and parent.unmanglings)}), vararg = (parent and parent.vararg)}
end
local function assert_msg(ast, msg)
  local ast_tbl = nil
  if ("table" == type(ast)) then
    ast_tbl = ast
  else
    ast_tbl = {}
  end
  local m = getmetatable(ast)
  local filename = ((m and m.filename) or ast_tbl.filename or "unknown")
  local line = ((m and m.line) or ast_tbl.line or "?")
  local col = ((m and m.col) or ast_tbl.col or "?")
  local target = tostring((utils["sym?"](ast_tbl[1]) or ast_tbl[1] or "()"))
  return string.format("%s:%s:%s: Compile error in '%s': %s", filename, line, col, target, msg)
end
local function assert_compile(condition, msg, ast, _3ffallback_ast)
  if not condition then
    local _5_ = (utils.root.options or {})
    local error_pinpoint = _5_["error-pinpoint"]
    local source = _5_["source"]
    local unfriendly = _5_["unfriendly"]
    local ast0 = nil
    if next(utils["ast-source"](ast)) then
      ast0 = ast
    else
      ast0 = (_3ffallback_ast or {})
    end
    if (nil == utils.hook("assert-compile", condition, msg, ast0, utils.root.reset)) then
      utils.root.reset()
      if unfriendly then
        error(assert_msg(ast0, msg), 0)
      else
        friend["assert-compile"](condition, msg, ast0, source, {["error-pinpoint"] = error_pinpoint})
      end
    end
  end
  return condition
end
scopes.global = make_scope()
scopes.global.vararg = true
scopes.compiler = make_scope(scopes.global)
scopes.macro = scopes.global
local serialize_subst_digits = {["\\10"] = "\\n", ["\\11"] = "\\v", ["\\12"] = "\\f", ["\\13"] = "\\r", ["\\7"] = "\\a", ["\\8"] = "\\b", ["\\9"] = "\\t"}
local function serialize_string(str)
  local function _10_(_241)
    return ("\\" .. _241:byte())
  end
  return string.gsub(string.gsub(string.gsub(string.format("%q", str), "\\\n", "\\n"), "\\..?", serialize_subst_digits), "[\128-\255]", _10_)
end
local function global_mangling(str)
  if utils["valid-lua-identifier?"](str) then
    return str
  else
    local _12_
    do
      local _11_0 = utils.root.options
      if (nil ~= _11_0) then
        _11_0 = _11_0["global-mangle"]
      end
      _12_ = _11_0
    end
    if (_12_ == false) then
      return ("_G[%q]"):format(str)
    else
      local function _14_(_241)
        return string.format("_%02x", _241:byte())
      end
      return ("__fnl_global__" .. str:gsub("[^%w]", _14_))
    end
  end
end
local function global_unmangling(identifier)
  local _16_0 = string.match(identifier, "^__fnl_global__(.*)$")
  if (nil ~= _16_0) then
    local rest = _16_0
    local _17_0 = nil
    local function _18_(_241)
      return string.char(tonumber(_241:sub(2), 16))
    end
    _17_0 = rest:gsub("_[%da-f][%da-f]", _18_)
    return _17_0
  else
    local _ = _16_0
    return identifier
  end
end
local function global_allowed_3f(name)
  local allowed = nil
  do
    local _20_0 = utils.root.options
    if (nil ~= _20_0) then
      _20_0 = _20_0.allowedGlobals
    end
    allowed = _20_0
  end
  return (not allowed or utils["member?"](name, allowed))
end
local function unique_mangling(original, mangling, scope, append)
  if scope.unmanglings[mangling] then
    return unique_mangling(original, (original .. append), scope, (append + 1))
  else
    return mangling
  end
end
local function apply_deferred_scope_changes(scope, deferred_scope_changes, ast)
  for raw, mangled in pairs(deferred_scope_changes.manglings) do
    assert_compile(not scope.refedglobals[mangled], ("use of global " .. raw .. " is aliased by a local"), ast)
    scope.manglings[raw] = mangled
  end
  for raw, symmeta in pairs(deferred_scope_changes.symmeta) do
    scope.symmeta[raw] = symmeta
  end
  return nil
end
local function combine_parts(parts, scope)
  local ret = (scope.manglings[parts[1]] or global_mangling(parts[1]))
  for i = 2, #parts do
    if utils["valid-lua-identifier?"](parts[i]) then
      if (parts["multi-sym-method-call"] and (i == #parts)) then
        ret = (ret .. ":" .. parts[i])
      else
        ret = (ret .. "." .. parts[i])
      end
    else
      ret = (ret .. "[" .. serialize_string(parts[i]) .. "]")
    end
  end
  return ret
end
local function root_scope(scope)
  return ((utils.root and utils.root.scope) or (scope.parent and root_scope(scope.parent)) or scope)
end
local function next_append(root_scope_2a)
  root_scope_2a["gensym-append"] = ((root_scope_2a["gensym-append"] or 0) + 1)
  return ("_" .. root_scope_2a["gensym-append"] .. "_")
end
local function gensym(scope, _3fbase, _3fsuffix)
  local root_scope_2a = root_scope(scope)
  local mangling = ((_3fbase or "") .. next_append(root_scope_2a) .. (_3fsuffix or ""))
  while scope.unmanglings[mangling] do
    mangling = ((_3fbase or "") .. next_append(root_scope_2a) .. (_3fsuffix or ""))
  end
  if (_3fbase and (0 < #_3fbase)) then
    scope["gensym-base"][mangling] = _3fbase
  end
  scope.gensyms[mangling] = true
  return mangling
end
local function combine_auto_gensym(parts, first)
  parts[1] = first
  local last = table.remove(parts)
  local last2 = table.remove(parts)
  local last_joiner = ((parts["multi-sym-method-call"] and ":") or ".")
  table.insert(parts, (last2 .. last_joiner .. last))
  return table.concat(parts, ".")
end
local function autogensym(base, scope)
  local _26_0 = utils["multi-sym?"](base)
  if (nil ~= _26_0) then
    local parts = _26_0
    return combine_auto_gensym(parts, autogensym(parts[1], scope))
  else
    local _ = _26_0
    local function _27_()
      local mangling = gensym(scope, base:sub(1, -2), "auto")
      scope.autogensyms[base] = mangling
      return mangling
    end
    return (scope.autogensyms[base] or _27_())
  end
end
local function check_binding_valid(symbol, scope, ast, _3fopts)
  local name = tostring(symbol)
  local macro_3f = nil
  do
    local _29_0 = _3fopts
    if (nil ~= _29_0) then
      _29_0 = _29_0["macro?"]
    end
    macro_3f = _29_0
  end
  assert_compile(("&" ~= name:match("[&.:]")), "invalid character: &", symbol)
  assert_compile(not name:find("^%."), "invalid character: .", symbol)
  assert_compile(not (scope.specials[name] or (not macro_3f and scope.macros[name])), ("local %s was overshadowed by a special form or macro"):format(name), ast)
  return assert_compile(not utils["quoted?"](symbol), string.format("macro tried to bind %s without gensym", name), symbol)
end
local function declare_local(symbol, scope, ast, _3fvar_3f, _3fdeferred_scope_changes)
  check_binding_valid(symbol, scope, ast)
  assert_compile(not utils["multi-sym?"](symbol), ("unexpected multi symbol " .. tostring(symbol)), ast)
  local str = tostring(symbol)
  local raw = nil
  if (utils["lua-keyword?"](str) or str:match("^%d")) then
    raw = ("_" .. str)
  else
    raw = str
  end
  local mangling = nil
  local function _32_(_241)
    return string.format("_%02x", _241:byte())
  end
  mangling = string.gsub(string.gsub(raw, "-", "_"), "[^%w_]", _32_)
  local unique = unique_mangling(mangling, mangling, scope, 0)
  scope.unmanglings[unique] = (scope["gensym-base"][str] or str)
  do
    local target = (_3fdeferred_scope_changes or scope)
    target.manglings[str] = unique
    target.symmeta[str] = {symbol = symbol, var = _3fvar_3f}
  end
  return unique
end
local function hashfn_arg_name(name, multi_sym_parts, scope)
  if not scope.hashfn then
    return nil
  elseif (name == "$") then
    return "$1"
  elseif multi_sym_parts then
    if (multi_sym_parts and (multi_sym_parts[1] == "$")) then
      multi_sym_parts[1] = "$1"
    end
    return table.concat(multi_sym_parts, ".")
  end
end
local function symbol_to_expression(symbol, scope, _3freference_3f)
  utils.hook("symbol-to-expression", symbol, scope, _3freference_3f)
  local name = symbol[1]
  local multi_sym_parts = utils["multi-sym?"](name)
  local name0 = (hashfn_arg_name(name, multi_sym_parts, scope) or name)
  local parts = (multi_sym_parts or {name0})
  local etype = (((1 < #parts) and "expression") or "sym")
  local local_3f = scope.manglings[parts[1]]
  if (local_3f and scope.symmeta[parts[1]]) then
    scope.symmeta[parts[1]]["used"] = true
    symbol.referent = scope.symmeta[parts[1]].symbol
  end
  assert_compile(not scope.macros[parts[1]], "tried to reference a macro without calling it", symbol)
  assert_compile((not scope.specials[parts[1]] or ("require" == parts[1])), "tried to reference a special form without calling it", symbol)
  assert_compile((not _3freference_3f or local_3f or ("_ENV" == parts[1]) or global_allowed_3f(parts[1])), ("unknown identifier: " .. tostring(parts[1])), symbol)
  local function _37_()
    local _36_0 = utils.root.options
    if (nil ~= _36_0) then
      _36_0 = _36_0.allowedGlobals
    end
    return _36_0
  end
  if (_37_() and not local_3f and scope.parent) then
    scope.parent.refedglobals[parts[1]] = true
  end
  return utils.expr(combine_parts(parts, scope), etype)
end
local function emit(chunk, out, _3fast)
  if (type(out) == "table") then
    return table.insert(chunk, out)
  else
    return table.insert(chunk, {ast = _3fast, leaf = out})
  end
end
local function peephole(chunk)
  if chunk.leaf then
    return chunk
  elseif ((3 <= #chunk) and (chunk[(#chunk - 2)].leaf == "do") and not chunk[(#chunk - 1)].leaf and (chunk[#chunk].leaf == "end")) then
    local kid = peephole(chunk[(#chunk - 1)])
    local new_chunk = {ast = chunk.ast}
    for i = 1, (#chunk - 3) do
      table.insert(new_chunk, peephole(chunk[i]))
    end
    for i = 1, #kid do
      table.insert(new_chunk, kid[i])
    end
    return new_chunk
  else
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _, x in ipairs(chunk) do
      local val_19_ = peephole(x)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    return tbl_17_
  end
end
local function flatten_chunk_correlated(main_chunk, options)
  local function flatten(chunk, out, last_line, file)
    local last_line0 = last_line
    if chunk.leaf then
      out[last_line0] = ((out[last_line0] or "") .. " " .. chunk.leaf)
    else
      for _, subchunk in ipairs(chunk) do
        if (subchunk.leaf or next(subchunk)) then
          local source = utils["ast-source"](subchunk.ast)
          if (file == source.filename) then
            last_line0 = math.max(last_line0, (source.line or 0))
          end
          last_line0 = flatten(subchunk, out, last_line0, file)
        end
      end
    end
    return last_line0
  end
  local out = {}
  local last = flatten(main_chunk, out, 1, options.filename)
  for i = 1, last do
    if (out[i] == nil) then
      out[i] = ""
    end
  end
  return table.concat(out, "\n")
end
local function flatten_chunk(file_sourcemap, chunk, tab, depth)
  if chunk.leaf then
    local _47_ = utils["ast-source"](chunk.ast)
    local endline = _47_["endline"]
    local filename = _47_["filename"]
    local line = _47_["line"]
    if ("end" == chunk.leaf) then
      table.insert(file_sourcemap, {filename, (endline or line)})
    else
      table.insert(file_sourcemap, {filename, line})
    end
    return chunk.leaf
  else
    local tab0 = nil
    do
      local _49_0 = tab
      if (_49_0 == true) then
        tab0 = "  "
      elseif (_49_0 == false) then
        tab0 = ""
      elseif (nil ~= _49_0) then
        local tab1 = _49_0
        tab0 = tab1
      elseif (_49_0 == nil) then
        tab0 = ""
      else
      tab0 = nil
      end
    end
    local _51_
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _, c in ipairs(chunk) do
        local val_19_ = nil
        if (c.leaf or next(c)) then
          local sub = flatten_chunk(file_sourcemap, c, tab0, (depth + 1))
          if (0 < depth) then
            val_19_ = (tab0 .. sub:gsub("\n", ("\n" .. tab0)))
          else
            val_19_ = sub
          end
        else
        val_19_ = nil
        end
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      _51_ = tbl_17_
    end
    return table.concat(_51_, "\n")
  end
end
local sourcemap = {}
local function make_short_src(source)
  local source0 = source:gsub("\n", " ")
  if (#source0 <= 49) then
    return ("[fennel \"" .. source0 .. "\"]")
  else
    return ("[fennel \"" .. source0:sub(1, 46) .. "...\"]")
  end
end
local function flatten(chunk, options)
  local chunk0 = peephole(chunk)
  local indent = (options.indent or "  ")
  if options.correlate then
    return flatten_chunk_correlated(chunk0, options), {}
  else
    local file_sourcemap = {}
    local src = flatten_chunk(file_sourcemap, chunk0, indent, 0)
    file_sourcemap.short_src = (options.filename or make_short_src((options.source or src)))
    if options.filename then
      file_sourcemap.key = ("@" .. options.filename)
    else
      file_sourcemap.key = src
    end
    sourcemap[file_sourcemap.key] = file_sourcemap
    return src, file_sourcemap
  end
end
local function make_metadata()
  local function _59_(self, tgt, _3fkey)
    if self[tgt] then
      if (nil ~= _3fkey) then
        return self[tgt][_3fkey]
      else
        return self[tgt]
      end
    end
  end
  local function _62_(self, tgt, key, value)
    self[tgt] = (self[tgt] or {})
    self[tgt][key] = value
    return tgt
  end
  local function _63_(self, tgt, ...)
    local kv_len = select("#", ...)
    local kvs = {...}
    if ((kv_len % 2) ~= 0) then
      error("metadata:setall() expected even number of k/v pairs")
    end
    self[tgt] = (self[tgt] or {})
    for i = 1, kv_len, 2 do
      self[tgt][kvs[i]] = kvs[(i + 1)]
    end
    return tgt
  end
  return setmetatable({}, {__index = {get = _59_, set = _62_, setall = _63_}, __mode = "k"})
end
local function exprs1(exprs)
  local _65_
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _, e in ipairs(exprs) do
      local val_19_ = tostring(e)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    _65_ = tbl_17_
  end
  return table.concat(_65_, ", ")
end
local function keep_side_effects(exprs, chunk, _3fstart, ast)
  for j = (_3fstart or 1), #exprs do
    local subexp = exprs[j]
    if ((subexp.type == "expression") and (subexp[1] ~= "nil")) then
      emit(chunk, ("do local _ = %s end"):format(tostring(subexp)), ast)
    elseif (subexp.type == "statement") then
      local code = tostring(subexp)
      local disambiguated = nil
      if (code:byte() == 40) then
        disambiguated = ("do end " .. code)
      else
        disambiguated = code
      end
      emit(chunk, disambiguated, ast)
    end
  end
  return nil
end
local function handle_compile_opts(exprs, parent, opts, ast)
  if opts.nval then
    local n = opts.nval
    local len = #exprs
    if (n ~= len) then
      if (n < len) then
        keep_side_effects(exprs, parent, (n + 1), ast)
        for i = (n + 1), len do
          exprs[i] = nil
        end
      else
        for i = (#exprs + 1), n do
          exprs[i] = utils.expr("nil", "literal")
        end
      end
    end
  end
  if opts.tail then
    emit(parent, string.format("return %s", exprs1(exprs)), ast)
  end
  if opts.target then
    local result = exprs1(exprs)
    local function _73_()
      if (result == "") then
        return "nil"
      else
        return result
      end
    end
    emit(parent, string.format("%s = %s", opts.target, _73_()), ast)
  end
  if (opts.tail or opts.target) then
    return {returned = true}
  else
    exprs["returned"] = true
    return exprs
  end
end
local function find_macro(ast, scope)
  local macro_2a = nil
  do
    local _76_0 = utils["sym?"](ast[1])
    if (_76_0 ~= nil) then
      local _77_0 = tostring(_76_0)
      if (_77_0 ~= nil) then
        macro_2a = scope.macros[_77_0]
      else
        macro_2a = _77_0
      end
    else
      macro_2a = _76_0
    end
  end
  local multi_sym_parts = utils["multi-sym?"](ast[1])
  if (not macro_2a and multi_sym_parts) then
    local nested_macro = utils["get-in"](scope.macros, multi_sym_parts)
    assert_compile((not scope.macros[multi_sym_parts[1]] or (type(nested_macro) == "function")), "macro not found in imported macro module", ast)
    return nested_macro
  else
    return macro_2a
  end
end
local function propagate_trace_info(_81_0, _index, node)
  local _82_ = _81_0
  local byteend = _82_["byteend"]
  local bytestart = _82_["bytestart"]
  local filename = _82_["filename"]
  local line = _82_["line"]
  do
    local src = utils["ast-source"](node)
    if (("table" == type(node)) and (filename ~= src.filename)) then
      src.filename, src.line, src["from-macro?"] = filename, line, true
      src.bytestart, src.byteend = bytestart, byteend
    end
  end
  return ("table" == type(node))
end
local function quote_literal_nils(index, node, parent)
  if (parent and utils["list?"](parent)) then
    for i = 1, utils.maxn(parent) do
      if (nil == parent[i]) then
        parent[i] = utils.sym("nil")
      end
    end
  end
  return index, node, parent
end
local function built_in_3f(m)
  local found_3f = false
  for _, f in pairs(scopes.global.macros) do
    if found_3f then break end
    found_3f = (f == m)
  end
  return found_3f
end
local function macroexpand_2a(ast, scope, _3fonce)
  local _86_0 = nil
  if utils["list?"](ast) then
    _86_0 = find_macro(ast, scope)
  else
  _86_0 = nil
  end
  if (_86_0 == false) then
    return ast
  elseif (nil ~= _86_0) then
    local macro_2a = _86_0
    local old_scope = scopes.macro
    local _ = nil
    scopes.macro = scope
    _ = nil
    local ok, transformed = nil, nil
    local function _88_()
      return macro_2a(unpack(ast, 2))
    end
    local function _89_()
      if built_in_3f(macro_2a) then
        return tostring
      else
        return debug.traceback
      end
    end
    ok, transformed = xpcall(_88_, _89_())
    local function _90_(...)
      return propagate_trace_info(ast, quote_literal_nils(...))
    end
    utils["walk-tree"](transformed, _90_)
    scopes.macro = old_scope
    assert_compile(ok, transformed, ast)
    utils.hook("macroexpand", ast, transformed, scope)
    if (_3fonce or not transformed) then
      return transformed
    else
      return macroexpand_2a(transformed, scope)
    end
  else
    local _ = _86_0
    return ast
  end
end
local function compile_special(ast, scope, parent, opts, special)
  local exprs = (special(ast, scope, parent, opts) or utils.expr("nil", "literal"))
  local exprs0 = nil
  if ("table" ~= type(exprs)) then
    exprs0 = utils.expr(exprs, "expression")
  else
    exprs0 = exprs
  end
  local exprs2 = nil
  if utils["expr?"](exprs0) then
    exprs2 = {exprs0}
  else
    exprs2 = exprs0
  end
  if not exprs2.returned then
    return handle_compile_opts(exprs2, parent, opts, ast)
  elseif (opts.tail or opts.target) then
    return {returned = true}
  else
    return exprs2
  end
end
local function callable_3f(_96_0, ctype, callee)
  local _97_ = _96_0
  local call_ast = _97_[1]
  if ("literal" == ctype) then
    return ("\"" == string.sub(callee, 1, 1))
  else
    return (utils["sym?"](call_ast) or utils["list?"](call_ast))
  end
end
local function compile_function_call(ast, scope, parent, opts, compile1, len)
  local _99_ = compile1(ast[1], scope, parent, {nval = 1})[1]
  local callee = _99_[1]
  local ctype = _99_["type"]
  local fargs = {}
  assert_compile(callable_3f(ast, ctype, callee), ("cannot call literal value " .. tostring(ast[1])), ast)
  for i = 2, len do
    local subexprs = nil
    local _100_
    if (i ~= len) then
      _100_ = 1
    else
    _100_ = nil
    end
    subexprs = compile1(ast[i], scope, parent, {nval = _100_})
    table.insert(fargs, subexprs[1])
    if (i == len) then
      for j = 2, #subexprs do
        table.insert(fargs, subexprs[j])
      end
    else
      keep_side_effects(subexprs, parent, 2, ast[i])
    end
  end
  local pat = nil
  if ("literal" == ctype) then
    pat = "(%s)(%s)"
  else
    pat = "%s(%s)"
  end
  local call = string.format(pat, tostring(callee), exprs1(fargs))
  return handle_compile_opts({utils.expr(call, "statement")}, parent, opts, ast)
end
local function compile_call(ast, scope, parent, opts, compile1)
  utils.hook("call", ast, scope)
  local len = #ast
  local first = ast[1]
  local multi_sym_parts = utils["multi-sym?"](first)
  local special = (utils["sym?"](first) and scope.specials[tostring(first)])
  assert_compile((0 < len), "expected a function, macro, or special to call", ast)
  if special then
    return compile_special(ast, scope, parent, opts, special)
  elseif (multi_sym_parts and multi_sym_parts["multi-sym-method-call"]) then
    local table_with_method = table.concat({unpack(multi_sym_parts, 1, (#multi_sym_parts - 1))}, ".")
    local method_to_call = multi_sym_parts[#multi_sym_parts]
    local new_ast = utils.list(utils.sym(":", ast), utils.sym(table_with_method, ast), method_to_call, select(2, unpack(ast)))
    return compile1(new_ast, scope, parent, opts)
  else
    return compile_function_call(ast, scope, parent, opts, compile1, len)
  end
end
local function compile_varg(ast, scope, parent, opts)
  local _105_
  if scope.hashfn then
    _105_ = "use $... in hashfn"
  else
    _105_ = "unexpected vararg"
  end
  assert_compile(scope.vararg, _105_, ast)
  return handle_compile_opts({utils.expr("...", "varg")}, parent, opts, ast)
end
local function compile_sym(ast, scope, parent, opts)
  local multi_sym_parts = utils["multi-sym?"](ast)
  assert_compile(not (multi_sym_parts and multi_sym_parts["multi-sym-method-call"]), "multisym method calls may only be in call position", ast)
  local e = nil
  if (ast[1] == "nil") then
    e = utils.expr("nil", "literal")
  else
    e = symbol_to_expression(ast, scope, true)
  end
  return handle_compile_opts({e}, parent, opts, ast)
end
local view_opts = nil
do
  local nan = tostring((0 / 0))
  local _108_
  if (45 == nan:byte()) then
    _108_ = "(0/0)"
  else
    _108_ = "(- (0/0))"
  end
  local _110_
  if (45 == nan:byte()) then
    _110_ = "(- (0/0))"
  else
    _110_ = "(0/0)"
  end
  view_opts = {["negative-infinity"] = "(-1/0)", ["negative-nan"] = _108_, infinity = "(1/0)", nan = _110_}
end
local function compile_scalar(ast, _scope, parent, opts)
  local compiled = nil
  do
    local _112_0 = type(ast)
    if (_112_0 == "nil") then
      compiled = "nil"
    elseif (_112_0 == "boolean") then
      compiled = tostring(ast)
    elseif (_112_0 == "string") then
      compiled = serialize_string(ast)
    elseif (_112_0 == "number") then
      compiled = view(ast, view_opts)
    else
    compiled = nil
    end
  end
  return handle_compile_opts({utils.expr(compiled, "literal")}, parent, opts)
end
local function compile_table(ast, scope, parent, opts, compile1)
  local function escape_key(k)
    if ((type(k) == "string") and utils["valid-lua-identifier?"](k)) then
      return k
    else
      local _114_ = compile1(k, scope, parent, {nval = 1})
      local compiled = _114_[1]
      return ("[" .. tostring(compiled) .. "]")
    end
  end
  local keys = {}
  local buffer = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for i, elem in ipairs(ast) do
      local val_19_ = nil
      do
        local nval = ((nil ~= ast[(i + 1)]) and 1)
        keys[i] = true
        val_19_ = exprs1(compile1(elem, scope, parent, {nval = nval}))
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    buffer = tbl_17_
  end
  do
    local tbl_17_ = buffer
    local i_18_ = #tbl_17_
    for k in utils.stablepairs(ast) do
      local val_19_ = nil
      if not keys[k] then
        local _117_ = compile1(ast[k], scope, parent, {nval = 1})
        local v = _117_[1]
        val_19_ = string.format("%s = %s", escape_key(k), tostring(v))
      else
      val_19_ = nil
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
  end
  return handle_compile_opts({utils.expr(("{" .. table.concat(buffer, ", ") .. "}"), "expression")}, parent, opts, ast)
end
local function compile1(ast, scope, parent, _3fopts)
  local opts = (_3fopts or {})
  local ast0 = macroexpand_2a(ast, scope)
  if utils["list?"](ast0) then
    return compile_call(ast0, scope, parent, opts, compile1)
  elseif utils["varg?"](ast0) then
    return compile_varg(ast0, scope, parent, opts)
  elseif utils["sym?"](ast0) then
    return compile_sym(ast0, scope, parent, opts)
  elseif (type(ast0) == "table") then
    return compile_table(ast0, scope, parent, opts, compile1)
  elseif ((type(ast0) == "nil") or (type(ast0) == "boolean") or (type(ast0) == "number") or (type(ast0) == "string")) then
    return compile_scalar(ast0, scope, parent, opts)
  else
    return assert_compile(false, ("could not compile value of type " .. type(ast0)), ast0)
  end
end
local function destructure(to, from, ast, scope, parent, opts)
  local opts0 = (opts or {})
  local _121_ = opts0
  local declaration = _121_["declaration"]
  local forceglobal = _121_["forceglobal"]
  local forceset = _121_["forceset"]
  local isvar = _121_["isvar"]
  local symtype = _121_["symtype"]
  local symtype0 = ("_" .. (symtype or "dst"))
  local setter = nil
  if declaration then
    setter = "local %s = %s"
  else
    setter = "%s = %s"
  end
  local deferred_scope_changes = {manglings = {}, symmeta = {}}
  local function getname(symbol, ast0)
    local raw = symbol[1]
    assert_compile(not (opts0.nomulti and utils["multi-sym?"](raw)), ("unexpected multi symbol " .. raw), ast0)
    if declaration then
      return declare_local(symbol, scope, symbol, isvar, deferred_scope_changes)
    else
      local parts = (utils["multi-sym?"](raw) or {raw})
      local _123_ = parts
      local first = _123_[1]
      local meta = scope.symmeta[first]
      assert_compile(not raw:find(":"), "cannot set method sym", symbol)
      if ((#parts == 1) and not forceset) then
        assert_compile(not (forceglobal and meta), string.format("global %s conflicts with local", tostring(symbol)), symbol)
        assert_compile(not (meta and not meta.var), ("expected var " .. raw), symbol)
      end
      assert_compile((meta or not opts0.noundef or (scope.hashfn and ("$" == first)) or global_allowed_3f(first)), ("expected local " .. first), symbol)
      if forceglobal then
        assert_compile(not scope.symmeta[scope.unmanglings[raw]], ("global " .. raw .. " conflicts with local"), symbol)
        scope.manglings[raw] = global_mangling(raw)
        scope.unmanglings[global_mangling(raw)] = raw
        local _126_
        do
          local _125_0 = utils.root.options
          if (nil ~= _125_0) then
            _125_0 = _125_0.allowedGlobals
          end
          _126_ = _125_0
        end
        if _126_ then
          local _129_
          do
            local _128_0 = utils.root.options
            if (nil ~= _128_0) then
              _128_0 = _128_0.allowedGlobals
            end
            _129_ = _128_0
          end
          table.insert(_129_, raw)
        end
      end
      return symbol_to_expression(symbol, scope)[1]
    end
  end
  local function compile_top_target(lvalues)
    local inits = nil
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _, l in ipairs(lvalues) do
        local val_19_ = nil
        if scope.manglings[l] then
          val_19_ = l
        else
          val_19_ = "nil"
        end
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      inits = tbl_17_
    end
    local init = table.concat(inits, ", ")
    local lvalue = table.concat(lvalues, ", ")
    local plast = parent[#parent]
    local plen = #parent
    local ret = compile1(from, scope, parent, {target = lvalue})
    if declaration then
      for pi = plen, #parent do
        if (parent[pi] == plast) then
          plen = pi
        end
      end
      if ((#parent == (plen + 1)) and parent[#parent].leaf) then
        parent[#parent]["leaf"] = ("local " .. parent[#parent].leaf)
      elseif (init == "nil") then
        table.insert(parent, (plen + 1), {ast = ast, leaf = ("local " .. lvalue)})
      else
        table.insert(parent, (plen + 1), {ast = ast, leaf = ("local " .. lvalue .. " = " .. init)})
      end
    end
    return ret
  end
  local function destructure_sym(left, rightexprs, up1, top_3f)
    local lname = getname(left, up1)
    check_binding_valid(left, scope, left)
    if top_3f then
      return compile_top_target({lname})
    else
      return emit(parent, setter:format(lname, exprs1(rightexprs)), left)
    end
  end
  local function dynamic_set_target(_140_0)
    local _141_ = _140_0
    local _ = _141_[1]
    local target = _141_[2]
    local keys = {(table.unpack or unpack)(_141_, 3)}
    assert_compile(utils["sym?"](target), "dynamic set needs symbol target", ast)
    assert_compile(next(keys), "dynamic set needs at least one key", ast)
    local keys0 = nil
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _0, k in ipairs(keys) do
        local val_19_ = tostring(compile1(k, scope, parent, {nval = 1})[1])
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      keys0 = tbl_17_
    end
    return string.format("%s[%s]", tostring(symbol_to_expression(target, scope, true)), table.concat(keys0, "]["))
  end
  local function destructure_values(left, rightexprs, up1, destructure1, top_3f)
    local left_names, tables = {}, {}
    for i, name in ipairs(left) do
      if utils["sym?"](name) then
        table.insert(left_names, getname(name, up1))
      elseif utils["call-of?"](name, ".") then
        table.insert(left_names, dynamic_set_target(name))
      else
        local symname = gensym(scope, symtype0)
        table.insert(left_names, symname)
        tables[i] = {name, utils.expr(symname, "sym")}
      end
    end
    assert_compile(left[1], "must provide at least one value", left)
    if top_3f then
      compile_top_target(left_names)
    elseif utils["expr?"](rightexprs) then
      emit(parent, setter:format(table.concat(left_names, ","), exprs1(rightexprs)), left)
    else
      local names = table.concat(left_names, ",")
      local target = nil
      if declaration then
        target = ("local " .. names)
      else
        target = names
      end
      emit(parent, compile1(rightexprs, scope, parent, {target = target}), left)
    end
    for _, pair in utils.stablepairs(tables) do
      destructure1(pair[1], {pair[2]}, left)
    end
    return nil
  end
  local unpack_fn = "function (t, k)\n                        return ((getmetatable(t) or {}).__fennelrest\n                                or function (t, k) return {(table.unpack or unpack)(t, k)} end)(t, k)\n                      end"
  local unpack_ks = "function (t, e)\n                        local rest = {}\n                        for k, v in pairs(t) do\n                          if not e[k] then rest[k] = v end\n                        end\n                        return rest\n                      end"
  local function destructure_kv_rest(s, v, left, excluded_keys, destructure1)
    local exclude_str = nil
    local _146_
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _, k in ipairs(excluded_keys) do
        local val_19_ = string.format("[%s] = true", serialize_string(k))
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      _146_ = tbl_17_
    end
    exclude_str = table.concat(_146_, ", ")
    local subexpr = utils.expr(string.format(string.gsub(("(" .. unpack_ks .. ")(%s, {%s})"), "\n%s*", " "), s, exclude_str), "expression")
    return destructure1(v, {subexpr}, left)
  end
  local function destructure_rest(s, k, left, destructure1)
    local unpack_str = ("(" .. unpack_fn .. ")(%s, %s)")
    local formatted = string.format(string.gsub(unpack_str, "\n%s*", " "), s, k)
    local subexpr = utils.expr(formatted, "expression")
    local function _148_()
      local next_symbol = left[(k + 2)]
      return ((nil == next_symbol) or utils["sym?"](next_symbol, "&as"))
    end
    assert_compile((utils["sequence?"](left) and _148_()), "expected rest argument before last parameter", left)
    return destructure1(left[(k + 1)], {subexpr}, left)
  end
  local function optimize_table_destructure_3f(left, right)
    local function _149_()
      local all = next(left)
      for _, d in ipairs(left) do
        if not all then break end
        all = ((utils["sym?"](d) and not tostring(d):find("^&")) or (utils["list?"](d) and utils["sym?"](d[1], ".")))
      end
      return all
    end
    return (utils["sequence?"](left) and utils["sequence?"](right) and _149_())
  end
  local function destructure_table(left, rightexprs, top_3f, destructure1, up1)
    assert_compile((("table" == type(rightexprs)) and not utils["sym?"](rightexprs, "nil")), "could not destructure literal", left)
    if optimize_table_destructure_3f(left, rightexprs) then
      return destructure_values(utils.list(unpack(left)), utils.list(utils.sym("values"), unpack(rightexprs)), up1, destructure1)
    else
      local right = nil
      do
        local _150_0 = nil
        if top_3f then
          _150_0 = exprs1(compile1(from, scope, parent))
        else
          _150_0 = exprs1(rightexprs)
        end
        if (_150_0 == "") then
          right = "nil"
        elseif (nil ~= _150_0) then
          local right0 = _150_0
          right = right0
        else
        right = nil
        end
      end
      local s = nil
      if utils["sym?"](rightexprs) then
        s = right
      else
        s = gensym(scope, symtype0)
      end
      local excluded_keys = {}
      if not utils["sym?"](rightexprs) then
        emit(parent, string.format("local %s = %s", s, right), left)
      end
      for k, v in utils.stablepairs(left) do
        if not (("number" == type(k)) and tostring(left[(k - 1)]):find("^&")) then
          if (utils["sym?"](k) and (tostring(k) == "&")) then
            destructure_kv_rest(s, v, left, excluded_keys, destructure1)
          elseif (utils["sym?"](v) and (tostring(v) == "&")) then
            destructure_rest(s, k, left, destructure1)
          elseif (utils["sym?"](k) and (tostring(k) == "&as")) then
            destructure_sym(v, {utils.expr(tostring(s))}, left)
          elseif (utils["sequence?"](left) and (tostring(v) == "&as")) then
            local _, next_sym, trailing = select(k, unpack(left))
            assert_compile((nil == trailing), "expected &as argument before last parameter", left)
            destructure_sym(next_sym, {utils.expr(tostring(s))}, left)
          else
            local key = nil
            if (type(k) == "string") then
              key = serialize_string(k)
            else
              key = k
            end
            local subexpr = utils.expr(("%s[%s]"):format(s, key), "expression")
            if (type(k) == "string") then
              table.insert(excluded_keys, k)
            end
            destructure1(v, subexpr, left)
          end
        end
      end
      return nil
    end
  end
  local function destructure1(left, rightexprs, up1, top_3f)
    if (utils["sym?"](left) and (left[1] ~= "nil")) then
      destructure_sym(left, rightexprs, up1, top_3f)
    elseif utils["table?"](left) then
      destructure_table(left, rightexprs, top_3f, destructure1, up1)
    elseif utils["call-of?"](left, ".") then
      destructure_values({left}, rightexprs, up1, destructure1)
    elseif utils["list?"](left) then
      assert_compile(top_3f, "can't nest multi-value destructuring", left)
      destructure_values(left, rightexprs, up1, destructure1, true)
    else
      assert_compile(false, string.format("unable to bind %s %s", type(left), tostring(left)), (((type(up1[2]) == "table") and up1[2]) or up1))
    end
    return (top_3f and {returned = true})
  end
  local ret = destructure1(to, from, ast, true)
  utils.hook("destructure", from, to, scope, opts0)
  apply_deferred_scope_changes(scope, deferred_scope_changes, ast)
  return ret
end
local function require_include(ast, scope, parent, opts)
  opts.fallback = function(e, no_warn)
    if not no_warn then
      utils.warn(("include module not found, falling back to require: %s"):format(tostring(e)), ast)
    end
    return utils.expr(string.format("require(%s)", tostring(e)), "statement")
  end
  return scopes.global.specials.include(ast, scope, parent, opts)
end
local function compile_asts(asts, options)
  local opts = utils.copy(options)
  local scope = nil
  if ("_COMPILER" == opts.scope) then
    scope = scopes.compiler
  elseif opts.scope then
    scope = opts.scope
  else
    scope = make_scope(scopes.global)
  end
  local chunk = {}
  if opts.requireAsInclude then
    scope.specials.require = require_include
  end
  if opts.assertAsRepl then
    scope.macros.assert = scope.macros["assert-repl"]
  end
  local _165_ = utils.root
  _165_["set-reset"](_165_)
  utils.root.chunk, utils.root.scope, utils.root.options = chunk, scope, opts
  for i = 1, #asts do
    local exprs = compile1(asts[i], scope, chunk, {nval = (((i < #asts) and 0) or nil), tail = (i == #asts)})
    keep_side_effects(exprs, chunk, nil, asts[i])
    if (i == #asts) then
      utils.hook("chunk", asts[i], scope)
    end
  end
  utils.root.reset()
  return flatten(chunk, opts)
end
local function compile_stream(stream, _3fopts)
  local opts = (_3fopts or {})
  local asts = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _, ast in parser.parser(stream, opts.filename, opts) do
      local val_19_ = ast
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    asts = tbl_17_
  end
  return compile_asts(asts, opts)
end
local function compile_string(str, _3fopts)
  return compile_stream(parser["string-stream"](str, _3fopts), _3fopts)
end
local function compile(from, _3fopts)
  local _168_0 = type(from)
  if (_168_0 == "userdata") then
    local function _169_()
      local _170_0 = from:read(1)
      if (nil ~= _170_0) then
        return _170_0:byte()
      else
        return _170_0
      end
    end
    return compile_stream(_169_, _3fopts)
  elseif (_168_0 == "function") then
    return compile_stream(from, _3fopts)
  else
    local _ = _168_0
    return compile_asts({from}, _3fopts)
  end
end
local function traceback_frame(info)
  if ((info.what == "C") and info.name) then
    return string.format("\9[C]: in function '%s'", info.name)
  elseif (info.what == "C") then
    return "\9[C]: in ?"
  else
    local remap = sourcemap[info.source]
    if (remap and remap[info.currentline]) then
      if ((remap[info.currentline][1] or "unknown") ~= "unknown") then
        info.short_src = sourcemap[("@" .. remap[info.currentline][1])].short_src
      else
        info.short_src = remap.short_src
      end
      info.currentline = (remap[info.currentline][2] or -1)
    end
    if (info.what == "Lua") then
      local function _175_()
        if info.name then
          return ("'" .. info.name .. "'")
        else
          return "?"
        end
      end
      return string.format("\9%s:%d: in function %s", info.short_src, info.currentline, _175_())
    elseif (info.short_src == "(tail call)") then
      return "  (tail call)"
    else
      return string.format("\9%s:%d: in main chunk", info.short_src, info.currentline)
    end
  end
end
local lua_getinfo = debug.getinfo
local function traceback(_3fmsg, _3fstart)
  local _178_0 = type(_3fmsg)
  if ((_178_0 == "nil") or (_178_0 == "string")) then
    local msg = (_3fmsg or "")
    if ((msg:find("^%g+:%d+:%d+ Compile error:.*") or msg:find("^%g+:%d+:%d+ Parse error:.*")) and not utils["debug-on?"]("trace")) then
      return msg
    else
      local lines = {}
      if (msg:find("^%g+:%d+:%d+ Compile error:") or msg:find("^%g+:%d+:%d+ Parse error:")) then
        table.insert(lines, msg)
      else
        local newmsg = msg:gsub("^[^:]*:%d+:%s+", "runtime error: ")
        table.insert(lines, newmsg)
      end
      table.insert(lines, "stack traceback:")
      local done_3f, level = false, (_3fstart or 2)
      while not done_3f do
        do
          local _180_0 = lua_getinfo(level, "Sln")
          if (_180_0 == nil) then
            done_3f = true
          elseif (nil ~= _180_0) then
            local info = _180_0
            table.insert(lines, traceback_frame(info))
          end
        end
        level = (level + 1)
      end
      return table.concat(lines, "\n")
    end
  else
    local _ = _178_0
    return _3fmsg
  end
end
local function getinfo(thread_or_level, ...)
  local thread_or_level0 = nil
  if ("number" == type(thread_or_level)) then
    thread_or_level0 = (1 + thread_or_level)
  else
    thread_or_level0 = thread_or_level
  end
  local info = lua_getinfo(thread_or_level0, ...)
  local mapped = (info and sourcemap[info.source])
  if mapped then
    for _, key in ipairs({"currentline", "linedefined", "lastlinedefined"}) do
      local mapped_value = nil
      do
        local _185_0 = mapped
        if (nil ~= _185_0) then
          _185_0 = _185_0[info[key]]
        end
        if (nil ~= _185_0) then
          _185_0 = _185_0[2]
        end
        mapped_value = _185_0
      end
      if (info[key] and mapped_value) then
        info[key] = mapped_value
      end
    end
    if info.activelines then
      local tbl_14_ = {}
      for line in pairs(info.activelines) do
        local k_15_, v_16_ = mapped[line][2], true
        if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
          tbl_14_[k_15_] = v_16_
        end
      end
      info.activelines = tbl_14_
    end
    if (info.what == "Lua") then
      info.what = "Fennel"
    end
  end
  return info
end
local function mixed_concat(t, joiner)
  local seen = {}
  local ret, s = "", ""
  for k, v in ipairs(t) do
    table.insert(seen, k)
    ret = (ret .. s .. v)
    s = joiner
  end
  for k, v in utils.stablepairs(t) do
    if not seen[k] then
      ret = (ret .. s .. "[" .. k .. "]" .. "=" .. v)
      s = joiner
    end
  end
  return ret
end
local function do_quote(form, scope, parent, runtime_3f)
  local function quote_all(form0, discard_non_numbers)
    local tbl_14_ = {}
    for k, v in utils.stablepairs(form0) do
      local k_15_, v_16_ = nil, nil
      if (type(k) == "number") then
        k_15_, v_16_ = k, do_quote(v, scope, parent, runtime_3f)
      elseif not discard_non_numbers then
        k_15_, v_16_ = do_quote(k, scope, parent, runtime_3f), do_quote(v, scope, parent, runtime_3f)
      else
      k_15_, v_16_ = nil
      end
      if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
        tbl_14_[k_15_] = v_16_
      end
    end
    return tbl_14_
  end
  if utils["varg?"](form) then
    assert_compile(not runtime_3f, "quoted ... may only be used at compile time", form)
    return "_VARARG"
  elseif utils["sym?"](form) then
    local filename = nil
    if form.filename then
      filename = string.format("%q", form.filename)
    else
      filename = "nil"
    end
    local symstr = tostring(form)
    assert_compile(not runtime_3f, "symbols may only be used at compile time", form)
    if (symstr:find("#$") or symstr:find("#[:.]")) then
      return string.format("_G.sym('%s', {filename=%s, line=%s})", autogensym(symstr, scope), filename, (form.line or "nil"))
    else
      return string.format("_G.sym('%s', {quoted=true, filename=%s, line=%s})", symstr, filename, (form.line or "nil"))
    end
  elseif utils["call-of?"](form, "unquote") then
    local res = unpack(compile1(form[2], scope, parent))
    return res[1]
  elseif utils["list?"](form) then
    local mapped = quote_all(form, true)
    local filename = nil
    if form.filename then
      filename = string.format("%q", form.filename)
    else
      filename = "nil"
    end
    assert_compile(not runtime_3f, "lists may only be used at compile time", form)
    return string.format(("setmetatable({filename=%s, line=%s, bytestart=%s, %s}" .. ", getmetatable(_G.list()))"), filename, (form.line or "nil"), (form.bytestart or "nil"), mixed_concat(mapped, ", "))
  elseif utils["sequence?"](form) then
    local mapped_str = mixed_concat(quote_all(form), ", ")
    local source = getmetatable(form)
    local filename = nil
    if source.filename then
      filename = ("%q"):format(source.filename)
    else
      filename = "nil"
    end
    if runtime_3f then
      return string.format("{%s}", mapped_str)
    else
      return string.format("setmetatable({%s}, {filename=%s, line=%s, sequence=%s})", mapped_str, filename, (source.line or "nil"), "(getmetatable(_G.sequence()))['sequence']")
    end
  elseif (type(form) == "table") then
    local source = getmetatable(form)
    local filename = nil
    if source.filename then
      filename = string.format("%q", source.filename)
    else
      filename = "nil"
    end
    local function _202_()
      if source then
        return source.line
      else
        return "nil"
      end
    end
    return string.format("setmetatable({%s}, {filename=%s, line=%s})", mixed_concat(quote_all(form), ", "), filename, _202_())
  elseif (type(form) == "string") then
    return serialize_string(form)
  else
    return tostring(form)
  end
end
return {["apply-deferred-scope-changes"] = apply_deferred_scope_changes, ["check-binding-valid"] = check_binding_valid, ["compile-stream"] = compile_stream, ["compile-string"] = compile_string, ["declare-local"] = declare_local, ["do-quote"] = do_quote, ["global-allowed?"] = global_allowed_3f, ["global-mangling"] = global_mangling, ["global-unmangling"] = global_unmangling, ["keep-side-effects"] = keep_side_effects, ["make-scope"] = make_scope, ["require-include"] = require_include, ["symbol-to-expression"] = symbol_to_expression, assert = assert_compile, autogensym = autogensym, compile = compile, compile1 = compile1, destructure = destructure, emit = emit, gensym = gensym, getinfo = getinfo, macroexpand = macroexpand_2a, metadata = make_metadata(), scopes = scopes, sourcemap = sourcemap, traceback = traceback}
