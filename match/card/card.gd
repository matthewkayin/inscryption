extends Sprite2D
class_name Card

var portrait 
var cost_sprite 
var power_label 
var health_label
var abilities 

var power: int
var health: int
var data: CardData

enum CardName {
    SQUIRREL,
    STOAT
}

const LOW_HEALTH_COLOR = Color(0x8e1533ff)

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
