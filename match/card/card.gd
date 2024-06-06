extends Sprite2D
class_name Card

static var DATA = []
static var SQUIRREL
static var THE_SMOKE 

const SPRINT_ABILITIES = [Ability.Name.SPRINTER, Ability.Name.HEFTY, Ability.Name.SQUIRREL_SHREDDER, Ability.Name.SKELETON_CREW, Ability.Name.RAMPAGER]

enum State {
    NONE,
    ANIMATE_PRESUMMON
}

enum FlipTo {
    FRONT,
    BACK,
    SUBMERGE
}

const LOW_HEALTH_COLOR = Color(0x8e1533ff)
const CARD_SIZE = Vector2(82, 112)
const ABILITY_ICON_SIZE = Vector2(34, 34)

# onready
@export var card_blank: Texture2D
@export var card_back: Texture2D
@export var card_submerged: Texture2D

var portrait 
var cost_sprite 
var power_label 
var health_label
var abilities 
var ability_icons
@onready var sacrifice_marker = $sacrifice
@onready var dim = $dim

# stats
var base_power: int
var base_health: int
var power: int
var health: int
var data: CardData

# behavior
var card_id: int
var state = State.NONE
var sacrifice_count: int = 0
var use_library_portrait = false
var is_face_down = false
var kill_count: int = 0
var morsel_power: int = 0
var morsel_health: int = 0

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

static func get_id_from_data(card_data: CardData):
    for data_card_id in range(0, DATA.size()):
        if DATA[data_card_id] == card_data:
            return data_card_id
    assert(false, "Card ID for given card data not found.")

func card_init(p_card_id: int, face_down = false):
    # get handles to all card members
    portrait = $portrait
    cost_sprite = $cost
    power_label = $power
    health_label = $health
    abilities = $abilities.get_children()
    ability_icons = [abilities[0].get_node("icon"), abilities[1].get_node("icon")]

    # create copies of label settings
    var shared_label_settings = power_label.label_settings
    power_label.label_settings = LabelSettings.new()
    power_label.label_settings.font = shared_label_settings.font
    power_label.label_settings.font_size = shared_label_settings.font_size
    power_label.label_settings.font_color = shared_label_settings.font_color
    health_label.label_settings = LabelSettings.new()
    health_label.label_settings.font = shared_label_settings.font
    health_label.label_settings.font_size = shared_label_settings.font_size
    health_label.label_settings.font_color = shared_label_settings.font_color

    is_face_down = face_down
    set_card_id(p_card_id)
    card_refresh()

    if is_face_down:
        texture = card_back

func set_card_id(p_card_id: int):
    card_id = p_card_id
    data = DATA[card_id]
    if use_library_portrait and data.library_portrait != null:
        portrait.texture = data.library_portrait
    else:
        portrait.texture = data.portrait 
    base_power = data.power
    power = base_power
    base_health = data.health
    health = base_health

func give_morsel(p_morsel_power, p_morsel_health):
    morsel_power = p_morsel_power
    morsel_health = p_morsel_health
    health += morsel_health

func card_refresh():
    if is_face_down:
        for child in get_children():
            child.visible = false
        return

    # Power
    if power != base_power:
        power_label.label_settings.font_color = LOW_HEALTH_COLOR
    else:
        power_label.label_settings.font_color = Color.BLACK
    power_label.text = str(power)
    power_label.visible = true

    # Health
    if health != base_health:
        health_label.label_settings.font_color = LOW_HEALTH_COLOR
    else:
        health_label.label_settings.font_color = Color.BLACK
    health_label.text = str(health)
    health_label.visible = true

    # Set cost sprite
    if data.cost_type == CardData.CostType.NONE:
        cost_sprite.visible = false
    else:
        cost_sprite.visible = true
        cost_sprite.frame_coords.y = int(data.cost_type) - 1
        cost_sprite.frame_coords.x = data.cost_amount - 1

    # Set ability sprites
    $abilities.visible = true
    abilities[0].visible = false
    abilities[1].visible = false
    if data.ability1 != Ability.Name.NONE:
        ability_icons[0].texture = Ability.load_icon(data.ability1)
        abilities[0].visible = true
    if data.ability2 != Ability.Name.NONE:
        ability_icons[1].texture = Ability.load_icon(data.ability2)
        abilities[1].visible = true

    portrait.visible = true

func has_point(point: Vector2):
    return Rect2(global_position - (CARD_SIZE * 0.5), CARD_SIZE).has_point(point)

func get_hovered_ability(point: Vector2):
    for i in range(0, 2):
        if not abilities[i].visible:
            continue
        if Rect2(ability_icons[i].global_position - (ABILITY_ICON_SIZE * 0.5), ABILITY_ICON_SIZE).has_point(point):
            if i == 0:
                return data.ability1
            if i == 1:
                return data.ability2
    return Ability.Name.NONE

func has_ability(ability_name: Ability.Name):
    return data.ability1 == ability_name or data.ability2 == ability_name

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

func animate_death(is_sacrifice = false):
    var tween = get_tree().create_tween()
    if is_sacrifice:
        sacrifice_marker.visible = true
    tween.tween_interval(0.25)
    tween.tween_property(self, "modulate", Color(modulate.r, modulate.g, modulate.b, 0), 0.1)
    await tween.finished

func card_flip(flip_to: FlipTo):
    var old_position = position

    z_index = 1

    var tween = get_tree().create_tween()
    tween.tween_property(self, "position", position + Vector2(-16, 16), 0.125)
    tween.tween_interval(0.125)
    tween.tween_property(self, "scale", Vector2(0, 1), 0.05)
    await tween.finished

    if flip_to == FlipTo.FRONT:
        texture = card_blank
        is_face_down = false
    elif flip_to == FlipTo.SUBMERGE:
        texture = card_submerged
        is_face_down = true
    else:
        texture = card_back
        is_face_down = true
    card_refresh()

    var tween2 = get_tree().create_tween()
    tween2.tween_property(self, "scale", Vector2(1, 1), 0.05)
    tween2.tween_property(self, "position", old_position, 0.125)
    await tween2.finished

    z_index = 0

func evolve():
    var tween = get_tree().create_tween()
    tween.tween_property(self, "scale", Vector2(0, 1), 0.05)
    await tween.finished

    var damage_taken = base_health - health
    var sprint_direction = get_sprint_direction()
    set_card_id(Card.get_id_from_data(data.evolves_into))
    set_sprint_direction(sprint_direction)
    health -= damage_taken
    card_refresh()

    var tween2 = get_tree().create_tween()
    tween2.tween_property(self, "scale", Vector2(1, 1), 0.05)
    await tween2.finished

func has_sprint_ability():
    return SPRINT_ABILITIES.has(data.ability1) or SPRINT_ABILITIES.has(data.ability2)

func get_sprint_direction():
    if SPRINT_ABILITIES.has(data.ability1):
        return -1 if ability_icons[0].flip_h else 1
    elif SPRINT_ABILITIES.has(data.ability2):
        return -1 if ability_icons[1].flip_h else 1
    else:
        return 1

func set_sprint_direction(direction: int):
    portrait.flip_h = direction == -1
    if SPRINT_ABILITIES.has(data.ability1):
        ability_icons[0].flip_h = direction == -1
    else:
        ability_icons[1].flip_h = direction == -1