extends Node2D

@onready var network = get_node("/root/Network")
@onready var director = get_node("/root/Director")

@onready var main_cluster = $main_cluster
@onready var name_edit = $main_cluster/name/edit
@onready var warn_label = $main_cluster/warn
@onready var warn_label_timer = $main_cluster/warn/hide_timer
@onready var host_button = $main_cluster/host_button
@onready var join_button = $main_cluster/join_button

@onready var host_cluster = $host_cluster
@onready var host_status = $host_cluster/status
@onready var host_back_button = $host_cluster/back_button
@onready var host_yes_button = $host_cluster/yes_button
@onready var host_no_button = $host_cluster/no_button

@onready var join_cluster = $join_cluster
@onready var ip_label = $join_cluster/ip
@onready var ip_edit = $join_cluster/ip/edit
@onready var join_warn_label = $join_cluster/warn
@onready var join_warn_label_timer = $join_cluster/warn/hide_timer
@onready var join_back_button = $join_cluster/back_button
@onready var join_connect_button = $join_cluster/connect_button
@onready var join_connect_status = $join_cluster/status
@onready var join_connect_back_button = $join_cluster/connect_back_button

@onready var lobby_cluster = $lobby_cluster
@onready var lobby_start_button = $lobby_cluster/start_button
@onready var lobby_back_button = $lobby_cluster/back_button
@onready var lobby_status = $lobby_cluster/status

var local_ip: String
var client_ready = false

func _ready():
    if OS.has_feature("windows") and OS.has_environment("COMPUTERNAME"):
        local_ip = IP.resolve_hostname(str(OS.get_environment("COMPUTERNAME")), IP.TYPE_IPV4)
    if (OS.has_feature("x11") or OS.has_feature("OSX")) and OS.has_environment("HOSTNAME"):
        local_ip = IP.resolve_hostname(str(OS.get_environment("HOSTNAME")), IP.TYPE_IPV4)

    # Main cluster
    host_button.pressed.connect(_on_host_button_pressed)
    join_button.pressed.connect(_on_join_button_pressed)
    warn_label_timer.timeout.connect(_on_warn_label_timer_timeout)

    # Host cluster
    host_back_button.pressed.connect(_on_host_back_button_pressed)
    host_yes_button.pressed.connect(_on_host_yes_button_pressed)
    host_no_button.pressed.connect(_on_host_no_button_pressed)

    # Join cluster
    join_back_button.pressed.connect(_on_join_back_button_pressed)
    join_connect_button.pressed.connect(_on_join_connect_button_pressed)
    join_warn_label_timer.timeout.connect(_on_join_warn_timer_timeout)
    join_connect_back_button.pressed.connect(_on_join_connect_back_button_pressed)

    # Lobby cluster
    lobby_start_button.pressed.connect(_on_lobby_start_button_pressed)
    lobby_back_button.pressed.connect(_on_lobby_back_button_pressed)

    network.server_client_connected.connect(_on_client_connected)
    network.server_client_disconnected.connect(_on_client_disconnected)
    network.client_server_disconnected.connect(_on_server_disconnected)

    open_main_cluster()

# NETWORK ROUTING FUNCTIONS

func _on_client_connected():
    if host_cluster.visible:
        _host_on_client_connected()

func _on_client_disconnected():
    if host_cluster.visible:
        _host_on_client_disconnected()
    if lobby_cluster.visible:
        _lobby_on_client_disconnected()

func _on_server_disconnected():
    if lobby_cluster.visible:
        _lobby_on_server_disconnected()

# MAIN CLUSTER

func update_username():
    network.player.name = name_edit.text

func open_main_cluster():
    main_cluster.visible = true
    host_cluster.visible = false
    join_cluster.visible = false
    lobby_cluster.visible = false

func _on_warn_label_timer_timeout():
    warn_label.visible = false

func main_show_warning(text):
    warn_label.text = text
    warn_label.visible = true
    warn_label_timer.start(1.0)

func _on_host_button_pressed():
    if not main_cluster.visible:
        return
    if name_edit.text == "":
        main_show_warning("Please enter a name.")
        return
    update_username()
    network.server_create()
    open_host_cluster()

func _on_join_button_pressed():
    if not main_cluster.visible:
        return
    if name_edit.text == "":
        main_show_warning("Please enter a name.")
        return
    update_username()
    open_join_cluster()

# HOST CLUSTER

func _on_host_back_button_pressed():
    if not visible:
        return
    network.network_disconnect()
    open_main_cluster()

func open_host_cluster():
    main_cluster.visible = false
    join_cluster.visible = false
    lobby_cluster.visible = false
    host_status.text = "Your IP is " + local_ip + "\nAwaiting an opponent..."
    host_cluster.visible = true
    host_back_button.visible = true
    host_yes_button.visible = false
    host_no_button.visible = false

func _host_on_client_connected():
    host_status.text = network.opponent.name + " has challenged you.\nAccept?"
    host_back_button.visible = false
    host_yes_button.visible = true
    host_no_button.visible = true

func _host_on_client_disconnected():
    open_host_cluster()

func _on_host_yes_button_pressed():
    _on_host_accept_reject_joiner.rpc_id(network.opponent_id, true)
    open_lobby_cluster()

func _on_host_no_button_pressed():
    _on_host_accept_reject_joiner.rpc_id(network.opponent_id, false)

# JOIN CLUSTER

func _on_join_warn_timer_timeout():
    join_warn_label.visible = false

func show_join_warning(text):
    join_warn_label.text = text 
    join_warn_label.visible = true
    join_warn_label_timer.start(1.0)

func open_join_cluster():
    main_cluster.visible = false
    host_cluster.visible = false
    lobby_cluster.visible = false

    join_connect_status.visible = false
    join_connect_back_button.visible = false

    join_connect_button.visible = true
    join_back_button.visible = true
    ip_label.visible = true
    join_cluster.visible = true

func _on_join_back_button_pressed():
    if not join_back_button.visible:
        return 
    network.network_disconnect()
    open_main_cluster()

func _on_join_connect_back_button_pressed():
    if not join_connect_back_button.visible:
        return 
    network.network_disconnect()
    open_join_cluster()

func _on_join_connect_button_pressed():
    if not join_connect_button.visible:
        return
    if not ip_edit.text.is_valid_ip_address():
        show_join_warning("Invalid IP address.")
        return
    var success = network.client_connect(ip_edit.text)
    if not success:
        show_join_warning("Connection failed.")
        return

    ip_label.visible = false
    join_connect_button.visible = false
    join_back_button.visible = false

    join_connect_status.text = "Connecting..."
    join_connect_status.visible = true
    join_connect_back_button.visible = true

@rpc("authority", "reliable")
func _on_host_accept_reject_joiner(accepted):
    if accepted:
        open_lobby_cluster()
    else:
        var opponent_name = network.opponent.name
        network.network_disconnect()
        open_join_cluster()
        show_join_warning(opponent_name + " denied your challenge.")

# LOBBY

func open_lobby_cluster():
    main_cluster.visible = false
    host_cluster.visible = false
    join_cluster.visible = false
    lobby_cluster.visible = true

    client_ready = false
    lobby_start_button.text = "START" if multiplayer.is_server() else "READY"
    lobby_update_status()
    
func lobby_update_status():
    lobby_status.text = "You are in a lobby.\n"
    if multiplayer.is_server():
        lobby_status.text += network.player.name + ": HOST\n"
        lobby_status.text += network.opponent.name + ": " + ("READY" if client_ready else "NOT READY")
    else:
        lobby_status.text += network.opponent.name + ": HOST\n"
        lobby_status.text += network.player.name + ": " + ("READY" if client_ready else "NOT READY")

@rpc("any_peer", "reliable")
func _on_client_ready(value):
    client_ready = value
    lobby_update_status()

func _lobby_on_client_disconnected():
    network.network_disconnect()
    open_main_cluster()
    main_show_warning("Your opponent left the lobby.")

func _lobby_on_server_disconnected():
    network.network_disconnect()
    open_main_cluster()
    main_show_warning("Your opponent left the lobby.")

func _on_lobby_start_button_pressed():
    if multiplayer.is_server():
        if not client_ready:
            return
        start_match.rpc_id(network.opponent_id)
        director.start_match()
    else:
        client_ready = not client_ready
        _on_client_ready.rpc_id(network.opponent_id, client_ready)
        lobby_update_status()

func _on_lobby_back_button_pressed():
    network.network_disconnect()
    open_main_cluster()

@rpc("authority", "reliable")
func start_match():
    director.start_match()