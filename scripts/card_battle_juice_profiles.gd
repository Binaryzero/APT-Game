class_name CardBattleJuiceProfiles
extends RefCounted

## Shared presentation language. Gameplay code asks for a semantic kit and tier;
## the director owns the actual tweens, particles, sound, and accessibility cuts.

const MOTION_FULL := "full"
const MOTION_REDUCED := "reduced"
const MOTION_MINIMAL := "minimal"

const TIER_MICRO := "micro"
const TIER_STANDARD := "standard"
const TIER_SIGNATURE := "signature"
const TIER_ENDING := "ending"

const TIERS := {
    TIER_MICRO: {"duration": 0.10, "blocking": 0.0, "flavor_budget": 8},
    TIER_STANDARD: {"duration": 0.34, "blocking": 0.10, "flavor_budget": 20},
    TIER_SIGNATURE: {"duration": 0.82, "blocking": 0.25, "flavor_budget": 36},
    TIER_ENDING: {"duration": 1.65, "blocking": 0.35, "flavor_budget": 52},
}

const KITS := {
    "blade": {"primary": "#8FE8D0", "secondary": "#E7FFF8", "particle": "shard", "sound": "blade"},
    "fire": {"primary": "#F3A33C", "secondary": "#D95757", "particle": "flame", "sound": "fire"},
    "broth": {"primary": "#D9F7E9", "secondary": "#55C6A9", "particle": "steam", "sound": "broth"},
    "armor": {"primary": "#C36D32", "secondary": "#F0C078", "particle": "rivet", "sound": "armor"},
    "meat": {"primary": "#D95757", "secondary": "#F0A080", "particle": "wedge", "sound": "meat"},
    "fungus": {"primary": "#B990FF", "secondary": "#69DCC2", "particle": "spore", "sound": "fungus"},
    "boss": {"primary": "#D95757", "secondary": "#F0C078", "particle": "seal", "sound": "boss"},
}

const LIMITS := {
    "particles": 180,
    "overlays": 8,
    "audio": 12,
    "flavor": 48,
    "history": 5,
}


static func tier(name: String) -> Dictionary:
    return TIERS.get(name, TIERS[TIER_STANDARD]).duplicate(true)


static func kit(name: String) -> Dictionary:
    return KITS.get(name, KITS["blade"]).duplicate(true)


static func duration_scale(mode: String, speed: float = 1.0) -> float:
    var base := 1.0
    if mode == MOTION_REDUCED:
        base = 0.55
    elif mode == MOTION_MINIMAL:
        base = 0.18
    return base / maxf(0.25, speed)


static func particle_scale(mode: String, density: float = 1.0) -> float:
    if mode == MOTION_MINIMAL:
        return 0.0
    if mode == MOTION_REDUCED:
        return density * 0.35
    return density


static func event_kit(kind: String, ingredient: String = "") -> String:
    if not ingredient.is_empty() and ingredient in ["fungus", "meat", "ember"]:
        return "fire" if ingredient == "ember" else ingredient
    if kind in ["precise_cut", "slash"]:
        return "blade"
    if kind in ["heal", "cook"]:
        return "broth"
    if kind in ["armor", "armor_absorb", "hero_power"]:
        return "armor"
    if kind in ["boss_enrage", "victory", "defeat"]:
        return "boss"
    return "blade"
