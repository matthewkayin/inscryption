extends Resource
class_name CardData

enum CostType {
    NONE,
    BLOOD,
    BONE
}

@export var portrait: Texture2D
@export var cost_type: CostType = CostType.NONE
@export var cost_amount: int = 0
@export var power: int = 0
@export var health: int = 0
@export var ability1: Ability.AbilityName = Ability.AbilityName.NONE
@export var ability2: Ability.AbilityName = Ability.AbilityName.NONE