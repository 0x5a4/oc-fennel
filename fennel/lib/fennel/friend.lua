local _1_ = require("fennel.utils")
local utils = _1_
local unpack = _1_["unpack"]
local utf8_ok_3f, utf8 = pcall(require, "utf8")
local suggestions = {["$ and $... in hashfn are mutually exclusive"] = {"modifying the hashfn so it only contains $... or $, $1, $2, $3, etc"}, ["can't introduce (.*) here"] = {"declaring the local at the top-level"}, ["can't start multisym segment with a digit"] = {"removing the digit", "adding a non-digit before the digit"}, ["cannot call literal value"] = {"checking for typos", "checking for a missing function name", "making sure to use prefix operators, not infix"}, ["could not compile value of type "] = {"debugging the macro you're calling to return a list or table"}, ["could not read number (.*)"] = {"removing the non-digit character", "beginning the identifier with a non-digit if it is not meant to be a number"}, ["expected a function.* to call"] = {"removing the empty parentheses", "using square brackets if you want an empty table"}, ["expected at least one pattern/body pair"] = {"adding a pattern and a body to execute when the pattern matches"}, ["expected binding and iterator"] = {"making sure you haven't omitted a local name or iterator"}, ["expected binding sequence"] = {"placing a table here in square brackets containing identifiers to bind"}, ["expected body expression"] = {"putting some code in the body of this form after the bindings"}, ["expected each macro to be function"] = {"ensuring that the value for each key in your macros table contains a function", "avoid defining nested macro tables"}, ["expected even number of name/value bindings"] = {"finding where the identifier or value is missing"}, ["expected even number of pattern/body pairs"] = {"checking that every pattern has a body to go with it", "adding _ before the final body"}, ["expected even number of values in table literal"] = {"removing a key", "adding a value"}, ["expected local"] = {"looking for a typo", "looking for a local which is used out of its scope"}, ["expected macros to be table"] = {"ensuring your macro definitions return a table"}, ["expected parameters"] = {"adding function parameters as a list of identifiers in brackets"}, ["expected range to include start and stop"] = {"adding missing arguments"}, ["expected rest argument before last parameter"] = {"moving & to right before the final identifier when destructuring"}, ["expected symbol for function parameter: (.*)"] = {"changing %s to an identifier instead of a literal value"}, ["expected var (.*)"] = {"declaring %s using var instead of let/local", "introducing a new local instead of changing the value of %s"}, ["expected vararg as last parameter"] = {"moving the \"...\" to the end of the parameter list"}, ["expected whitespace before opening delimiter"] = {"adding whitespace"}, ["global (.*) conflicts with local"] = {"renaming local %s"}, ["invalid character: (.)"] = {"deleting or replacing %s", "avoiding reserved characters like \", \\, ', ~, ;, @, `, and comma"}, ["local (.*) was overshadowed by a special form or macro"] = {"renaming local %s"}, ["macro not found in macro module"] = {"checking the keys of the imported macro module's returned table"}, ["macro tried to bind (.*) without gensym"] = {"changing to %s# when introducing identifiers inside macros"}, ["malformed multisym"] = {"ensuring each period or colon is not followed by another period or colon"}, ["may only be used at compile time"] = {"moving this to inside a macro if you need to manipulate symbols/lists", "using square brackets instead of parens to construct a table"}, ["method must be last component"] = {"using a period instead of a colon for field access", "removing segments after the colon", "making the method call, then looking up the field on the result"}, ["mismatched closing delimiter (.), expected (.)"] = {"replacing %s with %s", "deleting %s", "adding matching opening delimiter earlier"}, ["missing subject"] = {"adding an item to operate on"}, ["multisym method calls may only be in call position"] = {"using a period instead of a colon to reference a table's fields", "putting parens around this"}, ["tried to reference a macro without calling it"] = {"renaming the macro so as not to conflict with locals"}, ["tried to reference a special form without calling it"] = {"making sure to use prefix operators, not infix", "wrapping the special in a function if you need it to be first class"}, ["tried to use unquote outside quote"] = {"moving the form to inside a quoted form", "removing the comma"}, ["tried to use vararg with operator"] = {"accumulating over the operands"}, ["unable to bind (.*)"] = {"replacing the %s with an identifier"}, ["unexpected arguments"] = {"removing an argument", "checking for typos"}, ["unexpected closing delimiter (.)"] = {"deleting %s", "adding matching opening delimiter earlier"}, ["unexpected iterator clause"] = {"removing an argument", "checking for typos"}, ["unexpected multi symbol (.*)"] = {"removing periods or colons from %s"}, ["unexpected vararg"] = {"putting \"...\" at the end of the fn parameters if the vararg was intended"}, ["unknown identifier: (.*)"] = {"looking to see if there's a typo", "using the _G table instead, eg. _G.%s if you really want a global", "moving this code to somewhere that %s is in scope", "binding %s as a local in the scope of this code"}, ["unused local (.*)"] = {"renaming the local to _%s if it is meant to be unused", "fixing a typo so %s is used", "disabling the linter which checks for unused locals"}, ["use of global (.*) is aliased by a local"] = {"renaming local %s", "refer to the global using _G.%s instead of directly"}}
local function suggest(msg)
  local s = nil
  for pat, sug in pairs(suggestions) do
    if s then break end
    local matches = {msg:match(pat)}
    if next(matches) then
      local tbl_17_ = {}
      local i_18_ = #tbl_17_
      for _, s0 in ipairs(sug) do
        local val_19_ = s0:format(unpack(matches))
        if (nil ~= val_19_) then
          i_18_ = (i_18_ + 1)
          tbl_17_[i_18_] = val_19_
        end
      end
      s = tbl_17_
    else
    s = nil
    end
  end
  return s
end
local function read_line(filename, line, _3fsource)
  if _3fsource then
    local matcher = string.gmatch((_3fsource .. "\n"), "(.-)(\13?\n)")
    for _ = 2, line do
      matcher()
    end
    return matcher()
  else
    local f = assert(_G.io.open(filename))
    local function close_handlers_10_(ok_11_, ...)
      f:close()
      if ok_11_ then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _5_()
      for _ = 2, line do
        f:read()
      end
      return f:read()
    end
    return close_handlers_10_(_G.xpcall(_5_, (package.loaded.fennel or debug).traceback))
  end
end
local function sub(str, start, _end)
  if ((_end < start) or (#str < start)) then
    return ""
  elseif utf8_ok_3f then
    return string.sub(str, utf8.offset(str, start), ((utf8.offset(str, (_end + 1)) or (utf8.len(str) + 1)) - 1))
  else
    return string.sub(str, start, math.min(_end, str:len()))
  end
end
local function highlight_line(codeline, col, _3fendcol, opts)
  if ((opts and (false == opts["error-pinpoint"])) or (os and os.getenv and os.getenv("NO_COLOR"))) then
    return codeline
  else
    local _8_ = (opts or {})
    local error_pinpoint = _8_["error-pinpoint"]
    local endcol = (_3fendcol or col)
    local eol = nil
    if utf8_ok_3f then
      eol = utf8.len(codeline)
    else
      eol = string.len(codeline)
    end
    local _10_ = (error_pinpoint or {"\27[7m", "\27[0m"})
    local open = _10_[1]
    local close = _10_[2]
    return (sub(codeline, 1, col) .. open .. sub(codeline, (col + 1), (endcol + 1)) .. close .. sub(codeline, (endcol + 2), eol))
  end
end
local function friendly_msg(msg, _12_0, source, opts)
  local _13_ = _12_0
  local col = _13_["col"]
  local endcol = _13_["endcol"]
  local endline = _13_["endline"]
  local filename = _13_["filename"]
  local line = _13_["line"]
  local ok, codeline = pcall(read_line, filename, line, source)
  local endcol0 = nil
  if (ok and codeline and (line ~= endline)) then
    endcol0 = #codeline
  else
    endcol0 = endcol
  end
  local out = {msg, ""}
  if (ok and codeline) then
    if col then
      table.insert(out, highlight_line(codeline, col, endcol0, opts))
    else
      table.insert(out, codeline)
    end
  end
  for _, suggestion in ipairs((suggest(msg) or {})) do
    table.insert(out, ("* Try %s."):format(suggestion))
  end
  return table.concat(out, "\n")
end
local function assert_compile(condition, msg, ast, source, opts)
  if not condition then
    local _17_ = utils["ast-source"](ast)
    local col = _17_["col"]
    local filename = _17_["filename"]
    local line = _17_["line"]
    error(friendly_msg(("%s:%s:%s: Compile error: %s"):format((filename or "unknown"), (line or "?"), (col or "?"), msg), utils["ast-source"](ast), source, opts), 0)
  end
  return condition
end
local function parse_error(msg, filename, line, col, source, opts)
  return error(friendly_msg(("%s:%s:%s: Parse error: %s"):format(filename, line, col, msg), {col = col, filename = filename, line = line}, source, opts), 0)
end
return {["assert-compile"] = assert_compile, ["parse-error"] = parse_error}
