extends Node

@onready var match_scene = preload("res://match/match.tscn")
@onready var menu_scene = preload("res://menu/menu.tscn")

func _ready():
    pass 

func start_match():
    var menu_instance = get_node("/root/menu")
    var match_instance = match_scene.instantiate()
    var root = get_parent()
    root.remove_child(menu_instance)
    root.add_child(match_instance)