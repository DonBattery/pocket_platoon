pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function _init()
  -- save the first 128*112 pixel of the sprite sheet to the 0x8000 memory address
  memcpy(0x8000, 0x0, 0x1c00)

  -- set the value returned by sget outside of the spritesheet
  poke(0x5f36, 0x10)
  poke(0x5f59, 16)

  -- music please!
  music(0)

  -- z_index enums
  -- z_soldier = 1
  -- z_enemy = 2
  -- z_box = 3
  -- z_barrel = 4
  -- z_mine = 5
  -- z_gate = 6

  -- weapon enums
  -- w_pistol = 1
  -- w_knife = 2
  -- w_uzi = 3
  -- w_shotgun = 4
  -- w_sniper_rifle = 5
  -- w_rocket_launcher = 6
  -- w_flamethrower = 7

  -- object type enums
  -- ot_soldier = 1
  -- ot_box = 2
  -- ot_barrel = 3
  -- ot_mine = 4
  -- ot_droid = 5
  -- ot_gate = 6

  physics_constants = {
    ground_gravity = 0,
    air_gravity = 0.06,
    jetpack_force = -0.08,
    ground_acc = 0.025,
    air_acc = 0.03,
    ground_friction = 0.96,
    air_friction = 0.98,

    ground_speed_limit = { .4, -.5, .6 },
    air_speed_limit = { .75, -1.1, .9 },
    knocked_speed_limit = { 1, -1, 1 },
    exploded_speed_limit = { 1.2, -1.2, 1.2 },
    bullet_speed_limit = { 3, -3, 3 }
  }

  dir_to_trans = {
    n = { 2, false, false, v2(0, -1), v2(0, -1) },
    ne = { 3, false, false, v2(1, -1), v2(.7, -.7) },
    e = { 1, false, false, v2(1, 0), v2(1, 0) },
    se = { 4, false, false, v2(1, 1), v2(.7, .7) },
    s = { 2, true, true, v2(0, 1), v2(0, 1) },
    sw = { 4, true, false, v2(-1, 1), v2(-.7, .7) },
    w = { 1, true, false, v2(-1, 0), v2(-1, 0) },
    nw = { 3, true, false, v2(-1, -1), v2(-.7, -.7) }
  }

  screen_rect, map_rect, game_rect = { pos = v2(0, 0), size = v2(128, 128) }, { pos = v2(0, 0), size = v2(128, 112) }, { pos = v2(0, 8), size = v2(128, 112) }

  bg_particles, fg_particles = new_particle_system(), new_particle_system()

  destructors, edge_destructors = {}, {}
  init_destructors()

  world = new_world()

  -- min_dmg, max_dmg, magazine, reload_time, burst, max_life, max_w_cd, kind, sizes, colors, accuracy, min_force, max_force, mass, v_modifier
  weapons = parse_string_data(
    "1.9,2.4,10,110,1,300,22,1,1,7-10,0.015,1.1,1.4,0.011,0.12|5,7,1,80,1,300,80,5,2,6,0.02,1.2,1.6,0.021,0.18|1.8,3,30,120,1,300,6,1,1,7-10,0.009,1.25,1.7,0.012,0.13|1.4,2.2,5,120,5,100,55,1,1,7-10,0.022,1,1.6,0.014,0.15|5,6,3,120,1,100,60,4,1,10,0.001,2.4,2.6,0.01,0.1|5,6,1,90,1,200,70,6,2,11,0.017,2,2.1,0,0.04|0.6,1.2,50,145,3,30,7,3,0-1-1,10-10-9-9-9-8,0.04,0.45,1.2,-0.01,-0.03|1,3,0,0,1,45,0,4,0-1-2-2-2,8-8-8-2,0,1,1.2,0,0",
    weapon_parser
  )

  -- 1 - 15 soldier
  -- 16 - 43 weapons
  -- 44 - 55 items
  -- 56 - 64 enemy
  sprites = parse_string_data(
    "6,122,4,6,1,3,3,2,0,0,2,5|10,122,3,6,1,3,2,3,0,0,2,5|13,122,5,6,1,3,4,1,0,0,2,5|18,122,4,6,1,3,3,2,0,0,2,5|22,122,4,6,1,3,3,2,0,0,3,5|26,122,7,6,0,3,2,2,0,0,5,5|123,122,5,6,1,3,2,3,0,1,3,5|101,121,7,3,3,1,6,2,0,0,6,2|30,117,5,5,2,2,1,3,0,1,4,4|0,123,6,5,2,2,5,2,0,0,4,4|97,123,4,5,1,2,3,2,0,0,3,4|85,123,6,5,2,2,5,4,0,0,4,4|35,117,4,6,1,3,3,2,1,0,3,5|91,122,6,6,0,3,5,2,0,0,4,5|24,117,6,5,3,2,3,2,0,0,4,4|40,120,2,1,0,1,1,0|40,122,1,2,1,1,0,0|42,120,2,2,0,2,1,0|42,122,2,2,0,1,1,1|40,121,2,1,-1,0,1,0|41,122,1,2,0,2,0,0|46,120,2,2,-1,2,1,0|44,120,2,2,-1,-1,1,1|48,120,4,3,1,2,3,1|54,112,3,4,2,2,1,0|57,112,4,4,2,2,3,0|54,116,4,4,1,2,3,3|57,121,5,2,2,1,4,0|60,123,2,5,1,2,0,0|52,120,5,3,2,2,4,0|58,116,4,5,1,2,3,4|67,125,6,3,2,2,5,1|67,118,3,6,2,3,1,0|70,112,6,5,2,4,5,0|70,117,6,5,1,2,5,4|76,112,7,3,4,2,6,1|76,115,3,7,2,2,1,0|73,122,6,6,5,2,5,0|79,122,6,6,3,5,5,5|62,123,6,3,0,2,5,1|67,112,3,6,2,5,1,0|62,117,5,6,1,5,4,0|61,112,6,5,0,1,5,4|29,112,5,5,2,2|24,112,5,5,2,2|119,123,4,5,1,2|40,112,14,8,6,3|34,112,6,4,2,1|35,124,9,4,4,1|53,123,7,5,3,2|110,124,9,4,4,1|101,124,9,4,4,1|111,120,8,4,3,1|44,123,9,5,4,2|83,112,3,2,1,1|95,112,8,9,5,4,6,4,2,1,7,7|89,112,6,10,3,4,4,4,0,1,5,8|79,115,10,7,7,3,9,3,1,0,9,6|103,112,8,9,5,4,6,3,2,1,7,8|111,112,8,8,5,2,5,1,1,0,7,6|0,112,6,11,3,5,5,5,0,1,5,9|6,112,10,9,2,4,3,3,0,1,9,7|16,112,8,9,5,6,6,7,0,3,7,8|119,112,9,9,2,5,3,4,0,2,6,8",
    sprite_parser
  )

  -- id (odd numbers are facing left)
  -- color1, color2
  -- hud_points
  players = parse_string_data(
    "1,11,3,121,3,114,1,112,6,98,3,92,1,128,1|2,12,13,6,3,13,1,15,6,30,3,37,1,1,1|3,10,9,121,123,114,121,112,126,98,124,92,121,128,121|4,7,6,6,123,13,121,15,126,30,124,37,121,1,121",
    player_parser
  )

  gen_map()

  for i = 1, 10 do
    world:add_object(new_box(randint(1, 2), world:get_safe_spot(5)))
  end

  scheduler:add(
    "box-spawner", 100, 0, function()
      if rnd() < .8 then return end
      local boxes = world:get_objects(nil, 0, 2)
      if #boxes < 5 then
        world:add_object(new_box(randint(1, 2), world:get_safe_spot(5)))
      end
    end
  )

  scheduler:add(
    "enemy-spawner", 100, 0, function()
      if rnd() < .6 then return end
      local enemies = world:get_objects(nil, 0, 3)
      if #enemies < 3 then
        local spot = world:get_safe_spot(5)
        spawn_effect(spot, 0, 8)
        scheduler:add(
          "enemy-spawning", 50, 1, function()
            world:add_object(new_enemy(spot))
          end
        )
      end
    end
  )
end

function _update60()
  scheduler:update()
  bg_particles:update()
  fg_particles:update()
  world:update()
  for player in all(players) do
    player:update()
  end
end

function _draw()
  -- this copies the first 128*112 pixel from the sprite sheet directly to the screen starting from the 0,8 pixel
  memcpy(0x6200, 0X0, 0x1c00)

  bg_particles:draw()
  world:draw()
  fg_particles:draw()

  rectfill(0, 0, 127, 7, 0)
  rectfill(0, 120, 127, 127, 0)

  for player in all(players) do
    player:draw()
  end

  -- debug sprites
  -- cls(1)
  -- palt(0, false)
  -- palt(14, true)
  -- local x, y, i = 0, 0, 1
  -- for sprite in all(sprites) do
  --   pprint(i, x, y)
  --   sprite:draw(v2(x + 12, y + 3))
  --   x += sprite.size.x + 12
  --   if x > 100 then
  --     x = 0
  --     y += 12
  --   end
  --   i += 1
  -- end
  -- palt()
end
