extends Resource
class_name CardData

enum CostType {
    NONE,
    BLOOD,
    BONE
}

enum Rarity {
    HIDDEN,
    COMMON,
    RARE
}

@export var name: String
@export var portrait: Texture2D
@export var library_portrait: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var cost_type: CostType = CostType.NONE
@export var cost_amount: int = 0
@export var power: int = 0
@export var health: int = 0
@export var ability1: Ability.Name = Ability.Name.NONE
@export var ability2: Ability.Name = Ability.Name.NONE
@export var evolves_into: CardData = null
@export var tail: CardData = null