extends Node2D

@onready var director = get_node("/root/Director")

@onready var card_scene = preload("res://match/card/card.tscn")

@onready var score_scale = $scale
@onready var card_hover = $card_hover
@onready var rulebook = $rulebook
@onready var rulebook_name_label = $rulebook/name
@onready var rulebook_desc_label = $rulebook/desc
@onready var rulebook_icon = $rulebook/icon
@onready var player_cardslots = $player_cardslots.get_children()
@onready var opponent_cardslots = $opponent_cardslots.get_children()
@onready var bell = $bell
@onready var attack_animation = $attack_animation
@onready var bone_counter_label = $bone_counter/value
@onready var player_candles = $player_candles
@onready var opponent_candles = $opponent_candles
var blood_counter_sprites = []

enum State {
    WAIT,
    PLAYER_DRAW,
    PLAYER_TURN,
    PLAYER_SUMMONING
}

enum BellState {
    READY,
    DISABLED,
    HOVER,
    PRESS
}

enum Turn {
    PLAYER,
    OPPONENT
}

const BELL_SIZE = Vector2(182, 72)
@onready var BELL_RECT = Rect2(bell.position - (BELL_SIZE * 0.5), BELL_SIZE)

var state = State.WAIT
var player_hand = []
var player_board = [null, null, null, null]
var player_score = 0
var player_bone_count = 0
var opponent_board = [null, null, null, null]
var opponent_score = 0

var summoning_card = null
var summoning_cost_met = false
var summoning_blood_count = 0

func _ready():
    for child in $blood_counter.get_children():
        blood_counter_sprites.push_back(child.get_child(0))
    bell.frame_coords.x = int(BellState.DISABLED)
    score_scale.display_scores(0, 0)

    for i in range(0, 4):
        await hand_add_card(Card.CardName.SQUIRREL)
    state = State.PLAYER_TURN

    board_add_card(Turn.PLAYER, 1, Card.CardName.STOAT)
    board_add_card(Turn.OPPONENT, 1, Card.CardName.BULLFROG)

func _process(_delta):
    if state == State.WAIT:
        return
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        state = State.WAIT
        await hand_add_card(Card.CardName.SQUIRREL)
        state = State.PLAYER_TURN
        return
    if rulebook.visible:
        rulebook_process()
        return
    call(State.keys()[state].to_lower() + "_process")

# HAND

func hand_update_positions():
    const HAND_CENTER = Vector2(320, 407)
    const HAND_UPDATE_DURATION = 0.25

    var hand_size = player_hand.size()
    var HAND_CARD_PADDING 
    if hand_size < 6:
        HAND_CARD_PADDING = 98
    elif hand_size == 6:
        HAND_CARD_PADDING = 90
    else:
        const LAST_CARD_POSITION = 532.0 - 82.0
        HAND_CARD_PADDING = LAST_CARD_POSITION / (hand_size - 1)

    if player_hand.size() == 0:
        return
    var tween = get_tree().create_tween()
    if player_hand.size() == 1:
        tween.parallel().tween_property(player_hand[0], "position", HAND_CENTER, HAND_UPDATE_DURATION)
    else: 
        var hand_area_size 
        var hand_area_start 
        if hand_size < 7:
            hand_area_size = (player_hand.size() * HAND_CARD_PADDING) - (HAND_CARD_PADDING - Card.CARD_SIZE.x)
            hand_area_start = 320 - int(hand_area_size / 2.0) + (Card.CARD_SIZE.x / 2.0)
        else:
            hand_area_size = 532.0
            hand_area_start = 95.0
        for i in range(0, player_hand.size()):
            var card_x = hand_area_start + (i * HAND_CARD_PADDING)
            tween.parallel().tween_property(player_hand[i], "position", Vector2(card_x, HAND_CENTER.y), HAND_UPDATE_DURATION)
    await tween.finished

func hand_add_card(card_name: Card.CardName):
    const CARD_SPAWN_POS = Vector2(681, 407)

    var card_instance = card_scene.instantiate()
    card_instance.card_init(card_name)
    add_child(card_instance)
    card_instance.position = CARD_SPAWN_POS
    player_hand.append(card_instance)

    await hand_update_positions()

# UI

func ui_update_blood_counter():
    for i in range(0, 4):
        if summoning_blood_count > i:
            blood_counter_sprites[i].frame_coords.x = 1
        else:
            blood_counter_sprites[i].frame_coords.x = 0

func ui_update_bone_counter():
    bone_counter_label.text = "x" + str(player_bone_count)

# BOARD

func board_add_card(which: Turn, index: int, card_name: Card.CardName):
    var card_instance = card_scene.instantiate()
    card_instance.card_init(card_name)
    add_child(card_instance)
    if which == Turn.PLAYER:
        card_instance.position = player_cardslots[index].global_position
        player_board[index] = card_instance
    else:
        card_instance.position = opponent_cardslots[index].global_position
        opponent_board[index] = card_instance

# PLAYER DRAW

func player_draw_process():
    pass

# PLAYER TURN

func player_turn_process():
    var cursor_type = director.CursorType.POINTER

    var mouse_pos = get_viewport().get_mouse_position()
    var hovered_card = null
    for card in player_hand:
        card.z_index = 0
    for i in range(player_hand.size() - 1, -1, -1):
        var card = player_hand[i]
        if card.has_point(mouse_pos):
            # make sure that card hover is not already open on this card
            hovered_card = card
            if not (card_hover.visible and card_hover.position == card.position): 
                card_hover.open(card.position)
            break

    if hovered_card != null:
        hovered_card.z_index = 1
    if hovered_card == null and card_hover.visible:
        card_hover.close()

    # Check if we're hovering over a sigil
    var hovered_ability = null
    if hovered_card != null:
        hovered_ability = hovered_card.get_hovered_ability(mouse_pos)
    else:
        # Check sigil hover on player board
        for i in range(0, player_cardslots.size()):
            var cardslot = player_cardslots[i]
            if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos) and player_board[i] != null:
                hovered_ability = player_board[i].get_hovered_ability(mouse_pos)
                break
        if hovered_ability == null:
            # Check sigil hover on opponent board
            for i in range(0, opponent_cardslots.size()):
                var cardslot = opponent_cardslots[i]
                if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos) and opponent_board[i] != null:
                    hovered_ability = opponent_board[i].get_hovered_ability(mouse_pos)
                    break

    if hovered_ability != null:
        cursor_type = director.CursorType.RULEBOOK

    if hovered_ability != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        card_hover.close()
        rulebook_open(hovered_ability)
        return
    
    if hovered_card != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        # Check if we can summon this card
        var can_summon = false
        if hovered_card.data.cost_type == CardData.CostType.NONE:
            can_summon = true
        elif hovered_card.data.cost_type == CardData.CostType.BLOOD:
            var blood_available = 0
            for board_card in player_board:
                if board_card == null:
                    continue
                blood_available += 1
            if blood_available >= hovered_card.data.cost_amount:
                can_summon = true

        # Begin summoning
        if can_summon:
            card_hover.close()
            hovered_card.animate_presummon()
            hovered_card.z_index = 1
            state = State.PLAYER_SUMMONING

            summoning_card = hovered_card
            if summoning_card.data.cost_type == CardData.CostType.NONE:
                summoning_cost_met = true
            else:
                summoning_cost_met = false

    if BELL_RECT.has_point(mouse_pos):
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            # Ring the bell
            state = State.WAIT
            bell.frame_coords.x = int(BellState.PRESS)
            var tween = get_tree().create_tween()
            tween.tween_interval(0.2)
            await tween.finished
            bell.frame_coords.x = int(BellState.DISABLED)
            await combat_round(Turn.PLAYER)
            state = State.PLAYER_TURN
            return
        else:
            bell.frame_coords.x = int(BellState.HOVER)
    else:
        bell.frame_coords.x = int(BellState.READY)

    director.set_cursor(cursor_type)

# PLAYER SUMMONING

func player_summoning_process():
    var cursor_type = director.CursorType.POINTER
    var mouse_pos = get_viewport().get_mouse_position()

    # HOVER CARDSLOTS
    var hovered_cardslot = null
    var hovered_cardslot_index = -1
    for i in range(0, player_cardslots.size()):
        # Don't allow players to summon onto an occupied slot
        if summoning_cost_met and player_board[i] != null:
            continue
        # Don't allow players to sacrifice an empty slot
        if not summoning_cost_met and summoning_card.data.cost_type == CardData.CostType.BLOOD and player_board[i] == null:
            continue
        # Check if mouse is within cardslot
        var cardslot = player_cardslots[i]
        if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos):
            hovered_cardslot = cardslot
            hovered_cardslot_index = i
            # Open the card hover, but not if it's already in place
            if card_hover.visible and card_hover.position == cardslot.global_position:
                continue
            card_hover.open(cardslot.global_position)
    if hovered_cardslot == null and card_hover.visible:
        card_hover.close()

    # PLACE CREATURE
    if summoning_cost_met:
        if hovered_cardslot != null:
            cursor_type = director.CursorType.DROP
            if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
                # SUMMON
                state = State.WAIT
                director.set_cursor(director.CursorType.POINTER)
                card_hover.close()
                summoning_card.animate_presummon_end()
                # Move the card into place
                var tween = get_tree().create_tween()
                tween.tween_property(summoning_card, "position", hovered_cardslot.global_position, 0.25)
                await tween.finished
                summoning_card.z_index = 0
                # Swap the card out of player hand and onto the board
                player_hand.erase(summoning_card)
                player_board[hovered_cardslot_index] = summoning_card
                summoning_card = null
                summoning_blood_count = 0
                ui_update_blood_counter()
                await hand_update_positions()
                state = State.PLAYER_TURN
                return
    # SACRIFICE CREATURE
    elif summoning_card.data.cost_type == CardData.CostType.BLOOD:
        if hovered_cardslot != null:
            cursor_type = director.CursorType.KNIFE
            if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
                # PERFORM SACRIFICE
                state = State.WAIT
                director.set_cursor(director.CursorType.POINTER)
                card_hover.close()
                await card_death(Turn.PLAYER, hovered_cardslot_index, true)
                summoning_blood_count += 1
                summoning_cost_met = summoning_blood_count >= summoning_card.data.cost_amount
                ui_update_blood_counter()
                state = State.PLAYER_SUMMONING
                return

    director.set_cursor(cursor_type)

# RULEBOOK

func rulebook_open(ability):
    rulebook_name_label.text = ability.name
    rulebook_desc_label.text = ability.description
    rulebook_icon.texture = ability.icon
    rulebook.visible = true

func rulebook_close():
    rulebook.visible = false

func rulebook_process():
    director.set_cursor(director.CursorType.POINTER)
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        rulebook_close()

# COMBAT

func combat_round(turn: Turn):
    var lane_indices = range(0, 4) if turn == Turn.PLAYER else range(3, -1, -1)
    var attacker_board = player_board if turn == Turn.PLAYER else opponent_board
    var defender_board = opponent_board if turn == Turn.PLAYER else player_board
    var opponent_turn = Turn.OPPONENT if turn == Turn.PLAYER else Turn.PLAYER

    var combat_damage = 0
    for lane_index in lane_indices:
        var attacker = attacker_board[lane_index]
        var defender = defender_board[lane_index]
        if attacker == null:
            continue
        if attacker.power == 0:
            continue
        combat_damage = combat_damage + (await combat_do_attack(turn, attacker, defender))
        if defender != null and defender.health == 0:
            await card_death(opponent_turn, lane_index)
    
    # Update score
    for i in range(0, combat_damage):
        # Increment score
        if turn == Turn.PLAYER:
            player_score += 1
        else:
            opponent_score += 1

        # Update scale
        score_scale.display_scores(opponent_score, player_score)

        # Delay for suspense
        var tween = get_tree().create_tween()
        tween.tween_interval(0.1)
        await tween.finished

    # Check if a candle is to be snuffed
    var score = min(abs(player_score - opponent_score), score_scale.SCORE_LIMIT)
    if score == score_scale.SCORE_LIMIT:
        # Delay for suspense
        var tween3 = get_tree().create_tween()
        tween3.tween_interval(1.0)
        await tween3.finished

        # Snuff the candle
        if turn == Turn.PLAYER:
            opponent_candles.snuff_candle()
        else:
            player_candles.snuff_candle()
        
        # Delay for suspense
        var tween2 = get_tree().create_tween()
        tween2.tween_interval(0.25)
        await tween2.finished

        # Reset the scale
        player_score = 0
        opponent_score = 0
        score_scale.display_scores(0, 0)

func combat_attack_animation_play(at_position: Vector2):
    attack_animation.position = at_position
    attack_animation.visible = true
    attack_animation.play()
    await attack_animation.animation_finished
    var fade_tween = get_tree().create_tween()
    fade_tween.tween_property(attack_animation, "modulate", Color(attack_animation.modulate.r, attack_animation.modulate.g, attack_animation.modulate.b, 0.0), 0.1)
    await fade_tween.finished
    attack_animation.visible = false
    attack_animation.modulate.a = 1.0

func combat_do_attack(turn: Turn, attacker: Card, defender: Card):
    var attacker_position = attacker.position
    # attacker_direction flips attack direction when the opponent is attacking
    var attacker_direction = 1 if turn == Turn.PLAYER else -1
    var added_score = 0

    # Attacker lunge
    var attack_tween = get_tree().create_tween()
    attack_tween.tween_property(attacker, "position", attacker_position + Vector2(0, 4 * attacker_direction), 0.1)
    attack_tween.tween_property(attacker, "position", attacker_position + Vector2(0, -18 * attacker_direction), 0.25)
    await attack_tween.finished

    # Attacker return
    var return_tween = get_tree().create_tween()
    return_tween.tween_property(attacker, "position", attacker_position, 0.125)
    return_tween.tween_property(attacker, "position", attacker_position + Vector2(0, -8 * attacker_direction), 0.125)
    return_tween.tween_property(attacker, "position", attacker_position, 0.125)

    # Update health
    var defender_tween = null
    if defender != null:
        defender.health = max(defender.health - attacker.power, 0)
        defender.card_refresh()

        defender_tween = get_tree().create_tween()
        combat_attack_animation_play(defender.position)
        defender_tween.tween_property(defender.dim, "visible", true, 0.0)
        defender_tween.tween_property(defender, "position", defender.position + Vector2(4, 0), 0.1)
        defender_tween.tween_property(defender, "position", defender.position + Vector2(-4, 0), 0.2)
        defender_tween.tween_property(defender, "position", defender.position + Vector2(4, 0), 0.2)
        defender_tween.tween_property(defender, "position", defender.position, 0.1)
        defender_tween.tween_property(defender, "modulate", Color(1, 1, 1, 1), 0.0)
        defender_tween.tween_property(defender.dim, "visible", false, 0.0)
    else:
        added_score = attacker.power

    # Await tweens
    await return_tween.finished
    if defender_tween != null and defender_tween.is_running():
        await defender_tween.finished

    return added_score

func card_death(turn: Turn, index: int, is_sacrifice = false):
    var board = player_board if turn == Turn.PLAYER else opponent_board
    var card = board[index] 
    await card.animate_death(is_sacrifice)
    card.queue_free()
    board[index] = null
    if turn == Turn.PLAYER:
        player_bone_count += 1
        ui_update_bone_counter()