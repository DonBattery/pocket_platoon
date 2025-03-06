pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- random numbers
function rand(l, h) return rnd(abs(h - l)) + min(l, h) end
function randint(l, h) return flr(rnd(abs(h + 1 - l))) + min(l, h) end

-- text functions
function pixlen(s) return print(s, 0, 128) end

function pprint(s, x, y, c1, c2, indent)
  x = x - (indent == "right" and pixlen(s) or (indent == "center" and flr(pixlen(s) / 2) or 0))
  print(s, x, y + 1, c2)
  print(s, x, y, c1)
end

function debug(infos, pos)
  for i, info in ipairs(infos) do
    pprint(info[1] .. " : " .. tostr(info[2]), pos.x, pos.y + ((i - 1) * 7), 7, 5)
  end
end

-- data parsers
function parse_string_data(data, parser)
  local result = {}
  for part in all(split(data, "|")) do
    add(result, parser(part))
  end
  return result
end

function sprite_parser(data)
  local nums = {}
  for part in all(split(data, ",")) do
    add(nums, tonum(part))
  end
  local sprite = {
    spos = v2(nums[1], nums[2]),
    size = v2(nums[3], nums[4]),
    points = {},
    flipped = {}
  }
  function sprite:get_point(index, pos, flip_x, flip_y)
    local base, base_flip = self.points[1], self.flipped[1]
    local origin = v2(pos.x - (flip_x and base_flip.x or base.x), pos.y - (flip_y and base_flip.y or base.y))
    if index == 1 then return origin end
    local pt, pt_flip = self.points[index], self.flipped[index]
    return v2(origin.x + (flip_x and pt_flip.x or pt.x), origin.y + (flip_y and pt_flip.y or pt.y))
  end
  function sprite:draw(pos, flip_x, flip_y)
    local origin = self:get_point(1, pos, flip_x, flip_y)
    sspr(self.spos.x, self.spos.y, self.size.x, self.size.y, origin.x, origin.y, self.size.x, self.size.y, flip_x, flip_y)
  end
  for i = 5, #nums, 2 do
    local pt = v2(nums[i], nums[i + 1])
    add(sprite.points, pt)
    add(sprite.flipped, (sprite.size - v2(1, 1)) - pt)
  end
  return sprite
end

function weapon_parser(data)
  local parts = split(data, ",")
  local weapon = {
    min_dmg = tonum(parts[1]),
    max_dmg = tonum(parts[2]),
    magazine = tonum(parts[3]),
    reload_time = tonum(parts[4]),
    burst = tonum(parts[5]),
    max_life = tonum(parts[6]),
    max_w_cd = tonum(parts[7]),
    kind = tonum(parts[8]),
    sizes = {},
    colors = {},
    accuracy = tonum(parts[11]),
    min_force = tonum(parts[12]),
    max_force = tonum(parts[13]),
    mass = tonum(parts[14]),
    v_modifier = tonum(parts[15])
  }
  for token in all(split(parts[9], "-")) do
    add(weapon.sizes, tonum(token))
  end
  for token in all(split(parts[10], "-")) do
    add(weapon.colors, tonum(token))
  end
  return weapon
end

-- ui box
function round_box(pos, size, col)
  rectfill(pos.x, pos.y + 1, pos.x + size.x - 1, pos.y + size.y - 2, col)
  rectfill(pos.x + 1, pos.y, pos.x + size.x - 2, pos.y + size.y - 1, col)
end

-- 2d vector
_v2 = {}
_v2.__index = _v2
function _v2:new(x, y) return setmetatable({ x = x or 0, y = y or 0 }, self) end
function v2(x, y) return _v2:new(x, y) end
function _v2:__add(o) return _v2:new(self.x + o.x, self.y + o.y) end
function _v2:__sub(o) return _v2:new(self.x - o.x, self.y - o.y) end
function _v2:__mul(s) return _v2:new(self.x * s, self.y * s) end
function _v2:__div(s) return _v2:new(self.x / s, self.y / s) end
function _v2:__len() return sqrt(self.x ^ 2 + self.y ^ 2) end
function _v2:eq(o) return self.x == o.x and self.y == o.y end
function _v2:norm() local m = #self return m > 0 and self / m or v2() end
function _v2:copy() return _v2:new(self.x, self.y) end
function _v2:rand(lx, hx, ly, hy) return _v2:new(rand(lx, hx), rand(ly, hy)) end
function _v2:randint(lx, hx, ly, hy) return _v2:new(randint(lx, hx), randint(ly, hy)) end
function _v2:floor() return _v2:new(flr(self.x), flr(self.y)) end
function _v2:ceil() return _v2:new(ceil(self.x), ceil(self.y)) end
function _v2:dist(o) return sqrt(self:sqrdist(o)) end
function _v2:sqrdist(o) return (o.x - self.x) ^ 2 + (o.y - self.y) ^ 2 end
function _v2:limit(limit)
  self.x = mid(-limit[1], self.x, limit[1])
  self.y = mid(limit[2], self.y, limit[3])
end
function _v2:rot(a) local c, s = cos(a), sin(a) return _v2:new(self.x * c - self.y * s, self.x * s + self.y * c) end

-- collision detection
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

-- find points between two coords (including them) with bresenham's line algorithm
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

function occupied_by(pos)
  if (pos.y - 8 > 111) return 16
  return sget(pos.x, pos.y - 8)
end

function free_rect(pos, size)
  for x = pos.x, pos.x + size.x - 1 do
    for y = pos.y, pos.y + size.y - 1 do
      if (y - 8 > 111 or sget(x, y - 8) ~= 1) return false
    end
  end
  return true
end

-- smart button and joystick
function new_button(pid, bid)
  return {
    pid = pid,
    bid = bid,
    update = function(self)
      local press = btn(self.bid, self.pid)
      self.isdown, self.pressed, self.released, self.hold = press, press and not self.prev, not press and self.prev, press and self.prev
      self.prev = press
      return press
    end
  }
end

function new_joystick(pid)
  return {
    left = new_button(pid, 0),
    right = new_button(pid, 1),
    up = new_button(pid, 2),
    down = new_button(pid, 3),
    o = new_button(pid, 4),
    x = new_button(pid, 5),
    dir = "",
    update = function(self)
      local left, right, up, down = self.left:update(), self.right:update(), self.up:update(), self.down:update()
      self.x:update()
      self.o:update()
      self.dir = ((up and not down and "n") or (down and not up and "s") or "") .. ((left and not right and "w") or (right and not left and "e") or "")
    end
  }
end

-- timer and scheduler
function new_timer(interval_frames, occures, onoccure, onend, occureoninit)
  local occured = 0
  if occureoninit and onoccure then
    occured = 1
    onoccure()
  end
  return {
    interval_frames = interval_frames,
    occures = occures,
    onoccure = onoccure,
    onend = onend,
    elapsed_frames = 0,
    occured = occured,
    update = function(self)
      self.elapsed_frames += 1
      if self.elapsed_frames >= self.interval_frames then
        self.elapsed_frames = 0
        self.occured += 1
        if self.onoccure then self.onoccure() end
        if self.occures > 0 and self.occured >= self.occures then
          if self.onend then self.onend() end
          return true
        end
      end
    end
  }
end

scheduler = {
  timers = {},
  update = function(self)
    for name, timer in pairs(self.timers) do
      if (timer:update()) self.timers[name] = nil
    end
  end,
  add = function(self, name, interval, occures, onoccure, onend, force, occureoninit)
    if not force and self.timers[name] then return end
    self.timers[name] = new_timer(interval, occures, onoccure, onend, occureoninit)
  end
}

-- animation and animator
function new_animation(frames, dur)
  return {
    frames = frames,
    len = #frames,
    dur = dur or 5,
    cur = 1,
    timer = 0,
    update = function(self)
      if self.len > 1 then
        self.timer = (self.timer + 1) % self.dur
        if (self.timer == 0) self.cur = (self.cur % self.len) + 1
      end
    end,
    get_frame = function(self)
      return self.frames[self.cur]
    end
  }
end

function new_animator(animations)
  return {
    cur = "",
    animations = animations,
    times = 0,
    played = 0,
    force = false,
    after = nil,
    runs = false,
    update = function(self)
      if not self.runs then return end
      local anim = self.animations[self.cur]
      anim:update()
      if anim.timer == 0 and anim.cur == 1 then
        self.played += 1
        self.force = false
        if self.times > 0 and self.played >= self.times then
          self.runs = false
          if self.after then self.after() end
        end
      end
    end,
    play = function(self, name, times, force, after)
      if (self.cur == name) or (self.force and not force) then return end
      self.cur, self.times, self.force, self.after, self.played, self.runs = name, times or 0, force == true, after, 0, true
    end,
    get_frame = function(self)
      return self.animations[self.cur]:get_frame()
    end
  }
end

-- particle system

-- particle_px = 1
-- particle_circ = 2
-- particle_circfill = 3
-- particle_line = 4
-- particle_knife = 5
-- particle_rocket = 6

function new_particle_system()
  return {
    particles = {},
    update = function(self)
      for particle in all(self.particles) do
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
    end,
    draw = function(self)
      for particle in all(self.particles) do
        local x, y, t = particle.pos.x, particle.pos.y, particle.life / particle.max_life
        local size, color = particle.sizes[min(flr(t * particle.number_of_sizes) + 1, particle.number_of_sizes)], particle.colors[min(flr(t * particle.number_of_colors) + 1, particle.number_of_colors)]
        if particle.kind == 1 then
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
  }
end

function update_bullet(bullet, next_pos)
  local points, weapon, spd, objects, hit_obj, hit_ground = points_between(bullet.pos, next_pos), bullet.weapon, bullet.spd, world:get_near_objects(bullet, 64)

  if weapon == 6 and rnd() < .3 then
    smoke(points[1], randint(1, 3))
  end

  for i = 1, #points do
    local p = points[i]

    for o in all(objects) do
      if point_collide_with_rect(p, o:get_hitbox()) then
        if bullet.life > 10 or o.owner ~= bullet.owner then
          o:bullet_hit(bullet)
          hit_obj = true
          break
        end
      end
    end

    local c = occupied_by(p)
    if not hit_obj and c != 1 then
      if c == 16 and (p.x < 0 or p.x > 127 or p.y < 8) then return true end
      hit_ground = true
    end

    if hit_obj or hit_ground then
      -- w_knife
      if weapon == 2 then
        if hit_ground then
          sset(p.x, p.y - 8, 7)
          if i > 1 then
            sset(points[i - 1].x, points[i - 1].y - 8, 4)
          end
        end
        -- w_flamethrower
      elseif weapon == 7 then
        if hit_ground then
          sset(p.x, p.y - 8, 0)
        end
        smoke(p, 2)
        -- w_rocket_launcher
      elseif weapon == 6 then
        explosion(bullet.owner, p, spd, 6)
        -- w_pistol
      elseif weapon == 1 then
        flash_struct(p, spd, 1, randint(1, 3))
        -- w_uzi
      elseif weapon == 3 then
        flash_struct(p, spd, randint(1, 2), randint(2, 3))
        -- w_shotgun
      elseif weapon == 4 then
        flash_struct(p, spd, randint(1, 3), randint(2, 3))
      else
        -- w_rifle
        explosion(bullet.owner, p, spd, 4)
      end
      return true
    end
  end
  return false
end

function new_particle(fg_chance, max_life, kind, pos, spd, acc, sizes, colors, weapon, owner, on_update)
  add(
    rnd() < fg_chance and fg_particles.particles or bg_particles.particles, {
      max_life = max_life,
      life = 0,
      kind = kind,
      pos = pos,
      spd = spd,
      acc = acc,
      number_of_sizes = #sizes,
      sizes = sizes,
      number_of_colors = #colors,
      colors = colors,
      weapon = weapon,
      owner = owner,
      on_update = on_update
    }
  )
end

-- destructors
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

function destruct(pos, dir, size)
  dir = dir:norm() * 0.1
  local destructor = destructors[size]
  if (size == 1 and rnd() > .2) destructor = rnd(edge_destructors)
  for point in all(destructor) do
    local color_x, color_y = pos.x + point[1], pos.y + point[2] - 8
    if point_collide_with_rect(v2(color_x, color_y), map_rect) then
      local color = sget(color_x, color_y)
      if color ~= 1 then
        local chance = 1
        if color == 6 then chance = .3 end
        if color == 5 then chance = .1 end
        if rnd() <= chance then
          sset(color_x, color_y, 1)
          local c_pos = v2(color_x, color_y + 8)
          new_particle(.5, randint(25, 55), 1, c_pos, (c_pos - pos):norm() / 3 + _v2:rand(0, 0, -.3, -.1) + dir, v2(0, .01), { 1 }, { color })
        else
          sset(color_x, color_y, 0)
        end
      end
    end
  end
end

-- effects
function smoke(pos, burst)
  for i = 1, burst or 1 do
    new_particle(.2, randint(25, 35), 2, pos, _v2:rand(-.1, .1, -.3, -.1), v2(), { 0, 1 }, { 7, 6, 5 })
  end
end

function spawn_effect(pos, col)
  new_particle(1, 60, 2, pos, v2(), v2(), { 6, 5, 4, 3, 2, 1, 0 }, { 7, col })
  for i = 1, 13 do
    local d = pos + _v2:rand(-8, 8, -8, 8)
    local dd = ((d - pos):norm() * -1) / 8
    new_particle(.75, randint(35, 65), 4, d, dd, v2(), { 0, 1, 1, 2 }, { 7, col })
  end
end

function blood(pos, dir, size)
  local d = dir:norm()
  for i = 1, size do
    new_particle(
      .8, randint(45, 75), 1, pos + d * rand(0.5, 1.5), d:rot(rand(-.2, .2)) / 2, v2(0, .02), { 1 }, { rnd() < .2 and 2 or 8 }, 0, 0, function(blood, next_pos, outside)
        if outside then return true end
        if (occupied_by(next_pos) != 1 and rnd() > .6) then
          sset(next_pos.x, next_pos.y - 8, blood.colors[1])
          return true
        end
      end
    )
  end
end

function explosion(owner, pos, dir, size)
  destruct(pos, dir, size)

  local half, blobs, smokes = size / 2, size * 2, ceil(size * 2.5)

  for i = 1, smokes do
    smoke(pos + _v2:rand(-size, size, -size, size))
  end

  for i = 1, blobs do
    local d = _v2:rand(-half, half, -half, half)
    new_particle(.9, randint(20, 25), 3, pos + d, d * .07, v2(0, -.01), { 0, 1, 2, 2, 1 }, { 7, 10, 9, 8 })
  end

  local objects = world:get_near_objects({ pos = pos }, 128)

  for object in all(objects) do
    object:knock(owner, (object.pos - pos):norm() * (size / 4), size / 2, size * 2, 8, physics_constants.exploded_speed_limit)
  end
end

function heal_effect(pos, burst)
  for i = 1, burst do
    new_particle(.7, randint(45, 75), 2, pos + _v2:rand(-2, 2, -2, 2), _v2:rand(-.07, .07, .15, .07), _v2:rand(-.005, 0.005, -.003, -.01), { 0, 1, 1, 1 }, { 7, 11, 11, 3 })
  end
end

function flash_struct(pos, dir, size, destruct_size)
  local sizes = {
    { 0, 1, 2, 2 },
    { 1, 2, 3, 3 },
    { 2, 3, 4, 4 }
  }
  destruct(pos, dir, destruct_size)
  new_particle(.6, randint(8, 16), 3, pos, v2(), v2(), sizes[size], { 7, 7, 10 })
end

function jetpack_effect(pos)
  new_particle(.3, randint(5, 13), randint(2, 3), pos, _v2:rand(-.1, .1, .15, .07), _v2:rand(-.03, 0.03, .05, -.01), { 1, 0 }, { 9, 10, 7, 6, 5 })
end

-- game world and game objects
function new_world()
  return {
    objects = {},
    add_object = function(self, object)
      add(self.objects, object)
    end,
    get_near_objects = function(self, obj, sqrdist, type)
      local near_objects = {}
      for object in all(self.objects) do
        if not (type and object.type ~= type) and object ~= obj and object.pos:sqrdist(obj.pos) < sqrdist then
          add(near_objects, object)
        end
      end
      return near_objects
    end,
    -- todo: make this function more robust, now it can stuck in an infinite loop
    get_safe_spot = function(self, size)
      while true do
        local pos = _v2:randint(size + 1, 127 - size, 9 + size, 111 - size)
        local objects = self:get_near_objects({ pos = pos }, size * size)
        if (#objects == 0 and free_rect(pos - v2(size, size), v2(size * 2 + 1, size * 2 + 1))) return pos
      end
    end,
    update = function(self)
      for i = #self.objects, 1, -1 do
        local object = self.objects[i]
        if object:update() then
          deli(self.objects, i)
        end
      end
    end,
    draw = function(self)
      for object in all(self.objects) do
        object:draw()
        -- debug objects
        -- local hb = object:get_hitbox()
        -- rect(hb.pos.x, hb.pos.y, hb.pos.x + hb.size.x - 1, hb.pos.y + hb.size.y - 1, 8)
      end
    end
  }
end

function shoot(pos, aim, w_index, owner)
  local weapon, dir, mod = weapons[w_index], dir_to_trans[aim][5]
  for i = 1, weapon.burst do
    local spd = (dir * rand(weapon.min_force, weapon.max_force)):rot(rand(-weapon.accuracy, weapon.accuracy))
    if aim == "w" or aim == "e" then
      spd.y -= weapon.v_modifier
    end
    new_particle(0, weapon.max_life, weapon.kind, pos, spd, v2(0, weapon.mass), weapon.sizes, weapon.colors, w_index, owner, update_bullet)
  end
  return weapon.max_w_cd
end

-- game object
game_object = {}
game_object.__index = game_object

function game_object:new(type, pos, offset, size, color, climber)
  return setmetatable(
    {
      -- basic props
      type = type,
      pos = pos,
      offset = offset,
      size = size,
      color = color,
      climber = climber,

      -- physics props
      gravity = physics_constants.air_gravity,
      friction = physics_constants.air_friction,
      speed_limit = physics_constants.air_speed_limit,
      force_move_cd = 0,

      radius = size.x > size.y and ceil(size.x / 2) or ceil(size.y / 2),
      origin = pos + offset,
      real_size = size - v2(1, 1),
      real_pos = pos:copy(),
      spd = v2(),
      in_air = 0,
      on_ground = 0,
      grounded = false,
      face_left = false,
      remove = false
    }, self
  )
end

function game_object:get_hitbox()
  return { pos = self.origin, size = self.size }
end

function game_object:update()
  if self.remove then return true end

  if free_rect(v2(self.origin.x, self.origin.y + self.size.y), v2(self.size.x, 1)) then
    self.in_air += 1
    self.on_ground, self.grounded = 0, false
  else
    self.on_ground += 1
    self.in_air, self.grounded = 0, true
  end

  self.force_move_cd = max(0, self.force_move_cd - 1)

  if self.force_move_cd == 0 then
    if self.grounded then
      self.gravity, self.friction, self.speed_limit = physics_constants.ground_gravity, physics_constants.ground_friction, physics_constants.ground_speed_limit
    else
      self.gravity, self.friction, self.speed_limit = physics_constants.air_gravity, physics_constants.air_friction, physics_constants.air_speed_limit
    end
  end

  self.spd += self:control()

  self.spd:limit(self.speed_limit)

  self.spd *= self.friction

  if (abs(self.spd.x) < 0.005) self.spd.x = 0
  if (abs(self.spd.y) < 0.005) self.spd.y = 0
  local next_pos = self.real_pos + self.spd
  local points = points_between(self.real_pos, next_pos)
  local len = #points
  if len > 1 then
    for i = 2, len do
      local prev_point = points[i - 1]
      local can, block, res = self:step_one(prev_point, points[i] - prev_point)
      if not can then
        self.spd.x *= (not self.climber and block.x == 0) and -.8 or block.x
        self.spd.y *= (not self.climber and block.y == 0) and -.8 or block.y
        next_pos = res and res + v2(.5, .5) or prev_point + v2(.5, .5)
        break
      end
    end
  end

  self.real_pos, self.pos = next_pos, next_pos:floor()
  self.origin = self.pos + self.offset
end

function game_object:step_one(pos, step)
  if not self:legal_step(pos, step) then
    if step.x ~= 0 then
      if step.y ~= 0 then
        if self:legal_step(pos, v2(step.x, 0)) then
          return false, v2(.75, 0), pos + v2(step.x, 0)
        elseif self:legal_step(pos, v2(0, step.y)) then
          return false, v2(0, .75), pos + v2(0, step.y)
        end
      else
        if self:legal_step(pos, v2(step.x, -1)) then
          return false, v2(.75, 1), pos + v2(step.x, -1)
        elseif self.climber and self:legal_step(pos, v2(step.x, -2)) then
          return false, v2(.3, .75), pos + v2(step.x, -2)
        elseif self:legal_step(pos, v2(step.x, 1)) then
          return false, v2(.75, .75), pos + v2(step.x, 1)
        end
      end
    elseif step.y < 0 then
      if (self:legal_step(pos, v2(self.face_left and -1 or 1, -1))) return false, v2(.5, .75), pos + v2(self.face_left and -1 or 1, -1)
    else
      return false, v2(1, 0)
    end
    return false, v2()
  end
  return true
end

function game_object:legal_step(pos, step)
  if (step.x ~= 0 and not free_rect(pos + self.offset + (step.x < 0 and v2(-1, step.y) or v2(self.size.x, step.y)), v2(1, self.size.y))) return false
  if (step.y ~= 0 and not free_rect(pos + self.offset + (step.y < 0 and v2(step.x, -1) or v2(step.x, self.size.y)), v2(self.size.x, abs(step.y)))) return false
  return true
end

function game_object:knock(owner, force, min_dmg, max_dmg, cd, limit)
  if self.remove then return end
  self.spd += force
  self.force_move_cd, self.speed_limit, self.friction = cd, limit, 1
  self:take_dmg(owner, min_dmg, max_dmg)
end

function new_box(kind, pos)
  local box = game_object:new(2, pos, v2(-2, -2), v2(5, 5), 0, false)
  box.kind, box.hp = kind, 5
  box.control = function(self)
    local hitbox, near_soldiers = self:get_hitbox(), world:get_near_objects(self, 64, 1)
    for soldier in all(near_soldiers) do
      if not self.remove and rect_collide_with_rect(hitbox, soldier:get_hitbox()) then
        if self.kind == 1 and soldier.hp < 10 then
          heal_effect(soldier.pos, ceil(10 - soldier.hp))
          soldier.hp, self.remove = 10, true
        elseif self.kind == 2 then
          local prev_weapon = soldier.weapon
          while soldier.weapon == prev_weapon do
            soldier.weapon = randint(2, 7)
          end
          soldier.weapon_cd, soldier.reload_cd, soldier.magazine, self.remove = 0, 0, weapons[soldier.weapon].magazine, true
        end
      end
    end
    return v2(0, self.gravity)
  end
  box.draw = function(self) sprites[self.kind + 43]:draw(self.pos) end
  box.take_dmg = function(self, owner, min_dmg, max_dmg)
    -- if self.remove then return end
    self.hp -= rand(min_dmg, max_dmg)
    if self.hp <= 0 then
      self.remove = true
      explosion(owner, self.pos, _v2:rand(-.3, .3, -.7, -.3), randint(3, 5))
    end
  end
  box.bullet_hit = function(self, bullet)
    local w = weapons[bullet.weapon]
    self:take_dmg(bullet.owner, w.min_dmg, w.max_dmg)
  end
  return box
end

function new_soldier(spot, owner, joy, color1, color2)
  soldier = game_object:new(1, spot, v2(-1, -3), v2(3, 6), color1, true)
  soldier.owner = owner
  soldier.joy = joy
  soldier.color2 = color2
  soldier.aim = "e"
  soldier.aim_cd = 0
  soldier.melee_cd = 0
  soldier.weapon_cd = 0
  soldier.reload_cd = 0
  soldier.god_cd = 180
  soldier.magazine = 10
  soldier.head_free_for = 0
  soldier.hp = 10
  soldier.god = true
  soldier.weapon = 1
  soldier.anim = new_animator({
    stand = new_animation({ 1 }),
    stand_up = new_animation({ 3 }),
    stand_down = new_animation({ 2 }),
    fly = new_animation({ 8 }),
    fly_up = new_animation({ 10 }),
    fly_down = new_animation({ 12 }),
    run = new_animation({ 1, 4, 5, 11 }, 6),
    melee1 = new_animation({ 1, 13, 14, 14 }),
    melee2 = new_animation({ 1, 5, 6, 6 }),
    roll_forward = new_animation({ 1, 10, 10, 8, 12, 9, 7, 15 }),
    roll_backward = new_animation({ 1, 15, 15, 7, 9, 12, 8, 10 })
  })

  soldier.anim:play("stand")

  soldier.take_dmg = function(self, owner, min_dmg, max_dmg)
    self.hp -= rand(min_dmg, max_dmg)
    if self.hp <= 0 then
      blood(self.pos, v2(0, -.3), 20)
      players[self.owner].soldier = nil
      if owner == self.owner then
        players[owner].score -= 1
      else
        players[owner].score += 1
      end
      self.remove = true
    end
  end

  soldier.bullet_hit = function(self, bullet)
    blood(bullet.pos, bullet.spd, 5)
    local w = weapons[bullet.weapon]
    self:take_dmg(bullet.owner, w.min_dmg, w.max_dmg)
  end

  soldier.get_hitbox = function(self)
    local sprite = sprites[self.anim:get_frame()]
    local point_a, point_b = sprite:get_point(3, self.pos, self.face_left), sprite:get_point(4, self.pos, self.face_left)
    return {
      pos = v2(min(point_a.x, point_b.x), min(point_a.y, point_b.y)),
      size = v2(abs(point_a.x - point_b.x) + 1, abs(point_a.y - point_b.y) + 1)
    }
  end

  soldier.get_weapon_pos = function(self)
    local w_idx_mod, flip_x, flip_y = unpack(dir_to_trans[self.aim])
    local w_pos = sprites[self.anim:get_frame()]:get_point(2, self.pos, self.face_left)
    if (self.face_left and (self.aim == "n" or self.aim == "s")) flip_x = not flip_x
    return w_pos, sprites[15 + 4 * (self.weapon - 1) + w_idx_mod]:get_point(2, w_pos, flip_x, flip_y), w_idx_mod, flip_x, flip_y
  end

  soldier.control = function(self)
    self.anim:update()

    -- decrease cooldowns
    local prev_reload = self.reload_cd
    self.reload_cd = max(0, self.reload_cd - 1)
    self.aim_cd = max(0, self.aim_cd - 1)
    self.melee_cd = max(0, self.melee_cd - 1)
    self.weapon_cd = max(0, self.weapon_cd - 1)
    self.god_cd = max(0, self.god_cd - 1)

    if self.reload_cd == 0 and prev_reload == 1 then
      self.magazine = weapons[self.weapon].magazine
    end

    local joy, h_dir, forced_anim, acc = self.joy, self.face_left and -1 or 1, self.anim.force, v2(0, self.gravity)
    local can_control = not (self.force_move_cd > 0 or forced_anim)

    -- jetpack or gravity
    local head_free = self:legal_step(self.pos, v2(0, -1)) or self:legal_step(self.pos, v2(h_dir, -1))

    if head_free then
      self.head_free_for += 1
    else
      self.head_free_for = 0
    end

    if can_control and joy.o.hold then
      jetpack_effect(self.pos + v2(-h_dir * 2, 1))
      -- acc.y = physics_constants.jetpack_force
      if head_free then
        acc.y = physics_constants.jetpack_force
      else
        acc.y = 0
      end
    end

    if can_control then
      -- check if horizontal movement is blocked
      side_blocked = not (self:legal_step(self.pos, v2(h_dir, 0)) or self:legal_step(self.pos, v2(h_dir, -1)) or self:legal_step(self.pos, v2(h_dir, 1)) or self:legal_step(self.pos, v2(h_dir, -2)))

      -- horizontal movement
      local move_acc = self.grounded and physics_constants.ground_acc or physics_constants.air_acc
      if joy.left.isdown then
        self.face_left, acc.x = true, (not side_blocked and -move_acc or 0)
      elseif joy.right.isdown then
        self.face_left, acc.x = false, (not side_blocked and move_acc or 0)
      end

      -- aim
      if self.aim_cd == 0 then
        if joy.dir != "" then
          self.aim = joy.dir
          self.aim_cd = 6
        end
      end

      -- hit
      if joy.x.isdown then
        local melee, _, weapon_pos = false, self:get_weapon_pos()
        if self.melee_cd == 0 then
          local objects = world:get_near_objects(self, 72)
          local len, is_knife = #objects, self.weapon == 2
          if len > 0 then
            local hit_box, i = self:get_hitbox(), 1
            while i <= len and not melee do
              local object = objects[i]
              local o_hitbox = object:get_hitbox()
              local near_hit, far_hit = rect_collide_with_rect(hit_box, o_hitbox), point_collide_with_rect(weapon_pos, o_hitbox)
              if near_hit or far_hit then
                melee = true
                self.anim:play("melee" .. ((is_knife or far_hit) and "1" or "2"), 1, true)
                self.melee_cd = 30
                local force, dmg = rand(1.5, 1.7), is_knife and 9.5 or 2
                object:knock(self.owner, v2(self.face_left and -force or force, rand(-.6, -.2)), dmg - .5, dmg + .5, 16, physics_constants.air_speed_limit)
                if object.type == 1 then
                  blood(object.pos, object.pos - self.pos, ceil(dmg))
                  object.anim:play("roll_" .. (((object.spd.x < 0) == object.face_left) and "forward" or "backward"), 1, true)
                else
                  smoke(object.pos, ceil(dmg))
                end
              end
              i += 1
            end
          end
        end

        if not melee and self.magazine > 0 and self.weapon_cd == 0 and self.reload_cd == 0 then
          self.weapon_cd = shoot(weapon_pos, self.aim, self.weapon, self.owner)
          self.magazine -= 1
          if self.magazine <= 0 then
            self.reload_cd = weapons[self.weapon].reload_time
          end
        end
      end
    end

    -- auto anim
    if not forced_anim then
      if self.in_air < 15 then
        if abs(self.spd.x) > .1 then
          self.anim:play("run")
        else
          local s = "stand"
          if self.aim == "n" then
            s = s .. "_up"
          elseif self.aim == "s" then
            s = s .. "_down"
          end
          self.anim:play(s)
        end
      else
        local spd, s = self.spd.y, "stand"
        if spd < -.7 or (self.head_free_for < 10) then
          s = "stand"
        elseif spd < -.3 then
          s = "fly_up"
        elseif spd > .3 then
          s = "fly_down"
        else
          s = "fly"
        end
        self.anim:play(s)
      end
    end

    return acc
  end

  soldier.draw = function(self)
    palt(0, false)
    palt(14, true)
    if not (self.weapon == 2 and self.weapon_cd > 0) then
      local ww_pos, _, w_idx_mod, flip_x, flip_y = self:get_weapon_pos()
      sprites[15 + (4 * (self.weapon - 1)) + w_idx_mod]:draw(ww_pos, flip_x, flip_y)
    end
    pal(11, self.color)
    pal(5, self.color2)
    if self.hp <= 2 then
      if rnd() < .025 then
        blood(self.pos + _v2:rand(-1, 1, -2, 1), v2(), 1)
      end
      pal(15, 8)
    end
    if self.hp <= 1 then
      pal(15, 2)
    end
    sprites[self.anim:get_frame()]:draw(self.pos, self.face_left, false)
    pal()
    palt()
  end

  return soldier
end

function new_player(id, color1, color2, hud_points, face_left)
  return {
    id = id,
    color1 = color1,
    color2 = color2,
    hud_points = hud_points,
    face_left = face_left,
    connected = false,
    joy = new_joystick(id - 1),
    score = 0,
    soldier = nil,
    connected = false,
    spawning = 0,
    msg = "join 🅾️/❎",
    update = function(self)
      local joy = self.joy
      joy:update()
      if not self.connected and (joy.o.pressed or joy.x.pressed) then
        self.connected = true
      end
      if self.connected and not self.soldier and self.spawning == 0 then
        self.spawning, self.msg = 3, "spawn in 3"
        local spot = v2()
        scheduler:add(
          "spawn-soldier" .. self.id, 60, 3,
          function()
            self.spawning -= 1
            self.msg = "spawn in " .. self.spawning
            if self.spawning == 1 then
              spot = world:get_safe_spot(3)
              spawn_effect(spot, self.color1)
            end
          end,
          function()
            self.soldier = new_soldier(spot, self.id, joy, self.color1, self.color2)
            world:add_object(self.soldier)
          end
        )
      end
    end,
    draw = function(self)
      if not self.connected or self.spawning > 0 then
        pprint(self.msg, self.hud_points[6].x, self.hud_points[6].y, self.color1, self.color2, self.face_left and "right" or "left")
        return
      end
      palt(0, false)
      palt(14, true)
      local s = self.soldier
      if s then
        draw_hp_bar(self.hud_points[2], s.hp, self.face_left)
        draw_ammo_bar(self.hud_points[3], self.face_left, s.magazine, weapons[s.weapon].magazine, s.reload_cd, weapons[s.weapon].reload_time)
        round_box(self.hud_points[4] - v2(6, 3), v2(12, 7), 2)
        pal(11, 11)
        pal(3, 3)
        sprites[47 + s.weapon]:draw(self.hud_points[4] + (self.face_left and v2() or v2(-1, 0)), self.face_left)
        pprint(self.score, self.hud_points[5].x, self.hud_points[5].y, self.color1, self.color2, self.face_left and "right" or "left")
        if s.hp < 2 then
          pal(15, 8)
        end
        if s.hp < 1 then
          pal(15, 2)
        end
      end
      pal(11, self.color1)
      pal(3, self.color2)
      sprites[47]:draw(self.hud_points[1], self.face_left)
      palt()
      pal()
    end
  }
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
  -- draw gray baseline
  line(start_x, y, end_x, y, 5)
  if magazine > 0 then
    local len = min(flr((magazine / max_magazine) * 8) + 1, 8)
    -- draw white ammo bar
    line(facing_left and x - len + 1 or x, y, facing_left and x or x + len - 1, y, 7)
  elseif reload_cd < max_reload_cd then
    -- braw blue reload bar - more blue as reload completes (when reload_cd approaches 0)
    local len = 8 - min(flr((reload_cd / max_reload_cd) * 8) + 1, 8)
    line(facing_left and x - len or x, y, facing_left and x or x + len, y, 12)
  end
end

-- map generator
function cellautomata(orig, dest)
  for x = 0, 127 do
    for y = 0, 111 do
      local n = 0
      for i = -2, 2 do
        for j = -2, 2 do
          local nx, ny = x + i, y + j
          if nx < 0 or nx > 127 or ny < 0 or ny > 111 then
            -- Count out-of-bounds as walls
            n += 1
          elseif not (i == 0 and j == 0) then
            -- Count in-bounds neighbors
            if orig[nx][ny] > 0 then
              n += 1
            end
          end
        end
      end
      -- Apply rules
      dest[x][y] = n > 12 and 1 or 0
    end
  end
end

function gen_map()
  local map, temp_map, colors = {}, {}, rnd({
    { 3, 11 },
    { 13, 12 },
    { 5, 6 },
    { 4, 9 }
  })

  -- Initialize the map with random noise
  for x = 0, 127 do
    map[x] = {}
    temp_map[x] = {}
    for y = 0, 111 do
      map[x][y] = flr(rnd(2))
      temp_map[x][y] = 0
    end
  end

  -- Apply cellular automata rules multiple times
  for i = 1, 4 do
    cellautomata(i % 2 == 1 and map or temp_map, i % 2 == 1 and temp_map or map)
  end

  -- Draw the final map to the sprite sheet
  for x = 0, 127 do
    for y = 0, 111 do
      if map[x][y] == 1 then
        sset(x, y, rnd(1) < .85 and colors[1] or colors[2])
      else
        sset(x, y, 1)
      end
    end
  end
end
