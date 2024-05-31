extends Node2D

var sprites = []

func _ready():
    for child in get_children():
        if not child.visible:
            continue
        sprites.append(child)
        child.play("default")

func candles_left():
    var candles_lit = 0
    for sprite in sprites:
        if sprite.animation == "default":
            candles_lit += 1
    return candles_lit

func snuff_candle():
    for i in range(sprites.size() - 1, -1, -1):
        if sprites[i].animation == "snuffed":
            continue
        sprites[i].play("snuff")
        await sprites[i].animation_finished
        sprites[i].play("snuffed")
        return
