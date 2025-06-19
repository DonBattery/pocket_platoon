# Pocket Platoon
A [PICO-8](https://www.lexaloffle.com/pico-8.php) party game for up to 4 buddies  
ver: **Open Beta**

[<img src="doc/screenshot.png">](https://donbattery.github.io/pocket_platoon/)  
Test your skills in this fast-paced post-apocalyptic shooter against the invading techno squids (or your buddies)!  
**CLICK ON THE SCREENSHOT TO PLAY**  

This game features:
- Local multiplayer for 4 players  
- 3 game modes (PvE, PvP and PvPvE)  
- Infinite random generated maps (3 different planes: Earth, Void and Ruins with 9 possible color schemes)  
- Pixel perfect terrain destruction  
- 2 power-ups (HP and Weapon Box)  
- 2 traps (Land Mine and Acid Barrel)  
- 10 unique weapons  
- melee combat  
- techno squids  

## Controls  
![LeftRight](doc/left_right.gif) ![Jetpack](doc/jetpack.gif) ![8-way-aim](doc/8_way_aim.gif)  ![Melee](doc/melee.gif)  

### Player 1 Keyboard
**Movement/Aim**: <kbd>Left</kbd>, <kbd>Right</kbd>, <kbd>Up</kbd>, <kbd>Down</kbd>  
**Start/Shoot/Melee**: <kbd>X</kbd> / <kbd>V</kbd> / <kbd>M</kbd>  
**Start/Jetpack**: <kbd>Z</kbd> / <kbd>C</kbd> / <kbd>N</kbd>  

### Player 2 Keyboard
**Movement/Aim**:  <kbd>S</kbd>, <kbd>F</kbd>, <kbd>E</kbd>, <kbd>D</kbd>  
**Start/Shoot/Melee**: <kbd>LSHIFT</kbd> / <kbd>A</kbd>  
**Start/Jetpack**: <kbd>TAB</kbd> / <kbd>Q</kbd>  

### Player 1 - Player 4 - Joystick / Gamepad

Any SDL compatible controller with at least 6 buttons (left, right, up, down, O, X) is supported

### Mobile
Thanks to the PICO-8 webplayer, touch controls are available in both portrait (GameBoy) and landscape (GameGear) view.  

## How to play
**Main Menu**  
![MainMenu](doc/main_menu.png)  

**Map Menu**  
![MapMenu](doc/map_menu.png)  

**In Game**  
![InGame](doc/in_game.png)  

## Arsenal
| Weapon       | Portrait                         | Usage                | Damage | Burst| Magazine| Fire rate | Reload time|
|------------|------------------------------|----------------------------| -| -| -| -| -|
| Pistol     | ![Pistol](doc/pistol.png) |   ![Pistol in use](doc/pistol_use.gif) |2.8 - 3.2|1|8|2.79|1.5
| Knife     | ![Knife](doc/knife.png) |   ![Pistol in use](doc/knife_use.gif) |6 - 9|1|1|1|1
| Bolter     | ![Bolter](doc/bolter.png) |   ![Bolter in use](doc/bolter_use.gif) |0.9 - 1.1|1|30|10|2
| Shotgun     | ![Shotgun](doc/shotgun.png) |   ![Shotgun in use](doc/shotgun_use.gif) |0.9 - 1.3|5|5|2|2
| Lazer Rifle     | ![Lazer Rifle](doc/lazer_rifle.png) |   ![Lazer Rifle in use](doc/lazer_rifle_use.gif) |6 - 7.5|1|3|3|2
| Rocketeer     | ![Rocketeer](doc/rpg.png) |   ![Rocketeer in use](doc/rpg_use.gif) |7 - 8|1|1|0.63|1.58
| Flamer     | ![Flamer](doc/flamer.png) |   ![Flamer in use](doc/flamer_use.gif) |0.5 - 0.8|3|50|6|1.66
| Granadeer     | ![Granadeer](doc/granadeer.png) |   ![Granadeer in use](doc/granadeer_use.gif) |6 - 9|1|4|1|2.16
| Orber     | ![Orber](doc/orber.png) |   ![Orber in use](doc/orber_use.gif) |2 - 3|1|1|0.85|1.16
| Molter     | ![Molter](doc/molter.png) |   ![Molter in use](doc/molter_use.gif) |2.5 - 3|3|3|2|1.25

### Boxes 
**HP Box**  
![HP_Box](doc/hp_box.gif)  
Every soldier has 10 HP by default. You can only pick up a HP Box when your HP is below 10. Picking up a HP Box will restore your HP to 10.  

**Weapon Box**  
![Weapon_Box](doc/weapon_box.gif)  
You get a Pistol by default. Picking up a Weapon Box will change your weapon to a random weapon which is not a Pistol, and not the one you are currently holding.  


### Traps  
**Land mine**  
![Land_mine](doc/land_mine.gif)  

**Acid barrel**  
![Acid_Barrel](doc/acid_barrel.gif)  

### Enemies  
**Techno Squid (Weapon: Lazer Melee: Cyber Tentacles)**  
![TechnoSquid](doc/techno_squid.gif)  

### Music
[Gruber Jam - Space Lizards](https://www.lexaloffle.com/bbs/?tid=52127)

- although this is a really catchy chip-tune, it can get repetitive over some time. You can turn off the music separately from the sound, in the PICO-8 built-in menu (<kbd>P</kbd> or <kbd>Enter</kbd>)  
