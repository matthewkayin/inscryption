extends NinePatchRect

@onready var desc = $desc
@onready var timer = $timer

func _ready():
    close()

func open(text: String, duration = -1):
    desc.text = text
    size.x = desc.label_settings.font.get_string_size(text).x + 16
    position.x = 320 - size.x
    visible = true
    if duration != -1:
        timer.start(duration)
        await timer.timeout
        close()

func close():
    visible = false
