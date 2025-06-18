local _1_ = require("fennel.utils")
local utils = _1_
local unpack = _1_["unpack"]
local friend = require("fennel.friend")
local function granulate(getchunk)
  local c, index, done_3f = "", 1, false
  local function _2_(parser_state)
    if not done_3f then
      if (index <= #c) then
        local b = c:byte(index)
        index = (index + 1)
        return b
      else
        local _3_0 = getchunk(parser_state)
        if (nil ~= _3_0) then
          local input = _3_0
          c, index = input, 2
          return c:byte()
        else
          local _ = _3_0
          done_3f = true
          return nil
        end
      end
    end
  end
  local function _7_()
    c = ""
    return nil
  end
  return _2_, _7_
end
local function string_stream(str, _3foptions)
  local str0 = str:gsub("^#!", ";;")
  if _3foptions then
    _3foptions.source = str0
  end
  local index = 1
  local function _9_()
    local r = str0:byte(index)
    index = (index + 1)
    return r
  end
  return _9_
end
local delims = {[123] = 125, [125] = true, [40] = 41, [41] = true, [91] = 93, [93] = true}
local function sym_char_3f(b)
  local b0 = nil
  if ("number" == type(b)) then
    b0 = b
  else
    b0 = string.byte(b)
  end
  return ((32 < b0) and not delims[b0] and (b0 ~= 127) and (b0 ~= 34) and (b0 ~= 39) and (b0 ~= 126) and (b0 ~= 59) and (b0 ~= 44) and (b0 ~= 64) and (b0 ~= 96))
end
local prefixes = {[35] = "hashfn", [39] = "quote", [44] = "unquote", [96] = "quote"}
local nan, negative_nan = nil, nil
if (45 == string.byte(tostring((0 / 0)))) then
  nan, negative_nan = ( - (0 / 0)), (0 / 0)
else
  nan, negative_nan = (0 / 0), ( - (0 / 0))
end
local function char_starter_3f(b)
  return (((1 < b) and (b < 127)) or ((192 < b) and (b < 247)))
end
local function parser_fn(getbyte, filename, _12_0)
  local _13_ = _12_0
  local options = _13_
  local comments = _13_["comments"]
  local source = _13_["source"]
  local unfriendly = _13_["unfriendly"]
  local stack = {}
  local line, byteindex, col, prev_col, lastb = 1, 0, 0, 0, nil
  local function ungetb(ub)
    if char_starter_3f(ub) then
      col = (col - 1)
    end
    if (ub == 10) then
      line, col = (line - 1), prev_col
    end
    byteindex = (byteindex - 1)
    lastb = ub
    return nil
  end
  local function getb()
    local r = nil
    if lastb then
      r, lastb = lastb, nil
    else
      r = getbyte({["stack-size"] = #stack})
    end
    if r then
      byteindex = (byteindex + 1)
    end
    if (r and char_starter_3f(r)) then
      col = (col + 1)
    end
    if (r == 10) then
      line, col, prev_col = (line + 1), 0, col
    end
    return r
  end
  local function warn(...)
    return (options.warn or utils.warn)(...)
  end
  local function whitespace_3f(b)
    local function _21_()
      local _20_0 = options.whitespace
      if (nil ~= _20_0) then
        _20_0 = _20_0[b]
      end
      return _20_0
    end
    return ((b == 32) or ((9 <= b) and (b <= 13)) or _21_())
  end
  local function parse_error(msg, _3fcol_adjust)
    local col0 = (col + (_3fcol_adjust or -1))
    if (nil == utils["hook-opts"]("parse-error", options, msg, filename, (line or "?"), col0, source, utils.root.reset)) then
      utils.root.reset()
      if unfriendly then
        return error(string.format("%s:%s:%s: Parse error: %s", filename, (line or "?"), col0, msg), 0)
      else
        return friend["parse-error"](msg, filename, (line or "?"), col0, source, options)
      end
    end
  end
  local function parse_stream()
    local whitespace_since_dispatch, done_3f, retval = true
    local function set_source_fields(source0)
      source0.byteend, source0.endcol, source0.endline = byteindex, (col - 1), line
      return nil
    end
    local function dispatch(v, _3fsource, _3fraw)
      whitespace_since_dispatch = false
      local v0 = nil
      do
        local _25_0 = utils["hook-opts"]("parse-form", options, v, _3fsource, _3fraw, stack)
        if (nil ~= _25_0) then
          local hookv = _25_0
          v0 = hookv
        else
          local _ = _25_0
          v0 = v
        end
      end
      local _27_0 = stack[#stack]
      if (_27_0 == nil) then
        retval, done_3f = v0, true
        return nil
      elseif ((_G.type(_27_0) == "table") and (nil ~= _27_0.prefix)) then
        local prefix = _27_0.prefix
        local source0 = nil
        do
          local _28_0 = table.remove(stack)
          set_source_fields(_28_0)
          source0 = _28_0
        end
        local list = utils.list(utils.sym(prefix, source0), v0)
        return dispatch(utils.copy(source0, list))
      elseif (nil ~= _27_0) then
        local top = _27_0
        return table.insert(top, v0)
      end
    end
    local function badend()
      local closers = nil
      do
        local tbl_17_ = {}
        local i_18_ = #tbl_17_
        for _, _30_0 in ipairs(stack) do
          local _31_ = _30_0
          local closer = _31_["closer"]
          local val_19_ = closer
          if (nil ~= val_19_) then
            i_18_ = (i_18_ + 1)
            tbl_17_[i_18_] = val_19_
          end
        end
        closers = tbl_17_
      end
      local _33_
      if (#stack == 1) then
        _33_ = ""
      else
        _33_ = "s"
      end
      return parse_error(string.format("expected closing delimiter%s %s", _33_, string.char(unpack(closers))), 0)
    end
    local function skip_whitespace(b, close_table)
      if (b and whitespace_3f(b)) then
        whitespace_since_dispatch = true
        return skip_whitespace(getb(), close_table)
      elseif (not b and next(stack)) then
        badend()
        for i = #stack, 2, -1 do
          close_table(stack[i].closer)
        end
        return stack[1].closer
      else
        return b
      end
    end
    local function parse_comment(b, contents)
      if (b and (10 ~= b)) then
        local function _36_()
          table.insert(contents, string.char(b))
          return contents
        end
        return parse_comment(getb(), _36_())
      elseif comments then
        ungetb(10)
        return dispatch(utils.comment(table.concat(contents), {filename = filename, line = line}))
      end
    end
    local function open_table(b)
      if not whitespace_since_dispatch then
        parse_error(("expected whitespace before opening delimiter " .. string.char(b)))
      end
      return table.insert(stack, {bytestart = byteindex, closer = delims[b], col = (col - 1), filename = filename, line = line})
    end
    local function close_list(list)
      return dispatch(setmetatable(list, getmetatable(utils.list())))
    end
    local function close_sequence(tbl)
      local mt = getmetatable(utils.sequence())
      for k, v in pairs(tbl) do
        if ("number" ~= type(k)) then
          mt[k] = v
          tbl[k] = nil
        end
      end
      return dispatch(setmetatable(tbl, mt))
    end
    local function add_comment_at(comments0, index, node)
      local _40_0 = comments0[index]
      if (nil ~= _40_0) then
        local existing = _40_0
        return table.insert(existing, node)
      else
        local _ = _40_0
        comments0[index] = {node}
        return nil
      end
    end
    local function next_noncomment(tbl, i)
      if utils["comment?"](tbl[i]) then
        return next_noncomment(tbl, (i + 1))
      elseif utils["sym?"](tbl[i], ":") then
        return tostring(tbl[(i + 1)])
      else
        return tbl[i]
      end
    end
    local function extract_comments(tbl)
      local comments0 = {keys = {}, last = {}, values = {}}
      while utils["comment?"](tbl[#tbl]) do
        table.insert(comments0.last, 1, table.remove(tbl))
      end
      local last_key_3f = false
      for i, node in ipairs(tbl) do
        if not utils["comment?"](node) then
          last_key_3f = not last_key_3f
        elseif last_key_3f then
          add_comment_at(comments0.values, next_noncomment(tbl, i), node)
        else
          add_comment_at(comments0.keys, next_noncomment(tbl, i), node)
        end
      end
      for i = #tbl, 1, -1 do
        if utils["comment?"](tbl[i]) then
          table.remove(tbl, i)
        end
      end
      return comments0
    end
    local function close_curly_table(tbl)
      local comments0 = extract_comments(tbl)
      local keys = {}
      local val = {}
      if ((#tbl % 2) ~= 0) then
        byteindex = (byteindex - 1)
        parse_error("expected even number of values in table literal")
      end
      setmetatable(val, tbl)
      for i = 1, #tbl, 2 do
        if ((tostring(tbl[i]) == ":") and utils["sym?"](tbl[(i + 1)]) and utils["sym?"](tbl[i])) then
          tbl[i] = tostring(tbl[(i + 1)])
        end
        val[tbl[i]] = tbl[(i + 1)]
        table.insert(keys, tbl[i])
      end
      tbl.comments = comments0
      tbl.keys = keys
      return dispatch(val)
    end
    local function close_table(b)
      local top = table.remove(stack)
      if (top == nil) then
        parse_error(("unexpected closing delimiter " .. string.char(b)))
      end
      if (top.closer and (top.closer ~= b)) then
        parse_error(("mismatched closing delimiter " .. string.char(b) .. ", expected " .. string.char(top.closer)))
      end
      set_source_fields(top)
      if (b == 41) then
        return close_list(top)
      elseif (b == 93) then
        return close_sequence(top)
      else
        return close_curly_table(top)
      end
    end
    local function parse_string_loop(chars, b, state)
      if b then
        table.insert(chars, string.char(b))
      end
      local state0 = nil
      do
        local _51_0 = {state, b}
        if ((_G.type(_51_0) == "table") and (_51_0[1] == "base") and (_51_0[2] == 92)) then
          state0 = "backslash"
        elseif ((_G.type(_51_0) == "table") and (_51_0[1] == "base") and (_51_0[2] == 34)) then
          state0 = "done"
        elseif ((_G.type(_51_0) == "table") and (_51_0[1] == "backslash") and (_51_0[2] == 10)) then
          table.remove(chars, (#chars - 1))
          state0 = "base"
        else
          local _ = _51_0
          state0 = "base"
        end
      end
      if (b and (state0 ~= "done")) then
        return parse_string_loop(chars, getb(), state0)
      else
        return b
      end
    end
    local function escape_char(c)
      return ({[10] = "\\n", [11] = "\\v", [12] = "\\f", [13] = "\\r", [7] = "\\a", [8] = "\\b", [9] = "\\t"})[c:byte()]
    end
    local function parse_string(source0)
      if not whitespace_since_dispatch then
        warn("expected whitespace before string", nil, filename, line)
      end
      table.insert(stack, {closer = 34})
      local chars = {"\""}
      if not parse_string_loop(chars, getb(), "base") then
        badend()
      end
      table.remove(stack)
      local raw = table.concat(chars)
      local formatted = raw:gsub("[\7-\13]", escape_char)
      local _56_0 = (rawget(_G, "loadstring") or load)(("return " .. formatted))
      if (nil ~= _56_0) then
        local load_fn = _56_0
        return dispatch(load_fn(), source0, raw)
      elseif (_56_0 == nil) then
        return parse_error(("Invalid string: " .. raw))
      end
    end
    local function parse_prefix(b)
      table.insert(stack, {bytestart = byteindex, col = (col - 1), filename = filename, line = line, prefix = prefixes[b]})
      local nextb = getb()
      local trailing_whitespace_3f = (whitespace_3f(nextb) or (true == delims[nextb]))
      if (trailing_whitespace_3f and (b ~= 35)) then
        parse_error("invalid whitespace after quoting prefix")
      end
      ungetb(nextb)
      if (trailing_whitespace_3f and (b == 35)) then
        local source0 = table.remove(stack)
        set_source_fields(source0)
        return dispatch(utils.sym("#", source0))
      end
    end
    local function parse_sym_loop(chars, b)
      if (b and sym_char_3f(b)) then
        table.insert(chars, string.char(b))
        return parse_sym_loop(chars, getb())
      else
        if b then
          ungetb(b)
        end
        return chars
      end
    end
    local function parse_number(rawstr, source0)
      local trimmed = (not rawstr:find("^_") and rawstr:gsub("_", ""))
      if ((trimmed == "nan") or (trimmed == "-nan")) then
        return false
      elseif rawstr:match("^%d") then
        dispatch((tonumber(trimmed) or parse_error(("could not read number \"" .. rawstr .. "\""))), source0, rawstr)
        return true
      else
        local _62_0 = tonumber(trimmed)
        if (nil ~= _62_0) then
          local x = _62_0
          dispatch(x, source0, rawstr)
          return true
        else
          local _ = _62_0
          return false
        end
      end
    end
    local function check_malformed_sym(rawstr)
      local function col_adjust(pat)
        return (rawstr:find(pat) - utils.len(rawstr) - 1)
      end
      if (rawstr:match("^~") and (rawstr ~= "~=")) then
        parse_error("invalid character: ~")
      elseif (rawstr:match("[%.:][%.:]") and (rawstr ~= "..") and (rawstr ~= "$...")) then
        parse_error(("malformed multisym: " .. rawstr), col_adjust("[%.:][%.:]"))
      elseif ((rawstr ~= ":") and rawstr:match(":$")) then
        parse_error(("malformed multisym: " .. rawstr), col_adjust(":$"))
      elseif rawstr:match(":.+[%.:]") then
        parse_error(("method must be last component of multisym: " .. rawstr), col_adjust(":.+[%.:]"))
      end
      if not whitespace_since_dispatch then
        warn("expected whitespace before token", nil, filename, line)
      end
      return rawstr
    end
    local function parse_sym(b)
      local source0 = {bytestart = byteindex, col = (col - 1), filename = filename, line = line}
      local rawstr = table.concat(parse_sym_loop({string.char(b)}, getb()))
      set_source_fields(source0)
      if (rawstr == "true") then
        return dispatch(true, source0)
      elseif (rawstr == "false") then
        return dispatch(false, source0)
      elseif (rawstr == "...") then
        return dispatch(utils.varg(source0))
      elseif (rawstr == ".inf") then
        return dispatch((1 / 0), source0, rawstr)
      elseif (rawstr == "-.inf") then
        return dispatch((-1 / 0), source0, rawstr)
      elseif (rawstr == ".nan") then
        return dispatch(nan, source0, rawstr)
      elseif (rawstr == "-.nan") then
        return dispatch(negative_nan, source0, rawstr)
      elseif rawstr:match("^:.+$") then
        return dispatch(rawstr:sub(2), source0, rawstr)
      elseif not parse_number(rawstr, source0) then
        return dispatch(utils.sym(check_malformed_sym(rawstr), source0))
      end
    end
    local function parse_loop(b)
      if not b then
      elseif (b == 59) then
        parse_comment(getb(), {";"})
      elseif (type(delims[b]) == "number") then
        open_table(b)
      elseif delims[b] then
        close_table(b)
      elseif (b == 34) then
        parse_string({bytestart = byteindex, col = col, filename = filename, line = line})
      elseif prefixes[b] then
        parse_prefix(b)
      elseif (sym_char_3f(b) or (b == string.byte("~"))) then
        parse_sym(b)
      elseif not utils["hook-opts"]("illegal-char", options, b, getb, ungetb, dispatch) then
        parse_error(("invalid character: " .. string.char(b)))
      end
      if not b then
        return nil
      elseif done_3f then
        return true, retval
      else
        return parse_loop(skip_whitespace(getb(), close_table))
      end
    end
    return parse_loop(skip_whitespace(getb(), close_table))
  end
  local function _70_()
    stack, line, byteindex, col, lastb = {}, 1, 0, 0, ((lastb ~= 10) and lastb)
    return nil
  end
  return parse_stream, _70_
end
local function parser(stream_or_string, _3ffilename, _3foptions)
  local filename = (_3ffilename or "unknown")
  local options = (_3foptions or utils.root.options or {})
  assert(("string" == type(filename)), "expected filename as second argument to parser")
  if ("string" == type(stream_or_string)) then
    return parser_fn(string_stream(stream_or_string, options), filename, options)
  else
    return parser_fn(stream_or_string, filename, options)
  end
end
return {["string-stream"] = string_stream, ["sym-char?"] = sym_char_3f, granulate = granulate, parser = parser}
