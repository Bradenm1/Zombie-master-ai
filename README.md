## Zombie Master Bot
A bot for the gamemode Zombie Master on Garrys Mod.
Zombie Master requires two players to play and it can be hard to find player soo..
I figued I would created a bot for people to use for solo play.

### Code Example

This bot can currently:
* Use traps
* Spawn all types of zombies
* Command zombies
* Kill zombies (No players are near them)
* Use explosions

### Installation

* Download Zombie Master Gamemode
* Install at Garrys Mod Addons folder

### Usage

Load up a server, make sure you have a player slot available for the bot.
Play!

#### Console Commands: 
* zm_ai_enabled - Disables or Enables the bot. Toggle
* zm_ai_force_start_round - Forces the round to start/restart
* zm_ai_ignore_player - Adds player to a list for AI to ignore
* zm_ai_remove_ignore_player - Removes player from the ignore list
* zm_ai_max_zombies_per_player - Max amount of zombies the AI can spawn per player. Default 16
* zm_ai_speed - Changes bots global speed. Default: 1
* zm_ai_debug - Shows debug log in chat of what bot is doing and prints to console for debug reasons. Toggle
* zm_ai_dynamic_traps - If traps stats are generated as you go or all generated at round start. Default: 0
* zm_ai_command_delay - Changes the rate at which it commands zombies. Default: 1
* zm_ai_enable_force_start - Stops rounds from being forced when bot joins. Toggle
* zm_ai_zombie_spawn_delay - Rate at which zombies spawn. Default: 3 
* zm_ai_min_zombie_delete_dis - If zombies go over this distance from players they get deleted. Default: 3000
* zm_ai_max_zombie_spawn_dis - If a player is within this distance the AI spawns zombies. Default: 3000
* zm_ai_move_ply_to_last_spawn - Used for debugging.
* zm_ai_min_distance_to_act_trap - Min distance player has to be for trap to be activated. Default 92 
* zm_ai_max_distance_to_act_trap - Max distance player can be before the AI won't activate the trap. Default: 224

License
----

See the included LICENSE file