pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function start_gen()
  pprint("chaos emerges,", 24, 26, 11, 0, "l", true)
  pprint("last war approaches", 28, 35, 11, 0, "l", true)
  local colls, shape = map_colors[game_options[3][1]], game_options[2][1]
  background_color = 128 + colls[randint(3, #colls)]
  pal(1, background_color, 1)
  flip()
  gen_map(densities[game_options[1][1]], colls[1], colls[2], shape == 1, shape == 1, shape == 1 or shape == 2, true)
end

function _init()
  music(0, 500)

  initial_map = false

  countdown_t = 0

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

  parse_string_data(
    "smoke,0.1,0.25,25,45,-0.1,0.1,0.03,0.01,-0.005,0.005,-0.02,-0.01,2,0-1-1,7-6-6-5|spark,0.5,0.75,22,56,-0.42,0.42,-0.6,0.1,-0.01,0.01,0.01,0.02,1-4,0-0-1-1,7-10-10-10-8-2-0|jetpack,0.3,0,6,16,-0.1,0.1,0.15,0.7,-0.03,0.03,0,0,2-3,1-1-0,7-10-10-9-5-5|spawn_square_1,1,0,50,50,0,0,0,0,0,0,0,0,0,6-5-4-3-2-1-0,7|spawn_square_2,1,0,20,20,0,0,0,0,0,0,0,0,0,12-11-10-9-8-7-6-5-4-3-2-1-0,7|spawn_circle_1,1,0,50,50,0,0,0,0,0,0,0,0,2,6-5-4-3-2-1-0,7|spawn_circle_2,1,0,20,20,0,0,0,0,0,0,0,0,2,12-11-10-9-8-7-6-5-4-3-2-1-0,7|spawn_line,0.5,0.17,35,45,0,0,0,0,0,0,0,0,4,3-2-2-1,7|heal,0.7,0,65,85,-0.07,0.07,0.15,0.07,-0.005,0.005,-0.003,-0.01,3,0-1-1-1,7-7-11-11-3|blood,0.75,1,55,85,-0.01,0.01,-0.02,0.02,0,0,0.017,0.021,1,1,8|explosion_blob_1,0.9,0.1,20,25,-0.07,0.07,-0.07,0.07,0,0,-0.007,-0.017,3,1-2-2-1-0,7-10-9-8|explosion_blob_2,0.9,0.2,20,25,-0.07,0.07,-0.007,0.007,-0.007,0.007,-0.007,-0.017,3,2-3-3-2,7-7-10-10-10-9-8-2|explosion_blob_3,0.9,0.25,20,25,-0.07,0.07,-0.007,0.007,-0.007,0.007,-0.007,-0.017,3,3-4-4-3,7-7-10-10-10-9-8-2|explosion_shock_1,1,0,8,12,0,0,0,0,0,0,0,0,2,0-1-2-3-4-5,7|explosion_shock_2,1,0,8,12,0,0,0,0,0,0,0,0,2,0-1-2-3-4-5-7-8-9,7|explosion_shock_3,1,0,8,12,0,0,0,0,0,0,0,0,2,0-1-2-3-4-5-7-8-9-10-11-12-13,7|flash_1,0.8,0,7,10,0,0,0,0,0,0,0,0,3,1-2-2-3,7-7-7-10|flash_2,0.8,0,7,10,0,0,0,0,0,0,0,0,3,1-2-3-3-4,7-7-7-10-9|flash_3,0.6,0.3,8,16,0,0,0,0,0,0,0,0,3,1-2-2,7-14-8-2|dirt,0.5,0.4,25,90,-0.05,0.05,-0.05,-0.01,0,0,0.01,0.02,1,1",
    effect_parser
  )

  weapons = parse_string_data(
    "1,3,1.9,2.4,10,110,1,150,250,22,1,0.015,1.1,1.4,0.011,0.12,1,7-10|2,2,5,7,1,80,1,300,300,80,5,0.02,1.2,1.6,0.021,0.18,2,6|3,3,1.8,3,30,120,1,180,300,6,1,0.009,1.25,1.7,0.012,0.13,1,7-10|4,3,1.4,2.2,5,120,5,40,80,55,1,0.022,1,1.6,0.014,0.15,1,7-10|5,3,5,6,3,120,1,100,100,60,4,0.001,2.4,2.6,0.01,0.1,1,10|6,3,5,6,1,90,1,180,180,70,6,0.017,2,2.1,0,0.035,2,11|7,5,0.6,1.2,50,145,3,15,30,7,3,0.04,0.45,1.2,-0.01,-0.03,0-1-1,10-10-9-9-9-8|8,6,1,2.5,1,60,1,15,55,60,4,0.01,0.8,1.1,0,0,0-1-2-2-2,8-8-8-2-13",
    weapon_parser
  )

  sprites = parse_string_data(
    "6,122,4,6,1,3,3,2,0,0,2,5|10,122,3,6,1,3,2,3,0,0,2,5|13,122,5,6,1,3,4,1,0,0,2,5|18,122,4,6,1,3,3,2,0,0,2,5|22,122,4,6,1,3,3,2,0,0,3,5|26,122,7,6,0,3,2,2,0,0,5,5|123,122,5,6,1,3,2,3,0,1,3,5|101,121,7,3,3,1,6,2,0,0,6,2|30,117,5,5,2,2,1,3,0,1,4,4|0,123,6,5,2,2,5,2,0,0,4,4|97,123,4,5,1,2,3,2,0,0,3,4|85,123,6,5,2,2,5,4,0,0,4,4|35,117,4,6,1,3,3,2,1,0,3,5|91,122,6,6,0,3,5,2,0,0,4,5|24,117,6,5,3,2,3,2,0,0,4,4|40,120,2,1,0,1,1,0|40,122,1,2,1,1,0,0|42,120,2,2,0,2,1,0|42,122,2,2,0,1,1,1|40,121,2,1,-1,0,1,0|41,122,1,2,0,2,0,0|46,120,2,2,-1,2,1,0|44,120,2,2,-1,-1,1,1|48,120,4,3,1,2,3,1|54,112,3,4,2,2,1,0|57,112,4,4,2,2,3,0|54,116,4,4,1,2,3,3|57,121,5,2,2,1,4,0|60,123,2,5,1,2,0,0|52,120,5,3,2,2,4,0|58,116,4,5,1,2,3,4|67,125,6,3,2,2,5,1|67,118,3,6,2,3,1,0|70,112,6,5,2,4,5,0|70,117,6,5,1,2,5,4|76,112,7,3,4,2,6,1|76,115,3,7,2,2,1,0|73,122,6,6,5,2,5,0|79,122,6,6,3,5,5,5|62,123,6,3,0,2,5,1|67,112,3,6,2,5,1,0|62,117,5,6,1,5,4,0|61,112,6,5,0,1,5,4|29,112,5,5,2,2,0,0,0,0,4,4|24,112,5,5,2,2,0,0,0,0,4,4|119,123,4,5,1,2,0,0,0,0,3,4|83,112,3,2,1,0,0,0,0,0,2,1|40,112,14,8,6,3|34,112,6,4,2,1|35,124,9,4,4,1|53,123,7,5,3,2|110,124,9,4,4,1|101,124,9,4,4,1|111,120,8,4,3,1|44,123,9,5,4,2|95,112,8,9,5,4,6,4,2,1,7,7|89,112,6,10,3,4,4,4,0,1,5,8|79,115,10,7,7,3,9,3,1,0,9,6|103,112,8,9,5,4,6,3,2,1,7,8|111,112,8,8,5,2,5,1,1,0,7,6|0,112,6,11,3,5,5,5,0,1,5,9|6,112,10,9,2,4,3,3,0,1,9,7|16,112,8,9,5,6,6,7,0,3,7,8|119,112,9,9,2,5,3,4,0,2,6,8|0,0,104,28,0,0",
    sprite_parser
  )

  players = parse_string_data(
    "1,11,3,121,3,114,1,112,6,98,3,92,1,128,1|2,12,13,6,3,13,1,15,6,30,3,37,1,1,1|3,10,9,121,123,114,121,112,126,98,124,92,121,128,121|4,7,6,6,123,13,121,15,126,30,124,37,121,1,121",
    player_parser
  )

  main_menu = menu_parser(
    "mode,war,arena,chaos|time,5,10,15|boxes,few,more,lots|traps,none,more,lots|bots,lame,tough,boss| enter the wastelands", 27, function(opts, y)
      if y == 6 then
        sfx(31)
        game_options = opts
        game_state = "map_menu"
      end
    end
  )

  densities = { .485, .49, .515 }
  map_colors = {
    { 4, 3, 0, 1, 5, 12 },
    { 5, 12, 0, 1, 2, 4, 5, 6 },
    { 5, 6, 0, 1, 5 }
  }

  map_menu = menu_parser(
    "density,light,cozy,stuffed|shape,cave,canyon,island|fabric,earth,rock,concrete|terraform|start|back", 30, function(opts, y)
      if y == 4 then
        sfx(31)
        start_gen()
      elseif y == 5 then
        if not initial_map then
          initial_map = true
          start_gen()
        end
        init_spawners({
          enemy = {
            object_type = 6,
            max_spawn_time = 1200,
            max_objects = game_options[3][1] * 3,
            color1 = 0,
            color2 = 8
          },
          hp_box = {
            object_type = 2,
            max_spawn_time = 1800,
            max_objects = game_options[3][1] * 2,
            color1 = 7,
            color2 = 8
          },
          weapon_box = {
            object_type = 3,
            max_spawn_time = 1200,
            max_objects = game_options[3][1] * 3,
            color1 = 3,
            color2 = 4
          },
          barrel = {
            object_type = 4,
            max_spawn_time = 2000,
            max_objects = (game_options[4][1] - 1) * 3,
            color1 = 0,
            color2 = 11
          }
        })

        countdown_t = game_options[2][1] * 5 * 60 + 5

        game_state = "game"
      elseif y == 6 then
        sfx(31)
        game_state = "main_menu"
      end
    end
  )

  background_color = 1

  game_state = "main_menu"
end

function _update60()
  if countdown_t > 0 then
    countdown_t -= 1 / 60
    if countdown_t <= 0 then
      countdown_t = 0
      game_state = "game_over"
      cooldowns = {}
      for p in all(players) do
        p.soldier = nil
      end
      for o in all(world:get_objects(nil, 0, 1)) do
        o.remove = true
      end
    end
  end

  update_cooldowns()

  for player in all(players) do
    player:update()
  end

  bg_particles:update()

  fg_particles:update()

  world:update()

  if game_state == "game_over" then
    for p in all(players) do
      if p.connected and p.joy.x.pressed or p.joy.o.pressed then
        for pp in all(players) do
          pp.connected = false
          pp.score = 0
          pp.msg = "join 🅾️/❎"
        end
        game_state = "main_menu"
        break
      end
    end
  end
end

function _draw()
  memcpy(0x6200, 0x8200, 0x1C00)

  bg_particles:draw()
  world:draw()

  rectfill(0, 0, 127, 7, 0)
  rectfill(0, 120, 127, 127, 0)
  for player in all(players) do
    player:draw()
  end

  if countdown_t > 0 then
    local t, s, m = flr(countdown_t), flr(countdown_t) % 60, flr(countdown_t / 60)
    if not (t <= 3 and countdown_t % 1 < 0.5) then
      pprint(m .. ":" .. (s < 10 and "0" .. s or s), 64, 1, t <= 10 and 8 or t <= 30 and 10 or 7, 2, "c", true)
    end
  end

  if game_state == "main_menu" then
    main_menu:draw(v2(14, 59))
    pal(1, 0)
    sprites[65]:draw(v2(12, 22))
    pal()
  elseif game_state == "map_menu" then
    map_menu:draw(v2(4, 59))
  elseif game_state == "game_over" then
    pprint("the battle is over", 64, 18, 8, 0, "c", true)
  end

  fg_particles:draw()

  pal(1, background_color, 1)
end
