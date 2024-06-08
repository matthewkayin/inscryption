extends Node

@onready var network = get_node("/root/Network")

@export var CARD_DATA: Array[CardData] = []
@export var STARTER_DECKS: Array[Deck] = []

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

enum Scene {
    MENU,
    LOBBY,
    MATCH
}

var scenes = {}
var current_scene = Scene.MENU

func _ready():
    while not CARD_DATA.is_empty():
        Card.DATA.push_back(CARD_DATA.pop_front())
        if Card.DATA[Card.DATA.size() - 1].name == "Squirrel":
            Card.SQUIRREL = Card.DATA.size() - 1
        if Card.DATA[Card.DATA.size() - 1].name == "The Smoke":
            Card.THE_SMOKE = Card.DATA.size() - 1

    load_decks()

    # init cursors
    for i in range(0, CursorType.keys().size()):
        mouse_cursors[i] = load("res://ui/cursor/" + CursorType.keys()[i].to_lower() + ".png")
    set_cursor(CursorType.POINTER)
    root = get_parent()

    scenes[Scene.MENU] = load("res://menu/menu.tscn")
    scenes[Scene.LOBBY] = load("res://menu/lobby.tscn")
    scenes[Scene.MATCH] = load("res://match/match.tscn")

func is_player_deck_valid():
    return player_equipped_deck != -1

func load_decks():
    var deck_paths = []

    for starter_deck in STARTER_DECKS:
        var new_deck = {
            "name": starter_deck.name,
            "cards": [],
            "is_starter_deck": true
        }
        for deck_entry in starter_deck.cards:
            for i in range(0, deck_entry.count):
                new_deck.cards.push_back(Card.get_id_from_data(deck_entry.card))
        decks.push_back(new_deck)
    player_equipped_deck = 0

    var deck_dir = DirAccess.open("user://decks")
    if deck_dir:
        deck_dir.list_dir_begin()
        var filename = deck_dir.get_next()
        while filename != "":
            deck_paths.push_back("user://decks/" + filename)
            filename = deck_dir.get_next()

    for deck_path in deck_paths:
        var deck_file = FileAccess.open(deck_path, FileAccess.READ)
        if not deck_file:
            print("Unable to open ", deck_path)
            continue

        var new_deck = {
            "name": "",
            "cards": [],
            "is_starter_deck": false
        }

        new_deck.name = deck_file.get_line().split("=")[1]
        var card_strings = deck_file.get_line().split("=")[1].split(",")
        for card_string in card_strings:
            if card_string == "":
                continue
            new_deck.cards.push_back(int(card_string))
        decks.push_back(new_deck)

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

    for deck_index in range(0, decks.size()):
        var deck = decks[deck_index]
        # Don't save starter decks
        if deck.is_starter_deck:
            continue

        var filename = str(deck_index) + "_" + deck.name.to_lower().replace(" ", "_") + ".idf"

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

func set_scene(to: Scene):
    if network.client_is_connected():
        if current_scene == Scene.MATCH and to == Scene.LOBBY:
            network._on_client_return_to_lobby.rpc_id(1)

    var from: String = Scene.keys()[current_scene].to_lower()
    var old_instance = get_node_or_null("/root/" + from)
    if old_instance == null:
        print(network.player.name + ": scene /root/" + from + " is null")
        return
    var new_instance = scenes[to].instantiate()
    root.remove_child(old_instance)
    root.add_child(new_instance)
    old_instance.queue_free()
    current_scene = to