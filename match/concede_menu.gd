extends Node2D
class_name ConcedeMenu

signal player_conceded

@onready var concede_button = $concede
@onready var continue_button = $continue

const BUTTON_SIZE = Vector2(84, 112)
@onready var CONCEDE_RECT = Rect2(concede_button.position - (BUTTON_SIZE / 2.0), BUTTON_SIZE)
@onready var CONTINUE_RECT = Rect2(continue_button.position - (BUTTON_SIZE / 2.0), BUTTON_SIZE)

func _ready():
    close()

func open():
    visible = true

func close():
    visible = false

func _process(_delta):
    if not visible:
        return

    var mouse_pos = get_viewport().get_mouse_position()
    concede_button.frame_coords.x = int(CONCEDE_RECT.has_point(mouse_pos))
    continue_button.frame_coords.x = int(CONTINUE_RECT.has_point(mouse_pos))
    if Input.is_action_just_pressed("mouse_button_left"):
        if concede_button.frame_coords.x == 1:
            close()
            player_conceded.emit()
        elif continue_button.frame_coords.x == 1:
            close()