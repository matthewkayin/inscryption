extends Node2D

@onready var network = get_node("/root/Network")
@onready var director = get_node("/root/Director")

@onready var main_cluster = $main_cluster
@onready var name_edit = $main_cluster/name/edit
@onready var status = $main_cluster/status
@onready var warn_label_timer = $main_cluster/status/hide_timer
@onready var join_button = $main_cluster/join_button
@onready var version = $version

@onready var sfx_ok = $sfx/ok
@onready var sfx_back = $sfx/back

var local_ip: String
var client_ready = false
var enter_in_lobby = false

func _ready():
    # Server setup
    if DisplayServer.get_name() == "headless":
        network.server_create()
        return

    version.text = "Version " + network.VERSION

    # Main cluster
    join_button.pressed.connect(_on_join_button_pressed)
    warn_label_timer.timeout.connect(_on_warn_timeout)
    hide_status()

    network.client_player_list_updated.connect(_on_client_player_list_updated)
    network.client_server_disconnected.connect(_on_server_disconnected)

# NETWORK 

func _on_client_player_list_updated():
    director.set_scene(director.Scene.LOBBY)

func _on_server_disconnected(message: String):
    show_status(message, 1.0)
    join_button.disabled = false

# MAIN CLUSTER

func update_username():
    network.player.name = name_edit.text

func show_status(text, duration = 0.0):
    status.text = text
    status.visible = true
    if duration != 0.0:
        warn_label_timer.start(duration)

func _on_warn_timeout():
    hide_status()

func hide_status():
    status.visible = false
    warn_label_timer.stop()

func _on_join_button_pressed():
    sfx_ok.play()
    if name_edit.text == "":
        show_status("Please enter a name.", 1.0)
        return
    update_username()
    network.client_connect()
    join_button.disabled = true
    show_status("Connecting...")