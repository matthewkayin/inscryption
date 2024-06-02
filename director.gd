extends Node

@onready var network = get_node("/root/Network")
@onready var match_scene = preload("res://match/match.tscn")
@onready var menu_scene = preload("res://menu/menu.tscn")

enum CursorType {
    POINTER,
    HAND,
    RULEBOOK,
    KNIFE,
    DROP
}

var current_cursor = null
var mouse_cursors = {}
var menu_instance = null
var match_instance = null
var root

var player_deck = []

func _ready():
    # init cursors
    for i in range(0, CursorType.keys().size()):
        mouse_cursors[i] = load("res://ui/cursor/" + CursorType.keys()[i].to_lower() + ".png")
    set_cursor(CursorType.POINTER)
    root = get_parent()

func set_cursor(cursor_type: CursorType):
    if current_cursor == cursor_type:
        return
    current_cursor = cursor_type
    Input.set_custom_mouse_cursor(mouse_cursors[int(cursor_type)])

func start_match():
    if menu_instance == null:
        menu_instance = get_node("/root/menu")
    match_instance = match_scene.instantiate()
    root.remove_child(menu_instance)
    root.add_child(match_instance)

func end_match():
    if menu_instance == null or not network.network_is_connected():
        menu_instance = menu_scene.instantiate()
    else:
        menu_instance.client_ready = false
        menu_instance.lobby_update_status()
    root.remove_child(match_instance)
    root.add_child(menu_instance)
    match_instance.queue_free()