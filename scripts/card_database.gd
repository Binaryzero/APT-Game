class_name CardDatabase
extends RefCounted

const ART := {
    "title_kitchen": preload("res://assets/template/cardgame/title_kitchen.webp"),
    "battle_board": preload("res://assets/template/cardgame/battle_board.webp"),
    "kitchen_break": preload("res://assets/template/cardgame/kitchen_break.webp"),
    "chef_sama": preload("res://assets/template/cardgame/chef_sama.webp"),
    "icon_sword": preload("res://assets/template/cardgame/icon_sword.webp"),
    "icon_shield": preload("res://assets/template/cardgame/icon_shield.webp"),
    "leaderboard_crest": preload("res://assets/template/cardgame/leaderboard_crest.png"),
    "ingredient_fungus": preload("res://assets/template/cardgame/ingredient_fungus.png"),
    "ingredient_herb": preload("res://assets/template/cardgame/ingredient_herb.png"),
    "ingredient_meat": preload("res://assets/template/cardgame/ingredient_meat.png"),
    "ingredient_ember": preload("res://assets/template/cardgame/ingredient_ember.png"),
    "juice_card_back": preload("res://assets/template/cardgame/juice/card_back.png"),
    "juice_mana_burner": preload("res://assets/template/cardgame/juice/mana_burner.png"),
    "juice_armor_pan": preload("res://assets/template/cardgame/juice/armor_pan.png"),
    "juice_pantry_jar": preload("res://assets/template/cardgame/juice/pantry_jar.png"),
    "juice_encounter_seal": preload("res://assets/template/cardgame/juice/encounter_seal.png"),
    "juice_selection_knife": preload("res://assets/template/cardgame/juice/selection_knife.png"),
    "juice_cooking_cauldron": preload("res://assets/template/cardgame/juice/cooking_cauldron.png"),
	"tutorial_mise": preload("res://assets/template/cardgame/tutorial/mise_guide.png"),
	"tutorial_pointer": preload("res://assets/template/cardgame/tutorial/spoon_pointer.png"),
	"hud_hero_station_frame": preload("res://assets/template/cardgame/layout/hero_station_frame.png"),
	"hud_unit_plate_frame": preload("res://assets/template/cardgame/layout/unit_plate_frame.png"),
	"hud_passive_medallion_frame": preload("res://assets/template/cardgame/layout/passive_medallion_frame.png"),
	"hud_turn_marker": preload("res://assets/template/cardgame/layout/turn_marker.png"),
	"hud_end_turn_frame": preload("res://assets/template/cardgame/layout/end_turn_frame.png"),
	"hud_history_ticket_frame": preload("res://assets/template/cardgame/layout/history_ticket_frame.png"),
	"hud_pantry_tray_frame": preload("res://assets/template/cardgame/layout/pantry_tray_frame.png"),
	"hud_mana_rack_frame": preload("res://assets/template/cardgame/layout/mana_rack_frame.png"),
	"hud_deck_cradle": preload("res://assets/template/cardgame/layout/deck_cradle.png"),
	"picklemancer": preload("res://assets/template/cardgame/picklemancer.webp"),
    "mold_monarch": preload("res://assets/template/cardgame/mold_monarch.webp"),
    "ember_butcher": preload("res://assets/template/cardgame/ember_butcher.webp"),
    "banquet_tyrant": preload("res://assets/template/cardgame/banquet_tyrant.webp"),
    "card_back": preload("res://assets/template/cardgame/card_back.webp"),
    "coal_squire": preload("res://assets/template/cardgame/coal_squire.webp"),
    "pan_paladin": preload("res://assets/template/cardgame/pan_paladin.webp"),
    "pepper_mage": preload("res://assets/template/cardgame/pepper_mage.webp"),
    "broth_elemental": preload("res://assets/template/cardgame/broth_elemental.webp"),
    "truffle_knight": preload("res://assets/template/cardgame/truffle_knight.webp"),
    "precise_chop": preload("res://assets/template/cardgame/precise_chop.webp"),
    "searing_arc": preload("res://assets/template/cardgame/searing_arc.webp"),
    "mise_en_place": preload("res://assets/template/cardgame/mise_en_place.webp"),
    "kitchen_guard": preload("res://assets/template/cardgame/kitchen_guard.webp"),
    "seasoned_strike": preload("res://assets/template/cardgame/seasoned_strike.webp"),
    "mise_the_thousand_handed": preload("res://assets/template/cardgame/mise_the_thousand_handed.png"),
    "the_sovereign_cleaver": preload("res://assets/template/cardgame/the_sovereign_cleaver.png"),
    "bell_of_the_last_service": preload("res://assets/template/cardgame/bell_of_the_last_service.png"),
    "mooncap_broth": preload("res://assets/template/cardgame/mooncap_broth.webp"),
    "braised_bulwark": preload("res://assets/template/cardgame/braised_bulwark.webp"),
    "dragonpepper_roast": preload("res://assets/template/cardgame/dragonpepper_roast.webp"),
    "leftover_stew": preload("res://assets/template/cardgame/leftover_stew.webp"),
    "pickle_imp": preload("res://assets/template/cardgame/pickle_imp.webp"),
    "moldling": preload("res://assets/template/cardgame/moldling.webp"),
    "cursed_onion": preload("res://assets/template/cardgame/cursed_onion.webp"),
    "dough_golem": preload("res://assets/template/cardgame/dough_golem.webp"),
    "meat_mimic": preload("res://assets/template/cardgame/meat_mimic.webp"),
    "cellar_rat": preload("res://assets/template/cardgame/cellar_rat.webp"),
    "gravy_specter": preload("res://assets/template/cardgame/gravy_specter.webp"),
}

const CARDS := {
    "coal_squire": {
        "name_key": "card.coal_squire.name", "type": "unit", "cost": 1, "attack": 1, "health": 2,
        "text_key": "card.coal_squire.text", "effect": "armor_on_play", "value": 1,
        "art": "coal_squire", "rarity": "common",
    },
    "pan_paladin": {
        "name_key": "card.pan_paladin.name", "type": "unit", "cost": 2, "attack": 2, "health": 4,
        "text_key": "card.pan_paladin.text", "guard": true,
        "art": "pan_paladin", "rarity": "common",
    },
    "pepper_mage": {
        "name_key": "card.pepper_mage.name", "type": "unit", "cost": 3, "attack": 3, "health": 2,
        "text_key": "card.pepper_mage.text", "effect": "hero_damage_on_play", "value": 2,
        "art": "pepper_mage", "rarity": "rare",
    },
    "broth_elemental": {
        "name_key": "card.broth_elemental.name", "type": "unit", "cost": 3, "attack": 2, "health": 4,
        "text_key": "card.broth_elemental.text", "effect": "broth_on_play",
        "art": "broth_elemental", "rarity": "rare",
    },
    "truffle_knight": {
        "name_key": "card.truffle_knight.name", "type": "unit", "cost": 5, "attack": 5, "health": 6,
        "text_key": "card.truffle_knight.text", "guard": true,
        "art": "truffle_knight", "rarity": "epic",
    },
    "precise_chop": {
        "name_key": "card.precise_chop.name", "type": "spell", "cost": 1,
        "text_key": "card.precise_chop.text",
        "effect": "target_enemy_damage", "value": 2, "art": "precise_chop", "rarity": "common",
    },
    "searing_arc": {
        "name_key": "card.searing_arc.name", "type": "spell", "cost": 3,
        "text_key": "card.searing_arc.text", "effect": "enemy_area_damage", "value": 2,
        "art": "searing_arc", "rarity": "rare",
    },
    "mise_en_place": {
        "name_key": "card.mise_en_place.name", "type": "spell", "cost": 2,
        "text_key": "card.mise_en_place.text", "effect": "draw", "value": 2,
        "art": "mise_en_place", "rarity": "common",
    },
    "kitchen_guard": {
        "name_key": "card.kitchen_guard.name", "type": "spell", "cost": 2,
        "text_key": "card.kitchen_guard.text", "effect": "armor", "value": 5,
        "art": "kitchen_guard", "rarity": "common",
    },
    "seasoned_strike": {
        "name_key": "card.seasoned_strike.name", "type": "spell", "cost": 2,
        "text_key": "card.seasoned_strike.text", "effect": "target_friend_buff",
        "value": 2, "art": "seasoned_strike", "rarity": "rare",
    },
    "mise_the_thousand_handed": {
        "name_key": "card.mise_the_thousand_handed.name", "type": "unit", "cost": 6,
        "attack": 4, "health": 7, "text_key": "card.mise_the_thousand_handed.text",
        "aura": "low_cost_engine", "art": "mise_the_thousand_handed", "rarity": "legendary",
    },
    "the_sovereign_cleaver": {
        "name_key": "card.the_sovereign_cleaver.name", "type": "spell", "cost": 7,
        "text_key": "card.the_sovereign_cleaver.text", "effect": "sovereign_cleaver",
        "value": 5, "art": "the_sovereign_cleaver", "rarity": "legendary",
    },
    "bell_of_the_last_service": {
        "name_key": "card.bell_of_the_last_service.name", "type": "spell", "cost": 8,
        "text_key": "card.bell_of_the_last_service.text", "effect": "bell_last_service",
        "value": 3, "heal": 8, "art": "bell_of_the_last_service", "rarity": "legendary",
    },
    "mooncap_broth": {
        "name_key": "card.mooncap_broth.name", "type": "dish", "cost": 1,
        "text_key": "card.mooncap_broth.text", "effect": "mooncap_broth",
        "servings": 2, "art": "mooncap_broth", "rarity": "dish",
    },
    "braised_bulwark": {
        "name_key": "card.braised_bulwark.name", "type": "dish", "cost": 2,
        "text_key": "card.braised_bulwark.text",
        "effect": "braised_bulwark", "servings": 2, "art": "braised_bulwark", "rarity": "dish",
    },
    "dragonpepper_roast": {
        "name_key": "card.dragonpepper_roast.name", "type": "dish", "cost": 3,
        "text_key": "card.dragonpepper_roast.text",
        "effect": "dragonpepper_roast", "servings": 1, "art": "dragonpepper_roast", "rarity": "dish",
    },
    "leftover_stew": {
        "name_key": "card.leftover_stew.name", "type": "dish", "cost": 1,
        "text_key": "card.leftover_stew.text",
        "effect": "leftover_stew", "servings": 2, "art": "leftover_stew", "rarity": "dish",
    },
    "pickle_imp": {
        "name_key": "card.pickle_imp.name", "type": "unit", "cost": 1, "attack": 2, "health": 2,
        "text_key": "card.pickle_imp.text", "ingredient": "herb", "art": "pickle_imp", "rarity": "enemy",
    },
    "moldling": {
        "name_key": "card.moldling.name", "type": "unit", "cost": 2, "attack": 2, "health": 4,
        "text_key": "card.moldling.text", "guard": true, "ingredient": "fungus",
        "art": "moldling", "rarity": "enemy",
    },
    "cursed_onion": {
        "name_key": "card.cursed_onion.name", "type": "unit", "cost": 2, "attack": 2, "health": 3,
        "text_key": "card.cursed_onion.text", "effect": "enemy_on_play_damage",
        "value": 1, "ingredient": "herb", "art": "cursed_onion", "rarity": "enemy",
    },
    "dough_golem": {
        "name_key": "card.dough_golem.name", "type": "unit", "cost": 3, "attack": 3, "health": 5,
        "text_key": "card.dough_golem.text", "guard": true, "ingredient": "herb",
        "art": "dough_golem", "rarity": "enemy",
    },
    "meat_mimic": {
        "name_key": "card.meat_mimic.name", "type": "unit", "cost": 4, "attack": 5, "health": 4,
        "text_key": "card.meat_mimic.text", "ingredient": "meat", "art": "meat_mimic", "rarity": "enemy",
    },
    "cellar_rat": {
        "name_key": "card.cellar_rat.name", "type": "unit", "cost": 2, "attack": 3, "health": 2,
        "text_key": "card.cellar_rat.text", "ingredient": "herb", "art": "cellar_rat", "rarity": "enemy",
    },
    "gravy_specter": {
        "name_key": "card.gravy_specter.name", "type": "unit", "cost": 3, "attack": 3, "health": 3,
        "text_key": "card.gravy_specter.text",
        "effect": "enemy_heal_on_play", "value": 2, "ingredient": "fungus",
        "art": "gravy_specter", "rarity": "enemy",
    },
}

const STARTER_DECK := [
    "coal_squire", "coal_squire", "coal_squire", "coal_squire",
    "pan_paladin", "pan_paladin", "pepper_mage", "broth_elemental",
    "precise_chop", "precise_chop", "precise_chop", "searing_arc",
    "mise_en_place", "kitchen_guard", "seasoned_strike",
]

const LEGENDARY_REWARDS: Array[String] = [
    "mise_the_thousand_handed",
    "the_sovereign_cleaver",
    "bell_of_the_last_service",
]

const RECIPES := {
    "mooncap_broth": {
        "name_key": "card.mooncap_broth.name", "card": "mooncap_broth",
        "cost": {"fungus": 1, "herb": 1}, "summary_key": "recipe.mooncap_broth.summary",
    },
    "braised_bulwark": {
        "name_key": "card.braised_bulwark.name", "card": "braised_bulwark",
        "cost": {"meat": 1, "herb": 1}, "summary_key": "recipe.braised_bulwark.summary",
    },
    "dragonpepper_roast": {
        "name_key": "card.dragonpepper_roast.name", "card": "dragonpepper_roast",
        "cost": {"meat": 1, "ember": 1}, "summary_key": "recipe.dragonpepper_roast.summary",
    },
    "leftover_stew": {
        "name_key": "card.leftover_stew.name", "card": "leftover_stew",
        "cost_any": 2, "summary_key": "recipe.leftover_stew.summary",
    },
}

const ENCOUNTERS := {
    "picklemancer": {
        "name_key": "encounter.picklemancer.name", "subtitle_key": "encounter.picklemancer.subtitle", "portrait": "picklemancer",
        "health": 20, "passive_key": "encounter.picklemancer.passive",
        "deck": ["pickle_imp", "pickle_imp", "cursed_onion", "cellar_rat", "pickle_imp", "dough_golem", "cursed_onion", "cellar_rat"],
    },
    "mold_monarch": {
        "name_key": "encounter.mold_monarch.name", "subtitle_key": "encounter.mold_monarch.subtitle", "portrait": "mold_monarch",
        "health": 25, "passive_key": "encounter.mold_monarch.passive",
        "deck": ["moldling", "moldling", "gravy_specter", "dough_golem", "moldling", "cellar_rat", "gravy_specter", "dough_golem"],
    },
    "ember_butcher": {
        "name_key": "encounter.ember_butcher.name", "subtitle_key": "encounter.ember_butcher.subtitle", "portrait": "ember_butcher",
        "health": 24, "passive_key": "encounter.ember_butcher.passive",
        "deck": ["cellar_rat", "meat_mimic", "pickle_imp", "meat_mimic", "cursed_onion", "dough_golem", "meat_mimic", "cellar_rat"],
    },
    "banquet_tyrant": {
        "name_key": "encounter.banquet_tyrant.name", "subtitle_key": "encounter.banquet_tyrant.subtitle", "portrait": "banquet_tyrant",
        "health": 34, "passive_key": "encounter.banquet_tyrant.passive",
        "deck": ["pickle_imp", "moldling", "cellar_rat", "gravy_specter", "dough_golem", "meat_mimic", "cursed_onion", "meat_mimic", "gravy_specter", "dough_golem"],
    },
}

static func card(card_id: String) -> Dictionary:
    return CARDS.get(card_id, {}).duplicate(true)

static func encounter(encounter_id: String) -> Dictionary:
    return ENCOUNTERS.get(encounter_id, {}).duplicate(true)

static func art(art_id: String) -> Texture2D:
    return ART.get(art_id)
