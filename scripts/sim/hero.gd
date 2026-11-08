class_name Hero
extends Villager
## A named dragon hunter. Walks like a villager but has no home
## or job, and doesn't count toward the population. VillageSim moves them.

const MAX_NAME_LENGTH := 16
## Armor trades health for speed. Speed multiplies a villager's walking pace.
const ARMORS := {
	&"leather": {"name": "Leather", "note": "Light, fast", "health": 50, "speed": 2.0},
	&"chainmail": {"name": "Chainmail", "note": "Balanced", "health": 100, "speed": 1.5},
	&"dragonscale": {"name": "Dragonscale", "note": "Tough, slow", "health": 175, "speed": 1.1},
}
## Damage is dealt to the dragon's resolve each tick it's within reach (in cells).
## A weapon that keeps_clear attacks from outside the dragon's fire.
const WEAPONS := {
	&"longsword": {"name": "Longsword", "note": "Steady hits", "damage": 10, "reach": 3.0, "keeps_clear": false},
	&"longbow": {"name": "Longbow", "note": "Safe, weaker", "damage": 7, "reach": 7.0, "keeps_clear": true},
	&"battle_axe": {"name": "Battle Axe", "note": "Huge, close", "damage": 15, "reach": 2.5, "keeps_clear": false},
}
const LOOKS := {
	&"ember": {"name": "Ember", "note": "Red, crimson"},
	&"raven": {"name": "Raven", "note": "Black, gold"},
	&"frost": {"name": "Frost", "note": "Silver, teal"},
}

var hero_name := ""
var armor := &"chainmail"
var weapon := &"longsword"
var look := &"ember"
var health := 0
## Knocked out of the fight. Stays true until fully healed.
var wounded := false
var dragons_slain := 0
## Whether this hero landed a blow on the current visit's dragon.
var fought := false


static func clean_name(text: String) -> String:
	return SaveGame.strip_unsupported_characters(text).strip_edges().left(MAX_NAME_LENGTH).strip_edges()


## Returns null unless the name is usable and all three choices exist.
static func create(new_name: String, new_armor: StringName, new_weapon: StringName, new_look: StringName) -> Hero:
	if clean_name(new_name).is_empty():
		return null
	if not (ARMORS.has(new_armor) and WEAPONS.has(new_weapon) and LOOKS.has(new_look)):
		return null
	var hero := Hero.new()
	hero.hero_name = clean_name(new_name)
	hero.armor = new_armor
	hero.weapon = new_weapon
	hero.look = new_look
	hero.health = hero.max_health()
	return hero


func max_health() -> int:
	return ARMORS[armor].health


func speed_factor() -> float:
	return ARMORS[armor].speed


func damage() -> int:
	return WEAPONS[weapon].damage


func reach() -> float:
	return WEAPONS[weapon].reach


func keeps_clear() -> bool:
	return WEAPONS[weapon].keeps_clear


func weapon_index() -> int:
	return WEAPONS.keys().find(weapon)


## The row of hero.png showing this armor, weapon and look together.
func sprite_row() -> int:
	return sprite_row_for(armor, weapon, look)


static func sprite_row_for(for_armor: StringName, for_weapon: StringName, for_look: StringName) -> int:
	return ARMORS.keys().find(for_armor) * 9 + WEAPONS.keys().find(for_weapon) * 3 + LOOKS.keys().find(for_look)


func to_data() -> Dictionary:
	var data := super()
	data.merge({
		"name": hero_name,
		"armor": String(armor),
		"weapon": String(weapon),
		"look": String(look),
		"health": health,
		"wounded": wounded,
		"dragons_slain": dragons_slain,
		"fought": fought,
	})
	return data
