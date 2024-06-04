extends Node2D

signal server_ready

@onready var director = get_node("/root/Director")
@onready var network = get_node("/root/Network")

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
@onready var deck = $deck
@onready var deck_count_label = $deck/value
@onready var squirrel_deck = $squirrel_deck
@onready var squirrel_deck_count_label = $squirrel_deck/value
@onready var popup = $popup
@onready var fade = $fade
var blood_counter_sprites = []
@onready var sfx_sacrifice = $sfx/sacrifice
@onready var sfx_death = $sfx/death
@onready var sfx_win = $sfx/win
@onready var sfx_scale = $sfx/scale
@onready var sfx_attack = $sfx/attack
@onready var sfx_crunch = $sfx/crunch
@onready var sfx_blip = $sfx/blip

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

const CAT_LIVES = 9

const BELL_SIZE = Vector2(182, 72)
@onready var BELL_RECT = Rect2(bell.position - (BELL_SIZE * 0.5), BELL_SIZE)

var state = State.WAIT
var player_hand = []
var player_board = [null, null, null, null]
var player_score = 0
var player_bone_count = 0
var player_deck = []
var player_squirrel_deck_count = 20
var opponent_hand = []
var opponent_board = [null, null, null, null]
var opponent_score = 0

var summoning_card = null
var summoning_cost_met = false
var summoning_blood_count = 0

var network_action_queue = []
var network_is_action_running = false

var is_game_over = false
var is_game_done = false
var is_server_ready = false

var skip_draw = false
var skip_combat = false

func _ready():
    # Setup
    for child in $blood_counter.get_children():
        blood_counter_sprites.push_back(child.get_child(0))
    bell.frame_coords.x = int(BellState.DISABLED)
    score_scale.display_scores(0, 0)
    network.server_client_disconnected.connect(_on_opponent_disconnect)
    network.client_server_disconnected.connect(_on_opponent_disconnect)
    rulebook_close()

    # Init player deck
    var deck_unshuffled = []
    for card in director.player_deck:
        deck_unshuffled.push_back(card) 
    while not deck_unshuffled.is_empty():
        player_deck.push_back(deck_unshuffled.pop_at(randi_range(0, deck_unshuffled.size() - 1)))

    # Init opponent hand
    for i in range(0, 4):
        opponent_hand_add_card()
    # Init player hand
    await hand_add_card(Card.SQUIRREL)
    var cards_in_hand = 1
    while cards_in_hand != 4:
        if not player_deck.is_empty():
            await hand_add_card(player_deck.pop_front())
        else:
            await hand_add_card(Card.SQUIRREL)
        cards_in_hand += 1

    ui_update_deck_counters()

    if not network.network_is_connected():
        state = State.PLAYER_DRAW
    else:
        state = State.WAIT
        if not multiplayer.is_server():
            _on_client_ready.rpc_id(network.opponent_id)
        else:
            is_server_ready = true
            server_ready.emit()

@rpc("any_peer", "reliable")
func _on_client_ready():
    if not is_server_ready:
        await server_ready
    var server_goes_first = bool(randi_range(0, 1))
    _on_server_declared_first_turn.rpc_id(network.opponent_id, server_goes_first)
    state = State.PLAYER_DRAW if server_goes_first else State.WAIT
    var message = "You go first." if server_goes_first else "Opponent goes first."
    skip_draw = server_goes_first
    popup.open(message, 1.0)

@rpc("any_peer", "reliable")
func _on_server_declared_first_turn(server_goes_first):
    state = State.WAIT if server_goes_first else State.PLAYER_DRAW
    var message = "Opponent goes first" if server_goes_first else "You go first." 
    skip_draw = not server_goes_first
    popup.open(message, 1.0)

func _process(_delta):
    if is_game_done:
        return
    if is_game_over:
        if Input.is_action_just_pressed("mouse_button_left"):
            is_game_done = true
            var tween = get_tree().create_tween()
            tween.tween_property(fade, "color", Color(0, 0, 0, 1), 1.0)
            await tween.finished
            director.end_match()
            return
    if state == State.WAIT or state == State.PLAYER_DRAW:
        player_hand_process()
    if state == State.WAIT:
        network_process()
    if rulebook.visible:
        rulebook_process()
        return
    if state == State.WAIT:
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

func hand_add_card(card_id: int):
    const CARD_SPAWN_POS = Vector2(681, 407)

    var card_instance = card_scene.instantiate()
    card_instance.card_init(card_id)
    add_child(card_instance)
    card_instance.position = CARD_SPAWN_POS
    player_hand.append(card_instance)

    await hand_update_positions()

func opponent_hand_add_card():
    const CARD_SPAWN_POS = Vector2(681, -24)

    var opponent_card = card_scene.instantiate()
    opponent_card.card_init(Card.SQUIRREL, true)
    add_child(opponent_card)
    opponent_card.position = CARD_SPAWN_POS
    opponent_hand.append(opponent_card)

    await opponent_hand_update_positions()

func opponent_hand_update_positions():
    const HAND_CENTER = Vector2(426, -24)
    const HAND_UPDATE_DURATION = 0.25

    if opponent_hand.size() == 0:
        return
    if opponent_hand.size() == 1:
        var tween1 = get_tree().create_tween()
        tween1.parallel().tween_property(opponent_hand[0], "position", HAND_CENTER, HAND_UPDATE_DURATION)
        await tween1.finished
        return
    
    var hand_area_size = min(276.0, opponent_hand.size() * (0.5 * Card.CARD_SIZE.x))
    var HAND_CARD_PADDING = hand_area_size / (opponent_hand.size() - 1)
    var hand_area_start = HAND_CENTER.x - (hand_area_size * 0.5)

    var tween = get_tree().create_tween()
    for i in range(0, opponent_hand.size()):
        var card_x = hand_area_start + (i * HAND_CARD_PADDING)
        tween.parallel().tween_property(opponent_hand[i], "position", Vector2(card_x, HAND_CENTER.y), HAND_UPDATE_DURATION)
    await tween.finished

# UI

func ui_update_blood_counter():
    for i in range(0, 4):
        if summoning_blood_count > i:
            blood_counter_sprites[i].frame_coords.x = 1
        else:
            blood_counter_sprites[i].frame_coords.x = 0

func ui_update_bone_counter():
    bone_counter_label.text = "x" + str(player_bone_count)

func ui_update_deck_counters():
    deck_count_label.text = "x" + str(player_deck.size())
    squirrel_deck_count_label.text = "x" + str(player_squirrel_deck_count)

# BOARD

func board_add_card(which: Turn, index: int, card_id: int):
    var card_instance = card_scene.instantiate()
    card_instance.card_init(card_id)
    add_child(card_instance)
    if which == Turn.PLAYER:
        card_instance.position = player_cardslots[index].global_position
        player_board[index] = card_instance
    else:
        card_instance.position = opponent_cardslots[index].global_position
        opponent_board[index] = card_instance

func opponent_board_play_card(index: int, card_id: int):
    var card = opponent_hand[opponent_hand.size() - 1]
    card.z_index = 1

    var tween = get_tree().create_tween()
    tween.tween_property(card, "position", opponent_cardslots[index].global_position, 0.25)
    card.set_card_id(card_id)
    await tween.finished
    if card.has_ability(Ability.Name.SPRINTER) or card.has_ability(Ability.Name.HEFTY):
        card.set_sprint_direction(-1)
    await card.card_flip(Card.FlipTo.FRONT)
    sfx_crunch.play()
    card.z_index = 0

    opponent_hand.erase(card)
    opponent_board[index] = card
    await opponent_hand_update_positions()

    await on_card_played(Turn.OPPONENT, card, index)

func board_animate_guardian(which: Turn, from: int, to: int):
    var board = player_board if which == Turn.PLAYER else opponent_board
    var to_cardslot = player_cardslots[to] if which == Turn.PLAYER else opponent_cardslots[to]
    var card = board[from]
    var direction = 1 if which == Turn.PLAYER else -1

    card.z_index = 1
    var tween = get_tree().create_tween()
    tween.tween_property(card, "position", card.position + (direction * Vector2(0, 16)), 0.125)
    tween.tween_property(card, "position", to_cardslot.global_position + (direction * Vector2(0, 16)), 0.25)
    tween.tween_property(card, "position", to_cardslot.global_position, 0.125)
    await tween.finished
    card.z_index = 0
    sfx_crunch.play()

    board[to] = card
    board[from] = null

func board_kill_card(turn: Turn, index: int, is_sacrifice = false):
    var board = player_board if turn == Turn.PLAYER else opponent_board
    var card = board[index] 
    if is_sacrifice:
        sfx_sacrifice.play()
    else:
        sfx_death.play()
    await card.animate_death(is_sacrifice)
    board[index] = null
    if turn == Turn.PLAYER:
        if card.has_ability(Ability.Name.BONE_KING):
            player_bone_count += 4
        else:
            player_bone_count += 1
        ui_update_bone_counter()
    await on_card_died(turn, card, index, is_sacrifice)
    card.queue_free()

func board_compute_powers(which: Turn):
    var board = player_board if which == Turn.PLAYER else opponent_board
    var _opposite_board = opponent_board if which == Turn.PLAYER else player_board
    for index in range(0, board.size()):
        if board[index] == null:
            continue
        board[index].power = board[index].data.power
        if index - 1 >= 0 and board[index - 1] != null and board[index - 1].has_ability(Ability.Name.LEADER):
            board[index].power += 1
        if index + 1 < board.size() and board[index + 1] != null and board[index + 1].has_ability(Ability.Name.LEADER):
            board[index].power += 1
        board[index].card_refresh()

# GAME EVENTS

func on_card_played(who: Turn, card: Card, index: int):
    var opposite_player = Turn.OPPONENT if who == Turn.PLAYER else Turn.PLAYER
    var opposite_board = opponent_board if who == Turn.PLAYER else player_board

    if opposite_board[index] == null:
        for opposite_board_index in range(0, opposite_board.size()):
            if opposite_board[opposite_board_index] == null:
                continue
            if opposite_board[opposite_board_index].has_ability(Ability.Name.GUARDIAN):
                await board_animate_guardian(opposite_player, opposite_board_index, index)
                break

    board_compute_powers(Turn.PLAYER)
    board_compute_powers(Turn.OPPONENT)

    if card.has_ability(Ability.Name.ANT_SPAWNER) or card.has_ability(Ability.Name.RABBIT_HOLE):
        if who == Turn.PLAYER:
            await hand_add_card(Card.get_id_from_data(card.data.tail))
        else:
            await opponent_hand_add_card()

func on_card_hit(who: Turn, card: Card, attacker: Card):
    if card.has_ability(Ability.Name.BEES_WITHIN):
        if who == Turn.PLAYER:
            await hand_add_card(Card.get_id_from_data(card.data.tail))
        else:
            await opponent_hand_add_card()
    if card.has_ability(Ability.Name.SHARP):
        attacker.health -= 1
        board_compute_powers(Turn.PLAYER)
        board_compute_powers(Turn.OPPONENT)

func on_card_died(who: Turn, card: Card, index: int, was_sacrifice = false):
    var board = player_board if who == Turn.PLAYER else opponent_board

    if was_sacrifice and card.has_ability(Ability.Name.MANY_LIVES):
        board_add_card(who, index, card.card_id)
        if board[index].sacrifice_count < CAT_LIVES:
            board[index].sacrifice_count = card.sacrifice_count + 1
            if board[index].sacrifice_count == CAT_LIVES:
                if board[index].data.evolves_into != null:
                    await board[index].evolve()

    board_compute_powers(Turn.PLAYER)
    board_compute_powers(Turn.OPPONENT)

func on_combat_over(who: Turn):
    var attacker_board = player_board if who == Turn.PLAYER else opponent_board
    var attacker_cardslots = player_cardslots if who == Turn.PLAYER else opponent_cardslots
    var defender_board = opponent_board if who == Turn.PLAYER else player_board

    var skip_index = false
    var lane_indices = range(0, 4) if who == Turn.PLAYER else range(3, -1, -1)
    for board_index in lane_indices:
        if skip_index:
            skip_index = false
            continue
        var card = attacker_board[board_index]
        if card == null:
            continue
        if card.has_ability(Ability.Name.SPRINTER):
            # Determine if blocked
            var direction = card.get_sprint_direction()
            var next_index = board_index + direction
            var is_blocked = next_index < 0 or next_index >= attacker_board.size() or attacker_board[next_index] != null

            # If so, flip direction
            if is_blocked:
                card.set_sprint_direction(direction * -1)
            # Otherwise, move one space
            else:
                var tween = get_tree().create_tween()
                tween.tween_property(card, "position", attacker_cardslots[next_index].global_position, 0.25)
                await tween.finished
                attacker_board[next_index] = card
                attacker_board[board_index] = null
                if card.data.tail != null:
                    board_add_card(who, board_index, Card.get_id_from_data(card.data.tail))
                    attacker_board[board_index].set_sprint_direction(card.get_sprint_direction())

                # If we moved into the next index to be iterated over, skip that index
                if (direction == 1 and who == Turn.PLAYER) or (direction == -1 and who == Turn.OPPONENT):
                    skip_index = true
        if card.has_ability(Ability.Name.HEFTY):
            # Determine if blocked
            var direction = card.get_sprint_direction()
            var next_free_index = board_index
            while next_free_index >= 0 and next_free_index < attacker_board.size() and attacker_board[next_free_index] != null:
                next_free_index += direction
            var is_blocked = next_free_index < 0 or next_free_index >= attacker_board.size()

            # If so, flip direction
            if is_blocked:
                card.set_sprint_direction(direction * -1)
            # Otherwise, move one space
            else:
                var tween = get_tree().create_tween()
                # Start from the free space and move everyone over one at a time
                var dest_index = next_free_index
                while dest_index != board_index:
                    var source_index = dest_index - direction
                    tween.parallel().tween_property(attacker_board[source_index], "position", attacker_cardslots[dest_index].global_position, 0.25)
                    attacker_board[dest_index] = attacker_board[source_index]

                    dest_index = source_index
                attacker_board[board_index] = null
                await tween.finished
                # If we moved into the next index to be iterated over, skip that index
                if (direction == 1 and who == Turn.PLAYER) or (direction == -1 and who == Turn.OPPONENT):
                    skip_index = true
    for card in defender_board:
        if card == null:
            continue
        if card.has_ability(Ability.Name.EVOLVE):
            await card.evolve()

# PLAYER DRAW

func player_draw_process():
    const DECK_AREA_SIZE = Vector2(52, 34)
    const DECK_OFFSET = Vector2(-13, -17)

    if skip_draw:
        skip_draw = false
        state = State.PLAYER_TURN
        return

    if not popup.visible:
        popup.open("Draw a card.")

    if player_deck.size() == 0 and player_squirrel_deck_count == 0:
        state = State.WAIT
        if network.network_is_connected():
            _on_opponent_cannot_draw_card.rpc_id(network.opponent_id)
        opponent_score += 1

        # Update scale
        score_scale.display_scores(opponent_score, player_score)

        # Delay for suspense
        var tween = get_tree().create_tween()
        tween.tween_interval(0.1)
        await tween.finished

        await check_if_candle_snuffed(Turn.OPPONENT)
        state = State.PLAYER_TURN
        return

    var cursor_type = director.current_cursor
    var mouse_pos = get_viewport().get_mouse_position()

    var drawn_card = null
    var DECK_RECT = Rect2(deck.position + DECK_OFFSET, DECK_AREA_SIZE)
    if player_deck.size() != 0 and DECK_RECT.has_point(mouse_pos):
        cursor_type = director.CursorType.HAND
        if Input.is_action_just_pressed("mouse_button_left"):
            drawn_card = player_deck.pop_back()
    var SQUIRREL_DECK_RECT = Rect2(squirrel_deck.position + DECK_OFFSET, DECK_AREA_SIZE)
    if player_squirrel_deck_count != 0 and SQUIRREL_DECK_RECT.has_point(mouse_pos):
        cursor_type = director.CursorType.HAND
        if Input.is_action_just_pressed("mouse_button_left"):
            drawn_card = Card.SQUIRREL
            player_squirrel_deck_count -= 1

    if drawn_card != null:
        popup.close()
        if network.network_is_connected():
            _on_opponent_draw_card.rpc_id(network.opponent_id)
        state = State.WAIT
        ui_update_deck_counters()
        await hand_add_card(drawn_card)
        state = State.PLAYER_TURN

    director.set_cursor(cursor_type)

# PLAYER TURN

func player_hand_process():
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
            if state == State.PLAYER_TURN and not (card_hover.visible and card_hover.position == card.position): 
                card_hover.open(card.position)
            break

    if hovered_card != null:
        hovered_card.z_index = 1
    if hovered_card == null and card_hover.visible:
        card_hover.close()

    # Check if we're hovering over a sigil
    var hovered_ability = Ability.Name.NONE
    if hovered_card != null:
        hovered_ability = hovered_card.get_hovered_ability(mouse_pos)
    else:
        # Check sigil hover on player board
        for i in range(0, player_cardslots.size()):
            var cardslot = player_cardslots[i]
            if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos) and player_board[i] != null:
                hovered_ability = player_board[i].get_hovered_ability(mouse_pos)
                break
        if hovered_ability == Ability.Name.NONE:
            # Check sigil hover on opponent board
            for i in range(0, opponent_cardslots.size()):
                var cardslot = opponent_cardslots[i]
                if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos) and opponent_board[i] != null:
                    hovered_ability = opponent_board[i].get_hovered_ability(mouse_pos)
                    break

    if hovered_ability != Ability.Name.NONE:
        cursor_type = director.CursorType.RULEBOOK

    if hovered_ability != Ability.Name.NONE and Input.is_action_just_pressed("mouse_button_right"):
        card_hover.close()
        rulebook_open(hovered_ability)
        return null

    director.set_cursor(cursor_type)
    return hovered_card

func player_turn_process():
    var hovered_card = player_hand_process()

    if hovered_card != null and Input.is_action_just_pressed("mouse_button_left"):
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
                if board_card.has_ability(Ability.Name.WORTHY_SACRIFICE):
                    blood_available += 2
            if blood_available >= hovered_card.data.cost_amount:
                can_summon = true
        elif hovered_card.data.cost_type == CardData.CostType.BONE and player_bone_count >= hovered_card.data.cost_amount:
            can_summon = true

        # Check if there is space to summon this card
        var is_board_space_available = false
        for card in player_board:
            # Empty spaces count can be summoned onto
            if card == null:
                is_board_space_available = true
                break

            var card_will_reoccupy_slot = false
            if card.has_ability(Ability.Name.MANY_LIVES) and card.sacrifice_count < CAT_LIVES:
                card_will_reoccupy_slot = true
            if hovered_card.data.cost_type == CardData.CostType.BLOOD and not card_will_reoccupy_slot:
                is_board_space_available = true
                break
        if not is_board_space_available:
            can_summon = false

        # Begin summoning
        if can_summon:
            card_hover.close()
            hovered_card.animate_presummon()
            hovered_card.z_index = 1
            state = State.PLAYER_SUMMONING

            summoning_card = hovered_card
            if summoning_card.data.cost_type == CardData.CostType.NONE or summoning_card.data.cost_type == CardData.CostType.BONE:
                summoning_cost_met = true
            else:
                summoning_cost_met = false
        # Show can't summon message
        else:
            var message = ""
            if not is_board_space_available:
                message = "You have nowhere to place that."
            elif hovered_card.data.cost_type == CardData.CostType.BLOOD:
                message = "You need more sacrifices to summon that."
            elif hovered_card.data.cost_type == CardData.CostType.BONE:
                message = "You need more bones to summon that."
            popup.open(message, 1.0)

    var mouse_pos = get_viewport().get_mouse_position()
    if BELL_RECT.has_point(mouse_pos):
        if Input.is_action_just_pressed("mouse_button_left"):
            # COMBAT PHASE
            state = State.WAIT

            # Tell the opponent
            if network.network_is_connected():
                _on_opponent_ring_bell.rpc_id(network.opponent_id)

            # Ring the bell
            sfx_blip.play()
            bell.frame_coords.x = int(BellState.PRESS)
            var tween = get_tree().create_tween()
            tween.tween_interval(0.2)
            await tween.finished
            bell.frame_coords.x = int(BellState.DISABLED)

            # Do combat
            await combat_round(Turn.PLAYER)

            # Yield the turn
            if network.network_is_connected():
                popup.open("Opponent's turn.", 1.0)
                _on_opponent_yield_turn.rpc_id(network.opponent_id)
            else:
                state = State.PLAYER_TURN
            return
        else:
            bell.frame_coords.x = int(BellState.HOVER)
    else:
        bell.frame_coords.x = int(BellState.READY)

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
            if Input.is_action_just_pressed("mouse_button_left"):
                # SUMMON
                state = State.WAIT
                if network.network_is_connected():
                    _on_opponent_place_card.rpc_id(network.opponent_id, hovered_cardslot_index, summoning_card.card_id)
                director.set_cursor(director.CursorType.POINTER)
                card_hover.close()
                summoning_card.animate_presummon_end()

                # Move the card into place
                var tween = get_tree().create_tween()
                tween.tween_property(summoning_card, "position", hovered_cardslot.global_position, 0.25)
                await tween.finished
                sfx_crunch.play()
                summoning_card.z_index = 0

                # Swap the card out of player hand and onto the board
                player_hand.erase(summoning_card)
                player_board[hovered_cardslot_index] = summoning_card
                if summoning_card.data.cost_type == CardData.CostType.BONE:
                    player_bone_count -= summoning_card.data.cost_amount
                    ui_update_bone_counter()

                summoning_blood_count = 0
                summoning_card = null
                ui_update_blood_counter()

                await hand_update_positions()
                await on_card_played(Turn.PLAYER, player_board[hovered_cardslot_index], hovered_cardslot_index)
                state = State.PLAYER_TURN
                return
    # SACRIFICE CREATURE
    elif summoning_card.data.cost_type == CardData.CostType.BLOOD:
        if hovered_cardslot != null:
            cursor_type = director.CursorType.KNIFE
            if Input.is_action_just_pressed("mouse_button_left"):
                # PERFORM SACRIFICE
                state = State.WAIT
                if network.network_is_connected():
                    _on_opponent_sacrifice_card.rpc_id(network.opponent_id, hovered_cardslot_index)
                director.set_cursor(director.CursorType.POINTER)
                card_hover.close()
                summoning_blood_count += 1
                if player_board[hovered_cardslot_index].has_ability(Ability.Name.WORTHY_SACRIFICE):
                    summoning_blood_count += 2
                await board_kill_card(Turn.PLAYER, hovered_cardslot_index, true)
                summoning_cost_met = summoning_blood_count >= summoning_card.data.cost_amount
                ui_update_blood_counter()
                state = State.PLAYER_SUMMONING
                return

    director.set_cursor(cursor_type)

# RULEBOOK

func rulebook_open(ability_name: Ability.Name):
    rulebook_name_label.text = Ability.name_str(ability_name)
    rulebook_desc_label.text = Ability.DESC[ability_name]
    rulebook_icon.texture = Ability.load_icon(ability_name)
    rulebook.visible = true

func rulebook_close():
    rulebook.visible = false

func rulebook_process():
    director.set_cursor(director.CursorType.POINTER)
    if Input.is_action_just_pressed("mouse_button_left"):
        rulebook_close()

# COMBAT

func combat_round(turn: Turn):
    if skip_combat:
        skip_combat = false
        return

    var lane_indices = range(0, 4) if turn == Turn.PLAYER else range(3, -1, -1)
    var attacker_board = player_board if turn == Turn.PLAYER else opponent_board
    var defender_board = opponent_board if turn == Turn.PLAYER else player_board
    var opponent_turn = Turn.OPPONENT if turn == Turn.PLAYER else Turn.PLAYER

    var combat_damage = 0
    for lane_index in lane_indices:
        # Determine attacker
        var attacker = attacker_board[lane_index]
        if attacker == null:
            continue
        if attacker.power == 0:
            continue

        # Determine attack indices
        var attack_indices = [lane_index]
        if attacker.has_ability(Ability.Name.TWIN_STRIKE) or attacker.has_ability(Ability.Name.TRIPLET_STRIKE):
            if attacker.has_ability(Ability.Name.TWIN_STRIKE):
                attack_indices = [lane_index - 1, lane_index + 1] if turn == Turn.PLAYER else [lane_index + 1, lane_index - 1]
            else:
                attack_indices = [lane_index - 1, lane_index, lane_index + 1] if turn == Turn.PLAYER else [lane_index + 1, lane_index, lane_index - 1]
        # Attack at each index
        for attack_index in attack_indices:
            if attack_index < 0 or attack_index >= 4:
                continue

            var defender = defender_board[attack_index]
            if defender != null and attacker.has_ability(Ability.Name.AIRBORNE) and not defender.has_ability(Ability.Name.MIGHTY_LEAP):
                defender = null

            combat_damage = combat_damage + (await combat_do_attack(turn, attacker, attack_index))
            if defender != null:
                await on_card_hit(opponent_turn, defender, attacker)
                if defender.health == 0 or attacker.has_ability(Ability.Name.DEATHTOUCH):
                    await board_kill_card(opponent_turn, attack_index)
            # Handle death from porcupine
            if attacker.health == 0:
                await board_kill_card(turn, lane_index)
                break
    
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

    await check_if_candle_snuffed(turn)
    if is_game_over:
        return

    await on_combat_over(turn)

func check_if_candle_snuffed(turn: Turn):
    # Check if a candle is to be snuffed
    var score = min(abs(player_score - opponent_score), score_scale.SCORE_LIMIT)
    if score == score_scale.SCORE_LIMIT:
        # Delay for suspense
        var tween3 = get_tree().create_tween()
        tween3.tween_interval(1.0)
        await tween3.finished

        # Snuff the candle
        var candles = opponent_candles if turn == Turn.PLAYER else player_candles
        candles.snuff_candle()
        
        # Delay for suspense
        var tween2 = get_tree().create_tween()
        tween2.tween_interval(0.25)
        await tween2.finished

        if candles.no_candles_left():
            # End the game
            sfx_win.play()
            var message = "You win!" if turn == Turn.PLAYER else "You lose."
            popup.open(message)
            set_game_over()
        else:
            # Reset the scale
            sfx_scale.play()
            player_score = 0
            opponent_score = 0
            score_scale.display_scores(0, 0)

            # Give the defeated the smoke
            if turn == Turn.PLAYER:
                await opponent_hand_add_card()
            else:
                await hand_add_card(Card.THE_SMOKE)

func combat_attack_animation_play(at_position: Vector2):
    attack_animation.position = at_position
    attack_animation.visible = true
    attack_animation.play()
    sfx_attack.play()
    await attack_animation.animation_finished
    var fade_tween = get_tree().create_tween()
    fade_tween.tween_property(attack_animation, "modulate", Color(attack_animation.modulate.r, attack_animation.modulate.g, attack_animation.modulate.b, 0.0), 0.1)
    await fade_tween.finished
    attack_animation.visible = false
    attack_animation.modulate.a = 1.0

func combat_do_attack(turn: Turn, attacker: Card, index: int):
    var defender_board = opponent_board if turn == Turn.PLAYER else player_board
    var defender_cardslots = opponent_cardslots if turn == Turn.PLAYER else player_cardslots
    var defender = defender_board[index]

    var attacker_position = attacker.position
    var lunge_direction = attacker.position.direction_to(defender_cardslots[index].global_position)
    var added_score = 0

    # Attacker lunge
    var attack_tween = get_tree().create_tween()
    attack_tween.tween_property(attacker, "position", attacker_position + (-4 * lunge_direction), 0.1)
    attack_tween.tween_property(attacker, "position", attacker_position + (18 * lunge_direction), 0.25)
    await attack_tween.finished

    # Attacker return
    var return_tween = get_tree().create_tween()
    return_tween.tween_property(attacker, "position", attacker_position, 0.125)
    return_tween.tween_property(attacker, "position", attacker_position + (8 * lunge_direction), 0.125)
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

# RPC

enum NetworkActionType {
    DRAW,
    NO_DRAW,
    SACRIFICE,
    SUMMON,
    BELL,
    YIELD
}

func network_process():
    if network_is_action_running:
        return
    if network_action_queue.is_empty():
        return

    var action = network_action_queue.pop_front()
    network_is_action_running = true
    if action.type == NetworkActionType.DRAW:
        await opponent_hand_add_card()
    elif action.type == NetworkActionType.NO_DRAW:
        player_score += 1

        # Update scale
        score_scale.display_scores(opponent_score, player_score)

        # Delay for suspense
        var tween = get_tree().create_tween()
        tween.tween_interval(0.1)
        await tween.finished

        await check_if_candle_snuffed(Turn.OPPONENT)
    elif action.type == NetworkActionType.SACRIFICE:
        await board_kill_card(Turn.OPPONENT, 3 - action.index, true)
    elif action.type == NetworkActionType.SUMMON:
        await opponent_board_play_card(3 - action.index, action.card_id)
    elif action.type == NetworkActionType.BELL:
        await combat_round(Turn.OPPONENT)
    elif action.type == NetworkActionType.YIELD:
        assert(network_action_queue.is_empty())
        popup.open("Your turn.", 1.0)
        state = State.PLAYER_DRAW
    network_is_action_running = false

@rpc("any_peer", "reliable")
func _on_opponent_draw_card():
    network_action_queue.push_back({
        "type": NetworkActionType.DRAW
    })

@rpc("any_peer", "reliable")
func _on_opponent_cannot_draw_card():
    network_action_queue.push_back({
        "type": NetworkActionType.NO_DRAW
    })

@rpc("any_peer", "reliable")
func _on_opponent_sacrifice_card(index: int):
    network_action_queue.push_back({
        "type": NetworkActionType.SACRIFICE,
        "index": index
    })

@rpc("any_peer", "reliable")
func _on_opponent_place_card(index: int, card_id: int):
    network_action_queue.push_back({
        "type": NetworkActionType.SUMMON,
        "index": index,
        "card_id": card_id
    })

@rpc("any_peer", "reliable")
func _on_opponent_ring_bell():
    network_action_queue.push_back({
        "type": NetworkActionType.BELL
    })

@rpc("any_peer", "reliable")
func _on_opponent_yield_turn():
    network_action_queue.push_back({
        "type": NetworkActionType.YIELD
    })

func _on_opponent_disconnect():
    popup.open("Your opponent disconnected.")
    set_game_over()

func set_game_over():
    rulebook_close()
    is_game_over = true
