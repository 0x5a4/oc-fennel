local _1_ = require("fennel.utils")
local utils = _1_
local copy = _1_["copy"]
local parser = require("fennel.parser")
local compiler = require("fennel.compiler")
local specials = require("fennel.specials")
local view = require("fennel.view")
local depth = 0
local function prompt_for(top_3f)
  if top_3f then
    return (string.rep(">", (depth + 1)) .. " ")
  else
    return (string.rep(".", (depth + 1)) .. " ")
  end
end
local function default_read_chunk(parser_state)
  io.write(prompt_for((0 == parser_state["stack-size"])))
  io.flush()
  local _3_0 = io.read()
  if (nil ~= _3_0) then
    local input = _3_0
    return (input .. "\n")
  end
end
local function default_on_values(xs)
  io.write(table.concat(xs, "\9"))
  return io.write("\n")
end
local function default_on_error(errtype, err)
  local function _6_()
    local _5_0 = errtype
    if (_5_0 == "Runtime") then
      return (compiler.traceback(tostring(err), 4) .. "\n")
    else
      local _ = _5_0
      return ("%s error: %s\n"):format(errtype, tostring(err))
    end
  end
  return io.write(_6_())
end
local function splice_save_locals(env, lua_source, scope)
  local saves = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for name in pairs(env.___replLocals___) do
      local val_19_ = ("local %s = ___replLocals___[%q]"):format((scope.manglings[name] or name), name)
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    saves = tbl_17_
  end
  local binds = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for raw, name in pairs(scope.manglings) do
      local val_19_ = nil
      if not scope.gensyms[name] then
        val_19_ = ("___replLocals___[%q] = %s"):format(raw, name)
      else
      val_19_ = nil
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    binds = tbl_17_
  end
  local gap = nil
  if lua_source:find("\n") then
    gap = "\n"
  else
    gap = " "
  end
  local function _12_()
    if next(saves) then
      return (table.concat(saves, " ") .. gap)
    else
      return ""
    end
  end
  local function _15_()
    local _13_0, _14_0 = lua_source:match("^(.*)[\n ](return .*)$")
    if ((nil ~= _13_0) and (nil ~= _14_0)) then
      local body = _13_0
      local _return = _14_0
      return (body .. gap .. table.concat(binds, " ") .. gap .. _return)
    else
      local _ = _13_0
      return lua_source
    end
  end
  return (_12_() .. _15_())
end
local commands = {}
local function completer(env, scope, text, _3ffulltext, _from, _to)
  local max_items = 2000
  local seen = {}
  local matches = {}
  local input_fragment = text:gsub(".*[%s)(]+", "")
  local stop_looking_3f = false
  local function add_partials(input, tbl, prefix)
    local scope_first_3f = ((tbl == env) or (tbl == env.___replLocals___))
    local tbl_17_ = matches
    local i_18_ = #tbl_17_
    local function _17_()
      if scope_first_3f then
        return scope.manglings
      else
        return tbl
      end
    end
    for k, is_mangled in utils.allpairs(_17_()) do
      if (max_items <= #matches) then break end
      local val_19_ = nil
      do
        local lookup_k = nil
        if scope_first_3f then
          lookup_k = is_mangled
        else
          lookup_k = k
        end
        if ((type(k) == "string") and (input == k:sub(0, #input)) and not seen[k] and ((":" ~= prefix:sub(-1)) or ("function" == type(tbl[lookup_k])))) then
          seen[k] = true
          val_19_ = (prefix .. k)
        else
        val_19_ = nil
        end
      end
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    return tbl_17_
  end
  local function descend(input, tbl, prefix, add_matches, method_3f)
    local splitter = nil
    if method_3f then
      splitter = "^([^:]+):(.*)"
    else
      splitter = "^([^.]+)%.(.*)"
    end
    local head, tail = input:match(splitter)
    local raw_head = (scope.manglings[head] or head)
    if (type(tbl[raw_head]) == "table") then
      stop_looking_3f = true
      if method_3f then
        return add_partials(tail, tbl[raw_head], (prefix .. head .. ":"))
      else
        return add_matches(tail, tbl[raw_head], (prefix .. head))
      end
    end
  end
  local function add_matches(input, tbl, prefix)
    local prefix0 = nil
    if prefix then
      prefix0 = (prefix .. ".")
    else
      prefix0 = ""
    end
    if (not input:find("%.") and input:find(":")) then
      return descend(input, tbl, prefix0, add_matches, true)
    elseif not input:find("%.") then
      return add_partials(input, tbl, prefix0)
    else
      return descend(input, tbl, prefix0, add_matches, false)
    end
  end
  do
    local _26_0 = tostring((_3ffulltext or text)):match("^%s*,([^%s()[%]]*)$")
    if (nil ~= _26_0) then
      local cmd_fragment = _26_0
      add_partials(cmd_fragment, commands, ",")
    else
      local _ = _26_0
      for _0, source in ipairs({scope.specials, scope.macros, (env.___replLocals___ or {}), env, env._G}) do
        if stop_looking_3f then break end
        add_matches(input_fragment, source)
      end
    end
  end
  return matches
end
local function command_3f(input)
  return input:match("^%s*,")
end
local function command_docs()
  local _28_
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for name, f in utils.stablepairs(commands) do
      local val_19_ = ("  ,%s - %s"):format(name, ((compiler.metadata):get(f, "fnl/docstring") or "undocumented"))
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    _28_ = tbl_17_
  end
  return table.concat(_28_, "\n")
end
commands.help = function(_, _0, on_values)
  return on_values({("Welcome to Fennel.\nThis is the REPL where you can enter code to be evaluated.\nYou can also run these repl commands:\n\n" .. command_docs() .. "\n  ,return FORM - Evaluate FORM and return its value to the REPL's caller.\n  ,exit - Leave the repl.\n\nUse ,doc something to see descriptions for individual macros and special forms.\nValues from previous inputs are kept in *1, *2, and *3.\n\nFor more information about the language, see https://fennel-lang.org/reference")})
end
do end (compiler.metadata):set(commands.help, "fnl/docstring", "Show this message.")
local function reload(module_name, env, on_values, on_error)
  local _30_0, _31_0 = pcall(specials["load-code"]("return require(...)", env), module_name)
  if ((_30_0 == true) and (nil ~= _31_0)) then
    local old = _31_0
    local _ = nil
    package.loaded[module_name] = nil
    _ = nil
    local new = nil
    do
      local _32_0, _33_0 = pcall(require, module_name)
      if ((_32_0 == true) and (nil ~= _33_0)) then
        local new0 = _33_0
        new = new0
      elseif (true and (nil ~= _33_0)) then
        local _0 = _32_0
        local msg = _33_0
        on_error("Repl", msg)
        new = old
      else
      new = nil
      end
    end
    specials["macro-loaded"][module_name] = nil
    if ((type(old) == "table") and (type(new) == "table")) then
      for k, v in pairs(new) do
        old[k] = v
      end
      for k in pairs(old) do
        if (nil == new[k]) then
          old[k] = nil
        end
      end
      package.loaded[module_name] = old
    end
    return on_values({"ok"})
  elseif ((_30_0 == false) and (nil ~= _31_0)) then
    local msg = _31_0
    if msg:match("loop or previous error loading module") then
      package.loaded[module_name] = nil
      return reload(module_name, env, on_values, on_error)
    elseif specials["macro-loaded"][module_name] then
      specials["macro-loaded"][module_name] = nil
      return nil
    else
      local function _38_()
        local _37_0 = msg:gsub("\n.*", "")
        return _37_0
      end
      return on_error("Runtime", _38_())
    end
  end
end
local function run_command(read, on_error, f)
  local _41_0, _42_0, _43_0 = pcall(read)
  if ((_41_0 == true) and (_42_0 == true) and (nil ~= _43_0)) then
    local val = _43_0
    local _44_0, _45_0 = pcall(f, val)
    if ((_44_0 == false) and (nil ~= _45_0)) then
      local msg = _45_0
      return on_error("Runtime", msg)
    end
  elseif (_41_0 == false) then
    return on_error("Parse", "Couldn't parse input.")
  end
end
commands.reload = function(env, read, on_values, on_error)
  local function _48_(_241)
    return reload(tostring(_241), env, on_values, on_error)
  end
  return run_command(read, on_error, _48_)
end
do end (compiler.metadata):set(commands.reload, "fnl/docstring", "Reload the specified module.")
commands.reset = function(env, _, on_values)
  env.___replLocals___ = {}
  return on_values({"ok"})
end
do end (compiler.metadata):set(commands.reset, "fnl/docstring", "Erase all repl-local scope.")
commands.complete = function(env, read, on_values, on_error, scope, chars)
  local function _49_()
    return on_values(completer(env, scope, table.concat(chars):gsub("^%s*,complete%s+", ""):sub(1, -2)))
  end
  return run_command(read, on_error, _49_)
end
do end (compiler.metadata):set(commands.complete, "fnl/docstring", "Print all possible completions for a given input symbol.")
local function apropos_2a(pattern, tbl, prefix, seen, names)
  for name, subtbl in pairs(tbl) do
    if (("string" == type(name)) and (package ~= subtbl)) then
      local _50_0 = type(subtbl)
      if (_50_0 == "function") then
        if ((prefix .. name)):match(pattern) then
          table.insert(names, (prefix .. name))
        end
      elseif (_50_0 == "table") then
        if not seen[subtbl] then
          local _52_
          do
            seen[subtbl] = true
            _52_ = seen
          end
          apropos_2a(pattern, subtbl, (prefix .. name:gsub("%.", "/") .. "."), _52_, names)
        end
      end
    end
  end
  return names
end
local function apropos(pattern)
  return apropos_2a(pattern:gsub("^_G%.", ""), package.loaded, "", {}, {})
end
commands.apropos = function(_env, read, on_values, on_error, _scope)
  local function _56_(_241)
    return on_values(apropos(tostring(_241)))
  end
  return run_command(read, on_error, _56_)
end
do end (compiler.metadata):set(commands.apropos, "fnl/docstring", "Print all functions matching a pattern in all loaded modules.")
local function apropos_follow_path(path)
  local paths = nil
  do
    local tbl_17_ = {}
    local i_18_ = #tbl_17_
    for p in path:gmatch("[^%.]+") do
      local val_19_ = p
      if (nil ~= val_19_) then
        i_18_ = (i_18_ + 1)
        tbl_17_[i_18_] = val_19_
      end
    end
    paths = tbl_17_
  end
  local tgt = package.loaded
  for _, path0 in ipairs(paths) do
    if (nil == tgt) then break end
    local _59_
    do
      local _58_0 = path0:gsub("%/", ".")
      _59_ = _58_0
    end
    tgt = tgt[_59_]
  end
  return tgt
end
local function apropos_doc(pattern)
  local tbl_17_ = {}
  local i_18_ = #tbl_17_
  for _, path in ipairs(apropos(".*")) do
    local val_19_ = nil
    do
      local tgt = apropos_follow_path(path)
      if ("function" == type(tgt)) then
        local _60_0 = (compiler.metadata):get(tgt, "fnl/docstring")
        if (nil ~= _60_0) then
          local docstr = _60_0
          val_19_ = (docstr:match(pattern) and path)
        else
        val_19_ = nil
        end
      else
      val_19_ = nil
      end
    end
    if (nil ~= val_19_) then
      i_18_ = (i_18_ + 1)
      tbl_17_[i_18_] = val_19_
    end
  end
  return tbl_17_
end
commands["apropos-doc"] = function(_env, read, on_values, on_error, _scope)
  local function _64_(_241)
    return on_values(apropos_doc(tostring(_241)))
  end
  return run_command(read, on_error, _64_)
end
do end (compiler.metadata):set(commands["apropos-doc"], "fnl/docstring", "Print all functions that match the pattern in their docs")
local function apropos_show_docs(on_values, pattern)
  for _, path in ipairs(apropos(pattern)) do
    local tgt = apropos_follow_path(path)
    if (("function" == type(tgt)) and (compiler.metadata):get(tgt, "fnl/docstring")) then
      on_values({specials.doc(tgt, path)})
      on_values({})
    end
  end
  return nil
end
commands["apropos-show-docs"] = function(_env, read, on_values, on_error)
  local function _66_(_241)
    return apropos_show_docs(on_values, tostring(_241))
  end
  return run_command(read, on_error, _66_)
end
do end (compiler.metadata):set(commands["apropos-show-docs"], "fnl/docstring", "Print all documentations matching a pattern in function name")
local function resolve(identifier, _67_0, scope)
  local _68_ = _67_0
  local env = _68_
  local ___replLocals___ = _68_["___replLocals___"]
  local e = nil
  local function _69_(_241, _242)
    return (___replLocals___[scope.unmanglings[_242]] or env[_242])
  end
  e = setmetatable({}, {__index = _69_})
  local function _70_(...)
    local _71_0, _72_0 = ...
    if ((_71_0 == true) and (nil ~= _72_0)) then
      local code = _72_0
      local function _73_(...)
        local _74_0, _75_0 = ...
        if ((_74_0 == true) and (nil ~= _75_0)) then
          local val = _75_0
          return val
        else
          local _ = _74_0
          return nil
        end
      end
      return _73_(pcall(specials["load-code"](code, e)))
    else
      local _ = _71_0
      return nil
    end
  end
  return _70_(pcall(compiler["compile-string"], tostring(identifier), {scope = scope}))
end
commands.find = function(env, read, on_values, on_error, scope)
  local function _78_(_241)
    local _79_0 = nil
    do
      local _80_0 = utils["sym?"](_241)
      if (nil ~= _80_0) then
        local _81_0 = resolve(_80_0, env, scope)
        if (nil ~= _81_0) then
          _79_0 = debug.getinfo(_81_0)
        else
          _79_0 = _81_0
        end
      else
        _79_0 = _80_0
      end
    end
    if ((_G.type(_79_0) == "table") and (nil ~= _79_0.linedefined) and (nil ~= _79_0.short_src) and (nil ~= _79_0.source) and (_79_0.what == "Lua")) then
      local line = _79_0.linedefined
      local src = _79_0.short_src
      local source = _79_0.source
      local fnlsrc = nil
      do
        local _84_0 = compiler.sourcemap
        if (nil ~= _84_0) then
          _84_0 = _84_0[source]
        end
        if (nil ~= _84_0) then
          _84_0 = _84_0[line]
        end
        if (nil ~= _84_0) then
          _84_0 = _84_0[2]
        end
        fnlsrc = _84_0
      end
      return on_values({string.format("%s:%s", src, (fnlsrc or line))})
    elseif (_79_0 == nil) then
      return on_error("Repl", "Unknown value")
    else
      local _ = _79_0
      return on_error("Repl", "No source info")
    end
  end
  return run_command(read, on_error, _78_)
end
do end (compiler.metadata):set(commands.find, "fnl/docstring", "Print the filename and line number for a given function")
commands.doc = function(env, read, on_values, on_error, scope)
  local function _89_(_241)
    local name = tostring(_241)
    local path = (utils["multi-sym?"](name) or {name})
    local ok_3f, target = nil, nil
    local function _90_()
      return (scope.specials[name] or utils["get-in"](scope.macros, path) or resolve(name, env, scope))
    end
    ok_3f, target = pcall(_90_)
    if ok_3f then
      return on_values({specials.doc(target, name)})
    else
      return on_error("Repl", ("Could not find " .. name .. " for docs."))
    end
  end
  return run_command(read, on_error, _89_)
end
do end (compiler.metadata):set(commands.doc, "fnl/docstring", "Print the docstring and arglist for a function, macro, or special form.")
commands.compile = function(_, read, on_values, on_error, _0, _1, opts)
  local function _92_(_241)
    local _93_0, _94_0 = pcall(compiler.compile, _241, opts)
    if ((_93_0 == true) and (nil ~= _94_0)) then
      local result = _94_0
      return on_values({result})
    elseif (true and (nil ~= _94_0)) then
      local _2 = _93_0
      local msg = _94_0
      return on_error("Repl", ("Error compiling expression: " .. msg))
    end
  end
  return run_command(read, on_error, _92_)
end
do end (compiler.metadata):set(commands.compile, "fnl/docstring", "compiles the expression into lua and prints the result.")
local function load_plugin_commands(plugins)
  for i = #(plugins or {}), 1, -1 do
    for name, f in pairs(plugins[i]) do
      local _96_0 = name:match("^repl%-command%-(.*)")
      if (nil ~= _96_0) then
        local cmd_name = _96_0
        commands[cmd_name] = f
      end
    end
  end
  return nil
end
local function run_command_loop(input, read, loop, env, on_values, on_error, scope, chars, opts)
  local command_name = input:match(",([^%s/]+)")
  do
    local _98_0 = commands[command_name]
    if (nil ~= _98_0) then
      local command = _98_0
      command(env, read, on_values, on_error, scope, chars, opts)
    else
      local _ = _98_0
      if ((command_name ~= "exit") and (command_name ~= "return")) then
        on_values({"Unknown command", command_name})
      end
    end
  end
  if ("exit" ~= command_name) then
    return loop((command_name == "return"))
  end
end
local function try_readline_21(opts, ok, readline)
  if ok then
    if readline.set_readline_name then
      readline.set_readline_name("fennel")
    end
    readline.set_options({histfile = "", keeplines = 1000})
    opts.readChunk = function(parser_state)
      local _103_0 = readline.readline(prompt_for((0 == parser_state["stack-size"])))
      if (nil ~= _103_0) then
        local input = _103_0
        return (input .. "\n")
      end
    end
    local completer0 = nil
    opts.registerCompleter = function(repl_completer)
      completer0 = repl_completer
      return nil
    end
    local function repl_completer(text, from, to)
      if completer0 then
        readline.set_completion_append_character("")
        return completer0(text:sub(from, to), text, from, to)
      else
        return {}
      end
    end
    readline.set_complete_function(repl_completer)
    return readline
  end
end
local function should_use_readline_3f(opts)
  return (("dumb" ~= os.getenv("TERM")) and not opts.readChunk and not opts.registerCompleter)
end
local function repl(_3foptions)
  local old_root_options = utils.root.options
  local _107_ = copy(_3foptions)
  local opts = _107_
  local _3ffennelrc = _107_["fennelrc"]
  local _ = nil
  opts.fennelrc = nil
  _ = nil
  local readline = (should_use_readline_3f(opts) and try_readline_21(opts, pcall(require, "readline")))
  local _0 = nil
  if _3ffennelrc then
    _0 = _3ffennelrc()
  else
  _0 = nil
  end
  local env = specials["wrap-env"]((opts.env or rawget(_G, "_ENV") or _G))
  local callbacks = {["view-opts"] = (opts["view-opts"] or {depth = 4}), env = env, onError = (opts.onError or default_on_error), onValues = (opts.onValues or default_on_values), pp = (opts.pp or view), readChunk = (opts.readChunk or default_read_chunk)}
  local save_locals_3f = (opts.saveLocals ~= false)
  local byte_stream, clear_stream = nil, nil
  local function _109_(_241)
    return callbacks.readChunk(_241)
  end
  byte_stream, clear_stream = parser.granulate(_109_)
  local chars = {}
  local read, reset = nil, nil
  local function _110_(parser_state)
    local b = byte_stream(parser_state)
    if b then
      table.insert(chars, string.char(b))
    end
    return b
  end
  read, reset = parser.parser(_110_)
  depth = (depth + 1)
  if opts.message then
    callbacks.onValues({opts.message})
  end
  env.___repl___ = callbacks
  opts.env, opts.scope = env, compiler["make-scope"]()
  opts.useMetadata = (opts.useMetadata ~= false)
  if (opts.allowedGlobals == nil) then
    opts.allowedGlobals = specials["current-global-names"](env)
  end
  if opts.init then
    opts.init(opts, depth)
  end
  if opts.registerCompleter then
    local function _116_()
      local _115_0 = opts.scope
      local function _117_(...)
        return completer(env, _115_0, ...)
      end
      return _117_
    end
    opts.registerCompleter(_116_())
  end
  load_plugin_commands(opts.plugins)
  if save_locals_3f then
    local function newindex(t, k, v)
      if opts.scope.manglings[k] then
        return rawset(t, k, v)
      end
    end
    env.___replLocals___ = setmetatable({}, {__newindex = newindex})
  end
  local function print_values(...)
    local vals = {...}
    local out = {}
    local pp = callbacks.pp
    env._, env.__ = vals[1], vals
    for i = 1, select("#", ...) do
      table.insert(out, pp(vals[i], callbacks["view-opts"]))
    end
    return callbacks.onValues(out)
  end
  local function save_value(...)
    env.___replLocals___["*3"] = env.___replLocals___["*2"]
    env.___replLocals___["*2"] = env.___replLocals___["*1"]
    env.___replLocals___["*1"] = ...
    return ...
  end
  opts.scope.manglings["*1"], opts.scope.unmanglings._1 = "_1", "*1"
  opts.scope.manglings["*2"], opts.scope.unmanglings._2 = "_2", "*2"
  opts.scope.manglings["*3"], opts.scope.unmanglings._3 = "_3", "*3"
  local function loop(exit_next_3f)
    for k in pairs(chars) do
      chars[k] = nil
    end
    reset()
    local ok, parser_not_eof_3f, form = pcall(read)
    local src_string = table.concat(chars)
    local readline_not_eof_3f = (not readline or (src_string ~= "(null)"))
    local not_eof_3f = (readline_not_eof_3f and parser_not_eof_3f)
    if not ok then
      callbacks.onError("Parse", not_eof_3f)
      clear_stream()
      return loop()
    elseif command_3f(src_string) then
      return run_command_loop(src_string, read, loop, env, callbacks.onValues, callbacks.onError, opts.scope, chars, opts)
    else
      if not_eof_3f then
        local function _121_(...)
          local _122_0, _123_0 = ...
          if ((_122_0 == true) and (nil ~= _123_0)) then
            local src = _123_0
            local function _124_(...)
              local _125_0, _126_0 = ...
              if ((_125_0 == true) and (nil ~= _126_0)) then
                local chunk = _126_0
                local function _127_()
                  return print_values(save_value(chunk()))
                end
                local function _128_(...)
                  return callbacks.onError("Runtime", ...)
                end
                return xpcall(_127_, _128_)
              elseif ((_125_0 == false) and (nil ~= _126_0)) then
                local msg = _126_0
                clear_stream()
                return callbacks.onError("Compile", msg)
              end
            end
            local function _131_(...)
              local src0 = nil
              if save_locals_3f then
                src0 = splice_save_locals(env, src, opts.scope)
              else
                src0 = src
              end
              return pcall(specials["load-code"], src0, env)
            end
            return _124_(_131_(...))
          elseif ((_122_0 == false) and (nil ~= _123_0)) then
            local msg = _123_0
            clear_stream()
            return callbacks.onError("Compile", msg)
          end
        end
        local function _133_()
          opts["source"] = src_string
          return opts
        end
        _121_(pcall(compiler.compile, form, _133_()))
        utils.root.options = old_root_options
        if exit_next_3f then
          return env.___replLocals___["*1"]
        else
          return loop()
        end
      end
    end
  end
  local value = loop()
  depth = (depth - 1)
  if readline then
    readline.save_history()
  end
  if opts.exit then
    opts.exit(opts, depth)
  end
  return value
end
local repl_mt = {__index = {repl = repl}}
repl_mt.__call = function(_139_0, _3fopts)
  local _140_ = _139_0
  local overrides = _140_
  local view_opts = _140_["view-opts"]
  local opts = copy(_3fopts, copy(overrides))
  local _142_
  do
    local _141_0 = _3fopts
    if (nil ~= _141_0) then
      _141_0 = _141_0["view-opts"]
    end
    _142_ = _141_0
  end
  opts["view-opts"] = copy(_142_, copy(view_opts))
  return repl(opts)
end
return setmetatable({["view-opts"] = {}}, repl_mt)
