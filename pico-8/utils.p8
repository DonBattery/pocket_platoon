pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function rand(l, h) return rnd(abs(h - l)) + min(l, h) end
function randint(l, h) return flr(rnd(abs(h + 1 - l))) + min(l, h) end

function pprint(s, x, y, c1, c2, ind, out)
  x -= ind == "r" and print(s, 0, 128) or ind == "c" and print(s, 0, 128) / 2 or 0
  if out then
    for ox = -1, 1 do
      for oy = -1, 1 do
        if (ox | oy != 0) print(s, x + ox, y + oy, c2)
      end
    end
  end
  print(s, x, y, c1)
end

function get_px(x, y)
  if x < 0 or x > 127 or y < 8 then return 16 end
  if y > 119 then return 17 end
  x, y = flr(x), flr(y)
  local byte_val = peek(0x8000 + y * 64 + flr(x / 2))
  if x % 2 == 0 then
    return byte_val & 0x0f
  end
  return (byte_val >> 4) & 0x0f
end

function set_px(x, y, col)
  if x < 0 or x > 127 or y < 8 or y > 119 then return end
  x, y = flr(x), flr(y)
  local addr = 0x8000 + y * 64 + flr(x / 2)
  local byte_val = peek(addr)
  if x % 2 == 0 then
    byte_val = (byte_val & 0xf0) | (col & 0x0f)
  else
    byte_val = (byte_val & 0x0f) | ((col & 0x0f) << 4)
  end
  poke(addr, byte_val)
end

_v2 = {}
_v2.__index = _v2
function _v2:new(x, y) return setmetatable({ x = x or 0, y = y or 0 }, self) end
function v2(x, y) return _v2:new(x, y) end
function _v2:__add(o) return _v2:new(self.x + o.x, self.y + o.y) end
function _v2:__sub(o) return _v2:new(self.x - o.x, self.y - o.y) end
function _v2:__mul(s) return _v2:new(self.x * s, self.y * s) end
function _v2:__div(s) return _v2:new(self.x / s, self.y / s) end
function _v2:__len() return sqrt(self.x ^ 2 + self.y ^ 2) end
function _v2:norm() local m = #self return m > 0 and self / m or v2() end
function _v2:rnd() return _v2:new(1, 0):rot(rnd()) end
function _v2:rand(lx, hx, ly, hy) return _v2:new(rand(lx, hx), rand(ly, hy)) end
function _v2:randint(lx, hx, ly, hy) return _v2:new(randint(lx, hx), randint(ly, hy)) end
function _v2:floor() return _v2:new(flr(self.x), flr(self.y)) end
function _v2:sqrdist(o) return (o.x - self.x) ^ 2 + (o.y - self.y) ^ 2 end
function _v2:limit(limit) self.x, self.y = mid(-limit[1], self.x, limit[1]), mid(limit[2], self.y, limit[3]) end
function _v2:rot(a) local c, s = cos(a), sin(a) return _v2:new(self.x * c - self.y * s, self.x * s + self.y * c) end

function pal_spec(v)
  local t = {}
  for i = 1, 16 do
    add(t, v)
  end
  pal(t, 0)
end

function parse_string_data(d, f)
  local r = {}
  for s in all(split(d, "|")) do
    add(r, f(split(s, ",")))
  end
  return r
end

function menu_parser(data, width, submitfn)
  return setmetatable(
    {
      y = 1,
      w = width,
      opts = parse_string_data(
        data, function(p)
          add(p, 1, 1)
          return p
        end
      ),
      submit = submitfn,
      cd = 10,

      draw = function(_ENV, pos)
        cd = max(cd - 1, 0)
        for p in all(players) do
          if p.connected then
            local joy = p.joy
            if joy.up.pressed then
              y = max(y - 1, 1)
              sfx(29)
            elseif joy.down.pressed then
              y = min(y + 1, #opts)
              sfx(29)
            end

            local opt = opts[y]
            if joy.left.pressed then
              opt[1] = max(opt[1] - 1, 1)
              sfx(30)
            elseif joy.right.pressed then
              opt[1] = min(opt[1] + 1, #opt - 2)
              sfx(30)
            end

            if cd < 1 and (joy.x.pressed or joy.o.pressed) then
              cd = 10
              sfx(31)
              submit(opts, y)
            end
          end
        end

        for i, opt in ipairs(opts) do
          for j = 2, #opt do
            local sel = y == i and j == opt[1] + 2 and j > 2
            local c = sel and 10 or (j > 2 and j == opt[1] + 2) and 6 or (j == 2 and i == y and 11 or (j > 2 and 5 or 3))
            pprint(opt[j], (j - 2) * w + pos.x - (y == i and 1 or 0), (i - 1) * 9 + pos.y + (sel and -1 or 0), c, 0, "l", true)
          end
        end
      end
    }, { __index = _ENV }
  )
end

function effect_parser(parts)
  local effect = {}
  for i, key in ipairs(split("name,fg_chance,force_mul,min_life,max_life,min_x_spd,max_x_spd,min_y_spd,max_y_spd,min_x_acc,max_x_acc,min_y_acc,max_y_acc,kinds,sizes,colors", ",")) do
    if i > 1 and i < 14 then
      effect[key] = tonum(parts[i])
    else
      effect[key] = {}
      for token in all(split(parts[i], "-")) do
        add(effect[key], tonum(token))
      end
    end
  end
  _g[parts[1]] = function(pos, burst, force, spread, delay, cone, alt_colors, on_update)
    burst, force, spread, delay, cone, alt_colors = burst or 1, (force or v2()):norm() * effect.force_mul, spread or 0, delay or 0, cone or 0, alt_colors and alt_colors or effect.colors
    for i = 1, burst do
      new_particle(
        effect.fg_chance,
        randint(0, delay),
        randint(effect.min_life, effect.max_life),
        rnd(effect.kinds),
        pos + _v2:rnd() * rand(0, spread),
        (_v2:rand(effect.min_x_spd, effect.max_x_spd, effect.min_y_spd, effect.max_y_spd) + force):rot(rand(-cone, cone)),
        _v2:rand(effect.min_x_acc, effect.max_x_acc, effect.min_y_acc, effect.max_y_acc),
        effect.sizes,
        alt_colors,
        on_update
      )
    end
  end
end

function sprite_parser(parts)
  local nums = {}
  for part in all(parts) do
    add(nums, tonum(part))
  end

  local sprite = setmetatable(
    {
      spos = v2(parts[1], parts[2]),
      size = v2(parts[3], parts[4]),
      points = {},
      flipped = {},
      get_point = function(_ENV, index, pos, flip_x, flip_y)
        local base, base_flip = points[1], flipped[1]
        local origin = v2(pos.x - (flip_x and base_flip.x or base.x), pos.y - (flip_y and base_flip.y or base.y))
        if index == 1 then return origin end
        local pt, pt_flip = points[index], flipped[index]
        return v2(origin.x + (flip_x and pt_flip.x or pt.x), origin.y + (flip_y and pt_flip.y or pt.y))
      end,
      draw = function(_ENV, pos, flip_x, flip_y)
        local origin = get_point(_ENV, 1, pos, flip_x, flip_y)
        sspr(spos.x, spos.y, size.x, size.y, origin.x, origin.y, size.x, size.y, flip_x, flip_y)
      end
    }, { __index = _ENV }
  )

  for i = 5, #parts, 2 do
    local pt = v2(parts[i], parts[i + 1])
    add(sprite.points, pt)
    add(sprite.flipped, (sprite.size - v2(1, 1)) - pt)
  end

  return sprite
end

function animation_parser(data)
  local animations = {}
  for anim_data in all(split(data, "|")) do
    local parts, frames = split(anim_data, ","), {}
    for i = 1, #parts do
      add(frames, tonum(parts[i]))
    end
    add(
      animations,
      {
        frames = frames,
        len = #frames,
        cur = 1,
        timer = 0,
        update = function(_ENV)
          if len > 1 then
            timer = (timer + 1) % 6
            if (timer == 0) cur = (cur % len) + 1
          end
        end
      }
    )
  end
  return {
    cur = 1,
    animations = animations,
    times = 0,
    played = 0,
    force = false,
    after = nil,
    runs = false,
    update = function(_ENV)
      if not runs then return end
      local anim = animations[cur]
      anim:update()
      if anim.timer == 0 and anim.cur == 1 then
        played += 1
        force = false
        if times > 0 and played >= times then
          runs = false
          if after then
            after()
            after = nil
          end
        end
      end
    end,
    play = function(_ENV, id, times, forced, after)
      if cur == id or force and not forced then return end
      cur, times, force, after, played, runs = id, times or 0, forced == true, after, 0, true
    end,
    get_frame = function(_ENV)
      local a = animations[cur]
      return a.frames[a.cur]
    end
  }
end

function weapon_parser(parts)
  local weapon = {}
  for i, key in ipairs(split("id,dmg_type,min_dmg,max_dmg,magazine,reload_time,burst,min_life,max_life,weapon_cd,kind,accuracy,min_force,max_force,mass,v_modifier,sizes,colors", ",")) do
    if i < 17 then
      weapon[key] = tonum(parts[i])
    else
      weapon[key] = {}
      for token in all(split(parts[i], "-")) do
        add(weapon[key], tonum(token))
      end
    end
  end
  return weapon
end

function player_parser(parts)
  local nums = {}
  for part in all(parts) do
    add(nums, tonum(part))
  end
  local hud_points = {}
  for i = 4, #nums, 2 do
    add(hud_points, v2(nums[i], nums[i + 1]))
  end
  return new_player(nums[1], nums[2], nums[3], hud_points, nums[1] % 2 == 1)
end

function round_box(pos, size, col)
  rectfill(pos.x, pos.y + 1, pos.x + size.x - 1, pos.y + size.y - 2, col)
  rectfill(pos.x + 1, pos.y, pos.x + size.x - 2, pos.y + size.y - 1, col)
end

function bsort(t, cond)
  local length, swapped = #t
  if length < 2 then return t end
  repeat
    swapped = false
    for i = 2, length do
      if cond(t[i], t[i - 1]) then
        t[i], t[i - 1] = t[i - 1], t[i]
        swapped = true
      end
    end
    length -= 1
  until not swapped
  return t
end

function point_collide_with_rect(p, r)
  return p.x < r.pos.x + r.size.x
      and p.x >= r.pos.x
      and p.y < r.pos.y + r.size.y
      and p.y >= r.pos.y
end

function rect_collide_with_rect(a, b)
  return a.pos.x < b.pos.x + b.size.x
      and a.pos.x + a.size.x > b.pos.x
      and a.pos.y < b.pos.y + b.size.y
      and a.pos.y + a.size.y > b.pos.y
end

function points_between(p1, p2)
  local points, x1, y1, x2, y2 = {}, flr(p1.x), flr(p1.y), flr(p2.x), flr(p2.y)
  local dx, dy, sx, sy, err = abs(x2 - x1), abs(y2 - y1), x1 < x2 and 1 or -1, y1 < y2 and 1 or -1, abs(x2 - x1) - abs(y2 - y1)
  while true do
    add(points, v2(x1, y1))
    if x1 == x2 and y1 == y2 then return points end
    if 2 * err > -dy then
      err -= dy
      x1 += sx
    end
    if 2 * err < dx then
      err += dx
      y1 += sy
    end
  end
end

function free_rect(pos, size)
  for x = pos.x, pos.x + size.x - 1 do
    for y = pos.y, pos.y + size.y - 1 do
      if (get_px(x, y) ~= 1) return false
    end
  end
  return true
end

function new_button(p_id, b_id)
  return setmetatable(
    {
      pid = p_id,
      bid = b_id,
      update = function(_ENV)
        local press = btn(bid, pid)
        isdown, pressed, released, hold = press, press and not prev, not press and prev, press and prev
        prev = press
        return press
      end
    }, { __index = _ENV }
  )
end

function new_joystick(pid)
  return setmetatable(
    {
      left = new_button(pid, 0),
      right = new_button(pid, 1),
      up = new_button(pid, 2),
      down = new_button(pid, 3),
      o = new_button(pid, 4),
      x = new_button(pid, 5),
      dir = "",
      update = function(_ENV)
        local left, right, up, down = left:update(), right:update(), up:update(), down:update()
        x:update()
        o:update()
        dir = ((up and not down and "n") or (down and not up and "s") or "") .. ((left and not right and "w") or (right and not left and "e") or "")
      end
    }, { __index = _ENV }
  )
end

cooldowns = {}

function update_cooldowns()
  for name, cd in pairs(cooldowns) do
    if cd.timer > 0 then
      cooldowns[name].timer -= 1
    else
      if cd.trigger then cd:trigger() end
      if (cd.timer == 0) cooldowns[name] = nil
    end
  end
end

function new_particle_system()
  return {
    particles = {},
    update = function(self)
      for particle in all(self.particles) do
        if particle.delay > 0 then
          particle.delay -= 1
        else
          particle.life += 1
          particle.spd += particle.acc
          local end_of_life, next_pos = particle.life >= particle.max_life, particle.pos + particle.spd
          local outside = not point_collide_with_rect(next_pos, game_rect)
          if particle.on_update then
            end_of_life = particle:on_update(next_pos, outside)
          else
            end_of_life = end_of_life or outside
          end
          particle.pos = next_pos
          if (end_of_life) del(self.particles, particle)
        end
      end
    end,
    draw = function(self)
      for particle in all(self.particles) do
        if particle.delay <= 0 then
          local x, y, t = particle.pos.x, particle.pos.y, particle.life / particle.max_life
          local size, color = particle.sizes[min(flr(t * particle.number_of_sizes) + 1, particle.number_of_sizes)], particle.colors[min(flr(t * particle.number_of_colors) + 1, particle.number_of_colors)]
          if particle.kind == 0 then
            local half = size / 2
            rectfill(x - half, y - half, x + half, y + half, color)
          elseif particle.kind == 1 then
            pset(x, y, color)
          elseif particle.kind == 2 then
            circ(x, y, size, color)
          elseif particle.kind == 3 then
            circfill(x, y, size, color)
          elseif particle.kind == 4 then
            local dir = particle.spd:norm() * size
            line(x, y, x + dir.x, y + dir.y, color)
          elseif particle.kind == 5 then
            local dir = particle.pos + (particle.spd:norm():rot(particle.life / 50) * 3)
            line(x, y, dir.x, dir.y, color)
            pset(x, y, 4)
          elseif particle.kind == 6 then
            local dir = particle.pos + particle.spd:norm() * 3
            line(x, y, dir.x, dir.y, color)
            pset(x, y, 10)
          end
        end
      end
    end
  }
end

function new_particle(fg_chance, delay, max_life, kind, pos, spd, acc, sizes, colors, on_update, weapon, owner)
  add(
    rnd() < fg_chance and fg_particles.particles or bg_particles.particles, {
      max_life = max_life,
      delay = delay or 0,
      life = 0,
      kind = kind,
      pos = pos,
      spd = spd,
      acc = acc,
      number_of_sizes = #sizes,
      sizes = sizes,
      number_of_colors = #colors,
      colors = colors,
      on_update = on_update,
      weapon = weapon,
      owner = owner
    }
  )
end

function update_bullet(bullet, next_pos)
  local points, weapon, spd, objects, hit_obj, hit_ground = points_between(bullet.pos, next_pos), bullet.weapon.id, bullet.spd, world:get_objects(bullet, 64)

  if weapon == 6 and rnd() < .3 then
    smoke(points[1], randint(1, 3))
  end

  for i = 1, #points do
    local p = points[i]

    for o in all(objects) do
      if point_collide_with_rect(p, o:get_hitbox()) then
        if bullet.life > 10 or o.owner ~= bullet.owner then
          o:impact(bullet.owner, bullet.spd, 3, bullet.weapon.min_dmg, bullet.weapon.max_dmg)
          hit_obj = true
          break
        end
      end
    end

    local c = get_px(p.x, p.y)
    if not hit_obj and c ~= 1 then
      if c == 16 and (p.x < 0 or p.x > 127 or p.y < 8) then return true end
      hit_ground = true
    end

    if hit_obj or hit_ground then
      if weapon == 2 then
        if hit_ground then
          if p.y < 120 then
            set_px(p.x, p.y, 7)
          end
          if i > 1 and points[i - 1].y < 120 then
            set_px(points[i - 1].x, points[i - 1].y, 4)
          end
        end
      elseif weapon == 7 then
        smoke(p, 2)
        if hit_ground and c ~= 0 then
          if p.y < 120 then
            set_px(p.x, p.y, 0)
          end
        elseif rnd() < .35 then
          kill_px(p, 0, spd)
        end
      elseif weapon == 6 then
        explosion(bullet.owner, p, spd, 3)
      elseif weapon == 1 then
        flash_struct(p, spd, 1, randint(1, 3))
      elseif weapon == 3 then
        flash_struct(p, spd, randint(1, 2), randint(1, 2))
      elseif weapon == 4 then
        flash_struct(p, spd, randint(1, 2), randint(1, 3))
      elseif weapon == 8 then
        flash_struct(p, spd, 3, randint(1, 3))
      else
        explosion(bullet.owner, p, spd, 1)
      end
      return true
    end
  end
end

function create_destructor(r)
  local destructor = {}
  for x = 0, 2 * r + 1 do
    for y = 0, 2 * r + 1 do
      if pget(x, y) == 1 then
        add(destructor, { x - r, y - r })
      end
    end
  end
  return destructor
end

function init_destructors()
  for r = 0, 10 do
    cls()
    circfill(r, r, r, 1)
    add(destructors, create_destructor(r))
  end
  for pos in all({ v2(), v2(1, 0), v2(0, 1), v2(1, 1) }) do
    cls()
    rectfill(pos.x, pos.y, pos.x + 1, pos.y + 1, 1)
    add(edge_destructors, create_destructor(1))
  end
end

function kill_px(pos, c, dir)
  if pos.y > 119 then return end
  set_px(pos.x, pos.y, 1)
  dirt(pos, 1, dir, 0, 0, .25, { c })
end

function destruct(pos, dir, size)
  for point in all((size == 1 and rnd() > .2) and rnd(edge_destructors) or destructors[size]) do
    local sx, sy = pos.x + point[1], pos.y + point[2]
    if sy < 120 then
      local color = get_px(sx, sy)
      if color ~= 1 then
        if rnd() < ((color == 5 and 0.1) or (color == 6 and 0.3) or 2) then
          kill_px(v2(sx, sy), color, dir)
        else
          set_px(sx, sy, 0)
        end
      end
    end
  end
end

function spawn_effect(pos, type, color1, color2)
  local colors = { 7, color1, color2 }
  _g["spawn_" .. type .. "_1"](pos, 1, v2(), 0, 0, 0, colors)
  _g["spawn_" .. type .. "_2"](pos, 1, v2(), 0, 10, 0, colors)
  for i = 1, randint(15, 20) do
    local p_pos = pos + _v2:rand(7, 12, 0, 0):rot(rnd())
    spawn_line(p_pos, 1, pos - p_pos, 0, 15, 0, colors)
  end
end

function blood_effect(pos, burst, force, spread, delay, cone)
  blood(
    pos, burst, force, spread, delay, cone, nil, function(self, next_pos, outside)
      if outside then return true end
      if next_pos.y < 120 and (get_px(next_pos.x, next_pos.y) ~= 1 and rnd() < .3) then
        set_px(next_pos.x, next_pos.y, rnd(self.colors))
        return true
      end
    end
  )
end

function explosion(owner, pos, dir, size)
  destruct(pos, dir, size * 2)
  smoke(pos, size * 3, dir, size * 3, size * 2)
  _g["explosion_blob_" .. size](pos, size * 3, dir, size * 2, size * 3)
  _g["explosion_shock_" .. size](pos)
  local sizes = { 64, 196, 300 }
  for object in all(world:get_objects({ pos = pos }, sizes[size])) do
    object:impact(owner, (object.pos - pos):norm() * size, 4, size * 2, size * 3, size * 6, physics_constants.exploded_speed_limit)
  end
end

function flash_struct(pos, dir, size, destruct_size, colors)
  destruct(pos, dir, destruct_size)
  _g["flash_" .. size](pos, 1, dir, size, 0, 0, colors)
  if (rnd() < .3 * size) smoke(pos, size, dir, size, 6)
end

function new_world()
  return {
    objects = {},

    add_object = function(self, object)
      add(self.objects, object)
    end,

    get_objects = function(self, obj, sqrdist, type)
      local near_objects = {}
      for object in all(self.objects) do
        if not (type and object.type ~= type) and object ~= obj then
          if sqrdist == 0 or object.pos:sqrdist(obj.pos) < sqrdist then
            add(near_objects, object)
          end
        end
      end
      return near_objects
    end,

    get_safe_spot = function(self, size)
      while true do
        local pos = _v2:randint(size + 1, 127 - size, 9 + size, 111 - size)
        local objects = self:get_objects({ pos = pos }, size * size)
        if (#objects == 0 and free_rect(pos - v2(size, size), v2(size * 2 + 1, size * 2 + 1))) then
          return pos
        end
      end
    end,

    update = function(self)
      for i = #self.objects, 1, -1 do
        if self.objects[i]:update() then
          deli(self.objects, i)
        end
      end
    end,

    draw = function(self)
      for object in all(self.objects) do
        object:draw()
      end
    end
  }
end

function shoot(pos, aim, dir, weapon, owner)
  for i = 1, weapon.burst do
    local spd = (dir * rand(weapon.min_force, weapon.max_force)):rot(rand(-weapon.accuracy, weapon.accuracy))
    if aim == "w" or aim == "e" then
      spd.y -= weapon.v_modifier
    end
    new_particle(.1, 0, randint(weapon.min_life, weapon.max_life), weapon.kind, pos, spd, v2(0, weapon.mass), weapon.sizes, weapon.colors, update_bullet, weapon, owner)
  end
  return weapon.weapon_cd
end

function new_game_object(obj_type, spot, obj_offset, obj_size, max_hp, is_climber, anim_data, on_impact_fn, on_suffer_fn, on_update_fn, on_before_draw_fn, on_after_draw_fn, on_die_fn)
  return setmetatable(
    {
      type = obj_type,
      pos = spot,
      offset = obj_offset,
      size = obj_size,
      hp = max_hp,
      climber = is_climber,
      owner = 0,
      anim = animation_parser(anim_data),
      on_impact = on_impact_fn,
      on_suffer = on_suffer_fn,
      on_update = on_update_fn,
      on_before_draw = on_before_draw_fn,
      on_after_draw = on_after_draw_fn,
      on_die = on_die_fn,
      real_pos = spot,
      spd = v2(),
      gravity = physics_constants.air_gravity,
      friction = physics_constants.air_friction,
      speed_limit = physics_constants.air_speed_limit,
      qhp = ceil(max_hp / 4),
      in_air = 0,
      suffering = false,
      grounded = false,
      face_left = false,
      face_down = false,
      remove = false,
      cooldowns = {
        hit = 12
      },
      get_hitbox = function(_ENV)
        local sprite = sprites[anim:get_frame()]
        local point_a, point_b = sprite:get_point(3, pos, face_left, face_down), sprite:get_point(4, pos, face_left, face_down)
        return {
          pos = v2(min(point_a.x, point_b.x), min(point_a.y, point_b.y)),
          size = v2(abs(point_a.x - point_b.x) + 1, abs(point_a.y - point_b.y) + 1)
        }
      end,
      update = function(_ENV)
        if remove then
          return true
        end
        anim:update()
        for key, val in pairs(cooldowns) do
          cooldowns[key] = val > 0 and val - 1 or nil
        end
        if hp <= qhp then
          suffering = true
          if (rnd() < .03) on_suffer(pos)
        else
          suffering = false
        end
        if free_rect(v2(pos.x + offset.x, pos.y + offset.y + size.y), v2(size.x, 1)) then
          in_air += 1
          grounded = false
        else
          in_air, grounded = 0, true
        end
        if not cooldowns.force_move then
          if grounded then
            gravity, friction, speed_limit = physics_constants.ground_gravity, physics_constants.ground_friction, physics_constants.ground_speed_limit
          else
            gravity, friction, speed_limit = physics_constants.air_gravity, physics_constants.air_friction, physics_constants.air_speed_limit
          end
        end
        spd += on_update(_ENV)
        spd:limit(speed_limit)
        spd *= friction
        if (abs(spd.x) < 0.005) spd.x = 0
        if (abs(spd.y) < 0.005) spd.y = 0
        local next_pos = real_pos + spd
        local points = points_between(real_pos, next_pos)
        local len = #points
        if len > 1 then
          for i = 2, len do
            local prev_point = points[i - 1]
            local can, block, res = step_one(_ENV, prev_point, points[i] - prev_point)
            if not can then
              spd.x *= (not climber and block.x == 0) and -.8 or block.x
              spd.y *= (not climber and block.y == 0) and -.8 or block.y
              next_pos = res and res + v2(.5, .5) or prev_point + v2(.5, .5)
              break
            end
          end
        end
        real_pos, pos = next_pos, next_pos:floor()
      end,
      step_one = function(_ENV, pos, step)
        if not legal_step(_ENV, pos, step) then
          if step.x ~= 0 then
            if step.y ~= 0 then
              if legal_step(_ENV, pos, v2(step.x, 0)) then
                return false, v2(.75, 0), pos + v2(step.x, 0)
              elseif legal_step(_ENV, pos, v2(0, step.y)) then
                return false, v2(0, .75), pos + v2(0, step.y)
              end
            else
              if legal_step(_ENV, pos, v2(step.x, -1)) then
                return false, v2(.75, 1), pos + v2(step.x, -1)
              elseif climber and legal_step(_ENV, pos, v2(step.x, -2)) then
                return false, v2(.3, .75), pos + v2(step.x, -2)
              elseif legal_step(_ENV, pos, v2(step.x, 1)) then
                return false, v2(.75, .75), pos + v2(step.x, 1)
              end
            end
          elseif step.y < 0 then
            if (legal_step(_ENV, pos, v2(face_left and -1 or 1, -1))) return false, v2(.5, .75), pos + v2(face_left and -1 or 1, -1)
          else
            return false, v2(1, 0)
          end
          return false, v2()
        end
        return true
      end,
      legal_step = function(_ENV, pos, step)
        if (step.x ~= 0 and not free_rect(pos + offset + (step.x < 0 and v2(-1, step.y) or v2(size.x, step.y)), v2(1, size.y))) return false
        if (step.y ~= 0 and not free_rect(pos + offset + (step.y < 0 and v2(step.x, -1) or v2(step.x, size.y)), v2(size.x, abs(step.y)))) return false
        return true
      end,
      impact = function(_ENV, dmg_owner, force, dmg_type, min_dmg, max_dmg, cd, limit)
        if remove then return end
        spd += force
        cooldowns.force_move, speed_limit, friction = cd, limit, 1
        hp -= on_impact(_ENV, dmg_owner, force, dmg_type, min_dmg, max_dmg)
        if hp <= 0 then
          remove = true
          on_die(_ENV, dmg_owner, force, dmg_type)
        end
      end,
      draw = function(_ENV)
        palt(0b0000000000000010)
        if on_before_draw then on_before_draw(_ENV) end
        sprites[anim:get_frame()]:draw(pos, face_left, face_down)
        if on_after_draw then on_after_draw(_ENV) end
        palt()
        pal()
      end
    }, { __index = _ENV }
  )
end

function new_box(type, spot, offset, size, hp, anim_data, on_soldier_contact, on_die)
  return new_game_object(
    type, spot, offset, size, hp, false, anim_data,
    function(_ENV, dmg_owner, force, dmg_type, min_dmg, max_dmg)
      local dmg = rand(min_dmg, max_dmg)
      on_suffer(pos, ceil(dmg), force, 2)
      return dmg
    end,
    smoke,
    function(_ENV)
      local hitbox = get_hitbox(_ENV)
      for soldier in all(world:get_objects(_ENV, 64, 1)) do
        if not remove and rect_collide_with_rect(hitbox, soldier:get_hitbox()) then
          on_soldier_contact(_ENV, soldier)
        end
      end
      return v2(0, gravity)
    end,
    function(_ENV)
      if cooldowns.hit then pal_spec(suffering and 10 or 7) end
    end,
    nil,
    on_die
  )
end

function new_hp_box(spot)
  return new_box(
    2, spot, v2(-2, -2), v2(5, 5), 3, "44",
    function(_ENV, soldier)
      if soldier.hp < 10 then
        heal(soldier.pos, ceil(10 - soldier.hp))
        soldier.hp, remove = 10, true
      end
    end,
    function(_ENV, dmg_owner, dmg_dir)
      flash_struct(pos, dmg_dir, 2)
    end
  )
end

function new_weapon_box(spot)
  return new_box(
    3, spot, v2(-2, -2), v2(5, 5), 5, "45",
    function(_ENV, soldier)
      local prev_weapon_id = soldier.weapon.id
      while soldier.weapon.id == prev_weapon_id do
        soldier.weapon = weapons[randint(2, 7)]
      end
      soldier.cooldowns.weapon, soldier.cooldowns.reload, soldier.magazine, remove = 0, 0, soldier.weapon.magazine, true
    end,
    function(_ENV, dmg_owner, dmg_dir)
      explosion(dmg_owner, pos, dmg_dir, 2)
    end
  )
end

function new_barrel(spot)
  return new_box(
    4, spot, v2(-1, -2), v2(4, 5), 6, "46", function() end,
    function(_ENV, dmg_owner)
      explosion(owner, pos, _v2:rand(-.1, .1, -.7, -.1), 3)
    end
  )
end

function new_enemy(spot)
  local enemy = new_game_object(
    6, spot, v2(-2, -2), v2(5, 5), 8, false, "56|59|60|64|63|61,62,62|57,57,57,58,58,58,58,58,58,58,58",
    function(_ENV, owner, force, dmg_type, min_dmg, max_dmg)
      cooldowns.hit = 6
      local dmg = rand(min_dmg, max_dmg)
      on_suffer(pos, ceil(dmg), force, 2)
      return owner == 0 and 0 or dmg
    end,
    spark,
    function(_ENV)
      anim:update()
      if not cooldowns.stuck then
        cooldowns.stuck = randint(15, 45)
        if pos:sqrdist(prev_pos) < 8 then
          stucked += 1
        end
        prev_pos = pos
        if stucked > 3 then
          stucked = 0
          dir = v2(1, 0):rot(rnd())
          cooldowns.unstuck = randint(55, 95)
        end
      end
      local acc = v2(0, .008)
      local can_control = not (cooldowns.force_move or anim.force)
      if not can_control then
        return acc
      end
      if target and target.remove then
        target = nil
      end
      if not cooldowns.search then
        cooldowns.search = randint(60, 90)
        local soldiers = bsort(world:get_objects(_ENV, 0, 1), function(a, b) return a.pos:sqrdist(pos) < b.pos:sqrdist(pos) end)
        if #soldiers > 0 then
          target = soldiers[1]
        end
      end
      if target then
        dir = not cooldowns.unstuck and (target.pos - pos):norm() or dir
        if dir.x < 0 then
          face_left = true
          acc.x = -.009
        elseif dir.x > 0 then
          face_left = false
          acc.x = .009
        end
        if dir.y < 0 then
          face_down = false
          acc.y = -.007
        else
          face_down = true
        end
        if not cooldowns.melee then
          if (pos:sqrdist(target.pos) < 64) and rnd() < .03 then
            -- sfx(29)
            anim:play(6, 1, true)
            local force = rand(.8, 1.2)
            target:impact(0, v2(face_left and -force or force, rand(-.5, -.3)), 1, 1.2, 2.8, 16, physics_constants.air_speed_limit)
            cooldowns.melee = randint(90, 120)
          end
        end
        if not cooldowns.unstuck and not cooldowns.shoot and rnd() < .01 then
          cooldowns.shoot = randint(30, 60)
          local w_pos = sprites[anim:get_frame()]:get_point(2, pos, face_left, face_down)
          local dir = (target.pos - w_pos):norm()
          shoot(w_pos, "", dir, weapons[8], 0)
        end
      end
      -- if not self.anim.force then
      if abs(spd.x) > .2 then
        anim:play(7, 1, true)
      else
        local s = 1
        if abs(dir.y) > .2 then
          s = 2
        end
        if abs(dir.y) > .65 then
          s = 3
        end
        anim:play(s)
        -- end
      end
      return acc
    end,
    function(_ENV)
      if (cooldowns.hit) pal_spec(suffering and 8 or 7)
    end,
    function(_ENV)
      local eye_pos = sprites[anim:get_frame()]:get_point(2, pos, face_left, face_down)
      pset(eye_pos.x, eye_pos.y, suffering and 2 or 8)
      if (cooldowns.hit) circfill(eye_pos.x, eye_pos.y, 1, 0)
    end,
    function(_ENV, dmg_owner, force, dmg_type)
      spark(pos, randint(5, 11), force, 3, 7)
      explosion(dmg_owner, pos, force, 1)
      if dmg_owner ~= 0 then
        players[dmg_owner].score += 1
      end
    end
  )

  enemy.prev_pos = spot
  enemy.stucked = 0
  enemy.dir = _v2:rnd()

  return enemy
end

function new_soldier(spot, owner, joy, color1, color2)
  local soldier = new_game_object(
    1, spot, v2(-1, -3), v2(3, 6), 10, true, "1|3|2|8|10|12|1,4,5,11|1,13,14,14|1,5,6,6|1,10,10,8,12,9,7,15|1,15,15,7,9,12,8,10",
    function(_ENV, dmg_owner, force, dmg_type, min_dmg, max_dmg)
      local dmg = rand(min_dmg, max_dmg)
      on_suffer(pos, ceil(dmg), force, 2)
      return dmg
    end,
    blood_effect,
    function(_ENV)
      if not cooldowns.reload and prev_reload then
        magazine = weapon.magazine
      end
      prev_reload = cooldowns.reload
      local joy, h_dir, forced_anim, acc = joy, face_left and -1 or 1, anim.force, v2(0, gravity)
      local can_control = not (cooldowns.force_move or forced_anim)
      local head_free = legal_step(_ENV, pos, v2(0, -1)) or legal_step(_ENV, pos, v2(h_dir, -1))
      if head_free then
        head_free_for += 1
      else
        head_free_for = 0
      end
      if can_control and joy.o.hold then
        jetpack(pos + v2(-h_dir * 2, 1))
        if head_free then
          acc.y = physics_constants.jetpack_force
        else
          acc.y = 0
        end
      end

      if can_control then
        side_blocked = not (legal_step(_ENV, pos, v2(h_dir, 0)) or legal_step(_ENV, pos, v2(h_dir, -1)) or legal_step(_ENV, pos, v2(h_dir, 1)) or legal_step(_ENV, pos, v2(h_dir, -2)))
        local move_acc = grounded and physics_constants.ground_acc or physics_constants.air_acc
        if joy.left.isdown and not joy.right.isdown then
          face_left, acc.x = true, (not side_blocked and -move_acc or 0)
        elseif joy.right.isdown and not joy.left.isdown then
          face_left, acc.x = false, (not side_blocked and move_acc or 0)
        end
        if not cooldowns.aim then
          if joy.dir ~= "" then
            aim = joy.dir
            cooldowns.aim = 6
          end
        end
        if joy.x.isdown and not (cooldowns.melee and cooldowns.weapon) then
          local melee, _, weapon_pos = false, get_weapon_pos(_ENV)
          if not cooldowns.melee then
            local objects = world:get_objects(_ENV, 72)
            local len, is_knife = #objects, weapon.id == 2
            if len > 0 then
              local hit_box = get_hitbox(_ENV)
              for obj in all(objects) do
                local o_hitbox = obj:get_hitbox()
                local near_hit, far_hit = rect_collide_with_rect(hit_box, o_hitbox), point_collide_with_rect(weapon_pos, o_hitbox)
                if near_hit or far_hit then
                  melee = true
                  anim:play((is_knife or far_hit) and 8 or 9, 1, true)
                  cooldowns.melee = 30
                  local force, dmg = rand(1.5, 1.7), is_knife and 9.5 or 2
                  obj:impact(owner, v2(face_left and -force or force, rand(-.6, -.2)), is_knife and 2 or 1, is_nife and 5 or 1.5, is_knife and 9.5 or 3, 16, physics_constants.air_speed_limit)
                  break
                end
              end
            end
          end
          if not melee and magazine > 0 and not cooldowns.weapon and not cooldowns.reload then
            cooldowns.weapon = shoot(weapon_pos, aim, dir_to_trans[aim][5], weapon, owner)
            magazine -= 1
            if magazine <= 0 then
              cooldowns.reload = weapon.reload_time
            end
          end
        end
      end
      if not forced_anim then
        local s = 1
        if in_air < 15 then
          s = abs(spd.x) > .1 and 7 or (aim == "n" and 2 or aim == "s" and 3 or 1)
        else
          s = (spd.y < -.7 or head_free_for < 5) and 1
              or spd.y < -.45 and 5
              or spd.y > .45 and 6
              or 4
        end
        anim:play(s)
      end
      return acc
    end,
    function(_ENV)
      -- pprint(anim.cur, pos.x + 5, pos.y - 5, 11, 0, true)
      if not (weapon.id == 2 and cooldowns.weapon) then
        local ww_pos, _, w_idx_mod, flip_x, flip_y = get_weapon_pos(_ENV)
        sprites[15 + (4 * (weapon.id - 1)) + w_idx_mod]:draw(ww_pos, flip_x, flip_y)
      end
      pal(11, color1)
      pal(5, color2)
      pal(15, hp <= 1 and 2 or hp <= qhp and 8 or 15)
    end,
    nil,
    function(_ENV, dmg_owner, force, dmg_type)
      blood_effect(pos, 20, force, 2, 5, .25)
      players[owner].soldier = nil
      if dmg_owner == owner or dmg_owner == 0 then
        players[owner].score -= 1
      elseif dmg_owner ~= 0 then
        players[dmg_owner].score += 1
      end
    end
  )

  soldier.get_weapon_pos = function(_ENV)
    local w_idx_mod, flip_x, flip_y = unpack(dir_to_trans[aim])
    local w_pos = sprites[anim:get_frame()]:get_point(2, pos, face_left)
    if (face_left and (aim == "n" or aim == "s")) flip_x = not flip_x
    return w_pos, sprites[15 + 4 * (weapon.id - 1) + w_idx_mod]:get_point(2, w_pos, flip_x, flip_y), w_idx_mod, flip_x, flip_y
  end

  soldier.owner = owner
  soldier.joy = joy
  soldier.color1 = color1
  soldier.color2 = color2
  soldier.aim = "e"
  soldier.magazine = 10
  soldier.head_free_for = 0
  soldier.god = true
  soldier.weapon = weapons[1]
  soldier.cooldowns.god = 180

  return soldier
end

function new_player(p_id, p_color1, p_color2, p_hud_points, p_face_left)
  return setmetatable(
    {
      id = p_id,
      color1 = p_color1,
      color2 = p_color2,
      hud_points = p_hud_points,
      face_left = p_face_left,
      joy = new_joystick(p_id - 1),
      score = 0,
      soldier = nil,
      connected = false,
      spawning = 0,
      msg = "join 🅾️/❎",
      update = function(_ENV)
        joy:update()
        if not connected and (joy.o.pressed or joy.x.pressed) then
          connected = true
        end
        if connected and game_state == "game" and not soldier and spawning == 0 then
          spawning, msg = 3, "spawn in 3"
          local spot = v2()
          cooldowns["spawn-soldier" .. id] = {
            timer = 59,
            sec = 3,
            trigger = function(self)
              self.sec -= 1
              msg = "spawn in " .. self.sec
              if self.sec == 0 then
                spot = world:get_safe_spot(3)
                spawn_effect(spot, "circle", color1, color2)
                cooldowns["soldier-is-spawning" .. id] = {
                  timer = 50,
                  trigger = function()
                    spawning = 0
                    soldier = new_soldier(spot, id, joy, color1, color2)
                    world:add_object(soldier)
                  end
                }
              end
              self.timer = self.sec > 0 and 59 or 0
            end
          }
        end
      end,
      draw = function(_ENV)
        if not connected or spawning > 0 then
          pprint(msg, hud_points[6].x, hud_points[6].y, color1, color2, face_left and "r" or "l")
          return
        end
        palt(0, false)
        palt(14, true)
        if soldier then
          draw_hp_bar(hud_points[2], soldier.hp, face_left)
          draw_ammo_bar(hud_points[3], face_left, soldier.magazine, soldier.weapon.magazine, soldier.cooldowns.reload, soldier.weapon.reload_time)
          round_box(hud_points[4] - v2(6, 3), v2(12, 7), 2)
          pal(11, 11)
          pal(3, 3)
          sprites[48 + soldier.weapon.id]:draw(hud_points[4] + (face_left and v2() or v2(-1, 0)), face_left)
          pprint(score, hud_points[5].x, hud_points[5].y, color1, color2, face_left and "r" or "l")
          if soldier.hp < 2 then
            pal(15, 8)
          end
          if soldier.hp < 1 then
            pal(15, 2)
          end
        end
        pal(11, color1)
        pal(3, color2)
        sprites[48]:draw(hud_points[1], face_left)
        palt()
        pal()
      end
    }, { __index = _ENV }
  )
end

function draw_hp_bar(pos, hp, facing_left)
  local x, y = pos.x, pos.y
  local x2 = facing_left and x - 9 or x + 9
  rectfill(facing_left and x - 9 or x, y, facing_left and x or x + 9, y + 3, 8)
  if (hp > 0) rectfill(facing_left and x - hp + 1 or x, y, facing_left and x or max(x + hp - 1, x), y + 3, 10)
  pset(x2, y, 0)
  pset(x2, y + 3, 0)
  pset(x, y, 0)
  pset(x, y + 3, 0)
end

function draw_ammo_bar(pos, facing_left, magazine, max_magazine, reload_cd, max_reload_cd)
  local x, y = pos.x, pos.y
  local w = 8
  local start_x = facing_left and x - w + 1 or x
  local end_x = facing_left and x or x + w - 1
  reload_cd = reload_cd or 0
  line(start_x, y, end_x, y, 5)
  if magazine > 0 then
    local len = min(flr((magazine / max_magazine) * 8) + 1, 8)
    line(facing_left and x - len + 1 or x, y, facing_left and x or x + len - 1, y, 7)
  elseif reload_cd < max_reload_cd then
    local len = 8 - min(flr((reload_cd / max_reload_cd) * 8) + 1, 8)
    line(facing_left and x - len or x, y, facing_left and x or x + len, y, 12)
  end
end

function gen_map(density, color1, color2, left_closed, right_closed, top_closed, bottom_closed)
  local map, tmp = {}, {}
  for x = 0, 131 do
    map[x], tmp[x] = {}, {}
    for y = 0, 115 do
      map[x][y] = ((x < 2 and left_closed or x > 129 and right_closed or y < 2 and top_closed or y > 112 and bottom_closed or rnd() < density) and 1 or 0)
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
    local base = 0x8000 + (y + 8) * 64
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
          col[p + 1] = rnd() < ch and color2 or color1
        end
      end
      poke(base + (x >> 1), (col[2] << 4) | col[1])
    end
  end
end

function init_spawners(config)
  for name, spawner in pairs(config) do
    cooldowns[name .. "_spawner"] = {
      timer = randint(180, 1200),
      trigger = function(self)
        self.timer = randint(220, spawner.max_spawn_time)
        if #world:get_objects(nil, 0, spawner.object_type) < spawner.max_objects then
          local spot = world:get_safe_spot(5)
          spawn_effect(spot, spawner.object_type == 6 and "circle" or "square", spawner.color1, spawner.color2)
          cooldowns[name .. "_is_spawning"] = {
            timer = 50,
            trigger = function()
              world:add_object(_g["new_" .. name](spot))
            end
          }
        end
      end
    }
  end
end
