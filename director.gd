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
    const CARD_DATA_BASE_PATH = "res://data/card"

    var card_paths = []
    var card_dir = DirAccess.open(CARD_DATA_BASE_PATH)
    assert(card_dir)
    card_dir.list_dir_begin()
    var filename = card_dir.get_next()
    while filename != "":
        card_paths.push_back(filename)
        filename = card_dir.get_next()

    card_paths.sort()
    for path in card_paths:
        var data = load(CARD_DATA_BASE_PATH + "/" + path)
        Card.DATA.push_back(data)
        if data.name == "Squirrel":
            Card.SQUIRREL = Card.DATA.size() - 1
        if data.name == "The Smoke":
            Card.THE_SMOKE = Card.DATA.size() - 1

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
