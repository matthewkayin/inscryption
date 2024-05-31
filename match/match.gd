extends Node2D

@onready var director = get_node("/root/Director")

@onready var card_scene = preload("res://match/card/card.tscn")

@onready var score_scale = $scale
@onready var card_hover = $card_hover

const CARD_SIZE = Vector2(82, 112)

var player_hand = []
var accept_input = false

func _ready():
    for i in range(0, 2):
        await hand_add_card(Card.CardName.SQUIRREL)
    for i in range(0, 2):
        await hand_add_card(Card.CardName.STOAT)

func hand_update_positions():
    const HAND_CENTER = Vector2(279, 351)
    const HAND_CARD_PADDING = 16
    const HAND_UPDATE_DURATION = 0.5

    if player_hand.size() == 0:
        return
    var tween = get_tree().create_tween()
    if player_hand.size() == 1:
        tween.parallel().tween_property(player_hand[0], "position", HAND_CENTER, HAND_UPDATE_DURATION)
    else:
        var hand_area_size = (player_hand.size() * CARD_SIZE.x) + ((player_hand.size() - 1) * HAND_CARD_PADDING)
        var hand_area_start = 320 - int(hand_area_size / 2.0)
        for i in range(0, player_hand.size()):
            var card_x = hand_area_start + (i * (CARD_SIZE.x + HAND_CARD_PADDING))
            tween.parallel().tween_property(player_hand[i], "position", Vector2(card_x, HAND_CENTER.y), HAND_UPDATE_DURATION)
    await tween.finished

func hand_add_card(card_name: Card.CardName):
    const CARD_SPAWN_POS = Vector2(640, 351)

    var card_instance = card_scene.instantiate()
    card_instance.card_init(card_name)
    add_child(card_instance)
    card_instance.position = CARD_SPAWN_POS
    player_hand.append(card_instance)

    await hand_update_positions()

func _process(_delta):
    var mouse_pos = get_viewport().get_mouse_position()
    var card_hovering = false
    for card in player_hand:
        # check if mouse is hovering over card
        if not Rect2(card.position, CARD_SIZE).has_point(mouse_pos):
            continue
        # make sure that card hover is not already open on this card
        if card_hover.visible && card_hover.position == card.position - Vector2(4, 4):
            card_hovering = true
            continue
        card_hover.open(card.position - Vector2(4, 4))
        card_hovering = true
    if not card_hovering and card_hover.visible:
        card_hover.close()