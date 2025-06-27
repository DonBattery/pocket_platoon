pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- a PICO-8 party game
-- for up to 4 buddies

-- environment utility
_g = _ENV
function env(o)
 return setmetatable(o, { __index = _ENV })
end

-- no operation
function nope() end

-- random numbers
function rand(l, h) return rnd(abs(h - l)) + min(l, h) end
function randint(l, h) return flr(rnd(abs(h + 1 - l))) + min(l, h) end
function jitt() return randint(-1, 1) end

-- pretty print with shadow or outline and indention
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

-- simple table sort
function sort(t, cond)
 for i, ti in inext, t do
  for j, tj in inext, t do
   if cond(ti, tj) then
    ti, t[i], t[j] = tj, tj, ti
   end
  end
 end
end

-- turn every color to a specified one (flashing effect of sprites)
function pal_spec(v)
 for i = 0, 15 do
  pal(i, v)
 end
end

-- reset the palette and set transparency (black is opaque and pink is transparent)
function ppal()
 pal()
 palt(0b0000000000000010)
end

-- 2d vector class
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

-- point collide with rect
function p_coll(p, r)
 return not (p.x < flr(r.pos.x) or flr(p.x) > r.pos.x + r.size.x - 1 or p.y < flr(r.pos.y) or flr(p.y) > r.pos.y + r.size.y - 1)
end

--  rect collide with rect
function r_coll(a, b)
 return not (a.pos.x + a.size.x - 1 < flr(b.pos.x) or flr(a.pos.x) > b.pos.x + b.size.x - 1 or a.pos.y + a.size.y - 1 < flr(b.pos.y) or flr(a.pos.y) > b.pos.y + b.size.y - 1)
end

-- get the list of points between two coordinates, using bresenham's line algorithm
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

-- joystick
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
    press, prev = down and not prev, down
    return down
   end
  })
 end
 return j
end

-- data decoders
-- convert one element based on type and value strings
function conv(type, e)
 return type < 3 and e or type == 5 and split(e, "@") or type == 3 and v2(unpack(split(e, ":"))) or e == 1
end

-- decompress string data and call a function on each record (or just on a specific one if id is specified)
function use_data(format, data, cb, id)
 local fields, records = {}, split(data, "|")
 for field in all(split(format)) do
  add(fields, split(field, ";"))
 end
 local function decode(record)
  local o, tags = {}, split(record)
  for i, field in pairs(fields) do
   local type, key = unpack(field)
   if type < 10 then
    o[key] = conv(type, tags[i])
   else
    o[key] = {}
    for elem in all(split(tags[i], "#")) do
     add(o[key], conv(type % 10, elem))
    end
   end
  end
  return cb(o)
 end
 if id then
  return decode(records[id])
 end
 local o = {}
 for record in all(records) do
  add(o, decode(record))
 end
 return o
end

-- constructor functions to build objects and functions from data records
-- build a menu
function menu_c(o)
 o.draw, o.get= function(_ENV)
  for p in all(players) do
   if p.conn then
    local j = p.joy
    idx = mid(1, idx + (j.u.press and -1 or j.d.press and 1 or 0), #idxs)
    idxs[idx] = mid(rows[idx] > 1 and 2 or 1, idxs[idx] + (j.l.press and -1 or j.r.press and 1 or 0), rows[idx])
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
 end,
 function(_ENV, id) return idxs[id] - 1 end
 return env(o)
end

-- build a sprite
function sprite_c(o)
 -- maintain a list of flipped points for fast drawing of mirrored sprites
 o.flip, o.get_p, o.draw= {},
 function(_ENV, pos, i, f_x, f_y)
  local base, base_flip = pts[1], flip[1]
  local orig = v2(pos.x - (f_x and base_flip.x or base.x), pos.y - (f_y and base_flip.y or base.y))
  if not i or i == 1 then return orig end
  local pt, pt_flip = pts[i], flip[i]
  return v2(orig.x + (f_x and pt_flip.x or pt.x), orig.y + (f_y and pt_flip.y or pt.y))
 end,
 function(_ENV, pos, f_x, f_y)
  local orig = get_p(_ENV, pos, 1, f_x, f_y)
  sspr(spos.x, spos.y, size.x, size.y, orig.x, orig.y, size.x, size.y, f_x, f_y)
 end
 for p in all(o.pts) do
  add(o.flip, (o.size - v2(1, 1)) - p)
 end
 return env(o)
end

-- build an animator from a group id. a group is a list of animations belonging to one object
function new_anim(group_id)
 local a = env({
  gid = group_id,
  -- the animator maintain its own flipped states
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

-- build a player
function player_c(o)
 o.joy, o.upd, o.draw = joy(o.id - 1),
 function(_ENV)
  joy:upd()
  -- the players can connect in any stage of the game, except when the menu is on cooldown
  if not conn then
   if (joy.o.press or joy.x.press) and not cd.menu then
    sfx(28)
    conn, cd.menu = true, 10
   end
  else
   -- if the game is running handle the respawning of the player's soldier
   if state == 3 then
    if spwn > 0 then
     spwn -= 1
     msg = flr(spwn / 60) + 1
     if spwn == 60 then
      local spot = w_spot()
      local s = sold(_ENV, spot)
      spawn_fx(spot, s, "sci", 2, { 7, c1, c2 })
      schedule(
       56, function()
        soldier = s
        w_add(soldier)
       end
      )
     end
    elseif not soldier then
     spwn = 180
    end
   end
  end
 end,

 function(_ENV)
  -- if not connected or the soldier is respawning display the message
  if not conn or spwn > 0 then
   pprint(msgs[msg], msg_x, msg_y, c1, 0, ind)
  end
  if conn then
   local c = c3
   if soldier then
    -- based on the amount of hp left, set the skin color of the portrait
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
   -- portrait sprite
   if spwn == 0 then
    pal(1, c)
    sprites[spr_i]:draw(pos)
    ppal()
   end
  end
 end

 return env(o)
end

-- build a weapon
function weapon_c(o)
 o.shoot, o.get_m_pos, o.draw, o.draw_p = function(_ENV, pos, aim, ow, te, l)
  sfx(msfx)
  -- soldiers can aim in 8 direction with a string, enemies can aim in any direction with a vector
  if type(aim) == "string" then
   pos, aim = get_m_pos(_ENV, pos, aim, l), aims[aim].v2_mod + v2(0, (aim == "e" or aim == "w") and -v_m or 0)
  end
  -- add the muzzle effect and the projectile(s) to the particle system
  _g[m_fn](pos)
  _g[proj_fn](pos, bu, aim, fo, 0, co, nil, nil, upd_proj, ow, te, _ENV)
  return w_cd
 end,

 -- get the muzzle's position based on the current animation frame, aim and direction (facing left or right)
 function(_ENV, pos, aim, l)
  return sprites[1 + spr_i + aims[aim].sp_i]:get_p(pos, 2, aim == "n" and l or aim == "s" and not l or aims[aim].f_x, aims[aim].f_y)
 end,

 -- draw the weapon relative to a position (soldier's hand), with an aim and direction
 function(_ENV, pos, aim, l)
  sprites[1 + spr_i + aims[aim].sp_i]:draw(pos, aim == "n" and l or aim == "s" and not l or aims[aim].f_x, aims[aim].f_y)
 end,

 -- draw the portrait sprite of the weapon
 function(_ENV, pos, l)
  sprites[spr_i]:draw(pos, l)
 end

 return env(o)
end

-- acquire target around an object, in a radius (include object by filter, exclude object by owner)
function acq_tar(_ENV, r, filter, owner)
 tars = w_get(_ENV, r, filter)
 for tar in all(tars) do
  if (tar._ow == owner) del(tars, tar)
 end
 if #tars > 0 then
  -- return the closest target
  sort(tars, function(a, b) return a.pos:sqrdist(pos) < b.pos:sqrdist(pos) end)
  return tars[1]
 end
end

-- update a projectile
function upd_proj(_ENV)
 -- get the objects around the projectile and cast a ray between its current and next position
 local objs, pts, w_i, hit_obj, hit_ground, prev = w_get(_ENV, 64, 0), ray(pos, n_pos), we.id

 -- heat seeking missile
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
    acc.x, acc.y = d.x < 0 and -0.1 or d.x > 0 and 0.1 or 0, d.y < 0 and -0.1 or d.y > 0 and 0.1 or 0
    spd:limit(.6)
   end
  end
 end

 -- walk over the ray
 for i = 1, #pts do
  p = pts[i]

  -- if the projectile hit any object (units cannot hit themselves with new projectiles for 16 frame)
  for o in all(objs) do
   if p_coll(p, o:get_hb()) and (life > 16 or o._ow ~= ow) then
    hit_obj = o
    break
   end
  end

  if not hit_obj then
   local nc = get_px(p.x, p.y)
   -- if the projectile hit the ground (except for flamethrower, which has a chance to go through the ground)
   if (nc ~= 1 and nc ~= 17) and (w_i ~= 7 or rnd() < .3) then
    life += 10
    prev = i > 1 and pts[i - 1] or p
    -- grande bounces off the ground
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
     -- knife creates colored pixels
     if w_i == 2 then
      set_px(p.x, p.y, 7)
      set_px(prev.x, prev.y, 4)
     end
     -- molter blobs stick to the ground
     if w_i == 10 then
      spd, acc = v2(), v2()
     end
     break
    end
   end
  end
 end

 -- decide if the projectile should explode (grande and molter blob explodes on expire too)
 if hit_obj or (hit_ground and w_i ~= 10) or (eol and (w_i == 8 or w_i == 10)) then
  eol = not (w_i == 9 and hit_ground)
  -- flamethrower alters the color of hit pixels
  if w_i == 7 and hit_ground then
   set_px(hit_ground.x, hit_ground.y, rnd() < .25 and 1 or 0)
  end
  impactor(hit_obj, hit_ground or p, spd, we.kn_f, we.kn_r, we.kn_t, 1.1, we.dmg, ow, te, we.e_fn, we.esfx, randint(we.des.x, we.des.y), we.d_f)
 end
end

-- update spawners
function upd_spwn()
 local spwn = spwns[spwn_i]
 -- decide the maximum number of object from the current category (in War mode enemies are multiplied by 1.5)
 local max_obj = obj_nums[spwn_i][menus[1]:get(spwn.id)] * (spwn.mult and menus[1]:get(1) == 1 and 1.5 or 1)
 -- if there is not enough objects, roll D4 and spawn a new one on 1
 if #w_get(nil, 0, spwn.filter) < max_obj and rnd() < .25 then
  local spot, i = w_spot(), randint(1, spwn.no * 2 - 1) \ 2 + 1
  local o = _g[spwn.fns[i]](spot)
  spawn_fx(spot, o, spwn.fxs[i], spwn.f_s[i], { spwn.cols[(i - 1) * 2 + 1], spwn.cols[(i - 1) * 2 + 2] })
  schedule(
   50, function()
    w_add(o)
   end
  )
 end
 -- step to the next category, skip enemies in Arena mode
 spwn_i = (spwn_i % (menus[1]:get(1) == 2 and 2 or 3)) + 1
 schedule(randint(20, 30), upd_spwn)
end

-- update countdown, play sound if just 10 seconds left, end game if time is up
function upd_countdown()
 countdown -= 1
 if countdown == 10 then sfx(57) end
 if countdown == 0 then
  sfx(58)
  state, cd.menu = 4, 180
  for o in all(w_get(nil, 0, 1)) do
   players[o._ow].soldier = nil
   o.rem = true
  end
 end
 schedule(60, upd_countdown)
end

-- map
-- get a pixel's color from the map, if the coords are outside we will get 17 on sides and top, and 16 on bottom
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

-- set a pixels color on the map, if the coords are outside nothing will happen
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

-- check if a rectangle is free on the map (only contains air)
function free(p, s)
 for x = p.x, p.x + s.x - 1 do
  for y = p.y, p.y + s.y - 1 do
   if (get_px(x, y) ~= 1) return false
  end
 end
 return true
end

-- generate a map using a cellular automata
function gen_map()
 pprint("chaos emerges,", 24, 26, 11, 0, "l", true)
 pprint("last war approaches", 28, 35, 11, 0, "l", true)
 hud()
 -- we need to flip the above text and hud onto the screen, because this function takes about 2.5 sec to complete
 flip()
 -- decide the strength, density, shape, fabric and colors of the map
 local m = menus[2]
 local den, sha, fab = .465 + m:get(1) * .015, m:get(2), m:get(3)
 w_str, map_done, bg_col, b_col, hi_col, dmg_col = fab * .2, true, unpack(map_cols[(fab - 1) * 3 + randint(1, 3)])
 -- create the map and a temp map in memory and fill them with noise (based on density and shape)
 local map, tmp = {}, {}
 for x = 0, 131 do
  map[x], tmp[x] = {}, {}
  for y = 0, 115 do
   map[x][y] = ((x < 2 and sha == 1 or x > 129 and sha == 1 or y < 2 and sha < 3 or y > 112 or rnd() < den) and 1 or 0)
   tmp[x][y] = map[x][y]
  end
 end
 -- run the cellular automata 3 times, (this will make walls stick to other walls, and air to other airs)
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
 -- write the map directly into user memory (we will use memcpy to draw the map onto the screen)
 for y = 0, 111 do
  for x = 0, 126, 2 do
   local col = { 1, 1 }
   for p = 0, 1 do
    if map[x + p + 2][y + 2] == 1 then
     -- determine the color of the pixel
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

-- increase level of drama, shake camera if too much drama
function drama()
 drama_v += 6
 drama_t = 0
 if drama_v >= 7 then
  drama_v, cd.shake = 3, 12
 end
end

-- game object
function gob(id, p, _on_imp, _on_upd, _on_b_draw, _on_a_draw, _on_die, _on_land)
 return use_data(
  gof, god, function(o)
   o.pos, o.l, o.on_imp, o.on_suf, o.on_upd, o.on_b_draw, o.on_a_draw, o.on_die, o.on_land, o.anim, o.cd, o.get_hb, o.upd, o.step, o.cango, o.imp, o.draw = p, rnd() < .5, _on_imp,_g[o.suf], _on_upd, _on_b_draw, _on_a_draw, _on_die, _on_land, new_anim(o.a_id), { hit = 12 },
   -- get hitbox
   function(_ENV) return anim:get_hb(pos) end,
   -- update
   function(_ENV)
    if rem then return true end
    anim:upd()
    for k, v in pairs(cd) do
     cd[k] = v > 0 and v - 1 or nil
    end
    -- suffer if low hp
    if (hp < lhp and rnd() < .01) on_suf(pos, hp < ulhp and 2 or 1, spd, v2(.3, .6))
    -- check if we are in the air
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
    -- set gravity, friction and speed limit if movement is not forced
    if not cd.f_move then
     if ground then
      gra, fri, slim = 0, .96, .45
     else
      gra, fri, slim = .06, .98, .85
     end
    end
    -- update the speed with acceleration (provided by custom update fn, passive objects just return the gravity here)
    spd += on_upd(_ENV)
    spd:limit(slim)
    spd *= fri or 1
    -- slow object will eventually stop
    if (abs(spd.x) < 0.005) spd.x = 0
    if (abs(spd.y) < 0.005) spd.y = 0
    -- cast a ray to the next desired position
    local n_pos = pos + spd
    local pts = ray(pos, n_pos)
    local l = #pts
    -- walk the ray and check for collision and resolution
    if l > 1 then
     for i = 2, l do
      local prev = pts[i - 1]
      local can, block, res = step(_ENV, prev, pts[i] - prev)
      if not can then
       -- climber objects (the soldier) are stick to the ground, and may climb slopes, while non climbers (everything else) are bounce back
       spd.x *= (not cli and block.x == 0) and -.8 or block.x
       spd.y *= (not cli and block.y == 0) and -.75 or block.y
       n_pos = (res and res or prev) + v2(.5, .5)
       break
      end
     end
    end
    -- set current position
    pos = n_pos
   end,
   -- check if the object can move from one point in the ray to the next
   -- if not, offer a resolution if possible, if not possible stop the object
   function(_ENV, pos, dir)
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
        -- climber objects can try to climb 2 pixel tall slopes
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
   end,
   -- decide if one step is possible or not by checking just the relevant edges for blocking pixels
   function(_ENV, pos, dir)
    if (dir.x ~= 0 and not free(pos + off + (dir.x < 0 and v2(-1, dir.y) or v2(si.x, dir.y)), v2(1, si.y))) return false
    if (dir.y ~= 0 and not free(pos + off + (dir.y < 0 and v2(dir.x, dir.y) or v2(dir.x, si.y)), v2(si.x + abs(dir.y) - 1, abs(dir.y)))) return false
    return true
   end,
   -- apply impact on object, by forcing its movement and dealing damage
    function(_ENV, ow, te, fo, dmg, ti, limit)
    if rem then return end
    spd += fo
    cd.f_move, slim = ti, limit
    hp -= on_imp(_ENV, ow, te, fo, dmg)
    if hp <= 0 then
     rem = true
     drama()
     on_die(_ENV, ow, te, fo)
    end
   end,
   -- draw the object's animator with a possible before and after draw call
    function(_ENV)
    if on_b_draw then on_b_draw(_ENV) end
    anim:draw(pos)
    if on_a_draw then on_a_draw(_ENV) end
    ppal()
   end
   -- set animator's direction
   o.anim.f_x = o.l

   return env(o)
  end, id
 )
end

-- apply the impact of a force with sound, particle effect, terrain destruction, object movement and damage
function impactor(obj, pos, dir, fo, r, ti, lim, dmg, ow, te, fx_fn, sfx_i, des_s, des_f)
 -- sound and particle effect of the impact
 sfx(sfx_i)
 _g[fx_fn](pos, 1, dir, v2(fo, fo))

 -- destruction of the terrain
 -- make a list of destructors {{size, force}}
 local list = { { des_s, des_f } }
 -- add a smaller, stronger destructor to bigger ones
 if des_s > 2 then add(list, { des_s - 2, des_f * 1.5 }) end
 for i = 1, #list do
  local particles, size, str = 0, unpack(list[i])
  -- apply a small jitter to even sized destructors
  if size % 2 == 0 then pos += v2(jitt(), jitt()) end
  for p in all(destructors[size]) do
   local x, y = pos.x + p.x, pos.y + p.y
   local c, new_c = get_px(x, y), 1
   if c ~= 1 and c < 16 then
    -- based on the world and the destructor's strength decide if the pixel should be damaged or destroyed
    if rnd() > str - w_str + (c == dmg_col and .3 or 0) then
     new_c = dmg_col
    end
    -- the first 7 destructed pixel will be added to the particle system as dirt, the subsequent pixels has less and less chance to be added.
    if ((c ~= dmg_col) or (new_c == 1)) and rnd() < (particles < 7 and 1 or 1 - (particles - 7) / 20) then
     particles += 1
     drt(v2(x, y), 1, dir * (rnd() < .25 and -1 or 1), v2(.2, .7), 0, 0, nil, { c })
    end
    set_px(x, y, new_c)
   end
  end
 end

 -- if an object is given apply the impact on it
 if obj then
  obj:imp(ow, te, dir:norm() * fo, dmg:ab(), ti, lim)
  -- if a radius is given apply the impact on all objects in that radius (full impact in the center, less in the edges)
 elseif r > 0 then
  for o in all(w_get({ pos = pos }, r, 0)) do
   local str = 1 - pos:sqrdist(o.pos) / r
   local f = (o.pos - pos):norm() * str * fo
   o:imp(ow, te, f, dmg:ab() * str, ti * str, lim)
  end
 end
end

-- if the object is being hit alter its palette
function get_hit(_ENV)
 if cd.hit then pal_spec(hp > lhp and 7 or hp > ulhp and 10 or 8) end
end

-- create a box object, which can react to collision with other objects
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

-- hp box
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

-- weapon box
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

-- acid barrel
function barrel(p)
 return box(
  4, p, nil, nope, 1, function(_ENV, ow, te, fo)
   acid_fx(pos, randint(9, 13), fo, v2(.3, .7), 3, .2)
   impactor(nil, pos, fo, rand(2.2, 2.6), 400, 32, 1.3, v2(3, 5), ow, te, "brl", 4, 8, .8)
  end
 )
end

-- land mine
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
   impactor(nil, pos, fo, rand(2.2, 2.6), 360, 32, 1.3, v2(5, 9), ow, te, "mne", 5, 6, 1.1)
  end
 )
end

-- an unit is an object with a weapon and an attack
function unit(ow, te, god, c1, c2, c3, we_i, ...)
 local u = gob(...)

 u._ow, u._te, u.c1, u.c2, u.c3, u.aim, u.we, u.mag, u.cd.god, u.h_free, u.canattack = ow, te, c1, c2, c3, u.l and "w" or "e", weapons[we_i], weapons[we_i].mag, god, 0,

 -- decide if the unit can attack or not
 function(_ENV)
  -- get the weapon's and muzzle's position
  local w_pos = anim:get_p(pos)
  local m_pos = we:get_m_pos(w_pos, aim, l)
  if not cd.melee then
   local hb = get_hb(_ENV)
   for o in all(w_get(_ENV, 72, 0)) do
    local o_hb = o:get_hb()
    local near, far = r_coll(hb, o_hb), p_coll(m_pos, o_hb)
    -- an unit can perform a melee attack if it collides with another object, or its weapon's muzzle collides with another object
    if near or far then
     return "m", near, near and w_pos or m_pos, o
    end
   end
   -- the unit can perform a melee attack against the terrain if the muzzle is inside the wall
   if get_px(m_pos.x, m_pos.y) ~= 1 then
    return "m", false, m_pos
   end
  end
  -- if we have not performed a melee attack, and the weapon is not on cooldown, and it is not reloading, and we have ammo, it means we can shoot
  if not cd.weapon and not cd.reload and mag > 0 then
   return "s", false, w_pos
  end
 end

 return u
end

-- soldier is the player's unit
function sold(pl, p)
 local s = unit(
  -- set the owner to the player's id, and set the team according to game mode
  pl.id, menus[1]:get(1) == 1 and 1 or pl.id, 135, pl.c1, pl.c2, pl.c3, 1, 1, p,

  -- on impact
  function(_ENV, ow, te, fo, dmg)
   local le = #fo
   anim:play((not l and fo.x > 0) and (le > .8 and 11 or 5) or (le > .8 and 12 or 4), true)
   -- in god mode or in case of friendly fire, deal no damage
   if cd.god or (_ow ~= ow and _te == te) then
    return 0
   end
   sfx(36)
   on_suf(pos, ceil(dmg), fo, v2(.3, .6), 2, 0)
   return dmg
  end,

  -- on update
  function(_ENV)
   -- reload weapon
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
   -- jetpack
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
    -- move acc, and previous left face
    local m_a, prev_l = ground and 0.025 or 0.03, l
    -- move left or right and set facing direction
    if joy.l.down and not joy.r.down then
     l, acc.x = true, (not s_b and -m_a or 0)
    elseif joy.r.down and not joy.l.down then
     l, acc.x = false, (not s_b and m_a or 0)
    end
    -- force aim on orientation change
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
   -- draw the weapon (do not draw the knife if it is reloading)
   if not (we.id == 2 and cd.reload) then
    -- the weapon is blinking if it is reloading
    if cd.reload and cd.reload % 10 > 5 then
     pal_spec(we.id == 3 and 0 or 7)
    end
    we:draw(anim:get_p(pos), aim, l)
    ppal()
   end
   -- set the colors of the soldier based on hp and god status
   pal(1, c1)
   pal(2, c2)
   pal(3, hp < ulhp and 2 or hp < lhp and 8 or c3)
   if cd.god and cd.god % 10 > 5 then
    pal_spec(_ow == 4 and 0 or 7)
   end
  end,
  -- on after draw
  function(_ENV)
   -- draw the samll flame of the flamethrower
   if (we.id == 7 and not cd.weapon and not cd.reload and rnd() < .04) mflm(we:get_m_pos(anim:get_p(pos), aim, l))
  end,
  -- on die
  function(_ENV, ow, te, fo, dmg)
   sfx(56)
   blood_fx(pos, randint(15, 25), fo, v2(0.5, 1), 2, .25)
   drt(pos, randint(3, 11), fo * (rnd() < .25 and -1 or 1), v2(.2, .7), 0, 0, nil, { c1 }, sticky)
   lim(pos, randint(0, 2), fo, v2(.3, .7), 1, .2, nil, { 8, c1 }, sticky)
   players[_ow].soldier = nil
   -- if the soldier is killed by the enemy, traps or himself, the owner's score is reduced
   if ow == _ow or ow == 0 then
    players[_ow].scr -= 1
    -- if the soldier is killed by another player, their score is increased (add 2 points in chaos mode)
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

-- techno squid
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
    -- acquire target
    if not tar or not cd.search then
     cd.search, tar = 90, acq_tar(_ENV, 0, 1, 0)
    else
     if tar.rem then
      tar = nil
     else
      -- move towards the target
      d = (tar.pos - pos):norm()
      anim.f_y, acc.x, acc.y = d.y > 0, d.x < 0 and -.05 or d.x > 0 and .05 or 0, d.y < 0 and -.05 or d.y > 0 and .05 or 0
      if abs(tar.pos.x - pos.x) > 1 then
       anim.f_x = d.x < 0
      end
     end
    end
    -- check if we can attack
    if not cd.attack then
     local a_t, near, w_pos, o = canattack(_ENV)
     -- soldiers has bigger chance to be attacked by the tentacles, but nothing is spared (even other squids)
     if a_t == "m" and o and (rnd() < (o.type == 1 and .1 * lvl or .01)) then
      cd.attack = 75
      anim:play(7, true)
      impactor(o, w_pos, o.pos - pos, (v2(.5, .75) * lvl):ab(), 0, 12, .8, v2(1, 2) * lvl, 0, 0, "rhit", 54, 3+lvl, .5 * lvl)
      -- shoot at the target
     elseif a_t == "s" and tar and rnd() < .075 * lvl then
      cd.attack = randint(75, 270)
      if not cango(_ENV, pos, d) and rnd() < .5 then
       anim:play(7, true)
       impactor(nil, w_pos, v2(), 1, 0, 12, .8, v2(1,lvl), 0, 0, "rhit", 54, 3+lvl, .4*lvl)
      else
       we:shoot(eye, tar.pos - eye, 0, 0)
      end
     end
    end
    -- auto anim and speed limit
    anim:play(spd.x > .2 and 6 or abs(d.y) > .2 and 3 or abs(d.y) > .65 and 2 or 1)
    spd:limit(mspd * (hp < ulhp and .5 or hp < lhp and .75 or 1))
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
   sfx(62)

   ssmk(pos, randint(7, 13), fo, v2(.2, .4), 2, .25)
   drt(pos, randint(3, 11), fo * (rnd() < .25 and -1 or 1), v2(.2, .7), 0, 0, nil, rnd({ { 0 }, { 8, 2 } }), sticky)
   lim(pos, randint(2, 3), fo, v2(.3, .7), 1, .2, nil, { 2, 0 }, sticky)
   acid_fx(pos, (lvl - 1) * 3, fo, v2(.1, .3), 2, .2)
   impactor(nil, pos, fo, .7, lvl * 75, 16, 1, v2(.5, 1) * lvl, ow, te, "orbr", 1, lvl + 2, .6)
   -- if the squid is killed by a soldier, add a point to the owner's score
   if ow ~= 0 then
    players[ow].scr += 1
   end
  end,
  -- on land
  nil
 )
 e.eye, e.mspd = p, .1 + lvl * .02
 e.hp += lvl * 3
 return e
end

-- world manipulation
-- add an object to the world
function w_add(o) add(world, o) end
-- get objects from the world around an object, with radius and filter
function w_get(obj, sqrdist, filter)
 local near = {}
 for o in all(world) do
  if o ~= obj and not o.rem and (filter == 0 or (o.type & filter) ~= 0) and (sqrdist == 0 or obj.pos:sqrdist(o.pos) <= sqrdist) then
   add(near, o)
  end
 end
 return near
end
-- get a random safe spot in the world to place a new object
function w_spot()
 local i = 0
 while true do
  i += 1
  local p = v2(randint(3, 124), randint(13, 115))
  -- make sure there are no other objects nearby, and the spot is free
  -- after 100 try do not check other objects (or in some weird edge cases this can cause the program to hang)
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
  spd, pos = (spd + acc) * fri, n_pos
  return eol or pos.x < 0 or pos.x >= 128 or pos.y < 0 or pos.y >= 128
 end
end

-- particle effect constructor
-- cereates a function that puts the appropriate particles into the system
-- used both for effects and projectiles
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

-- combined effect constructor (used in explosions)
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

-- either a smoke or a spark particle
function ssmk(...)
 _g[rnd({ "smk", "spa" })](...)
end

-- spawn effect (circular or rectangular in two different sizes) with custom colors
function spawn_fx(pos, o, ty, si, cols)
 sfx(o.so)
 local n = 7 + si * 2
 for i = 1, n do
  if i < 3 and i <= si then
   _g[ty .. i](pos, 1, nil, nil, 0, 0, v2(3, 6), cols)
  end
  local p_pos = pos + v2(rand(7 + si, 9 + si), 0):rot(i / n)
  _g["sli" .. randint(1, si)](p_pos, 1, pos - p_pos, v2(.5, .6), 0, 0, nil, cols)
 end
end

-- sticky particlas has a chanche to stick on the terrain
function sticky(_ENV)
 if get_px(n_pos.x, n_pos.y) ~= 1 and rnd() < .3 then
  set_px(n_pos.x, n_pos.y, rnd(cols))
  eol = true
 end
end

-- blood effect
function blood_fx(pos, bu, di, fo, sp, co)
 blo(pos, bu, di, fo, sp, co, nil, nil, sticky)
end

-- acid effect
function acid_fx(p, bu, di, fo, sp, co)
 aci(
  p, bu, di, fo, sp, co, nil, nil, function(_ENV)
   if get_px(n_pos.x, n_pos.y) ~= 1 then
    local ch = rnd()
    sfx(34)
    set_px(n_pos.x, n_pos.y, ch < .1 and 1 or ch < .3 and 11 or ch < .5 and 3 or 0)
    eol = true
   else
    -- acid hits every object excepot the barrel
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

-- reset the game to its initial state (on init or after a battle)
function reset()
 players, p_sys, world, cd, sched, drama_v, flic, state = use_data(plf, pld, player_c), {}, {}, { menu = 10 }, {}, 0, 0, 1
end

-- draw the hud
function hud()
 -- in state 1 or 2 display the menu
 if state < 3 then
  -- in state 1 display the title sprite
  if state == 1 then
   sprites[14]:draw(v2(12, 22))
  end
  menus[state]:draw()
 end
 -- in state 4 display the high scores
 if state == 4 then
  pprint("this battle is over", 26, 26, 8, 0, "l", true)
  pprint("results :", 30, 36, 8, 0, "l", true)
  local sc, names = {}, split("  joe : ,hicks : , hank : , simo : ")
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
   pprint(s.n .. s.scr, 38, 36 + 8 * i, s.c, 0, "l", true)
  end
 end

 rectfill(0, 0, 127, 7, 0)
 rectfill(0, 120, 127, 127, 0)

 -- in state 3 display the timer
 if state == 3 then
  local s, m = countdown % 60, flr(countdown / 60)
  if countdown > 10 or flic % 30 >= 15 then
   pprint(m .. ":" .. (s < 10 and "0" .. s or s), 64, 1, countdown < 11 and 8 or countdown < 31 and 10 or 7, 1, "c", true)
  end
 end

 -- draw the players
 for p in all(players) do
  p:draw()
 end

 -- set the background color according to the map
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
   -- if the match is started without a map, generate one
   if not map_done then
    gen_map()
   end
   -- set the game to the running state
   spwn_i, countdown, lvl, state = 1, menus[1]:get(2) * 3 * 60 + 3, menus[1]:get(5), 3
   schedule(randint(30, 90), upd_spwn)
   schedule(60, upd_countdown)
   sfx(58)
  end
 end
end

-- schedule a function
function schedule(de, fn)
 add(
  sched, {
   delay = de,
   fn = fn
  }
 )
end

function _init()
 -- turn on the music by default, and add a menu item to control it separately
 music(0, 500)
 menuitem(
  1, "music:on",
  function()
   music_on = not music_on
   music(music_on and 0 or -1)
   menuitem(1, "music:" .. (music_on and "on" or "off"))
   return true
  end
 )

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

 -- attach lookup tables
 for ts in all(split(tbd, "|")) do
  local t, n, et, ds = {}, unpack(split(ts, "#"))
  for e in all(split(ds)) do
   local k, v = unpack(split(e, ";"))
   t[k] = conv(et, v)
  end
  _g[n] = t
 end

 -- build assets from data
 music_on, _y, destructors, aims, menus, sprites, anims, weapons, spwns = true, {}, {}, {}, use_data(mef, med, menu_c), use_data(spf, spd, sprite_c), use_data(a_f, a_d, env), use_data(wpf, wpd, weapon_c), use_data(swf, swd, env)

 -- memory addresses for fast access
 for y = 8, 119 do
  _y[y] = y * 64
 end

 -- init destructors
 for r = 0, 10 do
  cls()
  circfill(r, r, r, 1)
  local d = {}
  for x = 0, 2 * r + 1 do
   for y = 0, 2 * r + 1 do
    if pget(x, y) == 1 then add(d, { x = x - r, y = y - r }) end
   end
  end
  add(destructors, d)
 end

 -- create aim objects
 use_data(aif, aid, function(o) aims[o.n] = o end)

 -- particles
 use_data(paf, pad, part_c)
 -- effects
 use_data(fxf, fxd, fx_c)

 reset()
end

function _update60()
 flic += 1
 -- decay drama
 drama_v = max(drama_v - .03, 0)

 -- progress cooldowns
 for k, v in pairs(cd) do
  cd[k] = v > 0 and v - 1 or nil
 end

 -- progress the scheduled functions
 for sc in all(sched) do
  sc.delay -= 1
  if sc.delay <= 0 then
   del(sched, sc)
   if (state == 3) sc.fn()
  end
 end

 -- update players
 for p in all(players) do
  p:upd()
 end

 -- update particle system
 for p in all(p_sys) do
  if (p_upd(p)) del(p_sys, p)
 end

 -- update objects in the world
 for o in all(world) do
  if (o:upd()) del(world, o)
 end
end

function _draw()
 cls()
 ppal()
 -- apply jitter to the camera if we are shaking
 camera(cd.shake and jitt() or 0, cd.shake and jitt() or 0)

 -- draw the map (with jitter if we are shaking)
 memcpy(0x6200 + (cd.shake and (64 * jitt() + jitt()) or 0), 0x8200, 0x1c00)

 -- draw the objects in the world
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

 -- draw the hud without shake
 camera()
 hud()
end

__gfx__
eeeeebbbbbbbbbbbbbbbeebbbbbbbbbbeeeebbbbbbbbbbbbeeebbbbbeeeebbbbeeeeeeeebbbbbbbbeebbbbbbbbbbbeeeeeeeeeeeeeeebbbbbeeeee33334e3335
eeeeeb00b0000000000beeb000000000beeeb0000000000bbeeb000beeeb000beeeeeeeb0000000beeb000000000beeeeeeeeeeeeeeb3333bbeeee3bb4433335
eeeeeb00b0000000000beeb0000000000beeb00000000000beeb000beeb0000beeeeeeb00000000beeb000000000beeeeeeeeeeeeee311113bbeee3b43433355
eeeeeb00b0000000000beeb0000000000beeb00000000000beeb000beb00000beeeeeb000000000beeb000000000beeeeeeeeeeeeee3dddd33beee343343b555
eeeeeb00b0bbbbb0000beeb000bbbb000beeb000bbbbb000beeb000bb0000bbbeeeeb00000bbbbbbeebbbb000bbbbeeeeeeeeeeeeee3d1ddd3b5ee4444445555
eeeeeb00b0000000000beeb000beeb000beeb000beeeb000beeb0000000000beeeeb0000000000beeeeeeb000beeeeeeeeeeeeeeee5b11111b555ee333566666
eeeeeb0000000000000beeb000beeb000beeb000beeebbbbbeeb00000000000beeb00000000000beeeeeeb000beeeeeeeeeeeeeee553b111b35555333e56786d
eeeeeb0000000000000beeb000beeb000beeb000beeeeeeeeeeb00000000000beeb00000000000beeeeeeb000beeeeeeeeeeeeee53553bbb355335335356882d
eeeeeb0000000000000beeb000bbbb000beeb000bbbbbbbbeeeb000bbbbb000beeb0000bbbbbbbbbeeeeeb000beeeeeeeeeeeeeeeeeeedddddeeee3e254662dd
eeeeeb0000bbbbbbbbbbeeb0000000000beeb0000000000beeeb000beeeb000beeb000000000000beeeeeb000beeeeeeeeeeeeeeeeeedcccccdeee445446dddd
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
a32383c263a303c753a373c2130313a33353c233a3633223a323c763a373c2130363a33353c203a3633233a323c773a353c2131323a33353c203a3333243a323
c783a363c2131313a34313c203a3133253a333c71333a373c203a33353c263a303c733a363c2131373a32383c213a3433213a303c753a353c2132303a32383c2
13a3333233a313c763a333c2131393a33343c213a3133253a313c753a363c2131393a33373c213a3133243a343c753a363c233a35343c213a3333243a3133203
a3033223a353c743a363c203a34383c213a3333233a3233203a3033223a353c733a363c203a35343c213a3333223a3333203a3033223a353c763a353c21363a3
4323c223a3233253a3233213a3033243a343c773a333c21363a34373c233a3133263a3233203a3033253a323c763a363c22323a34323c223a3333253a3533203
a3133243a353c743a363c243a34383c213a3333233a3233203a3033223a353c743a363c283a34373c213a3333233a3233203a3033223a353c743a353c21323a3
4363c213a3233233a3233203a3033223a343c743a363c21353a35313c213a3333233a3233213a3033233a353c763a363c21393a35303c203a3333253a3233203
a3033233a353c773a363c283a35333c203a3333223a3233203a3033233a353c753a353c21313a34313c223a3233223a3233213a3033233a343c753a363c203a3
4323c223a3333223a3333203a3133233a353c763a353c253a34323c223a3233233a3233203a3033233a343c71343a383c2130343a303c21333a303c71343a383
c2130343a383c203a303c71343a383c2130343a31363c21333a303c71343a383c2131343a34373c203a303c743a363c22353a35333c213a3333233a3233203a3
033233a353c773a353c22353a34383c223a3233233a3233203a3033233a343c763a363c22383a34313c203a3333253a3033203a3033233a353c743a383c23343
a34323c203a3533223a3033203a3233233a373c753a363c23383a34323c213a3333243a3133213a3033233a353c743a363c24333a34323c213a3333233a32332
13a3033233a353c753a363c24373a34333c213a3333243a3433213a3133243a353c743a363c23323a35303c213a3333223a3333203a3133233a353c743a363c2
3363a35303c213a3233223a3533203a3133233a343c783a393c26333a34343c223a3433213a3533203a3133263a383c753a31333c27313a34343c223a3633243
a3633203a3133243a31313c783a393c27363a34333c253a3433263a3433223a3133273a373c763a31313c28343a34333c233a3533253a3533203a3133253a393
c71303a373c29303a34333c273a3333283a3333233a3033293a363c763a31303c2130303a34333c233a3433243a3433203a3133253a383c783a393c2130363a3
4343c253a3633263a3733203a3333273a383c793a393c26333a35333c263a3533263a3533213a3333283a383c71313a393c27363a35343c223a3433233a33332
03a3133273a373c783a393c28373a35343c253a3433263a3333213a3133273a373c783a383c29353a35333c253a3233253a3133213a3033273a363c793a393c2
130333a35333c223a3533223a3433203a3233283a383c71303a393c2131323a35353c273a3633283a3733223a3333293a383c703a303c213a313c203a3033203
a303c703a303c213a313c203a3033203a303c703a303c213a313c203a3033203a303c703a303c213a313c203a3033203a303c703a303c213a313c203a3033203
a30316f54610b913c263c723c263c733c263c743c263c753c263c763c263c773c263c783c263c793c263c71303c263c71303321313c263c71323321333c263c7
1323c263c76353c263c76363c263c76373c263c77393c243c76383c243c76393c263c77303c263c76363327313327323327333c263c763633273433273533273
53327353c253c76363327323327363327363327363c253c76363326383326393327303327373327383327393c263c76363327393327383327373327303326393
326383c263c77303326393327333326363c233c78343328353328353328353c253c76363326353328363328363328363c253c763533283833283733283733283
73c253c76363328393329303329303329303c253c76373329313329323329323329323c253c79353c263c7130323c263c7130333c263c7130343c21323c71303
03c21323c79353329363329383329373329373329373329373329373c283c79353329363329343321303133213031332130313c263c793533293833293433293
333213034332130343c253c79353329383321303033293933213035332130353c25307c646102213c2132363a303c2130343c2131333c263c213c243c21353c2
33c21313c203c29363a303c2d213c213c203c213c243c29303c203c213c28303c2132373c227c2131313c203c703c213a303c22343c21353c263c223c243c213
53c21333c21323c203c23323a303c213c213c203c213c243c24303c203c213c28313c223c2c6c21373c203c713c2132363a3132303c2130343c2131333c21323
63c233c2132343c293c243c21303c203c29363a3132313c2d213c2132323c203c2132313c243c29303c203c2132323c28323c2132373c227c2131313c203c703
c213a3132303c22343c21353c2132363c243c2132343c21353c263c273c203c23323a3132313c213c2132323c203c2132313c243c24303c203c2132323c28333
c223c2c6c21373c203668746101137d6b626c203a323c22666c637c2e6f60756c203c22666c63723c213c737d6b626c203a323c22766c637c2e6f60756c203c2
2766c63723c213c737d6b626b237d6b6c263a31383c2270776c23786f623c253c226c6f623c293c737d6b626b237d6b6c243a31323c2762756c23786f613c253
c266c63723c293c737d6b626c203a323c2f6272627c2273786f613c203c22766c63723c213c737d6b626c243a31323c2d6f6c647c23786f613c233c266c63723
c253c737d6b6b237d6b626c283a32323c22627c6c2763786f623c243c27666c63723c273c737d6b6b237d6b626c223a31303c2d6e656c23786f613c233c226c6
f613c253c737d6b626c203a323c2860726c2e6f60756c203c266c63723c21316f56600f01313b3662716d65637c213b337074647264610b5d61607f536f6c637
32533213b3132393044304330453c223b3132383044304930403c233b3133303045304330443c243b313333304030433041313c253b313330304230413430483
c263b3132393041333041323041353c273b3133333045304430403c283b3132383045304630403c293b3133323045304030463c7f626a6f5e657d63732533213
b33304530473c223b30304330453c233b32304430463c7d637763732233213b337071677e60296e60213c223b337071677e60296e60223c233b337071677e602
96e60233c243b3a6f696e602e8f279c77627f657073732533213b31304230433c223b34304530463c233b37304830493c243b31303041313041323041333c253
b31353041343041363041373041383041393042303042313042323042333042343042353042363042373042383042393043303043313c263b333230433330433
4304335304336304337304338304339304430316964600dc03e293a303e243c256c223c213a303c293c203c203c703e273a3d203e273c2e656c213c203e273a3
d203e273c21353c203c203c703a3d213c2e6c203c203a3d213c21363c203c203c7d203e273a3d203e273c2e677c213c2d203e273a3d203e273c21353c203c213
c7d203e293a303e243c277c223c2d213a303c293c203c213c7d203e273a303e273c23777c233c2d203e273a303e273c21373c203c213c703a313c237c203c203
a313c21383c213c203c703e273a303e273c23756c233c203e273a303e273c21373c203c20376f64610f033c203a303c226c6f6f646f56687c203c213c203c213
e253c203c26303c253c213c203a303c21303c2d213a3d233c233a363c723c203a303c237d6b6c203c203c203c213c203c263c223c223c203a303c263c2d223a3
d223c253a353c733c203a303c23737d6b6c203c203c203c213e253c203c263c213c243c203a303c283c2d223a3d223c253a353c743c203a303c216369646f566
87c203c203c203c223c203c263c233c283c203a303c293c2d213a3d223c243a353c773c203a303c237d6b6c203c203c203c233c203c263c243c21363c203a303
c22303c2d213a3d213c233a323c753c203a303c23737d6b6c203c203c203c233c203c273c263c23323c203a303c243c2d223a3d223c253a353770766002813b3
b6e6f527c213b3d61676c213b327f54796c213b3b6e6f566c213b356376687c213b39646c223b356f566e6c213b3d6376687c223b30727f6a6f566e6c213b346
f566c223b3d6f566e6c233b346d676c233b3465637c213b336f6c213b377f53646c213b3370727f596c233b366f6c213b367f5d6c213b3b6e6f547c213b32657
668766003223b31666c233b34656c223b3e616c223b33786f6c213b33707c223b32616c213b3265776f666007513b3c68607c233b3370746c223b3375766c213
b3169627c243b336c696c213b34756c213b357c68607c213b3f677c213b337f6c213b316f59646c213b347970756c233b3163636c213b38607c233b3f66666c2
33b33796d6564610c213c22332233223322332233213c213c22373c21343a35393c24332433243324332433213c2d6f646563277162732162756e61632368616
f637324796d6563233326332933226f68756373266567732d6f6275632c6f6473732472716073732e6f6e6563266567732d6f627563226f6473732c616d65632
47f65776863226f637373256e647562702478656027716374756c616e64637c713c22332233223321332133213c223c23303c243a35393c24332433243321332
133213c24656e63796479732c6f6773236f6a79732374757666656463237861607563236166756323616e697f6e6329637c616e6463266162627963632561627
47863267f6964632275796e63732475627271666f627d63256e6475627024786560226164747c65632261636b60247f60226163756377766006313b36696c647
5627c243b3d657c647c21313b336f6c637c213b39646c213b3e6f6c21323b366e637c21313b366f537c21323b3668737370766004133b33796a756c233b33707
f637c21333b307473707166600f333b397f537c233b387f537c223b3e616d656c21313b3b696e64637c213b3762716c21313b336f6c637c233b3c6966656c213
13b33796a75637c213b366279607c666001b43b3c6c233b307f637c213b38607f58723c213b38607f58713c213b316d6d6f6f597c213b39646c213b38607f597
23c213b33633c213b33623c213b33613c213b3370777e6c233b377f507f637c213b3261627f546c213b3d63776f597c243b336f6e6e6c213b38607f59713c213
b3d63776c213b3373627f587c213b3373627c213b3373627f597c213b3370727f596c213b3d63776f587c223b396e646c213b316d6d6f6f587c243b337f6c646
965627d65666001313b3964687c21313b396468737c213b39646c213b336f6c6f577c233b307f637c21313b327f67737c21323b3964756d63700000000000000
__label__
11111111111111111111111000000000000011111111111111111111111111111111111111111111211111112111211121111111111111111111111111112111
11111111111111111111000333333000000001000001111111111111111111111111111111111100001000000000000100000000000000000000000000100001
1111111111111111111033333333055555550055555011111111111111111111111111111111110bb000b00b00b0bb000b00bbb0bbb0bb0bb00b0b00b000bb01
1111111111111111110333333300555500055555005501111111111111111111111111111111110b0b0b0b0bb0b0b0b0b0b00b000b00b00b0b0b0b0b000b0001
1111111111111111100333300005555022205550220501111111111111111111111111111111210b0b0b0b0bb0b0bb00b0b00b010b00bb0bb000b000010bbb01
1111111111111111003330000050555088205550820550111111111111111111111111111111110b0b0b0b0b0bb0b0b0bbb00b010b00b00b0b00b01111000b01
1111111111111110003305000500055088205550820550111111111111111111111111111111110bb000b00b00b0bbb0b0b00b010b00bb0b0b00b011110bb001
11111111111111000330550055000550222055502205501111111111111111111111111111111100001000000000000000000001000000000000001111000011
11111111111111000005500055000555000550550055501111111111211111112111111111112111211121112111111111111111111111111111112121212121
111111111111100055055000555055555555555555550011111111111111111dd111111111111111111111111111111111111111111111111111111111111111
1111111111111005000550005055550000000000000000111111111111111155f000111111111111112111211111111111111111111111111121112121211121
111111111111005003300500050550333333333030300111111111111111115ddd01111111111111111111111111111111111111111111111111111111111111
1111111111110000003330500050000000000000000011111111211111112155d111111111112111211121111111111111111111111111212121212121212121
11111111111100000003330000030000000000000001111111111111111111add111111111111111111111111111111111111111111111111111111111111111
111111111111000550003333333004444fffffffff00111111111111111111a00111111111111121112111111111111111111111112111111121212111112121
11111111111005505500333303004ffffffff0000000111111111111111111911111111111111111111111111111111111444111111111111121111112111111
1111111111005555055000303004f00000000ccccc00111111112111211121911111111111112111212111111111111114444411112111212222212121112111
111111111100555505500033004f0ccccccccccccc00111111111111111111111111111111111111111111111111111154fff451111111111121111112111111
11111111100505555055000004f0ccc1111cccc11100111111211111112111911111111111211121112111111111112144440001112121212121212121112121
1111111110000055505500000000c1111111cc111100111111111111111111111111111111111111111111111111111140000000000111111111111111111111
1111111110000055505500055550c11111cc11ccc100111111112111211121111111111121112121211121211111211140000000000121212121211121111121
1111111110000055505500005550c1111cc11000cc00111111111111111111711111111111111111111111111111111140ff00ff111121111111111121121111
1111111110050555505504000550cc11cc1109990000111111111121112111711111112111211111111111111111211154444451212222212121212221212121
11111111100055550555004f00000cccc10099999000111111111111111111711111111111111111111111111111111154454451111121111111111111111111
111111112100555505509904fff000ccc00999049001111121112111212111711111112121212111111121212121211194414491212121212121212121211112
1111111111000550505049900fff0000009990449001111111111111111111711111111111111111111111111111111194414491121111111211121111111121
11111111111000050500449990ffffff099904499011112111211121112111111111112121211111112121211211212190010091212121212121212111112112
1111111111110000500444499900000099994499940111111111111111111111111111111111111111111111222111119a919a91111111111111111111121111
1111211121112000000444444999999999944990940121212111212111111111111111211121212121111121121121219a919a91212121212121211111111121
11111111111111110040004444099999999499909401111111111111111111711111111111111111111111111111121119111911112112112222111112111212
11111111111000000404000994400909999999049401112111211121112111711111112111212111212121212121212121212121222221212121111111110000
11111111000000000444000099440090999990449400111111111111111111111111111111111111111111111111111117111711112111111111111111000000
21110000000000000044440009944009999090449030012121212121212121211111112121211111212121212121212121217771222221212121111122002020
11000000000333000044404000994400990904499030000222111111111111111111222111111111121111111211121117111711122112111211121000000200
10000000000333300004440400099444099044990033000002211121212121712121222121111111212122212121212177712121212121111111210000020020
00003033000333300bbbbbbbbbbbbbbb99bbbbbbbbbb0033bbbbbbbbbbbb111bbbbb1111bbbb11111111bbbbbbbb11bbbbbbbbbbb11211111111210000000002
00300333000033330b00b0000000000b99b000000000b033b0000000000bb12b000b212b000b1121212b0000000b21b000000000b22121212111100220000020
03033333300003333b00b0000000000b99b0000000000b03b00000000000b11b000b22b0000b121112b00000000b12b000000000b21112111111002982000002
00333333330003333b00b0000000000b99b0000000000b03b00000000000b17b000b2b00000b21212b000000000b21b000000000b12121111121002822000020
00003333330000333b00b0bbbbb0000b99b000bbbb000b00b000bbbbb000b17b000bb0000bbb1111b00000bbbbbb11bbbb000bbbb11221111112000220002002
00000033333000333b00b0000000000b99b000b99b000b00b000b001b000b12b0000000000b1212b0000000000b121212b000b21212212211120000000000220
55000000333300033b0000000000000b44b000b94b000b00b000b301bbbbb11b00000000000b12b00000000000b112111b000b11121221111120002000000202
55555000003330003b0000000000000b44b000b44b000b00b000b3002121212b00000000000b21b00000000000b121212b000b21212121211110200002002020
55555500000033000b0000000000000b44b000bbbb000b00b000bbbbbbbb111b000bbbbb000b11b0000bbbbbbbbb11121b000b12111211121210000000020002
55555550500000300b0000bbbbbbbbbb44b0000000000b00b0000000000b217b000b212b000b28b000000000000b21212b000b21212121211110202020202020
55555555055000000b0000b33300000000b0000000000b30b0000000000b121b000b121b000b18b000000000000b12121b000b12121211121210020202020202
55555555555550000b0000b33333300000b0000000000b30b0000000000b212b000b212b000b29b000000000000b21212b000b21212121111210202020202020
55555555555555500bbbbbb33333333333bbbbbbbbbbbb00bbbbbbbbbbbb111bbbbb111bbbbb99bbbbbbbbbbbbbb11121bbbbb12111211111112020288888202
55555555555555050000003333333333333333333333308888898000030021712121212121219a81212121212121212121212721212121212112002889998820
55555555555555505000000003333333333333333333089a88885550000002711211221112129821121212111212121217122722121212111212020888899802
555555555555bbbbbbbbbbbbbbb03bbbbb88883300000899855bbbbbbbb00bbbbbbbbbbb21bbbbbbbbbb2121bbbbbbbbbb2122bbbbbbbb212120202020888820
555555555555b00b0000000000b00b000b8998800000008855b0000000b00b000000000b11b000000000b112b000000000b211b0000000b21202000202088802
555555555555b00b0000000000b08b000b888880000000005b00000000b00b000000000b21b0000000000b21b0000000000b27b00000000b2220012020208820
555555555555b00b0000000000b88b000b88800000000005b000000000b55b000000000b12b0000000000b12b0000000000b12b000000000b202021202028802
555555555555b00b0bbbbb0000b89b000b0000000000000b0000bbb000b55bbbb000bbbb21b000bbbb000b21b000bbbb000b21b0000b00000b20212120008820
505505555555b00b0000000000b99b000b500000000000b00000000000b55555b000b11211b000b21b000b12b000b21b000b12b0000bb00000b2021212108800
055050000000b0000000000000ba9b000b5555bbbbb00b000000000000b55555b000b00121b000b12b000b21b000b12b000b21b0000b2b00000b222111218820
000000000000b0000000000000b99b000b5555b000b00b000000000000b55555b000b08882b000b21b000b12b000b21b000b17b0000b12b0000b021212128812
000000000000b0000000000000b88b000bbbbbb000b00b000000000000b55555b000b50988b000bbbb000b21b000bbbb000b27b0000b222b000b201121228121
000000000000b0000bbbbbbbbbb85b000000000000b00b000bbbbbb000b55555b000b55598b0000000000b12b0000000000b17b0000b122b000b021112128212
333333030000b0000b00888888555b000000000000b00b000b0000b000b55555b000b55598b0000000000b21b0000000000b22b0000b222b000b222122282221
303330300000b0000b00898855555b000000000000b00b000b5550b000b55555b000b55588b0000000000b12b0000000000b12b0000b121b000b028812122122
030333000000bbbbbb38988005555bbbbbbbbbbbbbb05bbbbb5550bbbbb55055bbbbb55580bbbbbbbbbbbb02bbbbbbbbbbbb21bbbbbb212bbbbb208881212212
00033300000080333338880000555555555000005555555555550000000005055555555885555555000555002212221217121712221212121212088982120020
00000000000888333388830000000555550000055555050005555000000000055555558855555500000005502221222127212721222122212221289982000000
30000000088880333388833300000005500000055550500000055555500000000588885555555000000000502222121217121212121212121212889880200200
333000008880003333883333330000000000005555550000000055888550000008898855555580000d0000502222212121222121212221222128898820222222
333300088800000333883333330000000000055000050000000008888855500088988005555880000d0000502212121217221212121212121288888212122228
333300889800000333883000000000000000055000050000000008899888888889880005558800000d0000502221222122212221222122212888882122222228
33330889880000033300000000000000000055550005000000000888999999999880000558800000000dd0501212122212121712128212128888121212122288
03333888800000000000000000000000000000555005000000000088889aa98888000000588000dd020000502121222227212722288888888882212221222288
03388898880333333300000000000000004400555555000000000000088998885000500058800000000000501212122212121212189a99888212121222222288
033889988833003333333300000000000994400055550000000000000088880055555500888000000d0000502222222122212221889998882222222222222888
008899888300003333333300000000009994440005555000000000000000000005555500898500000d0888821222221212121288899888222212121222228888
0889998880003333333030099999999999494444000555555000000000000000005555589998000008889a882122212227288888888822222222212222288882
8889a99800033333330300099999999999949444440005555888800080000000000055589a988008899889988882221217188988121222222212122222288828
8899999803333333333300049999994990999999944440588998880888000000000000589a998888999988888888222122218882222222222222222222888888
999a99883333033333300044999994944409999999998888888855508000000000000008999999a9999888222228221212121712122222221222222228888888
99aaa998833003333330004499999444444099994448899888555555000000000000008899899aaa998888222222212221222722222282222222222288882888
9aaaa9888330033333000844499444444444099498899988000555555500000000000888998999a9988000222212122212122222222888222222222888828888
9aaa9988883000333300888444444400004449488999880000000555555550000000888898899999988500002222222222222222222282222222888888888888
aaaa99888800003333000844444440000004448889988000000000555555550000088889989999998855550002222282222222222222228822288288228888ee
a7aa99898880003333000444444400000000888999880000000000000550555500888899889a999988555555500228882222222222288222288888822888eeee
777aa998988003333080044440000000000889999880000055500000000505555588899889aaa989880555555550088222222228228822228888888288eeeee8
777aa999888803888880044000000000088899a988800005555500000000555558889988999a99898000055055555508888882822882222828288888eeeeeee8
7777aa9999888889988004088000000088998aaa8888000555555000000000558899998999a9988980000005055555588888822228888288882288888e88ee88
77777aa9999899999800008800000008899899a98880000555555000000000088999999aa7aa989980000000555588888882222288e8888888888888888ee888
77777a7aa99999a99888888800000888899999998800000555555555000008889899a9aa7aa989988000000088888888880022288eee888888888e88e88e88ee
77777777aaa99aaa998898800000888899999989880000055055055550888889899aaa9aaa99998800000008888888899855008888888888888eeeeee88888ee
a777777aaaaa9aaaa9999988888888999a99989888000005550050558888899999a9a99aa999998000000888888889998885588888899888eeeeeee88888eeee
aaaa7aaaaaa99aaaaa99998889999999aaa999888990000505550508888999a9aaaaa9aaa99998800008888888899998888889999988888eee8eeee8888ee888
a9a777aaa99999aaa9a9a99888999a9aaaaa9888890000055055888899999a9aaaaaaa7a9a99980008888889899999888889999998888888e8eeee8888888899
99aa7aaaaa999aaaaaaa9a989899a9aaa7aa988890000005088888999999aaaaaaa9a7aaaaa988088888989899a999888999988888888ee88eee888888889999
999aaaaaaa999aa777aaa99999999aaa7aaa9880000000888888aa99999aaaaaa999aaa99a998888888999999aaa989899998888888800088888888899999999
999a99aaaaaa9a777777aa999999aaaaaaaa998008888888899aaaa99999aa998999aaa999a988888899999a99a9aa999a98899988888000888899999999aa99
a9aaa9aa9a7aaa7777777aaaa99aaaaa9aaa9988889999999a7aaa9a9999a99889999a999aaa888899999aaaaa9aaaa9aaa999988899888885899999999aaaa9
a99a9aaaa777a777777777a7aaaaaa999aaa9998a9999999a7777aaaa99a98888999aaa999a988899999aa7aa999aaaaaaa999999999888888899999aaaaaa99
999999aaaa7a7777777777777aaaaa9999a9999aaa99999aaa7777aa99a988888999aaa99999888999999777a9aa9aaaaaa99a99999888888899999aaaaaa999
99a99999aaaaa7aa7aa7a7a7aaaaaaa99a99999aa99aaaaaaaaa7a999998888999999a99999998899a999a7aaaaaa9a99aaaa9a99888899999999aaa7aaa9998
aaaa9aa999aaa99aaaaaaaa9999aaa99999999aaa9aa7aaaa99aa99988888898a999999999999999aaa9aaaa9aaaa99999aaaa99888899aa9999aaa777aa9988
99aaa9a99999999a9aaaaaaa999999999999999aaa7777a99988999899999999999999999a9999999aaaaaaa99aa9999999aa9998889999999a99aaa7aa99988
999a99aa99999999a999aaa99999998899a9999aa7777aa99888998a9998a9999999a999aaa999999aaaaaa9999999899999a998899999999aaa7a77aaa99988
99999aaaa888999999999a99999988999aaa9999aa79aa99888998aaa99aaa99999aaa999a99999999aaa99999999888999aaa9899999a99a9a777777a999988
999999aa88889aaaa9999999999889999aa99aaa999aa99888899899999aa9999a99a9999999999999999999999988888899a999a999aaaaaaa77777a9999888
888899988889a9aa9999999988889999aaaaaaa9999999888899899999aaaa99a9a998999999999989999989999988889999999aaa999aaaa9aa77777a998888
88889998889aaa9aa8899998888999999aa99a999999998888999999999aa9999999888999a99888889988889999888899999999a99aaaaa99997777aa888889
88999888899aaaaaaa889988888999999aaa999999999888889999999988999a999888899aaa988889888888889988899988999999aaaaaa99999799a9888899
9998888899999aaaa8888999888999999aa999999899888889999a99988999aaa9988899a9a99988999888899889889998899999999aaaa98899999999888999
8899989999999aa98888999998a9999999a99998889888999999aaa99899999a999aaa9aaaaa99889a98889aaa988898889999aaa9aa99998888999998888999
8999999999999998888999999aaa9999999998888999999999999a99899a9999a9aaa999aaa99999aaa889aaaaa9899889999aaa7aaaa99998888999888899a9
9999a99999999988889999999aaa8999999888889999a999aaa9aaa899a9999aaa99999aaa9a99999a98899aaa9a9988999999a777aa99aaa988888888889aaa
999aaa9899999989999999999aa88899888a9999999aaa9aaaaa9a999999999aaaa999aaaaaaa999999888999999998999999aaa7a999aaaaa899988888899aa
9999a999999999999999a9999988888888aaa9999899a9aaaaa99a9999999999a99aa9aaaaaaaa99999888899999a8899999aaaaaaa99aaaa8999998888899aa
99a999a99a99a99a999aaa9a9998888899aaa9999a999aaaaa99aaa99a9988999999aaaaaaaaa9999999888889998999999aaaa9aaaa9999899aa998899999aa
97799aaaaaaaaaaaa9aaa9aaa9a98a999aaa9a9999a9aaaa9a979a99aaa98899999aaaaaaaaa9999999999999999a99999aaaa999aaa999889aaaa9899999aaa
7777a9a9aaaaa79aaaaaa99aaaaa99999999aaa99aaaaaa9aa777a999a99988999a9aaaaaa7aa99a99999999999aaa999aaaaa9a99a99a999aaaa9999999aaa9
7777779aaa9a777aaa7a9aaaaaaa9999999aaa99aa7a7779a7777aa9aaa99988899aaaaaa777aaaaa9a999aa799aaaa999a9aaaaa999aaa99aaaa999999aaa99
7777777aa97a7777a7777aaaaaaaa9999aaaaa9aa7777777777777a77a9999999a9a7aa7aa777aaa9aaa7aa777aaaaaa9aa7aaaa7a7aaaa9aaaa9aa9aaaaaa99
77aa97aa7777777aaa7777a9a777a999aaaaa999aa7777777777777777999999aaa7777777a7aaa99aa777a77a97aaa9aa777a9777777aaa7aaaaaaa7aaaaa9a
7a779aa7777777777a97777a777779aaaaa9999aa7777777777777777a99a999aaaa77777777aaaa7aa77a777a777a9aa777a79a777777a77779aaa777aaa9aa
70000000000000000000007777770000000000000000000000007770000000000000777777700000000000000000000aa7000700000000000000000000a0000a
709990909009909990099070007009909990909099909990999077709990999099907777770099099909990099099907a7090709990999099909990990009909
709990909090000900900070907090009090909090909000909077700900909099907000070900090909090900090007aa090a00900009090909090909090008
7090909090999009009077700070900099009090990099009900777709009990909070990709990999099909070990777a090770900090099909900909099908
70909090900090090090007090709090909090909090900090907a7009009090909070000a000909000909090009000777090000900900090909090909000908
a090900990990099900990700070999090900990999099909090aa70990090909090a777770990090a0909009909990777099909990999090909090999099008
a0000000000000000000007aaaa00000000000000000000000007770000000000000aaaaaa0000000a0000000000000777000000000000000000000000000088
aaaaaaaaaaaaaaaaa77777aaaaaa777777777777777777777777777777777777aaaaaaaaaaaaaaaaaaaaaa7a777777777777777777777777777777a999998888

__map__
737764006b362c302c382336233323342c332c322c68705f626f7823775f626f782c3223322c737371237373717c32342c302c30233131233223352c342c322c62617272656c236d696e652c3223312c737371237373717c33322c312c3023382c352c312c656e656d792c322c73636970616407ed303a302c303a302c70726f
6a6d2c352c302e30312c313023392c3330303a3630302c302c302e3939357c303a302c303a302c70726f6a6f2c352c302c3823322c3130303a3130302c302c317c303a302c303a302c70726f6a672c352c302e30312c313123332c3336303a3336302c302c302e39397c303a302c303a302c726f632c362c302c313123392c31
38303a3138302c322c317c2d302e313a2d302e322c2d302e313a302e312c6c696d2c372c302e30322c382331312c3432303a3432302c322c302e39397c303a302c303a302c6b6e6966652c372c302e3030372c3423372c3432303a3432302c322c302e3939397c303a302c303a302c726c70726f6a2c342c302c382c3132303a
3132302c332c317c303a302c303a302c6270726f6a2c342c302c31322c3132303a3132302c332c317c2d302e333a2d302e322c2d302e31373a302e31372c736d6b2c3123322c2d302e3030352c372336233623352c33353a34352c30233123312c317c2d302e313a2d302e312c2d302e313a302e312c736d6b622c322c2d302e
3030312c352c32343a33362c3223312331233023302c317c2d302e313a2d302e312c2d302e313a302e312c736d6b632c322c2d302e3030312c37233623352c35323a36382c312330233023302c317c2d302e313a2d302e332c2d302e32353a302e32352c6475732c322c302e30312c313523362c35323a36382c31233123302c
317c302e30353a302e312c2d302e313a302e312c6865616c2c322c2d302e3030372c372337233723313123332c36303a39302c30233123312c302e39397c303a302c303a302c6869742c322c302c313023372c31363a32322c31233123302c302e37347c303a302c303a302c726869742c322c302c3823322c383a31322c3123
3123302c302e37357c2d302e333a2d302e322c2d302e31373a302e31372c626c6f2c302c302e3031352c3823322c3132303a3138302c302c302e39397c303a302c2d302e313a302e312c6a70612c3123322c2d302e30312c3723313023392c31323a31362c31233123302c302e39387c303a2d302e322c2d302e323a302e322c
6472742c302c302e30312c302c393a39302c302c302e39387c2d302e30323a2d302e30312c2d302e30373a302e30372c6d666c6d2c312c2d302e30312c3723313023392338233223352c34303a36302c302c302e39397c303a302c2d302e323a302e322c666c6d2c322c2d302e3031332c372331302331302339233923382332
2c33333a36362c3123312331233123302c302e39397c2d302e323a2d302e342c2d302e353a302e352c7370612c3023342c302e30312c3723313023392338233523302c34353a38352c312332233223312c302e39387c2d302e353a2d312c2d302e353a302e352c6163692c302c302e30322c313123332c3132303a3138302c30
2c302e3937357c303a302c303a302c736369622c312c302c372331322331332c31323a31362c3523332332233123302c307c303a302c303a302c736369722c312c302c37233823322c31323a31362c3523332332233123302c307c303a302c303a302c736369312c312c302c302c31323a31362c3523332332233123302c307c
303a302c303a302c736369322c312c302c372c31323a31362c313323313123392337233523332332233123302c307c303a302c303a302c737371312c332c302c372c31323a31362c3523332332233123302c307c303a302c303a302c737371322c332c302c372c31323a31362c31332331312339233723352333233223312330
2c307c303a302c303a302c736c69312c342c302c372c34303a34382c33233223312c302e39357c303a302c303a302c736c69322c342c302c372c34343a35322c3523342333233223312c302e39357c303a302c303a302c73686f312c312c302c372c383a31322c302331233223332335233723392c307c303a302c303a302c73
686f322c312c302c372c31323a31362c30233123332335233723392331312331332331352331372c307c303a302c303a302c7273686f312c312c302c37233823322c383a31322c302331233223332335233723392c307c303a302c303a302c6273686f312c312c302c372331322331332c383a31322c30233123322333233523
3723392c307c303a302c303a302c6773686f322c312c302c3723313123332c31323a31362c30233123332335233723392331312331332c307c303a302c303a302c626c6f312c322c302c372331302339233823322c31323a31362c32233323322c302e36367c303a302c303a302c626c6f322c322c302c372331302339233823
322c31323a31362c3323342335233323322c302e36367c303a302c303a302c666c73312c322c302c3723313023392c363a382c30233123302c302e36367c303a302c303a302c666c73322c322c302c3723313023392c383a31322c322333233223312c302e36367c303a302c303a302c72666c73312c322c302c37233823322c
31323a31362c31233223312c302e36367c303a302c303a302c72666c73322c322c302c37233823322c31323a31362c32233323322c302e36367c303a302c303a302c62666c73312c322c302c372331322331332c31323a31362c31233223312c302e36367c303a302c303a302c62666c73322c322c302c372331322331332c31
323a31362c32233323322c302e36367c303a302c303a302c67666c73322c322c302c3723313123332c31323a31362c32233323322c302e36367c303a302c303a302c70726f6a312c312c302e30312c3723392c3330303a3332302c302c302e393937616966002c333b6d656c2c323b6e2c313b73705f692c333b76325f6d6f64
2c313b616e5f692c343b665f792c343b665f787770640332302c382c39302c302e32352c34312c312c666c73322c34302c70726f6a312c302e382c666c73312c322e383a332e322c323a332c302e30312c32322c31352c312e323a312e332c302c362c317c302c312c34352c302e372c34332c322c7370612c34322c6b6e6966
652c302c6e6f70652c363a392c303a302c302e30312c302c32302c313a312c302e30322c32302c317c302c33352c3132302c302e322c34312c332c666c73312c34342c70726f6a312c302e38352c666c73312c302e393a312e312c323a332c302e3031352c362c32352c312e343a312e352c302c362c317c302c352c3131302c
302e31352c34312c342c666c73312c34352c70726f6a312c302e392c666c73322c313a312e332c323a332c302e3032332c33302c33302c302e393a312e332c302c31322c357c36342c342c3131302c312e312c34332c352c62666c732c34342c6270726f6a2c312e322c736369622c363a372c333a342c302c32352c33352c32
3a322c302c31362c317c3332302c312c3132302c322c33352c362c7270672c34382c726f632c312e312c666c73322c373a382c363a372c302e30312c302c34302c302e383a302e392c302c33302c317c302c35302c3130302c302e312c33342c372c736d6b2c34392c666c6d2c302c6e6f70652c302e353a302e382c303a302c
302e30312c31302c34352c302e373a302e392c2d302e30352c302c337c3332342c352c3132302c312e342c33352c382c6772652c312c70726f6a672c302e37352c666c73322c343a362c343a362c302e3032352c36302c35302c312e323a312e332c302e30382c33302c317c35302c312c36302c312c35302c392c6f7262722c
35302c70726f6a6f2c302e382c736369722c383a392c333a342c302e30312c302c35352c302e353a302e362c302c31322c317c3235362c332c37352c302e372c35322c31302c6d6f6c742c35312c70726f6a6d2c302e372c666c73312c322e353a332c333a352c302e30332c33302c36302c302e383a312c302e30322c31382c
337c382c312c302c302e332c34372c31312c72666c732c34362c726c70726f6a2c312c736369722c312e323a322e322c323a342c302e30322c302c3130362c302e383a312c302c362c317370640933353a352c3131383a302c323a3223303a3023303a3023343a347c353a352c3132333a302c323a3223303a3023303a302334
3a347c353a352c3131383a352c323a3223303a3023303a3023343a347c353a352c3132333a352c323a3223303a3023303a3023343a347c353a352c3131383a31302c323a3223303a3023303a3023343a347c353a352c3132333a31302c323a3223303a3023303a3023343a347c343a352c3131383a31352c313a3223303a3023
303a3023333a347c343a352c3132323a31352c313a3223303a3023303a3023333a347c343a352c3131383a32302c313a3223303a3023303a3023333a347c333a322c3132323a32302c313a3123303a3023303a3023323a317c333a322c3132353a32302c313a3123303a3023303a3023323a317c333a322c3132323a32322c31
3a3123303a3023303a3023323a317c333a322c3132353a32322c313a3123303a3023303a3023323a317c3130343a32382c303a302c303a307c31333a372c303a32382c363a307c323a332c3132353a32382c313a3223303a307c333a342c3132353a33312c303a3323323a307c333a322c3132353a33352c303a3123323a307c
343a332c3132343a33372c313a3123333a327c31333a372c31333a32382c363a307c333a332c3131393a34332c323a3223303a307c333a332c3132323a34332c303a3223323a307c333a312c3132353a34332c303a3023323a307c333a332c3132353a34342c303a3023323a327c31333a372c32363a32382c363a307c323a36
2c31333a33352c313a3423313a307c363a362c31353a33352c323a3423343a317c363a322c32313a33352c313a3123353a317c363a352c32313a33372c313a3223343a337c31333a372c33393a32382c363a307c323a362c32373a33352c313a3423303a307c353a352c32393a33352c323a3423343a307c363a322c33353a33
352c313a3123353a307c363a352c33353a33372c313a3123353a347c31333a372c35323a32382c363a307c333a372c34313a33352c323a3523313a307c363a372c34343a33352c313a3523353a307c373a332c35303a33352c313a3223363a317c363a362c35303a33382c313a3223353a357c31333a372c36353a32382c363a
307c333a372c35373a33352c323a3223313a307c363a362c36303a33352c343a3323353a307c373a332c36363a33352c343a3223363a317c363a362c36363a33382c333a3423353a357c31333a372c37383a32382c363a307c333a362c37333a33352c313a3523303a307c343a352c37363a33352c303a3423333a307c363a33
2c38303a33352c303a3123353a307c353a342c38303a33382c303a3023343a337c31333a372c39313a32382c363a307c333a362c38363a33352c313a3423303a307c363a352c38393a33352c313a3423343a307c363a332c39353a33352c313a3123353a307c363a352c39353a33382c313a3123353a337c31333a372c313034
__sfx__
b40100010c36000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
01030000286550f355236350c35509600096000960009600096000960009600096000960009600096000960009600096000960009600096000960009600096000960009600096000960009600096000000000000
8d0700022445530235244553023500205002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
090d00031843018411304150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200001265112671126711267112671326713667038670396603a6603b6503b6503a650396403764035640336402f640266401d64016640116300d6300a6300762005620000000000000000000000000000000
0002000034072340723407234072340723407236671376713a6713d6613f6613f6613f6613f6513e6513d6513c6413964137631336312e62128621226251c6151461510605246001f6001b600156000e6000a600
00020000087510a7710b7710b7620b7620d752147521c742227422a7422f732327223371133701337010e70131702167023300233002330023300133001330013300133001340013200132002340023400234002
0102000004411084210a4210c4210e42110421124311443215432184321b432204422444227442294422a4422b4522d4522f45233462344623546135461364513743136400364003640036400374000000000000
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
00010000190311a0311a0411a0411a0311a001300012e0012c00327003260032005324063280632b0732c0732c0732d0732e0732e0032e0032d00313003070030700307000070000700007000070000700007000
00010000155341d552295750050002500215000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
00010000150741b052290450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002d5242d5312d54100500005001c5611c5611c5511c5511c53500500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100002d0502d0502d0502d0502d0500000000000000000000000000000000000000000000002d0502d0502d0502d0502d0500000000000000000000000000000002d0502d0502d0502d0502d0502d0502d050
00010000246312b6412c6512e6613566136671366713a6713a6713c6713b6713b6713a671396713966139661386623766234662316522d6522b642236421d632196321b6221d6221a61218612126120060000600
0001000025510295102d6102b6102861028610296202b6302d6302e6202e62028620246101d610126101060000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000000001d010210202303027030290402d04030140311503465037660396603c6703c6703a670396703867037670366703667034660306602d6502b65026640236401f6301e6301b620166201461000000
00010000301203113032140321503316032170311702e1602b140316003160026130291502f170121000c10012100111002260023600246002460025600266002660028600296002260022600226000060000600
000100001863019640196501c6001b60018600146000e6400d6200c6100c6000c600006000b6000b6000860006600066000000000000000000000000000000000000000000000000000000000000000000000000
00010000221512415122151221510010000100004000040000400004000040018152181521a1521f15222152251552a1552e15033150361503715036150361500040000400004000040000400004000040000400
000200001561018620196201b6201b6201b6201b620216202163021630226201a6201a62019620196200662006630066301462012620116100e6100c6100c6000860007600076000860008600086000860008600
000100002f0502f06005070060400f0202e3000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
00010000156101d630020400304003040030303203033020320202e0102c010331000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
0001000012660136601364013620136101261012610116100f610116000f6000e6000e6000d6000d6000d6000e60010610166101d6102161023610286102b6102d62030630336403566036670366703666036640
0001000036010370103801039060390502654023530225201e5201f5201f5201f5301f540205501e5501c5401952015520145001d500205002055026530285102c51031510105100b510095100a5000650000500
000100002f3302f33000300173700c37005370003003b3403c3403130031300313003130000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
0001000003020030200302002020030300304036642386523866238662386623866239662396633966338653386533865339653396433964339643396433963339633376253562533625306152c6152a60027600
000100002651127521285312a5412b5412b5422b5420a5420a5320a512000000a5000a5000a500075000750007500075002550025500005000050000500005000050000500005000050000500005000050000500
000100000f5000f5000f5000f50026500285002a5002c5002d5002f5002f5003050033500345000a5000a5000b5000b5000b5000d5110d5110d5110d5210e53211532175421d5522156225572275522754223542
00010000086510a6610b6610967108672096720961209622096322b6522b6622b6622b6722b6722b6722b6622b6622a6622a6522a6522a6522a64229642276322763227622256222561224615216151e61500000
0002000024612266122b6122a6122d6122d6112d6112d6112d6112d6112d6112c6112e6112f6112f6112f6112f61130611306112c621186211862117611176111761717617176171661716617156171561738600
0001000016060190701e0500000000000000000000000050000700007000070010700207002060020500205001040010400004000030000300103001020000100005000050000000000000000000000000000000
0001000036171311712e1612a15126151251420314205132051320512205122041120411504135041550517500000062000620000000000000000000000000000000000000000000000000000000000000000000
00010000080410e06112071190711e071260712b0712e6723267236672386623a6523b6323d6223e6223d6123f6123f6123f6123f6123f6123e6123f6123f6120c0120c0220d0221303518035240452d0552e075
00010000106201162000000000001a6201b6202f6102e610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101000005662076720a672096720966209652086320762225600256000502205022020620207224600156000060015600146001460014600116000c6000a6000960008600086000860008600086000860008600
000100000503605046000060000008616096260a63632656326613166130651062000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000291102c11031120301303314036150361503615035160351603516036170361703717037170341703216036150361503714038140391303a14039140371503815036150351603716039160391603b160
0002000028703297502975029750297500c7000a7000070029700297002970029700287002975029750297502975029700297002970029700287002f000200502005020050200502005020050200502005020050
000200001a5501a5501a550215000950022550225502255022550225500550008500265502655026550265502655004500045001e5521e5521e5521e5521e5521e5521e5521e5521e5521e5521e5521e5521f552
000100003041233432234422d442314520d4623247232462104420d43200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000120111a03121051270612b0712e0723207236072380723907239072390623a0523b0423b0323b02200000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000024421284412d451314623247234472324122741228422294222b4222d4322e4312e4312f4312f4313143231432324423244236442394413b4413c4413c4413c4513c4513c4513c4623e4623f4423d412
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
