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
var root

var player_deck = []
var decks = []
var player_equipped_deck = -1

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

    load_decks()

    # init cursors
    for i in range(0, CursorType.keys().size()):
        mouse_cursors[i] = load("res://ui/cursor/" + CursorType.keys()[i].to_lower() + ".png")
    set_cursor(CursorType.POINTER)
    root = get_parent()

func is_player_deck_valid():
    return player_equipped_deck != -1

func load_decks():
    var deck_dir = DirAccess.open("user://decks")
    if deck_dir:
        deck_dir.list_dir_begin()
        var filename = deck_dir.get_next()
        while filename != "":
            var deck_file = FileAccess.open("user://decks/" + filename, FileAccess.READ)
            if not deck_file:
                print("Unable to open user://decks/", filename)
                continue

            var new_deck = {
                "name": "",
                "cards": []
            }

            new_deck.name = deck_file.get_line().split("=")[1]
            var card_strings = deck_file.get_line().split("=")[1].split(",")
            for card_string in card_strings:
                if card_string == "":
                    continue
                new_deck.cards.push_back(int(card_string))
            decks.push_back(new_deck)
            if not is_player_deck_valid() and new_deck.cards.size() == Library.MAX_DECK_SIZE:
                player_equipped_deck = decks.size() - 1

            filename = deck_dir.get_next()

func save_decks():
    if not DirAccess.dir_exists_absolute("user://decks"):
        DirAccess.make_dir_absolute("user://decks")

    var deck_dir = DirAccess.open("user://decks")
    if not deck_dir:
        print("error opening user://decks")
        return
    deck_dir.list_dir_begin()
    var delete_filename = deck_dir.get_next()
    while delete_filename != "":
        deck_dir.remove(delete_filename)
        delete_filename = deck_dir.get_next()

    var already_used_names = {}
    for deck in decks:
        var filename = deck.name.to_lower().replace(" ", "_")
        if already_used_names.keys().has(filename):
            filename += "_" + str(already_used_names[filename])
            already_used_names[filename] += 1
        else:
            already_used_names[filename] = 1
        filename += ".idf"

        var deck_file = FileAccess.open("user://decks/" + filename, FileAccess.WRITE)
        if not deck_file:
            print("Unable to open user://decks/", filename)
            return
        deck_file.store_line("name=" + deck.name)
        var card_line = "cards="
        for card_id_index in range(0, deck.cards.size()):
            card_line += str(deck.cards[card_id_index])
            if card_id_index != deck.cards.size() - 1:
                card_line += ","
        deck_file.store_line(card_line)
        deck_file.close()

func set_cursor(cursor_type: CursorType):
    if current_cursor == cursor_type:
        return
    current_cursor = cursor_type
    Input.set_custom_mouse_cursor(mouse_cursors[int(cursor_type)])

func start_match():
    var menu_instance = get_node_or_null("/root/menu")
    if menu_instance == null:
        print(network.player.name + ": MENU IS NULL")
        return
    var match_instance = match_scene.instantiate()
    root.remove_child(menu_instance)
    root.add_child(match_instance)
    menu_instance.queue_free()

func end_match():
    var match_instance = get_node_or_null("/root/match")
    if match_instance == null:
        print(network.player.name + ": MATCH IS NULL")
        return
    var menu_instance = menu_scene.instantiate()
    root.remove_child(match_instance)
    root.add_child(menu_instance)
    match_instance.queue_free()
