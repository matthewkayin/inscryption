extends Sprite2D

@onready var timer = $timer

var border_offset = 0

func _ready():
    timer.timeout.connect(_on_timer_timeout)
    close()

func open(open_position = null):
    if open_position != null:
        position = open_position
    visible = true
    border_offset = 0
    material.set_shader_parameter("offset", border_offset)
    timer.start(0.1)

func close():
    visible = false
    timer.stop()

func _on_timer_timeout():
    border_offset = (border_offset + 1) % 4
    material.set_shader_parameter("offset", border_offset)
