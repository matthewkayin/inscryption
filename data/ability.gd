extends Resource
class_name Ability

enum AbilityName {
    NONE,
    BONE_KING,
    MIGHTY_LEAP
}

@export var icon: Texture2D
@export_multiline var description: String

static func load_data(ability_name: AbilityName):
    if ability_name == AbilityName.NONE:
        return null
    return load("res://data/ability/" + AbilityName.keys()[ability_name].to_lower() + ".tres")