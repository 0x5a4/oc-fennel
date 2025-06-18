local arg = table.pack(...)
local fennel = require("fennel")
local _1_ = require("fennel.utils")
local pack = _1_["pack"]
local unpack = _1_["unpack"]
local help = "Usage: fennel [FLAG] [FILE]\n\nRun Fennel, a Lisp programming language for the Lua runtime.\n\n  --repl                   : Command to launch an interactive REPL session\n  --compile FILES (-c)     : Command to AOT compile files, writing Lua to stdout\n  --eval SOURCE (-e)       : Command to evaluate source code and print result\n\n  --correlate              : Make Lua output line numbers try to match Fennel's\n  --load FILE (-l)         : Load the specified FILE before executing command\n  --no-compiler-sandbox    : Don't limit compiler environment to minimal sandbox\n  --compile-binary FILE\n      OUT LUA_LIB LUA_DIR  : Compile FILE to standalone binary OUT\n  --compile-binary --help  : Display further help for compiling binaries\n  --add-package-path PATH  : Add PATH to package.path for finding Lua modules\n  --add-package-cpath PATH : Add PATH to package.cpath for finding Lua modules\n  --add-fennel-path PATH   : Add PATH to fennel.path for finding Fennel modules\n  --add-macro-path PATH    : Add PATH to fennel.macro-path for macro modules\n  --globals G1[,G2...]     : Allow these globals in addition to standard ones\n  --globals-only G1[,G2]   : Same as above, but exclude standard ones\n  --assert-as-repl         : Replace assert calls with assert-repl\n  --require-as-include     : Inline required modules in the output\n  --skip-include M1[,M2]   : Omit certain modules from output when included\n  --use-bit-lib            : Use LuaJITs bit library instead of operators\n  --metadata               : Enable function metadata, even in compiled output\n  --no-metadata            : Disable function metadata, even in REPL\n  --lua LUA_EXE            : Run in a child process with LUA_EXE\n  --plugin FILE            : Activate the compiler plugin in FILE\n  --raw-errors             : Disable friendly compile error reporting\n  --no-searcher            : Skip installing package.searchers entry\n  --no-fennelrc            : Skip loading ~/.fennelrc when launching REPL\n  --keywords K1[,K2...]    : Treat these symbols as reserved Lua keywords\n\n  --help (-h)              : Display this text\n  --version (-v)           : Show version\n\nGlobals are not checked when doing AOT (ahead-of-time) compilation unless\nthe --globals-only or --globals flag is provided. Use --globals \"*\" to disable\nstrict globals checking in other contexts.\n\nMetadata is typically considered a development feature and is not recommended\nfor production. It is used for docstrings and enabled by default in the REPL.\n\nWhen not given a command, runs the file given as the first argument.\nWhen given neither command nor file, launches a REPL.\n\nUse the NO_COLOR environment variable to disable escape codes in error messages.\n\nIf ~/.fennelrc exists, it will be loaded before launching a REPL."
local options = {keywords = {}, plugins = {}}
local function dosafely(f, ...)
  local args = {...}
  local result = nil
  local function _2_()
    return f(unpack(args))
  end
  result = pack(xpcall(_2_, fennel.traceback))
  if not result[1] then
    do end (io.stderr):write((tostring(result[2]) .. "\n"))
    os.exit(1)
  end
  return unpack(result, 2, result.n)
end
local function allow_globals(names, actual_globals)
  if (names == "*") then
    options.allowedGlobals = false
    return nil
  else
    do
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for g in names:gmatch("([^,]+),?") do
        local val_19_ = g
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      options.allowedGlobals = tbl_17_
    end
    for global_name in pairs(actual_globals) do
      table.insert(options.allowedGlobals, global_name)
    end
    return nil
  end
end
local function handle_load(i)
  local file = table.remove(arg, (i + 1))
  dosafely(fennel.dofile, file, options)
  return table.remove(arg, i)
end
local function handle_lua(i)
  table.remove(arg, i)
  local tgt_lua = table.remove(arg, i)
  local cmd = {string.format("%s %s", tgt_lua, (arg[0] or "fennel"))}
  for i0 = 1, #arg do
    table.insert(cmd, string.format("%q", arg[i0]))
  end
  if (nil == arg[-1]) then
    do end (io.stderr):write("WARNING: --lua argument only works from script, not binary.\n")
  end
  local _7_0, _8_0 = os.execute(table.concat(cmd, " "))
  if (((_7_0 == true) and (_8_0 == "exit")) or (_7_0 == 0)) then
    return os.exit(0, true)
  else
    local _ = _7_0
    return os.exit(1, true)
  end
end
for i = #arg, 1, -1 do
  local _10_0 = arg[i]
  if (_10_0 == "--lua") then
    handle_lua(i)
  end
end
local function load_plugin(filename)
  local opts = {["compiler-env"] = _G, env = "_COMPILER", useMetadata = true}
  if (".lua" == filename:sub(-4)) then
    return fennel["load-code"](assert(io.open(filename, "rb")):read("*a"), require("fennel.specials")["make-compiler-env"](nil, fennel.scope(), nil, opts), filename)()
  else
    return fennel.dofile(filename, opts)
  end
end
do
  local commands = {["-"] = true, ["--compile"] = true, ["--compile-binary"] = true, ["--eval"] = true, ["--help"] = true, ["--repl"] = true, ["--version"] = true, ["-c"] = true, ["-e"] = true, ["-h"] = true, ["-v"] = true}
  local i = 1
  while (arg[i] and not options["ignore-options"]) do
    local _13_0 = arg[i]
    if (_13_0 == "--no-searcher") then
      options["no-searcher"] = true
      table.remove(arg, i)
    elseif (_13_0 == "--indent") then
      options.indent = table.remove(arg, (i + 1))
      if (options.indent == "false") then
        options.indent = false
      end
      table.remove(arg, i)
    elseif (_13_0 == "--add-package-path") then
      local entry = table.remove(arg, (i + 1))
      package.path = (entry .. ";" .. package.path)
      table.remove(arg, i)
    elseif (_13_0 == "--add-package-cpath") then
      local entry = table.remove(arg, (i + 1))
      package.cpath = (entry .. ";" .. package.cpath)
      table.remove(arg, i)
    elseif (_13_0 == "--add-fennel-path") then
      local entry = table.remove(arg, (i + 1))
      fennel.path = (entry .. ";" .. fennel.path)
      table.remove(arg, i)
    elseif (_13_0 == "--add-macro-path") then
      local entry = table.remove(arg, (i + 1))
      fennel["macro-path"] = (entry .. ";" .. fennel["macro-path"])
      table.remove(arg, i)
    elseif (_13_0 == "--load") then
      handle_load(i)
    elseif (_13_0 == "-l") then
      handle_load(i)
    elseif (_13_0 == "--no-fennelrc") then
      options.fennelrc = false
      table.remove(arg, i)
    elseif (_13_0 == "--correlate") then
      options.correlate = true
      table.remove(arg, i)
    elseif (_13_0 == "--globals") then
      allow_globals(table.remove(arg, (i + 1)), _G)
      table.remove(arg, i)
    elseif (_13_0 == "--globals-only") then
      allow_globals(table.remove(arg, (i + 1)), {})
      table.remove(arg, i)
    elseif (_13_0 == "--require-as-include") then
      options.requireAsInclude = true
      table.remove(arg, i)
    elseif (_13_0 == "--assert-as-repl") then
      options.assertAsRepl = true
      table.remove(arg, i)
    elseif (_13_0 == "--skip-include") then
      local skip_names = table.remove(arg, (i + 1))
      local skip = nil
      do
        local tbl_17_ = {}
        local i_18_ = #tbl_17_
        for m in skip_names:gmatch("([^,]+)") do
          local val_19_ = m
          if (nil ~= val_19_) then
            i_18_ = (i_18_ + 1)
            tbl_17_[i_18_] = val_19_
          end
        end
        skip = tbl_17_
      end
      options.skipInclude = skip
      table.remove(arg, i)
    elseif (_13_0 == "--use-bit-lib") then
      options.useBitLib = true
      table.remove(arg, i)
    elseif (_13_0 == "--metadata") then
      options.useMetadata = true
      table.remove(arg, i)
    elseif (_13_0 == "--no-metadata") then
      options.useMetadata = false
      table.remove(arg, i)
    elseif (_13_0 == "--no-compiler-sandbox") then
      options["compiler-env"] = _G
      table.remove(arg, i)
    elseif (_13_0 == "--raw-errors") then
      options.unfriendly = true
      table.remove(arg, i)
    elseif (_13_0 == "--plugin") then
      local plugin = load_plugin(table.remove(arg, (i + 1)))
      table.insert(options.plugins, 1, plugin)
      table.remove(arg, i)
    elseif (_13_0 == "--keywords") then
      for keyword in string.gmatch(table.remove(arg, (i + 1)), "[^,]+") do
        options.keywords[keyword] = true
      end
      table.remove(arg, i)
    else
      local _ = _13_0
      if not commands[arg[i]] then
        options["ignore-options"] = true
        i = (i + 1)
      end
      i = (i + 1)
    end
  end
end
local searcher_opts = {}
if not options["no-searcher"] then
  for k, v in pairs(options) do
    searcher_opts[k] = v
  end
  table.insert((package.loaders or package.searchers), fennel["make-searcher"](searcher_opts))
end
local function load_initfile()
  local home = (os.getenv("HOME") or "/")
  local xdg_config_home = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"))
  local xdg_initfile = (xdg_config_home .. "/fennel/fennelrc")
  local home_initfile = (home .. "/.fennelrc")
  local init = io.open(xdg_initfile, "rb")
  local init_filename = nil
  if init then
    init_filename = xdg_initfile
  else
    init_filename = home_initfile
  end
  local init0 = (init or io.open(home_initfile, "rb"))
  if init0 then
    init0:close()
    return dosafely(fennel.dofile, init_filename, options, options, fennel)
  end
end
local function repl()
  local readline_3f = (("dumb" ~= os.getenv("TERM")) and pcall(require, "readline"))
  local welcome = {("Welcome to " .. fennel["runtime-version"]() .. "!"), "Use ,help to see available commands."}
  searcher_opts.useMetadata = (false ~= options.useMetadata)
  if (false ~= options.fennelrc) then
    options.fennelrc = load_initfile
  end
  options.message = table.concat(welcome, "\n")
  return fennel.repl(options)
end
local function eval(form)
  local _23_
  if (form == "-") then
    _23_ = (io.stdin):read("*a")
  else
    _23_ = form
  end
  return print(dosafely(fennel.eval, _23_, options))
end
local function compile(files)
  for _, filename in ipairs(files) do
    options.filename = filename
    local f = nil
    if (filename == "-") then
      f = io.stdin
    else
      f = assert(io.open(filename, "rb"))
    end
    do
      local _26_0, _27_0 = nil, nil
      local function _28_()
        return fennel["compile-string"](f:read("*a"), options)
      end
      _26_0, _27_0 = xpcall(_28_, fennel.traceback)
      if ((_26_0 == true) and (nil ~= _27_0)) then
        local val = _27_0
        print(val)
      elseif (true and (nil ~= _27_0)) then
        local _0 = _26_0
        local msg = _27_0
        do end (io.stderr):write((msg .. "\n"))
        os.exit(1)
      end
    end
    f:close()
  end
  return nil
end
local _30_0 = arg
local function _31_(...)
  return (0 == #arg)
end
if ((_G.type(_30_0) == "table") and _31_(...)) then
  return repl()
elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "--repl")) then
  return repl()
elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "--compile")) then
  local files = {select(2, (table.unpack or _G.unpack)(_30_0))}
  return compile(files)
elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "-c")) then
  local files = {select(2, (table.unpack or _G.unpack)(_30_0))}
  return compile(files)
elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "--compile-binary") and (nil ~= _30_0[2]) and (nil ~= _30_0[3]) and (nil ~= _30_0[4]) and (nil ~= _30_0[5])) then
  local filename = _30_0[2]
  local out = _30_0[3]
  local static_lua = _30_0[4]
  local lua_include_dir = _30_0[5]
  local args = {select(6, (table.unpack or _G.unpack)(_30_0))}
  local bin = require("fennel.binary")
  options.filename = filename
  options.requireAsInclude = true
  return bin.compile(filename, out, static_lua, lua_include_dir, options, args)
elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "--compile-binary")) then
  local cmd = (arg[0] or "fennel")
  return print((require("fennel.binary").help):format(cmd, cmd, cmd))
elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "--eval") and (nil ~= _30_0[2])) then
  local form = _30_0[2]
  return eval(form)
elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "-e") and (nil ~= _30_0[2])) then
  local form = _30_0[2]
  return eval(form)
else
  local function _32_(...)
    local a = _30_0[1]
    return ((a == "-v") or (a == "--version"))
  end
  if (((_G.type(_30_0) == "table") and (nil ~= _30_0[1])) and _32_(...)) then
    local a = _30_0[1]
    return print(fennel["runtime-version"]())
  elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "--help")) then
    return print(help)
  elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "-h")) then
    return print(help)
  elseif ((_G.type(_30_0) == "table") and (_30_0[1] == "-")) then
    return dosafely(fennel.eval, (io.stdin):read("*a"))
  elseif ((_G.type(_30_0) == "table") and (nil ~= _30_0[1])) then
    local filename = _30_0[1]
    local args = {select(2, (table.unpack or _G.unpack)(_30_0))}
    arg[-2] = arg[-1]
    arg[-1] = arg[0]
    arg[0] = table.remove(arg, 1)
    return dosafely(fennel.dofile, filename, options, unpack(args))
  end
end
