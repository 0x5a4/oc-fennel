local utils = require("fennel.utils")
local parser = require("fennel.parser")
local compiler = require("fennel.compiler")
local specials = require("fennel.specials")
local repl = require("fennel.repl")
local view = require("fennel.view")
local function eval_env(env, opts)
  if (env == "_COMPILER") then
    local env0 = specials["make-compiler-env"](nil, compiler.scopes.compiler, {}, opts)
    if (opts.allowedGlobals == nil) then
      opts.allowedGlobals = specials["current-global-names"](env0)
    end
    return specials["wrap-env"](env0)
  else
    return (env and specials["wrap-env"](env))
  end
end
local function eval_opts(options, str)
  local opts = utils.copy(options)
  if (opts.allowedGlobals == nil) then
    opts.allowedGlobals = specials["current-global-names"](opts.env)
  end
  if (not opts.filename and not opts.source) then
    opts.source = str
  end
  if (opts.env == "_COMPILER") then
    opts.scope = compiler["make-scope"](compiler.scopes.compiler)
  end
  return opts
end
local function eval(str, _3foptions, ...)
  local opts = eval_opts(_3foptions, str)
  local env = eval_env(opts.env, opts)
  local lua_source = compiler["compile-string"](str, opts)
  local loader = nil
  local function _6_(...)
    if opts.filename then
      return ("@" .. opts.filename)
    else
      return str
    end
  end
  loader = specials["load-code"](lua_source, env, _6_(...))
  opts.filename = nil
  return loader(...)
end
local function dofile_2a(filename, _3foptions, ...)
  local opts = utils.copy(_3foptions)
  local f = assert(io.open(filename, "rb"))
  local source = assert(f:read("*all"), ("Could not read " .. filename))
  f:close()
  opts.filename = filename
  return eval(source, opts, ...)
end
local function syntax()
  local body_3f = {"when", "with-open", "collect", "icollect", "fcollect", "lambda", "\206\187", "macro", "match", "match-try", "case", "case-try", "accumulate", "faccumulate", "doto"}
  local binding_3f = {"collect", "icollect", "fcollect", "each", "for", "let", "with-open", "accumulate", "faccumulate"}
  local define_3f = {"fn", "lambda", "\206\187", "var", "local", "macro", "macros", "global"}
  local deprecated = {"~=", "#", "global", "require-macros", "pick-args"}
  local out = {}
  for k, v in pairs(compiler.scopes.global.specials) do
    local metadata = (compiler.metadata[v] or {})
    out[k] = {["binding-form?"] = utils["member?"](k, binding_3f), ["body-form?"] = metadata["fnl/body-form?"], ["define?"] = utils["member?"](k, define_3f), ["deprecated?"] = utils["member?"](k, deprecated), ["special?"] = true}
  end
  for k in pairs(compiler.scopes.global.macros) do
    out[k] = {["binding-form?"] = utils["member?"](k, binding_3f), ["body-form?"] = utils["member?"](k, body_3f), ["define?"] = utils["member?"](k, define_3f), ["macro?"] = true}
  end
  for k, v in pairs(_G) do
    local _7_0 = type(v)
    if (_7_0 == "function") then
      out[k] = {["function?"] = true, ["global?"] = true}
    elseif (_7_0 == "table") then
      if not k:find("^_") then
        for k2, v2 in pairs(v) do
          if ("function" == type(v2)) then
            out[(k .. "." .. k2)] = {["function?"] = true, ["global?"] = true}
          end
        end
        out[k] = {["global?"] = true}
      end
    end
  end
  return out
end
local mod = {["ast-source"] = utils["ast-source"], ["comment?"] = utils["comment?"], ["compile-stream"] = compiler["compile-stream"], ["compile-string"] = compiler["compile-string"], ["list?"] = utils["list?"], ["load-code"] = specials["load-code"], ["macro-loaded"] = specials["macro-loaded"], ["macro-path"] = utils["macro-path"], ["macro-searchers"] = specials["macro-searchers"], ["make-searcher"] = specials["make-searcher"], ["multi-sym?"] = utils["multi-sym?"], ["runtime-version"] = utils["runtime-version"], ["search-module"] = specials["search-module"], ["sequence?"] = utils["sequence?"], ["string-stream"] = parser["string-stream"], ["sym-char?"] = parser["sym-char?"], ["sym?"] = utils["sym?"], ["table?"] = utils["table?"], ["varg?"] = utils["varg?"], comment = utils.comment, compile = compiler.compile, compile1 = compiler.compile1, compileStream = compiler["compile-stream"], compileString = compiler["compile-string"], doc = specials.doc, dofile = dofile_2a, eval = eval, gensym = compiler.gensym, getinfo = compiler.getinfo, granulate = parser.granulate, list = utils.list, loadCode = specials["load-code"], macroLoaded = specials["macro-loaded"], macroPath = utils["macro-path"], macroSearchers = specials["macro-searchers"], makeSearcher = specials["make-searcher"], make_searcher = specials["make-searcher"], mangle = compiler["global-mangling"], metadata = compiler.metadata, parser = parser.parser, path = utils.path, repl = repl, runtimeVersion = utils["runtime-version"], scope = compiler["make-scope"], searchModule = specials["search-module"], searcher = specials["make-searcher"](), sequence = utils.sequence, stringStream = parser["string-stream"], sym = utils.sym, syntax = syntax, traceback = compiler.traceback, unmangle = compiler["global-unmangling"], varg = utils.varg, version = utils.version, view = view}
mod.install = function(_3fopts)
  table.insert((package.searchers or package.loaders), specials["make-searcher"](_3fopts))
  return mod
end
utils["fennel-module"] = mod
local function load_macros(src, env)
  local chunk = assert(specials["load-code"](src, env, "src/fennel/macros.fnl"))
  for k, v in pairs(chunk()) do
    compiler.scopes.global.macros[k] = v
  end
  return nil
end
do
  local env = specials["make-compiler-env"](nil, compiler.scopes.compiler, {})
  env.utils = utils
  env["get-function-metadata"] = specials["get-function-metadata"]
  load_macros([===[local function copy(t)
    local out = {}
    for _, v in ipairs(t) do
      table.insert(out, v)
    end
    return setmetatable(out, getmetatable(t))
  end
  utils['fennel-module'].metadata:setall(copy, "fnl/arglist", {"t"})
  local function __3e_2a(val, ...)
    local x = val
    for _, e in ipairs({...}) do
      local elt = nil
      if _G["list?"](e) then
        elt = copy(e)
      else
        elt = list(e)
      end
      table.insert(elt, 2, x)
      x = elt
    end
    return x
  end
  utils['fennel-module'].metadata:setall(__3e_2a, "fnl/arglist", {"val", "..."}, "fnl/docstring", "Thread-first macro.\nTake the first value and splice it into the second form as its first argument.\nThe value of the second form is spliced into the first arg of the third, etc.")
  local function __3e_3e_2a(val, ...)
    local x = val
    for _, e in ipairs({...}) do
      local elt = nil
      if _G["list?"](e) then
        elt = copy(e)
      else
        elt = list(e)
      end
      table.insert(elt, x)
      x = elt
    end
    return x
  end
  utils['fennel-module'].metadata:setall(__3e_3e_2a, "fnl/arglist", {"val", "..."}, "fnl/docstring", "Thread-last macro.\nSame as ->, except splices the value into the last position of each form\nrather than the first.")
  local function __3f_3e_2a(val, _3fe, ...)
    if (nil == _3fe) then
      return val
    elseif not utils["idempotent-expr?"](val) then
      return setmetatable({filename="src/fennel/macros.fnl", line=40, bytestart=1174, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=40}), setmetatable({sym('tmp_3_', nil, {filename="src/fennel/macros.fnl", line=40}), val}, {filename="src/fennel/macros.fnl", line=40}), setmetatable({filename="src/fennel/macros.fnl", line=41, bytestart=1199, sym('-?>', nil, {quoted=true, filename="src/fennel/macros.fnl", line=41}), sym('tmp_3_', nil, {filename="src/fennel/macros.fnl", line=41}), _3fe, ...}, getmetatable(list()))}, getmetatable(list()))
    else
      local call = nil
      if _G["list?"](_3fe) then
        call = copy(_3fe)
      else
        call = list(_3fe)
      end
      table.insert(call, 2, val)
      return setmetatable({filename="src/fennel/macros.fnl", line=44, bytestart=1317, sym('if', nil, {quoted=true, filename="src/fennel/macros.fnl", line=44}), setmetatable({filename="src/fennel/macros.fnl", line=44, bytestart=1321, sym('not=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=44}), sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=44}), val}, getmetatable(list())), __3f_3e_2a(call, ...)}, getmetatable(list()))
    end
  end
  utils['fennel-module'].metadata:setall(__3f_3e_2a, "fnl/arglist", {"val", "?e", "..."}, "fnl/docstring", "Nil-safe thread-first macro.\nSame as -> except will short-circuit with nil when it encounters a nil value.")
  local function __3f_3e_3e_2a(val, _3fe, ...)
    if (nil == _3fe) then
      return val
    elseif not utils["idempotent-expr?"](val) then
      return setmetatable({filename="src/fennel/macros.fnl", line=54, bytestart=1627, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=54}), setmetatable({sym('tmp_6_', nil, {filename="src/fennel/macros.fnl", line=54}), val}, {filename="src/fennel/macros.fnl", line=54}), setmetatable({filename="src/fennel/macros.fnl", line=55, bytestart=1652, sym('-?>>', nil, {quoted=true, filename="src/fennel/macros.fnl", line=55}), sym('tmp_6_', nil, {filename="src/fennel/macros.fnl", line=55}), _3fe, ...}, getmetatable(list()))}, getmetatable(list()))
    else
      local call = nil
      if _G["list?"](_3fe) then
        call = copy(_3fe)
      else
        call = list(_3fe)
      end
      table.insert(call, val)
      return setmetatable({filename="src/fennel/macros.fnl", line=58, bytestart=1769, sym('if', nil, {quoted=true, filename="src/fennel/macros.fnl", line=58}), setmetatable({filename="src/fennel/macros.fnl", line=58, bytestart=1773, sym('not=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=58}), val, sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=58})}, getmetatable(list())), __3f_3e_3e_2a(call, ...)}, getmetatable(list()))
    end
  end
  utils['fennel-module'].metadata:setall(__3f_3e_3e_2a, "fnl/arglist", {"val", "?e", "..."}, "fnl/docstring", "Nil-safe thread-last macro.\nSame as ->> except will short-circuit with nil when it encounters a nil value.")
  local function _3fdot(tbl, ...)
    local head = gensym("t")
    local lookups = setmetatable({filename="src/fennel/macros.fnl", line=66, bytestart=2024, sym('do', nil, {quoted=true, filename="src/fennel/macros.fnl", line=66}), setmetatable({filename="src/fennel/macros.fnl", line=67, bytestart=2047, sym('var', nil, {quoted=true, filename="src/fennel/macros.fnl", line=67}), head, tbl}, getmetatable(list())), head}, getmetatable(list()))
    for i, k in ipairs({...}) do
      table.insert(lookups, (i + 2), setmetatable({filename="src/fennel/macros.fnl", line=73, bytestart=2335, sym('if', nil, {quoted=true, filename="src/fennel/macros.fnl", line=73}), setmetatable({filename="src/fennel/macros.fnl", line=73, bytestart=2339, sym('not=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=73}), sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=73}), head}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=73, bytestart=2356, sym('set', nil, {quoted=true, filename="src/fennel/macros.fnl", line=73}), head, setmetatable({filename="src/fennel/macros.fnl", line=73, bytestart=2367, sym('.', nil, {quoted=true, filename="src/fennel/macros.fnl", line=73}), head, k}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list())))
    end
    return lookups
  end
  utils['fennel-module'].metadata:setall(_3fdot, "fnl/arglist", {"tbl", "..."}, "fnl/docstring", "Nil-safe table look up.\nSame as . (dot), except will short-circuit with nil when it encounters\na nil value in any of subsequent keys.")
  local function doto_2a(val, ...)
    assert((val ~= nil), "missing subject")
    if not utils["idempotent-expr?"](val) then
      return setmetatable({filename="src/fennel/macros.fnl", line=80, bytestart=2585, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=80}), setmetatable({sym('tmp_9_', nil, {filename="src/fennel/macros.fnl", line=80}), val}, {filename="src/fennel/macros.fnl", line=80}), setmetatable({filename="src/fennel/macros.fnl", line=81, bytestart=2609, sym('doto', nil, {quoted=true, filename="src/fennel/macros.fnl", line=81}), sym('tmp_9_', nil, {filename="src/fennel/macros.fnl", line=81}), ...}, getmetatable(list()))}, getmetatable(list()))
    else
      local form = setmetatable({filename="src/fennel/macros.fnl", line=82, bytestart=2643, sym('do', nil, {quoted=true, filename="src/fennel/macros.fnl", line=82})}, getmetatable(list()))
      for _, elt in ipairs({...}) do
        local elt0 = nil
        if _G["list?"](elt) then
          elt0 = copy(elt)
        else
          elt0 = list(elt)
        end
        table.insert(elt0, 2, val)
        table.insert(form, elt0)
      end
      table.insert(form, val)
      return form
    end
  end
  utils['fennel-module'].metadata:setall(doto_2a, "fnl/arglist", {"val", "..."}, "fnl/docstring", "Evaluate val and splice it into the first argument of subsequent forms.")
  local function when_2a(condition, body1, ...)
    assert(body1, "expected body")
    return setmetatable({filename="src/fennel/macros.fnl", line=93, bytestart=2992, sym('if', nil, {quoted=true, filename="src/fennel/macros.fnl", line=93}), condition, setmetatable({filename="src/fennel/macros.fnl", line=94, bytestart=3014, sym('do', nil, {quoted=true, filename="src/fennel/macros.fnl", line=94}), body1, ...}, getmetatable(list()))}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(when_2a, "fnl/arglist", {"condition", "body1", "..."}, "fnl/docstring", "Evaluate body for side-effects only when condition is truthy.")
  local function with_open_2a(closable_bindings, ...)
    local bodyfn = setmetatable({filename="src/fennel/macros.fnl", line=102, bytestart=3312, sym('fn', nil, {quoted=true, filename="src/fennel/macros.fnl", line=102}), setmetatable({}, {filename="src/fennel/macros.fnl", line=102}), ...}, getmetatable(list()))
    local closer = setmetatable({filename="src/fennel/macros.fnl", line=104, bytestart=3359, sym('fn', nil, {quoted=true, filename="src/fennel/macros.fnl", line=104}), sym('close-handlers_12_', nil, {filename="src/fennel/macros.fnl", line=104}), setmetatable({sym('ok_13_', nil, {filename="src/fennel/macros.fnl", line=104}), _VARARG}, {filename="src/fennel/macros.fnl", line=104}), setmetatable({filename="src/fennel/macros.fnl", line=105, bytestart=3407, sym('if', nil, {quoted=true, filename="src/fennel/macros.fnl", line=105}), sym('ok_13_', nil, {filename="src/fennel/macros.fnl", line=105}), _VARARG, setmetatable({filename="src/fennel/macros.fnl", line=105, bytestart=3419, sym('error', nil, {quoted=true, filename="src/fennel/macros.fnl", line=105}), _VARARG, 0}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))
    local traceback = setmetatable({filename="src/fennel/macros.fnl", line=106, bytestart=3454, sym('.', nil, {quoted=true, filename="src/fennel/macros.fnl", line=106}), setmetatable({filename="src/fennel/macros.fnl", line=106, bytestart=3457, sym('or', nil, {quoted=true, filename="src/fennel/macros.fnl", line=106}), setmetatable({filename="src/fennel/macros.fnl", line=106, bytestart=3461, sym('?.', nil, {quoted=true, filename="src/fennel/macros.fnl", line=106}), sym('_G', nil, {quoted=true, filename="src/fennel/macros.fnl", line=106}), "package", "loaded", _G["fennel-module-name"]()}, getmetatable(list())), sym('_G.debug', nil, {quoted=true, filename="src/fennel/macros.fnl", line=107}), setmetatable({["traceback"]=setmetatable({filename=nil, line=nil, bytestart=nil, sym('hashfn', nil, {quoted=true, filename=nil, line=nil}), ""}, getmetatable(list()))}, {filename="src/fennel/macros.fnl", line=107})}, getmetatable(list())), "traceback"}, getmetatable(list()))
    for i = 1, #closable_bindings, 2 do
      assert(_G["sym?"](closable_bindings[i]), "with-open only allows symbols in bindings")
      table.insert(closer, 4, setmetatable({filename="src/fennel/macros.fnl", line=111, bytestart=3752, sym(':', nil, {quoted=true, filename="src/fennel/macros.fnl", line=111}), closable_bindings[i], "close"}, getmetatable(list())))
    end
    return setmetatable({filename="src/fennel/macros.fnl", line=112, bytestart=3795, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=112}), closable_bindings, closer, setmetatable({filename="src/fennel/macros.fnl", line=114, bytestart=3841, sym('close-handlers_12_', nil, {filename="src/fennel/macros.fnl", line=114}), setmetatable({filename="src/fennel/macros.fnl", line=114, bytestart=3858, sym('_G.xpcall', nil, {quoted=true, filename="src/fennel/macros.fnl", line=114}), bodyfn, traceback}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(with_open_2a, "fnl/arglist", {"closable-bindings", "..."}, "fnl/docstring", "Like `let`, but invokes (v:close) on each binding after evaluating the body.\nThe body is evaluated inside `xpcall` so that bound values will be closed upon\nencountering an error before propagating it.")
  local function extract_into(iter_tbl)
    local into, iter_out, found_3f = {}, copy(iter_tbl)
    for i = #iter_tbl, 2, -1 do
      local item = iter_tbl[i]
      if (_G["sym?"](item, "&into") or ("into" == item)) then
        assert(not found_3f, "expected only one &into clause")
        found_3f = true
        into = iter_tbl[(i + 1)]
        table.remove(iter_out, i)
        table.remove(iter_out, i)
      end
    end
    assert((not found_3f or _G["sym?"](into) or _G["table?"](into) or _G["list?"](into)), "expected table, function call, or symbol in &into clause")
    return into, iter_out, found_3f
  end
  utils['fennel-module'].metadata:setall(extract_into, "fnl/arglist", {"iter-tbl"})
  local function collect_2a(iter_tbl, key_expr, value_expr, ...)
    assert((_G["sequence?"](iter_tbl) and (2 <= #iter_tbl)), "expected iterator binding table")
    assert((nil ~= key_expr), "expected key and value expression")
    assert((nil == ...), "expected 1 or 2 body expressions; wrap multiple expressions with do")
    assert((value_expr or _G["list?"](key_expr)), "need key and value")
    local kv_expr = nil
    if (nil == value_expr) then
      kv_expr = key_expr
    else
      kv_expr = setmetatable({filename="src/fennel/macros.fnl", line=151, bytestart=5514, sym('values', nil, {quoted=true, filename="src/fennel/macros.fnl", line=151}), key_expr, value_expr}, getmetatable(list()))
    end
    local into, iter = extract_into(iter_tbl)
    return setmetatable({filename="src/fennel/macros.fnl", line=153, bytestart=5596, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=153}), setmetatable({sym('tbl_16_', nil, {filename="src/fennel/macros.fnl", line=153}), into}, {filename="src/fennel/macros.fnl", line=153}), setmetatable({filename="src/fennel/macros.fnl", line=154, bytestart=5621, sym('each', nil, {quoted=true, filename="src/fennel/macros.fnl", line=154}), iter, setmetatable({filename="src/fennel/macros.fnl", line=155, bytestart=5642, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=155}), setmetatable({setmetatable({filename="src/fennel/macros.fnl", line=155, bytestart=5648, sym('k_17_', nil, {filename="src/fennel/macros.fnl", line=155}), sym('v_18_', nil, {filename="src/fennel/macros.fnl", line=155})}, getmetatable(list())), kv_expr}, {filename="src/fennel/macros.fnl", line=155}), setmetatable({filename="src/fennel/macros.fnl", line=156, bytestart=5677, sym('if', nil, {quoted=true, filename="src/fennel/macros.fnl", line=156}), setmetatable({filename="src/fennel/macros.fnl", line=156, bytestart=5681, sym('and', nil, {quoted=true, filename="src/fennel/macros.fnl", line=156}), setmetatable({filename="src/fennel/macros.fnl", line=156, bytestart=5686, sym('not=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=156}), sym('k_17_', nil, {filename="src/fennel/macros.fnl", line=156}), sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=156})}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=156, bytestart=5700, sym('not=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=156}), sym('v_18_', nil, {filename="src/fennel/macros.fnl", line=156}), sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=156})}, getmetatable(list()))}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=157, bytestart=5728, sym('tset', nil, {quoted=true, filename="src/fennel/macros.fnl", line=157}), sym('tbl_16_', nil, {filename="src/fennel/macros.fnl", line=157}), sym('k_17_', nil, {filename="src/fennel/macros.fnl", line=157}), sym('v_18_', nil, {filename="src/fennel/macros.fnl", line=157})}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list())), sym('tbl_16_', nil, {filename="src/fennel/macros.fnl", line=158})}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(collect_2a, "fnl/arglist", {"iter-tbl", "key-expr", "value-expr", "..."}, "fnl/docstring", "Return a table made by running an iterator and evaluating an expression that\nreturns key-value pairs to be inserted sequentially into the table.  This can\nbe thought of as a table comprehension. The body should provide two expressions\n(used as key and value) or nil, which causes it to be omitted.\n\nFor example,\n  (collect [k v (pairs {:apple \"red\" :orange \"orange\"})]\n    (values v k))\nreturns\n  {:red \"apple\" :orange \"orange\"}\n\nSupports an &into clause after the iterator to put results in an existing table.\nSupports early termination with an &until clause.")
  local function seq_collect(how, iter_tbl, value_expr, ...)
    assert((nil ~= value_expr), "expected table value expression")
    assert((nil == ...), "expected exactly one body expression. Wrap multiple expressions in do")
    local into, iter, has_into_3f = extract_into(iter_tbl)
    if has_into_3f then
      return setmetatable({filename="src/fennel/macros.fnl", line=170, bytestart=6252, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=170}), setmetatable({sym('tbl_19_', nil, {filename="src/fennel/macros.fnl", line=170}), into}, {filename="src/fennel/macros.fnl", line=170}), setmetatable({filename="src/fennel/macros.fnl", line=171, bytestart=6281, how, iter, setmetatable({filename="src/fennel/macros.fnl", line=171, bytestart=6293, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=171}), setmetatable({sym('val_20_', nil, {filename="src/fennel/macros.fnl", line=171}), value_expr}, {filename="src/fennel/macros.fnl", line=171}), setmetatable({filename="src/fennel/macros.fnl", line=172, bytestart=6342, sym('table.insert', nil, {quoted=true, filename="src/fennel/macros.fnl", line=172}), sym('tbl_19_', nil, {filename="src/fennel/macros.fnl", line=172}), sym('val_20_', nil, {filename="src/fennel/macros.fnl", line=172})}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list())), sym('tbl_19_', nil, {filename="src/fennel/macros.fnl", line=173})}, getmetatable(list()))
    else
      return setmetatable({filename="src/fennel/macros.fnl", line=177, bytestart=6618, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=177}), setmetatable({sym('tbl_21_', nil, {filename="src/fennel/macros.fnl", line=177}), setmetatable({}, {filename="src/fennel/macros.fnl", line=177})}, {filename="src/fennel/macros.fnl", line=177}), setmetatable({filename="src/fennel/macros.fnl", line=178, bytestart=6644, sym('var', nil, {quoted=true, filename="src/fennel/macros.fnl", line=178}), sym('i_22_', nil, {filename="src/fennel/macros.fnl", line=178}), 0}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=179, bytestart=6666, how, iter, setmetatable({filename="src/fennel/macros.fnl", line=180, bytestart=6695, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=180}), setmetatable({sym('val_23_', nil, {filename="src/fennel/macros.fnl", line=180}), value_expr}, {filename="src/fennel/macros.fnl", line=180}), setmetatable({filename="src/fennel/macros.fnl", line=181, bytestart=6738, sym('when', nil, {quoted=true, filename="src/fennel/macros.fnl", line=181}), setmetatable({filename="src/fennel/macros.fnl", line=181, bytestart=6744, sym('not=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=181}), sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=181}), sym('val_23_', nil, {filename="src/fennel/macros.fnl", line=181})}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=182, bytestart=6781, sym('set', nil, {quoted=true, filename="src/fennel/macros.fnl", line=182}), sym('i_22_', nil, {filename="src/fennel/macros.fnl", line=182}), setmetatable({filename="src/fennel/macros.fnl", line=182, bytestart=6789, sym('+', nil, {quoted=true, filename="src/fennel/macros.fnl", line=182}), sym('i_22_', nil, {filename="src/fennel/macros.fnl", line=182}), 1}, getmetatable(list()))}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=183, bytestart=6820, sym('tset', nil, {quoted=true, filename="src/fennel/macros.fnl", line=183}), sym('tbl_21_', nil, {filename="src/fennel/macros.fnl", line=183}), sym('i_22_', nil, {filename="src/fennel/macros.fnl", line=183}), sym('val_23_', nil, {filename="src/fennel/macros.fnl", line=183})}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list())), sym('tbl_21_', nil, {filename="src/fennel/macros.fnl", line=184})}, getmetatable(list()))
    end
  end
  utils['fennel-module'].metadata:setall(seq_collect, "fnl/arglist", {"how", "iter-tbl", "value-expr", "..."}, "fnl/docstring", "Common part between icollect and fcollect for producing sequential tables.\n\nIteration code only differs in using the for or each keyword, the rest\nof the generated code is identical.")
  local function icollect_2a(iter_tbl, value_expr, ...)
    assert((_G["sequence?"](iter_tbl) and (2 <= #iter_tbl)), "expected iterator binding table")
    return seq_collect(sym('each', nil, {quoted=true, filename="src/fennel/macros.fnl", line=203}), iter_tbl, value_expr, ...)
  end
  utils['fennel-module'].metadata:setall(icollect_2a, "fnl/arglist", {"iter-tbl", "value-expr", "..."}, "fnl/docstring", "Return a sequential table made by running an iterator and evaluating an\nexpression that returns values to be inserted sequentially into the table.\nThis can be thought of as a table comprehension. If the body evaluates to nil\nthat element is omitted.\n\nFor example,\n  (icollect [_ v (ipairs [1 2 3 4 5])]\n    (when (not= v 3)\n      (* v v)))\nreturns\n  [1 4 16 25]\n\nSupports an &into clause after the iterator to put results in an existing table.\nSupports early termination with an &until clause.")
  local function fcollect_2a(iter_tbl, value_expr, ...)
    assert((_G["sequence?"](iter_tbl) and (2 < #iter_tbl)), "expected range binding table")
    return seq_collect(sym('for', nil, {quoted=true, filename="src/fennel/macros.fnl", line=222}), iter_tbl, value_expr, ...)
  end
  utils['fennel-module'].metadata:setall(fcollect_2a, "fnl/arglist", {"iter-tbl", "value-expr", "..."}, "fnl/docstring", "Return a sequential table made by advancing a range as specified by\nfor, and evaluating an expression that returns values to be inserted\nsequentially into the table.  This can be thought of as a range\ncomprehension. If the body evaluates to nil that element is omitted.\n\nFor example,\n  (fcollect [i 1 10 2]\n    (when (not= i 3)\n      (* i i)))\nreturns\n  [1 25 49 81]\n\nSupports an &into clause after the range to put results in an existing table.\nSupports early termination with an &until clause.")
  local function accumulate_impl(for_3f, iter_tbl, body, ...)
    assert((_G["sequence?"](iter_tbl) and (4 <= #iter_tbl)), "expected initial value and iterator binding table")
    assert((nil ~= body), "expected body expression")
    assert((nil == ...), "expected exactly one body expression. Wrap multiple expressions with do")
    local _25_ = iter_tbl
    local accum_var = _25_[1]
    local accum_init = _25_[2]
    local iter = nil
    local function _26_(...)
      if for_3f then
        return "for"
      else
        return "each"
      end
    end
    iter = sym(_26_(...))
    local function _27_(...)
      if _G["list?"](accum_var) then
        return list(sym("values"), unpack(accum_var))
      else
        return accum_var
      end
    end
    return setmetatable({filename="src/fennel/macros.fnl", line=232, bytestart=8695, sym('do', nil, {quoted=true, filename="src/fennel/macros.fnl", line=232}), setmetatable({filename="src/fennel/macros.fnl", line=233, bytestart=8706, sym('var', nil, {quoted=true, filename="src/fennel/macros.fnl", line=233}), accum_var, accum_init}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=234, bytestart=8742, iter, {unpack(iter_tbl, 3)}, setmetatable({filename="src/fennel/macros.fnl", line=235, bytestart=8786, sym('set', nil, {quoted=true, filename="src/fennel/macros.fnl", line=235}), accum_var, body}, getmetatable(list()))}, getmetatable(list())), _27_(...)}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(accumulate_impl, "fnl/arglist", {"for?", "iter-tbl", "body", "..."})
  local function accumulate_2a(iter_tbl, body, ...)
    return accumulate_impl(false, iter_tbl, body, ...)
  end
  utils['fennel-module'].metadata:setall(accumulate_2a, "fnl/arglist", {"iter-tbl", "body", "..."}, "fnl/docstring", "Accumulation macro.\n\nIt takes a binding table and an expression as its arguments.  In the binding\ntable, the first form starts out bound to the second value, which is an initial\naccumulator. The rest are an iterator binding table in the format `each` takes.\n\nIt runs through the iterator in each step of which the given expression is\nevaluated, and the accumulator is set to the value of the expression. It\neventually returns the final value of the accumulator.\n\nFor example,\n  (accumulate [total 0\n               _ n (pairs {:apple 2 :orange 3})]\n    (+ total n))\nreturns 5")
  local function faccumulate_2a(iter_tbl, body, ...)
    return accumulate_impl(true, iter_tbl, body, ...)
  end
  utils['fennel-module'].metadata:setall(faccumulate_2a, "fnl/arglist", {"iter-tbl", "body", "..."}, "fnl/docstring", "Identical to accumulate, but after the accumulator the binding table is the\nsame as `for` instead of `each`. Like collect to fcollect, will iterate over a\nnumerical range like `for` rather than an iterator.")
  local function partial_2a(f, ...)
    assert(f, "expected a function to partially apply")
    local bindings = {}
    local args = {}
    for _, arg in ipairs({...}) do
      if utils["idempotent-expr?"](arg) then
        table.insert(args, arg)
      else
        local name = gensym()
        table.insert(bindings, name)
        table.insert(bindings, arg)
        table.insert(args, name)
      end
    end
    local body = list(f, unpack(args))
    table.insert(body, _VARARG)
    if (nil == bindings[1]) then
      return setmetatable({filename="src/fennel/macros.fnl", line=280, bytestart=10477, sym('fn', nil, {quoted=true, filename="src/fennel/macros.fnl", line=280}), setmetatable({_VARARG}, {filename="src/fennel/macros.fnl", line=280}), body}, getmetatable(list()))
    else
      return setmetatable({filename="src/fennel/macros.fnl", line=281, bytestart=10510, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=281}), bindings, setmetatable({filename="src/fennel/macros.fnl", line=282, bytestart=10538, sym('fn', nil, {quoted=true, filename="src/fennel/macros.fnl", line=282}), setmetatable({_VARARG}, {filename="src/fennel/macros.fnl", line=282}), body}, getmetatable(list()))}, getmetatable(list()))
    end
  end
  utils['fennel-module'].metadata:setall(partial_2a, "fnl/arglist", {"f", "..."}, "fnl/docstring", "Return a function with all arguments partially applied to f.")
  local function pick_args_2a(n, f)
    if (_G.io and _G.io.stderr) then
      do end (_G.io.stderr):write("-- WARNING: pick-args is deprecated and will be removed in the future.\n")
    end
    local bindings = {}
    for i = 1, n do
      bindings[i] = gensym()
    end
    return setmetatable({filename="src/fennel/macros.fnl", line=291, bytestart=10877, sym('fn', nil, {quoted=true, filename="src/fennel/macros.fnl", line=291}), bindings, setmetatable({filename="src/fennel/macros.fnl", line=291, bytestart=10891, f, unpack(bindings)}, getmetatable(list()))}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(pick_args_2a, "fnl/arglist", {"n", "f"}, "fnl/docstring", "Create a function of arity n that applies its arguments to f. Deprecated.")
  local function lambda_2a(...)
    local args = {...}
    local args_len = #args
    local has_internal_name_3f = _G["sym?"](args[1])
    local arglist = nil
    if has_internal_name_3f then
      arglist = args[2]
    else
      arglist = args[1]
    end
    local metadata_position = nil
    if has_internal_name_3f then
      metadata_position = 3
    else
      metadata_position = 2
    end
    local _, check_position = _G["get-function-metadata"]({"lambda", ...}, arglist, metadata_position)
    local empty_body_3f = (args_len < check_position)
    local function check_21(a)
      if _G["table?"](a) then
        for _0, a0 in pairs(a) do
          check_21(a0)
        end
        return nil
      else
        local _33_
        do
          local as = tostring(a)
          local as1 = as:sub(1, 1)
          _33_ = not (("_" == as1) or ("?" == as1) or ("&" == as) or ("..." == as) or ("&as" == as))
        end
        if _33_ then
          return table.insert(args, check_position, setmetatable({filename="src/fennel/macros.fnl", line=312, bytestart=11826, sym('_G.assert', nil, {quoted=true, filename="src/fennel/macros.fnl", line=312}), setmetatable({filename="src/fennel/macros.fnl", line=312, bytestart=11837, sym('not=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=312}), sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=312}), a}, getmetatable(list())), ("Missing argument %s on %s:%s"):format(tostring(a), (a.filename or "unknown"), (a.line or "?"))}, getmetatable(list())))
        end
      end
    end
    utils['fennel-module'].metadata:setall(check_21, "fnl/arglist", {"a"})
    assert(("table" == type(arglist)), "expected arg list")
    for _0, a in ipairs(arglist) do
      check_21(a)
    end
    if empty_body_3f then
      table.insert(args, sym("nil"))
    end
    return setmetatable({filename="src/fennel/macros.fnl", line=321, bytestart=12271, sym('fn', nil, {quoted=true, filename="src/fennel/macros.fnl", line=321}), unpack(args)}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(lambda_2a, "fnl/arglist", {"..."}, "fnl/docstring", "Function literal with nil-checked arguments.\nLike `fn`, but will throw an exception if a declared argument is passed in as\nnil, unless that argument's name begins with a question mark.")
  local function macro_2a(name, ...)
    assert(_G["sym?"](name), "expected symbol for macro name")
    local args = {...}
    return setmetatable({filename="src/fennel/macros.fnl", line=327, bytestart=12423, sym('macros', nil, {quoted=true, filename="src/fennel/macros.fnl", line=327}), setmetatable({[tostring(name)]=setmetatable({filename="src/fennel/macros.fnl", line=327, bytestart=12449, sym('fn', nil, {quoted=true, filename="src/fennel/macros.fnl", line=327}), unpack(args)}, getmetatable(list()))}, {filename="src/fennel/macros.fnl", line=327})}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(macro_2a, "fnl/arglist", {"name", "..."}, "fnl/docstring", "Define a single macro.")
  local function macrodebug_2a(form, return_3f)
    local handle = nil
    if return_3f then
      handle = sym('do', nil, {quoted=true, filename="src/fennel/macros.fnl", line=332})
    else
      handle = sym('print', nil, {quoted=true, filename="src/fennel/macros.fnl", line=332})
    end
    return setmetatable({filename="src/fennel/macros.fnl", line=335, bytestart=12845, handle, view(macroexpand(form, _SCOPE), {["detect-cycles?"] = false})}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(macrodebug_2a, "fnl/arglist", {"form", "return?"}, "fnl/docstring", "Print the resulting form after performing macroexpansion.\nWith a second argument, returns expanded form as a string instead of printing.")
  local function import_macros_2a(binding1, module_name1, ...)
    assert((binding1 and module_name1 and (0 == (select("#", ...) % 2))), "expected even number of binding/modulename pairs")
    for i = 1, select("#", binding1, module_name1, ...), 2 do
      local binding, modname = select(i, binding1, module_name1, ...)
      local scope = _G["get-scope"]()
      local expr = setmetatable({filename="src/fennel/macros.fnl", line=354, bytestart=14006, sym('import-macros', nil, {quoted=true, filename="src/fennel/macros.fnl", line=354}), modname}, getmetatable(list()))
      local filename = nil
      if _G["list?"](modname) then
        filename = modname[1].filename
      else
        filename = "unknown"
      end
      local _ = nil
      expr.filename = filename
      _ = nil
      local macros_2a = _SPECIALS["require-macros"](expr, scope, {}, binding)
      if _G["sym?"](binding) then
        scope.macros[binding[1]] = macros_2a
      elseif _G["table?"](binding) then
        for macro_name, _38_0 in pairs(binding) do
          local _39_ = _38_0
          local import_key = _39_[1]
          assert(("function" == type(macros_2a[macro_name])), ("macro " .. macro_name .. " not found in module " .. tostring(modname)))
          scope.macros[import_key] = macros_2a[macro_name]
        end
      end
    end
    return nil
  end
  utils['fennel-module'].metadata:setall(import_macros_2a, "fnl/arglist", {"binding1", "module-name1", "..."}, "fnl/docstring", "Bind a table of macros from each macro module according to a binding form.\nEach binding form can be either a symbol or a k/v destructuring table.\nExample:\n  (import-macros mymacros                 :my-macros    ; bind to symbol\n                 {:macro1 alias : macro2} :proj.macros) ; import by name")
  local function assert_repl_2a(condition, ...)
    do local _ = {["fnl/arglist"] = {condition, _G["?message"], ...}} end
    local function add_locals(_41_0, locals)
      local _42_ = _41_0
      local parent = _42_["parent"]
      local symmeta = _42_["symmeta"]
      for name in pairs(symmeta) do
        locals[name] = sym(name)
      end
      if parent then
        return add_locals(parent, locals)
      else
        return locals
      end
    end
    utils['fennel-module'].metadata:setall(add_locals, "fnl/arglist", {"#<table>", "locals"})
    return setmetatable({filename="src/fennel/macros.fnl", line=379, bytestart=15225, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=379}), setmetatable({sym('unpack_44_', nil, {filename="src/fennel/macros.fnl", line=379}), setmetatable({filename="src/fennel/macros.fnl", line=379, bytestart=15239, sym('or', nil, {quoted=true, filename="src/fennel/macros.fnl", line=379}), sym('table.unpack', nil, {quoted=true, filename="src/fennel/macros.fnl", line=379}), sym('_G.unpack', nil, {quoted=true, filename="src/fennel/macros.fnl", line=379})}, getmetatable(list())), sym('pack_46_', nil, {filename="src/fennel/macros.fnl", line=380}), setmetatable({filename="src/fennel/macros.fnl", line=380, bytestart=15282, sym('or', nil, {quoted=true, filename="src/fennel/macros.fnl", line=380}), sym('table.pack', nil, {quoted=true, filename="src/fennel/macros.fnl", line=380}), setmetatable({filename=nil, line=nil, bytestart=nil, sym('hashfn', nil, {quoted=true, filename=nil, line=nil}), setmetatable({filename="src/fennel/macros.fnl", line=380, bytestart=15298, sym('doto', nil, {quoted=true, filename="src/fennel/macros.fnl", line=380}), setmetatable({sym('$...', nil, {quoted=true, filename="src/fennel/macros.fnl", line=380})}, {filename="src/fennel/macros.fnl", line=380}), setmetatable({filename="src/fennel/macros.fnl", line=380, bytestart=15311, sym('tset', nil, {quoted=true, filename="src/fennel/macros.fnl", line=380}), "n", setmetatable({filename="src/fennel/macros.fnl", line=380, bytestart=15320, sym('select', nil, {quoted=true, filename="src/fennel/macros.fnl", line=380}), "#", sym('$...', nil, {quoted=true, filename="src/fennel/macros.fnl", line=380})}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list())), sym('vals_45_', nil, {filename="src/fennel/macros.fnl", line=383}), setmetatable({filename="src/fennel/macros.fnl", line=383, bytestart=15493, sym('pack_46_', nil, {filename="src/fennel/macros.fnl", line=383}), condition, ...}, getmetatable(list())), sym('condition_47_', nil, {filename="src/fennel/macros.fnl", line=384}), setmetatable({filename="src/fennel/macros.fnl", line=384, bytestart=15537, sym('.', nil, {quoted=true, filename="src/fennel/macros.fnl", line=384}), sym('vals_45_', nil, {filename="src/fennel/macros.fnl", line=384}), 1}, getmetatable(list())), sym('message_48_', nil, {filename="src/fennel/macros.fnl", line=385}), setmetatable({filename="src/fennel/macros.fnl", line=385, bytestart=15567, sym('or', nil, {quoted=true, filename="src/fennel/macros.fnl", line=385}), setmetatable({filename="src/fennel/macros.fnl", line=385, bytestart=15571, sym('.', nil, {quoted=true, filename="src/fennel/macros.fnl", line=385}), sym('vals_45_', nil, {filename="src/fennel/macros.fnl", line=385}), 2}, getmetatable(list())), "assertion failed, entering repl."}, getmetatable(list()))}, {filename="src/fennel/macros.fnl", line=379}), setmetatable({filename="src/fennel/macros.fnl", line=386, bytestart=15625, sym('if', nil, {quoted=true, filename="src/fennel/macros.fnl", line=386}), setmetatable({filename="src/fennel/macros.fnl", line=386, bytestart=15629, sym('not', nil, {quoted=true, filename="src/fennel/macros.fnl", line=386}), sym('condition_47_', nil, {filename="src/fennel/macros.fnl", line=386})}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=387, bytestart=15655, sym('let', nil, {quoted=true, filename="src/fennel/macros.fnl", line=387}), setmetatable({sym('opts_49_', nil, {filename="src/fennel/macros.fnl", line=387}), setmetatable({["assert-repl?"]=true}, {filename="src/fennel/macros.fnl", line=387}), sym('fennel_50_', nil, {filename="src/fennel/macros.fnl", line=388}), setmetatable({filename="src/fennel/macros.fnl", line=388, bytestart=15711, sym('require', nil, {quoted=true, filename="src/fennel/macros.fnl", line=388}), _G["fennel-module-name"]()}, getmetatable(list())), sym('locals_51_', nil, {filename="src/fennel/macros.fnl", line=389}), add_locals(_G["get-scope"](), {})}, {filename="src/fennel/macros.fnl", line=387}), setmetatable({filename="src/fennel/macros.fnl", line=390, bytestart=15807, sym('set', nil, {quoted=true, filename="src/fennel/macros.fnl", line=390}), sym('opts_49_.message', nil, {filename="src/fennel/macros.fnl", line=390}), setmetatable({filename="src/fennel/macros.fnl", line=390, bytestart=15826, sym('fennel_50_.traceback', nil, {filename="src/fennel/macros.fnl", line=390}), sym('message_48_', nil, {filename="src/fennel/macros.fnl", line=390})}, getmetatable(list()))}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=391, bytestart=15867, sym('each', nil, {quoted=true, filename="src/fennel/macros.fnl", line=391}), setmetatable({sym('k_52_', nil, {filename="src/fennel/macros.fnl", line=391}), sym('v_53_', nil, {filename="src/fennel/macros.fnl", line=391}), setmetatable({filename="src/fennel/macros.fnl", line=391, bytestart=15880, sym('pairs', nil, {quoted=true, filename="src/fennel/macros.fnl", line=391}), sym('_G', nil, {quoted=true, filename="src/fennel/macros.fnl", line=391})}, getmetatable(list()))}, {filename="src/fennel/macros.fnl", line=391}), setmetatable({filename="src/fennel/macros.fnl", line=392, bytestart=15905, sym('when', nil, {quoted=true, filename="src/fennel/macros.fnl", line=392}), setmetatable({filename="src/fennel/macros.fnl", line=392, bytestart=15911, sym('=', nil, {quoted=true, filename="src/fennel/macros.fnl", line=392}), sym('nil', nil, {quoted=true, filename="src/fennel/macros.fnl", line=392}), setmetatable({filename="src/fennel/macros.fnl", line=392, bytestart=15918, sym('.', nil, {quoted=true, filename="src/fennel/macros.fnl", line=392}), sym('locals_51_', nil, {filename="src/fennel/macros.fnl", line=392}), sym('k_52_', nil, {filename="src/fennel/macros.fnl", line=392})}, getmetatable(list()))}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=392, bytestart=15934, sym('tset', nil, {quoted=true, filename="src/fennel/macros.fnl", line=392}), sym('locals_51_', nil, {filename="src/fennel/macros.fnl", line=392}), sym('k_52_', nil, {filename="src/fennel/macros.fnl", line=392}), sym('v_53_', nil, {filename="src/fennel/macros.fnl", line=392})}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=393, bytestart=15968, sym('set', nil, {quoted=true, filename="src/fennel/macros.fnl", line=393}), sym('opts_49_.env', nil, {filename="src/fennel/macros.fnl", line=393}), sym('locals_51_', nil, {filename="src/fennel/macros.fnl", line=393})}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=394, bytestart=16003, sym('_G.assert', nil, {quoted=true, filename="src/fennel/macros.fnl", line=394}), setmetatable({filename="src/fennel/macros.fnl", line=394, bytestart=16014, sym('fennel_50_.repl', nil, {filename="src/fennel/macros.fnl", line=394}), sym('opts_49_', nil, {filename="src/fennel/macros.fnl", line=394})}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list())), setmetatable({filename="src/fennel/macros.fnl", line=395, bytestart=16046, sym('values', nil, {quoted=true, filename="src/fennel/macros.fnl", line=395}), setmetatable({filename="src/fennel/macros.fnl", line=395, bytestart=16054, sym('unpack_44_', nil, {filename="src/fennel/macros.fnl", line=395}), sym('vals_45_', nil, {filename="src/fennel/macros.fnl", line=395}), 1, sym('vals_45_.n', nil, {filename="src/fennel/macros.fnl", line=395})}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))}, getmetatable(list()))
  end
  utils['fennel-module'].metadata:setall(assert_repl_2a, "fnl/arglist", {"condition", "..."}, "fnl/docstring", "Enter into a debug REPL  and print the message when condition is false/nil.\nWorks as a drop-in replacement for Lua's `assert`.\nREPL `,return` command returns values to assert in place to continue execution.")
  return {["->"] = __3e_2a, ["->>"] = __3e_3e_2a, ["-?>"] = __3f_3e_2a, ["-?>>"] = __3f_3e_3e_2a, ["?."] = _3fdot, ["\206\187"] = lambda_2a, ["assert-repl"] = assert_repl_2a, ["import-macros"] = import_macros_2a, ["pick-args"] = pick_args_2a, ["with-open"] = with_open_2a, accumulate = accumulate_2a, collect = collect_2a, doto = doto_2a, faccumulate = faccumulate_2a, fcollect = fcollect_2a, icollect = icollect_2a, lambda = lambda_2a, macro = macro_2a, macrodebug = macrodebug_2a, partial = partial_2a, when = when_2a}
  ]===], env)
  load_macros([===[local function copy(t)
    local tbl_14_ = {}
    for k, v in pairs(t) do
      local k_15_, v_16_ = k, v
      if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
        tbl_14_[k_15_] = v_16_
      end
    end
    return tbl_14_
  end
  utils['fennel-module'].metadata:setall(copy, "fnl/arglist", {"t"})
  local function double_eval_safe_3f(x, type)
    return (("number" == type) or ("string" == type) or ("boolean" == type) or (_G["sym?"](x) and not _G["multi-sym?"](x)))
  end
  utils['fennel-module'].metadata:setall(double_eval_safe_3f, "fnl/arglist", {"x", "type"})
  local function with(opts, k)
    local _2_0 = copy(opts)
    _2_0[k] = true
    return _2_0
  end
  utils['fennel-module'].metadata:setall(with, "fnl/arglist", {"opts", "k"})
  local function without(opts, k)
    local _3_0 = copy(opts)
    _3_0[k] = nil
    return _3_0
  end
  utils['fennel-module'].metadata:setall(without, "fnl/arglist", {"opts", "k"})
  local function case_values(vals, pattern, unifications, case_pattern, opts)
    local condition = setmetatable({filename="src/fennel/match.fnl", line=20, bytestart=528, sym('and', nil, {quoted=true, filename="src/fennel/match.fnl", line=20})}, getmetatable(list()))
    local bindings = {}
    for i, pat in ipairs(pattern) do
      local subcondition, subbindings = case_pattern({vals[i]}, pat, unifications, without(opts, "multival?"))
      table.insert(condition, subcondition)
      local tbl_17_ = bindings
      local i_18_ = #tbl_17_
      for _, b in ipairs(subbindings) do
        local val_19_ = b
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
    end
    return condition, bindings
  end
  utils['fennel-module'].metadata:setall(case_values, "fnl/arglist", {"vals", "pattern", "unifications", "case-pattern", "opts"})
  local function case_table(val, pattern, unifications, case_pattern, opts, _3ftop)
    local condition = nil
    if ("table" == _3ftop) then
      condition = setmetatable({filename="src/fennel/match.fnl", line=30, bytestart=1005, sym('and', nil, {quoted=true, filename="src/fennel/match.fnl", line=30})}, getmetatable(list()))
    else
      condition = setmetatable({filename="src/fennel/match.fnl", line=30, bytestart=1012, sym('and', nil, {quoted=true, filename="src/fennel/match.fnl", line=30}), setmetatable({filename="src/fennel/match.fnl", line=30, bytestart=1017, sym('=', nil, {quoted=true, filename="src/fennel/match.fnl", line=30}), setmetatable({filename="src/fennel/match.fnl", line=30, bytestart=1020, sym('_G.type', nil, {quoted=true, filename="src/fennel/match.fnl", line=30}), val}, getmetatable(list())), "table"}, getmetatable(list()))}, getmetatable(list()))
    end
    local bindings = {}
    for k, pat in pairs(pattern) do
      if _G["sym?"](pat, "&") then
        local rest_pat = pattern[(k + 1)]
        local rest_val = setmetatable({filename="src/fennel/match.fnl", line=35, bytestart=1195, sym('select', nil, {quoted=true, filename="src/fennel/match.fnl", line=35}), k, setmetatable({filename="src/fennel/match.fnl", line=35, bytestart=1206, setmetatable({filename="src/fennel/match.fnl", line=35, bytestart=1207, sym('or', nil, {quoted=true, filename="src/fennel/match.fnl", line=35}), sym('table.unpack', nil, {quoted=true, filename="src/fennel/match.fnl", line=35}), sym('_G.unpack', nil, {quoted=true, filename="src/fennel/match.fnl", line=35})}, getmetatable(list())), val}, getmetatable(list()))}, getmetatable(list()))
        local subcondition = case_table(setmetatable({filename="src/fennel/match.fnl", line=36, bytestart=1284, sym('pick-values', nil, {quoted=true, filename="src/fennel/match.fnl", line=36}), 1, rest_val}, getmetatable(list())), rest_pat, unifications, case_pattern, without(opts, "multival?"))
        if not _G["sym?"](rest_pat) then
          table.insert(condition, subcondition)
        end
        assert((nil == pattern[(k + 2)]), "expected & rest argument before last parameter")
        table.insert(bindings, rest_pat)
        table.insert(bindings, {rest_val})
      elseif _G["sym?"](k, "&as") then
        table.insert(bindings, pat)
        table.insert(bindings, val)
      elseif (("number" == type(k)) and _G["sym?"](pat, "&as")) then
        assert((nil == pattern[(k + 2)]), "expected &as argument before last parameter")
        table.insert(bindings, pattern[(k + 1)])
        table.insert(bindings, val)
      elseif (("number" ~= type(k)) or (not _G["sym?"](pattern[(k - 1)], "&as") and not _G["sym?"](pattern[(k - 1)], "&"))) then
        local subval = setmetatable({filename="src/fennel/match.fnl", line=58, bytestart=2418, sym('.', nil, {quoted=true, filename="src/fennel/match.fnl", line=58}), val, k}, getmetatable(list()))
        local subcondition, subbindings = case_pattern({subval}, pat, unifications, without(opts, "multival?"))
        table.insert(condition, subcondition)
        local tbl_17_ = bindings
        local i_18_ = #tbl_17_
        for _, b in ipairs(subbindings) do
          local val_19_ = b
          if (nil ~= val_19_) then
            i_18_ = (i_18_ + 1)
            tbl_17_[i_18_] = val_19_
          end
        end
      end
    end
    return condition, bindings
  end
  utils['fennel-module'].metadata:setall(case_table, "fnl/arglist", {"val", "pattern", "unifications", "case-pattern", "opts", "?top"})
  local function case_guard(vals, condition, guards, unifications, case_pattern, opts)
    if guards[1] then
      local pcondition, bindings = case_pattern(vals, condition, unifications, opts)
      local condition0 = setmetatable({filename="src/fennel/match.fnl", line=69, bytestart=3002, sym('and', nil, {quoted=true, filename="src/fennel/match.fnl", line=69}), unpack(guards)}, getmetatable(list()))
      return setmetatable({filename="src/fennel/match.fnl", line=70, bytestart=3042, sym('and', nil, {quoted=true, filename="src/fennel/match.fnl", line=70}), pcondition, setmetatable({filename="src/fennel/match.fnl", line=71, bytestart=3080, sym('let', nil, {quoted=true, filename="src/fennel/match.fnl", line=71}), bindings, condition0}, getmetatable(list()))}, getmetatable(list())), bindings
    else
      return case_pattern(vals, condition, unifications, opts)
    end
  end
  utils['fennel-module'].metadata:setall(case_guard, "fnl/arglist", {"vals", "condition", "guards", "unifications", "case-pattern", "opts"})
  local function symbols_in_pattern(pattern)
    if _G["list?"](pattern) then
      if (_G["sym?"](pattern[1], "where") or _G["sym?"](pattern[1], "=")) then
        return symbols_in_pattern(pattern[2])
      elseif _G["sym?"](pattern[2], "?") then
        return symbols_in_pattern(pattern[1])
      else
        local result = {}
        for _, child_pattern in ipairs(pattern) do
          local tbl_14_ = result
          for name, symbol in pairs(symbols_in_pattern(child_pattern)) do
            local k_15_, v_16_ = name, symbol
            if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
              tbl_14_[k_15_] = v_16_
            end
          end
        end
        return result
      end
    elseif _G["sym?"](pattern) then
      if (not _G["sym?"](pattern, "or") and not _G["sym?"](pattern, "nil")) then
        return {[tostring(pattern)] = pattern}
      else
        return {}
      end
    elseif (type(pattern) == "table") then
      local result = {}
      for key_pattern, value_pattern in pairs(pattern) do
        do
          local tbl_14_ = result
          for name, symbol in pairs(symbols_in_pattern(key_pattern)) do
            local k_15_, v_16_ = name, symbol
            if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
              tbl_14_[k_15_] = v_16_
            end
          end
        end
        local tbl_14_ = result
        for name, symbol in pairs(symbols_in_pattern(value_pattern)) do
          local k_15_, v_16_ = name, symbol
          if ((k_15_ ~= nil) and (v_16_ ~= nil)) then
            tbl_14_[k_15_] = v_16_
          end
        end
      end
      return result
    else
      return {}
    end
  end
  utils['fennel-module'].metadata:setall(symbols_in_pattern, "fnl/arglist", {"pattern"}, "fnl/docstring", "gives the set of symbols inside a pattern")
  local function symbols_in_every_pattern(pattern_list, infer_unification_3f)
    local _3fsymbols = nil
    do
      local _3fsymbols0 = nil
      for _, pattern in ipairs(pattern_list) do
        local in_pattern = symbols_in_pattern(pattern)
        if _3fsymbols0 then
          for name in pairs(_3fsymbols0) do
            if not in_pattern[name] then
              _3fsymbols0[name] = nil
            end
          end
          _3fsymbols0 = _3fsymbols0
        else
          _3fsymbols0 = in_pattern
        end
      end
      _3fsymbols = _3fsymbols0
    end
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for _, symbol in pairs((_3fsymbols or {})) do
      local val_19_ = nil
      if not (infer_unification_3f and _G["in-scope?"](symbol)) then
        val_19_ = symbol
      else
      val_19_ = nil
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    return tbl_17_
  end
  utils['fennel-module'].metadata:setall(symbols_in_every_pattern, "fnl/arglist", {"pattern-list", "infer-unification?"}, "fnl/docstring", "gives a list of symbols that are present in every pattern in the list")
  local function case_or(vals, pattern, guards, unifications, case_pattern, opts)
    local pattern0 = {unpack(pattern, 2)}
    local bindings = symbols_in_every_pattern(pattern0, opts["infer-unification?"])
    if (nil == bindings[1]) then
      local condition = nil
      do
        local tbl_17_ = setmetatable({filename="src/fennel/match.fnl", line=125, bytestart=5354, sym('or', nil, {quoted=true, filename="src/fennel/match.fnl", line=125})}, getmetatable(list()))
        local i_18_ = #tbl_17_
        for _, subpattern in ipairs(pattern0) do
          local val_19_ = case_pattern(vals, subpattern, unifications, opts)
          if (nil ~= val_19_) then
            i_18_ = (i_18_ + 1)
            tbl_17_[i_18_] = val_19_
          end
        end
        condition = tbl_17_
      end
      local _21_
      if guards[1] then
        _21_ = setmetatable({filename="src/fennel/match.fnl", line=128, bytestart=5495, sym('and', nil, {quoted=true, filename="src/fennel/match.fnl", line=128}), condition, unpack(guards)}, getmetatable(list()))
      else
        _21_ = condition
      end
      return _21_, {}
    else
      local matched_3f = gensym("matched?")
      local bindings_mangled = nil
      do
        local tbl_17_ = {}
        local i_18_ = #tbl_17_
        for _, binding in ipairs(bindings) do
          local val_19_ = gensym(tostring(binding))
          if (nil ~= val_19_) then
            i_18_ = (i_18_ + 1)
            tbl_17_[i_18_] = val_19_
          end
        end
        bindings_mangled = tbl_17_
      end
      local pre_bindings = setmetatable({filename="src/fennel/match.fnl", line=135, bytestart=5870, sym('if', nil, {quoted=true, filename="src/fennel/match.fnl", line=135})}, getmetatable(list()))
      for _, subpattern in ipairs(pattern0) do
        local subcondition, subbindings = case_guard(vals, subpattern, guards, {}, case_pattern, opts)
        table.insert(pre_bindings, subcondition)
        table.insert(pre_bindings, setmetatable({filename="src/fennel/match.fnl", line=139, bytestart=6116, sym('let', nil, {quoted=true, filename="src/fennel/match.fnl", line=139}), subbindings, setmetatable({filename="src/fennel/match.fnl", line=140, bytestart=6176, sym('values', nil, {quoted=true, filename="src/fennel/match.fnl", line=140}), true, unpack(bindings)}, getmetatable(list()))}, getmetatable(list())))
      end
      return matched_3f, {setmetatable({filename="src/fennel/match.fnl", line=142, bytestart=6256, unpack(bindings)}, getmetatable(list())), setmetatable({filename="src/fennel/match.fnl", line=142, bytestart=6278, sym('values', nil, {quoted=true, filename="src/fennel/match.fnl", line=142}), unpack(bindings_mangled)}, getmetatable(list()))}, {setmetatable({filename="src/fennel/match.fnl", line=143, bytestart=6333, matched_3f, unpack(bindings_mangled)}, getmetatable(list())), pre_bindings}
    end
  end
  utils['fennel-module'].metadata:setall(case_or, "fnl/arglist", {"vals", "pattern", "guards", "unifications", "case-pattern", "opts"})
  local function case_pattern(vals, pattern, unifications, opts, _3ftop)
    local _25_ = vals
    local val = _25_[1]
    if (_G["sym?"](pattern) and (_G["sym?"](pattern, "nil") or (opts["infer-unification?"] and _G["in-scope?"](pattern) and not _G["sym?"](pattern, "_")) or (opts["infer-unification?"] and _G["multi-sym?"](pattern) and _G["in-scope?"](_G["multi-sym?"](pattern)[1])))) then
      return setmetatable({filename="src/fennel/match.fnl", line=177, bytestart=8254, sym('=', nil, {quoted=true, filename="src/fennel/match.fnl", line=177}), val, pattern}, getmetatable(list())), {}
    elseif (_G["sym?"](pattern) and unifications[tostring(pattern)]) then
      return setmetatable({filename="src/fennel/match.fnl", line=180, bytestart=8402, sym('=', nil, {quoted=true, filename="src/fennel/match.fnl", line=180}), unifications[tostring(pattern)], val}, getmetatable(list())), {}
    elseif _G["sym?"](pattern) then
      local wildcard_3f = tostring(pattern):find("^_")
      if not wildcard_3f then
        unifications[tostring(pattern)] = val
      end
      local _27_
      if (wildcard_3f or string.find(tostring(pattern), "^?")) then
        _27_ = true
      else
        _27_ = setmetatable({filename="src/fennel/match.fnl", line=186, bytestart=8741, sym('not=', nil, {quoted=true, filename="src/fennel/match.fnl", line=186}), sym("nil"), val}, getmetatable(list()))
      end
      return _27_, {pattern, val}
    elseif (_G["list?"](pattern) and _G["sym?"](pattern[1], "=") and _G["sym?"](pattern[2])) then
      local bind = pattern[2]
      _G["assert-compile"]((2 == #pattern), "(=) should take only one argument", pattern)
      _G["assert-compile"](not opts["infer-unification?"], "(=) cannot be used inside of match", pattern)
      _G["assert-compile"](opts["in-where?"], "(=) must be used in (where) patterns", pattern)
      _G["assert-compile"]((_G["sym?"](bind) and not _G["sym?"](bind, "nil") and "= has to bind to a symbol" and bind))
      return setmetatable({filename="src/fennel/match.fnl", line=196, bytestart=9355, sym('=', nil, {quoted=true, filename="src/fennel/match.fnl", line=196}), val, bind}, getmetatable(list())), {}
    elseif (_G["list?"](pattern) and _G["sym?"](pattern[1], "where") and _G["list?"](pattern[2]) and _G["sym?"](pattern[2][1], "or")) then
      _G["assert-compile"](_3ftop, "can't nest (where) pattern", pattern)
      return case_or(vals, pattern[2], {unpack(pattern, 3)}, unifications, case_pattern, with(opts, "in-where?"))
    elseif (_G["list?"](pattern) and _G["sym?"](pattern[1], "where")) then
      _G["assert-compile"](_3ftop, "can't nest (where) pattern", pattern)
      return case_guard(vals, pattern[2], {unpack(pattern, 3)}, unifications, case_pattern, with(opts, "in-where?"))
    elseif (_G["list?"](pattern) and _G["sym?"](pattern[1], "or")) then
      _G["assert-compile"](_3ftop, "can't nest (or) pattern", pattern)
      _G["assert-compile"](false, "(or) must be used in (where) patterns", pattern)
      return case_or(vals, pattern, {}, unifications, case_pattern, opts)
    elseif (_G["list?"](pattern) and _G["sym?"](pattern[2], "?")) then
      _G["assert-compile"](opts["legacy-guard-allowed?"], "legacy guard clause not supported in case", pattern)
      return case_guard(vals, pattern[1], {unpack(pattern, 3)}, unifications, case_pattern, opts)
    elseif _G["list?"](pattern) then
      _G["assert-compile"](opts["multival?"], "can't nest multi-value destructuring", pattern)
      return case_values(vals, pattern, unifications, case_pattern, opts)
    elseif (type(pattern) == "table") then
      return case_table(val, pattern, unifications, case_pattern, opts, _3ftop)
    else
      return setmetatable({filename="src/fennel/match.fnl", line=228, bytestart=11092, sym('=', nil, {quoted=true, filename="src/fennel/match.fnl", line=228}), val, pattern}, getmetatable(list())), {}
    end
  end
  utils['fennel-module'].metadata:setall(case_pattern, "fnl/arglist", {"vals", "pattern", "unifications", "opts", "?top"}, "fnl/docstring", "Take the AST of values and a single pattern and returns a condition\nto determine if it matches as well as a list of bindings to\nintroduce for the duration of the body if it does match.")
  local function add_pre_bindings(out, pre_bindings)
    if pre_bindings then
      local tail = setmetatable({filename="src/fennel/match.fnl", line=237, bytestart=11490, sym('if', nil, {quoted=true, filename="src/fennel/match.fnl", line=237})}, getmetatable(list()))
      table.insert(out, true)
      table.insert(out, setmetatable({filename="src/fennel/match.fnl", line=239, bytestart=11555, sym('let', nil, {quoted=true, filename="src/fennel/match.fnl", line=239}), pre_bindings, tail}, getmetatable(list())))
      return tail
    else
      return out
    end
  end
  utils['fennel-module'].metadata:setall(add_pre_bindings, "fnl/arglist", {"out", "pre-bindings"}, "fnl/docstring", "Decide when to switch from the current `if` AST to a new one")
  local function case_condition(vals, clauses, match_3f, top_table_3f)
    local root = setmetatable({filename="src/fennel/match.fnl", line=248, bytestart=11896, sym('if', nil, {quoted=true, filename="src/fennel/match.fnl", line=248})}, getmetatable(list()))
    do
      local out = root
      for i = 1, #clauses, 2 do
        local pattern = clauses[i]
        local body = clauses[(i + 1)]
        local condition, bindings, pre_bindings = nil, nil, nil
        local function _31_()
          if top_table_3f then
            return "table"
          else
            return true
          end
        end
        condition, bindings, pre_bindings = case_pattern(vals, pattern, {}, {["infer-unification?"] = match_3f, ["legacy-guard-allowed?"] = match_3f, ["multival?"] = true}, _31_())
        local out0 = add_pre_bindings(out, pre_bindings)
        table.insert(out0, condition)
        table.insert(out0, setmetatable({filename="src/fennel/match.fnl", line=261, bytestart=12633, sym('let', nil, {quoted=true, filename="src/fennel/match.fnl", line=261}), bindings, body}, getmetatable(list())))
        out = out0
      end
    end
    return root
  end
  utils['fennel-module'].metadata:setall(case_condition, "fnl/arglist", {"vals", "clauses", "match?", "top-table?"}, "fnl/docstring", "Construct the actual `if` AST for the given match values and clauses.")
  local function count_case_multival(pattern)
    if (_G["list?"](pattern) and _G["sym?"](pattern[2], "?")) then
      return count_case_multival(pattern[1])
    elseif (_G["list?"](pattern) and _G["sym?"](pattern[1], "where")) then
      return count_case_multival(pattern[2])
    elseif (_G["list?"](pattern) and _G["sym?"](pattern[1], "or")) then
      local longest = 0
      for _, child_pattern in ipairs(pattern) do
        longest = math.max(longest, count_case_multival(child_pattern))
      end
      return longest
    elseif _G["list?"](pattern) then
      return #pattern
    else
      return 1
    end
  end
  utils['fennel-module'].metadata:setall(count_case_multival, "fnl/arglist", {"pattern"}, "fnl/docstring", "Identify the amount of multival values that a pattern requires.")
  local function case_count_syms(clauses)
    local patterns = nil
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for i = 1, #clauses, 2 do
        local val_19_ = clauses[i]
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      patterns = tbl_17_
    end
    local longest = 0
    for _, pattern in ipairs(patterns) do
      longest = math.max(longest, count_case_multival(pattern))
    end
    return longest
  end
  utils['fennel-module'].metadata:setall(case_count_syms, "fnl/arglist", {"clauses"}, "fnl/docstring", "Find the length of the largest multi-valued clause")
  local function maybe_optimize_table(val, clauses)
    local _34_
    do
      local all = _G["sequence?"](val)
      for i = 1, #clauses, 2 do
        if not all then break end
        local function _35_()
          local all2 = next(clauses[i])
          for _, d in ipairs(clauses[i]) do
            if not all2 then break end
            all2 = (all2 and (not _G["sym?"](d) or not tostring(d):find("^&")))
          end
          return all2
        end
        all = (_G["sequence?"](clauses[i]) and _35_())
      end
      _34_ = all
    end
    if _34_ then
      local function _36_()
        local tbl_17_ = {}
        local i_18_ = #tbl_17_
        for i = 1, #clauses do
          local val_19_ = nil
          if (1 == (i % 2)) then
            val_19_ = list(unpack(clauses[i]))
          else
            val_19_ = clauses[i]
          end
          if (nil ~= val_19_) then
            i_18_ = (i_18_ + 1)
            tbl_17_[i_18_] = val_19_
          end
        end
        return tbl_17_
      end
      return setmetatable({filename="src/fennel/match.fnl", line=293, bytestart=13916, sym('values', nil, {quoted=true, filename="src/fennel/match.fnl", line=293}), unpack(val)}, getmetatable(list())), _36_()
    else
      return val, clauses
    end
  end
  utils['fennel-module'].metadata:setall(maybe_optimize_table, "fnl/arglist", {"val", "clauses"})
  local function case_impl(match_3f, init_val, ...)
    assert((init_val ~= nil), "missing subject")
    assert((0 == math.fmod(select("#", ...), 2)), "expected even number of pattern/body pairs")
    assert((0 ~= select("#", ...)), "expected at least one pattern/body pair")
    local val, clauses = maybe_optimize_table(init_val, {...})
    local vals_count = case_count_syms(clauses)
    local skips_multiple_eval_protection_3f = ((vals_count == 1) and double_eval_safe_3f(val))
    if skips_multiple_eval_protection_3f then
      return case_condition(list(val), clauses, match_3f, _G["table?"](init_val))
    else
      local vals = nil
      do
        local tbl_17_ = list()
        local i_18_ = #tbl_17_
        for _ = 1, vals_count do
          local val_19_ = gensym()
          if (nil ~= val_19_) then
            i_18_ = (i_18_ + 1)
            tbl_17_[i_18_] = val_19_
          end
        end
        vals = tbl_17_
      end
      return list(sym('let', nil, {quoted=true, filename="src/fennel/match.fnl", line=315}), {vals, val}, case_condition(vals, clauses, match_3f, _G["table?"](init_val)))
    end
  end
  utils['fennel-module'].metadata:setall(case_impl, "fnl/arglist", {"match?", "init-val", "..."}, "fnl/docstring", "The shared implementation of case and match.")
  local function case_2a(val, ...)
    return case_impl(false, val, ...)
  end
  utils['fennel-module'].metadata:setall(case_2a, "fnl/arglist", {"val", "..."}, "fnl/docstring", "Perform pattern matching on val. See reference for details.\n\nSyntax:\n\n(case data-expression\n  pattern body\n  (where pattern guards*) body\n  (where (or pattern patterns*) guards*) body)")
  local function match_2a(val, ...)
    return case_impl(true, val, ...)
  end
  utils['fennel-module'].metadata:setall(match_2a, "fnl/arglist", {"val", "..."}, "fnl/docstring", "Perform pattern matching on val, automatically unifying on variables in\nlocal scope. See reference for details.\n\nSyntax:\n\n(match data-expression\n  pattern body\n  (where pattern guards*) body\n  (where (or pattern patterns*) guards*) body)")
  local function case_try_step(how, expr, _else, pattern, body, ...)
    if ((nil == pattern) and (pattern == body)) then
      return expr
    else
      return setmetatable({filename="src/fennel/match.fnl", line=346, bytestart=15867, setmetatable({filename="src/fennel/match.fnl", line=346, bytestart=15868, sym('fn', nil, {quoted=true, filename="src/fennel/match.fnl", line=346}), setmetatable({_VARARG}, {filename="src/fennel/match.fnl", line=346}), setmetatable({filename="src/fennel/match.fnl", line=347, bytestart=15888, how, _VARARG, pattern, case_try_step(how, body, _else, ...), unpack(_else)}, getmetatable(list()))}, getmetatable(list())), expr}, getmetatable(list()))
    end
  end
  utils['fennel-module'].metadata:setall(case_try_step, "fnl/arglist", {"how", "expr", "else", "pattern", "body", "..."})
  local function case_try_impl(how, expr, pattern, body, ...)
    local clauses = {pattern, body, ...}
    local last = clauses[#clauses]
    local catch = nil
    if _G["sym?"]((("table" == type(last)) and last[1]), "catch") then
      local _43_ = table.remove(clauses)
      local _ = _43_[1]
      local e = {(table.unpack or unpack)(_43_, 2)}
      catch = e
    else
      catch = {sym('__44_', nil, {filename="src/fennel/match.fnl", line=357}), _VARARG}
    end
    assert((0 == math.fmod(#clauses, 2)), "expected every pattern to have a body")
    assert((0 == math.fmod(#catch, 2)), "expected every catch pattern to have a body")
    return case_try_step(how, expr, catch, unpack(clauses))
  end
  utils['fennel-module'].metadata:setall(case_try_impl, "fnl/arglist", {"how", "expr", "pattern", "body", "..."})
  local function case_try_2a(expr, pattern, body, ...)
    return case_try_impl(sym('case', nil, {quoted=true, filename="src/fennel/match.fnl", line=375}), expr, pattern, body, ...)
  end
  utils['fennel-module'].metadata:setall(case_try_2a, "fnl/arglist", {"expr", "pattern", "body", "..."}, "fnl/docstring", "Perform chained pattern matching for a sequence of steps which might fail.\n\nThe values from the initial expression are matched against the first pattern.\nIf they match, the first body is evaluated and its values are matched against\nthe second pattern, etc.\n\nIf there is a (catch pat1 body1 pat2 body2 ...) form at the end, any mismatch\nfrom the steps will be tried against these patterns in sequence as a fallback\njust like a normal match. If there is no catch, the mismatched values will be\nreturned as the value of the entire expression.")
  local function match_try_2a(expr, pattern, body, ...)
    return case_try_impl(sym('match', nil, {quoted=true, filename="src/fennel/match.fnl", line=388}), expr, pattern, body, ...)
  end
  utils['fennel-module'].metadata:setall(match_try_2a, "fnl/arglist", {"expr", "pattern", "body", "..."}, "fnl/docstring", "Perform chained pattern matching for a sequence of steps which might fail.\n\nThe values from the initial expression are matched against the first pattern.\nIf they match, the first body is evaluated and its values are matched against\nthe second pattern, etc.\n\nIf there is a (catch pat1 body1 pat2 body2 ...) form at the end, any mismatch\nfrom the steps will be tried against these patterns in sequence as a fallback\njust like a normal match. If there is no catch, the mismatched values will be\nreturned as the value of the entire expression.")
  return {["case-try"] = case_try_2a, ["match-try"] = match_try_2a, case = case_2a, match = match_2a}
  ]===], env)
end
return mod
