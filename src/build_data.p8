pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function debug(infos, pos, col1, col2)
 for i, info in ipairs(infos) do
  local inf = info[2]
  if type(inf) == "table" and inf.x then
   inf = inf.x .. "," .. inf.y
  end
  pprint(info[1] .. " : " .. tostr(inf), pos.x, pos.y + ((i - 1) * 7), col1 or 7, col2 or 5)
 end
end

-- data encoders

-- joins strings in a table with a separator
-- @param t: table of strings to join
-- @param sep: separator string (default is empty)
-- @return: joined string
function join(t, sep)
 local s = ""
 for i = 1, #t do
  s = s .. t[i] .. (i < #t and sep or "")
 end
 return s
end

-- encoder for multiple named tables with specified types
-- accepts a table where keys are table names and values are the tables to encode
-- Automatically detects types like encode_records does
-- @param tables: table of {[table_name] = table_data}
-- @return: encoded string containing all tables
function encode_tables(tables)
 local encoded_tables = {}
 for name, elems in pairs(tables) do
  local encoded = {}
  local elem_type

  -- determine type from first element (assuming homogeneous table)
  local _, first_val = next(elems)
  if type(first_val) == "table" then
   if first_val.x and first_val.y then
    elem_type = 3 -- v2 type
   else
    elem_type = 5 -- list type
   end
  elseif type(first_val) == "number" then
   elem_type = 1 -- number
  elseif type(first_val) == "string" then
   elem_type = 2 -- string
  elseif type(first_val) == "boolean" then
   elem_type = 4 -- boolean
  else
   elem_type = 2 -- default to string if unknown
  end

  for k, v in pairs(elems) do
   local val
   if elem_type == 1 then
    val = tostr(v)
   elseif elem_type == 2 then
    val = v
   elseif elem_type == 3 then
    val = v.x .. ":" .. v.y
   elseif elem_type == 4 then
    val = v and "1" or "0"
   elseif elem_type == 5 then
    val = join(v, "@")
   end

   add(encoded, k .. ";" .. val)
  end

  -- store table info as: name#type#encoded_data
  add(encoded_tables, name .. "#" .. elem_type .. "#" .. join(encoded, ","))
 end

 return join(encoded_tables, "|")
end

-- encoder for a list of records (heterogeneous objects)
-- automatically detects data types from the first record
-- supports arrays of simple types
-- @param records: table of records (objects with same structure)
-- @return: format_string, data_string (two separate strings)
--   format_string describes the structure of the data
--   data_string contains the actual encoded values
function encode_records(records)
 local type_map = { number = 1, string = 2, table = 3, boolean = 4 }

 local format_parts, data_parts = {}, {}

 -- detect format from the first record
 local first = records[1]
 for k, v in pairs(first) do
  local type_code
  if type(v) == "table" and v.x and v.y then
   type_code = 3 -- v2 type
  elseif type(v) == "number" then
   type_code = 1 -- number
  elseif type(v) == "string" then
   type_code = 2 -- string
  elseif type(v) == "boolean" then
   type_code = 4 -- boolean
  elseif type(v) == "table" then
   -- handle arrays/lists of simple types
   local sub_type = type(v[1])
   if sub_type == "table" and v[1].x then
    sub_type = 3 -- v2 type
   else
    sub_type = type_map[sub_type]
   end
   type_code = 10 + sub_type -- array type code (11-14)
  end

  add(format_parts, type_code .. ";" .. k)
 end

 -- encode all records according to detected format
 for rec in all(records) do
  local encoded_rec = {}

  for part in all(format_parts) do
   local type_code, key = unpack(split(part, ";"))
   type_code = tonum(type_code)
   local val = rec[key]

   if type_code < 10 then
    -- simple type
    if type_code == 4 then
     -- boolean
     val = val and "1" or "0"
    elseif type_code == 3 then
     -- v2
     val = val.x .. ":" .. val.y
    else
     -- number or string
     val = tostr(val)
    end
   else
    -- array type
    local sub_vals = {}
    for sub_val in all(val) do
     if type_code % 10 == 4 then
      -- boolean array
      add(sub_vals, sub_val and "1" or "0")
     elseif type_code % 10 == 3 then
      -- v2 array
      add(sub_vals, sub_val.x .. ":" .. sub_val.y)
     else
      -- number or string array
      add(sub_vals, tostr(sub_val))
     end
    end
    val = join(sub_vals, "#")
   end

   add(encoded_rec, val)
  end

  add(data_parts, join(encoded_rec, ","))
 end

 return join(format_parts, ","), join(data_parts, "|")
end

function encode_kv(tbl)
 local idx, ms = 0, function(i, v) mset(i % 128, flr(i / 128), v) end
 for k, v in pairs(tbl) do
  -- key (3 bytes)
  for i = 1, 3 do
   local b = ord(sub(k, i, i))
   ms(idx, b)
   idx += 1
  end
  -- length (2 bytes)
  local len = #v
  local hi, lo = flr(len / 256), len % 256
  for _, b in ipairs({ hi, lo }) do
   ms(idx, b)
   idx += 1
  end
  -- value (len bytes)
  for i = 1, len do
   local b = ord(sub(v, i, i))
   ms(idx, b)
   idx += 1
  end
 end
 -- sentinel: signal end-of-stream
 mset(idx % 128, flr(idx / 128), 0)
 idx += 1
 return idx
end

function v2(x, y) return { x = x or 0, y = y or 0 } end

lookup_tables = {
 msgs = {
  "spawn in 1",
  "spawn in 2",
  "spawn in 3",
  "join 🅾️/❎"
 },

 obj_nums = {
  { 3, 5, 7 },
  { 0, 3, 5 },
  { 2, 4, 6 }
 },

 map_cols = {
  -- earth
  { 129, 4, 3, 5 },
  { 128, 4, 9, 0 },
  { 130, 5, 3, 4 },
  -- void
  { 133, 0, 3, 11 },
  { 130, 2, 14, 8 },
  { 129, 13, 12, 15 },
  -- ruins
  { 133, 5, 4, 0 },
  { 128, 5, 6, 0 },
  { 132, 5, 0, 6 }
 }
}

-- lookup_tbl = {
--  {
--   m = "spawn in 1",
--   o = { 3, 5, 7 }
--   mc = { 129, 4, 3, 5, 128, 4, 9, 0, 130, 5, 3, 4}
--  },

-- }

aims = {
 {
  n = "e",
  sp_i = 2,
  f_x = false,
  f_y = false,
  v2_mod = v2(1, 0),
  an_i = 9,
  mel = v2(.9, .4)
 },
 {
  n = "ne",
  sp_i = 1,
  f_x = false,
  f_y = false,
  v2_mod = v2(.7, -.7),
  an_i = 15,
  mel = v2(.7, -.7)
 },
 {
  n = "n",
  sp_i = 0,
  f_x = false,
  f_y = false,
  v2_mod = v2(0, -1),
  an_i = 16,
  mel = v2(0, -1)
 },
 {
  n = "nw",
  sp_i = 1,
  f_x = true,
  f_y = false,
  v2_mod = v2(-.7, -.7),
  an_i = 15,
  mel = v2(-.7, -.7)
 },
 {
  n = "w",
  sp_i = 2,
  f_x = true,
  f_y = false,
  v2_mod = v2(-1, 0),
  an_i = 9,
  mel = v2(-.9, .4)
 },
 {
  n = "sw",
  sp_i = 3,
  f_x = true,
  f_y = false,
  v2_mod = v2(-.7, .7),
  an_i = 17,
  mel = v2(-.7, .7)
 },
 {
  n = "s",
  sp_i = 0,
  f_x = false,
  f_y = true,
  v2_mod = v2(0, 1),
  an_i = 18,
  mel = v2(0, 1)
 },
 {
  n = "se",
  sp_i = 3,
  f_x = false,
  f_y = false,
  v2_mod = v2(.7, .7),
  an_i = 17,
  mel = v2(.7, .7)
 }
}

--- Particles ---
particles = {
 {
  name = "projm",
  kinds = { 5 },
  life = v2(300, 600),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0 },
  cols = { 10, 9 },
  fri = .995,
  gra = .01
 },
 {
  name = "projo",
  kinds = { 5 },
  life = v2(100, 100),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0 },
  cols = { 8, 2 },
  fri = 1,
  gra = 0
 },
 {
  name = "projg",
  kinds = { 5 },
  life = v2(360, 360),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0 },
  cols = { 11, 3 },
  fri = .99,
  gra = .01
 },
 {
  name = "roc",
  kinds = { 6 },
  life = v2(180, 180),
  x_s = v2(),
  y_s = v2(),
  sizes = { 2 },
  cols = { 11, 9 },
  fri = 1,
  gra = 0
 },
 {
  name = "lim",
  kinds = { 7 },
  life = v2(420, 420),
  x_s = v2(-.1, .1),
  y_s = v2(-.1, -.2),
  sizes = { 2 },
  cols = { 8, 11 },
  fri = .99,
  gra = .02
 },
 {
  name = "knife",
  kinds = { 7 },
  life = v2(420, 420),
  x_s = v2(0, 0),
  y_s = v2(0, 0),
  sizes = { 2 },
  cols = { 4, 7 },
  fri = .999,
  gra = .007
 },
 {
  name = "rlproj",
  kinds = { 4 },
  life = v2(120, 120),
  x_s = v2(),
  y_s = v2(),
  sizes = { 3 },
  cols = { 8 },
  fri = 1,
  gra = 0
 },
 {
  name = "bproj",
  kinds = { 4 },
  life = v2(120, 120),
  x_s = v2(),
  y_s = v2(),
  sizes = { 3 },
  cols = { 12 },
  fri = 1,
  gra = 0
 },
 {
  name = "smk",
  kinds = { 1, 2 },
  life = v2(35, 45),
  x_s = v2(-.17, .17),
  y_s = v2(-.3, -.2),
  sizes = { 0, 1, 1 },
  cols = { 7, 6, 6, 5 },
  fri = 1,
  gra = -.005
 },
 {
  name = "smkb",
  kinds = { 2 },
  life = v2(24, 36),
  x_s = v2(-.1, .1),
  y_s = v2(-.1, -.1),
  sizes = { 2, 1, 1, 0, 0 },
  cols = { 5 },
  fri = 1,
  gra = -.001
 },
 {
  name = "smkc",
  kinds = { 2 },
  life = v2(52, 68),
  x_s = v2(-.1, .1),
  y_s = v2(-.1, -.1),
  sizes = { 1, 0, 0, 0 },
  cols = { 7, 6, 5 },
  fri = 1,
  gra = -.001
 },
 {
  name = "dus",
  kinds = { 2 },
  life = v2(52, 68),
  x_s = v2(-.25, .25),
  y_s = v2(-.1, -.3),
  sizes = { 1, 1, 0 },
  cols = { 15, 6 },
  fri = 1,
  gra = .01
 },
 {
  name = "heal",
  kinds = { 2 },
  life = v2(60, 90),
  x_s = v2(-.1, .1),
  y_s = v2(.05, .1),
  sizes = { 0, 1, 1 },
  cols = { 7, 7, 7, 11, 3 },
  fri = 0.99,
  gra = -0.007
 },
 {
  name = "hit",
  kinds = { 2 },
  life = v2(16, 22),
  x_s = v2(),
  y_s = v2(),
  sizes = { 1, 1, 0 },
  cols = { 10, 7 },
  fri = 0.74,
  gra = 0
 },
 {
  name = "rhit",
  kinds = { 2 },
  life = v2(8, 12),
  x_s = v2(),
  y_s = v2(),
  sizes = { 1, 1, 0 },
  cols = { 8, 2 },
  fri = 0.75,
  gra = 0
 },
 {
  name = "blo",
  kinds = { 0 },
  life = v2(120, 180),
  x_s = v2(-.17, .17),
  y_s = v2(-.3, -.2),
  sizes = { 0 },
  cols = { 8, 2 },
  fri = .99,
  gra = .015
 },
 {
  name = "jpa",
  kinds = { 1, 2 },
  life = v2(12, 16),
  x_s = v2(-.1, .1),
  y_s = v2(),
  sizes = { 1, 1, 0 },
  cols = { 7, 10, 9 },
  fri = .98,
  gra = -.01
 },
 {
  name = "drt",
  kinds = { 0 },
  life = v2(9, 90),
  x_s = v2(-.2, .2),
  y_s = v2(0, -.2),
  sizes = { 0 },
  cols = { 0 },
  fri = .98,
  gra = .01
 },
 {
  name = "mflm",
  kinds = { 1 },
  life = v2(40, 60),
  x_s = v2(-.07, .07),
  y_s = v2(-.02, -.01),
  sizes = { 0 },
  cols = { 7, 10, 9, 8, 2, 5 },
  fri = .99,
  gra = -.01
 },
 {
  name = "flm",
  kinds = { 2 },
  life = v2(33, 66),
  x_s = v2(-.2, .2),
  y_s = v2(),
  sizes = { 1, 1, 1, 1, 0 },
  cols = { 7, 10, 10, 9, 9, 8, 2 },
  fri = .99,
  gra = -.013
 },
 {
  name = "spa",
  kinds = { 0, 4 },
  life = v2(45, 85),
  x_s = v2(-.5, .5),
  y_s = v2(-.2, -.4),
  sizes = { 1, 2, 2, 1 },
  cols = { 7, 10, 9, 8, 5, 0 },
  fri = .98,
  gra = .01
 },
 {
  name = "aci",
  kinds = { 0 },
  life = v2(120, 180),
  x_s = v2(-.5, .5),
  y_s = v2(-.5, -1),
  sizes = { 0 },
  cols = { 11, 3 },
  fri = .975,
  gra = .02
 },
 -- spawn circles
 {
  name = "scib",
  kinds = { 1 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 5, 3, 2, 1, 0 },
  cols = { 7, 12, 13 },
  fri = 0,
  gra = 0
 },
 {
  name = "scir",
  kinds = { 1 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 5, 3, 2, 1, 0 },
  cols = { 7, 8, 2 },
  fri = 0,
  gra = 0
 },
 {
  name = "sci1",
  kinds = { 1 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 5, 3, 2, 1, 0 },
  cols = { 0 },
  fri = 0,
  gra = 0
 },
 {
  name = "sci2",
  kinds = { 1 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 13, 11, 9, 7, 5, 3, 2, 1, 0 },
  cols = { 7 },
  fri = 0,
  gra = 0
 },
 -- spawn squares
 {
  name = "ssq1",
  kinds = { 3 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 5, 3, 2, 1, 0 },
  cols = { 7 },
  fri = 0,
  gra = 0
 },
 {
  name = "ssq2",
  kinds = { 3 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 13, 11, 9, 7, 5, 3, 2, 1, 0 },
  cols = { 7 },
  fri = 0,
  gra = 0
 },
 -- spawn lines
 {
  name = "sli1",
  kinds = { 4 },
  life = v2(40, 48),
  x_s = v2(),
  y_s = v2(),
  sizes = { 3, 2, 1 },
  cols = { 7 },
  fri = .95,
  gra = 0
 },
 {
  name = "sli2",
  kinds = { 4 },
  life = v2(44, 52),
  x_s = v2(),
  y_s = v2(),
  sizes = { 5, 4, 3, 2, 1 },
  cols = { 7 },
  fri = .95,
  gra = 0
 },
 -- explosion particles
 {
  name = "sho1",
  kinds = { 1 },
  life = v2(8, 12),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0, 1, 2, 3, 5, 7, 9 },
  cols = { 7 },
  fri = 0,
  gra = 0
 },
 {
  name = "sho2",
  kinds = { 1 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0, 1, 3, 5, 7, 9, 11, 13, 15, 17 },
  cols = { 7 },
  fri = 0,
  gra = 0
 },
 {
  name = "rsho1",
  kinds = { 1 },
  life = v2(8, 12),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0, 1, 2, 3, 5, 7, 9 },
  cols = { 7, 8, 2 },
  fri = 0,
  gra = 0
 },
 {
  name = "bsho1",
  kinds = { 1 },
  life = v2(8, 12),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0, 1, 2, 3, 5, 7, 9 },
  cols = { 7, 12, 13 },
  fri = 0,
  gra = 0
 },
 {
  name = "gsho2",
  kinds = { 1 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0, 1, 3, 5, 7, 9, 11, 13 },
  cols = { 7, 11, 3 },
  fri = 0,
  gra = 0
 },
 {
  name = "blo1",
  kinds = { 2 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 2, 3, 2 },
  cols = { 7, 10, 9, 8, 2 },
  fri = .66,
  gra = 0
 },
 {
  name = "blo2",
  kinds = { 2 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 3, 4, 5, 3, 2 },
  cols = { 7, 10, 9, 8, 2 },
  fri = .66,
  gra = 0
 },
 {
  name = "fls1",
  kinds = { 2 },
  life = v2(6, 8),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0, 1, 0 },
  cols = { 7, 10, 9 },
  fri = .66,
  gra = 0
 },
 {
  name = "fls2",
  kinds = { 2 },
  life = v2(8, 12),
  x_s = v2(),
  y_s = v2(),
  sizes = { 2, 3, 2, 1 },
  cols = { 7, 10, 9 },
  fri = .66,
  gra = 0
 },
 {
  name = "rfls1",
  kinds = { 2 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 1, 2, 1 },
  cols = { 7, 8, 2 },
  fri = .66,
  gra = 0
 },
 {
  name = "rfls2",
  kinds = { 2 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 2, 3, 2 },
  cols = { 7, 8, 2 },
  fri = .66,
  gra = 0
 },
 {
  name = "bfls1",
  kinds = { 2 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 1, 2, 1 },
  cols = { 7, 12, 13 },
  fri = .66,
  gra = 0
 },
 {
  name = "bfls2",
  kinds = { 2 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 2, 3, 2 },
  cols = { 7, 12, 13 },
  fri = .66,
  gra = 0
 },
 {
  name = "gfls2",
  kinds = { 2 },
  life = v2(12, 16),
  x_s = v2(),
  y_s = v2(),
  sizes = { 2, 3, 2 },
  cols = { 7, 11, 3 },
  fri = .66,
  gra = 0
 },
 -- projectiles
 {
  name = "proj1",
  kinds = { 1 },
  life = v2(300, 320),
  x_s = v2(),
  y_s = v2(),
  sizes = { 0 },
  cols = { 7, 9 },
  fri = .997,
  gra = .01
 }
}

-- effects
effects = {
 {
  na = "bfls",
  ba = "bfls2",
  sho = "nope",
  af = "smkb",
  sp = 0,
  bu = 1,
  de = v2(0, 2)
 },
 {
  na = "rfls",
  ba = "rfls2",
  sho = "nope",
  af = "smkb",
  sp = 0,
  bu = 1,
  de = v2(0, 2)
 },
 {
  na = "rpg",
  ba = "blo2",
  sho = "sho2",
  af = "smkb+smk",
  sp = 5,
  bu = 9,
  de = v2(6, 18)
 },
 {
  na = "gre",
  ba = "fls2",
  sho = "sho1",
  af = "smkb+smk",
  sp = 5,
  bu = 9,
  de = v2(4, 12)
 },
 {
  na = "orbr",
  ba = "rfls2",
  sho = "rsho1",
  af = "smkb",
  sp = 0,
  bu = 1,
  de = v2(0, 2)
 },
 {
  na = "molt",
  ba = "fls2",
  sho = "sho1",
  af = "smkb",
  sp = 3,
  bu = 5,
  de = v2(4, 12)
 },
 {
  na = "brl",
  ba = "gfls2",
  sho = "gsho2",
  af = "smk+smkb",
  sp = 4,
  bu = 7,
  de = v2(8, 22)
 },
 {
  na = "mne",
  ba = "blo1",
  sho = "sho1",
  af = "smk+smkb",
  sp = 3,
  bu = 5,
  de = v2(2, 10)
 },
 {
  na = "hpb",
  ba = "fls2",
  sho = "nope",
  af = "smkb",
  sp = 0,
  bu = 1,
  de = v2(0, 2)
 }
}

players = {
 {
  id = 1,
  spr_i = 80,
  c1 = 11,
  c2 = 3,
  c3 = 15,
  bar_d = -1,
  l = true,
  ind = "r",
  pos = v2(126, 0),
  w_pos = v2(96, 0),
  hp_x1 = 113,
  hp_x2 = 104,
  hp_y1 = 1,
  hp_y2 = 4,
  ammo_x = 111,
  ammo_y = 6,
  msg_x = 127,
  msg_y = 1,
  scr_x = 90,
  scr_y = 1,
  scr = 0,
  soldier = false,
  conn = false,
  spwn = 0,
  msg = 4
 },
 {
  id = 2,
  spr_i = 81,
  c1 = 12,
  c2 = 13,
  c3 = 15,
  bar_d = 1,
  l = false,
  ind = "l",
  pos = v2(1, 0),
  w_pos = v2(32, 0),
  hp_x1 = 15,
  hp_x2 = 24,
  hp_y1 = 1,
  hp_y2 = 4,
  ammo_x = 17,
  ammo_y = 6,
  msg_x = 2,
  msg_y = 1,
  scr_x = 40,
  scr_y = 1,
  scr = 0,
  soldier = false,
  conn = false,
  spwn = 0,
  msg = 4
 },
 {
  id = 3,
  spr_i = 82,
  c1 = 10,
  c2 = 4,
  c3 = 9,
  bar_d = -1,
  l = true,
  ind = "r",
  pos = v2(126, 120),
  w_pos = v2(96, 121),
  hp_x1 = 113,
  hp_x2 = 104,
  hp_y1 = 121,
  hp_y2 = 124,
  ammo_x = 111,
  ammo_y = 126,
  msg_x = 127,
  msg_y = 122,
  scr_x = 90,
  scr_y = 122,
  scr = 0,
  soldier = false,
  conn = false,
  spwn = 0,
  msg = 4
 },
 {
  id = 4,
  spr_i = 83,
  c1 = 7,
  c2 = 6,
  c3 = 15,
  bar_d = 1,
  l = false,
  ind = "l",
  pos = v2(1, 120),
  w_pos = v2(32, 121),
  hp_x1 = 15,
  hp_x2 = 24,
  hp_y1 = 121,
  hp_y2 = 124,
  ammo_x = 17,
  ammo_y = 126,
  msg_x = 2,
  msg_y = 122,
  scr_x = 40,
  scr_y = 122,
  scr = 0,
  soldier = false,
  conn = false,
  spwn = 0,
  msg = 4
 }
}

weapons = {
 -- pistol
 {
  id = 1,
  spr_i = 15,
  dmg = v2(2.8, 3.2),
  mag = 8,
  bu = 1,
  co = .01,
  r_ti = 90,
  w_cd = 22,
  proj_fn = "proj1",
  fo = v2(1.2, 1.3),
  v_m = 0,
  kn_f = .25,
  kn_t = 6,
  kn_r = 0,
  des = v2(2, 3),
  d_f = .8,
  m_fn = "fls1",
  msfx = 40,
  e_fn = "fls2",
  esfx = 41
 },
 -- knife
 {
  id = 2,
  spr_i = 20,
  dmg = v2(6, 9),
  mag = 1,
  bu = 1,
  co = .01,
  r_ti = 45,
  w_cd = 0,
  proj_fn = "knife",
  fo = v2(1, 1),
  v_m = .02,
  kn_f = .7,
  kn_t = 20,
  kn_r = 0,
  des = v2(),
  d_f = 0,
  m_fn = "nope",
  msfx = 42,
  e_fn = "spa",
  esfx = 43
 },
 -- bolter
 {
  id = 3,
  spr_i = 25,
  dmg = v2(.9, 1.1),
  mag = 35,
  bu = 1,
  co = .015,
  r_ti = 120,
  w_cd = 6,
  proj_fn = "proj1",
  fo = v2(1.4, 1.5),
  v_m = 0,
  kn_f = .2,
  kn_t = 6,
  kn_r = 0,
  des = v2(2, 3),
  d_f = .85,
  m_fn = "fls1",
  msfx = 44,
  e_fn = "fls1",
  esfx = 41
 },
 -- shotgun
 {
  id = 4,
  spr_i = 30,
  dmg = v2(1, 1.3),
  mag = 5,
  bu = 5,
  co = .023,
  r_ti = 110,
  w_cd = 30,
  proj_fn = "proj1",
  fo = v2(0.9, 1.3),
  v_m = 0,
  kn_f = .15,
  kn_t = 12,
  kn_r = 0,
  des = v2(2, 3),
  d_f = .9,
  m_fn = "fls2",
  msfx = 45,
  e_fn = "fls1",
  esfx = 41
 },
 -- -- lazer rifle
 {
  id = 5,
  spr_i = 35,
  dmg = v2(6, 7),
  mag = 4,
  bu = 1,
  co = 0,
  r_ti = 110,
  w_cd = 25,
  proj_fn = "bproj",
  fo = v2(2, 2),
  v_m = 0,
  kn_f = 1.1,
  kn_t = 16,
  kn_r = 64,
  des = v2(3, 4),
  d_f = 1.2,
  m_fn = "scib",
  msfx = 44,
  e_fn = "bfls",
  esfx = 43
 },
 -- -- rpg
 {
  spr_i = 40,
  id = 6,
  dmg = v2(7, 8),
  mag = 1,
  bu = 1,
  co = .01,
  r_ti = 120,
  w_cd = 0,
  proj_fn = "roc",
  fo = v2(.8, .9),
  v_m = 0,
  kn_f = 2,
  kn_t = 30,
  kn_r = 320,
  des = v2(6, 7),
  d_f = 1.1,
  m_fn = "fls2",
  msfx = 48,
  e_fn = "rpg",
  esfx = 35
 },
 -- -- flamethrower
 {
  id = 7,
  spr_i = 45,
  dmg = v2(.5, .8),
  mag = 50,
  bu = 3,
  co = .01,
  r_ti = 100,
  w_cd = 10,
  proj_fn = "flm",
  fo = v2(.7, .9),
  v_m = -.05,
  kn_f = .1,
  kn_t = 0,
  kn_r = 0,
  des = v2(),
  d_f = 0,
  m_fn = "nope",
  msfx = 49,
  e_fn = "smk",
  esfx = 34
 },
 -- granadeer
 {
  id = 8,
  spr_i = 50,
  dmg = v2(4, 6),
  mag = 5,
  bu = 1,
  co = 0.025,
  r_ti = 120,
  w_cd = 60,
  proj_fn = "projg",
  fo = v2(1.2, 1.3),
  v_m = .08,
  kn_f = 1.4,
  kn_t = 30,
  kn_r = 324,
  des = v2(4, 6),
  d_f = .75,
  m_fn = "fls2",
  msfx = 1,
  e_fn = "gre",
  esfx = 35
 },
 -- -- orber
 {
  id = 9,
  spr_i = 55,
  dmg = v2(8, 9),
  mag = 1,
  bu = 1,
  co = .01,
  r_ti = 60,
  w_cd = 0,
  proj_fn = "projo",
  fo = v2(.5, .6),
  v_m = 0,
  kn_f = 1,
  kn_t = 12,
  kn_r = 50,
  des = v2(3, 4),
  d_f = .8,
  m_fn = "scir",
  msfx = 50,
  e_fn = "orbr",
  esfx = 50
 },
 -- molter
 {
  id = 10,
  spr_i = 60,
  dmg = v2(2.5, 3),
  mag = 3,
  bu = 3,
  co = .03,
  r_ti = 75,
  w_cd = 30,
  proj_fn = "projm",
  fo = v2(.8, 1),
  v_m = .02,
  kn_f = .7,
  kn_t = 18,
  kn_r = 256,
  des = v2(3, 5),
  d_f = .7,
  m_fn = "fls1",
  msfx = 51,
  e_fn = "molt",
  esfx = 52
 },
 -- lazer
 {
  id = 11,
  spr_i = 106,
  dmg = v2(1.2, 2.2),
  mag = 1,
  bu = 1,
  co = .02,
  r_ti = 0,
  w_cd = 0,
  proj_fn = "rlproj",
  fo = v2(.8, 1),
  v_m = 0,
  kn_f = 0.3,
  kn_t = 6,
  kn_r = 8,
  des = v2(2, 4),
  d_f = 1,
  m_fn = "scir",
  msfx = 46,
  e_fn = "rfls",
  esfx = 47
 }
}

-- object type enums
-- ot = {
--   soldier = 1, -- 2^0 = 1
--   hp_box = 2, -- 2^1 = 2
--   wp_box = 4, -- 2^2 = 4
--   barrel = 8, -- 2^3 = 8
--   mine = 16, -- 2^4 = 16
--   squid = 32, -- 2^5 = 32
--   gate = 64,
--   proj = 128
-- },

game_objects = {
 -- 1 - soldier
 {
  type = 1,
  so = 60,
  a_id = 5,
  si = v2(3, 6),
  off = v2(-1, -3),
  hp = 10,
  lhp = 3,
  ulhp = 1.5,
  cli = true,
  suf = "blood_fx",
  ow = 0,
  te = 0,
  spd = v2(),
  acc = v2(),
  air = 0
 },

 -- 2 - hp box
 {
  type = 2,
  so = 6,
  a_id = 2,
  si = v2(5, 5),
  off = v2(-2, -2),
  hp = 6,
  lhp = 2,
  ulhp = 1,
  cli = false,
  suf = "smk",
  ow = 0,
  te = 0,
  spd = v2(),
  acc = v2(),
  air = 0
 },

 -- 3 - weapon box
 {
  type = 4,
  so = 6,
  a_id = 1,
  si = v2(5, 5),
  off = v2(-2, -2),
  hp = 8,
  lhp = 3,
  ulhp = 1.5,
  cli = false,
  suf = "ssmk",
  ow = 0,
  te = 0,
  spd = v2(),
  acc = v2(),
  air = 0
 },

 -- 4 - barrel
 {
  type = 8,
  so = 6,
  a_id = 3,
  si = v2(4, 5),
  off = v2(-1, -2),
  hp = 9,
  lhp = 4,
  ulhp = 2,
  cli = false,
  suf = "acid_fx",
  ow = 0,
  te = 0,
  spd = v2(),
  acc = v2(),
  air = 0
 },

 -- 5 - mine
 {
  type = 16,
  so = 6,
  a_id = 4,
  si = v2(3, 2),
  off = v2(-1, -1),
  hp = 20,
  lhp = 7,
  ulhp = 3,
  cli = false,
  suf = "smk",
  ow = 0,
  te = 0,
  spd = v2(),
  acc = v2(),
  air = 0
 },

 -- 6 - techno squid
 {
  type = 32,
  so = 7,
  a_id = 6,
  si = v2(5, 5),
  off = v2(-2, -2),
  hp = 4,
  lhp = 5,
  ulhp = 3,
  cli = false,
  suf = "ssmk",
  ow = 0,
  te = 0,
  spd = v2(),
  acc = v2(),
  air = 0
 }
}

menu_objects = {
 {
  id = 1,
  items = { "mode", "war", "arena", "chaos", "time", "3", "6", "9", "boxes", "few", "more", "lots", "traps", "none", "few", "more", "bots", "lame", "tough", "boss", "enter the wastelands" },
  pos = v2(14, 59),
  col_w = 27,
  rows = { 4, 4, 4, 4, 4, 1 },
  idxs = { 2, 2, 2, 2, 2, 1 },
  idx = 1
 },
 {
  id = 2,
  items = { "density", "low", "cozy", "stuffed", "shape", "cave", "canyon", "island", "fabric", "earth", "void", "ruins", "terraform", "enter the battle", "back to base" },
  pos = v2(4, 59),
  col_w = 30,
  rows = { 4, 4, 4, 1, 1, 1 },
  idxs = { 2, 2, 2, 1, 1, 1 },
  idx = 1
 }
}

-- spawners
spawners = {
 -- box spawner
 {
  id = 3,
  filter = 6,
  no = 2,
  mult = false,
  fxs = { "ssq", "ssq" },
  f_s = { 2, 2 },
  fns = { "hp_box", "w_box" },
  cols = { 8, 6, 3, 4 }
 },
 -- trap spawner
 {
  id = 4,
  filter = 24,
  no = 2,
  mult = false,
  fxs = { "ssq", "ssq" },
  f_s = { 2, 1 },
  fns = { "barrel", "mine" },
  cols = { 0, 11, 2, 5 }
 },
 -- enemy spawner
 {
  id = 5,
  filter = 32,
  no = 1,
  mult = true,
  fxs = { "sci" },
  f_s = { 2 },
  fns = { "enemy" },
  cols = { 0, 8 }
 }
}

_data = {
 a_f = "11;frames,1;spd",
 a_d = "1,6|2,6|3,6|4,6|5,6|6,6|7,6|8,6|9,6|10,6|10#11,6|12#13,6|12,6|65,6|66,6|67,6|79,4|68,4|69,6|70,6|66#71#72#73,6|66#74#75#75#75,5|66#72#76#76#76,5|66#68#69#70#77#78#79,6|66#79#78#77#70#69#68,6|70#69#73#66,3|84#85#85#85,5|66#65#86#86#86,5|65#88#87#87#87,5|66#89#90#90#90,5|67#91#92#92#92,5|95,6|102,6|103,6|104,12|100,12|95#96#98#97#97#97#97#97,8|95#96#94#101#101#101,6|95#98#94#93#104#104,5|95#98#100#99#105#105,5",
 spf = "3;size,3;spos,13;pts",
 spd = "5:5,118:0,2:2#0:0#0:0#4:4|5:5,123:0,2:2#0:0#0:0#4:4|5:5,118:5,2:2#0:0#0:0#4:4|5:5,123:5,2:2#0:0#0:0#4:4|5:5,118:10,2:2#0:0#0:0#4:4|5:5,123:10,2:2#0:0#0:0#4:4|4:5,118:15,1:2#0:0#0:0#3:4|4:5,122:15,1:2#0:0#0:0#3:4|4:5,118:20,1:2#0:0#0:0#3:4|3:2,122:20,1:1#0:0#0:0#2:1|3:2,125:20,1:1#0:0#0:0#2:1|3:2,122:22,1:1#0:0#0:0#2:1|3:2,125:22,1:1#0:0#0:0#2:1|104:28,0:0,0:0|13:7,0:28,6:0|2:3,125:28,1:2#0:0|3:4,125:31,0:3#2:0|3:2,125:35,0:1#2:0|4:3,124:37,1:1#3:2|13:7,13:28,6:0|3:3,119:43,2:2#0:0|3:3,122:43,0:2#2:0|3:1,125:43,0:0#2:0|3:3,125:44,0:0#2:2|13:7,26:28,6:0|2:6,13:35,1:4#1:0|6:6,15:35,2:4#4:1|6:2,21:35,1:1#5:1|6:5,21:37,1:2#4:3|13:7,39:28,6:0|2:6,27:35,1:4#0:0|5:5,29:35,2:4#4:0|6:2,35:35,1:1#5:0|6:5,35:37,1:1#5:4|13:7,52:28,6:0|3:7,41:35,2:5#1:0|6:7,44:35,1:5#5:0|7:3,50:35,1:2#6:1|6:6,50:38,1:2#5:5|13:7,65:28,6:0|3:7,57:35,2:2#1:0|6:6,60:35,4:3#5:0|7:3,66:35,4:2#6:1|6:6,66:38,3:4#5:5|13:7,78:28,6:0|3:6,73:35,1:5#0:0|4:5,76:35,0:4#3:0|6:3,80:35,0:1#5:0|5:4,80:38,0:0#4:3|13:7,91:28,6:0|3:6,86:35,1:4#0:0|6:5,89:35,1:4#4:0|6:3,95:35,1:1#5:0|6:5,95:38,1:1#5:3|13:7,104:28,6:0|5:7,101:35,3:6#2:2|6:7,106:35,0:6#3:2|7:5,112:35,0:3#4:2|8:6,111:41,0:1#5:3|13:7,0:35,6:0|3:6,117:28,1:4#1:0|5:5,120:28,1:3#3:1|6:3,119:34,1:1#5:1|5:6,119:37,1:1#4:4|5:6,3:54,1:3#4:1#0:0#2:5|4:6,0:48,1:3#3:2#0:0#2:5|3:6,0:54,1:3#2:3#0:0#2:5|6:5,16:42,2:2#5:2#1:0#4:4|7:3,16:47,3:1#6:2#0:0#5:2|6:6,22:42,2:3#5:5#0:1#4:5|4:6,4:48,1:3#3:2#0:0#2:5|4:6,8:47,1:3#3:2#0:0#2:5|4:5,12:46,1:2#3:2#0:0#2:4|4:6,15:51,1:3#3:2#1:0#3:5|6:6,19:50,0:3#5:2#0:0#3:5|7:6,8:53,0:3#2:2#0:0#3:5|5:5,11:41,2:2#2:2#1:0#3:4|5:6,0:42,2:3#2:3#0:1#3:5|6:5,5:42,2:2#3:2#0:0#3:4|14:8,104:0,13:0|14:8,104:8,0:0|14:8,104:16,13:0|14:8,114:47,0:0|4:6,25:53,1:3#3:2#0:0#3:5|7:5,25:48,2:2#3:2#0:0#3:4|6:6,28:41,0:3#5:0#0:0#3:5|4:8,34:42,0:5#2:0#0:2#3:7|5:6,38:42,1:3#4:1#1:0#3:5|4:6,43:42,1:3#3:2#1:0#3:5|5:6,47:43,1:3#4:4#1:1#4:5|4:6,32:50,1:3#2:3#0:1#3:5|4:6,36:50,1:2#2:5#0:1#3:4|8:9,63:44,2:4#1:5#0:1#6:8|5:13,71:44,2:6#4:6#0:1#4:11|8:9,76:43,5:4#6:4#2:1#7:7|6:11,84:43,3:5#5:5#0:1#5:9|10:7,90:43,7:3#8:3#3:0#9:6|6:10,100:43,3:4#4:4#0:1#5:8|8:9,106:44,5:6#6:7#0:3#7:8|9:9,63:53,6:5#6:5#1:3#8:8|11:9,76:54,2:4#3:3#0:1#7:7|8:9,87:54,5:4#6:3#1:1#7:7|8:8,95:53,5:2#5:1#1:0#7:6|9:9,103:53,2:5#2:4#0:2#8:8|10:9,112:55,7:6#8:7#2:3#9:8|0:0,1:1,0:0#0:0|0:0,1:1,0:0#0:0|0:0,1:1,0:0#0:0|0:0,1:1,0:0#0:0|0:0,1:1,0:0#0:0"
}

function build_record_data(name, data)
 local f, d = encode_records(data)
 _data[name .. "f"] = f
 _data[name .. "d"] = d
 print("r format:" .. f)
 print("r data:" .. d)
end

function build_table_data(name, data)
 local anim_groups = "groups#5#1;1@2@3,2;4@5@6,3;7@8@9,4;10@11@12@13,5;15@14@16@17@18@19@20@21@22@23@24@25@26@27@28@29@30@31,6;32@33@34@35@36@37@38@39@40"
 local d = join({ encode_tables(data), anim_groups }, "|")
 _data[name .. "d"] = d
 print("t data:" .. d)
end

for record in all({
 { name = "sw", data = spawners },
 { name = "go", data = game_objects },
 { name = "pl", data = players },
 { name = "wp", data = weapons },
 { name = "me", data = menu_objects },
 { name = "pa", data = particles },
 { name = "fx", data = effects },
 { name = "ai", data = aims }
}) do
 print("building " .. record.name)
 build_record_data(record.name, record.data)
end

build_table_data("tb", lookup_tables)

-- persist map[0x1000 .. 0x1000+total_bytes-1] into the cartridge’s map section
-- map RAM begins at 0x1000, cart map rom begins at 0x1000
local total_bytes, total_records = encode_kv(_data), 0

print("total bytes: " .. total_bytes)

-- if total_bytes is grater than 8Kb exit with an error
if total_bytes > 8192 then
 print("data too large! max 8Kb")
 return
end

cstore(0x1000, 0x1000, 8192, "game.p8")

for k, v in pairs(_data) do
 total_records += 1
end
print("encoded " .. total_records .. " entries, " .. total_bytes .. " bytes")
color(11)
print("remaining bytes: " .. 8192 - total_bytes)
print("data encoded successfully")
