extends Sprite2D

@onready var director = get_node("/root/Director")

@onready var library = get_node("../library")
@onready var decklist = get_node("../decklist")
@onready var sfx_ok = get_node("../sfx/ok")
@onready var sfx_back = get_node("../sfx/back")

var button_rect: Rect2
var is_tweening = false

func _ready():
    var size = Vector2((texture.get_width() / 4.0) * scale.x, texture.get_height() * scale.y)
    button_rect = Rect2(global_position - (size * 0.5), size)
    decklist.edit_deck_pressed.connect(_on_edit_deck_pressed)

func _on_edit_deck_pressed():
    library.open(decklist.edit_deck_index)

func _process(_delta):
    if is_tweening:
        return

    var is_disabled = decklist.visible and not director.is_player_deck_valid()

    if decklist.visible or library.visible:
        if is_disabled:
            frame_coords.x = 4
        else:
            frame_coords.x = 2
    else:
        frame_coords.x = 0

    var mouse_pos = get_viewport().get_mouse_position()
    if button_rect.has_point(mouse_pos) and not is_disabled:
        if Input.is_action_just_pressed("mouse_button_left"):
            if decklist.visible or library.visible:
                sfx_back.play()
            else:
                sfx_ok.play()

            is_tweening = true

            var tween = get_tree().create_tween()
            tween.tween_property(self, "scale", Vector2(0, 2), 0.125)
            await tween.finished

            if library.visible:
                library.close()
                frame_coords.x = 0
                decklist.open()
            elif decklist.visible:
                director.save_decks()
                decklist.close()
                frame_coords.x = 0
            else:
                decklist.open()
                frame_coords.x = 2

            var tween2 = get_tree().create_tween()
            tween2.tween_property(self, "scale", Vector2(2, 2), 0.125)
            await tween2.finished

            is_tweening = false
        else:
            if library.visible or decklist.visible:
                frame_coords.x = 3
            else:
                frame_coords.x = 1
