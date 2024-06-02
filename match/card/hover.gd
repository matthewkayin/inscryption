extends AnimatedSprite2D

func _ready():
    close()

func open(open_position = null):
    if open_position != null:
        position = open_position
    play()
    visible = true

func close():
    stop()
    visible = false