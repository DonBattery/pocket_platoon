pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- utility
_g = _ENV
function env(o)
 return setmetatable(o, { __index = _ENV })
end

function nope() end

function rand(l, h) return rnd(abs(h - l)) + min(l, h) end

function randint(l, h) return flr(rnd(abs(h + 1 - l))) + min(l, h) end

function pprint(s, x, y, c1, c2, ind, out)
 x -= ind == "r" and print(s, 0, 128) or ind == "c" and print(s, 0, 128) / 2 or 0
 if out then
  for ox = -1, 1 do
   for oy = -1, 1 do
    print(s, x + ox, y + oy, c2)
   end
  end
 else
  print(s, x, y + 1, c2)
 end
 print(s, x, y, c1)
end

function sort(t, cond)
 for i, ti in inext, t do
  for j, tj in inext, t do
   if cond(ti, tj) then
    ti, t[i], t[j] = tj, tj, ti
   end
  end
 end
end

function pal_spec(v)
 for i = 0, 15 do
  pal(i, v)
 end
end

function ppal()
 pal()
 palt(0b0000000000000010)
end

-- 2d vector
v2 = {}
v2.__index = v2
setmetatable(
 v2, {
  __call = function(cls, x, y)
   return setmetatable({ x = x or 0, y = y or 0 }, cls)
  end
 }
)
function v2:__add(o) return v2(self.x + o.x, self.y + o.y) end
function v2:__sub(o) return v2(self.x - o.x, self.y - o.y) end
function v2:__mul(s) return v2(self.x * s, self.y * s) end
function v2:__div(s) return v2(self.x / s, self.y / s) end
function v2:__len() return sqrt(self.x ^ 2 + self.y ^ 2) end
function v2:norm() local l = #self return l > 0 and self / l or v2() end
function v2:sqrdist(o) return (o.x - self.x) ^ 2 + (o.y - self.y) ^ 2 end
function v2:limit(l) self.x, self.y = mid(-l, self.x, l), mid(-l, self.y, l) end
function v2:rot(a) local c, s = cos(a), sin(a) return v2(self.x * c - self.y * s, self.x * s + self.y * c) end
function v2:ab() return rand(self.x, self.y) end

function p_coll(p, r)
 return not (p.x < flr(r.pos.x) or flr(p.x) > r.pos.x + r.size.x - 1 or p.y < flr(r.pos.y) or flr(p.y) > r.pos.y + r.size.y - 1)
end

function r_coll(a, b)
 return not (a.pos.x + a.size.x - 1 < flr(b.pos.x) or flr(a.pos.x) > b.pos.x + b.size.x - 1 or a.pos.y + a.size.y - 1 < flr(b.pos.y) or flr(a.pos.y) > b.pos.y + b.size.y - 1)
end

function ray(p1, p2)
 local pts, x1, y1, x2, y2 = {}, flr(p1.x), flr(p1.y), flr(p2.x), flr(p2.y)
 local dx, dy, sx, sy = abs(x2 - x1), abs(y2 - y1), x1 < x2 and 1 or -1, y1 < y2 and 1 or -1
 local err = dx - dy
 while true do
  add(pts, v2(x1, y1))
  if x1 == x2 and y1 == y2 then break end
  local e2 = 2 * err
  if e2 > -dy then
   err, x1 = err - dy, x1 + sx
  end
  if e2 < dx then
   err, y1 = err + dx, y1 + sy
  end
 end
 return pts
end

-- control
function joy(pid)
 local j = env({
  upd = function(_ENV)
   local _l, _r, _u, _d = l:upd(), r:upd(), u:upd(), d:upd()
   x:upd()
   o:upd()
   dir = ((_u and not _d and "n") or (_d and not _u and "s") or "") .. ((_l and not _r and "w") or (_r and not _l and "e") or "")
  end
 })
 for i, b in ipairs(split("l,r,u,d,o,x")) do
  j[b] = env({
   _p = pid,
   _b = i - 1,
   upd = function(_ENV)
    down = btn(_b, _p)
    press = down and not prev
    prev = down
    return down
   end
  })
 end
 return j
end

-- data decoders
function conv(et, e)
 return et < 3 and e or et == 5 and split(e, "@") or et == 3 and v2(unpack(split(e, ":"))) or e == 1
end

function use_data(fs, ds, cb, i)
 local fi, rs = {}, split(ds, "|")
 for f in all(split(fs)) do
  add(fi, split(f, ";"))
 end
 local function rec(r)
  local o, ts = {}, split(r)
  for i, f in pairs(fi) do
   local t, k = unpack(f)
   if t < 10 then
    o[k] = conv(t, ts[i])
   else
    o[k] = {}
    for e in all(split(ts[i], "#")) do
     add(o[k], conv(t % 10, e))
    end
   end
  end
  return cb(o)
 end
 if i then
  return rec(rs[i])
 end
 local o = {}
 for r in all(rs) do
  add(o, rec(r))
 end
 return o
end

-- constructors
function menu_c(o)
 o.draw = function(_ENV)
  for p in all(players) do
   if p.conn then
    local j = p.joy
    idx = mid(1, idx + (j.u.press and -1 or 0) + (j.d.press and 1 or 0), #idxs)
    idxs[idx] = mid(rows[idx] > 1 and 2 or 1, idxs[idx] + (j.l.press and -1 or 0) + (j.r.press and 1 or 0), rows[idx])
    if j.u.press or j.d.press then
     sfx(29)
    end
    if j.l.press or j.r.press then
     sfx(30)
    end
    if (not cd.menu and (j.x.press or j.o.press)) submit(id)
   end
  end
  local off, c, r = v2(pos.x, pos.y), 1, 1
  for item in all(items) do
   pprint(item, off.x - (idx == r and 1 or 0), off.y, c == 1 and (idx == r and 11 or 3) or (idx == r and (c == idxs[r] and 10 or 5)) or (c == idxs[r] and 6 or 5), 0, "l", true)
   if c < rows[r] then
    off.x += col_w
    c += 1
   else
    off.x, c = pos.x, 1
    off.y += 8
    r += 1
   end
  end
 end
 o.get = function(_ENV, id) return idxs[id] - 1 end
 return env(o)
end

function sprite_c(o)
 o.flip = {}
 o.get_p = function(_ENV, pos, i, f_x, f_y)
  local base, base_flip = pts[1], flip[1]
  local orig = v2(pos.x - (f_x and base_flip.x or base.x), pos.y - (f_y and base_flip.y or base.y))
  if not i or i == 1 then return orig end
  local pt, pt_flip = pts[i], flip[i]
  return v2(orig.x + (f_x and pt_flip.x or pt.x), orig.y + (f_y and pt_flip.y or pt.y))
 end
 o.draw = function(_ENV, pos, f_x, f_y)
  local orig = get_p(_ENV, pos, 1, f_x, f_y)
  sspr(spos.x, spos.y, size.x, size.y, orig.x, orig.y, size.x, size.y, f_x, f_y)
 end
 for p in all(o.pts) do
  add(o.flip, (o.size - v2(1, 1)) - p)
 end
 return env(o)
end

function new_anim(group_id)
 local a = env({
  gid = group_id,
  f_x = false,
  f_y = false,
  upd = function(_ENV)
   if runs then
    ti, eof = (ti + 1) % spd
    if ti == 0 then
     fid = (fid % len) + 1
     if fid == 1 and fo then
      eof, fo, runs = true
     end
    end
   end
  end,
  play = function(_ENV, anim_id, forced)
   if aid == anim_id or (fo and not forced) then return end
   anim, aid, fid, fo, runs, ti = anims[groups[gid][anim_id]], anim_id, 1, forced, true, 0
   len, spd = #anim.frames, anim.spd
  end,
  draw = function(_ENV, pos)
   sprites[anim.frames[fid]]:draw(pos, f_x, f_y)
  end,
  get_p = function(_ENV, pos, i)
   return sprites[anim.frames[fid]]:get_p(pos, i or 2, f_x, f_y)
  end,
  get_hb = function(_ENV, pos)
   local p_a, p_b = get_p(_ENV, pos, 3), get_p(_ENV, pos, 4)
   return {
    pos = v2(min(p_a.x, p_b.x), min(p_a.y, p_b.y)),
    size = v2(abs(p_a.x - p_b.x) + 1, abs(p_a.y - p_b.y) + 1)
   }
  end
 })
 a:play(1)
 return a
end

function player_c(o)
 o.joy = joy(o.id - 1)

 o.upd = function(_ENV)
  joy:upd()
  if not conn then
   if (joy.o.press or joy.x.press) and not cd.menu then
    sfx(28)
    conn, cd.menu = true, 10
   end
  else
   if state == 3 then
    if spwn > 0 then
     spwn -= 1
     msg = flr(spwn / 60) + 1
     if spwn == 60 then
      local s = w_spot()
      spawn_fx(s, "sci", 2, { 7, c1, c2 })
      schedule(
       56, function()
        soldier = sold(_ENV, s)
        w_add(soldier)
       end
      )
     end
    elseif not soldier then
     spwn = 180
    end
   end
  end
 end

 o.draw = function(_ENV)
  if not conn or spwn > 0 then
   pprint(msgs[msg], msg_x, msg_y, c1, 0, ind)
  end
  if conn then
   local c = c3
   if soldier then
    c = soldier.hp < soldier.ulhp and 2 or soldier.hp < soldier.lhp and 8 or c3
    -- hp bar
    rectfill(hp_x1, hp_y1, hp_x2, hp_y2, 8)
    rectfill(hp_x1, hp_y1, hp_x1 + (max((soldier.hp - 1), 0) * bar_d), hp_y2, 10)

    -- corner pixels for rounded look
    pset(hp_x1, hp_y1, 0)
    pset(hp_x1, hp_y2, 0)
    pset(hp_x2, hp_y1, 0)
    pset(hp_x2, hp_y2, 0)

    local w = soldier.we
    -- ammo bar or reload progress
    if soldier.mag > 0 then
     line(ammo_x, ammo_y, ammo_x + max(0, (flr((soldier.mag / w.mag) * 7) - 1)) * bar_d, ammo_y, 7)
    elseif soldier.cd.reload then
     line(ammo_x, ammo_y, ammo_x + (7 - flr((soldier.cd.reload / w.r_ti) * 7)) * bar_d, ammo_y, 12)
    end

    -- weapon portrait sprite
    w:draw_p(w_pos, l)

    -- score
    pprint(scr, scr_x, scr_y, c1, 0, ind)
   end
   if spwn == 0 then
    pal(1, c)
    sprites[spr_i]:draw(pos)
    ppal()
   end
  end
 end

 return env(o)
end

-- acquire target
function acq_tar(_ENV, r, filter, owner)
 tars = w_get(_ENV, r, filter)
 for tar in all(tars) do
  if (tar._ow == owner) del(tars, tar)
 end
 if #tars > 0 then
  sort(tars, function(a, b) return a.pos:sqrdist(pos) < b.pos:sqrdist(pos) end)
  return tars[1]
 end
end

function upd_proj(_ENV)
 local objs, pts, w_i, hit_obj, hit_ground, prev = w_get(_ENV, 64, 0), ray(pos, n_pos), we.id

 if w_i == 6 then
  if rnd() < .2 then smkc(pos) end
  if not tar then
   tar = acq_tar(_ENV, 400, menus[1]:get(1) == 1 and 32 or 33, ow)
   if tar then
    sfx(32)
    ssq2(tar.pos)
   end
  else
   if tar.rem then
    tar = nil
   else
    local d = tar.pos - pos
    acc.x = d.x < 0 and -0.1 or d.x > 0 and 0.1 or 0
    acc.y = d.y < 0 and -0.1 or d.y > 0 and 0.1 or 0
    spd:limit(.65)
   end
  end
 end

 for i = 1, #pts do
  p = pts[i]

  for o in all(objs) do
   if p_coll(p, o:get_hb()) and (life > 16 or o._ow ~= ow) then
    hit_obj = o
    break
   end
  end

  if not hit_obj then
   local nc = get_px(p.x, p.y)
   if (nc ~= 1 and nc ~= 17) and (w_i ~= 7 or rnd() < .3) then
    life += 10
    prev = i > 1 and pts[i - 1] or p
    if w_i == 8 then
     local d = p - prev
     if d.x ~= 0 then
      if d.y ~= 0 then
       if get_px(p.x + (d.x < 0 and 1 or -1), p.y) == 1 then
        spd.x *= -.9
       elseif get_px(p.x, p.y + (d.y < 0 and 1 or -1)) == 1 then
        spd.y *= -.9
       else
        spd = (spd * -.9):rot(rand(-.01, .01))
       end
      else
       spd.x *= -.9
      end
     else
      spd.y *= -.9
     end
     sfx(53)
     dus(p, 1, spd, v2(.05, .1))
     n_pos = prev
    else
     hit_ground = p
     if w_i == 2 then
      set_px(p.x, p.y, 7)
      set_px(prev.x, prev.y, 4)
     end
     if w_i == 10 then
      spd, acc = v2(), v2()
     end
     break
    end
   end
  end
 end

 if hit_obj or (hit_ground and w_i ~= 10) or (eol and (w_i == 8 or w_i == 10)) then
  eol = not (w_i == 9 and hit_ground)
  if w_i == 7 and hit_ground then
   set_px(hit_ground.x, hit_ground.y, rnd() < .25 and 1 or 0)
  end
  impactor(hit_obj, hit_ground or p, spd, we.kn_f, we.kn_r, we.kn_t, 1.1, we.dmg, ow, te, we.e_fn, we.esfx, randint(we.des.x, we.des.y), we.d_f)
 end
end

function weapon_c(o)
 o.shoot = function(_ENV, pos, aim, ow, te, l)
  sfx(msfx)
  local m_pos = pos
  if type(aim) == "string" then
   m_pos = get_m_pos(_ENV, pos, aim, l)
   aim = aims[aim].v2_mod + v2(0, (aim == "e" or aim == "w") and -v_m or 0)
  end
  _g[m_fn](m_pos)
  _g[proj_fn](m_pos, bu, aim, fo, 0, co, nil, nil, upd_proj, ow, te, _ENV)
  return w_cd
 end

 o.get_m_pos = function(_ENV, pos, aim, l)
  return sprites[1 + spr_i + aims[aim].sp_i]:get_p(pos, 2, aim == "n" and l or aim == "s" and not l or aims[aim].f_x, aims[aim].f_y)
 end

 o.draw = function(_ENV, pos, aim, l)
  sprites[1 + spr_i + aims[aim].sp_i]:draw(pos, aim == "n" and l or aim == "s" and not l or aims[aim].f_x, aims[aim].f_y)
 end

 o.draw_p = function(_ENV, pos, l)
  sprites[spr_i]:draw(pos, l)
 end

 return env(o)
end

function upd_spwn()
 local spwn = spwns[spwn_i]
 local max_obj = obj_nums[spwn_i][menus[1]:get(spwn.id)] * (spwn.mult and menus[1]:get(1) == 1 and 1.5 or 1)
 if #w_get(nil, 0, spwn.filter) < max_obj and rnd() < .25 then
  local spot, i = w_spot(), randint(1, spwn.no * 2 - 1) \ 2 + 1
  spawn_fx(spot, spwn.fxs[i], spwn.f_s[i], { spwn.cols[(i - 1) * 2 + 1], spwn.cols[(i - 1) * 2 + 2] })
  schedule(
   50, function()
    w_add(_g[spwn.fns[i]](spot))
   end
  )
 end
 spwn_i = (spwn_i % (menus[1]:get(1) == 2 and 2 or 3)) + 1
 schedule(randint(20, 30), upd_spwn)
end

function upd_countdown()
 countdown -= 1
 if countdown == 10 then sfx(57) end
 if countdown == 0 then
  sfx(58)
  state = 4
  cd.menu = 180
  for o in all(w_get(nil, 0, 1)) do
   players[o._ow].soldier = nil
   o.rem = true
  end
 end
 schedule(60, upd_countdown)
end

-- map
function get_px(x, y)
 if x < 0 or x >= 128 or y < 8 then return 17 end
 if y >= 120 then return 16 end
 x, y = flr(x), flr(y)
 local v = @(0x8000 + _y[y] + flr(x / 2))
 if x % 2 == 0 then
  return v & 0x0f
 end
 return (v >> 4) & 0x0f
end

function set_px(x, y, c)
 if x < 0 or x >= 128 or y < 8 or y >= 120 then return end
 x, y = flr(x), flr(y)
 local addr = 0x8000 + _y[y] + flr(x / 2)
 local v = @addr
 if x % 2 == 0 then
  v = (v & 0xf0) | (c & 0x0f)
 else
  v = (v & 0x0f) | ((c & 0x0f) << 4)
 end
 poke(addr, v)
end

function free(p, s)
 for x = p.x, p.x + s.x - 1 do
  for y = p.y, p.y + s.y - 1 do
   if (get_px(x, y) ~= 1) return false
  end
 end
 return true
end

function gen_map()
 pprint("chaos emerges,", 24, 26, 11, 0, "l", true)
 pprint("last war approaches", 28, 35, 11, 0, "l", true)
 hud()
 flip()
 local m = menus[2]
 local den, sha, fab = .465 + m:get(1) * .015, m:get(2), m:get(3)
 w_str, map_done, bg_col, b_col, hi_col, dmg_col = fab * .2, true, unpack(map_cols[(fab - 1) * 3 + randint(1, 3)])
 local map, tmp = {}, {}
 for x = 0, 131 do
  map[x], tmp[x] = {}, {}
  for y = 0, 115 do
   map[x][y] = ((x < 2 and sha == 1 or x > 129 and sha == 1 or y < 2 and sha < 3 or y > 112 or rnd() < den) and 1 or 0)
   tmp[x][y] = map[x][y]
  end
 end
 for _ = 1, 3 do
  for x = 2, 129 do
   for y = 2, 113 do
    local n = 0
    for dx = -2, 2 do
     for dy = -2, 2 do
      n += (dx ~= 0 or dy ~= 0) and map[x + dx][y + dy] or 0
     end
    end
    tmp[x][y] = n > 12 and 1 or 0
   end
  end
  map, tmp = tmp, map
 end
 for y = 0, 111 do
  for x = 0, 126, 2 do
   local col = { 1, 1 }
   for p = 0, 1 do
    if map[x + p + 2][y + 2] == 1 then
     local ch = .13
     for off = 1, 3 do
      if y > 2 and map[x + p + 2][y + 2 - off] == 0 then
       ch += (.58 / (off + 1))
      end
     end
     col[p + 1] = rnd() < ch and hi_col or b_col
    end
   end
   poke(0x8000 + _y[y + 8] + (x >> 1), (col[2] << 4) | col[1])
  end
 end
end

function destruct(pos, dir, l)
 for i = 1, #l do
  local s, str = l[i][1], l[i][2]
  if s % 2 == 0 then pos += v2(randint(-1, 1), randint(-1, 1)) end
  local m, ps = str - w_str, 0
  for p in all(dests[s]) do
   local x, y = pos.x + p.x, pos.y + p.y
   local c, r = get_px(x, y), 1
   if c ~= 1 and c < 16 then
    if rnd() > m + (c == dmg_col and .3 or 0) then
     r = dmg_col
    end
    if ((c ~= dmg_col) or (r == 1)) and rnd() < (ps < 7 and 1 or 1 - (ps - 7) / 20) then
     ps += 1
     drt(v2(x, y), 1, dir * (rnd() < .25 and -1 or 1), v2(.2, .7), 0, 0, nil, { c })
    end
    set_px(x, y, r)
   end
  end
 end
end

function drama()
 drama_v += 6
 drama_t = 0
 if drama_v >= 7 then
  drama_v = 3
  cd.shake = 12
 end
end

-- game objects
function gob(id, p, _on_imp, _on_upd, _on_b_draw, _on_a_draw, _on_die, _on_land)
 return use_data(
  gof, god, function(o)
   o.pos = p
   o.l = rnd() < .5
   o.on_imp = _on_imp
   o.on_suf = _g[o.suf]
   o.on_upd = _on_upd
   o.on_b_draw = _on_b_draw
   o.on_a_draw = _on_a_draw
   o.on_die = _on_die
   o.on_land = _on_land
   o.anim = new_anim(o.a_id)
   o.anim.f_x = o.l
   o.cd = {
    hit = 12
   }

   o.get_hb = function(_ENV) return anim:get_hb(pos) end

   o.upd = function(_ENV)
    if rem then return true end

    anim:upd()

    for k, v in pairs(cd) do
     cd[k] = v > 0 and v - 1 or nil
    end

    if (hp < lhp and rnd() < .01) on_suf(pos, hp < ulhp and 2 or 1, spd, v2(.3, .6))
    if free(v2(pos.x + off.x, pos.y + off.y + si.y), v2(si.x, 1)) then
     air += 1
     ground = false
    else
     -- on land
     if not ground then
      if air > 15 and spd.y > .45 then
       sfx(53)
       dus(pos + v2(0, 2), randint(1, 2), spd, v2(.05, .1))
       if (on_land) on_land(_ENV)
      end
     end
     air, ground = 0, true
    end

    if not cd.f_move then
     if ground then
      gra, fri, slim = 0, .96, .45
     else
      gra, fri, slim = .06, .98, .85
     end
    end
    spd += on_upd(_ENV)
    spd:limit(slim)
    spd *= fri or 1
    if (abs(spd.x) < 0.005) spd.x = 0
    if (abs(spd.y) < 0.005) spd.y = 0
    local n_pos = pos + spd
    local pts = ray(pos, n_pos)
    local l = #pts
    if l > 1 then
     for i = 2, l do
      local prev = pts[i - 1]
      local can, block, res = step(_ENV, prev, pts[i] - prev)
      if not can then
       spd.x *= (not cli and block.x == 0) and -.8 or block.x
       spd.y *= (not cli and block.y == 0) and -.75 or block.y
       n_pos = (res and res or prev) + v2(.5, .5)
       break
      end
     end
    end
    pos = n_pos
   end

   o.step = function(_ENV, pos, dir)
    if not cango(_ENV, pos, dir) then
     if dir.x ~= 0 then
      if dir.y ~= 0 then
       if cango(_ENV, pos, v2(dir.x, 0)) then
        return false, v2(.75, 0), pos + v2(dir.x, 0)
       elseif cango(_ENV, pos, v2(0, dir.y)) then
        return false, v2(0, .75), pos + v2(0, dir.y)
       end
      else
       if cango(_ENV, pos, v2(dir.x, -1)) then
        return false, v2(.75, 1), pos + v2(dir.x, -1)
       elseif cli and cango(_ENV, pos, v2(dir.x, -2)) then
        return false, v2(.3, .75), pos + v2(dir.x, -2)
       elseif cango(_ENV, pos, v2(dir.x, 1)) then
        return false, v2(.75, .75), pos + v2(dir.x, 1)
       end
      end
     elseif dir.y < 0 then
      if (cango(_ENV, pos, v2(l and -1 or 1, -1))) return false, v2(.5, .75), pos + v2(l and -1 or 1, -1)
     else
      return false, v2(1, 0)
     end
     return false, v2()
    end
    return true
   end

   o.cango = function(_ENV, pos, dir)
    if (dir.x ~= 0 and not free(pos + off + (dir.x < 0 and v2(-1, dir.y) or v2(si.x, dir.y)), v2(1, si.y))) return false
    if (dir.y ~= 0 and not free(pos + off + (dir.y < 0 and v2(dir.x, dir.y) or v2(dir.x, si.y)), v2(si.x + abs(dir.y) - 1, abs(dir.y)))) return false
    return true
   end

   o.imp = function(_ENV, ow, te, fo, dmg, ti, limit)
    if rem then return end
    spd += fo
    cd.f_move, slim = ti, limit
    hp -= on_imp(_ENV, ow, te, fo, dmg)
    if hp <= 0 then
     rem = true
     drama()
     on_die(_ENV, ow, te, fo)
    end
   end

   o.draw = function(_ENV)
    if on_b_draw then on_b_draw(_ENV) end
    anim:draw(pos)
    if on_a_draw then on_a_draw(_ENV) end
    ppal()
   end

   return env(o)
  end, id
 )
end

function impactor(obj, pos, dir, fo, r, ti, lim, dmg, ow, te, fx_fn, sfx_i, des_s, des_f)
 sfx(sfx_i)
 _g[fx_fn](pos, 1, dir, v2(fo, fo))
 local d = { { des_s, des_f } }
 if des_s > 2 then add(d, { des_s - 2, des_f * 1.5 }) end
 destruct(pos, dir, d)
 if obj then
  obj:imp(ow, te, dir:norm() * fo, dmg:ab(), ti, lim)
 elseif r > 0 then
  for o in all(w_get({ pos = pos }, r, 0)) do
   local str = 1 - pos:sqrdist(o.pos) / r
   local f = (o.pos - pos):norm() * str * fo
   o:imp(ow, te, f, dmg:ab() * str, ti * str, lim)
  end
 end
end

function get_hit(_ENV)
 if cd.hit then pal_spec(hp > lhp and 7 or hp > ulhp and 10 or 8) end
end

function box(id, p, on_b_upd, on_con, filter, on_die)
 return gob(
  id, p,
  function(_ENV, ow, te, fo, dmg)
   cd.hit = dmg
   on_suf(pos, ceil(dmg), fo, v2(.3, .6))
   return dmg
  end,
  function(_ENV)
   if on_b_upd then on_b_upd(_ENV) end
   local hb = get_hb(_ENV)
   for o in all(w_get(_ENV, 64, filter)) do
    if not rem and r_coll(o:get_hb(), hb) then
     on_con(_ENV, o)
     break
    end
   end
   anim:play(hp < ulhp and 3 or hp < lhp and 2 or 1)
   return v2(0, gra)
  end,
  get_hit,
  nil,
  on_die
 )
end

function hp_box(p)
 return box(
  2, p, nil, function(_ENV, o)
   if o.hp < 10 then
    sfx(38)
    heal(o.pos, ceil(10 - o.hp))
    o.hp, rem = 10, true
   end
  end,
  1,
  function(_ENV, ow, te, fo)
   impactor(nil, pos, fo, rand(1.2, 1.8), 196, 16, 1.1, v2(1, 2), ow, te, "fls2", 48, 5, .7)
  end
 )
end

function w_box(p)
 return box(
  3, p, nil, function(_ENV, s)
   sfx(38)
   local prev = s.we.id
   while s.we.id == prev do
    s.we = weapons[randint(2, 10)]
   end
   s.cd.weapon, s.cd.reload, s.mag, rem = 0, 0, s.we.mag, true
  end,
  1,
  function(_ENV, ow, te, fo)
   impactor(nil, pos, fo, rand(1.4, 2.2), 256, 22, 1.2, v2(2, 5), ow, te, "mne", 35, 6, .9)
  end
 )
end

function barrel(p)
 return box(
  4, p, nil, nope, 1, function(_ENV, ow, te, fo)
   acid_fx(pos, randint(9, 13), fo, v2(.3, .7), 3, .2)
   impactor(nil, pos, fo, rand(2.2, 2.6), 400, 32, 1.3, v2(3, 5), ow, te, "brl", 1, 8, .8)
  end
 )
end

function mine(p)
 return box(
  5, p, function(_ENV)
   if hp <= lhp then
    hp -= .09
    if (hp < 0) imp(_ENV, 0, 0, v2(), 0, 0, 0)
   end
  end,
  function(_ENV)
   if hp > lhp then
    sfx(32)
    hp = lhp
   end
  end, 33, function(_ENV, ow, te, fo)
   impactor(nil, pos, fo, rand(2.2, 2.6), 360, 32, 1.3, v2(5, 9), ow, te, "mne", 35, 6, 1.1)
  end
 )
end

function unit(ow, te, god, c1, c2, c3, we_i, ...)
 local u = gob(...)

 u._ow = ow
 u._te = te
 u.c1 = c1
 u.c2 = c2
 u.c3 = c3
 u.aim = u.l and "w" or "e"
 u.we = weapons[we_i]
 u.mag = u.we.mag
 u.cd.god = god
 u.h_free = 0

 u.canattack = function(_ENV)
  local w_pos = anim:get_p(pos)
  local m_pos = we:get_m_pos(w_pos, aim, l)
  if not cd.melee then
   local hb = get_hb(_ENV)
   for o in all(w_get(_ENV, 72, 0)) do
    local o_hb = o:get_hb()
    local near, far = r_coll(hb, o_hb), p_coll(m_pos, o_hb)
    if near or far then
     return "m", near, near and w_pos or m_pos, o
    end
   end
   if get_px(m_pos.x, m_pos.y) ~= 1 then
    return "m", false, m_pos
   end
  end
  if not cd.weapon and not cd.reload and mag > 0 then
   return "s", false, w_pos
  end
 end

 return u
end

function sold(pl, p)
 local s = unit(
  pl.id, menus[1]:get(1) == 1 and 1 or pl.id, 135, pl.c1, pl.c2, pl.c3, 1, 1, p,
  function(_ENV, ow, te, fo, dmg)
   local le = #fo
   anim:play((not l and fo.x > 0) and (le > .8 and 11 or 5) or (le > .8 and 12 or 4), true)
   if cd.god or (_ow ~= ow and _te == te) then
    return 0
   end
   sfx(36)
   on_suf(pos, ceil(dmg), fo, v2(.3, .6), 2, 0)
   return dmg
  end,
  function(_ENV)
   if anim.eof then
    cd.aim = nil
   end
   if not cd.reload and p_reload then
    mag = we.mag
   end
   p_reload = cd.reload
   local h_dir, a_fo, acc = l and -1 or 1, anim.fo, v2(0, gra)
   local can_control = not (cd.f_move or a_fo)
   -- head free
   local h_f = cango(_ENV, pos, v2(0, -1)) or cango(_ENV, pos, v2(h_dir, -1))
   if h_f then
    h_free += 1
   else
    h_free = 0
   end
   if can_control and joy.o.down then
    if rnd() < .1 then sfx(39) end
    jpa(pos + v2(-h_dir * 2, 1), 1, spd, v2(-.2, -.4))
    if h_f then
     acc.y = -0.08
    else
     acc.y = 0
    end
   end

   if can_control then
    -- side blocked
    s_b = true
    for d in all({ v2(h_dir, 0), v2(h_dir, -1), v2(h_dir, 1), v2(h_dir, -2) }) do
     if cango(_ENV, pos, d) then
      s_b = false
      break
     end
    end
    -- move acc
    local m_a, prev_l = ground and 0.025 or 0.03, l
    if joy.l.down and not joy.r.down then
     l, acc.x = true, (not s_b and -m_a or 0)
    elseif joy.r.down and not joy.l.down then
     l, acc.x = false, (not s_b and m_a or 0)
    end
    if l ~= prev_l then
     aim = joy.dir
    end
    anim.f_x = l
    if not cd.aim then
     if joy.dir ~= "" then
      aim = joy.dir
      cd.aim = 6
     end
    end
    -- attack
    if joy.x.down then
     local a_t, near, p, o = canattack(_ENV)
     if a_t == "m" then
      cd.melee = 30
      if not cd.weapon then
       cd.weapon = 10
      end
      anim:play(not near and aims[aim].an_i or ground and (aim == "n" and 16 or 10) or 14, true)
      impactor(o, p, aims[aim].mel:rot(rand(-.05, .05)), rand(1.2, 1.3), 0, 12, 1, v2(1, 2) * ((we.id == 2) and 3 or 1), _ow, _te, "hit", 54, randint(3, 4), 1.3)
     elseif a_t == "s" then
      cd.weapon = we:shoot(p, aim, _ow, _te, l)
      if not cd.melee then
       cd.melee = 10
      end
      mag -= 1
      if mag <= 0 then
       cd.reload = we.r_ti
      end
     end
    end
   end
   -- auto animation
   if not a_fo then
    anim:play(air < 15 and (abs(spd.x) > .1 and 8 or aim == "n" and 2 or aim == "s" and 3 or 1) or ((spd.y < -.7 or h_free < 5) and 1 or spd.y < -.45 and 5 or spd.y > .45 and 7 or 5))
   end

   return acc
  end,
  -- on before draw
  function(_ENV)
   if not (we.id == 2 and cd.reload) then
    if cd.reload and cd.reload % 10 > 5 then
     pal_spec(we.id == 3 and 0 or 7)
    end
    we:draw(anim:get_p(pos), aim, l)
    ppal()
   end
   pal(1, c1)
   pal(2, c2)
   pal(3, hp < ulhp and 2 or hp < lhp and 8 or c3)
   if cd.god and cd.god % 10 > 5 then
    pal_spec(_ow == 4 and 0 or 7)
   end
  end,
  -- on after draw
  function(_ENV)
   if (we.id == 7 and not cd.weapon and not cd.reload and rnd() < .05) mflm(we:get_m_pos(anim:get_p(pos), aim, l))
  end,
  -- on die
  function(_ENV, ow, te, fo, dmg)
   sfx(56)
   blood_fx(pos, randint(15, 25), fo, v2(0.5, 1), 2, .25)
   drt(pos, randint(3, 11), fo * (rnd() < .25 and -1 or 1), v2(.2, .7), 0, 0, nil, { c1 }, sticky)
   lim(pos, randint(0, 2), fo, v2(.3, .7), 1, .2, nil, { 8, c1 }, sticky)
   players[_ow].soldier = nil
   if ow == _ow or ow == 0 then
    players[_ow].scr -= 1
   elseif ow ~= 0 then
    players[ow].scr += menus[1]:get(1) == 3 and 2 or 1
   end
  end,
  -- on land
  function(_ENV)
   if air > 15 and spd.y > .45 then
    anim:play(13, true)
   end
  end
 )

 s.joy = pl.joy

 return s
end

function enemy(p)
 local e = unit(
  0, 0, 0, 0, 8, 2, 11, 6, p,
  -- on impact
  function(_ENV, ow, te, fo, dmg)
   local le = #fo
   anim:play((not l and fo.x > 0) and (le > .8 and 9 or 5) or (le > .8 and 8 or 4), true)
   sfx(59)
   cd.hit = 3 + dmg
   on_suf(pos, ceil(dmg), fo, v2(.3, .6), 2, 0)
   return dmg
  end,
  -- on update
  function(_ENV)
   if not (anim.fo or cd.f_move) then
    local d = v2()
    if not tar or not cd.search then
     cd.search = 90
     tar = acq_tar(_ENV, 0, 1, 0)
    else
     if tar.rem then
      tar = nil
     else
      d = (tar.pos - pos):norm()
      anim.f_x = d.x < 0
      anim.f_y = d.y > 0
      acc.x = d.x < 0 and -.05 or d.x > 0 and .05 or 0
      acc.y = d.y < 0 and -.05 or d.y > 0 and .05 or 0
     end
    end
    if not cd.attack then
     local a_t, near, w_pos, o = canattack(_ENV)
     if a_t == "m" and o and (rnd() < (o.type == 1 and .1 or .01)) then
      cd.attack = 75
      anim:play(7, true)
      impactor(o, w_pos, o.pos - pos, (v2(.5, .75) * lvl):ab(), 0, 12, .8, v2(1, 2) * lvl, 0, 0, "rhit", 54, 4, .5 * lvl)
     elseif a_t == "s" and tar and rnd() < .1 then
      cd.attack = randint(75, 270)
      we:shoot(eye, tar.pos - eye, 0, 0)
     end
    end
    anim:play(spd.x > .2 and 6 or abs(d.y) > .2 and 3 or abs(d.y) > .65 and 2 or 1)
    spd:limit(hp < ulhp and mspd / .5 or hp < lhp and mspd / .75 or mspd)
    return acc
   end
   return v2(0.01)
  end,
  -- on before draw
  get_hit,
  -- on after draw
  function(_ENV)
   eye = anim:get_p(pos)
   if tar then
    eye += (tar.pos - pos):norm()
   end
   pset(eye.x, eye.y, hp < ulhp and (flic % 10 > 3 and 0 or 2) or hp < lhp and 2 or 8)
  end,
  -- on die
  function(_ENV, ow, te, fo, dmg)
   sfx(60)
   ssmk(pos, randint(7, 13), fo, v2(.2, .4), 2, .25)
   drt(pos, randint(3, 11), fo * (rnd() < .25 and -1 or 1), v2(.2, .7), 0, 0, nil, rnd({ { 0 }, { 8, 2 } }), sticky)
   lim(pos, randint(2, 3), fo, v2(.3, .7), 1, .2, nil, { 2, 0 }, sticky)
   if ow ~= 0 then
    players[ow].scr += 1
   end
  end,
  -- on land
  nil
 )
 e.eye = p
 e.hp += lvl * 3
 e.mspd = .1 + lvl * .02
 return e
end

-- world manipulation
function w_add(o) add(world, o) end
function w_get(obj, sqrdist, filter)
 local near = {}
 for o in all(world) do
  if o ~= obj and (filter == 0 or (o.type & filter) ~= 0) and (sqrdist == 0 or obj.pos:sqrdist(o.pos) <= sqrdist) then
   add(near, o)
  end
 end
 return near
end
function w_spot()
 local i = 0
 while true do
  i += 1
  local p = v2(randint(3, 124), randint(13, 115))
  if ((i > 100 or w_get({ pos = p }, 360 - i * 3, 0) == 0) and free(p - v2(2, 3), v2(5, 6))) return p
 end
end

-- particle system
function p_upd(_ENV)
 if delay > 0 then
  delay -= 1
 else
  life += 1
  eol, acc, n_pos = life > max_life, v2(0, gra), pos + spd
  if on_upd then on_upd(_ENV) end
  spd = (spd + acc) * fri
  pos = n_pos
  return eol or pos.x < 0 or pos.x >= 128 or pos.y < 0 or pos.y >= 128
 end
end

function part_c(e)
 _g[e.name] = function(pos, bu, di, fo, sp, co, de, cols, on_upd, ow, te, we)
  bu, di, fo, sp, co, de, cols = bu or 1, di and di:norm() or v2(), fo or v2(1, 1), sp or 0, co or 0, de or v2(), cols or e.cols
  for _ = 1, bu do
   add(
    p_sys, env({
     life = 0,
     bou = 0,
     max_life = e.life:ab(),
     delay = de:ab(),
     kind = rnd(e.kinds),
     pos = pos + v2(1, 0):rot(rnd()) * rand(0, sp),
     spd = (v2(e.x_s:ab(), e.y_s:ab()) + di * fo:ab()):rot(rand(-co, co)),
     gra = e.gra,
     fri = e.fri,
     num_s = #e.sizes,
     sizes = e.sizes,
     num_c = #cols,
     cols = cols,
     on_upd = on_upd,
     ow = ow,
     te = te,
     we = we
    })
   )
  end
 end
end

function fx_c(fx)
 _g[fx.na] = function(p, bu, di)
  _g[fx.sho](p)
  _g[fx.ba](
   p, fx.bu, di, nil, fx.sp, 0, fx.de, nil, function(_ENV)
    if (eol) _g[rnd(split(fx.af, "+"))](pos, 1, di, v2(.1, .3))
   end
  )
 end
end

function ssmk(...)
 _g[rnd({ "smk", "spa" })](...)
end

function xsmk(...)
 _g[rnd({ "smk", "smkb", "smkc" })](...)
end

function spawn_fx(pos, ty, si, cols)
 local n = 7 + si * 2
 for i = 1, n do
  if i < 3 and i <= si then
   _g[ty .. i](pos, 1, nil, nil, 0, 0, v2(3, 6), cols)
  end
  local p_pos = pos + v2(rand(7 + si, 9 + si), 0):rot(i / n)
  _g["sli" .. randint(1, si)](p_pos, 1, pos - p_pos, v2(.5, .6), 0, 0, nil, cols)
 end
end

function sticky(_ENV)
 if get_px(n_pos.x, n_pos.y) ~= 1 and rnd() < .3 then
  set_px(n_pos.x, n_pos.y, rnd(cols))
  eol = true
 end
end

function blood_fx(pos, bu, di, fo, sp, co)
 blo(pos, bu, di, fo, sp, co, nil, nil, sticky)
end

function acid_fx(p, bu, di, fo, sp, co)
 aci(
  p, bu, di, fo, sp, co, nil, nil, function(_ENV)
   if get_px(n_pos.x, n_pos.y) ~= 1 then
    local ch = rnd()
    sfx(34)
    set_px(n_pos.x, n_pos.y, ch < .1 and 1 or ch < .3 and 11 or ch < .5 and 3 or 0)
    eol = true
   else
    for o in all(w_get(_ENV, 64, 119)) do
     if p_coll(pos, o:get_hb()) then
      eol = true
      impactor(o, pos, spd, .2, 0, 6, .8, v2(.5, 1), 0, 0, "smkc", 34, 1, .1)
      break
     end
    end
   end
   if (eol) smk(pos)
  end
 )
end

function reset()
 players = use_data(plf, pld, player_c)
 p_sys = {}
 world = {}
 cd = {
  menu = 10
 }
 sched = {}
 drama_v = 0
 flic = 0
 state = 1
end

function hud()
 if state < 3 then
  if state == 1 then
   sprites[14]:draw(v2(12, 22))
  end
  menus[state]:draw()
 end
 if state == 4 then
  pprint("this battle is over", 27, 16, 8, 0, "l", true)
  pprint("results:", 27, 26, 8, 0, "l", true)
  local sc, names = {}, split("joe,hicks,hank,simo")
  for p in all(players) do
   if not cd.menu and (p.joy.x.press or p.joy.o.press) then
    sfx(31)
    reset()
   end
   if p.conn then
    add(
     sc, {
      n = names[p.id],
      c = p.c1,
      scr = p.scr
     }
    )
   end
  end
  sort(sc, function(a, b) return a.scr > b.scr end)
  for i, s in ipairs(sc) do
   pprint(s.n .. ": " .. s.scr, 30, 26 + 8 * i, s.c, 0, "l", true)
  end
 end

 rectfill(0, 0, 127, 7, 0)
 rectfill(0, 120, 127, 127, 0)
 if state == 3 then
  local s, m = countdown % 60, flr(countdown / 60)
  if countdown > 10 or flic % 30 >= 15 then
   pprint(m .. ":" .. (s < 10 and "0" .. s or s), 64, 1, countdown < 11 and 8 or countdown < 31 and 10 or 7, 1, "c", true)
  end
 end
 for p in all(players) do
  p:draw()
 end
 pal(1, bg_col, 1)
end

-- submit menu
function submit(id)
 sfx(31)
 cd.menu = 10
 local m = menus[id]
 if id == 1 then
  if m.idx == 6 then
   state = 2
  end
 elseif id == 2 then
  if m.idx == 6 then
   state = 1
  elseif m.idx ~= 5 then
   gen_map()
  else
   if not map_done then
    gen_map()
   end
   spwn_i, countdown, lvl, state = 1, menus[1]:get(2) * 3 * 60 + 3, menus[1]:get(5), 3
   schedule(randint(30, 90), upd_spwn)
   schedule(60, upd_countdown)
   sfx(58)
  end
 end
end

function schedule(de, fn)
 add(
  sched, {
   delay = de,
   fn = fn
  }
 )
end

function _init()
 music(0, 500)
 music_on = true
 menuitem(
  1, "music:on",
  function()
   music_on = not music_on
   music(music_on and 0 or -1)
   menuitem(1, "music:" .. (music_on and "on" or "off"))
   return true
  end
 )

 -- memory addresses for fast access
 _y = {}
 for y = 8, 119 do
  _y[y] = y * 64
 end

 -- init destructors
 dests = {}
 for r = 0, 10 do
  cls()
  circfill(r, r, r, 1)
  local d = {}
  for x = 0, 2 * r + 1 do
   for y = 0, 2 * r + 1 do
    if pget(x, y) == 1 then add(d, { x = x - r, y = y - r }) end
   end
  end
  add(dests, d)
 end

 -- decode string data stored in map memory and lower sprite
 local i, mg = 0, function(a) return mget(a % 128, flr(a / 128)) end
 while true do
  local b = mg(i)
  if b == 0 then break end
  local k, v, hi, lo = chr(b) .. chr(mg(i + 1)) .. chr(mg(i + 2)), "", mg(i + 3), mg(i + 4)
  i += 5
  for _ = 1, hi * 256 + lo do
   v = v .. chr(mg(i))
   i += 1
  end
  _g[k] = v
 end

 -- attach tables
 for ts in all(split(tbd, "|")) do
  local t, n, et, ds = {}, unpack(split(ts, "#"))
  for e in all(split(ds)) do
   local k, v = unpack(split(e, ";"))
   t[k] = conv(et, v)
  end
  _g[n] = t
 end

 menus = use_data(mef, med, menu_c)

 sprites = use_data(spf, spd, sprite_c)
 printh("number of sprites:" .. #sprites, "debug.txt")

 anims = use_data(a_f, a_d, env)

 weapons = use_data(wpf, wpd, weapon_c)

 spwns = use_data(swf, swd, env)

 aims = {}
 use_data(aif, aid, function(o) aims[o.n] = o end)

 -- particles
 use_data(paf, pad, part_c)
 -- effects
 use_data(fxf, fxd, fx_c)

 reset()
end

function _update60()
 flic += 1
 drama_v = max(drama_v - .03, 0)

 for k, v in pairs(cd) do
  cd[k] = v > 0 and v - 1 or nil
 end

 for sc in all(sched) do
  sc.delay -= 1
  if sc.delay <= 0 then
   del(sched, sc)
   if (state == 3) sc.fn()
  end
 end

 for p in all(players) do
  p:upd()
 end

 for p in all(p_sys) do
  if (p_upd(p)) del(p_sys, p)
 end

 for o in all(world) do
  if (o:upd()) del(world, o)
 end
end

function _draw()
 cls()
 ppal()

 camera(cd.shake and randint(-1, 1) or 0, cd.shake and randint(-1, 1) or 0)
 -- draw the map
 memcpy(0x6200 + (cd.shake and (64 * randint(-1, 1) + randint(-1, 1)) or 0), 0x8200, 0x1c00)

 for o in all(world) do
  o:draw()
 end

 -- draw particle system
 for p in all(p_sys) do
  if p.delay < 1 then
   local k, x, y, t = p.kind, p.pos.x, p.pos.y, p.life / p.max_life
   local s, c = p.sizes[min(flr(t * p.num_s) + 1, p.num_s)], p.cols[min(flr(t * p.num_c) + 1, p.num_c)]
   if k == 0 then
    pset(x, y, c)
   elseif k == 1 then
    circ(x, y, s, c)
   elseif k == 2 then
    circfill(x, y, s, c)
   elseif k == 3 then
    local h = s / 2
    rect(x - h, y - h, x + h, y + h, c)
   elseif k == 4 then
    local d = p.spd:norm() * -s
    line(x, y, x + d.x, y + d.y, c)
   elseif k == 5 then
    circ(x, y, 1, p.cols[2])
    pset(x, y, p.cols[1])
   elseif k == 6 then
    local d = p.spd:norm() * -s
    line(x, y, x + d.x, y + d.y, p.cols[1])
    pset(x + d.x, y + d.y, p.cols[2])
   else
    local d = p.pos - (p.spd:norm():rot(p.life / 50) * 3)
    line(x, y, d.x, d.y, p.cols[2])
    pset(d.x, d.y, p.cols[1])
   end
  end
 end

 camera()
 hud()
end

__gfx__
eeeeebbbbbbbbbbbbbbbeebbbbbbbbbbeeeebbbbbbbbbbbbeeebbbbbeeeebbbbeeeeeeeebbbbbbbbeebbbbbbbbbbbeeeeeeeeeeeeeeebbbbbeeeee33334e3335
eeeeeb00b0000000000beeb000000000beeeb0000000000bbeeb000beeeb000beeeeeeeb0000000beeb000000000beeeeeeeeeeeeeeb3333bbeeee3bb44333e5
eeeeeb00b0000000000beeb0000000000beeb00000000000beeb000beeb0000beeeeeeb00000000beeb000000000beeeeeeeeeeeeee311113bbeee3b43433535
eeeeeb00b0000000000beeb0000000000beeb00000000000beeb000beb00000beeeeeb000000000beeb000000000beeeeeeeeeeeeee3dddd33beee343343e254
eeeeeb00b0bbbbb0000beeb000bbbb000beeb000bbbbb000beeb000bb0000bbbeeeeb00000bbbbbbeebbbb000bbbbeeeeeeeeeeeeee3d1ddd3b5ee4444444544
eeeeeb00b0000000000beeb000beeb000beeb000beeeb000beeb0000000000beeeeb0000000000beeeeeeb000beeeeeeeeeeeeeeee5b11111b555ee333566666
eeeeeb0000000000000beeb000beeb000beeb000beeebbbbbeeb00000000000beeb00000000000beeeeeeb000beeeeeeeeeeeeeee553b111b35555333356786d
eeeeeb0000000000000beeb000beeb000beeb000beeeeeeeeeeb00000000000beeb00000000000beeeeeeb000beeeeeeeeeeeeee53553bbb355335333556882d
eeeeeb0000000000000beeb000bbbb000beeb000bbbbbbbbeeeb000bbbbb000beeb0000bbbbbbbbbeeeeeb000beeeeeeeeeeeeeeeeeeedddddeeee3b555662dd
eeeeeb0000bbbbbbbbbbeeb0000000000beeb0000000000beeeb000beeeb000beeb000000000000beeeeeb000beeeeeeeeeeeeeeeeeedcccccdeee455556dddd
eeeeeb0000beeeeeeeeeeeb0000000000beeb0000000000beeeb000beeeb000beeb000000000000beeeeeb000beeeeeeeeeeeeeeeeedccdddddeeee6666ee666
eeeeeb0000beeeeeeeeeeeb0000000000beeb0000000000beeeb000beeeb000beeb000000000000beeeeeb000beeeeeeeeeeeeeeeeedcd11111dee6686de666d
eeeeebbbbbbeeeeeeeeeeebbbbbbbbbbbbeebbbbbbbbbbbbeeebbbbbeeebbbbbeebbbbbbbbbbbbbbeeeeebbbbbeeeeeeeeeeeeeeeeedd1111c1dee6822d662dd
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee555cccccceee6dddd62ded
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee55555ccccd55edddddddddd
bbbbbbbbbbbbbbbeebbbbbeeeeeeeeeeeeeeeeebbbbbbbbeebbbbbbbbbbbeebbbbbbbbbbeeeebbbbbbbbbbeeeebbbbbbbbeeeeee5cdd555dd55ddcb350bb50ee
b00b0000000000beeb000beeeeeeeeeeeeeeeeb0000000beeb000000000beeb000000000beeeb000000000beeeb0000000beeeeeeeeaaaaaaaeeee3500b300ee
b00b0000000000beeb000beeeeeeeeeeeeeeeb00000000beeb000000000beeb0000000000beeb0000000000beeb00000000beeeeeeaaaaaaaaaeee35503550ee
b00b0000000000beeb000beeeeeeeeeeeeeeb000000000beeb000000000beeb0000000000beeb0000000000beeb000000000beeeeea111114aaaee35003500ee
b00b0bbbbb0000beeb000beeeeeeeeeeeeeb0000bbb000beebbbb000bbbbeeb000bbbb000beeb000bbbb000beeb0000b00000beeeee5555555aaee55505550ee
b00b0000000000beeb000beeeeeeeeeeeeb00000000000beeeeeb000beeeeeb000beeb000beeb000beeb000beeb0000bb00000beeee51555144eeebb30676686
b0000000000000beeb000beeeebbbbbeeb000000000000beeeeeb000beeeeeb000beeb000beeb000beeb000beeb0000beb00000be551111144555eb3e0dddddd
b0000000000000beeb000beeeeb000beeb000000000000beeeeeb000beeeeeb000beeb000beeb000beeb000beeb0000beeb0000b55511114455a553350d6dd2d
b0000000000000beeb000bbbbbb000beeb000000000000beeeeeb000beeeeeb000bbbb000beeb000bbbb000beeb0000beeeb000b5a5444445aaaa5b500555555
b0000bbbbbbbbbbeeb000000000000beeb000bbbbbb000beeeeeb000beeeeeb0000000000beeb0000000000beeb0000beeeb000beeeeeeeeeeeeee5300eeeeee
b0000beeeeeeeeeeeb000000000000beeb000beeeeb000beeeeeb000beeeeeb0000000000beeb0000000000beeb0000beeeb000beeeeeeeeeeeeeeeeeeeeeeee
b0000beeeeeeeeeeeb000000000000beeb000beeeeb000beeeeeb000beeeeeb0000000000beeb0000000000beeb0000beeeb000beeeeeeeeeeeeeeeeeeeeeeee
bbbbbbeeeeeeeeeeebbbbbbbbbbbbbbeebbbbbeeeebbbbbeeeeebbbbbeeeeebbbbbbbbbbbbeebbbbbbbbbbbbeebbbbbbeeebbbbbeeeeeeeeeeeeeeeeeeeeeeee
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee98eeeeeeeeeeeeeeeeeeeeeeee552ee9a4eee9e5ee
eee5dd5d5d5eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeedeeeee555eeeeebbbbbbbbbbbbbeeeeeeeeee88eeeeeeeeee55eeeeeeeee55ee8e994ee9a4dee
ee655555555eeeeeedeeeeeeeed66667776677eeeee55dd555555dddccccccccc333333d555233eeeeeeeeee898e44445555555eee555225eeeee9a4e9a9454e
e9942e55555ee9999d66666666d66666666666e2444445552445555dddddddddd555555d555255222222ddddfa9e22222566665ee5528525528ee99e9e94eee5
e944eeeeeeeee44445ddddddded6ee6d6ddd66e24442deeeeeee5ee55eeeeeeeeeeeeeee55eeee2dd2222eeeeeee22e2e577775ee5d55225eeeee9e949eeeede
e94eeeeeeeeeeeeee5eeeeeeeeeeee6deeeeeee244eeeeeeeeeeeee5eeeeeeeeeeeeeeee5eeeee2eee2deeeeeeeeeeeeeeddddeee5de55e55ee8e949eeeee5ee
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee2deeeeeeeeeeeeee5555eeeeeeeeee552eeee9999994ee
eeeeeeeeeeeee66eeee6ed667760eeeee0e444000eceeeeeecee55eee33eeeee3333333332eeeee222222256deee55e445555e2e2eee22eeeeee22e4e9a9a5d5
999999999999e76eee766de66660eeee0ee4400eeeceeeeece5cccccc32eeee30233300232eeee2e2e2dee56dee556d4ee5662eee2e2eeeee000ee299e4444ee
4e999aa9a97ae76ee766eed6eee00ee40eee4eeeeeceee5cee5e5eeee300ee3000eeee0ee2dde2deee2dee55ee556deeeeedd2e8e2e0e8e200028eee9eeee5ee
4e9999999999e66e666eed667ee40444eee444eee5cee5ceee5eeeeee30ee333ee33eeeee222222d22eeee5ee445eeee44eeee020ee02ee20e00ee24e9ee44de
999ee9444999e6ed6eeeeee667e44e4eeeeee00ee5c5ec5eee5c5eeee33e333eee333eeee2ee2eeee22eee4ee4eeeee4e55eee000e00002eeeee22e9999eeee5
eeeeeeeeeeeeeddedeeeeeee66644eeeeeeeee00eece55eeeee5c5eee33ee3eeeee333eee22eeeeee2d2ee44eeeeeeeee565ee00ee00eeeeeeeeeeeee4a9eeee
eeeeeeeeeeeeee2eeeeeeeeee6eee22113eeeeee0e55e5eeeeeeeceee33eeeeeeeee303eeeeeeeeeedee2eeeeeeeeeeeeed65ee00e0eeeee000eeeeee49aeeee
ee0eee11eee01222eee11ee0eeee221eeeee3ee11eeee11eeeeeeeceeeeeeeeeeeee0023eeeeeeeeeeeeeeeeeeeeeeeeeeedeeeeeeeeeee0e00002eeee4eeeee
ee110223eeee1122e2223e01eeee222eeeee1e222e3e22322eeeeeeceeeeeeeeeeeeee3eeeeee000eeeee00eee000000eeeee00eeeeeeeeeee02ee26eeee6466
ee11e2113100132ee22113122eeee211ee121e2211e211322211eeeeeeeeeeeeee000eeee0eeeeee0eee0ee0eeeeeeee000e0ee0ee0eeeeeee0e8e2e6ee6e4ee
ee11e2211eeee11e0111ee12211e1111ee221ee22ee221ee2133eeeeeeeeeeeee0eeeeeeee0eeeee000eee0eeeeeeee00000ee000ee0eeeeee2eeeeee44eee6e
1322eeee0eee211ee01eeee1223e0ee0ee222ee111ee111ee111eeeeeeeeeeee000eeeeeee0eeee00000ee000e0000000000e00000ee0eeeeee22eeeeeeeeee6
1222eeee211e223eee2221ee1113eeeeeee221e0e0ee0e0e1e13eeeeeeeeeee00000ee0ee0ee00000000e00000eeeee000000000000ee0eeeeeeee666666eeee
e11e211e223e2113012123eee211eeeeee1ee1eeeeeeeeee0ee0eeeeeeeeeee0000000ee000eeee00000000000eeeeee000ee000000eee000eeee666dddd6eee
223e223e2113e1110111113ee223eeeeee0ee0eeeeeeeeeeeeeeeeeeeeeeeee00000eee00000eeee000ee00000e0000000eeee000ee0e00000eee66d11116eee
21132113e2110ee0eeeee11ee2112eeee22ee22eeeeeeeeeeeeeeeeeeeeeeeee000eeee00000eeeee0eeee000eeeeeeeeeeee0ee0e0e000000eee6d100106eee
221ee21ee10eeeeee112223eee211110211e2112eeeeeeeeeeeeeeeeeeeeeeeeee0ee0e00000e0000eeeeee0eeeeeeeeeeeee0ee0ee0e00000ee56d1111165ee
e11ee01ee0eeeee2223222113e110eee23312332eeeeeeeeeeeeeeeeeeeeeeeeeee00eee000eeeeeeeeee0ee0eeeeeeeeeeeee00eeee00000ee556d11111655e
e00eee0eee11eee2113e112eee11eeee213e1111eeeeeeeeeeeeeeeeeeeeeee0eeeeeeeeee0eeeeeeeeeee00eeeeeeeee00000eeeeeeeee0eee555666666655e
e11e11ee2223eeee21e1ee1eee23eeee11110e10eeeeeeeeeeeeeeeeeeeeeeee0eeeeeeeeee0eeeee000000ee00eeeee0e00000eeee0000eee66655666665566
233222e3113eeeee1110ee0ee2112eee0ee0ee3eeeeeeeeeeeeeeeeeeeeeeeeee0eeeeeeeee0eeee0eeeeeee0ee0eeeeee00000eee0eeeeeeeeee00eeeeeeeee
2112211ee211110e0e0eeeeee2211eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0ee00000eee0ee000eeeeeeeeeee000eee000000e000eeeeeeeee0ee0eeeeeeee
213222eee11eeeeeeeeeeeeee21e0eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0ee00000eeee00000eeeeeeeee00000e0ee000e00000ee0eee0e0eeeeeeeeeee
e11e11ee0eeeeeeeeeeeeeeeee0eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000eeee0000000000ee00000000eeee0ee0000000eeee0ee0eeeeeeeeee
e00e00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000eeee00000eeeeee0ee00000eeeee0ee00000eeeeee0eee000eeeeeee
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eee000eeeeee000eeeeeeeeeee000eeee00eeee000eeee0eee0e00000eeeeee
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000eeeeeeeeeeee0eeeeeeeeeee0eeeeeeeeeeeeee0000ee00e000000eeeeee
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000eee000eeeeeeeeeeeeeeeeeeee0ee0e00000eeeeee
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000eeeeeee
a303c733a323c2132353a33353c203a3133223a303c743a333c2132343a33373c213a3133233a323c71333a373c21333a32383c263a303c733a333c2131393a3
4333c223a3233203a303c733a333c2132323a34333c203a3233223a303c733a313c2132353a34333c203a3033223a303c733a333c2132353a34343c203a30332
23a323c71333a373c22363a32383c263a303c723a363c21333a33353c213a3433213a303c763a363c21353a33353c223a3433243a313c763a323c22313a33353
c213a3133253a313c763a353c22313a33373c213a3233243a333c71333a373c23393a32383c263a303c723a363c22373a33353c213a3433203a303c753a353c2
2393a33353c223a3433243a303c763a323c23353a33353c213a3133253a303c763a353c23353a33373c213a3133253a343c71333a373c25323a32383c263a303
c733a373c24313a33353c223a3533213a303c763a373c24343a33353c213a3533253a303c773a333c25303a33353c213a3233263a313c763a363c25303a33383
c213a3233253a353c71333a373c26353a32383c263a303c733a373c25373a33353c223a3233213a303c763a363c26303a33353c243a3333253a303c773a333c2
6363a33353c243a3233263a313c763a363c26363a33383c233a3433253a353c71333a373c27383a32383c263a303c733a363c27333a33353c213a3533203a303
c743a353c27363a33353c203a3433233a303c763a333c28303a33353c203a3133253a303c753a343c28303a33383c203a3033243a333c71333a373c29313a323
83c263a303c733a363c28363a33353c213a3433203a303c763a353c28393a33353c213a3433243a303c763a333c29353a33353c213a3133253a303c763a353c2
9353a33383c213a3133253a333c71333a373c2130343a32383c263a303c753a373c2130313a33353c233a3633223a323c763a373c2130363a33353c203a36332
33a323c773a353c2131323a33353c203a3333243a323c783a363c2131313a34313c203a3133253a333c71333a373c203a33353c263a303c733a363c2131373a3
2383c213a3433213a303c753a353c2132303a32383c213a3333233a313c763a333c2131393a33343c213a3133253a313c753a363c2131393a33373c213a31332
43a343c753a363c233a35343c213a3333243a3133203a3033223a353c743a363c203a34383c213a3333233a3233203a3033223a353c733a363c203a35343c213
a3333223a3333203a3033223a353c763a353c21363a34323c223a3233253a3233213a3033243a343c773a333c21363a34373c233a3133263a3233203a3033253
a323c763a363c22323a34323c223a3333253a3533203a3133243a353c743a363c243a34383c213a3333233a3233203a3033223a353c743a363c283a34373c213
a3333233a3233203a3033223a353c743a353c21323a34363c213a3233233a3233203a3033223a343c743a363c21353a35313c213a3333233a3233213a3033233
a353c763a363c21393a35303c203a3333253a3233203a3033233a353c773a363c283a35333c203a3333223a3233203a3033233a353c753a353c21313a34313c2
23a3233223a3233213a3033233a343c753a363c203a34323c223a3333223a3333203a3133233a353c763a353c253a34323c223a3233233a3233203a3033233a3
43c71343a383c2130343a303c21333a303c71343a383c2130343a383c203a303c71343a383c2130343a31363c21333a303c71343a383c2131343a34373c203a3
03c743a363c22353a35333c213a3333233a3233203a3033233a353c773a353c22353a34383c223a3233233a3233203a3033233a343c763a363c22383a34313c2
03a3333253a3033203a3033233a353c743a383c23343a34323c203a3533223a3033203a3233233a373c753a363c23383a34323c213a3333243a3133213a30332
33a353c743a363c24333a34323c213a3333233a3233213a3033233a353c753a363c24373a34333c213a3333243a3433213a3133243a353c743a363c23323a353
03c213a3333223a3333203a3133233a353c743a363c23363a35303c213a3233223a3533203a3133233a343c783a393c26333a34343c223a3433213a3533203a3
133263a383c753a31333c27313a34343c223a3633243a3633203a3133243a31313c783a393c27363a34333c253a3433263a3433223a3133273a373c763a31313
c28343a34333c233a3533253a3533203a3133253a393c71303a373c29303a34333c273a3333283a3333233a3033293a363c763a31303c2130303a34333c233a3
433243a3433203a3133253a383c783a393c2130363a34343c253a3633263a3733203a3333273a383c793a393c26333a35333c263a3533263a3533213a3333283
a383c71313a393c27363a35343c223a3433233a3333203a3133273a373c783a393c28373a35343c253a3433263a3333213a3133273a373c783a383c29353a353
33c253a3233253a3133213a3033273a363c793a393c2130333a35333c223a3533223a3433203a3233283a383c71303a393c2131323a35353c273a3633283a373
3223a3333293a383c703a303c213a313c203a3033203a303c703a303c213a313c203a3033203a303c703a303c213a313c203a3033203a303c703a303c213a313
c203a3033203a303c703a303c213a313c203a3033203a30376f666002533b3370746c233b33796c213b3169627c213b38607c233b3f66666c213b34756c243b3
36c696c213b3f677c233b3163636c213b357c68607c223b3375766c213b316f59646c213b3c68607c213b347970756770746305366c63723c29303c213e223a3
13e233c203e283c203e20313c20727f6a613c283c213c203c22323c24313c203e22353c266c63713c223a333c203c213c263c223e283a333e223c24303c21353
c7370716c26303c213a313c203c203e20313c2b6e6966656c213c213c203c203c24333c203e273c2e6f60756c203a303c203e20323c223c22303c263a393c243
23c22303c766c63713c2132303c213e243a313e253c203e28353c203e2031353c20727f6a613c23303c213c203c263c24313c203e223c266c63713c223a333c2
03c233c263c203e293a313e213c24343c22353c766c63713c2132303c203e293a313e233c203e293c203e2032333c20727f6a613c253c253c203c23303c24313
c203e21353c266c63723c223a333c203c243c21323c213a313e233c24353c23303c72666c637c2132303c223a323c213e223c203c226c60727f6a6c233c213c2
6343c22303c24333c213e213c237369626c233a343c203c253c21363c263a373e253c24343c23353c7270776c29353c203e283a303e293c213e213c203e20313
c227f636c213c213c2332303c203c23353c223c266c63723c263a373c203c263c23303c273a383c24383c24303c78737d6b6c2130303c203e273a303e293c203
c203e20323c266c6d6c25303c233c203c21303c23343c203e213c2e6f60756c203a303c2d203e20353c273c203c203e253a303e283c24393c24353c7762756c2
133303c213e223a313e233c213c203e2032353c20727f6a676c243c213c2235363c26303c23353c213e243c266c63723c243a353c203e20383c283c23303c263
a393c213c25303c7f6272627c27303c203e253a303e263c203e253c203e20313c20727f6a6f6c213c213c2132383c203c25303c203e273c237369627c233a353
c203c293c21383c223a333c25303c25353c7d6f6c647c27353c203e283a313c203e273c203e20333c20727f6a6d6c233c233c2235363c23303c25323c203e273
c266c63713c233a353c203e20323c21303c21383c223e253a333c25313c26303c72766c637c203c203e283a313c213c203e20323c227c60727f6a6c213c213c2
83c203c24373c203e233c237369627c223a333c203c21313c263c213e223a323e223c24363c213036337774600b623c28607f526f6873277f526f687c2833263
32333243c233c263c237371732373717c2233223c203c723c22616272756c632d696e656c20332131332233253c243c22343c237371732373717c2233213c203
c713c256e656d697c2033283c253c23323c2373696c223c21316964600dc03e293a303e243c223c203c203c256c293c213a303c703e273a3d203e273c213c203
c203c2e656c21353c203e273a3d203e273c703a3d213c203c203c203c2e6c21363c203a3d213c7d203e273a3d203e273c213c213c203c2e677c21353c2d203e2
73a3d203e273c7d203e293a303e243c223c213c203c277c293c2d213a303c7d203e273a303e273c233c213c203c23777c21373c2d203e273a303e273c703a313
c203c203c213c237c21383c203a313c703e273a303e273c233c203c203c23756c21373c203e273a303e27307166600f31313b3b696e64637c223b3e616d656c2
33b3c6966656c21313b336f6c637c213b3662796c213b3762716c233b397f537c233b387f537c21313b33796a7563716966600c233b3d656c6c213b33707f596
c243b366f587c243b366f597c223b3e6c213b316e6f596c233b36723f5d6f64616f54610b913c263c723c263c733c263c743c263c753c263c763c263c773c263
c783c263c793c263c71303c263c71303321313c263c71323321333c263c71323c263c76353c263c76363c263c76373c263c77393c243c76383c243c76393c263
c77303c263c76363327313327323327333c263c76363327343327353327353327353c253c76363327323327363327363327363c253c763633263833263933273
03327373327383327393c263c76363327393327383327373327303326393326383c263c77303326393327333326363c233c78343328353328353328353c253c7
6363326353328363328363328363c253c76353328383328373328373328373c253c76363328393329303329303329303c253c763733293133293233293233293
23c253c79353c263c7130323c263c7130333c263c7130343c21323c7130303c21323c79353329363329383329373329373329373329373329373c283c7935332
9363329343321303133213031332130313c263c793533293833293433293333213034332130343c253c79353329383321303033293933213035332130353c253
668746101103c2e6f60756c22666c63723c237d6b626c213c22666c637c203a323c703c2e6f60756c22766c63723c237d6b626c213c22766c637c203a323c753
c23786f623c226c6f623c237d6b626b237d6b6c293c2270776c263a31383c753c23786f613c266c63723c237d6b626b237d6b6c293c2762756c243a31323c703
c2273786f613c22766c63723c237d6b626c213c2f6272627c203a323c733c23786f613c266c63723c237d6b626c253c2d6f6c647c243a31323c743c2763786f6
23c27666c63723c237d6b6b237d6b626c273c22627c6c283a32323c733c23786f613c226c6f613c237d6b6b237d6b626c253c2d6e656c223a31303c703c2e6f6
0756c266c63723c237d6b626c213c2860726c203a32316f56600f01313b3662716d65637c213b3370746370766004133b33796a756c233b33707f637c21333b3
074737668766003213b33707c223b33786f6c223b32616c223b31666c213b32657c223b3e616c233b34656000000000000000000000000000000000000000000
__label__
11111111111111111111111000000000000011111111111111111111111111111111111111111111211111112111211121111111111111111111111111112110
11111111111111111111000333333000000001000001111111111111111111111111111111111100001000000000000100000000000000000000000000100000
1111111111111111111033333333055555550055555011111111111111111111111111111111110bb000b00b00b0bb000b00bbb0bbb0bb0bb00b0b00b000bb00
1111111111111111110333333300555500055555005501111111111111111111111111111111110b0b0b0b0bb0b0b0b0b0b00b000b00b00b0b0b0b0b000b0000
1111111111111111100333300005555022205550220501111111111111111111111111111111210b0b0b0b0bb0b0bb00b0b00b010b00bb0bb000b000010bbb00
1111111111111111003330000050555088205550820550111111111111111111111111111111110b0b0b0b0b0bb0b0b0bbb00b010b00b00b0b00b01111000b00
1111111111111110003305000500055088205550820550111111111111111111111111111111110bb000b00b00b0bbb0b0b00b010b00bb0b0b00b011110bb000
11111111111111000330550055000550222055502205501111111111111111111111111111111100001000000000000000000001000000000000001111000010
11111111111111000005500055000555000550550055501111111111211111112111111111112111211121112111111111111111111111111111112121212120
111111111111100055055000555055555555555555550011111111111111111dd111111111111111111111111111111111111111111111111111111111111110
1111111111111005000550005055550000000000000000111111111111111155f000111111111111112111211111111111111111111111111121112121211120
111111111111005003300500050550333333333030300111111111111111115ddd01111111111111111111111111111111111111111111111111111111111110
1111111111110000003330500050000000000000000011111111211111112155d111111111112111211121111111111111111111111111212121212121212120
11111111111100000003330000030000000000000001111111111111111111add111111111111111111111111111111111111111111111111111111111111110
111111111111000550003333333004444fffffffff00111111111111111111a00111111111111121112111111111111111111111112111111121212111112120
11111111111005505500333303004ffffffff0000000111111111111111111911111111111111111111111111111111111444111111111111121111112111110
1111111111005555055000303004f00000000ccccc00111111112111211121911111111111112111212111111111111114444411112111212222212121112110
111111111100555505500033004f0ccccccccccccc00111111111111111111111111111111111111111111111111111154fff451111111111121111112111110
11111111100505555055000004f0ccc1111cccc11100111111211111112111911111111111211121112111111111112144440001112121212121212121112120
1111111110000055505500000000c1111111cc111100111111111111111111111111111111111111111111111111111140000000000111111111111111111110
1111111110000055505500055550c11111cc11ccc100111111112111211121111111111121112121211121211111211140000000000121212121211121111120
1111111110000055505500005550c1111cc11000cc00111111111111111111711111111111111111111111111111111140ff00ff111121111111111121121110
1111111110050555505504000550cc11cc1109990000111111111121112111711111112111211111111111111111211154444451212222212121212221212120
11111111100055550555004f00000cccc10099999000111111111111111111711111111111111111111111111111111154454451111121111111111111111110
111111112100555505509904fff000ccc00999049001111121112111212111711111112121212111111121212121211194414491212121212121212121211110
1111111111000550505049900fff0000009990449001111111111111111111711111111111111111111111111111111194414491121111111211121111111120
11111111111000050500449990ffffff099904499011112111211121112111111111112121211111112121211211212190010091212121212121212111112110
1111111111110000500444499900000099994499940111111111111111111111111111111111111111111111222111119a919a91111111111111111111121110
1111211121112000000444444999999999944990940121212111212111111111111111211121212121111121121121219a919a91212121212121211111111120
11111111111111110040004444099999999499909401111111111111111111711111111111111111111111111111121119111911112112112222111112111210
11111111111000000404000994400909999999049401112111211121112111711111112111212111212121212121212121212121222221212121111111110000
11111111000000000444000099440090999990449400111111111111111111111111111111111111111111111111111117111711112111111111111111000000
21110000000000000044440009944009999090449030012121212121212121211111112121211111212121212121212121217771222221212121111122002020
11000000000333000044404000994400990904499030000222111111111111111111222111111111121111111211121117111711122112111211121000000200
10000000000333300004440400099444099044990033000002211121212121712121222121111111212122212121212177712121212121111111210000020020
00003033000333300bbbbbbbbbbbbbbb99bbbbbbbbbb0033bbbbbbbbbbbb111bbbbb1111bbbb11111111bbbbbbbb11bbbbbbbbbbb11211111111210000000000
00300333000033330b00b0000000000b99b000000000b033b0000000000bb12b000b212b000b1121212b0000000b21b000000000b22121212111100220000020
03033333300003333b00b0000000000b99b0000000000b03b00000000000b11b000b22b0000b121112b00000000b12b000000000b21112111111002982000000
00333333330003333b00b0000000000b99b0000000000b03b00000000000b17b000b2b00000b21212b000000000b21b000000000b12121111121002822000020
00003333330000333b00b0bbbbb0000b99b000bbbb000b00b000bbbbb000b17b000bb0000bbb1111b00000bbbbbb11bbbb000bbbb11221111112000220002000
00000033333000333b00b0000000000b99b000b99b000b00b000b001b000b12b0000000000b1212b0000000000b121212b000b21212212211120000000000220
55000000333300033b0000000000000b44b000b94b000b00b000b301bbbbb11b00000000000b12b00000000000b112111b000b11121221111120002000000200
55555000003330003b0000000000000b44b000b44b000b00b000b3002121212b00000000000b21b00000000000b121212b000b21212121211110200002002020
55555500000033000b0000000000000b44b000bbbb000b00b000bbbbbbbb111b000bbbbb000b11b0000bbbbbbbbb11121b000b12111211121210000000020000
55555550500000300b0000bbbbbbbbbb44b0000000000b00b0000000000b217b000b212b000b28b000000000000b21212b000b21212121211110202020202020
55555555055000000b0000b33300000000b0000000000b30b0000000000b121b000b121b000b18b000000000000b12121b000b12121211121210020202020200
55555555555550000b0000b33333300000b0000000000b30b0000000000b212b000b212b000b29b000000000000b21212b000b21212121111210202020202020
55555555555555500bbbbbb33333333333bbbbbbbbbbbb00bbbbbbbbbbbb111bbbbb111bbbbb99bbbbbbbbbbbbbb11121bbbbb12111211111112020288888200
55555555555555050000003333333333333333333333308888898000030021712121212121219a81212121212121212121212721212121212112002889998820
55555555555555505000000003333333333333333333089a88885550000002711211221112129821121212111212121217122722121212111212020888899800
555555555555bbbbbbbbbbbbbbb03bbbbb88883300000899855bbbbbbbb00bbbbbbbbbbb21bbbbbbbbbb2121bbbbbbbbbb2122bbbbbbbb212120202020888820
555555555555b00b0000000000b00b000b8998800000008855b0000000b00b000000000b11b000000000b112b000000000b211b0000000b21202000202088800
555555555555b00b0000000000b08b000b888880000000005b00000000b00b000000000b21b0000000000b21b0000000000b27b00000000b2220012020208820
555555555555b00b0000000000b88b000b88800000000005b000000000b55b000000000b12b0000000000b12b0000000000b12b000000000b202021202028800
555555555555b00b0bbbbb0000b89b000b0000000000000b0000bbb000b55bbbb000bbbb21b000bbbb000b21b000bbbb000b21b0000b00000b20212120008820
505505555555b00b0000000000b99b000b500000000000b00000000000b55555b000b11211b000b21b000b12b000b21b000b12b0000bb00000b2021212108800
055050000000b0000000000000ba9b000b5555bbbbb00b000000000000b55555b000b00121b000b12b000b21b000b12b000b21b0000b2b00000b222111218820
000000000000b0000000000000b99b000b5555b000b00b000000000000b55555b000b08882b000b21b000b12b000b21b000b17b0000b12b0000b021212128810
000000000000b0000000000000b88b000bbbbbb000b00b000000000000b55555b000b50988b000bbbb000b21b000bbbb000b27b0000b222b000b201121228120
000000000000b0000bbbbbbbbbb85b000000000000b00b000bbbbbb000b55555b000b55598b0000000000b12b0000000000b17b0000b122b000b021112128210
333333030000b0000b00888888555b000000000000b00b000b0000b000b55555b000b55598b0000000000b21b0000000000b22b0000b222b000b222122282220
303330300000b0000b00898855555b000000000000b00b000b5550b000b55555b000b55588b0000000000b12b0000000000b12b0000b121b000b028812122120
030333000000bbbbbb38988005555bbbbbbbbbbbbbb05bbbbb5550bbbbb55055bbbbb55580bbbbbbbbbbbb02bbbbbbbbbbbb21bbbbbb212bbbbb208881212210
00033300000080333338880000555555555000005555555555550000000005055555555885555555000555002212221217121712221212121212088982120020
00000000000888333388830000000555550000055555050005555000000000055555558855555500000005502221222127212721222122212221289982000000
30000000088880333388833300000005500000055550500000055555500000000588885555555000000000502222121217121212121212121212889880200200
333000008880003333883333330000000000005555550000000055888550000008898855555580000d0000502222212121222121212221222128898820222220
333300088800000333883333330000000000055000050000000008888855500088988005555880000d0000502212121217221212121212121288888212122220
333300889800000333883000000000000000055000050000000008899888888889880005558800000d0000502221222122212221222122212888882122222220
33330889880000033300000000000000000055550005000000000888999999999880000558800000000dd0501212122212121712128212128888121212122280
03333888800000000000000000000000000000555005000000000088889aa98888000000588000dd020000502121222227212722288888888882212221222280
03388898880333333300000000000000004400555555000000000000088998885000500058800000000000501212122212121212189a99888212121222222280
033889988833003333333300000000000994400055550000000000000088880055555500888000000d0000502222222122212221889998882222222222222880
008899888300003333333300000000009994440005555000000000000000000005555500898500000d0888821222221212121288899888222212121222228880
0889998880003333333030099999999999494444000555555000000000000000005555589998000008889a882122212227288888888822222222212222288880
8889a99800033333330300099999999999949444440005555888800080000000000055589a988008899889988882221217188988121222222212122222288820
8899999803333333333300049999994990999999944440588998880888000000000000589a998888999988888888222122218882222222222222222222888880
999a99883333033333300044999994944409999999998888888855508000000000000008999999a9999888222228221212121712122222221222222228888880
99aaa998833003333330004499999444444099994448899888555555000000000000008899899aaa998888222222212221222722222282222222222288882880
9aaaa9888330033333000844499444444444099498899988000555555500000000000888998999a9988000222212122212122222222888222222222888828880
9aaa9988883000333300888444444400004449488999880000000555555550000000888898899999988500002222222222222222222282222222888888888880
aaaa99888800003333000844444440000004448889988000000000555555550000088889989999998855550002222282222222222222228822288288228888e0
a7aa99898880003333000444444400000000888999880000000000000550555500888899889a999988555555500228882222222222288222288888822888eee0
777aa998988003333080044440000000000889999880000055500000000505555588899889aaa989880555555550088222222228228822228888888288eeeee0
777aa999888803888880044000000000088899a988800005555500000000555558889988999a99898000055055555508888882822882222828288888eeeeeee0
7777aa9999888889988004088000000088998aaa8888000555555000000000558899998999a9988980000005055555588888822228888288882288888e88ee80
77777aa9999899999800008800000008899899a98880000555555000000000088999999aa7aa989980000000555588888882222288e8888888888888888ee880
77777a7aa99999a99888888800000888899999998800000555555555000008889899a9aa7aa989988000000088888888880022288eee888888888e88e88e88e0
77777777aaa99aaa998898800000888899999989880000055055055550888889899aaa9aaa99998800000008888888899855008888888888888eeeeee88888e0
a777777aaaaa9aaaa9999988888888999a99989888000005550050558888899999a9a99aa999998000000888888889998885588888899888eeeeeee88888eee0
aaaa7aaaaaa99aaaaa99998889999999aaa999888990000505550508888999a9aaaaa9aaa99998800008888888899998888889999988888eee8eeee8888ee880
a9a777aaa99999aaa9a9a99888999a9aaaaa9888890000055055888899999a9aaaaaaa7a9a99980008888889899999888889999998888888e8eeee8888888890
99aa7aaaaa999aaaaaaa9a989899a9aaa7aa988890000005088888999999aaaaaaa9a7aaaaa988088888989899a999888999988888888ee88eee888888889990
999aaaaaaa999aa777aaa99999999aaa7aaa9880000000888888aa99999aaaaaa999aaa99a998888888999999aaa989899998888888800088888888899999990
999a99aaaaaa9a777777aa999999aaaaaaaa998008888888899aaaa99999aa998999aaa999a988888899999a99a9aa999a98899988888000888899999999aa90
a9aaa9aa9a7aaa7777777aaaa99aaaaa9aaa9988889999999a7aaa9a9999a99889999a999aaa888899999aaaaa9aaaa9aaa999988899888885899999999aaaa0
a99a9aaaa777a777777777a7aaaaaa999aaa9998a9999999a7777aaaa99a98888999aaa999a988899999aa7aa999aaaaaaa999999999888888899999aaaaaa90
999999aaaa7a7777777777777aaaaa9999a9999aaa99999aaa7777aa99a988888999aaa99999888999999777a9aa9aaaaaa99a99999888888899999aaaaaa990
99a99999aaaaa7aa7aa7a7a7aaaaaaa99a99999aa99aaaaaaaaa7a999998888999999a99999998899a999a7aaaaaa9a99aaaa9a99888899999999aaa7aaa9990
aaaa9aa999aaa99aaaaaaaa9999aaa99999999aaa9aa7aaaa99aa99988888898a999999999999999aaa9aaaa9aaaa99999aaaa99888899aa9999aaa777aa9980
99aaa9a99999999a9aaaaaaa999999999999999aaa7777a99988999899999999999999999a9999999aaaaaaa99aa9999999aa9998889999999a99aaa7aa99980
999a99aa99999999a999aaa99999998899a9999aa7777aa99888998a9998a9999999a999aaa999999aaaaaa9999999899999a998899999999aaa7a77aaa99980
99999aaaa888999999999a99999988999aaa9999aa79aa99888998aaa99aaa99999aaa999a99999999aaa99999999888999aaa9899999a99a9a777777a999980
999999aa88889aaaa9999999999889999aa99aaa999aa99888899899999aa9999a99a9999999999999999999999988888899a999a999aaaaaaa77777a9999880
888899988889a9aa9999999988889999aaaaaaa9999999888899899999aaaa99a9a998999999999989999989999988889999999aaa999aaaa9aa77777a998880
88889998889aaa9aa8899998888999999aa99a999999998888999999999aa9999999888999a99888889988889999888899999999a99aaaaa99997777aa888880
88999888899aaaaaaa889988888999999aaa999999999888889999999988999a999888899aaa988889888888889988899988999999aaaaaa99999799a9888890
9998888899999aaaa8888999888999999aa999999899888889999a99988999aaa9988899a9a99988999888899889889998899999999aaaa98899999999888990
8899989999999aa98888999998a9999999a99998889888999999aaa99899999a999aaa9aaaaa99889a98889aaa988898889999aaa9aa99998888999998888990
8999999999999998888999999aaa9999999998888999999999999a99899a9999a9aaa999aaa99999aaa889aaaaa9899889999aaa7aaaa99998888999888899a0
9999a99999999988889999999aaa8999999888889999a999aaa9aaa899a9999aaa99999aaa9a99999a98899aaa9a9988999999a777aa99aaa988888888889aa0
999aaa9899999989999999999aa88899888a9999999aaa9aaaaa9a999999999aaaa999aaaaaaa999999888999999998999999aaa7a999aaaaa899988888899a0
9999a999999999999999a9999988888888aaa9999899a9aaaaa99a9999999999a99aa9aaaaaaaa99999888899999a8899999aaaaaaa99aaaa8999998888899a0
99a999a99a99a99a999aaa9a9998888899aaa9999a999aaaaa99aaa99a9988999999aaaaaaaaa9999999888889998999999aaaa9aaaa9999899aa998899999a0
97799aaaaaaaaaaaa9aaa9aaa9a98a999aaa9a9999a9aaaa9a979a99aaa98899999aaaaaaaaa9999999999999999a99999aaaa999aaa999889aaaa9899999aa0
7777a9a9aaaaa79aaaaaa99aaaaa99999999aaa99aaaaaa9aa777a999a99988999a9aaaaaa7aa99a99999999999aaa999aaaaa9a99a99a999aaaa9999999aaa0
7777779aaa9a777aaa7a9aaaaaaa9999999aaa99aa7a7779a7777aa9aaa99988899aaaaaa777aaaaa9a999aa799aaaa999a9aaaaa999aaa99aaaa999999aaa90
7777777aa97a7777a7777aaaaaaaa9999aaaaa9aa7777777777777a77a9999999a9a7aa7aa777aaa9aaa7aa777aaaaaa9aa7aaaa7a7aaaa9aaaa9aa9aaaaaa90
77aa97aa7777777aaa7777a9a777a999aaaaa999aa7777777777777777999999aaa7777777a7aaa99aa777a77a97aaa9aa777a9777777aaa7aaaaaaa7aaaaa90
7a779aa7777777777a97777a777779aaaaa9999aa7777777777777777a99a999aaaa77777777aaaa7aa77a777a777a9aa777a79a777777a77779aaa777aaa9a0
70000000000000000000007777770000000000000000000000007770000000000000777777700000000000000000000aa7000700000000000000000000a00000
709990909009909990099070007009909990909099909990999077709990999099907777770099099909990099099907a7090709990999099909990990009900
709990909090000900900070907090009090909090909000909077700900909099907000070900090909090900090007aa090a00900009090909090909090000
7090909090999009009077700070900099009090990099009900777709009990909070990709990999099909070990777a090770900090099909900909099900
70909090900090090090007090709090909090909090900090907a7009009090909070000a000909000909090009000777090000900900090909090909000900
a090900990990099900990700070999090900990999099909090aa70990090909090a777770990090a0909009909990777099909990999090909090999099000
a0000000000000000000007aaaa00000000000000000000000007770000000000000aaaaaa0000000a0000000000000777000000000000000000000000000080
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__map__
7770660082323b655f666e2c313b725f74692c333b666f2c313b645f662c313b636f2c323b70726f6a5f666e2c313b6d61672c313b62752c313b6b6e5f722c313b775f63642c313b657366782c313b6b6e5f662c323b6d5f666e2c333b6465732c313b765f6d2c313b69642c313b6b6e5f742c333b646d672c313b6d7366782c
313b7370725f69676f640102303a302c333a362c302c31302c2d313a2d332c302c312c302c303a302c312e352c626c6f6f645f66782c352c332c317c303a302c353a352c302c362c2d323a2d322c302c302c302c303a302c312c736d6b2c322c322c327c303a302c353a352c302c382c2d323a2d322c302c302c302c303a302c
312e352c73736d6b2c312c332c347c303a302c343a352c302c392c2d313a2d322c302c302c302c303a302c322c616369645f66782c332c342c387c303a302c333a322c302c32302c2d313a2d312c302c302c302c303a302c332c736d6b2c342c372c31367c303a302c353a352c302c342c2d323a2d322c302c302c302c303a30
2c332c73736d6b2c362c352c3332706c64012231352c332c3131312c722c342c302c302c302c302c39302c312c3130342c3131332c312c39363a302c362c342c312c31312c2d312c312c3132372c3132363a302c312c38307c31352c31332c31372c6c2c342c302c302c302c302c34302c312c32342c31352c312c33323a302c
362c342c312c31322c312c322c322c313a302c302c38317c392c342c3131312c722c342c302c302c302c302c39302c3132322c3130342c3131332c3132322c39363a3132312c3132362c3132342c3132312c31302c2d312c332c3132372c3132363a3132302c312c38327c31352c362c31372c6c2c342c302c302c302c302c34
302c3132322c32342c31352c3132322c33323a3132312c3132362c3132342c3132312c372c312c342c322c313a3132302c302c383370616407ee352c70726f6a6d2c3330303a3630302c313023392c302e3939352c302e30312c303a302c303a302c307c352c70726f6a6f2c3130303a3130302c3823322c312c302c303a302c
303a302c307c352c70726f6a672c3336303a3336302c313123332c302e39392c302e30312c303a302c303a302c307c362c726f632c3138303a3138302c313123392c312c302c303a302c303a302c327c372c6c696d2c3432303a3432302c382331312c302e39392c302e30322c2d302e313a2d302e322c2d302e313a302e312c
327c372c6b6e6966652c3432303a3432302c3423372c302e3939392c302e3030372c303a302c303a302c327c342c726c70726f6a2c3132303a3132302c382c312c302c303a302c303a302c337c342c626c70726f6a2c3132303a3132302c31322c312c302c303a302c303a302c337c3123322c736d6b2c33353a34352c372336
233623352c312c2d302e3030352c2d302e333a2d302e322c2d302e31373a302e31372c30233123317c322c736d6b622c32343a33362c352c312c2d302e3030312c2d302e313a2d302e312c2d302e313a302e312c3223312331233023307c322c736d6b632c35323a36382c37233623352c312c2d302e3030312c2d302e313a2d
302e312c2d302e313a302e312c312330233023307c322c6475732c35323a36382c313523362c312c302e30312c2d302e313a2d302e332c2d302e32353a302e32352c31233123307c322c6865616c2c36303a39302c372337233723313123332c302e39392c2d302e3030372c302e30353a302e312c2d302e313a302e312c3023
3123317c322c6869742c31363a32322c313023372c302e37342c302c303a302c303a302c31233123307c322c726869742c383a31322c3823322c302e37352c302c303a302c303a302c31233123307c302c626c6f2c3132303a3138302c3823322c302e39392c302e3031352c2d302e333a2d302e322c2d302e31373a302e3137
2c307c3123322c6a70612c31323a31362c3723313023392c302e39382c2d302e30312c303a302c2d302e313a302e312c31233123307c302c6472742c393a39302c302c302e39382c302e30312c303a2d302e322c2d302e323a302e322c307c312c6d666c6d2c34303a36302c3723313023392338233223352c302e39392c2d30
2e30312c2d302e30323a2d302e30312c2d302e30373a302e30372c307c322c666c6d2c33333a36362c3723313023313023392339233823322c302e39392c2d302e3031332c303a302c2d302e323a302e322c3123312331233123307c3023342c7370612c34353a38352c3723313023392338233523302c302e39382c302e3031
2c2d302e323a2d302e342c2d302e353a302e352c312332233223317c302c6163692c3132303a3138302c313123332c302e3937352c302e30322c2d302e353a2d312c2d302e353a302e352c307c312c736369622c31323a31362c372331322331332c302c302c303a302c303a302c3523332332233123307c312c736369722c31
323a31362c37233823322c302c302c303a302c303a302c3523332332233123307c312c736369312c31323a31362c302c302c302c303a302c303a302c3523332332233123307c312c736369322c31323a31362c372c302c302c303a302c303a302c313323313123392337233523332332233123307c332c737371312c31323a31
362c372c302c302c303a302c303a302c3523332332233123307c332c737371322c31323a31362c372c302c302c303a302c303a302c313323313123392337233523332332233123307c342c736c69312c34303a34382c372c302e39352c302c303a302c303a302c33233223317c342c736c69322c34343a35322c372c302e3935
2c302c303a302c303a302c3523342333233223317c312c73686f312c383a31322c372c302c302c303a302c303a302c302331233223332335233723397c312c73686f322c31323a31362c372c302c302c303a302c303a302c30233123332335233723392331312331332331352331377c312c7273686f312c383a31322c372338
23322c302c302c303a302c303a302c302331233223332335233723397c312c6273686f312c383a31322c372331322331332c302c302c303a302c303a302c302331233223332335233723397c312c6773686f322c31323a31362c3723313123332c302c302c303a302c303a302c30233123332335233723392331312331337c32
2c626c6f312c31323a31362c372331302339233823322c302e36362c302c303a302c303a302c32233323327c322c626c6f322c31323a31362c372331302339233823322c302e36362c302c303a302c303a302c3323342335233323327c322c666c73312c363a382c3723313023392c302e36362c302c303a302c303a302c3023
3123307c322c666c73322c383a31322c3723313023392c302e36362c302c303a302c303a302c322333233223317c322c72666c73312c31323a31362c37233823322c302e36362c302c303a302c303a302c31233223317c322c72666c73322c31323a31362c37233823322c302e36362c302c303a302c303a302c32233323327c
322c62666c73312c31323a31362c372331322331332c302e36362c302c303a302c303a302c31233223317c322c62666c73322c31323a31362c372331322331332c302e36362c302c303a302c303a302c32233323327c322c67666c73322c31323a31362c3723313123332c302e36362c302c303a302c303a302c32233323327c
312c70726f6a312c3330303a3332302c3723392c302e3939372c302e30312c303a302c303a302c306d65660031313b636f6c5f772c333b706f732c313b69642c31313b696478732c31313b726f77732c313b6964782c31323b6974656d73746264015b6d736773233223313b737061776e20696e20312c323b737061776e2069
6e20322c333b737061776e20696e20332c343b6a6f696e208e2f977c6f626a5f6e756d73233523313b33403540372c323b30403340352c333b32403440367c6d61705f636f6c73233523313b3132394034403340352c323b3132384034403940302c333b3133304035403340342c343b313333403040334031312c353b313330
403240313440382c363b3132394031334031324031352c373b3133334035403440302c383b3132384035403640302c393b3133324035403040367c67726f757073233523313b31403240332c323b34403540362c333b37403840392c343b31304031314031324031332c353b3135403134403136403137403138403139403230
4032314032324032334032344032354032364032374032384032394033304033312c363b33324033334033344033354033364033374033384033394034307377660036313b6e6f2c31323b666e732c31313b636f6c732c313b69642c313b66696c7465722c31323b6678732c31313b665f732c343b6d756c746d6564012c3237
2c31343a35392c312c32233223322332233223312c34233423342334233423312c312c6d6f646523776172236172656e61236368616f732374696d6523332336233923626f78657323666577236d6f7265236c6f7473237472617073236e6f6e6523666577236d6f726523626f7473236c616d6523746f75676823626f737323
656e746572207468652077617374656c616e64737c33302c343a35392c322c32233223322331233123312c34233423342331233123312c312c64656e73697479236c6f7723636f7a79237374756666656423736861706523636176652363616e796f6e2369736c616e642366616272696323656172746823766f696423727569
6e73237465727261666f726d23656e7465722074686520626174746c65236261636b20746f2062617365706c6600b1313b63332c313b63322c313b616d6d6f5f782c323b696e642c313b6d73672c313b7363722c343b636f6e6e2c343b736f6c646965722c313b7370776e2c313b7363725f782c313b7363725f792c313b6870
5f78322c313b68705f78312c313b6d73675f792c333b775f706f732c313b616d6d6f5f792c313b68705f79322c313b68705f79312c313b63312c313b6261725f642c313b69642c313b6d73675f782c333b706f732c343b6c2c313b7370725f697370640933353a352c3131383a302c323a3223303a3023303a3023343a347c35
3a352c3132333a302c323a3223303a3023303a3023343a347c353a352c3131383a352c323a3223303a3023303a3023343a347c353a352c3132333a352c323a3223303a3023303a3023343a347c353a352c3131383a31302c323a3223303a3023303a3023343a347c353a352c3132333a31302c323a3223303a3023303a302334
3a347c343a352c3131383a31352c313a3223303a3023303a3023333a347c343a352c3132323a31352c313a3223303a3023303a3023333a347c343a352c3131383a32302c313a3223303a3023303a3023333a347c333a322c3132323a32302c313a3123303a3023303a3023323a317c333a322c3132353a32302c313a3123303a
3023303a3023323a317c333a322c3132323a32322c313a3123303a3023303a3023323a317c333a322c3132353a32322c313a3123303a3023303a3023323a317c3130343a32382c303a302c303a307c31333a372c303a32382c363a307c323a332c3132353a32382c313a3223303a307c333a342c3132353a33312c303a332332
__sfx__
b40100010c36000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
01030000286550f355236350c35509600096000960009600096000960009600096000960009600096000960009600096000960009600096000960009600096000960009600096000960009600096000000000000
8d0700022445530235244553023500205002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
090d00031843018411304150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e1d002bb402eb402eb2130b402bb422bb2229b4027b4027b3227b2229b402eb402bb402bb322bb022eb4030b4130b3130b2118b0130b002eb402eb302bb402bb3027b4027b3224b4122b3000b0000b0000b00
010e1d000c8400c8250c8400c82100025001350c8400c82100135000250f8400f8210f03500525033150a8400a8250a8400a8210a0350a1250a8400a8250a8400a821003151602507824078310c8000000000000
010e1d00118401182511840118210502505135118401182105025051350f8400f8210f13500025071350c8400c8250c8400c8210712500025001350c8400c8250c8400c821001350f8240f8310c8000c80000000
000e1d00118401182511840118210c8000c80011840118210c800000000f8400f8210c8000c800000000c8400c8250c8400c8210c80000000000000c8400c82513840138210000007824078310c8000c80000000
010e1d000c8400c8250c8400c82100025001350c8400c82100135000250f8400f8210f03500525033150a8400a8250a8400a8210a0350a1250a8400a8250a8400a82100315160250f8240f8310c8000000000000
150e1d000c0200c0250c0200c02100025000250c0200c02100025000250f0200f0210f02500025030250a0200a0250a0200a0210a0250a0250a0200a0250a0200a021000251602507024070210c0000000000000
010e00000c00318a001ba0000000189251da0018a000c00318a00222041ba000c00318925189051820418a000c00318a000c00318925189051da000c003182040c003189250c0031892500000000000000000000
010e1d000c05318a301ba2018a241892518a300c05318a20222141ba400c0331da20189251821418a300c05318a200c0331ba301892518a251da400c033182140c0331892518a40189250c023000000000000000
010e1d002eb4030b4033b4033b4033b3133b2227b4024b4024b3024b2224b4027b4029b4029b352bb0227b4024b4124b3124b2118b0130b0024b4022b301fb401fb301db401fb3022b4027b3000b0000b0000b00
010e1d002bb402eb402eb2130b4030b3230b222eb402bb402bb302bb2229b4027b4029b4029b352bb0227b4024b4124b4124b3124b3530b0030b4030b302eb402eb3029b4029b3027b4124b3000b0000b0000b00
010e1d002eb4030b4033b4030b4030b3130b222bb4029b4029b3029b2229b4027b4029b4029b352bb0227b4024b4124b3124b2118b0130b0024b4027b3027b4029b302bb402eb3030b4033b3000b0000b0000b00
01101d0035b5035b5035b4135b4035b3135b3035b2129b5029b5029b4129b4029b3129b3029b212bb502bb502bb502bb412bb402bb402bb312bb302bb302bb212bb202bb202bb112bb152bb14000000000000000
7d101d000c00035b2035b2035b2135b2035b2135b2035b2129b2029b2029b2129b2029b2129b2029b212bb202bb202bb202bb202bb202bb202bb202bb202bb202bb202bb202bb202bb202bb2024b050c0000c000
310e00003cb503cb503cb503cb403cb403cb403cb303cb303cb203cb203cb103cb103cb103cb143cb153cb143cb153cb140c0000c0000c0000c0000c0000c0000c0000c0000c0000c0000c0000c0000c0000c000
01101d0035b5035b5035b4135b4035b3135b3035b213ab503ab503ab413ab403ab313ab303ab2137b5037b5037b5037b4137b4037b4037b3133b5033b5033b4133b4033b3133b3033b2133b20000000000000000
19101d000000029b1029b1029b1129b1029b1129b1029b111db101db101db111db101db111db101db111fb101fb101fb111fb101fb111fb101fb1118b0018b0018b0118b0018b0118b0018b0118b050000000000
01101d0035b5035b5035b4135b4035b3135b3035b2137b5037b5037b4137b4037b3137b3037b213ab503ab503ab503ab413ab403ab403ab303bb403bb403bb313bb303bb203bb213bb153bb14000000000000000
19101d000000029b1029b1029b1129b1029b1129b1029b111db101db101db111db101db111db101db111fb101fb101fb111fb101fb111fb101fb1118b0018b0018b0118b0018b0118b0018b0118b050000000000
010e1d00118401182511840118210502505135118401182105025051350f8400f8210f135000250713513840138251384013821071250702507135138401382513840138210713507824078310c8000c80000000
350e1d00000002bb102eb102eb1130b102bb102bb1229b1027b1027b1227b1229b102eb102bb102bb152bb022eb1030b1130b1130b1118b0130b002eb102eb102bb102bb1027b1027b1024b1122b1000b0000b00
00010000190311a0311a0411a0411a0311a001300012e0012c00327003260032005324063280632b0732c0732c0732d0732e0732e0032e0032d00313003130031500315000140001400014000140001500015000
00010000155341d552295750050002500215000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
00010000150741b052290450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002d5242d5312d54100500005001c5611c5611c5511c5511c53500500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100002d0502d0502d0502d0502d0500000000000000000000000000000000000000000000002d0502d0502d0502d0502d0500000000000000000000000000000002d0502d0502d0502d0502d0502d0502d050
01010000246312b6412c6512e6613566136671366713a6713a6713c6713b6713b6713a671396713966139661386623766234662316522d6522b642236421d632196321b6221d6221a61218612126120060000600
0001000021010270102d6102b6202862028620296302b6402d6402e6402e63028630246201d620126101060000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000000001d010210202303027030290402d04030140311503465037660396603c6703c6703a670396703867037670366703667034660306602d6502b65026640236401f6301e6301b620166201461000000
00010000301203113032140321503316032170311702e1602b140316003160026130291502f170121000c10012100111002260023600246002460025600266002660028600296002260022600226000060000600
000100001863019640196501c6001b60018600146000e6400d6200c6100c6000c600006000b6000b6000860006600066000000000000000000000000000000000000000000000000000000000000000000000000
00010000221512415122151221510010000100004000040000400004000040018152181521a1521f15222152251552a1552e15033150361503715036150361500040000400004000040000400004000040000400
000200001561018620196201b6201b6201b6201b620216202163021630226201a6201a62019620196200662006630066301462012620116100e6100c6100c6000860007600076000860008600086000860008600
000100002f0502f06005070060400f0202e3000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
00010000156101d630020400304003040030303203033020320202e0102c010331000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000100002b6602b6602a6602a650296302863028620286202462016620000000000000620006200d6200d6200e6201362015630196301c64023650286602b6602d67030670336703567036670366703666036650
0001000027520345503a5703b560365502654023530225201e5201f5201f5201f5301f540205501e5501c5401952015520145501d5001c5001c5001b5001a5001a5001850016500135000f5000a5000650000500
000100002f3302f33000300173700c37005370003003b3403c3403130031300313003130000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000200003065030650306503065030650000003165031650046000460004650046500365005600056000460000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002f52035530375403854038540375403554007540075500755007550075502b56029560285602755026540255302553000500005000050000500005000050000500005000050000500005000050000500
00010000185201c5301f54020540085400d5502b5503155031550355500c5500f5503755037550385503855037540375200102000020000500205001050000500005001040010100000000000000000000000000
000200002a6122b6222b6222c6222c6322c6412c6512c6712c6712b6512b6412b6312b6312b6212b6212b6212b6212b6212a6212a6212a6232a6232a6232962327623276132761326613276002b6002b6002b600
0001000024610266102b6302c6302263024630226301e62028620266202561022610316002c60029600246002160024600266002c6002f60031600316002c6002a60028600236001f6001d600000000000000000
0001000016060190701e0500000000000000000000000050000700007000070010700207002060020500205001040010400004000030000300103001020000100005000050000000000000000000000000000000
000100001125022270222500000000000072200623006230062400525005260062700627006270062700627006260062400000000000000000000000000000000000000000000000000000000000000000000000
0001000003250032500325003250032500325002250000000000000000000000d0300d0500d0500d0700d0700d0700e0700e0700e0700e0600e0400e040000000000000000000000000000000000000000000000
00010000106201162000000000001a6201b6202f6102e610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101000005662076720a672096720966209652086320762225600256000502205022020620207224600156000060015600146001460014600116000c6000a6000960008600086000860008600086000860008600
010100000503605046000060000008616096260a63632656326613166130651062000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000291102c11031120301303314036150361503615035160351603516036170361703717037170341703216036150361503714038140391303a14039140371503815036150351603716039160391603b160
0002000028703297502975029750297500c7000a7000070029700297002970029700287002975029750297502975029700297002970029700287002f000200502005020050200502005020050200502005020050
000200001a5501a5501a550215000950022550225502255022550225500550008500265502655026550265502655004500045001e5521e5521e5521e5521e5521e5521e5521e5521e5521e5521e5521e5521f552
010100003041233432234422d442314520d4623247232462104420d43200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102000024421284412d451314623247234472324122741228422294222b4222d4322e4312e4312f4312f4313143231432324423244236442394413b4413c4413c4413c4513c4513c4513c4623e4623f4423d412
__music__
00 0d094d44
00 0d094344
00 0d090e44
00 0d090e44
00 0f090d55
01 0f090d44
00 0f090d44
00 0f090d44
00 0f09081b
00 0f09101b
00 0f09111b
00 0f09121b
00 0f0a1314
00 0f0a1314
00 0f0a1614
00 0f1a1814
02 0f090d15

