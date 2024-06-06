extends Sprite2D

@onready var rod = $rod
@onready var player_platform = $player_platform
@onready var player_score_label = $player_platform/score
@onready var opponent_platform = $opponent_platform
@onready var opponent_score_label = $opponent_platform/score
@onready var cursor = $ticker/cursor

const SCORE_LIMIT = 5.0
const PLATFORM_DROP_DISTANCE = 10.0
const TICKER_DISTANCE = 45.0

func _ready():
    pass 

func display_scores(opponent_score, player_score):
    player_score_label.text = str(player_score)
    opponent_score_label.text = str(opponent_score)
    var score = clamp(player_score - opponent_score, -SCORE_LIMIT, SCORE_LIMIT)
    var score_percent: float = score / SCORE_LIMIT
    rod.rotation_degrees = 15.0 * score_percent
    player_platform.position.y = score_percent * PLATFORM_DROP_DISTANCE
    opponent_platform.position.y = -player_platform.position.y
    cursor.position.x = TICKER_DISTANCE * score_percent