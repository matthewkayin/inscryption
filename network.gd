extends Node

const PORT = 6767

var peer

var opponent_peer_id
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

func _on_peer_connected(id):
    opponent_peer_id = id
    print("my name: ", player.name, " and someone connected: ", opponent_peer_id)
    _on_opponent_greeting.rpc_id(opponent_peer_id, player)

func _on_peer_disconnected(_id):
    print("client disconnected ")

@rpc("any_peer", "reliable")
func _on_opponent_greeting(opponent_info):
    opponent = opponent_info
    print("me: ", player.name, " opponent peer id ", opponent_peer_id)
    print("me: ", player.name, " opponent info ", opponent)

# SERVER

func server_disconnect():
    multiplayer.multiplayer_peer = null

func server_create():
    peer = ENetMultiplayerPeer.new()
    peer.create_server(PORT, 1)
    multiplayer.multiplayer_peer = peer

# CLIENT

func client_disconnect():
    multiplayer.multiplayer_peer = null

func client_connect(ip_addr: String):
    peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(ip_addr, PORT)
    if error:
        client_disconnect()
        return false
    multiplayer.multiplayer_peer = peer
    return true

func _client_on_connection_ok():
    print("connected to server")

func _client_on_connection_fail():
    print("failed to connect to server")
    client_disconnect()

func _client_on_server_disconnected():
    print("server disconnected")
    client_disconnect()
