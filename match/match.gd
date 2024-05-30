extends Node2D

@onready var score_scale = $scale

func _ready():
    for i in range(0, 10):
        var tween = get_tree().create_tween()
        tween.tween_interval(0.5)
        await tween.finished
        score_scale.display_scores(0, i + 1)
    for i in range(0, 20):
        var tween = get_tree().create_tween()
        tween.tween_interval(0.5)
        await tween.finished
        score_scale.display_scores(i + 1, 10)