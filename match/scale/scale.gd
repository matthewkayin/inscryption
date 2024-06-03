extends Sprite2D

@onready var rod = $rod
@onready var player_platform = $player_platform
@onready var player_score_label = $player_platform/score
@onready var opponent_platform = $opponent_platform
@onready var opponent_score_label = $opponent_platform/score

const SCORE_LIMIT = 5.0
const PLATFORM_DROP_DISTANCE = 10.0

func _ready():
    pass 

func display_scores(opponent_score, player_score):
    player_score_label.text = str(player_score)
    opponent_score_label.text = str(opponent_score)
    var score = clamp(player_score - opponent_score, -SCORE_LIMIT, SCORE_LIMIT)
    rod.rotation_degrees = 15.0 * (score / SCORE_LIMIT)
    player_platform.position.y = (score / SCORE_LIMIT) * PLATFORM_DROP_DISTANCE
    opponent_platform.position.y = -player_platform.position.y