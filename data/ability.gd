extends Resource
class_name Ability

enum Name {
    NONE,
    BONE_KING,
    MIGHTY_LEAP,
    AIRBORNE,
    EVOLVE,
    GUARDIAN,
    LEADER,
    MANY_LIVES,
    WORTHY_SACRIFICE,
    SPRINTER,
    HEFTY,
    TWIN_STRIKE,
    TRIPLET_STRIKE,
    DEATHTOUCH,
    BEES_WITHIN,
    SHARP,
    ANT_SPAWNER,
    RABBIT_HOLE,
    COLONY,
    UNKILLABLE,
    ETERNAL,
    CORPSE_EATER,
    LOOSE_TAIL,
    SUBMERGE,
    FECUNDITY,
    BURROWER
}

const DESC = {
    Name.NONE: "",
    Name.BONE_KING: "When this card dies, 4 bones are \nawarded instead of 1.",
    Name.MIGHTY_LEAP: "This card blocks opposing Airborne \ncreatures.",
    Name.AIRBORNE: "This card ignores opposing creatures\nand attacks an opponent directly.",
    Name.EVOLVE: "After surviving for 1 turn, this card\ngrows into a stronger form.",
    Name.GUARDIAN: "When an opposing card is played, this\ncard moves into the opposite space.",
    Name.LEADER: "Creatures adjacent to this card\ngain 1 power.",
    Name.MANY_LIVES: "When this card is sacrificed,\nit does not perish.",
    Name.WORTHY_SACRIFICE: "This card counts as 3 Blood rather\nthan 1 Blood when sacrificed.",
    Name.SPRINTER: "After owner's turn, this\ncard moves in the sigil's direction.",
    Name.HEFTY: "After owner's turn, this and adjacent\ncards move in the sigil's direction.",
    Name.TWIN_STRIKE: "This card attacks opposing spaces to\nthe left and right of it.",
    Name.TRIPLET_STRIKE: "This card attacks opposing spaces to\nthe left, right, and opposite of it.",
    Name.DEATHTOUCH: "This card instantly kills any card\nit damages.",
    Name.BEES_WITHIN: "When this card is struck, a Bee is\ncreated in the owner's hand.",
    Name.SHARP: "When this card is struck, the attacker\nis dealt 1 damage.",
    Name.ANT_SPAWNER: "When this card is played, an Ant is\ncreated in the owner's hand.",
    Name.RABBIT_HOLE: "When this card is played, a Rabbit is\ncreated in the owner's hand.",
    Name.COLONY: "This card gets 1 power for each ant on\nits side of the board (including itself).",
    Name.UNKILLABLE: "When this card dies, a copy of it is\ncreated in its owner's hand.",
    Name.ETERNAL: "When this card dies, a +1/+1 copy of it\nis created in its owner's hand.",
    Name.CORPSE_EATER: "When a card you own dies by combat,\nthis card is played in its place.",
    Name.LOOSE_TAIL: "When this card would be struck, it\ndrops its' tail and moves to the side.",
    Name.SUBMERGE: "This card avoids attacks. Attacks aimed\nat it will strike its owner instead.",
    Name.FECUNDITY: "When this card is played, a copy of it is\ncreated in its owner's hand.",
    Name.BURROWER: "When an opposing card attacks, this\ncard moves to block it."
}

static func name_str(ability_name: Name) -> String:
    return Name.keys()[ability_name].capitalize()

static func load_icon(ability_name: Name) -> Texture2D:
    if ability_name == Name.NONE:
        return null
    return load("res://match/ability/pixelability_" + Name.keys()[ability_name].to_lower() + ".png")