extends Node

signal client_server_disconnected
signal client_player_list_updated
signal client_opponent_disconnected
signal client_server_rejected_game
signal client_server_accepted_game

var SERVER_VERSION = ""
const VERSION = "0.9.3"
const SERVER_IP = "wss://inscryption.xyz:6767"
# const SERVER_IP = "ws://127.0.0.1:6767"
const PORT = 6767

var peer

var opponent_id = -1
var player = {
    "name":  ""
}
var players = {}
var player_goes_first = false

func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

    multiplayer.connected_to_server.connect(_client_on_connection_ok)
    multiplayer.connection_failed.connect(_client_on_connection_fail)
    multiplayer.server_disconnected.connect(_client_on_server_disconnected)

func _on_peer_connected(_id):
    pass

# SERVER

func server_disconnect():
    if peer.get_conncetion_status() == peer.CONNECTION_CONNECTED:
        peer.close()
    opponent_id = -1
    players = {}
    peer = null
    multiplayer.multiplayer_peer = null

func _on_peer_disconnected(id):
    if multiplayer.is_server():
        print("Client ", id, " disconnected.")
        players.erase(id)
        server_broadcast_player_list()
    else:
        if opponent_id == id:
            client_opponent_disconnected.emit()

func server_broadcast_player_list():
    print("Broadcasting player list...")
    for client_id in players.keys():
        _client_on_server_broadcast_player_list.rpc_id(client_id, players)
    print("Done.")

@rpc("any_peer", "reliable")
func _server_on_client_greeting(client_info):
    if not multiplayer.is_server():
        return
    var new_client_id = multiplayer.get_remote_sender_id()
    print("Received new client: ", new_client_id)
    if client_info.version != SERVER_VERSION:
        # Reject the client
        print("Version mismatch. Client ", new_client_id, " rejected.")
        _client_on_version_rejected.rpc_id(new_client_id)

        # Wait 5 seconds
        var tween = get_tree().create_tween()
        tween.tween_interval(5.0)
        await tween.finished

        # If they are still connected, kick them
        peer.disconnect_peer(new_client_id)
        return
    players[new_client_id] = {
        "name": client_info.name,
        "in_game": false
    }
    server_broadcast_player_list()

@rpc("any_peer", "reliable")
func _server_on_client_accepted_match(challenger):
    if not multiplayer.is_server():
        return
    var challengee = multiplayer.get_remote_sender_id()
    if players[challengee].in_game or players[challenger].in_game:
        _client_on_server_rejected_game.rpc_id(challengee)
        return
    var challenger_goes_first = bool(randi_range(0, 1))
    _client_on_server_accepted_game.rpc_id(challenger, challengee, challenger_goes_first)
    _client_on_server_accepted_game.rpc_id(challengee, challenger, not challenger_goes_first)

    players[challengee].in_game = true
    players[challenger].in_game = true
    server_broadcast_player_list()

@rpc("any_peer", "reliable")
func _on_client_return_to_lobby():
    players[multiplayer.get_remote_sender_id()].in_game = false
    server_broadcast_player_list()

func server_config_get_key(server_config, key) -> String:
    if not server_config.keys().has(key):
        print("Server config is missing key ", key)
        get_tree().quit()
    
    return server_config[key]

func server_create():
    var server_config_file = FileAccess.open("./server.cfg", FileAccess.READ)
    if not server_config_file.is_open():
        print("Could not open server config.")
        get_tree().quit()

    var server_config = {}
    while server_config_file.get_position() < server_config_file.get_length():
        var next_line = server_config_file.get_line()
        var key_value = next_line.split("=")
        if key_value.size() != 2:
            print("Server config not invalid.")
            get_tree().quit()

        server_config[key_value[0]] = key_value[1]

    SERVER_VERSION = server_config_get_key(server_config, "version")
    var server_cas = load(server_config_get_key(server_config, "cas"))
    var server_key = load(server_config_get_key(server_config, "privkey"))
    var server_tls = TLSOptions.server(server_key, server_cas)
    peer = WebSocketMultiplayerPeer.new()
    peer.create_server(PORT, "*", server_tls)
    multiplayer.multiplayer_peer = peer
    print("Started Inscryption server v" + SERVER_VERSION)

# CLIENT

func client_has_opponent():
    return opponent_id != -1

func client_is_connected():
    return peer != null

func client_connect():
    peer = WebSocketMultiplayerPeer.new()
    var error = peer.create_client(SERVER_IP)
    if error:
        client_disconnect()
        return false
    multiplayer.multiplayer_peer = peer
    return true

func client_disconnect(message: String = ""):
    if peer.get_connection_status() == peer.CONNECTION_CONNECTED:
        peer.disconnect_peer(1)
    opponent_id = -1
    players = {}
    peer = null
    multiplayer.multiplayer_peer = null
    client_server_disconnected.emit(message)

func _client_on_connection_ok():
    _server_on_client_greeting.rpc_id(1, {
        "name": player.name,
        "version": VERSION
    })

func _client_on_connection_fail():
    client_disconnect("Failed to connect to server.")

func _client_on_version_rejected():
    client_disconnect("Client version is out of date.")

func _client_on_server_disconnected():
    client_disconnect("Server disconnected.")

@rpc("authority", "reliable")
func _client_on_server_broadcast_player_list(player_list):
    players = player_list
    client_player_list_updated.emit()

@rpc("authority", "reliable")
func _client_on_server_rejected_game():
    client_server_rejected_game.emit()

@rpc("authority", "reliable")
func _client_on_server_accepted_game(game_opponent_id, game_player_goes_first):
    player_goes_first = game_player_goes_first
    opponent_id = game_opponent_id
    client_server_accepted_game.emit()