extends Resource
class_name Ability

enum Name {
    NONE,
    BONE_KING,
    MIGHTY_LEAP,
    AIRBORNE,
    EVOLVE,
    GUARDIAN,
    LEADER
}

const DESC = {
    Name.NONE: "",
    Name.BONE_KING: "When this card dies, 4 bones are \nawarded instead of 1.",
    Name.MIGHTY_LEAP: "This card blocks opposing Airborne \ncreatures.",
    Name.AIRBORNE: "This card ignores opposing creatures\nand attacks an opponent directly.",
    Name.EVOLVE: "After surviving for 1 turn, this card\ngrows into a stronger form.",
    Name.GUARDIAN: "When an opposing card is played, this\ncard moves into the opposite space.",
    Name.LEADER: "Creatures adjacent to this card\ngain 1 power."
}

static func name_str(ability_name: Name) -> String:
    return Name.keys()[ability_name].capitalize()

static func load_icon(ability_name: Name) -> Texture2D:
    if ability_name == Name.NONE:
        return null
    return load("res://match/ability/pixelability_" + Name.keys()[ability_name].to_lower() + ".png")