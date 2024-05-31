extends Sprite2D
class_name Card

enum CardName {
    SQUIRREL,
    STOAT,
    BULLFROG
}

enum State {
    NONE,
    ANIMATE_PRESUMMON
}

const LOW_HEALTH_COLOR = Color(0x8e1533ff)
const CARD_SIZE = Vector2(82, 112)
const ABILITY_ICON_SIZE = Vector2(34, 34)

# onready
var portrait 
var cost_sprite 
var power_label 
var health_label
var abilities 
@onready var sacrifice_marker = $sacrifice

# stats
var power: int
var health: int
var data: CardData

# behavior
var state = State.NONE

var previous_position = null
const ANIMATE_PRESUMMON_POSITION_OFFSETS = [
    Vector2(0, -8), 
    Vector2(4, -8), 
    Vector2(8, -6), 
    Vector2(4, -4), 
    Vector2(0, -4), 
    Vector2(-4, -4), 
    Vector2(-8, -6),
    Vector2(-4, -8)
]
var animate_presummon_index = 0

func _ready():
    pass 

func card_init(card_name: CardName):
    # get handles to all card members
    portrait = $portrait
    cost_sprite = $cost
    power_label = $power
    health_label = $health
    abilities = $abilities.get_children()

    # load the card data
    data = load("res://match/data/card/" + CardName.keys()[card_name].to_lower() + ".tres")

    portrait.texture = data.portrait
    power = data.power
    health = data.health

    # Set cost sprite
    if data.cost_type == CardData.CostType.NONE:
        cost_sprite.visible = false
    else:
        cost_sprite.visible = true
        if data.cost_type == CardData.CostType.BLOOD:
            cost_sprite.frame_coords.y = 0
        elif data.cost_type == CardData.CostType.BLOOD:
            cost_sprite.frame_coords.y = 1
        cost_sprite.frame_coords.x = data.cost_amount - 1

    # Set ability sprites
    abilities[0].visible = false
    abilities[1].visible = false
    if data.ability1 != null:
        abilities[0].get_node("icon").texture = data.ability1.icon
        abilities[0].visible = true
    if data.ability2 != null:
        abilities[1].get_node("icon").texture = data.ability2.icon
        abilities[1].visible = true

    card_refresh()

func card_refresh():
    if power != data.power:
        power_label.label_settings.font_color = LOW_HEALTH_COLOR
    else:
        power_label.label_settings.font_color = Color.BLACK
    power_label.text = str(power)

    if health != data.health:
        health_label.label_settings.font_color = LOW_HEALTH_COLOR
    else:
        health_label.label_settings.font_color = Color.BLACK
    health_label.text = str(health)

func has_point(point: Vector2):
    return Rect2(position, CARD_SIZE).has_point(point)

func get_hovered_ability(point: Vector2):
    for i in range(0, 2):
        if not abilities[i].visible:
            continue
        var ability_icon = abilities[0].get_node("icon")
        if Rect2(ability_icon.global_position - (ABILITY_ICON_SIZE * 0.5), ABILITY_ICON_SIZE).has_point(point):
            if i == 0:
                return data.ability1
            if i == 1:
                return data.ability2
    return null

func _process(delta):
    if state == State.ANIMATE_PRESUMMON:
        animate_presummon_process(delta)

func animate_presummon():
    previous_position = position
    var tween = get_tree().create_tween()
    tween.tween_property(self, "position", position + ANIMATE_PRESUMMON_POSITION_OFFSETS[0], 0.25)
    await tween.finished
    state = State.ANIMATE_PRESUMMON
    animate_presummon_index = 0

func animate_presummon_end():
    state = State.NONE

func animate_presummon_process(delta):
    var target_position = previous_position + ANIMATE_PRESUMMON_POSITION_OFFSETS[animate_presummon_index]
    var traveled = 10.0 * delta
    var distance_remaining = position.distance_to(target_position)
    if distance_remaining < traveled:
        position = target_position
        animate_presummon_index = (animate_presummon_index + 1) % ANIMATE_PRESUMMON_POSITION_OFFSETS.size()
        target_position = previous_position + ANIMATE_PRESUMMON_POSITION_OFFSETS[animate_presummon_index]
        traveled -= distance_remaining
    position += traveled * position.direction_to(target_position)

func animate_sacrifice():
    sacrifice_marker.visible = true
    var tween = get_tree().create_tween()
    tween.tween_interval(0.25)
    tween.tween_property(self, "modulate", Color(modulate.r, modulate.g, modulate.b, 0), 0.25)
    await tween.finished