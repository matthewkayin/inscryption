extends Node

@onready var match_scene = preload("res://match/match.tscn")
@onready var menu_scene = preload("res://menu/menu.tscn")

enum CursorType {
    POINTER,
    HAND
}

var mouse_cursors = {}

func _ready():
    # init cursors
    for i in range(0, CursorType.keys().size()):
        mouse_cursors[i] = load("res://ui/cursor/" + CursorType.keys()[i] + ".png")
    set_cursor(CursorType.POINTER)

func set_cursor(cursor_type: CursorType):
    Input.set_custom_mouse_cursor(mouse_cursors[int(cursor_type)])

func start_match():
    var menu_instance = get_node("/root/menu")
    var match_instance = match_scene.instantiate()
    var root = get_parent()
    root.remove_child(menu_instance)
    root.add_child(match_instance)