extends Node

signal server_client_connected
signal server_client_disconnected
signal client_server_disconnected

const PORT = 6767

var peer

var opponent_id = -1
var player = {
    "name":  ""
}
var opponent = {
    "name": ""
}

func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

    multiplayer.connected_to_server.connect(_client_on_connection_ok)
    multiplayer.connection_failed.connect(_client_on_connection_fail)
    multiplayer.server_disconnected.connect(_client_on_server_disconnected)

func network_is_connected():
    return opponent_id != -1

func network_disconnect():
    if opponent_id != -1:
        if multiplayer.is_server():
            multiplayer.multiplayer_peer.close()
        else:
            multiplayer.disconnect_peer(opponent_id)
    peer = null
    multiplayer.multiplayer_peer = null
    opponent_id = -1
    opponent = {
        "name": ""
    }

func _on_peer_connected(id):
    opponent_id = id
    _on_opponent_greeting.rpc_id(opponent_id, player)

func _on_peer_disconnected(_id):
    if multiplayer.is_server():
        opponent_id = -1
        opponent = {
            "name": ""
        }
        server_client_disconnected.emit()

@rpc("any_peer", "reliable")
func _on_opponent_greeting(opponent_info):
    opponent = opponent_info
    if multiplayer.is_server():
        server_client_connected.emit()

# SERVER

func server_create():
    peer = ENetMultiplayerPeer.new()
    peer.create_server(PORT, 1)
    multiplayer.multiplayer_peer = peer

# CLIENT

func client_connect(ip_addr: String):
    peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(ip_addr, PORT)
    if error:
        network_disconnect()
        return false
    multiplayer.multiplayer_peer = peer
    return true

func _client_on_connection_ok():
    pass

func _client_on_connection_fail():
    network_disconnect()

func _client_on_server_disconnected():
    opponent_id = -1
    opponent = {
        "name": ""
    }
    client_server_disconnected.emit()