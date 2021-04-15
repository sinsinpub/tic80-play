--[[
-- Collection of Lua common utilities. (Lua 5.1 compatible)
--]]

-- export to global name "utils"
utils = {
  _VERSION = "utils 0.2"
}

-- shortcuts and performance tricks for Lua 5.1
local type, tonumber = type, tonumber
local pairs, ipairs, next, select = pairs, ipairs, next, select
local rawget, rawset, getmetatable, setmetatable = rawget, rawset, getmetatable, setmetatable
local string, tostring, format, byteAt, strupr = string, tostring, string.format, string.byte, string.upper
local math, floor, ceil, modf, min, max = math, math.floor, math.ceil, math.modf, math.min, math.max
local table, tconcat, tinsert, tremove, tsort = table, table.concat, table.insert, table.remove, table.sort
local io, iowrite = io, io.write

-- number methods
function utils.hex(n, l)
  return format("%0"..(l or 2).."X", (n or 0))
end

function utils.int(s, r)
  return tonumber(tostring(s or ""), r or 16)
end

function utils.inc(v, i)
  return (v or 0) + (tonumber(i) or 1)
end

function utils.dec(v, i)
  return (v or 0) - (tonumber(i) or 1)
end

function utils.sgn(v)
  return v == 0 and 0 or v > 0 and 1 or -1
end

function utils.div(v1, v2)
  local i, d = modf(v1 / v2)
  return i
end

function utils.round(v)
  return floor(v + (v < 0 and -0.5 or 0.5))
end

function utils.fixed(method, v, dec)
  local mul = 10 ^ (dec or 0)
  local pre = math
  if method == "round" then
    pre = utils
  elseif method == "floor" then
  elseif method == "ceil" then
  else
    error("unsupport method: "..method)
  end
  return pre[method](v * mul) / mul
end

function utils.warp(v, min, max)
  v = v or min or 0
  if min and v < min then v = max or min end
  if max and v > max then v = min or max end
  return v
end

function utils.warpi(v, min, max)
  v = v or min or 0
  if min and v <= min then v = v + (max or min) - (min or 0) end
  if max and v >= max then v = v - (max or min) - (min or 0) end
  return v
end

function utils.clamp(v, min, max)
  v = v or min or 0
  if min and v < min then v = min end
  if max and v > max then v = max end
  return v
end

function utils.default(v, dv)
  return v == nil and dv or v
end

function utils.iif(cond, tv, fv)
  return cond and tv or fv
end

-- string methods
function utils.isDigit(c)
  local b = type(c) == "string" and byteAt(c) or c
  return b >= 48 and b <= 57
end

function utils.isAlpha(c)
  local b = type(c) == "string" and byteAt(c) or c
  return b >= 65 and b <= 90 or b == 95 or b >= 97 and b <= 122
end

function utils.isBlank(c)
  local b = type(c) == "string" and byteAt(c) or c
  return b <= 32
end

function utils.isNum(s)
  return type(s) == "number"
    or type(s) == "string" and tonumber(s) ~= nil
end

function utils.capitalize(s)
  s = s:gsub("%a", strupr, 1)
  return s
end

function utils.trim(s)
  return s:match("^()%s*$") and "" or s:match("^%s*(.*%S)")
end

function utils.ltrim(s)
  return s:gsub("^%s*", "")
end

function utils.rtrim(s)
  local n = #s
  while n > 0 and s:find("^%s", n) do n = n - 1 end
  return s:sub(1, n)
end

function utils.startsWith(s, start)
  return s:sub(1, #start) == start
end

function utils.endsWith(s, ending)
  return ending == "" or s:sub(-#ending) == ending
end

function utils.contains(s, pat)
  return s:find(pat) ~= nil
end

function utils.subst(str, tbl)
  str = str:gsub("%$%{([%w_]+)%}", function(name)
    local val = tbl[utils.isNum(name) and tonumber(name) or name]
    return val ~= nil and tostring(val)
  end)
  return str
end

function utils.split(str, pat)
  local tbl = {}
  local fpat = "(.-)"..pat
  local lastend = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      tinsert(tbl, cap)
    end
    lastend = e + 1
    s, e, cap = str:find(fpat, lastend)
  end
  if lastend <= #str then
    cap = str:sub(lastend)
    tinsert(tbl, cap)
  end
  return tbl
end

function utils.forEachLine(str, callback)
  if type(str) == "string" and type(callback) == "function" then
    local num = 0
    for line in str:gmatch("[^\r\n]+") do
      num = num + 1
      callback(line, num, str)
    end
  end
end

function utils.tobool(v)
  if type(v) == "string" then return v ~= "" and v ~= "false" end
  if type(v) == "number" then return v ~= 0 end
  return v and true or false
end

-- table methods
function utils.keys(tbl)
  if type(tbl) == "table" then
    local keys = {}
    for k, v in pairs(tbl) do
      keys[#keys + 1] = k
    end
    return keys
  end
  return nil
end

function utils.values(tbl)
  if type(tbl) == "table" then
    local values = {}
    for k, v in pairs(tbl) do
      values[#values + 1] = v
    end
    return values
  end
  return nil
end

function utils.containsKey(tbl, key)
  return type(tbl) == "table" and tbl[key] ~= nil or false
end

function utils.isEmpty(tbl)
  return tbl == nil or type(tbl) == "table" and next(tbl) == nil
end

-- array-like table methods
function utils.isArray(tbl)
  return type(tbl) == "table" and tbl[1] ~= nil
end

function utils.includes(arr, val)
  if type(arr) == "table" then
    for i, v in ipairs(arr) do
      if v == val then return true end
    end
  end
  return false
end

function utils.join(arr, sep)
  return type(arr) == "table" and tconcat(arr, sep or ",") or arr
end

function utils.push(arr, ...)
  if utils.isArray(arr) then
    for i = 1, select("#", ...) do
      arr[#arr + 1] = select(i, ...)
    end
  end
  return arr
end

function utils.slice(arr, st, ed)
  local abs = function(len, i)
    return i < 0 and (len + i + 1) or i
  end
  local n = #arr
  local i = st and abs(n, st) or 1
  local j = ed and abs(n, ed) or n
  local narr = {}
  for k = i < 1 and 1 or i, j > n and n or j do
    narr[#narr + 1] = arr[k]
  end
  return narr
end

-- shallow copy
function utils.copy(tbl)
  if type(tbl) == "table" then
    local nt = {}
    for k, v in pairs(tbl) do nt[k] = v end
    return nt
  end
  return tbl
end

-- deep clone
function utils.clone(orig, copies)
  copies = copies or {}
  local origType = type(orig)
  local copy
  if origType == "table" then
    if copies[orig] then
      copy = copies[orig]
    else
      copy = {}
      for origKey, origValue in next, orig, nil do
        copy[utils.clone(origKey, copies)] = utils.clone(origValue, copies)
      end
      copies[orig] = copy
      setmetatable(copy, utils.clone(getmetatable(orig), copies))
    end
  else
    copy = orig
  end
  return copy
end

-- return copied and sorted table (by values)
function utils.sort(tbl, comp)
  if type(tbl) == "table" then
    local nt = utils.copy(tbl)
    tsort(nt, comp)
    return nt
  end
  return tbl
end

-- return table sorted by keys
function utils.sortedTable(tbl, comp)
  local mt, _korder = {}, {}
  local fsort = comp or function(a, b) return tostring(a) < tostring(b) end
  local isSorted = true
  mt.__index = {
    hidden = function() return pairs(mt.__index) end,
    -- traversal of table ordered: returning index, key
    ipairs = function(self)
      if not isSorted then
        tsort(_korder, fsort)
        isSorted = true
      end
      return ipairs(_korder)
    end,
    -- traversal of table unsorted: returning key, value
    pairs = function(self) return pairs(self) end,
    -- traversal of table sorted: returning key, value
    spairs = function(self)
      if not isSorted then
        tsort(_korder, fsort)
          isSorted = true
      end
      local i = 0
      local function iter(self)
        i = i + 1
        local k = _korder[i]
        if k then
          return k, self[k]
        end
      end
      return iter, self
    end,
    -- to be able to delete entries
    del = function(self, key)
      if self[key] then
        self[key] = nil
        for i, k in ipairs(_korder) do
          if k == key then
            tremove(_korder,i)
            return
          end
        end
      end
    end,
  }
  mt.__newindex = function(self, k, v)
    if k ~= "del" and v then
      rawset(self, k, v)
      tinsert(_korder, k)
      isSorted = false
    end
  end
  return setmetatable(tbl or {}, mt)
end

-- syntax sugar
function utils.switch(defs)
  defs.case = function(self, case, ...)
    local fn = self[case] or self.default
    if fn then
      if type(fn) == "function" then
        fn(self, case, ...)
      elseif type(self[fn]) == "function" then
        self[fn](self, case, ...)
      else
        error("case "..tostring(case).." not a function")
      end
    end
  end
  return defs
end

-- meta table methods
function utils.getMetaMethod(x, n)
  local _, m = pcall(
    function(x) return getmetatable(x)[n] end,
    x
  )
  if type(m) ~= "function" then
    m = nil
  end
  return m
end

-- from http://www.cs.chalmers.se/~rjmh/Papers/pretty.ps
local function render(x, opencb, closecb, elemcb, paircb, sepcb, roots)
  roots = roots or {}
  local function stop_roots(x)
    return roots[x] or
      render(x, opencb, closecb, elemcb, paircb, sepcb, utils.copy(roots))
  end
  if type(x) ~= "table" or utils.getMetaMethod(x, "__tostring") then
    return type(x) == "string" and '"'..x..'"' or elemcb(x)
  else
    local buf, k_, v_ = { opencb(x) }
    roots[x] = elemcb(x)
    for _, k in ipairs(utils.sort(utils.keys(x))) do
      local v = x[k]
      buf[#buf + 1] = sepcb(x, k_, v_, k, v)
      buf[#buf + 1] = paircb(x, k, v, stop_roots(k), stop_roots(v))
      k_, v_ = k, v
    end
    buf[#buf + 1] = sepcb(x, k_, v_)
    buf[#buf + 1] = closecb(x)
    return tconcat(buf)
  end
end

-- deep tostring, dig into table
function utils.tostring(x)
  return render(x,
    function() return "{" end,
    function() return "}" end,
    tostring,
    function(_, _, _, is, vs) return is.."="..vs end,
    function(_, i, _, k) return i and k and ", " or "" end
  )
end

-- for debugging output
function utils.print(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "table" then
      print(utils.tostring(v))
    else
      print(tostring(v))
    end
  end
end

-- for debugging output
function utils.xd(buf, first, last)
  local function align(n) return ceil(n/16)*16 end
  for i = (align((first or 1)-16)+1),
           align(min(last or #buf, #buf)) do
    if (i-1) % 16 == 0 then iowrite(format("%08X ", i-1)) end
    iowrite(i > #buf and '   ' or format("%02X ", buf:byte(i)))
    if i% 8 == 0 then iowrite(' ') end
    if i%16 == 0 then iowrite(buf:sub(i-16+1, i):gsub("%c", "."), "\n") end
  end
end

-- evil eval
function utils.eval(s)
  local loadstr = loadstring or load
  return loadstr("return "..s)()
end

return utils
