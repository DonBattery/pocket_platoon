pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- vector class
function v2(x, y)
  local v = {
    x = x or 0, y = y or 0,
    __add = function(a, b) return v2(a.x + b.x, a.y + b.y) end,
    __sub = function(a, b) return v2(a.x - b.x, a.y - b.y) end,
    __mul = function(a, s) return v2(a.x * s, a.y * s) end,
    __div = function(a, s) return v2(a.x / s, a.y / s) end,
    __len = function(a) return sqrt(a.x ^ 2 + a.y ^ 2) end,
    norm = function(a) local m = #a return m > 0 and a / m or v2() end,
    rot = function(a, r) return v2(a.x * cos(r) - a.y * sin(r), a.x * sin(r) + a.y * cos(r)) end,
    copy = function(a) return v2(a.x, a.y) end,
    eq = function(a, b) return a.x == b.x and a.y == b.y end,
    sqrdist = function(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end,
    dist = function(a, b) return sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end,
    floor = function(a) return v2(flr(a.x), flr(a.y)) end,
    ceil = function(a) return v2(ceil(a.x), ceil(a.y)) end,
    randint = function(a, lx, hx, ly, hy) return v2(randint(lx, hx), randint(ly, hy)) end,
    random = function(a, min, max) return v2(rand(min, max), 0):rot(rand(0, 2 * 3.14)) end,
    clamp = function(a, min, max)
      return v2(
        mid(min.x, a.x, max.x),
        mid(min.y, a.y, max.y)
      )
    end
  }
  setmetatable(v, v)
  return v
end

-- utils
function rand(l, h) return rnd(abs(h - l)) + min(l, h) end
function randint(l, h) return flr(rnd(abs(h + 1 - l))) + min(l, h) end

-- game controller classes
-- smart button
function smartbutt(pid, bid, ddlen, dcd)
  local sb = {
    pid = pid,
    bid = bid,
    ddlen = ddlen,
    dcd = dcd,
    press_frames = 0,
    release_frames = 0,
    isdown = false,
    pressed = false,
    double = false,
    cooldown = 0
  }

  function sb:update()
    local press = btn(self.bid, self.pid)
    self.pressed, self.double = false, false
    if press then
      self.press_frames += 1
      if not self.isdown then
        self.pressed = true
        if self.release_frames > 0 and self.release_frames <= self.ddlen and self.cooldown == 0 then
          self.double, self.cooldown = true, self.dcd
        end
      end
      self.release_frames = 0
    else
      self.release_frames += 1
      if self.isdown then self.press_frames = 0 end
    end
    self.cooldown = max(0, self.cooldown - 1)
    self.isdown = press
    return press
  end

  function sb:hold(frames)
    return self.isdown and self.press_frames >= (frames or 1)
  end

  return sb
end

-- joystick
function joystick(pid, ddlen, dcd)
  local function dir_btn(id) return smartbutt(pid, id, ddlen, dcd) end

  local joy = {
    left = dir_btn(0),
    right = dir_btn(1),
    up = dir_btn(2),
    down = dir_btn(3),
    o = dir_btn(4),
    x = dir_btn(5),
    dir = ""
  }

  function joy:update()
    local left, right, up, down = self.left:update(), self.right:update(), self.up:update(), self.down:update()
    self.o:update()
    self.x:update()
    self.dir = ((left and not right and "w") or (right and not left and "e") or "") .. ((up and not down and "n") or (down and not up and "s") or "")
  end

  return joy
end

function draw_flickering_line(value, x, y, face_left, color)
  local length = (value > 1) and value - 1 or 9
  if value > 1 or (flicker % 6) < 3 then
    line(x, y, x + (face_left and -length or length), y, color)
  end
end

-- find points between two coords (including them) with Bresenham's line algorithm
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

function occupiedby(pos)
  if (pos.x < 0 or pos.x > 127 or pos.y - 8 < 0 or pos.y - 8 > 111) return 16
  return sget(pos.x, pos.y - 8)
end

function free_rect(pos, size)
  for x = pos.x, pos.x + size.x - 1 do
    for y = pos.y, pos.y + size.y - 1 do
      if occupiedby(v2(x, y)) > 0 then
        return false
      end
    end
  end
  return true
end

function no_soldier_nearby(pos, dist)
  for p in all(players) do
    if p.soldier then
      if pos:dist(p.soldier.pos) < dist then
        return false
      end
    end
  end
  return true
end

function get_safe_spot(size)
  while true do
    local pos = v2():randint(size + 1, 126 - size, 9 + size, 103 - size)
    if (no_soldier_nearby(pos, 12) and free_rect(pos - v2(size, size), v2(size * 2 + 1, size * 2 + 1))) then
      return pos
    end
  end
end

physics_constants = {
  ground_gravity = 0.05,
  air_gravity = 0.07,
  jetpack_force = -0.1,
  ground_acc = 0.03,
  air_acc = 0.05,
  ground_friction = 0.93,
  air_friction = 0.95,
  max_ground_h_spd = .6,
  max_ground_up_spd = -.8,
  max_ground_down_spd = 1,
  max_air_h_spd = 1,
  max_air_up_spd = -1.2,
  max_air_down_spd = 1.8
}

function new_soldier(joy, color)
  local safe_pos = get_safe_spot(2)

  local s = {
    color = color,
    joy = joy,
    pos = safe_pos:copy(),
    real_pos = safe_pos:copy(),
    acc = v2(),
    spd = v2(),
    size = v2(5, 5),
    state = "standing",
    face_left = false,
    aim = "e",
    can_aim = true,
    grounded = false,
    sided = false,
    headed = false,
    in_air = 0,
    fuel = 10
  }

  function s:can_step(pos, step)
    local block, can, res = v2(0, 0)
    if step.x ~= 0 then
      if step.y ~= 0 then
        -- we are moving diagonally
        can = free_rect(v2(pos.x + step.x * 3, pos.y - 2 + step.y), v2(1, 5)) and free_rect(v2(pos.x - 2 + step.x, pos.y + step.y * 3), v2(5, 1))
        if not can then
          -- we are moving diagonally upwards
          if step.y < 0 then
            -- try to resolve vertically
            if free_rect(v2(pos.x - 2, pos.y - 3), v2(5, 1)) then
              res, block = pos + v2(0, -1), v2(.5, 1)
              -- try to resolve horizontally
            elseif free_rect(v2(pos.x + step.x * 3, pos.y - 2), v2(1, 5)) then
              res, block = pos + v2(step.x, 0), v2(1, .5)
            end
            -- we are moving diagonally downwards
          else
            -- try to resolve horizontally
            if free_rect(v2(pos.x + step.x * 3, pos.y - 2), v2(1, 5)) then
              res, block = pos + v2(step.x, 0), v2(1, 0)
              -- try to resolve vertically
            elseif free_rect(v2(pos.x - 2, pos.y + 3), v2(5, 1)) then
              res, block = pos + v2(0, 1), v2(0, 1)
            end
          end
        end
      else
        -- we are moving horizontally
        can = free_rect(v2(pos.x + step.x * 3, pos.y - 2), v2(1, 5))
        if not can then
          -- try to resolve diagonally upwards by 1 pixel
          if free_rect(v2(pos.x + step.x * 3, pos.y - 3), v2(1, 5)) and free_rect(v2(pos.x - 2 + step.x, pos.y - 3), v2(5, 1)) then
            res, block = pos + v2(step.x, -1), v2(.8, 0)
            -- try to resolve diagonally upwards by 2 pixel
          elseif free_rect(v2(pos.x + step.x * 3, pos.y - 4), v2(1, 5)) and free_rect(v2(pos.x - 2 + step.x, pos.y - 4), v2(5, 2)) then
            res, block = pos + v2(step.x, -2), v2(.4, 0)
            -- try to resolve diagonally downwards
          elseif free_rect(v2(pos.x + step.x * 3, pos.y - 1), v2(1, 5)) and free_rect(v2(pos.x - 2 + step.x, pos.y + 3), v2(5, 1)) then
            res, block = pos + v2(step.x, 1), v2(1, 1)
          end
        end
      end
    else
      -- we are moving vertically
      can = free_rect(v2(pos.x - 2, pos.y + step.y * 3), v2(5, 1))
      if not can then
        -- if we are moving upwards
        if step.y < 0 then
          local dir = self.face_left and -1 or 1
          -- try to resolve diagonally to the facing direction
          if free_rect(v2(pos.x - 2 + dir, pos.y - 3), v2(5, 1)) and free_rect(v2(pos.x + dir * 3, pos.y - 3), v2(1, 5)) then
            res, block = pos + v2(dir, -1), v2(1, 0.8)
          end
          -- there is no resolution for moving downwards
        else
          block = v2(1, 0)
        end
      end
    end

    return can, res, block
  end

  -- collide with the map
  function s:check_collision(pos1, pos2)
    local points = points_between(pos1, pos2)

    if (#points == 1) return pos2
    for i = 2, #points do
      local prev_point = points[i - 1]
      local can, res, block = self:can_step(prev_point, points[i] - prev_point)
      if not can then
        self.spd.x *= block.x
        self.spd.y *= block.y
        if res then
          return res + v2(.5, .5)
        else
          return prev_point + v2(.5, .5)
        end
      end
    end

    return pos2
  end

  function s:update()
    -- reset acceleration
    self.acc = v2()

    -- check if we are in the air
    if free_rect(v2(self.pos.x - 2, self.pos.y + 3), v2(5, 1)) then
      self.in_air += 1
      if self.in_air > 5 then
        self.grounded = false
      end
    else
      self.in_air = 0
      self.grounded = true
    end

    -- check if horizontal movement is blocked
    self.sided = not free_rect(v2(self.pos.x + (self.face_left and -3 or 3), self.pos.y - 1), v2(1, 2))

    -- check if vertical movement is blocked upwards
    self.headed = not (free_rect(v2(self.pos.x - 2, self.pos.y - 3), v2(5, 1)) or free_rect(v2(self.pos.x - 2 + (self.face_left and -1 or 1), self.pos.y - 3), v2(5, 1)))

    -- jetpack
    if (not self.joy.o.isdown) self.fuel = min(self.fuel + (self.grounded and .2 or .1), 10)
    if (self.joy.o:hold(2)) self.fuel = max(self.fuel - 0.1, 0)
    if self.joy.o:hold(2) and self.fuel >= 0.1 and not self.headed then
      self.acc.y = physics_constants.jetpack_force
    else
      self.acc.y = self.grounded and physics_constants.ground_gravity or physics_constants.air_gravity
    end

    -- process horizontal movement using left/right input.
    local move_acc = self.grounded and physics_constants.ground_acc or physics_constants.air_acc
    if self.joy.left.isdown then
      self.face_left, self.acc.x = true, not self.sided and -move_acc or self.acc.x
    elseif self.joy.right.isdown then
      self.face_left, self.acc.x = false, not self.sided and move_acc or self.acc.x
    else
      self.spd.x = self.spd.x * (self.grounded and physics_constants.ground_friction or physics_constants.air_friction)
    end

    -- apply acceleration
    self.spd += self.acc

    -- clamp speed
    if self.grounded then
      self.spd.x = mid(self.spd.x, physics_constants.max_ground_h_spd * -1, physics_constants.max_ground_h_spd)
      self.spd.y = mid(self.spd.y, physics_constants.max_ground_up_spd, physics_constants.max_ground_down_spd)
    else
      self.spd.x = mid(self.spd.x, physics_constants.max_air_h_spd * -1, physics_constants.max_air_h_spd)
      self.spd.y = mid(self.spd.y, physics_constants.max_air_up_spd, physics_constants.max_air_down_spd)
    end
    if abs(self.spd.x) < 0.005 then
      self.spd.x = 0
    end

    self.real_pos = self:check_collision(self.real_pos, self.real_pos + self.spd)

    self.pos = self.real_pos:floor()
  end

  function s:draw()
    rect(self.pos.x - 2, self.pos.y - 2, self.pos.x + 2, self.pos.y + 2, self.color)
    pset(self.pos.x, self.pos.y, self.color)
    line(0, self.color, self.fuel, self.color, self.color)
  end

  return s
end

function new_player(joy, color)
  return {
    joy = joy,
    color = color,
    soldier = nil,
    spawn = function(self)
      self.soldier = new_soldier(self.joy, self.color)
    end,
    update = function(self)
      if self.joy.x.double then
        sfx(1)
        self:spawn()
      end

      if self.soldier then
        self.soldier:update()
      end
    end,
    draw = function(self)
      if self.soldier then
        self.soldier:draw()
      end
    end
  }
end

-- Init, Update and Draw
function _init()
  joysticks = {
    joystick(0, 8, 30),
    joystick(1, 8, 30),
    joystick(2, 8, 30),
    joystick(3, 8, 30)
  }

  players = {
    new_player(joysticks[1], 11),
    new_player(joysticks[2], 12),
    new_player(joysticks[3], 13),
    new_player(joysticks[4], 14)
  }

  for p in all(players) do
    p:spawn()
  end
end

function _update60()
  for j in all(joysticks) do
    j:update()
  end

  for p in all(players) do
    p:update()
  end
end

function _draw()
  cls(1)
  sspr(0, 0, 128, 112, 0, 8)

  for p in all(players) do
    p:draw()
  end

  if players[1].soldier then
    local s = players[1].soldier
  end
end
