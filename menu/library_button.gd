extends Sprite2D

@onready var library = get_node("../library")
@onready var sfx_ok = get_node("../sfx/ok")
@onready var sfx_back = get_node("../sfx/back")

var button_rect: Rect2
var is_tweening = false

func _ready():
    var size = Vector2((texture.get_width() / 4.0) * scale.x, texture.get_height() * scale.y)
    button_rect = Rect2(global_position - (size * 0.5), size)

func _process(_delta):
    if is_tweening:
        return
    if library.visible:
        frame_coords.x = 2
    else:
        frame_coords.x = 0

    var mouse_pos = get_viewport().get_mouse_position()
    if button_rect.has_point(mouse_pos):
        if Input.is_action_just_pressed("mouse_button_left"):
            if not library.visible:
                sfx_ok.play()
            else:
                sfx_back.play()

            is_tweening = true

            var tween = get_tree().create_tween()
            tween.tween_property(self, "scale", Vector2(0, 2), 0.125)
            await tween.finished

            if not library.visible:
                library.open()
                frame_coords.x = 2
            else:
                library.close()
                frame_coords.x = 0
            var tween2 = get_tree().create_tween()
            tween2.tween_property(self, "scale", Vector2(2, 2), 0.125)
            await tween2.finished

            is_tweening = false
        else:
            if library.visible:
                frame_coords.x = 3
            else:
                frame_coords.x = 1
