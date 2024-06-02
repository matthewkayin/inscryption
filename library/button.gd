extends Sprite2D

signal pressed

var button_rect: Rect2

func _ready():
    var size = Vector2(int(texture.get_width() / 3.0) * scale.x, texture.get_height() * scale.y)
    button_rect = Rect2(global_position - (size * 0.5), size)

func _process(_delta):
    var mouse_pos = get_viewport().get_mouse_position()
    if button_rect.has_point(mouse_pos):
        if Input.is_action_just_pressed("mouse_button_left"):
            pressed.emit()
            frame_coords.x = 2
        else:
            frame_coords.x = 1
    else:
        frame_coords.x = 0