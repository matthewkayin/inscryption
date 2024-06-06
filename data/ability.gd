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
    BURROWER,
    HOARDER,
    STINKY,
    BONE_THIEF,
    BONE_DIGGER,
    DOUBLE_STRIKE,
    DOUBLE_DEATH,
    HANDY
}

const DESC = {
    Name.NONE: "",
    Name.BONE_KING: "When this card dies, 4 Bones are awarded instead of 1.",
    Name.MIGHTY_LEAP: "This card blocks opposing Airborne creatures.",
    Name.AIRBORNE: "This card ignores opposing creatures and attacks its opponent directly.",
    Name.EVOLVE: "After surviving for 1 turn, this card grows into a stronger form.",
    Name.GUARDIAN: "When an opposing card is played, this card moves into the opposite space.",
    Name.LEADER: "Creatures adjacent to this card gain 1 power.",
    Name.MANY_LIVES: "When this card is sacrificed, it does not perish.",
    Name.WORTHY_SACRIFICE: "This card counts as 3 Blood rather than 1 Blood when sacrificed.",
    Name.SPRINTER: "After its owner's turn, this card moves in the sigil's direction.",
    Name.HEFTY: "After its owner's turn, this card moves and pushes other cards in front of it.",
    Name.TWIN_STRIKE: "This card attacks opposing spaces to the left and right of it.",
    Name.TRIPLET_STRIKE: "This card attacks opposing spaces to the left, right, and opposite of it.",
    Name.DEATHTOUCH: "This card instantly kills any card it damages.",
    Name.BEES_WITHIN: "When this card is struck, a Bee is created in the owner's hand.",
    Name.SHARP: "When this card is struck, the attacker is dealt 1 damage.",
    Name.ANT_SPAWNER: "When this card is played, an Ant is created in the owner's hand.",
    Name.RABBIT_HOLE: "When this card is played, a Rabbit is created in the owner's hand.",
    Name.COLONY: "This card gets 1 power for each ant on its side of the board (including itself).",
    Name.UNKILLABLE: "When this card dies, a copy of it is created in its owner's hand.",
    Name.ETERNAL: "When this card dies, a +1/+1 copy of it is created in its owner's hand.",
    Name.CORPSE_EATER: "When a card you own dies by combat, this card is played in its place.",
    Name.LOOSE_TAIL: "When this card would be struck, it drops its' tail and moves to the side.",
    Name.SUBMERGE: "This card avoids attacks. Attacks aimed at it will strike its owner instead.",
    Name.FECUNDITY: "When this card is played, a copy of it is created in its owner's hand.",
    Name.BURROWER: "When an opposing card attacks, this card moves to block it.",
    Name.HOARDER: "When this card is played, its owner draws a card of choice from their deck.",
    Name.STINKY: "The card opposing this one loses 1 power.",
    Name.BONE_THIEF: "When an opposing creature dies, this card's owner takes the bones.",
    Name.BONE_DIGGER: "After the opponent's turn, this card grants its owner 1 bone.",
    Name.DOUBLE_STRIKE: "This card attacks twice.",
    Name.DOUBLE_DEATH: "This card makes its owner's cards die twice.",
    Name.HANDY: "When this card is played, its owner discards their hand then draws 4 cards."
}

static func name_str(ability_name: Name) -> String:
    return Name.keys()[ability_name].capitalize()

static func load_icon(ability_name: Name) -> Texture2D:
    if ability_name == Name.NONE:
        return null
    return load("res://match/ability/pixelability_" + Name.keys()[ability_name].to_lower() + ".png")