extends Node2D

@onready var network = get_node("/root/Network")
@onready var director = get_node("/root/Director")

@onready var decklist = $decklist
@onready var library = $library

@onready var player_labels = $player_list/players.get_children()
var player_selected_bar = []
@onready var back_button = $back_button
@onready var challenge_button = $challenge_button
@onready var status = $status
@onready var status_timer = $status/hide_timer
@onready var challenge_label = $challenge_buttons/status
@onready var yes_no_buttons = $challenge_buttons
@onready var yes_button = $challenge_buttons/yes_button
@onready var no_button = $challenge_buttons/no_button

var selected_player_id = 0
var challenge_queue = []

func _ready():
    for label in player_labels:
        player_selected_bar.push_back(label.get_node("selected"))

    back_button.pressed.connect(_on_back_button_pressed)
    challenge_button.pressed.connect(_on_challenge_pressed)
    no_button.pressed.connect(_on_no_pressed)
    yes_button.pressed.connect(_on_yes_pressed)

    status.visible = false
    yes_no_buttons.visible = false
    yes_button.disabled = true
    no_button.disabled = true
    status_timer.timeout.connect(hide_status)

    network.client_player_list_updated.connect(player_list_update)
    network.client_server_rejected_game.connect(_on_server_rejected_game)
    network.client_server_accepted_game.connect(_on_server_accepted_game)

    challenge_queue.clear()
    player_list_update()

func show_status(message: String, duration = 0.0):
    status.text = message
    status.visible = true
    if duration != 0.0:
        status_timer.start(duration)

func hide_status():
    status.visible = false

func player_list_update():
    for label in player_labels:
        label.visible = false

    var player_ids = network.players.keys()

    var encountered_selected_id = false
    for player_id in player_ids:
        if player_id == selected_player_id:
            encountered_selected_id = true
    if not encountered_selected_id:
        selected_player_id = -1

    for i in range(0, player_ids.size()):
        if i >= player_labels.size():
            break
        player_labels[i].text = network.players[player_ids[i]].name
        if network.players[player_ids[i]].in_game:
            player_labels[i].text += " (In Game)"
        player_labels[i].visible = true
        player_selected_bar[i].visible = selected_player_id == player_ids[i]

func _on_back_button_pressed():
    network.client_disconnect()
    director.set_scene(director.Scene.MENU)

func _on_challenge_pressed():
    if selected_player_id == -1:
        return
    if selected_player_id == network.peer.get_unique_id():
        show_status("You can't challenge yourself!", 1.0)
        return
    if network.players[selected_player_id].in_game:
        show_status("That player is already in a game.", 1.0)
        return
    _on_received_challenge.rpc_id(selected_player_id)

func _on_no_pressed():
    _on_challenge_yes_no.rpc_id(challenge_queue[0], false)
    challenge_queue.pop_front()
    yes_no_buttons.visible = false
    yes_button.disabled = true
    no_button.disabled = true

func _on_yes_pressed():
    _on_challenge_yes_no.rpc_id(challenge_queue[0], true)
    network.opponent_id = challenge_queue[0]
    challenge_queue.clear()
    yes_no_buttons.visible = false
    yes_button.disabled = true
    no_button.disabled = true
    network._server_on_client_accepted_match.rpc_id(1, network.opponent_id)

@rpc("any_peer", "reliable")
func _on_received_challenge():
    var challenger_id = multiplayer.get_remote_sender_id()
    if challenge_queue.has(challenger_id):
        return
    challenge_queue.push_back(challenger_id)

@rpc("any_peer", "reliable")
func _on_challenge_yes_no(accepted: bool):
    if not accepted:
        show_status(network.players[selected_player_id].name + " rejected your challenge.", 1.0)
        return
    network.opponent_id = multiplayer.get_remote_sender_id()
    director.set_scene(director.Scene.MATCH)

func _process(_delta):
    if library.visible or decklist.visible:
        return

    if not yes_no_buttons.visible and not challenge_queue.is_empty():
        var challenger_id = challenge_queue[0]
        challenge_label.text = network.players[challenger_id].name + "\nchallenged you.\nAccept?"
        yes_no_buttons.visible = true
        yes_button.disabled = false
        no_button.disabled = false

    var mouse_pos = get_viewport().get_mouse_position()
    var player_ids = network.players.keys()
    for i in range(0, player_ids.size()):
        if i >= player_labels.size():
            break
        if player_selected_bar[i].get_global_rect().has_point(mouse_pos) and Input.is_action_just_pressed("mouse_button_left"):
            selected_player_id = player_ids[i]
            player_list_update()

func _on_server_rejected_game():
    show_status("Challenger joined another game.", 1.0)

func _on_server_accepted_game():
    director.set_scene(director.Scene.MATCH)